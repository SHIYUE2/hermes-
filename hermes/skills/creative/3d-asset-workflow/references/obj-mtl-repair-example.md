# OBJ/MTL Repair — Session Transcript

**Date:** 2026-06-14
**File:** `C:\Users\shiyue\Desktop\test_b\成都超人.obj`

## The problem
User tried to import the OBJ into Blender and it failed. No error message captured, but the file had two silent failures that would cause a blank or broken import.

## Directory contents
```
test_b/
├── 成都超人.dae          (408K) — Collada format, also present
├── 成都超人.mtl          (458B) — Material template library
├── 成都超人.obj          (244K) — Wavefront OBJ
├── 成都超人_by_Sofy_...zip (253K) — original distribution archive
├── 身体.png              (73K)  — body texture
└── 头.png                (17K)  — head texture
```

## Failure #1: mtllib name mismatch

OBJ header:
```
mtllib Metro Man.mtl    ← REFERENCES A FILE THAT DOESN'T EXIST
```

The actual MTL file on disk is `成都超人.mtl`. Blender couldn't find the material definition, so the import either failed or imported a material-less mesh.

**Fix:** `mtllib Metro Man.mtl` → `mtllib 成都超人.mtl`

## Failure #2: Absolute texture paths from another machine

MTL contents before fix:
```mtl
newmtl Material.001
...
map_Kd C:/Users/patri/Music/tex_35out.png    ← patri's machine, wrong filename

newmtl Material.002
...
map_Kd C:/Users/patri/Music/tex_34out.png    ← patri's machine, wrong filename
```

The original author (user `patri`) exported from their machine. The texture filenames (`tex_35out.png`, `tex_34out.png`) also didn't match what was in the directory (`身体.png`, `头.png`).

**Fix:**
- `map_Kd C:/Users/patri/Music/tex_35out.png` → `map_Kd 头.png`
- `map_Kd C:/Users/patri/Music/tex_34out.png` → `map_Kd 身体.png`

Material usage order from OBJ (`grep "^usemtl"`):
```
usemtl Material.002
usemtl Material.001
```

## Verification

Command:
```
"D:\建模\Blender Foundation\Blender 5.1\blender.exe" --background --python-expr "
import bpy
bpy.ops.wm.obj_import(filepath='C:/Users/shiyue/Desktop/test_b/成都超人.obj')
print(f'Objects: {len(bpy.data.objects)}')
print(f'Materials: {len(bpy.data.materials)}')
for i in bpy.data.images:
    print(f'  Image: {i.name} ({i.size[0]}x{i.size[1]})')
"
```

Output:
```
Objects: 5
Materials: 4
  Image: 头.png (128x128)
  Image: 身体.png (256x256)
```

All 5 objects imported, 4 materials resolved, both textures loaded at correct resolutions. 🎯
