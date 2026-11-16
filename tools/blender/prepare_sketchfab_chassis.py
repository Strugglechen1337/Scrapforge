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
    "bastion": {
        "out_dir": "bastion",
        "target_height": 2.08,
        "drop_meshes": ["Icosphere"],
        "max_tris": 75000,
        "flatten_armature": True,
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

    if cfg.get("flatten_armature"):
        deps = bpy.context.evaluated_depsgraph_get()
        baked = []
        for o in list(bpy.context.scene.objects):
            if o.type != "MESH":
                continue
            ev = o.evaluated_get(deps)
            mesh = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=deps)
            mesh.transform(o.matrix_world)
            clean = bpy.data.objects.new(o.name + "_clean", mesh)
            bpy.context.collection.objects.link(clean)
            baked.append(clean)
        for o in list(bpy.context.scene.objects):
            if o not in baked:
                bpy.data.objects.remove(o, do_unlink=True)
        pts = [v.co for m in baked for v in m.data.vertices]
        lo_x = min(p.x for p in pts); hi_x = max(p.x for p in pts)
        lo_y = min(p.y for p in pts); hi_y = max(p.y for p in pts)
        lo_z = min(p.z for p in pts); hi_z = max(p.z for p in pts)
        scale = cfg["target_height"] / max(hi_z - lo_z, 1e-4)
        cx = (lo_x + hi_x) * 0.5; cy = (lo_y + hi_y) * 0.5
        from mathutils import Matrix
        xf = Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((-cx, -cy, -lo_z)))
        for m in baked:
            m.data.transform(xf)
            m.data.update()
        bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
        arm = bpy.context.active_object
        arm.name = "BastionRig"
        eb = arm.data.edit_bones
        eb.remove(eb[0])
        def add_bone(bname, head, tail, parent=None, radius=0.45):
            b = eb.new(bname)
            b.head = head; b.tail = tail; b.envelope_distance = radius
            if parent: b.parent = parent
            return b
        root_b = add_bone("Root_01", (0, 0, 0.95), (0, 0, 1.55), None, 0.8)
        add_bone("Camera_08", (0, -0.2, 1.75), (0, -0.4, 1.85), root_b, 0.4)
        al = add_bone("Arm_L_02", (0.55, 0, 1.35), (0.75, 0, 1.05), root_b, 0.45)
        add_bone("Gun_L_04", (0.75, -0.35, 1.05), (0.75, -0.65, 1.05), al, 0.35)
        ar = add_bone("Arm_R_05", (-0.55, 0, 1.35), (-0.75, 0, 1.05), root_b, 0.45)
        add_bone("Gun_R_07", (-0.75, -0.35, 1.05), (-0.75, -0.65, 1.05), ar, 0.35)
        tl = add_bone("Top_Leg_L_09", (0.38, 0, 0.92), (0.42, 0, 0.48), root_b, 0.45)
        add_bone("Low_Leg_L_014", (0.42, 0, 0.48), (0.42, 0, 0.02), tl, 0.45)
        tr = add_bone("Top_Leg_R_023", (-0.38, 0, 0.92), (-0.42, 0, 0.48), root_b, 0.45)
        add_bone("Mid_Leg_R_00", (-0.42, 0, 0.48), (-0.42, 0, 0.02), tr, 0.45)
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        for m in baked: m.select_set(True)
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    else:
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        lo_x = min(p.x for p in pts); hi_x = max(p.x for p in pts)
        lo_y = min(p.y for p in pts); hi_y = max(p.y for p in pts)
        lo_z = min(p.z for p in pts); hi_z = max(p.z for p in pts)
        cx = (lo_x + hi_x) * 0.5; cy = (lo_y + hi_y) * 0.5
        height = max(hi_z - lo_z, 1e-4)
        scale = cfg["target_height"] / height
        roots = [o for o in bpy.context.scene.objects if o.parent is None]
        for r in roots:
            r.scale = (r.scale.x * scale, r.scale.y * scale, r.scale.z * scale)
            r.location.x -= cx * scale
            r.location.y -= cy * scale
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
