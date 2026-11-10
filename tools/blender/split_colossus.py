"""Split the prepared static Colossus into rigid, pivoted parts for Godot.

The sculpt is one asymmetrical mesh, so faces are assigned spatially. The
original UVs and texture material are retained. Coordinates are Blender's
Z-up coordinates; the glTF exporter performs the conversion to Godot Y-up.
"""
import argparse
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


# Each pivot is at the anatomical joint in the original model's coordinates.
PARTS = {
    "torso": ((0, 0, 0), None),
    "head": ((0, -0.16, 0.38), "torso"),
    "shoulder_l": ((-0.45, 0, 0.54), "torso"),
    "upper_arm_l": ((-0.48, 0, 0.32), "shoulder_l"),
    "forearm_l": ((-0.59, 0, -0.05), "upper_arm_l"),
    "shoulder_r": ((0.45, 0, 0.54), "torso"),
    "upper_arm_r": ((0.50, 0, 0.32), "shoulder_r"),
    "forearm_r": ((0.55, -0.13, 0.10), "upper_arm_r"),
    "thigh_l": ((-0.26, 0, -0.10), "torso"),
    "shin_l": ((-0.34, 0, -0.50), "thigh_l"),
    "thigh_r": ((0.26, 0, -0.10), "torso"),
    "shin_r": ((0.34, 0, -0.50), "thigh_r"),
}


def part_for(p):
    x, y, z = p
    if z < -0.10 and abs(x) < 0.58:
        side = "l" if x < 0 else "r"
        return ("shin_" if z < -0.50 else "thigh_") + side
    if x < -0.43:
        return "shoulder_l" if z > 0.48 else ("upper_arm_l" if z > -0.05 else "forearm_l")
    if x > 0.43:
        return "shoulder_r" if z > 0.48 else ("upper_arm_r" if z > 0.25 else "forearm_r")
    if abs(x) < 0.27 and y < -0.13 and z > 0.38:
        return "head"
    return "torso"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.source))
    source = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    # Bake the imported object's world transform, keeping the original UVs.
    source.data.transform(source.matrix_world)
    source.matrix_world = Matrix.Identity(4)
    objects = {}
    for name, (pivot, _) in PARTS.items():
        bm = bmesh.new()
        bm.from_mesh(source.data)
        remove = [f for f in bm.faces if part_for(f.calc_center_median()) != name]
        bmesh.ops.delete(bm, geom=remove, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        if not bm.faces:
            raise RuntimeError("No faces assigned to " + name)
        for vertex in bm.verts:
            vertex.co -= Vector(pivot)
        mesh = bpy.data.meshes.new(name + "_mesh")
        bm.to_mesh(mesh)
        bm.free()
        for material in source.data.materials:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = pivot
        objects[name] = obj
        print("PART", name, len(mesh.polygons))
    # Preserve world-space pivots while building the transform hierarchy.
    bpy.context.view_layer.update()
    for name, (_, parent) in PARTS.items():
        if parent:
            obj = objects[name]
            world = obj.matrix_world.copy()
            obj.parent = objects[parent]
            obj.matrix_world = world
    # Export just our explicitly created parts, with no source hierarchy.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects.values():
        obj.select_set(True)
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.output), export_format="GLB", use_selection=True)


if __name__ == "__main__":
    main()
