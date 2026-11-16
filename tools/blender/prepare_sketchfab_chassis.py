"""Prepare CC-BY Sketchfab chassis models (Vanguard, Bastion) for Scrapforge using Blender.

Run:
  blender -b -P tools/blender/prepare_sketchfab_chassis.py -- --source-root D:/Temp/scrapforge-sketchfab --output-root assets/third_party/sketchfab --asset vanguard
"""
import argparse
import os
import sys

import bpy
from mathutils import Vector

CONFIGS = {
    "vanguard": {
        "out_dir": "vanguard",
        "target_height": 1.88,
        "drop_meshes": ["Icosphere"],
        "max_tris": 75000,
    },
}


def prepare_chassis(name: str, cfg: dict, source_root: str, output_root: str) -> None:
    src_path = os.path.join(source_root, name, f"{name}.glb")
    if not os.path.exists(src_path):
        raise FileNotFoundError(src_path)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path)

    for drop_name in cfg.get("drop_meshes", []):
        obj = bpy.data.objects.get(drop_name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo_z = min(p.z for p in pts)
    hi_z = max(p.z for p in pts)
    height = max(hi_z - lo_z, 1e-4)
    scale = cfg["target_height"] / height

    roots = [o for o in bpy.context.scene.objects if o.parent is None]
    for r in roots:
        r.scale = (r.scale.x * scale, r.scale.y * scale, r.scale.z * scale)
        r.location.z -= lo_z * scale

    for img in bpy.data.images:
        if max(img.size) > 2048:
            factor = 2048.0 / float(max(img.size))
            img.scale(
                max(1, round(img.size[0] * factor)),
                max(1, round(img.size[1] * factor)),
            )

    out_dir = os.path.join(output_root, cfg["out_dir"])
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB")
    print(f"PREPARED CHASSIS {name}: height {height:.2f} -> {cfg['target_height']:.2f}, out={out_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--asset", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
    if args.asset not in CONFIGS:
        raise ValueError(f"Unknown chassis {args.asset}")
    prepare_chassis(args.asset, CONFIGS[args.asset], args.source_root, args.output_root)


if __name__ == "__main__":
    main()
