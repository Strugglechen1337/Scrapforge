"""Prepare Sketchfab scenery props (CC BY 4.0) for Scrapforge.

Run with Blender in background mode:
    blender --background --factory-startup --python tools/blender/process_props.py -- <extracted_dir> <out_dir>

For every prop listed in PROPS the script imports the glTF, drops animations,
joins all meshes into one object, puts the origin at the bottom centre, scales
the longest horizontal side to the target size in metres, limits textures to
1024 px and exports a single GLB with embedded textures.
"""
import os
import sys

import bpy
from mathutils import Vector

# uid -> (output name, target length of the longest horizontal side in metres)
PROPS = {
    "042201dac61041fabb88f483368daa3f": ("crate_basic", 1.3),
    "8eda583592f34498a350f6cc5a650042": ("crate_scifi", 1.6),
    "ac36898521304e51a8e305aa602f1f5b": ("crate_cargo", 2.2),
    "c50d7a37b9ec483f8abfdbecd162aa35": ("crate_v2", 1.4),
    "481f7499eaf64b8792bffc59a8b4e05a": ("barrel", 0.9),
    "8a19b0e0e22c4b9ba057eab497742f61": ("container", 1.7),  # tall supply canister, not a shipping container
}
MAX_TEXTURE = 1024


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def find_gltf(folder):
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if name.lower().endswith((".gltf", ".glb")):
                return os.path.join(root, name)
    raise FileNotFoundError(folder)


def process(uid, name, target, src_root, out_dir):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=find_gltf(os.path.join(src_root, uid)))
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
        obj.animation_data_clear()
    bpy.context.view_layer.objects.active = meshes[0]
    # Bake parent transforms (glTF imports often nest scaled empties).
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for other in [o for o in bpy.context.scene.objects if o != obj]:
        bpy.data.objects.remove(other, do_unlink=True)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    size = hi - lo
    scale = target / max(size.x, size.y, 1e-6)
    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co = (obj.matrix_world @ v.co - pivot) * scale
    obj.matrix_world.identity()
    obj.name = name
    for image in bpy.data.images:
        if image.size[0] > MAX_TEXTURE or image.size[1] > MAX_TEXTURE:
            factor = MAX_TEXTURE / max(image.size[0], image.size[1])
            image.scale(max(1, int(image.size[0] * factor)), max(1, int(image.size[1] * factor)))
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=85)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"PROP {name}: {tris} triangles, size {tuple(round(s * scale, 2) for s in size)} -> {path}")


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src_root, out_dir = args[0], args[1]
    for uid, (name, target) in PROPS.items():
        process(uid, name, target, src_root, out_dir)


main()
