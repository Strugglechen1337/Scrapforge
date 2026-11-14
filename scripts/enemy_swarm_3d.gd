extends Node3D
class_name EnemySwarm3D

const CAPACITY := 600
const SIZES := [0.45, 0.80, 0.60, 2.50, 0.68, 2.95]

var spider_kind_cache: Array[int] = []
var spider: MultiMeshInstance3D
var brute: MultiMeshInstance3D
var brute_armor: MultiMeshInstance3D
var ranged: MultiMeshInstance3D
var ranged_cannon: MultiMeshInstance3D
var ranged_sensor: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var heads: MultiMeshInstance3D
var armor: MultiMeshInstance3D
var seams: MultiMeshInstance3D
var eyes: MultiMeshInstance3D
var accents: MultiMeshInstance3D
var legs: MultiMeshInstance3D
var guns: MultiMeshInstance3D
var boss_lights: MultiMeshInstance3D
var boss_rig: Node3D
var boss_leg_pivots: Array[Node3D] = []
var boss_hit_overlay: ShaderMaterial
var boss_turrets: Array[Node3D] = []
var boss_armor_meshes: Array[MeshInstance3D] = []
var boss_armor_l: Node3D
var boss_armor_r: Node3D
var boss_smoke_l: Node3D
var boss_smoke_r: Node3D
var boss_sparks_l: Node3D
var boss_sparks_r: Node3D
var boss_steel_mat := StandardMaterial3D.new()
var boss_trim_mat := StandardMaterial3D.new()
var boss_dark_mat := StandardMaterial3D.new()
var boss_flash_mat := StandardMaterial3D.new()
var eye_mat := StandardMaterial3D.new()
var enemy_gunmetal_mat := StandardMaterial3D.new()
var enemy_dark_mat := StandardMaterial3D.new()
var plates_normal: Texture2D
var plates_roughness: Texture2D
var time := 0.0
var leg_phase := 0
var prewarm_boss_frames := 2
var previous_kinds: Array[int] = []
var elite_lights: Array[OmniLight3D] = []

func enemy_scale(kind: int) -> float:
	return SIZES[clampi(kind, 0, SIZES.size() - 1)]

func body_dimensions(kind: int) -> Vector3:
	var size := enemy_scale(kind)
	var width := 1.42 if kind == 1 else (1.04 if kind == 2 else 0.94)
	var body_len := 0.92 if kind == 1 else 0.76
	return Vector3(0.72 * width, 0.30, body_len) * size

func leg_count(kind: int) -> int:
	return 6 if kind == 1 else 8

func has_turret(kind: int) -> bool:
	return kind == 2 or kind == 3

func ranged_charge(e: Dictionary) -> float:
	if int(e.get("kind", 0)) != 2:
		return 0.0
	var atk := float(e.get("attack", 2.0))
	return clampf(1.0 - atk / 0.75, 0.0, 1.0) if atk <= 0.75 else 0.0

func _ready() -> void:
	if not OS.has_feature("mobile"):
		for _i in range(4):
			var el := OmniLight3D.new()
			el.light_color = Color("c65cff")
			el.light_energy = 4.2
			el.omni_range = 4.5
			el.visible = false
			add_child(el)
			elite_lights.append(el)
	plates_normal = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
	plates_roughness = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")

	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color.WHITE
	shell.metallic = 0.52
	shell.roughness = 0.48
	shell.vertex_color_use_as_albedo = true
	shell.vertex_color_is_srgb = true
	shell.normal_enabled = true
	shell.normal_scale = 0.45
	shell.normal_texture = plates_normal

	enemy_gunmetal_mat.albedo_color = Color("2b313a")
	enemy_gunmetal_mat.metallic = 0.52
	enemy_gunmetal_mat.roughness = 0.48
	enemy_gunmetal_mat.normal_enabled = true
	enemy_gunmetal_mat.normal_texture = plates_normal
	enemy_gunmetal_mat.normal_scale = 0.5
	enemy_gunmetal_mat.roughness_texture = plates_roughness

	enemy_dark_mat.albedo_color = Color("161a20")
	enemy_dark_mat.metallic = 0.65
	enemy_dark_mat.roughness = 0.44
	enemy_dark_mat.normal_enabled = true
	enemy_dark_mat.normal_texture = plates_normal
	enemy_dark_mat.normal_scale = 0.45

	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color("ff2a2a")
	eye_mat.emission_enabled = true
	eye_mat.emission = Color("ff2a2a")
	eye_mat.emission_energy_multiplier = 1.6

	var leg_shader := Shader.new()
	leg_shader.code = """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform float metallic : hint_range(0.0, 1.0) = 0.50;
uniform float roughness : hint_range(0.0, 1.0) = 0.48;

varying vec3 v_color;

void vertex() {
	int inst = INSTANCE_ID;
	int enemy_id = inst / 16;
	int rem = inst % 16;
	int leg_id = rem / 2;
	int seg_id = rem % 2;

	float active = step(0.5, COLOR.a);
	float side = (leg_id < 4) ? -1.0 : 1.0;
	float row = float(leg_id % 4);
	float spread = (row - 1.5) * 0.24;

	float phase = TIME * 11.5 + float(enemy_id) * 0.77 + row * 1.85 + side * 1.57;
	float stride = sin(phase) * 0.13;
	float lift = max(0.0, cos(phase)) * 0.10;

	vec3 hip = vec3(side * 0.28, 0.22, spread * 0.75);
	vec3 knee = vec3(side * 0.62, 0.45 + lift * 0.55, spread * 1.12 + stride * 0.65);
	vec3 foot = vec3(side * 0.88, 0.02 + lift, spread * 1.40 + stride);

	vec3 p0 = (seg_id == 0) ? hip : knee;
	vec3 p1 = (seg_id == 0) ? knee : foot;
	vec3 dir = p1 - p0;
	float len = max(length(dir), 0.001);
	vec3 forward = dir / len;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);

	float t = VERTEX.z + 0.5;
	float width = (seg_id == 0) ? mix(0.09, 0.11, t) : mix(0.095, 0.045, t);
	vec3 local_pos = p0 + forward * (t * len) + right * (VERTEX.x * width) + up * (VERTEX.y * width * 1.2);

	VERTEX = local_pos * active;
	vec3 geom_n = normalize(right * NORMAL.x + up * NORMAL.y + forward * NORMAL.z);
	NORMAL = normalize(mix(geom_n, vec3(0.0, 1.0, 0.0), 0.35));
	v_color = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	ALBEDO = v_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""
	var leg_mat := ShaderMaterial.new()
	leg_mat.shader = leg_shader

	var block := BoxMesh.new()
	block.size = Vector3.ONE
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.radial_segments = 8
	dome.rings = 4
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.5
	eye_sphere.height = 1.0
	eye_sphere.radial_segments = 8
	eye_sphere.rings = 4

	var spider_scene := load("res://assets/third_party/sketchfab/mech_spider/mech_spider.glb") as PackedScene
	var spider_root := spider_scene.instantiate()
	var spider_mesh: Mesh = find_mesh(spider_root)
	spider_root.free()
	var spider_material := ShaderMaterial.new()
	spider_material.shader = load("res://assets/third_party/sketchfab/mech_spider/walk.gdshader")
	spider_material.set_shader_parameter("albedo_texture", load("res://assets/third_party/sketchfab/mech_spider/gunmetal.png"))
	spider_material.set_shader_parameter("walk_vat", load("res://assets/third_party/sketchfab/mech_spider/walk_vat.png"))
	spider = batch(spider_mesh, spider_material, CAPACITY, true)
	brute = variant_batch("res://assets/third_party/sketchfab/brute_spider/brute_spider.glb", false)
	brute_armor = attachment_batch("res://assets/models/enemies/brute_armor.glb", CAPACITY)
	ranged = variant_batch("res://assets/third_party/sketchfab/ranged_spider/ranged_spider.glb", true)
	ranged_cannon = attachment_batch("res://assets/models/enemies/ranged_cannon.glb", CAPACITY)
	var sensor_mat := StandardMaterial3D.new()
	sensor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sensor_mat.albedo_color = Color("ff2a2a")
	sensor_mat.emission_enabled = true
	sensor_mat.emission = Color("ff2a2a")
	sensor_mat.emission_energy_multiplier = 3.5
	ranged_sensor = batch(eye_sphere, sensor_mat, CAPACITY, false)
	bodies = batch(dome, shell, CAPACITY, true)
	heads = batch(block, shell, CAPACITY, true)
	armor = batch(dome, shell, CAPACITY, true)
	seams = batch(block, shell, CAPACITY * 3, true)
	eyes = batch(eye_sphere, eye_mat, CAPACITY * 4, false)
	accents = batch(block, eye_mat, CAPACITY * 2, false)
	boss_lights = batch(eye_sphere, eye_mat, 8, false)
	legs = batch(block, leg_mat, CAPACITY * 16, true)
	guns = batch(block, shell, CAPACITY * 2, true)
	build_boss_rig()

func find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for child in node.get_children():
		var found := find_mesh(child)
		if found:
			return found
	return null

func attachment_batch(path: String, count: int) -> MultiMeshInstance3D:
	var scene := load(path) as PackedScene
	var root := scene.instantiate()
	var mesh := find_mesh(root).duplicate() as Mesh
	root.free()
	for i in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(i)
		if source and source.resource_name == "mat_red":
			mesh.surface_set_material(i, eye_mat)
		elif source and source.resource_name == "mat_dark":
			mesh.surface_set_material(i, enemy_dark_mat)
		else:
			mesh.surface_set_material(i, enemy_gunmetal_mat)
	return batch(mesh, null, count, false)

func variant_batch(path: String, hovering: bool) -> MultiMeshInstance3D:
	var scene := load(path) as PackedScene
	var root := scene.instantiate()
	var mesh := find_mesh(root).duplicate() as Mesh
	root.free()
	var shader := load("res://assets/third_party/sketchfab/enemy_variants.gdshader") as Shader
	for i in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(i) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("hover", hovering)
		material.set_shader_parameter("normal_texture", plates_normal)
		if source:
			material.set_shader_parameter("albedo_texture", source.albedo_texture)
		mesh.surface_set_material(i, material)
	return batch(mesh, null, CAPACITY, true)

func batch(mesh: Mesh, material: Material, count: int, colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.instance_count = count
	mm.visible_instance_count = 0
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-120, -10, -120), Vector3(240, 50, 240))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _load_boss_part(path: String, pos: Vector3, rot_deg := Vector3.ZERO) -> Node3D:
	var scene := load(path) as PackedScene
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees = rot_deg
	_apply_enemy_glb_materials(node)
	boss_rig.add_child(node)
	return node

func _apply_enemy_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for s in range(mesh_node.mesh.get_surface_count()):
			var orig := mesh_node.get_active_material(s)
			if orig and orig.resource_name == "mat_red":
				mesh_node.set_surface_override_material(s, eye_mat)
			elif orig and orig.resource_name == "mat_dark":
				mesh_node.set_surface_override_material(s, enemy_dark_mat)
			else:
				mesh_node.set_surface_override_material(s, enemy_gunmetal_mat)
		mesh_node.material_overlay = boss_hit_overlay
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_enemy_glb_materials(child)

func _make_damage_emitter(pos: Vector3, is_smoke: bool) -> Node3D:
	var ps: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55) if is_smoke else Vector2(0.18, 0.18)
	var mat := CombatEffects3D.soft_material(not is_smoke)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.14, 0.14, 0.15, 0.65) if is_smoke else Color(1.0, 0.55, 0.12, 0.95)
	quad.material = mat
	if ps is GPUParticles3D:
		var proc := ParticleProcessMaterial.new()
		proc.direction = Vector3.UP
		proc.spread = 28.0 if is_smoke else 65.0
		proc.initial_velocity_min = 0.8 if is_smoke else 2.0
		proc.initial_velocity_max = 1.8 if is_smoke else 4.5
		proc.gravity = Vector3(0, 0.6, 0) if is_smoke else Vector3(0, -6.0, 0)
		ps.process_material = proc
		ps.draw_pass_1 = quad
	else:
		ps.mesh = quad
		ps.direction = Vector3.UP
		ps.spread = 28.0 if is_smoke else 65.0
		ps.initial_velocity_min = 0.8 if is_smoke else 2.0
		ps.initial_velocity_max = 1.8 if is_smoke else 4.5
		ps.gravity = Vector3(0, 0.6, 0) if is_smoke else Vector3(0, -6.0, 0)
	ps.amount = 6 if is_smoke else 8
	ps.lifetime = 0.9 if is_smoke else 0.4
	ps.emitting = false
	ps.position = pos
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boss_rig.add_child(ps)
	return ps

func build_boss_rig() -> void:
	var scene := load("res://assets/third_party/sketchfab/boss_spider/boss_spider.glb") as PackedScene
	boss_rig = scene.instantiate() as Node3D
	add_child(boss_rig)
	boss_leg_pivots.clear()
	boss_turrets.clear()
	for i in range(4):
		var pivot := boss_rig.find_child("LegPivot%d" % i, true, false) as Node3D
		if pivot:
			boss_leg_pivots.append(pivot)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform float hit = 0.0;
void fragment() { ALBEDO = vec3(0.65, 0.35, 0.22); ALPHA = hit * 0.06; }
"""
	boss_hit_overlay = ShaderMaterial.new()
	boss_hit_overlay.shader = shader
	prepare_boss_meshes(boss_rig)
	# Red glowing optics + dorsal turret + exposed flank/rear weakspots + detachable flank armor
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.09
	lamp_mesh.height = 0.18
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = lamp_mesh
		lamp.material_override = eye_mat
		lamp.position = Vector3(side * 0.38, 1.2, 1.15)
		boss_rig.add_child(lamp)
	var turret := _load_boss_part("res://assets/models/enemies/boss_turret.glb", Vector3(0, 1.98, 0.05))
	boss_turrets.append(turret)
	_load_boss_part("res://assets/models/enemies/boss_weakspot.glb", Vector3(-0.92, 1.05, 0.05))
	_load_boss_part("res://assets/models/enemies/boss_weakspot.glb", Vector3(0.92, 1.05, 0.05), Vector3(0, 180, 0))
	_load_boss_part("res://assets/models/enemies/boss_weakspot.glb", Vector3(0.0, 1.38, -1.02), Vector3(0, 90, 0))
	boss_armor_l = _load_boss_part("res://assets/models/enemies/boss_armor_plate.glb", Vector3(-1.12, 1.05, 0.05))
	boss_armor_r = _load_boss_part("res://assets/models/enemies/boss_armor_plate.glb", Vector3(1.12, 1.05, 0.05))
	boss_smoke_l = _make_damage_emitter(Vector3(-0.95, 1.15, 0.05), true)
	boss_smoke_r = _make_damage_emitter(Vector3(0.95, 1.15, 0.05), true)
	boss_sparks_l = _make_damage_emitter(Vector3(-0.95, 1.10, 0.05), false)
	boss_sparks_r = _make_damage_emitter(Vector3(0.95, 1.10, 0.05), false)

func prepare_boss_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for s in range(mesh_node.mesh.get_surface_count()):
			var orig := mesh_node.get_active_material(s) as StandardMaterial3D
			var mat := StandardMaterial3D.new()
			if orig and orig.albedo_texture:
				mat.albedo_texture = orig.albedo_texture
			mat.albedo_color = Color("6b7482")
			mat.metallic = 0.54
			mat.roughness = 0.48
			mat.normal_enabled = true
			mat.normal_texture = plates_normal
			mat.normal_scale = 0.55
			mat.roughness_texture = plates_roughness
			mesh_node.set_surface_override_material(s, mat)
		mesh_node.material_overlay = boss_hit_overlay
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		prepare_boss_meshes(child)

func transform_at(base: Vector3, rotation: Basis, offset: Vector3, scale: Vector3) -> Transform3D:
	return Transform3D(rotation * Basis.from_scale(scale), base + rotation * offset)

func update_swarm(enemies: Array, player: Vector2, delta: float) -> void:
	time += delta
	leg_phase = 1 - leg_phase
	var count := mini(enemies.size(), CAPACITY)
	while spider_kind_cache.size() < count:
		spider_kind_cache.append(-1)
	spider.multimesh.visible_instance_count = count
	brute.multimesh.visible_instance_count = count
	brute_armor.multimesh.visible_instance_count = count
	ranged.multimesh.visible_instance_count = count
	ranged_cannon.multimesh.visible_instance_count = count
	ranged_sensor.multimesh.visible_instance_count = count
	for node in [bodies, heads, armor]:
		node.multimesh.visible_instance_count = count
	seams.multimesh.visible_instance_count = count * 3
	eyes.multimesh.visible_instance_count = count * 4
	accents.multimesh.visible_instance_count = count * 2
	legs.multimesh.visible_instance_count = count * 16
	guns.multimesh.visible_instance_count = count * 2
	boss_lights.multimesh.visible_instance_count = 0
	if prewarm_boss_frames > 0:
		prewarm_boss_frames -= 1
		boss_rig.visible = true
		boss_rig.position = Vector3.ZERO
	else:
		boss_rig.visible = false

	var elite_light_used := 0
	for l in elite_lights:
		l.visible = false
	for i in range(count):
		var e: Dictionary = enemies[i]
		var kind: int = e.kind
		var is_elite: bool = e.get("elite", false)
		var size := enemy_scale(kind) * (1.45 if is_elite else 1.0)
		var pos := Vector3(e.pos.x / 50.0, 0.0, e.pos.y / 50.0)
		var yaw := atan2(player.x - e.pos.x, player.y - e.pos.y)
		var rotation := Basis(Vector3.UP, yaw)
		var flash: bool = e.get("flash", 0.0) > 0.0

		if previous_kinds.size() <= i:
			previous_kinds.append(-1)
		var kind_changed := previous_kinds[i] != kind
		previous_kinds[i] = kind
		var hidden_variant := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO)
		spider_kind_cache[i] = kind
		if kind_changed:
			for node in [spider, brute, brute_armor, ranged, ranged_cannon, ranged_sensor, bodies, heads, armor]:
				node.multimesh.set_instance_transform(i, hidden_variant)
			for k in range(3):
				seams.multimesh.set_instance_transform(i * 3 + k, hidden_variant)
			for k in range(4):
				eyes.multimesh.set_instance_transform(i * 4 + k, hidden_variant)
			for k in range(2):
				accents.multimesh.set_instance_transform(i * 2 + k, hidden_variant)
				guns.multimesh.set_instance_transform(i * 2 + k, hidden_variant)
			for k in range(16):
				legs.multimesh.set_instance_transform(i * 16 + k, hidden_variant)
				legs.multimesh.set_instance_color(i * 16 + k, Color(0, 0, 0, 0))
		if kind < 3 or kind == 4:
			var chosen: MultiMeshInstance3D = ranged if kind == 4 else [spider, brute, ranged][kind]
			var type_scale := Vector3(1.0, 0.85, 1.0) if kind == 0 else (Vector3(1.22, 1.08, 1.05) if kind == 1 else (Vector3(1.1, 0.85, 1.25) if kind == 4 else Vector3.ONE))
			var hover := Vector3(0, 0.35 + sin(time * 8.0 + float(i)) * 0.12, 0) if kind == 4 else Vector3.ZERO
			chosen.multimesh.set_instance_transform(i, transform_at(pos, rotation, hover, type_scale * size))
			var charge := ranged_charge(e)
			chosen.multimesh.set_instance_color(i, Color(1.0 if flash else 0.0, charge, 0.0, 1.0))
			if kind == 0 or kind == 1:
				for eye in range(2):
					var eye_x := (-0.12 if eye == 0 else 0.12) * size
					eyes.multimesh.set_instance_transform(i * 4 + eye, transform_at(pos, rotation, Vector3(eye_x, 0.48 * size, 0.32 * size), Vector3.ONE * 0.10 * size))
			if is_elite and not OS.has_feature("mobile"):
				if elite_light_used < elite_lights.size():
					elite_lights[elite_light_used].position = pos + Vector3(0, 1.3 * size, 0)
					elite_lights[elite_light_used].visible = true
					elite_light_used += 1
			if kind == 1 or kind == 4 or is_elite:
				brute_armor.multimesh.set_instance_transform(i, transform_at(pos, rotation, hover, type_scale * size))
			if kind == 2:
				var bob := 0.14 + sin(time * 4.0 + float(i) * 0.77) * 0.045
				ranged_cannon.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3(0, bob, 0) * size, Vector3.ONE * size))
				var orb_scale := (0.07 + charge * 0.22) * size
				ranged_sensor.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3(0, 0.58 + bob, 0.72) * size, Vector3.ONE * orb_scale))
			continue

		if kind == 3 or kind == 5:
			var intro := float(e.get("intro", 0.0))
			var drop_y := pow(clampf(intro / 1.35, 0.0, 1.0), 2.0) * 7.5
			var hp_ratio := float(e.get("hp", 1800)) / maxf(float(e.get("max_hp", 1800)), 1.0)
			boss_rig.visible = true
			boss_rig.position = pos + Vector3(0, drop_y, 0)
			boss_rig.basis = rotation
			boss_rig.scale = Vector3.ONE * (1.18 if kind == 5 else 1.0)
			boss_hit_overlay.set_shader_parameter("hit", 1.0 if flash else 0.0)
			if is_instance_valid(boss_armor_l):
				boss_armor_l.visible = hp_ratio >= 0.70
			if is_instance_valid(boss_armor_r):
				boss_armor_r.visible = hp_ratio >= 0.35
			if is_instance_valid(boss_smoke_l):
				boss_smoke_l.emitting = hp_ratio < 0.70
				boss_sparks_l.emitting = hp_ratio < 0.70
			if is_instance_valid(boss_smoke_r):
				boss_smoke_r.emitting = hp_ratio < 0.35
				boss_sparks_r.emitting = hp_ratio < 0.35
			for t in boss_turrets:
				t.rotation.y = sin(time * 1.4) * 0.15
			for j in range(boss_leg_pivots.size()):
				var phase := time * 7.0 + float(j % 2) * PI + float(j / 2) * PI
				boss_leg_pivots[j].rotation.y = sin(phase) * 0.16
				boss_leg_pivots[j].rotation.z = sin(phase) * (0.09 if j < 2 else -0.09)
			var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos)
			bodies.multimesh.set_instance_transform(i, hidden)
			bodies.multimesh.set_instance_color(i, Color.BLACK)
			heads.multimesh.set_instance_transform(i, hidden)
			heads.multimesh.set_instance_color(i, Color.BLACK)
			armor.multimesh.set_instance_transform(i, hidden)
			armor.multimesh.set_instance_color(i, Color.BLACK)
			for k in range(3):
				seams.multimesh.set_instance_transform(i * 3 + k, hidden)
				seams.multimesh.set_instance_color(i * 3 + k, Color.BLACK)
			for j in range(4):
				eyes.multimesh.set_instance_transform(i * 4 + j, hidden)
			for j in range(2):
				accents.multimesh.set_instance_transform(i * 2 + j, hidden)
				guns.multimesh.set_instance_transform(i * 2 + j, hidden)
				guns.multimesh.set_instance_color(i * 2 + j, Color.BLACK)
			for l in range(16):
				legs.multimesh.set_instance_transform(i * 16 + l, hidden)
				legs.multimesh.set_instance_color(i * 16 + l, Color(0, 0, 0, 0))
			continue
