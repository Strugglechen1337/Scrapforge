"""Prepare Poly Haven CC0 boundary and scrap models for Scrapforge.

Run with Blender in background mode:
    blender --background --factory-startup --python tools/blender/process_polyhaven.py -- <polyhaven_dir> <out_dir>
"""
import os
import sys

import bpy
from mathutils import Vector

# Re-use weathering helpers from process_props.py in the same folder.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_props import weather_materials


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_selected(meshes, out_path, name, target_w=None, target_h=None, target_max=None,
                    max_tex=1024, image_format="JPEG", max_val=0.42):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for other in [o for o in bpy.context.scene.objects if o != obj]:
        bpy.data.objects.remove(other, do_unlink=True)

    # Remove unused materials and images before processing textures.
    used_mats = set(obj.data.materials)
    for m in list(bpy.data.materials):
        if m not in used_mats:
            bpy.data.materials.remove(m)

    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    size = hi - lo
    sx = sy = sz = 1.0
    if target_w is not None and target_h is not None:
        sx = sy = target_w / max(size.x, 1e-6)
        sz = target_h / max(size.z, 1e-6)
    elif target_max is not None:
        s = target_max / max(size.x, size.y, size.z, 1e-6)
        sx = sy = sz = s

    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co - pivot
        v.co = Vector((p.x * sx, p.y * sy, p.z * sz))
    obj.matrix_world.identity()
    obj.name = name

    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > 5000:
        if obj.data.shape_keys is not None:
            obj.shape_key_clear()
        mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
        mod.ratio = 4500.0 / float(tris)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    for image in bpy.data.images:
        if image.size[0] > max_tex or image.size[1] > max_tex:
            factor = max_tex / max(image.size[0], image.size[1])
            image.scale(max(1, int(image.size[0] * factor)), max(1, int(image.size[1] * factor)))

    weather_materials(name, max_val=max_val)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=False,
                              export_image_format=image_format, export_jpeg_quality=85)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"POLYHAVEN {name}: {tris} tris, size ({size.x*sx:.2f}, {size.y*sy:.2f}, {size.z*sz:.2f}) -> {out_path}")


def process_single(src_gltf, out_path, name, target_max, max_tex=512):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    export_selected(meshes, out_path, name, target_max=target_max, max_tex=max_tex, image_format="JPEG")


def process_fence(src_gltf, out_dir):
    # Fence panel (double section, ~1.9m wide x 1.55m tall so it stays low toward the camera).
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name == "modular_chainlink_fence_double"]
    export_selected(meshes, os.path.join(out_dir, "modular_chainlink_fence", "fence_panel.glb"),
                    "fence_panel", target_w=2.0, target_h=1.55, max_tex=512, image_format="AUTO", max_val=0.58)

    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name == "modular_chainlink_fence_post"]
    export_selected(meshes, os.path.join(out_dir, "modular_chainlink_fence", "fence_post.glb"),
                    "fence_post", target_w=0.16, target_h=1.65, max_tex=512, image_format="JPEG")


def process_facade(src_gltf, out_dir):
    # Solid 3m x 3m industrial wall panel
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name == "wall_standard_standard_01"]
    export_selected(meshes, os.path.join(out_dir, "modular_factory_facade", "wall_panel.glb"),
                    "wall_panel", target_w=3.0, target_h=3.2, max_tex=1024, image_format="JPEG")

    # Structural wall pier / column
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name == "wall_pier_standard_01"]
    export_selected(meshes, os.path.join(out_dir, "modular_factory_facade", "wall_pier.glb"),
                    "wall_pier", target_w=0.36, target_h=3.4, max_tex=512, image_format="JPEG")

    # 6m wide industrial garage bay wall + shutter door
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=src_gltf)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name in ("wall_door_garage_door_01", "door_garage_door_01")]
    export_selected(meshes, os.path.join(out_dir, "modular_factory_facade", "wall_bay.glb"),
                    "wall_bay", target_w=6.0, target_h=3.2, max_tex=1024, image_format="JPEG")


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src_dir, out_dir = args[0], args[1]
    process_fence(os.path.join(src_dir, "modular_chainlink_fence", "modular_chainlink_fence_1k.gltf"), out_dir)
    process_facade(os.path.join(src_dir, "modular_factory_facade", "modular_factory_facade_1k.gltf"), out_dir)
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.join(src_dir, "concrete_road_barrier_02", "concrete_road_barrier_02_1k.gltf"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    export_selected(meshes, os.path.join(out_dir, "concrete_road_barrier_02", "concrete_barrier.glb"),
                    "concrete_barrier", target_w=2.2, target_h=0.95, max_tex=512, image_format="JPEG")
    process_single(os.path.join(src_dir, "old_tyre", "old_tyre_1k.gltf"),
                   os.path.join(out_dir, "old_tyre", "old_tyre.glb"),
                   "old_tyre", target_max=0.95, max_tex=512)
    process_single(os.path.join(src_dir, "rusted_wheel_rim_01", "rusted_wheel_rim_01_1k.gltf"),
                   os.path.join(out_dir, "rusted_wheel_rim_01", "rusted_wheel_rim.glb"),
                   "rusted_wheel_rim", target_max=0.75, max_tex=512)
    process_single(os.path.join(src_dir, "old_military_compressor", "old_military_compressor_1k.gltf"),
                   os.path.join(out_dir, "old_military_compressor", "old_compressor.glb"),
                   "old_compressor", target_max=2.1, max_tex=1024)


main()
