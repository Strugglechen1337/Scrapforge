extends Node3D
class_name EnemySwarm3D

const CAPACITY := 600
const SIZES := [0.45, 0.80, 0.60, 2.50]

var spider: MultiMeshInstance3D
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
var boss_steel_mat := StandardMaterial3D.new()
var boss_trim_mat := StandardMaterial3D.new()
var boss_dark_mat := StandardMaterial3D.new()
var boss_flash_mat := StandardMaterial3D.new()
var eye_mat := StandardMaterial3D.new()
var time := 0.0
var leg_phase := 0
var prewarm_boss_frames := 2
var previous_kinds: Array[int] = []

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

func _ready() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color.WHITE
	shell.metallic = 0.58
	shell.roughness = 0.52
	shell.vertex_color_use_as_albedo = true
	shell.vertex_color_is_srgb = true
	shell.normal_enabled = true
	shell.normal_scale = 0.45
	shell.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")

	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(0.96, 0.02, 0.015)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.95, 0.01, 0.005)
	eye_mat.emission_energy_multiplier = 0.78

	var leg_shader := Shader.new()
	leg_shader.code = """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform float metallic : hint_range(0.0, 1.0) = 0.42;
uniform float roughness : hint_range(0.0, 1.0) = 0.74;

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

func build_boss_rig() -> void:
	var scene := load("res://assets/third_party/sketchfab/boss_spider/boss_spider.glb") as PackedScene
	boss_rig = scene.instantiate() as Node3D
	add_child(boss_rig)
	boss_leg_pivots.clear()
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
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.075
	lamp_mesh.height = 0.15
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = lamp_mesh
		lamp.material_override = eye_mat
		lamp.position = Vector3(side * 0.38, 1.2, 1.15)
		boss_rig.add_child(lamp)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color("d76a1b")
	stripe_mat.metallic = 0.35
	stripe_mat.roughness = 0.5
	for side in [-1.0, 1.0]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.12, 0.025, 0.65)
		stripe.mesh = stripe_mesh
		stripe.material_override = stripe_mat
		stripe.position = Vector3(side * 0.5, 2.06, -0.35)
		boss_rig.add_child(stripe)

func prepare_boss_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_overlay = boss_hit_overlay
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		prepare_boss_meshes(child)

func transform_at(base: Vector3, rotation: Basis, offset: Vector3, scale: Vector3) -> Transform3D:
	return Transform3D(rotation * Basis.from_scale(scale), base + rotation * offset)

func update_swarm(enemies: Array, player: Vector2, delta: float) -> void:
	time += delta
	leg_phase = 1 - leg_phase
	var count := mini(enemies.size(), CAPACITY)
	spider.multimesh.visible_instance_count = count
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

	for i in range(count):
		var e: Dictionary = enemies[i]
		var kind: int = e.kind
		var size := enemy_scale(kind)
		var pos := Vector3(e.pos.x / 50.0, 0.0, e.pos.y / 50.0)
		var yaw := atan2(player.x - e.pos.x, player.y - e.pos.y)
		var rotation := Basis(Vector3.UP, yaw)
		var flash: bool = e.get("flash", 0.0) > 0.0

		if previous_kinds.size() <= i:
			previous_kinds.append(-1)
		var kind_changed := previous_kinds[i] != kind
		previous_kinds[i] = kind
		var spider_hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos)
		if kind == 0:
			spider.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3.ZERO, Vector3.ONE * size))
			spider.multimesh.set_instance_color(i, Color.WHITE if flash else Color.BLACK)
			if kind_changed:
				for node in [bodies, heads, armor]:
					node.multimesh.set_instance_transform(i, spider_hidden)
				for k in range(3):
					seams.multimesh.set_instance_transform(i * 3 + k, spider_hidden)
				for k in range(4):
					eyes.multimesh.set_instance_transform(i * 4 + k, spider_hidden)
				for k in range(2):
					accents.multimesh.set_instance_transform(i * 2 + k, spider_hidden)
					guns.multimesh.set_instance_transform(i * 2 + k, spider_hidden)
				for k in range(16):
					legs.multimesh.set_instance_transform(i * 16 + k, spider_hidden)
					legs.multimesh.set_instance_color(i * 16 + k, Color(0, 0, 0, 0))
			continue
		if kind_changed:
			spider.multimesh.set_instance_transform(i, spider_hidden)

		if kind == 3:
			boss_rig.visible = true
			boss_rig.position = pos
			boss_rig.basis = rotation
			boss_hit_overlay.set_shader_parameter("hit", 1.0 if flash else 0.0)
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

		var base_color: Color = [Color("272d36"), Color("323842"), Color("2b3440"), Color("282e38")][kind]
		var plate_color: Color = [Color("404854"), Color("545e6c"), Color("465262"), Color("404854")][kind]
		var seam_color: Color = [Color("101318"), Color("14181f"), Color("12161d"), Color("12161c")][kind]
		var leg_tint: Color = [Color("3b4352"), Color("465060"), Color("3e4858"), Color("38404e")][kind]
		if flash:
			base_color = Color.WHITE
			plate_color = Color.WHITE
			seam_color = Color.WHITE
			leg_tint = Color.WHITE

		var width := 1.42 if kind == 1 else (1.04 if kind == 2 else 0.94)
		var body_len := 0.92 if kind == 1 else 0.76
		bodies.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3(0, 0.23, -0.10) * size, Vector3(0.72 * width, 0.30, body_len) * size))
		bodies.multimesh.set_instance_color(i, base_color)

		var head_w := 0.54 * width if kind == 1 else 0.44 * width
		heads.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3(0, 0.24, 0.29) * size, Vector3(head_w, 0.21, 0.34) * size))
		heads.multimesh.set_instance_color(i, base_color.lightened(0.06))

		var armor_h := 0.22 if kind == 1 else 0.16
		armor.multimesh.set_instance_transform(i, transform_at(pos, rotation, Vector3(0, 0.32, -0.10) * size, Vector3(0.58 * width, armor_h, body_len * 0.82) * size))
		armor.multimesh.set_instance_color(i, plate_color)

		var is_fresh: bool = e.get("fresh", true)
		var flash_changed: bool = e.get("was_flash", false) != flash
		if is_fresh or flash_changed or (i % 2 == leg_phase):
			e["fresh"] = false
			e["was_flash"] = flash
			for k in range(3):
				var panel_z := (-0.28 + float(k) * 0.17) * size
				seams.multimesh.set_instance_transform(i * 3 + k, transform_at(pos, rotation, Vector3(0, 0.38 * size, panel_z), Vector3(0.62 * width, 0.06, 0.045) * size))
				seams.multimesh.set_instance_color(i * 3 + k, seam_color)

			for j in range(4):
				var spread_x := (float(j) - 1.5) * 0.095 * width
				var curve_z := 0.45 - absf(float(j) - 1.5) * 0.025
				var eye_scale := 0.082 if (j == 1 or j == 2) else 0.065
				eyes.multimesh.set_instance_transform(i * 4 + j, transform_at(pos, rotation, Vector3(spread_x, 0.29, curve_z) * size, Vector3.ONE * eye_scale * size))

			accents.multimesh.set_instance_transform(i * 2, transform_at(pos, rotation, Vector3(0, 0.42, -0.12) * size, Vector3(0.08 * width, 0.025, 0.10) * size))
			var front_y := 0.56 if kind == 2 else 0.35
			var front_z := 0.12 if kind == 2 else 0.26
			accents.multimesh.set_instance_transform(i * 2 + 1, transform_at(pos, rotation, Vector3(0, front_y, front_z) * size, Vector3(0.11 * width, 0.025, 0.05) * size))

			var enemy_xform := Transform3D(rotation * Basis.from_scale(Vector3.ONE * size), pos)
			var leg_col := Color(leg_tint.r, leg_tint.g, leg_tint.b, 1.0)
			var off_col := Color(0, 0, 0, 0)
			var base_leg := i * 16
			for j in range(8):
				var used := kind != 1 or (j % 4) != 3
				var col := leg_col if used else off_col
				legs.multimesh.set_instance_transform(base_leg + j * 2, enemy_xform)
				legs.multimesh.set_instance_transform(base_leg + j * 2 + 1, enemy_xform)
				legs.multimesh.set_instance_color(base_leg + j * 2, col)
				legs.multimesh.set_instance_color(base_leg + j * 2 + 1, col)

			if kind == 2:
				guns.multimesh.set_instance_transform(i * 2, transform_at(pos, rotation, Vector3(0, 0.45, -0.02) * size, Vector3(0.32, 0.16, 0.36) * size))
				guns.multimesh.set_instance_color(i * 2, plate_color.lightened(0.12))
				guns.multimesh.set_instance_transform(i * 2 + 1, transform_at(pos, rotation, Vector3(0, 0.47, 0.28) * size, Vector3(0.18, 0.09, 0.58) * size))
				guns.multimesh.set_instance_color(i * 2 + 1, seam_color.lightened(0.15))
			else:
				var zero_gun := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos)
				guns.multimesh.set_instance_transform(i * 2, zero_gun)
				guns.multimesh.set_instance_transform(i * 2 + 1, zero_gun)
