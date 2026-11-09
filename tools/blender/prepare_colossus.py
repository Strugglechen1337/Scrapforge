"""Prepare the CC-BY Colossus source; run with Blender in background mode.

The input is untrusted model data, never Python code.  This is an intermediate
static mesh, not a replacement for the animated in-game chassis.
"""
import argparse
import os
import sys

import bpy


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--source", required=True, help="Path to extracted scene.gltf")
    args.add_argument("--output", required=True, help="Output .glb path")
    options = args.parse_args(sys.argv[sys.argv.index("--") + 1:])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(options.source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError("Expected exactly one source mesh, got %d" % len(meshes))
    mesh = meshes[0]
    mesh.data.calc_loop_triangles()
    before = len(mesh.data.loop_triangles)
    modifier = mesh.modifiers.new("Triangle budget", "DECIMATE")
    modifier.ratio = min(1.0, 28000.0 / before)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh.data.calc_loop_triangles()
    after = len(mesh.data.loop_triangles)
    if not 25000 <= after <= 30000:
        raise RuntimeError("Unexpected triangle count: %d" % after)
    for image in bpy.data.images:
        if image.source == "FILE" and max(image.size) > 2048:
            scale = 2048.0 / max(image.size)
            image.scale(max(1, round(image.size[0] * scale)), max(1, round(image.size[1] * scale)))
    os.makedirs(os.path.dirname(os.path.abspath(options.output)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(options.output), export_format="GLB")
    print("COLOSSUS_TRIANGLES %d -> %d" % (before, after))


if __name__ == "__main__":
    main()
