"""Prepare CC-BY Sketchfab modules from untrusted glTF data, using Blender.

Run with --source-root and --output-root; source files are imported only.
"""
import argparse, os, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ASSETS = {
    'minigun': ('cca7f67173ee4cd9b0ce3d3329ea19a8', True, False),
    'laser': ('4826a9e0a04c492baffd54bed340ad4c', True, False),
    'turret': ('fe59a306020d4492b50eea6ec47226a3', False, True),
    'rocket': ('b5d4095b0f824fbf99eb3b060ed9372c', False, True),
    'drone': ('3dbf07385d1b471a96dce6de6cba97d6', False, False),
    'shield': ('69bde44d6abe41f58240687a5f25a441', False, False),
}

def prepare(name, uid, sideways, trim_base, source, out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(source, uid, 'scene.gltf'))
    deps = bpy.context.evaluated_depsgraph_get()
    meshes = []
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH': continue
        evaluated = obj.evaluated_get(deps)
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
        mesh.transform(obj.matrix_world)
        clean = bpy.data.objects.new('part', mesh)
        bpy.context.collection.objects.link(clean)
        meshes.append(clean)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = meshes[0]
    if sideways: obj.data.transform(Matrix.Rotation(1.57079632679, 4, 'Z'))
    points = [v.co for v in obj.data.vertices]
    lo = Vector([min(v[i] for v in points) for i in range(3)])
    hi = Vector([max(v[i] for v in points) for i in range(3)])
    if trim_base:
        bm = bmesh.new(); bm.from_mesh(obj.data)
        threshold = lo.z + (hi.z - lo.z) * (0.32 if name == 'turret' else 0.30)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < threshold], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(obj.data); bm.free()
        points = [v.co for v in obj.data.vertices]
        lo = Vector([min(v[i] for v in points) for i in range(3)])
        hi = Vector([max(v[i] for v in points) for i in range(3)])
    center = (lo + hi) / 2
    scale = 1.0 / max(hi - lo)
    obj.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(-center))
    obj.name = name
    for img in bpy.data.images:
        if img.source == 'FILE' and max(img.size) > 1024:
            factor = 1024 / max(img.size)
            img.scale(max(1, round(img.size[0]*factor)), max(1, round(img.size[1]*factor)))
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    os.makedirs(out, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name+'.glb'), export_format='GLB', use_selection=True)
    print('PREPARED', name, len(obj.data.polygons), 'bounds', lo, hi)

parser=argparse.ArgumentParser()
parser.add_argument('--source-root', required=True); parser.add_argument('--output-root', required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
for name, (uid, sideways, trim) in ASSETS.items(): prepare(name, uid, sideways, trim, args.source_root, args.output_root)
