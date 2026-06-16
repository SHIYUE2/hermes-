---
name: 3d-asset-workflow
description: Diagnose and fix 3D model import failures in Blender — broken OBJ/MTL references, missing textures, corrupt DAE files, format conversion. Covers the full repair-verify loop with Blender headless for validation.
---

# 3D Asset Workflow

## When to use
User says a 3D model "won't import", "can't open", "textures missing", or "looks broken" in Blender. Also: format questions (OBJ vs DAE vs glTF), batch conversion, or Blender CLI automation.

## Before you start
- **Blender location on this machine**: `D:\建模\Blender Foundation\Blender 5.1\blender.exe` (user migrated off C: drive — do NOT assume `C:\Program Files\`)
- User prefers software on D: drive; don't install to C: unless forced
- Blender can be driven headless with `blender --background --python-expr "..."` for verification without opening the GUI

## Diagnostic workflow

### Step 1: Inspect the asset directory
Run `file` on the target and `ls -lh` to see what's actually present:
```
file <path>
ls -lh <path>/
```
OBJ projects often come with companion files: `.mtl` (materials), `.png`/`.jpg` (textures), `.dae` (Collada). The directory may contain multiple formats of the same model.

### Step 2: For OBJ — check the mtllib reference
```
head -5 <path>/model.obj
```
The OBJ header should contain `mtllib <filename>.mtl`. **Common failure**: the referenced MTL name doesn't match what's on disk (e.g., OBJ says `mtllib Metro Man.mtl` but the file is called `成都超人.mtl`). Fix with `patch`.

### Step 3: For MTL — audit texture paths
```
cat <path>/model.mtl
```
Look at every `map_Kd` line. **Two common failures**:
1. **Absolute paths pointing to the original author's machine** (e.g., `C:/Users/patri/Music/tex_35out.png`). Replace with relative paths to the actual texture files in the directory.
2. **Texture filenames don't match** what's on disk. Check the directory listing and map the right texture to each material group.

To determine which texture maps to which material, check `grep "^usemtl" model.obj` — it shows material usage order.

### Step 4: For DAE — check embedded texture paths
```
grep -i "<image>" model.dae | head -20
grep -i "init_from" model.dae | head -20
```
Collada files embed texture references inside `<library_images>`. Same absolute-path problem as MTL. Fix with `patch` on the DAE XML.

### Step 5: Verify with headless Blender import
```
"/d/建模/Blender Foundation/Blender 5.1/blender.exe" --background --python-expr "
import bpy
bpy.ops.wm.obj_import(filepath='<absolute/windows/path>/model.obj')
print(f'Objects: {len(bpy.data.objects)}')
print(f'Materials: {len(bpy.data.materials)}')
for i in bpy.data.images:
    print(f'  Image: {i.name} ({i.size[0]}x{i.size[1]})')
"
```
This confirms the import works and textures loaded before the user opens the GUI. For DAE: use `bpy.ops.wm.collada_import()` instead.

### Step 6: Set up PBR materials for imported FBX (especially Unreal Engine exports)

When importing an FBX that came from Unreal Engine (or similar PBR pipeline), materials come in blank — they need shader nodes wired manually. UE naming conventions:

| Suffix | Meaning | Blender target | Color Space |
|--------|---------|----------------|-------------|
| `_D` | Diffuse / Base Color | Principled BSDF → Base Color | sRGB |
| `_N` | Normal map | Normal Map node → BSDF Normal | Non-Color |
| `_FTM` | Combined mask (R=Roughness usually) | SeparateColor R → BSDF Roughness | Non-Color |
| `_RGID` | RGBA ID / blend mask | Load only (not wired) | Non-Color |
| `_HM` | Height Map | Load only (manual setup) | Non-Color |
| `_HET` | Height (eye/face) | Load only | Non-Color |
| `_EM` | Emissive | Load only | sRGB |
| `_FX` | Flow/effects map | Load only | Non-Color |

**Workflow**: write a Blender Python script that:
1. Imports the FBX with `bpy.ops.import_scene.fbx()`
2. Pre-loads all `.png` files from the model directory with `bpy.data.images.load()`
3. For each material slot, creates Principled BSDF + Texture Coordinate nodes, wires Diffuse to Base Color, Normal through a Normal Map node, and FTM R channel to Roughness
4. Saves as `.blend` in the same directory so texture paths resolve relatively

Prefer **saving `.blend` alongside the textures** — Blender resolves relative texture paths from the blend file location. See `references/ue-fbx-pbr-setup.py` for the full reference script.

### Step 7: Validate material setup

After running the setup script, verify with headless Blender — same pattern as Step 5 but with `bpy.ops.wm.open_mainfile()` instead of importing.

## Pitfalls

- **Windows paths in Blender Python**: use forward slashes (`C:/Users/...`) even on Windows. Backslashes fail silently.
- **MTL file must be in same directory as OBJ** — Blender resolves texture paths relative to the MTL's directory.
- **Chinese/Unicode filenames** are fine in OBJ/MTL on modern Blender (5.x), but some older tools (Noesis, 3ds Max export) produce ASCII-only references that need manual correction.
- **User prefers D: drive**: Blender is at `D:\建模\Blender Foundation\`, not `C:\Program Files\`. Don't assume C: paths.
- **Texture swapping**: if the body/head texture mapping is wrong, swap the `map_Kd` lines in the MTL — no need to re-import.

## References
- `references/obj-mtl-repair-example.md` — full transcript of the OBJ/MTL repair from this session
- `references/ue-fbx-pbr-setup.py` — reference script: import UE FBX into Blender and wire PBR materials from _D/_N/_FTM/_RGID textures
