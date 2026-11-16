"""Prepare CC-BY Sketchfab module assets for Scrapforge using Blender.

Run:
  blender -b -P tools/blender/prepare_sketchfab_modules.py -- --source-root <dir> --output-root <dir> --asset saw
"""
import argparse
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

CONFIGS = {
    "saw": {
        "target_size": 0.62,
        "max_tris": 14000,
        "rot_deg": (90.0, 0.0, 0.0),
    },
    "radar": {
        "target_size": 0.44,
        "max_tris": 14000,
        "rot_deg": (0.0, 0.0, 0.0),
    },
    "sensor": {
        "target_size": 0.36,
        "max_tris": 14000,
        "rot_deg": (0.0, 0.0, 0.0),
        "include_meshes": ["Camera2_Unreal_Camera2_0", "Camera2_Unreal_Glass_0"],
    },
    "thruster": {
        "target_size": 0.44,
        "max_tris": 12000,
        "rot_deg": (0.0, 90.0, 0.0),
    },
    "rocket": {
        "target_size": 0.70,
        "max_tris": 12000,
        "rot_deg": (0.0, 0.0, 0.0),
        "trim_z_frac": 0.28,
    },
}


def prepare_asset(name: str, cfg: dict, source_root: str, output_root: str) -> None:
    src_path = os.path.join(source_root, name, f"{name}.glb")
    if not os.path.exists(src_path):
        raise FileNotFoundError(src_path)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path)

    deps = bpy.context.evaluated_depsgraph_get()
    meshes = []
    include_names = cfg.get("include_meshes")
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        if include_names and obj.name not in include_names:
            continue
        evaluated = obj.evaluated_get(deps)
        mesh = bpy.data.meshes.new_from_object(
            evaluated, preserve_all_data_layers=True, depsgraph=deps
        )
        mesh.transform(obj.matrix_world)
        clean = bpy.data.objects.new(obj.name + "_clean", mesh)
        bpy.context.collection.objects.link(clean)
        meshes.append(clean)

    if not meshes:
        raise RuntimeError(f"No meshes selected for {name}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name

    rx, ry, rz = cfg.get("rot_deg", (0.0, 0.0, 0.0))
    if rx or ry or rz:
        import math
        rot = (
            Matrix.Rotation(math.radians(rz), 4, "Z")
            @ Matrix.Rotation(math.radians(ry), 4, "Y")
            @ Matrix.Rotation(math.radians(rx), 4, "X")
        )
        obj.data.transform(rot)

    if cfg.get("trim_z_frac", 0.0) > 0.0:
        pts = [v.co for v in obj.data.vertices]
        lo_z = min(p.z for p in pts)
        hi_z = max(p.z for p in pts)
        threshold = lo_z + (hi_z - lo_z) * cfg["trim_z_frac"]
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.delete(
            bm,
            geom=[f for f in bm.faces if f.calc_center_median().z < threshold],
            context="FACES",
        )
        bmesh.ops.delete(
            bm,
            geom=[v for v in bm.verts if not v.link_faces],
            context="VERTS",
        )
        bm.to_mesh(obj.data)
        bm.free()

    obj.data.calc_loop_triangles()
    tris_before = len(obj.data.loop_triangles)
    max_tris = cfg.get("max_tris", 14000)
    if tris_before > max_tris:
        mod = obj.modifiers.new("DecimateBudget", "DECIMATE")
        mod.ratio = max(0.05, min(1.0, float(max_tris) / float(tris_before)))
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    pts = [v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in pts) for i in range(3)])
    hi = Vector([max(v[i] for v in pts) for i in range(3)])
    center = (lo + hi) * 0.5
    max_dim = max(hi - lo)
    scale = cfg["target_size"] / max(max_dim, 1e-5)
    obj.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(-center))

    for img in bpy.data.images:
        if max(img.size) > 1024:
            factor = 1024.0 / float(max(img.size))
            img.scale(
                max(1, round(img.size[0] * factor)),
                max(1, round(img.size[1] * factor)),
            )

    obj.data.calc_loop_triangles()
    tris_after = len(obj.data.loop_triangles)
    os.makedirs(output_root, exist_ok=True)
    out_path = os.path.join(output_root, f"{name}.glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLB", use_selection=True
    )
    print(f"PREPARED {name}: tris {tris_before} -> {tris_after}, out={out_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--asset", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
    if args.asset not in CONFIGS:
        raise ValueError(f"Unknown asset {args.asset}")
    prepare_asset(args.asset, CONFIGS[args.asset], args.source_root, args.output_root)


if __name__ == "__main__":
    main()
