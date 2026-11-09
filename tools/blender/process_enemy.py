"""Bake Shima Daisuke's Mech Spider walk to a shared VAT and static GLB.

Run Blender in background with --python tools/blender/process_enemy.py. Inputs are
read as data only. Blender 5.2.3; source path and output can be overridden after --.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('D:/Temp/scrapforge-sketchfab/extracted/70bcd7115d8643b6b647a2c8a8a92d5e')
OUT = ROOT / 'assets/third_party/sketchfab/mech_spider'
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if args:
    SOURCE = Path(args[0])
if len(args) > 1:
    OUT = Path(args[1])
OUT.mkdir(parents=True, exist_ok=True)
FRAMES = 32
WIDTH = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'scene.gltf'))
mesh_obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.data.polygons) > 1000)
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = bpy.data.actions['walk']
for track in rig.animation_data.nla_tracks:
    track.mute = True
start, end = rig.animation_data.action.frame_range
scene = bpy.context.scene

def snapshot(frame):
    scene.frame_set(int(frame), subframe=frame % 1)
    deps = bpy.context.evaluated_depsgraph_get()
    obj = mesh_obj.evaluated_get(deps)
    mesh = obj.to_mesh(preserve_all_data_layers=True, depsgraph=deps)
    coords = [obj.matrix_world @ v.co for v in mesh.vertices]
    return obj, mesh, coords

obj, evaluated, base = snapshot(start)
result = bpy.data.meshes.new_from_object(obj, preserve_all_data_layers=True, depsgraph=bpy.context.evaluated_depsgraph_get())
obj.to_mesh_clear()
assert len(result.vertices) == len(base)
result.calc_loop_triangles()
assert len(result.loop_triangles) <= 2500, len(result.loop_triangles)
mins = [min(v[i] for v in base) for i in range(3)]
maxs = [max(v[i] for v in base) for i in range(3)]
scale = 1.8 / max(maxs[0]-mins[0], maxs[1]-mins[1])
center = Vector(((mins[0]+maxs[0])/2, (mins[1]+maxs[1])/2, mins[2]))
for vert, co in zip(result.vertices, base):
    vert.co = (co - center) * scale
rows = math.ceil(len(base) / WIDTH)
height = rows * FRAMES
uv = result.uv_layers.new(name='VAT_index')
for poly in result.polygons:
    for loop_index in poly.loop_indices:
        vertex = result.loops[loop_index].vertex_index
        # glTF export flips V; PNG storage also starts at its top row.
        uv.data[loop_index].uv = ((vertex % WIDTH + 0.5) / WIDTH, 1.0 - (vertex // WIDTH + 0.5) / height)
result.uv_layers.active_index = 0
# Encode world-space deltas in the Godot/glTF coordinate system.
frames = []
max_delta = 0.0
for frame in range(FRAMES):
    ob, mesh, coords = snapshot(start + (end - start) * frame / FRAMES)
    assert len(coords) == len(base)
    delta = [(p - b) * scale for p, b in zip(coords, base)]
    max_delta = max(max_delta, max(abs(c) for p in delta for c in p))
    frames.append(delta)
    ob.to_mesh_clear()
max_delta = max(max_delta * 1.01, 0.001)
import numpy as np
pixels = np.zeros((height, WIDTH, 4), dtype=np.float32)
pixels[:,:,3] = 1.0
for f, delta in enumerate(frames):
    for i, v in enumerate(delta):
        row = f * rows + i // WIDTH
        pixels[height - 1 - row, i % WIDTH, :3] = (0.5 + v.x/(2*max_delta), 0.5 + v.z/(2*max_delta), 0.5 - v.y/(2*max_delta))
image = bpy.data.images.new('walk_vat', width=WIDTH, height=height, alpha=True)
image.colorspace_settings.name = 'Non-Color'
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw = str(OUT / 'walk_vat.png')
image.file_format = 'PNG'
image.save()
# Preserve the source's dark details while making the armor neutral gunmetal.
source = bpy.data.images.load(str(SOURCE / 'textures/lambert3_baseColor.png'), check_existing=True)
if tuple(source.size) != (1024, 1024):
    source.scale(1024, 1024)
w, h = source.size
colors = np.empty(w*h*4, dtype=np.float32)
source.pixels.foreach_get(colors)
colors = colors.reshape((h,w,4))
rgb = colors[:,:,:3].copy()
red = (rgb[:,:,0] > rgb[:,:,1] * 1.5) & (rgb[:,:,0] > rgb[:,:,2] * 1.25) & (rgb[:,:,0] > 0.08)
# The large red atlas patch is armor, not an optic.
red[int(h*0.24):int(h*0.56), int(w*0.74):] = False
luma = rgb[:,:,0]*0.2126 + rgb[:,:,1]*0.7152 + rgb[:,:,2]*0.0722
for channel, factor in enumerate((0.72, 0.78, 0.84)):
    colors[:,:,channel] = np.where(red, rgb[:,:,channel], luma * factor)
source.pixels.foreach_set(colors.ravel())
source.filepath_raw = str(OUT / 'gunmetal.png')
source.file_format = 'PNG'
source.save()
mat = bpy.data.materials.new('Gunmetal and red optics')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = source
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Metallic'].default_value = 0.6
bsdf.inputs['Roughness'].default_value = 0.55
result.materials.clear()
result.materials.append(mat)
for p in result.polygons:
    p.material_index = 0
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
new = bpy.data.objects.new('MechSpider', result)
bpy.context.collection.objects.link(new)
bpy.context.view_layer.objects.active = new
new.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'mech_spider.glb'), export_format='GLB', use_selection=True, export_animations=False)
(OUT / 'vat_metadata.txt').write_text(f'{max_delta:.9f}\n{rows}\n{height}\n{(end-start)/scene.render.fps:.9f}\n', encoding='utf-8')
print('VAT', len(base), len(result.loop_triangles), WIDTH, height, rows, max_delta, 'duration', (end-start)/scene.render.fps)
