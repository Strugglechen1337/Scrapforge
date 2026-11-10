"""Prepare leoxx300's SCI FI SPIDER ROBOT for Godot; source is data only."""
import bpy, sys
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('D:/Temp/scrapforge-sketchfab/extracted/b562b06a357d4588a9135eb6e82d3f78')
OUT = ROOT / 'assets/third_party/sketchfab/boss_spider'
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if args: SOURCE = Path(args[0])
if len(args)>1: OUT = Path(args[1])
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'scene.gltf'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
scale = 5.6 / max(hi.x-lo.x, hi.y-lo.y)
# Four independently movable legs, grouped by source object names.
groups = [(['Cube.005','Cube.006','Cube.007','Cube.008','Cylinder.009'],(-5.39,-19.34,3.21)), (['Cube.001','Cube.002','Cube.003','Cube.009','Cylinder.010'],(-5.39,-9.41,3.21)), (['Cube.010','Cube.011','Cube.012','Cube.013','Cylinder.011'],(-12.92,-19.34,3.21)), (['Cube.014','Cube.015','Cube.016','Cylinder.012'],(-12.92,-9.41,3.21))]
root = bpy.data.objects.new('BossSpider', None); bpy.context.collection.objects.link(root)
pivots=[]
for i,(_,p) in enumerate(groups):
 pivot=bpy.data.objects.new('LegPivot%d'%i,None); bpy.context.collection.objects.link(pivot); pivot.parent=root; pivot.location=(Vector(p)-center)*scale; pivots.append(pivot)
for o in meshes:
 world=o.matrix_world.copy(); source_parent=o.parent.name if o.parent else ''
 idx=next((i for i,(names,_) in enumerate(groups) if source_parent in names),-1)
 pivot=pivots[idx] if idx>=0 else root
 offset=pivot.location.copy() if idx>=0 else Vector((0,0,0))
 for v in o.data.vertices: v.co=(world @ v.co-center)*scale-offset
 o.parent=pivot; o.matrix_parent_inverse.identity(); o.location=(0,0,0); o.rotation_euler=(0,0,0); o.scale=(1,1,1)
# Limit every source texture, including normal and metallic maps, before embedding.
for image in list(bpy.data.images):
 if image.source == "FILE" and max(image.size) > 1024:
  image.scale(1024, 1024)
  image.filepath_raw = str(Path("D:/DevCache/blender/temp") / image.name)
  image.file_format = "PNG"
  image.save()
  if image.packed_file: image.unpack(method="REMOVE")
  image.pack()
# Recolour yellow armor in base-color textures while preserving dark details and orange markings.
for image in list(bpy.data.images):
 if 'baseColor' not in image.name: continue
 if max(image.size)>2048: image.scale(2048,2048)
 w,h=image.size; data=np.empty(w*h*4,dtype=np.float32); image.pixels.foreach_get(data); data=data.reshape(h,w,4)
 rgb=data[:,:,:3].copy(); yellow=(rgb[:,:,0] > .12) & (rgb[:,:,1] > .08) & (rgb[:,:,0] > rgb[:,:,2]*1.3) & (rgb[:,:,1] > rgb[:,:,2]*1.25) & (rgb[:,:,1] > rgb[:,:,0]*.55)
 lum=rgb[:,:,0]*.2126+rgb[:,:,1]*.7152+rgb[:,:,2]*.0722
 for c,f in enumerate((.58,.64,.70)): data[:,:,c]=np.where(yellow,lum*f,rgb[:,:,c])
 image.pixels.foreach_set(data.ravel()); image.filepath_raw=str(Path('D:/DevCache/blender/temp')/image.name); image.file_format='PNG'; image.save();
 if image.packed_file: image.unpack(method="REMOVE")
 image.pack()
# Remove source hierarchy after extracting the mesh transforms.
for o in list(bpy.data.objects):
 if o not in meshes and o not in pivots and o != root: bpy.data.objects.remove(o,do_unlink=True)
for o in bpy.context.selected_objects: o.select_set(False)
for o in [root]+pivots+meshes: o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'boss_spider.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('BOSS',sum(len(o.data.polygons) for o in meshes),'meshes',len(meshes),'dimensions',tuple((hi-lo)*scale))
