class_name ArenaAtmosphere
extends RefCounted

# All scenery is decoration and lives outside gameplay collision.
static func build(parent: Node3D, mobile: bool) -> Node3D:
	if mobile:
		return null
	var root := Node3D.new()
	root.name = "ArenaAtmosphere"
	parent.add_child(root)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(240, 200)
	ground.mesh = ground_mesh
	ground.position.y = -0.25
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("373531")
	ground_mat.albedo_texture = load("res://assets/third_party/ambientcg/Concrete034/Concrete034_2K-JPG_Color.jpg")
	ground_mat.uv1_scale = Vector3(30, 25, 1)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	var walls: Array[Transform3D] = []
	for x in range(-60, 61, 3):
		walls.append(Transform3D(Basis.IDENTITY, Vector3(x, 0, -48)))
	ArenaProps.create_multimesh(root, "DistantHall", ArenaBoundary.scene("wall_panel"), walls)
	var piers: Array[Transform3D] = []
	for x in range(-60, 61, 9):
		piers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, 2.3, 1)), Vector3(x, 0, -48)))
	ArenaProps.create_multimesh(root, "DistantPiers", ArenaBoundary.scene("wall_pier"), piers)
	for item in [
		["Hall", Vector3(-17, 3.3, -23.9), Color("c7d9ed")],
		["Hall", Vector3(17, 3.3, -23.9), Color("c7d9ed")],
		["Warning", Vector3(-32, 2.8, -23), Color("ff7a1a")],
		["Warning", Vector3(32, 2.8, -23), Color("ff7a1a")],
		["Fire", Vector3(-30, 0, 17), Color("ff9b48")],
		["Fire", Vector3(30, 0, 17), Color("ff9b48")]]:
		_add_source(root, item[0], item[1], item[2])
	return root

static func _add_source(root: Node3D, kind: String, pos: Vector3, color: Color) -> void:
	var source := Node3D.new()
	source.name = kind + "Source" + str(root.get_child_count())
	source.position = pos
	root.add_child(source)
	if kind == "Fire":
		var barrel := ArenaProps.scene("barrel").instantiate() as Node3D
		barrel.name = "Barrel"
		source.add_child(barrel)
		_add_particles(source, color, false)
		_add_particles(source, Color("34312e"), true)
		_add_sparks(source)
	else:
		# A small faceted reflector with a recessed emissive lens.
		var housing := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := Vector3(0, 0.18, 0)
		var ring := [Vector3(-0.34, 0, -0.22), Vector3(0.34, 0, -0.22), Vector3(0.34, 0, 0.22), Vector3(-0.34, 0, 0.22)]
		for i in range(4):
			st.add_vertex(top)
			st.add_vertex(ring[i])
			st.add_vertex(ring[(i + 1) % 4])
		st.generate_normals()
		housing.mesh = st.commit()
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("55595b")
		metal.metallic = 0.7
		metal.roughness = 0.8
		housing.material_override = metal
		source.add_child(housing)
		var lens := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.38, 0.22)
		lens.mesh = quad
		lens.rotation.x = PI / 2
		lens.position.y = -0.01
		var emission := StandardMaterial3D.new()
		emission.albedo_color = color
		emission.emission_enabled = true
		emission.emission = color
		emission.emission_energy_multiplier = 1.5
		emission.cull_mode = BaseMaterial3D.CULL_DISABLED
		lens.material_override = emission
		lens.name = "Lens"
		source.add_child(lens)
	if kind == "Hall":
		_add_beam(source, color)
	var light := OmniLight3D.new()
	light.name = "SourceLight"
	light.position.y = 1.3 if kind == "Fire" else -0.2
	light.light_color = color
	light.light_energy = 0.45 if kind == "Fire" else 0.3
	light.omni_range = 4.0 if kind != "Hall" else 6.0
	light.shadow_enabled = false
	source.add_child(light)
	if kind == "Fire":
		var tween := source.create_tween().set_loops()
		tween.tween_property(light, "light_energy", 0.3, 0.45)
		tween.tween_property(light, "light_energy", 0.5, 0.6)

static func _add_particles(source: Node3D, color: Color, smoke: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Smoke" if smoke else "Flame"
	particles.position.y = 1.2
	particles.amount = 8 if smoke else 16
	particles.lifetime = 1.5 if smoke else 0.7
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 18
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0, 0.4, 0)
	process.scale_min = 0.15 if smoke else 0.1
	process.scale_max = 0.4 if smoke else 0.25
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.18 if smoke else 0.6)
	mat.albedo_texture = load("res://assets/arena/flame_particle.png")
	if not smoke:
		mat.emission_enabled = true
		mat.emission = color
	quad.material = mat
	particles.draw_pass_1 = quad
	source.add_child(particles)

static func _add_sparks(source: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.position.y = 1.3
	p.amount = 5
	p.lifetime = 0.8
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 30
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.3
	process.gravity = Vector3(0, -0.2, 0)
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color("ffb05c")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	quad.material = mat
	p.draw_pass_1 = quad
	source.add_child(p)



static func _add_beam(source: Node3D, color: Color) -> void:
	var beam := MeshInstance3D.new()
	beam.name = "LightHint"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(0, -0.1, 0))
	st.add_vertex(Vector3(-0.55, -2.6, 0))
	st.add_vertex(Vector3(0.55, -2.6, 0))
	st.generate_normals()
	beam.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color, 0.012)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.01
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	source.add_child(beam)

