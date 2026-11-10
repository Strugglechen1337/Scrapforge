"""Prepare unrigged Sketchfab enemies for shared MultiMesh rendering."""
import bpy, sys
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SOURCES=[('brute_spider','c4bca3a398344fa998eb404cc1d3d7a2',2.05),('ranged_spider','62d7805038744326baaaca74c6e99c2f',1.8)]
for name,uid,width in SOURCES:
 source=Path('D:/Temp/scrapforge-sketchfab/extracted')/uid
 out=ROOT/'assets/third_party/sketchfab'/name; out.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(source/'scene.gltf'))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 if name=='brute_spider':
  obj=meshes[0]; bpy.context.view_layer.objects.active=obj; obj.select_set(True)
  mod=obj.modifiers.new('Reduce to approximately 3000 triangles','DECIMATE'); mod.ratio=0.623
  bpy.ops.object.modifier_apply(modifier=mod.name)
 for obj in meshes:
  obj.data.transform(obj.matrix_world); obj.parent=None; obj.matrix_world.identity()
 points=[v.co.copy() for o in meshes for v in o.data.vertices]
 low=Vector(tuple(min(p[i] for p in points) for i in range(3))); high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z)); scale=width/max(high.x-low.x,high.y-low.y)
 for obj in meshes:
  for v in obj.data.vertices: v.co=(v.co-center)*scale
  # UV2 carries leg influence; the compact central shell remains still.
  uv=obj.data.uv_layers.new(name='LegMotion')
  for poly in obj.data.polygons:
   for li in poly.loop_indices:
    v=obj.data.vertices[obj.data.loops[li].vertex_index].co
    influence=max(0.0,min(1.0,(max(abs(v.x),abs(v.y))-(width*.20))/(width*.22))) if name=='brute_spider' else 0.0
    uv.data[li].uv=(influence,0.5)
 # Keep source details, recolour non-emissive areas gunmetal.
 for image in list(bpy.data.images):
  if 'baseColor' not in image.name: continue
  w,h=image.size; data=np.empty(w*h*4,dtype=np.float32); image.pixels.foreach_get(data); data=data.reshape(h,w,4); rgb=data[:,:,:3].copy()
  red=(rgb[:,:,0]>.15)&(rgb[:,:,0]>rgb[:,:,1]*1.5)&(rgb[:,:,0]>rgb[:,:,2]*1.4)
  lum=rgb[:,:,0]*.2126+rgb[:,:,1]*.7152+rgb[:,:,2]*.0722
  for c,f in enumerate((.80,.88,1.0)): data[:,:,c]=np.where(red,rgb[:,:,c],(.07+lum*.62)*f)
  image.pixels.foreach_set(data.ravel()); image.filepath_raw=str(Path('D:/DevCache/blender/temp')/(name+'_'+image.name)); image.file_format='PNG'; image.save()
  if image.packed_file: image.unpack(method='REMOVE')
  image.pack()
 for obj in bpy.context.selected_objects: obj.select_set(False)
 for obj in meshes: obj.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 if len(meshes)>1: bpy.ops.object.join()
 obj=meshes[0]; obj.data.calc_loop_triangles()
 print(name,'triangles',len(obj.data.loop_triangles),'bounds',tuple((high-low)*scale))
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
