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
var boss_leg_pivots: Array[Dictionary] = []
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

func add_part(parent: Node3D, mesh: Mesh, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, track_armor := false) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = size
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	if track_armor:
		boss_armor_meshes.append(inst)
	return inst

func build_boss_rig() -> void:
	boss_steel_mat.albedo_color = Color("949995")
	boss_steel_mat.metallic = 0.52
	boss_steel_mat.roughness = 0.54
	boss_steel_mat.albedo_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
	boss_steel_mat.normal_enabled = true
	boss_steel_mat.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")

	boss_trim_mat.albedo_color = Color("c64517")
	boss_trim_mat.metallic = 0.45
	boss_trim_mat.roughness = 0.48

	boss_dark_mat.albedo_color = Color("202630")
	boss_dark_mat.metallic = 0.65
	boss_dark_mat.roughness = 0.52

	boss_flash_mat.albedo_color = Color.WHITE
	boss_flash_mat.emission_enabled = true
	boss_flash_mat.emission = Color(1.0, 0.9, 0.85)
	boss_flash_mat.emission_energy_multiplier = 1.2

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.5
	cyl_mesh.bottom_radius = 0.5
	cyl_mesh.height = 1.0
	cyl_mesh.radial_segments = 12
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	sphere_mesh.radial_segments = 10
	sphere_mesh.rings = 5

	boss_rig = Node3D.new()
	boss_rig.visible = true
	add_child(boss_rig)

	# 1. Segmented Cephalothorax (Armored Mech Head + Mandibles + 6 Crimson Optics)
	add_part(boss_rig, box_mesh, Vector3(1.12, 0.42, 0.72), Vector3(0, 0.54, 0.94), boss_dark_mat)
	add_part(boss_rig, box_mesh, Vector3(0.98, 0.14, 0.62), Vector3(0, 0.78, 0.92), boss_steel_mat, Vector3(8, 0, 0), true)
	for side in [-1.0, 1.0]:
		add_part(boss_rig, box_mesh, Vector3(0.20, 0.30, 0.58), Vector3(side * 0.56, 0.56, 0.94), boss_steel_mat, Vector3(0, side * -8, 0), true)
		add_part(boss_rig, box_mesh, Vector3(0.14, 0.16, 0.44), Vector3(side * 0.34, 0.38, 1.36), boss_dark_mat, Vector3(0, side * -18, 0))
		add_part(boss_rig, box_mesh, Vector3(0.08, 0.08, 0.22), Vector3(side * 0.24, 0.38, 1.54), eye_mat, Vector3(0, side * -28, 0))
	for e_idx in range(6):
		var ex := (float(e_idx) - 2.5) * 0.15
		var ez := 1.30 - absf(float(e_idx) - 2.5) * 0.04
		var es := 0.12 if (e_idx == 2 or e_idx == 3) else 0.095
		add_part(boss_rig, sphere_mesh, Vector3.ONE * es, Vector3(ex, 0.62, ez), eye_mat)

	# 2. Central Armored Thorax Chassis (Mech-style layered plates + Orange-Red Trim + Reactor Core)
	add_part(boss_rig, box_mesh, Vector3(1.58, 0.52, 1.16), Vector3(0, 0.58, 0.12), boss_dark_mat)
	add_part(boss_rig, box_mesh, Vector3(1.40, 0.16, 0.98), Vector3(0, 0.88, 0.12), boss_steel_mat, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		add_part(boss_rig, box_mesh, Vector3(0.24, 0.36, 1.04), Vector3(side * 0.82, 0.64, 0.12), boss_steel_mat, Vector3(0, 0, side * -14), true)
		add_part(boss_rig, box_mesh, Vector3(0.20, 0.10, 0.74), Vector3(side * 0.62, 0.92, 0.16), boss_trim_mat)
		add_part(boss_rig, box_mesh, Vector3(0.06, 0.06, 0.78), Vector3(side * 0.74, 0.84, 0.12), eye_mat)
	add_part(boss_rig, cyl_mesh, Vector3(0.48, 0.14, 0.48), Vector3(0, 0.95, 0.18), boss_dark_mat)
	add_part(boss_rig, sphere_mesh, Vector3(0.32, 0.14, 0.32), Vector3(0, 0.98, 0.18), eye_mat)

	# 3. Multi-Segmented Abdomen (3 Armored Tail Segments with Plate Seams & Red Vent Strips)
	for seg in range(3):
		var z_pos := -0.62 - float(seg) * 0.48
		var y_pos := 0.62 - float(seg) * 0.04
		var w := 1.68 - float(seg) * 0.24
		var h := 0.48 - float(seg) * 0.05
		add_part(boss_rig, box_mesh, Vector3(w, h, 0.40), Vector3(0, y_pos, z_pos), boss_dark_mat)
		add_part(boss_rig, box_mesh, Vector3(w * 0.88, 0.14, 0.34), Vector3(0, y_pos + h * 0.52, z_pos), boss_steel_mat, Vector3(-4 * (seg + 1), 0, 0), true)
		add_part(boss_rig, box_mesh, Vector3(w * 0.72, 0.05, 0.05), Vector3(0, y_pos + h * 0.56, z_pos + 0.18), eye_mat)
		for side in [-1.0, 1.0]:
			add_part(boss_rig, box_mesh, Vector3(0.16, h * 0.75, 0.34), Vector3(side * (w * 0.52), y_pos + 0.04, z_pos), boss_steel_mat, Vector3(0, 0, side * -16), true)

	# 4. Twin Dorsal Heavy Turrets + Central Missile Pod (in Player Mech style)
	boss_turrets.clear()
	for side in [-1.0, 1.0]:
		var turret := Node3D.new()
		turret.position = Vector3(side * 0.58, 0.98, 0.22)
		boss_rig.add_child(turret)
		add_part(turret, cyl_mesh, Vector3(0.36, 0.14, 0.36), Vector3.ZERO, boss_dark_mat)
		add_part(turret, box_mesh, Vector3(0.38, 0.24, 0.52), Vector3(0, 0.16, 0.04), boss_steel_mat, Vector3.ZERO, true)
		add_part(turret, box_mesh, Vector3(0.42, 0.10, 0.32), Vector3(0, 0.18, -0.02), boss_trim_mat)
		add_part(turret, box_mesh, Vector3(0.20, 0.05, 0.26), Vector3(0, 0.30, 0.04), eye_mat)
		for b in [-1.0, 1.0]:
			add_part(turret, cyl_mesh, Vector3(0.09, 0.78, 0.09), Vector3(b * 0.10, 0.16, 0.52), boss_dark_mat, Vector3(90, 0, 0))
			add_part(turret, cyl_mesh, Vector3(0.12, 0.14, 0.12), Vector3(b * 0.10, 0.16, 0.86), boss_steel_mat, Vector3(90, 0, 0), true)
			add_part(turret, sphere_mesh, Vector3.ONE * 0.075, Vector3(b * 0.10, 0.16, 0.93), eye_mat)
		boss_turrets.append(turret)

	var pod := Node3D.new()
	pod.position = Vector3(0, 1.04, -0.58)
	pod.rotation_degrees = Vector3(14, 0, 0)
	boss_rig.add_child(pod)
	add_part(pod, box_mesh, Vector3(0.76, 0.38, 0.44), Vector3.ZERO, boss_dark_mat)
	add_part(pod, box_mesh, Vector3(0.84, 0.10, 0.48), Vector3(0, 0.21, 0), boss_steel_mat, Vector3.ZERO, true)
	for r_idx in range(6):
		var rx := (float(r_idx % 3) - 1.0) * 0.22
		var ry := (float(r_idx / 3) - 0.5) * 0.15
		add_part(pod, sphere_mesh, Vector3.ONE * 0.095, Vector3(rx, ry, 0.23), eye_mat)

	# 5. 8 Articulated Multi-Joint Spider-Mech Legs
	boss_leg_pivots.clear()
	for j in range(8):
		var side := -1.0 if j < 4 else 1.0
		var row := j % 4
		var z_off := (1.5 - float(row)) * 0.52 - 0.06
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.80, 0.48, z_off)
		boss_rig.add_child(hip)
		add_part(hip, cyl_mesh, Vector3(0.24, 0.20, 0.24), Vector3.ZERO, boss_dark_mat)
		add_part(hip, box_mesh, Vector3(0.28, 0.14, 0.28), Vector3(side * 0.08, 0.12, 0), boss_steel_mat, Vector3.ZERO, true)
		add_part(hip, sphere_mesh, Vector3.ONE * 0.085, Vector3(side * 0.14, 0.20, 0), eye_mat)

		var femur := Node3D.new()
		hip.add_child(femur)
		add_part(femur, box_mesh, Vector3(0.92, 0.18, 0.22), Vector3(side * 0.42, 0.28, 0), boss_dark_mat, Vector3(0, 0, side * 32))
		add_part(femur, box_mesh, Vector3(0.76, 0.10, 0.25), Vector3(side * 0.40, 0.36, 0), boss_steel_mat, Vector3(0, 0, side * 32), true)
		add_part(femur, box_mesh, Vector3(0.36, 0.06, 0.26), Vector3(side * 0.38, 0.40, 0), boss_trim_mat, Vector3(0, 0, side * 32))

		var knee := Node3D.new()
		knee.position = Vector3(side * 0.82, 0.56, 0)
		femur.add_child(knee)
		add_part(knee, cyl_mesh, Vector3(0.24, 0.26, 0.24), Vector3.ZERO, boss_dark_mat, Vector3(90, 0, 0))
		add_part(knee, sphere_mesh, Vector3.ONE * 0.12, Vector3(side * 0.06, 0.08, 0), eye_mat)

		var tibia := Node3D.new()
		knee.add_child(tibia)
		add_part(tibia, box_mesh, Vector3(0.18, 1.18, 0.18), Vector3(side * 0.28, -0.50, 0), boss_dark_mat, Vector3(0, 0, side * 26))
		add_part(tibia, box_mesh, Vector3(0.12, 0.86, 0.22), Vector3(side * 0.34, -0.44, 0), boss_steel_mat, Vector3(0, 0, side * 26), true)
		add_part(tibia, box_mesh, Vector3(0.30, 0.10, 0.36), Vector3(side * 0.56, -1.02, 0.04), boss_steel_mat, Vector3.ZERO, true)
		add_part(tibia, box_mesh, Vector3(0.12, 0.06, 0.12), Vector3(side * 0.58, -0.96, 0.18), eye_mat)

		var base_yaw := side * (float(row) - 1.5) * 0.26
		boss_leg_pivots.append({"hip": hip, "femur": femur, "knee": knee, "side": side, "row": row, "base_yaw": base_yaw})

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
			var target_mat: Material = boss_flash_mat if flash else boss_steel_mat
			for mesh_inst in boss_armor_meshes:
				mesh_inst.material_override = target_mat
			for leg_data in boss_leg_pivots:
				var s: float = leg_data.side
				var r: int = leg_data.row
				var phase := time * 8.5 + float(r) * 1.75 + s * 1.57
				var swing := sin(phase) * 0.22
				var lift := maxf(0.0, cos(phase)) * 0.18
				(leg_data.hip as Node3D).rotation.y = leg_data.base_yaw + swing * 0.65
				(leg_data.femur as Node3D).rotation.z = s * lift * 0.55
				(leg_data.knee as Node3D).rotation.z = -s * lift * 0.45
			boss_lights.multimesh.visible_instance_count = 8
			for j in range(8):
				var lx := (float(j % 4) - 1.5) * 0.28
				var lz := 0.35 - float(j / 4) * 0.85
				boss_lights.multimesh.set_instance_transform(j, transform_at(pos, rotation, Vector3(lx, 0.94, lz), Vector3.ONE * 0.11))
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
