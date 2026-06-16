"""
Reference script: Import Unreal Engine FBX into Blender and set up PBR materials.
UE naming conventions:
  _D  = Diffuse / Base Color (sRGB)
  _N  = Normal (non-color, via Normal Map node)
  _FTM = Combined mask — R channel → Roughness (adjust if wrong)
  _RGID = RGB ID mask (loaded, not wired — for manual blending)
  _HM/_HET/_EM/_FX/_SDF = loaded as images, not wired

Usage from terminal:
  blender --background --python path/to/this_script.py

Set TEX_DIR and BLEND_PATH before running.
"""

import bpy
import os

# ═══════════════ CONFIGURE THESE ═══════════════
TEX_DIR = "D:/建模/models/lx/R2T1LucyMd10011/Model"
BLEND_PATH = "D:/建模/models/lx/R2T1LucyMd10011/Model/MyModel.blend"
FBX_NAME = "R2T1LucyMd10011.fbx"

MATERIAL_MAP = {
    # material_name_in_fbx: texture_base_name (without suffix)
    'MI_R2T1LucyMd10011Bangs': 'T_R2T1LucyMd10011Bangs',
    'MI_R2T1LucyMd10011Hair':  'T_R2T1LucyMd10011Hair',
    'MI_R2T1LucyMd10011Up':    'T_R2T1LucyMd10011Up',
    'MI_R2T1LucyMd10011Down':  'T_R2T1LucyMd10011Down',
    'MI_R2T1LucyMd10011Cloth': 'T_R2T1LucyMd10011Cloth',
    'MI_R2T1LucyMd10011Eye':   'T_R2T1LucyMd10011Eye',
}

# Face uses Face01_D instead of Face_D — handle as special case
SPECIAL_MATERIALS = [
    ('MI_R2T1LucyMd10011Face', 'T_R2T1LucyMd10011Face', '01_D'),
]
# ═══════════════════════════════════════════════


def load_texture(name):
    """Load PNG from TEX_DIR into bpy.data.images if not already loaded."""
    if name in bpy.data.images:
        return bpy.data.images[name]
    path = os.path.join(TEX_DIR, name)
    if os.path.exists(path):
        img = bpy.data.images.load(path)
        img.name = name
        return img
    print(f"  MISSING: {path}")
    return None


def setup_pbr_material(mat_name, tex_base, base_color_suffix='_D'):
    """Create Principled BSDF node tree for a UE-derived material."""
    mat = bpy.data.materials.get(mat_name)
    if not mat:
        print(f"  WARN: Material '{mat_name}' not found in scene")
        return

    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Principled BSDF
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (400, 0)

    out = nodes.new(type='ShaderNodeOutputMaterial')
    out.location = (800, 0)
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

    # Texture Coordinate (UV)
    texcoord = nodes.new(type='ShaderNodeTexCoord')
    texcoord.location = (-700, 300)

    x, y = -400, 300

    # ── Base Color (Diffuse) ──
    d_name = f"{tex_base}{base_color_suffix}.png"
    d_img = load_texture(d_name)
    if d_img:
        d_img.colorspace_settings.name = 'sRGB'
        tn = nodes.new(type='ShaderNodeTexImage')
        tn.image = d_img
        tn.location = (x, y)
        tn.label = "BaseColor"
        links.new(texcoord.outputs['UV'], tn.inputs['Vector'])
        links.new(tn.outputs['Color'], bsdf.inputs['Base Color'])
        if d_img.channels >= 4:
            links.new(tn.outputs['Alpha'], bsdf.inputs['Alpha'])
        print(f"    ✓ BaseColor: {d_name}")
        y -= 280

    # ── Normal ──
    n_name = f"{tex_base}_N.png"
    n_img = load_texture(n_name)
    if n_img:
        n_img.colorspace_settings.name = 'Non-Color'
        tn = nodes.new(type='ShaderNodeTexImage')
        tn.image = n_img
        tn.location = (x, y)
        tn.label = "Normal"
        links.new(texcoord.outputs['UV'], tn.inputs['Vector'])

        nm = nodes.new(type='ShaderNodeNormalMap')
        nm.location = (x + 300, y)
        links.new(tn.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        print(f"    ✓ Normal: {n_name}")
        y -= 280

    # ── FTM mask (R → Roughness) ──
    ftm_name = f"{tex_base}_FTM.png"
    ftm_img = load_texture(ftm_name)
    if ftm_img:
        ftm_img.colorspace_settings.name = 'Non-Color'
        tn = nodes.new(type='ShaderNodeTexImage')
        tn.image = ftm_img
        tn.location = (x, y)
        tn.label = "FTM"
        links.new(texcoord.outputs['UV'], tn.inputs['Vector'])

        sep = nodes.new(type='ShaderNodeSeparateColor')
        sep.location = (x + 300, y)
        links.new(tn.outputs['Color'], sep.inputs['Color'])
        links.new(sep.outputs['Red'], bsdf.inputs['Roughness'])
        print(f"    ✓ FTM: {ftm_name} (R→Roughness)")
        y -= 280

    # ── RGID mask (loaded, not wired) ──
    rgid_name = f"{tex_base}_RGID.png"
    rgid_img = load_texture(rgid_name)
    if rgid_img:
        rgid_img.colorspace_settings.name = 'Non-Color'
        tn = nodes.new(type='ShaderNodeTexImage')
        tn.image = rgid_img
        tn.location = (x, y)
        tn.label = "RGID"
        links.new(texcoord.outputs['UV'], tn.inputs['Vector'])
        print(f"    ✓ RGID: {rgid_name} (loaded)")
        y -= 280

    print(f"  → Material '{mat_name}' complete")


# ═══════════════ MAIN ═══════════════

# 1. Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
for block in list(bpy.data.meshes):
    if block.users == 0:
        bpy.data.meshes.remove(block)
for block in list(bpy.data.materials):
    if block.users == 0:
        bpy.data.materials.remove(block)
for block in list(bpy.data.images):
    if block.users == 0:
        bpy.data.images.remove(block)

# 2. Import FBX
fbx_path = os.path.join(TEX_DIR, FBX_NAME)
print(f"Importing: {fbx_path}")
bpy.ops.import_scene.fbx(filepath=fbx_path)

# 3. Pre-load all PNG textures
png_files = sorted([f for f in os.listdir(TEX_DIR) if f.endswith('.png')])
for f in png_files:
    load_texture(f)
print(f"Loaded {len(png_files)} textures")

# 4. Set up all standard materials
print("\n=== Setting up PBR materials ===")
for mat_name, tex_base in MATERIAL_MAP.items():
    setup_pbr_material(mat_name, tex_base)

# 5. Handle special materials (e.g., multi-variant Diffuse)
for mat_name, tex_base, suffix in SPECIAL_MATERIALS:
    print(f"\n=== Special: {mat_name} ===")
    setup_pbr_material(mat_name, tex_base, base_color_suffix=suffix)

# 6. Clean up unused defaults
for m in list(bpy.data.materials):
    if m.name in ('Dots Stroke', 'Material') and m.users == 0:
        bpy.data.materials.remove(m)

# 7. Save
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

print(f"\n=== DONE: {BLEND_PATH} ===")
print(f"Objects: {len(bpy.data.objects)}")
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        print(f"  {obj.name}: {len(obj.data.vertices)} verts")
print(f"Materials: {len(bpy.data.materials)}")
print(f"Images: {len(bpy.data.images)}")
