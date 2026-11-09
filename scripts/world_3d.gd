extends Node3D
class_name ScrapWorld3D

var game: Node
var robot: Robot3D
var camera: Camera3D
var entities: Node3D
var enemy_nodes: Array[Node3D] = []
var projectile_nodes: Array[Node3D] = []
var crystal_nodes: Array[Node3D] = []
var enemy_projectile_nodes: Array[Node3D] = []
var swarm: EnemySwarm3D
var effects_3d: CombatEffects3D
var boss_warning: MeshInstance3D
var collection_ring: MeshInstance3D
var metal := StandardMaterial3D.new()
var dark_rocket := StandardMaterial3D.new()
var red := StandardMaterial3D.new()
var ruby := StandardMaterial3D.new()
var ruby_halo := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var orange := StandardMaterial3D.new()
var tracer := StandardMaterial3D.new()
var soot := StandardMaterial3D.new()
var crystal_mesh := PrismMesh.new()
var enemy_orb_mesh := SphereMesh.new()
var enemy_halo_mesh := SphereMesh.new()
var bullet_core_mesh := BoxMesh.new()
var bullet_tail_mesh := BoxMesh.new()
var rocket_body_mesh := BoxMesh.new()
var rocket_nose_mesh := BoxMesh.new()
var smoke_mesh := SphereMesh.new()
var smoke_process := ParticleProcessMaterial.new()
var elapsed := 0.0
var prewarm_frames := 2

func _ready() -> void:
	metal.albedo_color = Color("30343d")
	metal.metallic = 0.6
	metal.roughness = 0.7
	metal.albedo_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
	metal.normal_enabled = true
	metal.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
	dark_rocket.albedo_color = Color("1f242d")
	dark_rocket.metallic = 0.78
	dark_rocket.roughness = 0.35
	red = emissive(Color("ff3428"))
	ruby.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ruby.albedo_color = Color(0.98, 0.02, 0.015)
	ruby.emission_enabled = true
	ruby.emission = Color(0.96, 0.01, 0.006)
	ruby.emission_energy_multiplier = 0.85
	ruby_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ruby_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ruby_halo.albedo_color = Color(0.98, 0.02, 0.015, 0.35)
	ruby_halo.emission_enabled = true
	ruby_halo.emission = Color(0.95, 0.01, 0.005)
	ruby_halo.emission_energy_multiplier = 0.55
	cyan = emissive(Color("33f5ff"))
	orange = emissive(Color("ff7a1a"))
	cyan.albedo_color = Color("087b83")
	cyan.emission = Color("09b8c2")
	cyan.emission_energy_multiplier = 0.9
	orange.albedo_color = Color("7a3109")
	orange.emission = Color("b4480c")
	orange.emission_energy_multiplier = 0.6
	tracer.albedo_color = Color("ffe094")
	tracer.emission_enabled = true
	tracer.emission = Color("ff801a")
	tracer.emission_energy_multiplier = 2.8
	soot.albedo_color = Color("8c867e")

	crystal_mesh.size = Vector3(0.24, 0.5, 0.24)
	enemy_orb_mesh.radius = 0.095
	enemy_orb_mesh.height = 0.19
	enemy_orb_mesh.radial_segments = 12
	enemy_orb_mesh.rings = 6
	enemy_halo_mesh.radius = 0.15
	enemy_halo_mesh.height = 0.30
	enemy_halo_mesh.radial_segments = 10
	enemy_halo_mesh.rings = 5
	bullet_core_mesh.size = Vector3(0.11, 0.11, 0.34)
	bullet_tail_mesh.size = Vector3(0.05, 0.05, 0.44)
	rocket_body_mesh.size = Vector3(0.16, 0.16, 0.44)
	rocket_nose_mesh.size = Vector3(0.13, 0.13, 0.16)
	smoke_mesh.radius = 0.075
	smoke_mesh.height = 0.15
	smoke_mesh.material = soot
	smoke_process.direction = Vector3(0, 0, 1)
	smoke_process.spread = 15
	smoke_process.initial_velocity_min = 0.3
	smoke_process.initial_velocity_max = 0.7
	smoke_process.gravity = Vector3(0, 0.4, 0)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10131b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("798a9c")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("202b39")
	env.fog_density = 0.008
	var environment := WorldEnvironment.new()
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40
	camera.position = Vector3(6, 15.5, 10.3)
	add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("42464e")
	floor_material.metallic = 0.4
	floor_material.roughness = 0.85
	floor_material.albedo_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
	floor_material.normal_enabled = true
	floor_material.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
	floor_material.roughness_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")
	floor_material.uv1_scale = Vector3(20, 14, 1)
	box(self, Vector3(80, 0.2, 55), Vector3(0, -0.2, 0), floor_material)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("0b0d10")
	dirt.roughness = 0.5
	var random := RandomNumberGenerator.new()
	random.seed = 8125
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
		add_child(stain)
	for z in [-25.0, 25.0]:
		box(self, Vector3(76, 2.5, 0.6), Vector3(0, 1.15, z), metal)
		for x in range(-34, 35, 4):
			box(self, Vector3(0.25, 3.0, 1.0), Vector3(x, 1.4, z), metal)
	for x in [-37.0, 37.0]:
		box(self, Vector3(0.6, 2.5, 50), Vector3(x, 1.15, 0), metal)
	# Discontinuous industrial barriers and salvage clusters frame the first view.
	for z in [-10.0, 10.0]:
		for x in [-16.0, -11.0, 9.0, 15.0]:
			box(self, Vector3(3.5, 1.5, 0.35), Vector3(x, 0.7, z), metal)
			box(self, Vector3(3.65, 0.12, 0.5), Vector3(x, 1.5, z), metal)
			for side in [-1, 1]:
				box(self, Vector3(0.14, 1.7, 0.55), Vector3(x + side * 1.5, 0.8, z), metal)
		for x in [-13.0, 11.0]:
			box(self, Vector3(1.8, 1.3, 1.2), Vector3(x, 0.65, z + 1.2), metal)
			box(self, Vector3(1.95, 0.12, 1.3), Vector3(x, 1.35, z + 1.2), metal)
	for x in range(-20, 21):
		box(self, Vector3(0.035, 0.012, 55), Vector3(x * 2, -0.09, 0), metal)
	for z in range(-14, 15):
		box(self, Vector3(80, 0.012, 0.035), Vector3(0, -0.09, z * 2), metal)
	for x in range(-18, 19, 2):
		box(self, Vector3(0.8, 0.02, 0.08), Vector3(x * 2, -0.08, -25), orange)
		box(self, Vector3(0.8, 0.02, 0.08), Vector3(x * 2, -0.08, 25), cyan)
	for z in [-8.0, 8.0]:
		box(self, Vector3(35, 0.02, 0.05), Vector3(0, -0.07, z), orange if z < 0 else cyan)
		for i in range(-14, 15):
			var stripe := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.45, 0.015, 0.07)
			stripe.mesh = mesh
			stripe.material_override = orange if z < 0 else cyan
			stripe.position = Vector3(i * 1.2, -0.06, z + 0.22)
			stripe.rotation.y = 0.6
			add_child(stripe)
	var prop_paths := ["barrel", "machine-generator", "pipe-straight", "monorail-traincargo"]
	for i in range(32):
		var packed: PackedScene = load("res://assets/third_party/kenney/space-kit/" + prop_paths[i % prop_paths.size()] + ".glb")
		var prop := packed.instantiate() as Node3D
		add_child(prop)
		shade_prop(prop)
		prop.position = Vector3((i % 16 - 7.5) * 4.5, 0, -10.0 if i < 16 else 10.0)
		prop.rotation.y = float(i % 4) * PI / 2.0
		prop.scale = Vector3.ONE * 1.4
	for z in [-8.0, 8.0]:
		for x in [-12.0, 0.0, 12.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 1.0, z)
			lamp.light_color = Color("ff7a1a") if z < 0 else Color("33f5ff")
			lamp.light_energy = 0.5
			lamp.omni_range = 5.0
			add_child(lamp)
	robot = Robot3D.new()
	add_child(robot)
	var player_light := OmniLight3D.new()
	player_light.position = Vector3(-0.8, 2.2, 1.2)
	player_light.light_color = Color("dae6ff")
	player_light.light_energy = 1.9
	player_light.omni_range = 4.5
	player_light.light_cull_mask = 2
	robot.add_child(player_light)
	collection_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.15
	ring.outer_radius = 1.18
	collection_ring.mesh = ring
	collection_ring.material_override = cyan
	add_child(collection_ring)
	entities = Node3D.new()
	add_child(entities)
	swarm = EnemySwarm3D.new()
	add_child(swarm)
	effects_3d = CombatEffects3D.new()
	add_child(effects_3d)
	boss_warning = MeshInstance3D.new()
	var warning_ring := TorusMesh.new()
	warning_ring.inner_radius = 1.3
	warning_ring.outer_radius = 1.34
	boss_warning.mesh = warning_ring
	boss_warning.material_override = red
	add_child(boss_warning)
	boss_warning.visible = true

	# Pre-allocate object pools for projectiles and crystals so combat never stalls on allocations.
	sync_nodes(projectile_nodes, 48, "bullet")
	sync_nodes(enemy_projectile_nodes, 36, "enemy_bullet")
	sync_nodes(crystal_nodes, 128, "crystal")
	if not projectile_nodes.is_empty():
		projectile_nodes[0].visible = true
		projectile_nodes[0].get_node("Smoke").emitting = true
	if not enemy_projectile_nodes.is_empty():
		enemy_projectile_nodes[0].visible = true
	if not crystal_nodes.is_empty():
		crystal_nodes[0].visible = true

func emissive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material

func shade_prop(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = metal
	for child in node.get_children():
		shade_prop(child)

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)

func create_enemy() -> Node3D:
	var enemy := Node3D.new()
	entities.add_child(enemy)
	box(enemy, Vector3(0.7, 0.3, 0.55), Vector3(0, 0.35, 0), metal)
	box(enemy, Vector3(0.38, 0.08, 0.08), Vector3(0, 0.38, -0.3), red)
	for side in [-1, 1]:
		for i in range(3):
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.45, 0.25, (i - 1) * 0.25)
			leg.rotation_degrees.z = side * 25
			enemy.add_child(leg)
			box(leg, Vector3(0.5, 0.07, 0.07), Vector3(side * 0.15, 0, 0), metal)
	return enemy

func sync_nodes(nodes: Array[Node3D], count: int, kind: String) -> void:
	while nodes.size() < count:
		var node: Node3D
		if kind == "enemy":
			node = create_enemy()
		else:
			node = Node3D.new()
			entities.add_child(node)
			if kind == "crystal":
				var gem := MeshInstance3D.new()
				gem.mesh = crystal_mesh
				gem.material_override = cyan
				gem.position.y = 0.3
				gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(gem)
			elif kind == "enemy_bullet":
				var orb := MeshInstance3D.new()
				orb.mesh = enemy_orb_mesh
				orb.material_override = ruby
				orb.position.y = 0.32
				orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(orb)
				var halo := MeshInstance3D.new()
				halo.mesh = enemy_halo_mesh
				halo.material_override = ruby_halo
				halo.position.y = 0.32
				halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(halo)
			else:
				var core := MeshInstance3D.new()
				core.name = "Core"
				core.mesh = bullet_core_mesh
				core.material_override = tracer
				core.position = Vector3(0, 0.3, 0)
				core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(core)
				var tail := MeshInstance3D.new()
				tail.name = "Tail"
				tail.mesh = bullet_tail_mesh
				tail.material_override = tracer
				tail.position = Vector3(0, 0.3, 0.38)
				tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(tail)
				var r_body := MeshInstance3D.new()
				r_body.name = "RocketBody"
				r_body.mesh = rocket_body_mesh
				r_body.material_override = dark_rocket
				r_body.position = Vector3(0, 0.3, 0)
				r_body.visible = false
				r_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(r_body)
				var r_nose := MeshInstance3D.new()
				r_nose.name = "RocketNose"
				r_nose.mesh = rocket_nose_mesh
				r_nose.material_override = ruby
				r_nose.position = Vector3(0, 0.3, -0.28)
				r_nose.visible = false
				r_nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(r_nose)
				add_smoke(node)
		nodes.append(node)
	for i in range(nodes.size()):
		nodes[i].visible = i < count
		if kind == "bullet" and i >= count:
			nodes[i].get_node("Smoke").emitting = false

func add_smoke(node: Node3D) -> void:
	var smoke: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
	smoke.name = "Smoke"
	if smoke is GPUParticles3D:
		smoke.process_material = smoke_process
		smoke.draw_pass_1 = smoke_mesh
	else:
		smoke.mesh = smoke_mesh
		smoke.direction = Vector3(0, 0, 1)
		smoke.spread = 15
		smoke.initial_velocity_min = 0.3
		smoke.initial_velocity_max = 0.7
		smoke.gravity = Vector3(0, 0.4, 0)
	smoke.amount = 8
	smoke.lifetime = 0.5
	smoke.emitting = false
	node.add_child(smoke)

func update_view() -> void:
	if not game:
		return
	if prewarm_frames > 0:
		prewarm_frames -= 1
		if prewarm_frames == 0:
			boss_warning.visible = false
			if not projectile_nodes.is_empty():
				projectile_nodes[0].get_node("Smoke").emitting = false
	visible = game.mode != "menu" and game.mode != "settings"
	robot.state = game.state
	robot.definitions = game.definitions
	var center := Vector3(game.player.x / 50.0, 0, game.player.y / 50.0)
	robot.position = center
	collection_ring.position = center + Vector3(0, 0.03, 0)
	collection_ring.scale = Vector3.ONE * (1.0 + game.state.level("magnet") * 0.2)
	camera.position = center + Vector3(6, 15.5, 10.3)
	camera.look_at(center + Vector3(0, 0.7, 0))
	if game.shake_enabled and game.shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * game.shake * 0.015
	swarm.update_swarm(game.enemies, game.player, get_process_delta_time())
	sync_nodes(projectile_nodes, game.bullets.size(), "bullet")
	sync_nodes(crystal_nodes, game.crystals.size(), "crystal")
	sync_nodes(enemy_projectile_nodes, game.enemy_shots.size(), "enemy_bullet")
	if prewarm_frames == 0:
		boss_warning.visible = false
	for e in game.enemies:
		if e.kind == 3 and e.get("jump_warning", 0.0) > 0:
			boss_warning.position = Vector3(e.jump_target.x / 50.0, 0.02, e.jump_target.y / 50.0)
			boss_warning.visible = true
	for i in range(game.bullets.size()):
		var p: Vector2 = game.bullets[i].pos
		projectile_nodes[i].position = Vector3(p.x / 50.0, 0.5, p.y / 50.0)
		var velocity: Vector2 = game.bullets[i].vel
		projectile_nodes[i].rotation.y = atan2(velocity.x, velocity.y)
		var is_rocket: bool = game.bullets[i].get("rocket", false)
		projectile_nodes[i].get_node("RocketBody").visible = is_rocket
		projectile_nodes[i].get_node("RocketNose").visible = is_rocket
		projectile_nodes[i].get_node("Smoke").emitting = is_rocket
	for i in range(game.enemy_shots.size()):
		var p: Vector2 = game.enemy_shots[i].pos
		enemy_projectile_nodes[i].position = Vector3(p.x / 50.0, 0.4, p.y / 50.0)
		var velocity: Vector2 = game.enemy_shots[i].vel
		enemy_projectile_nodes[i].rotation.y = atan2(velocity.x, velocity.y)
	for i in range(game.crystals.size()):
		var p: Vector2 = game.crystals[i]
		crystal_nodes[i].position = Vector3(p.x / 50.0, 0, p.y / 50.0)
