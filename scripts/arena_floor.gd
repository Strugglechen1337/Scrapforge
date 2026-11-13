class_name ArenaFloor
extends RefCounted

const MAX_DECALS := 24
const RESERVED_SCORCH_DECALS := 8
const STATIC_DECALS := 16
const SEED := 8125
const FLOOR_LAYER := 4
const DIR := "res://assets/third_party/ambientcg/"
const DECAL_DIR := "res://assets/arena/"
const KINDS := ["oil", "soot", "puddle", "scratch", "warning"]

static func build(parent: Node3D, mobile: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaFloor"
	parent.add_child(root)
	var mat: Material
	if mobile:
		var old := StandardMaterial3D.new()
		old.albedo_color = Color("42464e")
		old.metallic = 0.4
		old.roughness = 0.85
		old.albedo_texture = load(DIR + "MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
		old.normal_enabled = true
		old.normal_texture = load(DIR + "MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
		old.roughness_texture = load(DIR + "MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")
		old.uv1_scale = Vector3(20, 14, 1)
		mat = old
	else:
		var shader := ShaderMaterial.new()
		shader.shader = load("res://scripts/arena_floor.gdshader")
		shader.set_shader_parameter("floor_mask", load(DECAL_DIR + "floor_mask.png"))
		for map in [["color", "Color"], ["normal", "NormalGL"], ["rough", "Roughness"]]:
			shader.set_shader_parameter("metal_" + map[0], load(DIR + "MetalPlates001/MetalPlates001_2K-JPG_" + map[1] + ".jpg"))
		shader.set_shader_parameter("concrete_color", load(DIR + "Concrete034/Concrete034_2K-JPG_Color.jpg"))
		mat = shader
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(80, 0.2, 55)
	floor_node.mesh = mesh
	floor_node.position = Vector3(0, -0.2, 0)
	floor_node.material_override = mat
	if not mobile:
		floor_node.layers = FLOOR_LAYER
	root.add_child(floor_node)
	if mobile:
		build_old_stains(root)
	else:
		build_decals(root)
	return root

static func build_old_stains(root: Node3D) -> void:
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("0b0d10")
	dirt.roughness = 0.5
	var random := RandomNumberGenerator.new()
	random.seed = SEED
	var stain_mesh := CylinderMesh.new()
	stain_mesh.top_radius = 1.0
	stain_mesh.bottom_radius = 1.0
	stain_mesh.height = 0.012
	stain_mesh.radial_segments = 12
	for i in range(75):
		var stain := MeshInstance3D.new()
		stain.mesh = stain_mesh
		stain.material_override = dirt
		stain.position = Vector3(random.randf_range(-35, 35), -0.078, random.randf_range(-24, 24))
		stain.scale = Vector3(random.randf_range(0.15, 0.8), 1, random.randf_range(0.12, 0.5))
		root.add_child(stain)

static func build_decals(root: Node3D) -> void:
	var textures := {}
	for kind in KINDS:
		textures[kind] = load(DECAL_DIR + kind + ".png")
	var orm := {"puddle": load(DECAL_DIR + "puddle_orm.png"), "oil": load(DECAL_DIR + "oil_orm.png")}
	# kind, x, z, rotation in degrees, width, depth. Hand placed, so the game camera
	# (around the arena centre) always sees a few, the rest frames the arena.
	var layout := [
		["warning", 2.0, 4.5, 0.0, 6.0, 3.0], ["puddle", -3.5, 2.0, 25.0, 3.6, 2.4],
		["oil", 6.5, -2.0, 70.0, 3.4, 2.4], ["soot", -6.5, -3.5, 10.0, 4.2, 3.0],
		["scratch", 3.0, 0.5, 40.0, 3.0, 3.0], ["puddle", 9.0, 5.5, 110.0, 3.2, 2.2],
		["warning", -10.0, -7.0, 90.0, 6.0, 3.0], ["oil", -9.0, 6.5, 150.0, 3.2, 2.2],
		["soot", 12.0, -8.0, 60.0, 4.2, 3.0], ["scratch", -15.0, 1.0, 5.0, 3.0, 3.0],
		["puddle", 17.0, 2.0, 80.0, 3.4, 2.2], ["warning", 20.0, -14.0, 0.0, 6.0, 3.0],
		["oil", -20.0, 12.0, 30.0, 3.4, 2.4], ["soot", -24.0, -12.0, 120.0, 4.2, 3.0],
		["warning", 26.0, 14.0, 90.0, 6.0, 3.0], ["puddle", -29.0, 5.0, 15.0, 3.4, 2.2],
	]
	assert(layout.size() == STATIC_DECALS)
	for i in range(STATIC_DECALS):
		var entry: Array = layout[i]
		var kind: String = entry[0]
		var decal := Decal.new()
		decal.name = kind.capitalize() + str(i)
		decal.texture_albedo = textures[kind]
		decal.cull_mask = FLOOR_LAYER
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 28.0
		decal.distance_fade_length = 10.0
		decal.upper_fade = 0.2
		decal.lower_fade = 0.2
		if orm.has(kind):
			decal.texture_orm = orm[kind]
		var size_factor := 0.72 if kind in ["oil", "soot", "puddle"] else 1.0
		decal.size = Vector3(entry[4] * size_factor, 0.5, entry[5] * size_factor)
		decal.position = Vector3(entry[1], -0.05, entry[2])
		decal.rotation.y = deg_to_rad(entry[3])
		root.add_child(decal)