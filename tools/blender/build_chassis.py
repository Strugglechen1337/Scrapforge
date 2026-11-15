"""Build distinct beveled, UV-mapped 3D mech chassis (.glb) for Vanguard and Bastion.

Run with Blender 5.2.3:
  blender --background --factory-startup --python tools/blender/build_chassis.py
"""
import math
import os
import bmesh
import bpy
from mathutils import Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models", "chassis")
TEX_DIR = os.path.join(ROOT, "assets", "third_party", "ambientcg", "MetalPlates001")


def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def make_pbr_mat(name, base_tint=(0.65, 0.65, 0.65, 1.0)):
	mat = bpy.data.materials.new(name=name)
	mat.use_nodes = True
	nt = mat.node_tree
	bsdf = nt.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = base_tint
	bsdf.inputs["Metallic"].default_value = 0.45
	bsdf.inputs["Roughness"].default_value = 0.55

	col_path = os.path.join(TEX_DIR, "MetalPlates001_1K-JPG_Color.jpg")
	nrm_path = os.path.join(TEX_DIR, "MetalPlates001_1K-JPG_NormalGL.jpg")
	rgh_path = os.path.join(TEX_DIR, "MetalPlates001_1K-JPG_Roughness.jpg")

	if os.path.exists(col_path):
		tex_c = nt.nodes.new("ShaderNodeTexImage")
		tex_c.image = bpy.data.images.load(col_path)
		nt.links.new(tex_c.outputs["Color"], bsdf.inputs["Base Color"])
	if os.path.exists(rgh_path):
		tex_r = nt.nodes.new("ShaderNodeTexImage")
		tex_r.image = bpy.data.images.load(rgh_path)
		tex_r.image.colorspace_settings.name = "Non-Color"
		nt.links.new(tex_r.outputs["Color"], bsdf.inputs["Roughness"])
	if os.path.exists(nrm_path):
		tex_n = nt.nodes.new("ShaderNodeTexImage")
		tex_n.image = bpy.data.images.load(nrm_path)
		tex_n.image.colorspace_settings.name = "Non-Color"
		nmap = nt.nodes.new("ShaderNodeNormalMap")
		nt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
		nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
	return mat


def add_box(bm, size, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.015, taper_x=1.0, taper_y=1.0):
	ret = bmesh.ops.create_cube(bm, size=1.0)
	verts = ret["verts"]
	for v in verts:
		if v.co.z > 0:
			v.co.x *= taper_x
			v.co.y *= taper_y
	mat_t = (
		Matrix.Translation(center)
		@ Matrix.Rotation(rot[2], 4, "Z")
		@ Matrix.Rotation(rot[1], 4, "Y")
		@ Matrix.Rotation(rot[0], 4, "X")
		@ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
	)
	bmesh.ops.transform(bm, matrix=mat_t, verts=verts)
	edges = list({e for v in verts for e in v.link_edges})
	if bevel > 0:
		bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)


def add_cyl(bm, r1, r2, depth, segs=14, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.008):
	ret = bmesh.ops.create_cone(
		bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth
	)
	verts = ret["verts"]
	mat_t = (
		Matrix.Translation(center)
		@ Matrix.Rotation(rot[2], 4, "Z")
		@ Matrix.Rotation(rot[1], 4, "Y")
		@ Matrix.Rotation(rot[0], 4, "X")
	)
	bmesh.ops.transform(bm, matrix=mat_t, verts=verts)
	edges = list({e for v in verts for e in v.link_edges})
	if bevel > 0:
		bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)


def finish_part(name, bm, mat, loc=(0, 0, 0), parent=None):
	mesh = bpy.data.meshes.new(name)
	bm.normal_update()
	uv_layer = bm.loops.layers.uv.verify()
	for f in bm.faces:
		n = f.normal
		ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
		for loop in f.loops:
			co = loop.vert.co
			if az >= ax and az >= ay:
				loop[uv_layer].uv = (co.x * 0.65 + 0.5, co.y * 0.65 + 0.5)
			elif ax >= ay:
				loop[uv_layer].uv = (co.y * 0.65 + 0.5, co.z * 0.65 + 0.5)
			else:
				loop[uv_layer].uv = (co.x * 0.65 + 0.5, co.z * 0.65 + 0.5)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	obj.location = loc
	if parent:
		obj.parent = parent
	obj.data.materials.append(mat)
	bpy.context.collection.objects.link(obj)
	return obj


def build_vanguard():
	reset_scene()
	mat = make_pbr_mat("mat_vanguard")

	# Torso: sleek angular forward-swept wedge + twin jump-jet pods
	bm = bmesh.new()
	add_box(bm, (0.58, 0.56, 0.66), (0, 0.02, 0.14), bevel=0.024, taper_x=1.18, taper_y=0.82)
	add_box(bm, (0.44, 0.34, 0.28), (0, -0.22, 0.22), rot=(0.25, 0, 0), bevel=0.018, taper_x=0.85)
	add_box(bm, (0.38, 0.36, 0.24), (0, 0.0, -0.22), bevel=0.016)
	# Twin swept-back thruster packs
	for s in (-1, 1):
		add_box(bm, (0.18, 0.28, 0.48), (s * 0.22, 0.30, 0.20), rot=(-0.28, s * 0.10, 0), bevel=0.014)
		add_cyl(bm, 0.075, 0.055, 0.16, center=(s * 0.22, 0.38, -0.02), rot=(-0.32, 0, 0))
	torso = finish_part("torso", bm, mat, (0, 0, 0))

	# Head: narrow angular recon cowl + sensor fin
	bm = bmesh.new()
	add_box(bm, (0.28, 0.36, 0.24), (0, -0.02, 0.06), rot=(0.12, 0, 0), bevel=0.016, taper_x=0.78, taper_y=0.72)
	add_box(bm, (0.06, 0.28, 0.14), (0, 0.04, 0.20), rot=(-0.18, 0, 0), bevel=0.008)
	finish_part("head", bm, mat, (0.0, -0.14, 0.44), torso)

	# Shoulders, Upper Arms, Forearms (slim, swept-back wing pauldrons)
	for side, s in (("l", -1), ("r", 1)):
		bm = bmesh.new()
		add_box(bm, (0.28, 0.42, 0.24), (s * 0.04, 0.04, 0.04), rot=(-0.15, s * -0.22, 0), bevel=0.016, taper_x=0.75)
		add_box(bm, (0.14, 0.34, 0.16), (s * 0.12, 0.12, 0.14), rot=(-0.22, s * -0.30, 0), bevel=0.010)
		sh = finish_part(f"shoulder_{side}", bm, mat, (s * 0.38, 0.0, 0.48), torso)

		bm = bmesh.new()
		add_cyl(bm, 0.09, 0.08, 0.16, center=(0, 0, 0), rot=(0, math.pi * 0.5, 0))
		add_box(bm, (0.16, 0.18, 0.32), (0, 0, -0.16), bevel=0.012)
		ua = finish_part(f"upper_arm_{side}", bm, mat, (s * 0.04, 0.0, -0.18), sh)

		bm = bmesh.new()
		add_box(bm, (0.18, 0.34, 0.22), (0, -0.10, -0.06), rot=(0.18, 0, 0), bevel=0.014, taper_x=0.82)
		add_box(bm, (0.10, 0.26, 0.08), (s * 0.08, -0.14, 0.02), bevel=0.008)
		finish_part(f"forearm_{side}", bm, mat, (s * 0.04, -0.04, -0.28), ua)

	# Thighs & Shins (athletic digitigrade silhouette)
	for side, s in (("l", -1), ("r", 1)):
		bm = bmesh.new()
		add_cyl(bm, 0.11, 0.11, 0.18, center=(0, 0, 0), rot=(0, math.pi * 0.5, 0))
		add_box(bm, (0.22, 0.26, 0.44), (0, -0.04, -0.22), rot=(0.22, 0, 0), bevel=0.016, taper_x=0.85)
		th = finish_part(f"thigh_{side}", bm, mat, (s * 0.22, 0.0, -0.14), torso)

		bm = bmesh.new()
		add_box(bm, (0.18, 0.22, 0.44), (0, 0.04, -0.20), rot=(-0.22, 0, 0), bevel=0.014, taper_x=0.80)
		add_box(bm, (0.22, 0.36, 0.10), (0, -0.08, -0.42), bevel=0.012, taper_y=0.75)
		finish_part(f"shin_{side}", bm, mat, (s * 0.03, -0.06, -0.40), th)

	os.makedirs(OUT_DIR, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=os.path.join(OUT_DIR, "vanguard.glb"),
		export_format="GLB",
		export_apply=True,
	)


def build_bastion():
	reset_scene()
	mat = make_pbr_mat("mat_bastion")

	# Torso: massive wide citadel chassis with sloped glacis & heavy side armor
	bm = bmesh.new()
	add_box(bm, (0.98, 0.84, 0.78), (0, 0.0, 0.14), bevel=0.026, taper_x=1.08)
	add_box(bm, (0.78, 0.42, 0.44), (0, -0.34, 0.12), rot=(0.28, 0, 0), bevel=0.020)
	add_box(bm, (0.72, 0.62, 0.30), (0, 0.0, -0.24), bevel=0.020)
	# Heavy rear reactor block
	add_box(bm, (0.70, 0.36, 0.56), (0, 0.42, 0.16), bevel=0.018)
	for s in (-1, 1):
		add_cyl(bm, 0.11, 0.11, 0.28, center=(s * 0.22, 0.48, 0.34), rot=(0.15, 0, 0))
	torso = finish_part("torso", bm, mat, (0, 0, 0))

	# Head: armored bunker dome recessed under heavy brow cowl
	bm = bmesh.new()
	add_box(bm, (0.44, 0.44, 0.28), (0, -0.02, 0.02), bevel=0.018)
	add_box(bm, (0.52, 0.48, 0.12), (0, -0.06, 0.14), rot=(0.10, 0, 0), bevel=0.014)
	finish_part("head", bm, mat, (0.0, -0.18, 0.40), torso)

	# Shoulders, Upper Arms, Forearms (towering fortress pauldrons + siege gauntlets)
	for side, s in (("l", -1), ("r", 1)):
		bm = bmesh.new()
		add_box(bm, (0.46, 0.64, 0.48), (s * 0.06, 0.0, 0.06), rot=(0, s * -0.10, 0), bevel=0.022)
		add_box(bm, (0.38, 0.56, 0.16), (s * 0.10, 0.0, 0.28), rot=(0, s * -0.18, 0), bevel=0.014)
		sh = finish_part(f"shoulder_{side}", bm, mat, (s * 0.56, 0.0, 0.52), torso)

		bm = bmesh.new()
		add_cyl(bm, 0.15, 0.14, 0.22, center=(0, 0, 0), rot=(0, math.pi * 0.5, 0))
		add_box(bm, (0.30, 0.32, 0.38), (0, 0, -0.18), bevel=0.016)
		ua = finish_part(f"upper_arm_{side}", bm, mat, (s * 0.06, 0.0, -0.24), sh)

		bm = bmesh.new()
		add_box(bm, (0.34, 0.54, 0.34), (0, -0.10, -0.06), bevel=0.018)
		add_box(bm, (0.28, 0.42, 0.16), (s * 0.08, -0.14, -0.06), bevel=0.012)
		finish_part(f"forearm_{side}", bm, mat, (s * 0.04, -0.02, -0.26), ua)

	# Thighs & Shins (wide pillar siege legs with heavy knee shields)
	for side, s in (("l", -1), ("r", 1)):
		bm = bmesh.new()
		add_cyl(bm, 0.16, 0.16, 0.22, center=(0, 0, 0), rot=(0, math.pi * 0.5, 0))
		add_box(bm, (0.36, 0.38, 0.44), (0, 0.0, -0.20), bevel=0.018)
		th = finish_part(f"thigh_{side}", bm, mat, (s * 0.32, 0.0, -0.12), torso)

		bm = bmesh.new()
		add_box(bm, (0.36, 0.40, 0.48), (0, 0.0, -0.22), bevel=0.018)
		add_box(bm, (0.38, 0.16, 0.32), (0, -0.22, -0.08), rot=(0.12, 0, 0), bevel=0.014)
		add_box(bm, (0.44, 0.54, 0.14), (0, -0.08, -0.44), bevel=0.016)
		finish_part(f"shin_{side}", bm, mat, (s * 0.04, 0.0, -0.40), th)

	os.makedirs(OUT_DIR, exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=os.path.join(OUT_DIR, "bastion_mech.glb"),
		export_format="GLB",
		export_apply=True,
	)


if __name__ == "__main__":
	build_vanguard()
	build_bastion()
	print("Built vanguard.glb and bastion_mech.glb in", OUT_DIR)
