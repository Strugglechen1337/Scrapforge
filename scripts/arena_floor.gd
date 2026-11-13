class_name ArenaFloor
extends RefCounted

const MAX_DECALS := 48
const RESERVED_SCORCH_DECALS := 8
const STATIC_DECALS := 40
const SEED := 8125
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
		for entry in [["metal", "MetalPlates001"], ["concrete", "Concrete034"]]:
			for map in [["color", "Color"], ["normal", "NormalGL"], ["rough", "Roughness"]]:
				shader.set_shader_parameter(entry[0] + "_" + map[0], load(DIR + entry[1] + "/" + entry[1] + "_2K-JPG_" + map[1] + ".jpg"))
		mat = shader
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(80, 0.2, 55)
	floor_node.mesh = mesh
	floor_node.position = Vector3(0, -0.2, 0)
	floor_node.material_override = mat
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
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var textures := {}
	for kind in KINDS:
		textures[kind] = load(DECAL_DIR + kind + ".png")
	var puddle_orm: Texture2D = load(DECAL_DIR + "puddle_orm.png")
	for i in range(STATIC_DECALS):
		var kind: String = KINDS[i % KINDS.size()]
		var decal := Decal.new()
		decal.name = kind.capitalize() + str(i)
		decal.texture_albedo = textures[kind]
		if kind == "puddle":
			decal.texture_orm = puddle_orm
		decal.size = Vector3(rng.randf_range(1.0, 3.0), 0.5, rng.randf_range(0.7, 2.1))
		decal.position = Vector3(rng.randf_range(-34, 34), -0.05, rng.randf_range(-22, 22))
		decal.rotation.y = rng.randf_range(0, TAU)
		root.add_child(decal)
