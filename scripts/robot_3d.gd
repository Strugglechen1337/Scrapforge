extends Node3D
class_name Robot3D

var state: UpgradeState
var definitions: Dictionary = {}
var signature := ""
var chassis_id := "colossus"
var skin: Resource
var body_material: ShaderMaterial
var accent := StandardMaterial3D.new()
var metal := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var glow := StandardMaterial3D.new()
var visor_glow := StandardMaterial3D.new()
var sockets: Dictionary = {}
var parts: Node3D
var animation: AnimationPlayer
var clock := 0.0
var visor: MeshInstance3D
var model: Node3D
var chassis: Dictionary = {}
var chassis_skeleton: Skeleton3D
var chassis_bones: Dictionary = {}
var chassis_bone_rest: Dictionary = {}
var model_base_y := 0.956
var last_position := Vector3.ZERO
var motion := 0.0
var recoil := 0.0
var body_recoil := 0.0
var body_recoil_vel := 0.0
var last_facing_y := 0.0
var aim_yaw := 0.0
var previous_fire_clock := 0.0
var last_step_half := -1

func _ready() -> void:
	metal.albedo_color = Color("a9a39a")
	accent.albedo_color = Color("e97220")
	accent.metallic = 0.08
	accent.roughness = 0.72
	metal.metallic = 0.08
	metal.roughness = 0.72
	dark.albedo_color = Color("192431")
	dark.metallic = 0.68
	dark.roughness = 0.44
	glow.albedo_color = Color("e94e04")
	glow.emission_enabled = true
	glow.emission = Color("ff620d")
	glow.emission_energy_multiplier = 2.0
	visor_glow.albedo_color = Color("21dbea")
	visor_glow.emission_enabled = true
	visor_glow.emission = Color("31eaff")
	visor_glow.emission_energy_multiplier = 2.5
	animation = AnimationPlayer.new()
	var library := AnimationLibrary.new()
	var walk := Animation.new()
	walk.length = 1.0
	walk.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("Walk", walk)
	animation.add_animation_library("", library)
	add_child(animation)
	animation.play("Walk")
	parts = Node3D.new()
	add_child(parts)
	_build_chassis("colossus")
	set_skin(load("res://data/skins/standard.tres"))
	set_robot_layer(self)

func _build_chassis(id: String) -> void:
	if is_instance_valid(visor):
		visor.get_parent().remove_child(visor)
		visor.queue_free()
		visor = null
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	chassis.clear()
	sockets.clear()
	chassis_skeleton = null
	chassis_bones.clear()
	chassis_bone_rest.clear()
	if id in ["vanguard", "bastion_mech"]:
		model_base_y = 0.0
		var glb_path := "res://assets/third_party/sketchfab/vanguard/vanguard.glb" if id == "vanguard" else "res://assets/third_party/sketchfab/bastion/bastion.glb"
		model = (load(glb_path) as PackedScene).instantiate() as Node3D
		add_child(model)
		var skels := model.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			chassis_skeleton = skels[0] as Skeleton3D
			var socket_map: Array = [
				["left_arm", "arm_pivot_left_09", Vector3.ZERO],
				["right_arm", "arm_pivot_right_05", Vector3.ZERO],
				["left_shoulder", "shoulder_left_07", Vector3(0.18, 0.14, 0.0)],
				["right_shoulder", "shoulder_right_03", Vector3(-0.18, 0.14, 0.0)],
				["head", "neck_01", Vector3(0.0, 0.18, 0.22)],
				["back", "hull_00", Vector3(0.0, 0.22, -0.45)],
				["legs", "hip_011", Vector3(0.0, -0.22, 0.0)],
				["core", "core_02", Vector3(0.0, 0.05, 0.15)],
			] if id == "vanguard" else [
				["left_arm", "Gun_L_04", Vector3.ZERO],
				["right_arm", "Gun_R_07", Vector3.ZERO],
				["left_shoulder", "Arm_L_02", Vector3(0.14, 0.18, 0.0)],
				["right_shoulder", "Arm_R_05", Vector3(-0.14, 0.18, 0.0)],
				["head", "Camera_08", Vector3(0.0, 0.16, 0.20)],
				["back", "Root_01", Vector3(0.0, 0.22, -0.45)],
				["legs", "Root_01", Vector3(0.0, -0.22, 0.0)],
				["core", "Root_01", Vector3(0.0, 0.12, 0.22)],
			]
			for entry in socket_map:
				var ba := BoneAttachment3D.new()
				ba.bone_name = entry[1]
				chassis_skeleton.add_child(ba)
				sockets[entry[0]] = make_marker(ba, entry[0], entry[2])
			var bone_map: Dictionary = {
				"thigh_l": "thigh_left_023",
				"thigh_r": "thigh_right_012",
				"shin_l": "leg_left_025",
				"shin_r": "leg_right_014",
				"arm_l": "arm_swing_left_08",
				"arm_r": "arm_swing_right_04",
				"torso": "hull_00",
			} if id == "vanguard" else {
				"thigh_l": "Top_Leg_L_09",
				"thigh_r": "Top_Leg_R_023",
				"shin_l": "Low_Leg_L_014",
				"shin_r": "Mid_Leg_R_00",
				"arm_l": "Arm_L_02",
				"arm_r": "Arm_R_05",
				"torso": "Root_01",
			}
			for key in bone_map:
				var idx := chassis_skeleton.find_bone(bone_map[key])
				if idx >= 0:
					chassis_bones[key] = idx
					chassis_bone_rest[key] = chassis_skeleton.get_bone_pose_rotation(idx)
	else:
		model_base_y = 0.956
		model = (load("res://assets/third_party/sketchfab/colossus/colossus-parts.glb") as PackedScene).instantiate() as Node3D
		model.position.y = model_base_y
		add_child(model)
		for part_name in ["torso", "head", "shoulder_l", "shoulder_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
			var node := model.find_child(part_name, true, false) as MeshInstance3D
			chassis[part_name] = node
		var original := (chassis["torso"] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		body_material = ShaderMaterial.new()
		body_material.shader = load("res://scripts/colossus_paint.gdshader")
		body_material.set_shader_parameter("base_texture", original.albedo_texture)
		body_material.set_shader_parameter("normal_texture", original.normal_texture)
		body_material.set_shader_parameter("paint_mask", load("res://assets/models/colossus_paint_mask.png"))
		for part_name in chassis:
			var node: MeshInstance3D = chassis[part_name]
			node.material_override = body_material
			node.set_instance_shader_parameter("orange_panel", 1.0 if part_name in ["shoulder_l", "shoulder_r", "thigh_l", "thigh_r"] else 0.0)
			node.set_instance_shader_parameter("chest_panel", 1.0 if part_name == "torso" else 0.0)
			if part_name != "torso": node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for entry in [
			["left_arm", "forearm_l", Vector3(-0.12, -0.12, 0.08)],
			["right_arm", "forearm_r", Vector3(0.18, 0.02, 0.08)],
			["left_shoulder", "shoulder_l", Vector3(-0.10, 0.13, 0.0)],
			["right_shoulder", "shoulder_r", Vector3(0.10, 0.13, 0.0)],
			["head", "head", Vector3(0, 0.12, 0.25)],
			["back", "torso", Vector3(0, 0.20, -0.34)],
			["legs", "torso", Vector3(0, -0.20, 0)],
			["core", "torso", Vector3(0, 0.10, 0.22)]]:
			sockets[entry[0]] = make_marker(chassis[entry[1]], entry[0], entry[2])
	visor = MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.24, 0.055, 0.035)
	visor.mesh = visor_mesh
	visor.material_override = visor_glow
	sockets["head"].add_child(visor)
	set_robot_layer(model)
	if skin:
		set_skin(skin)

func make_marker(parent: Node3D, marker_name: String, offset: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = offset
	marker.set_meta("rest_basis", Basis.IDENTITY)
	parent.add_child(marker)
	return marker

func set_skin(value: Resource) -> void:
	skin = value
	if not skin: return
	metal.albedo_color = skin.armor_color * Color(0.55, 0.55, 0.55)
	accent.albedo_color = skin.accent_color
	if body_material:
		body_material.set_shader_parameter("paint_color", skin.armor_color)
		body_material.set_shader_parameter("accent_color", skin.accent_color)
		var pat_name: String = skin.pattern if "pattern" in skin else ("camo" if skin.camouflage else "stripes")
		var pat_mode := 0
		match pat_name:
			"hazard": pat_mode = 1
			"camo": pat_mode = 2
			"camo_hazard": pat_mode = 3
			_: pat_mode = 2 if skin.camouflage else 0
		body_material.set_shader_parameter("pattern_mode", pat_mode)
		var unit_str: String = skin.unit_number if "unit_number" in skin else "01"
		body_material.set_shader_parameter("unit_index", clampi(unit_str.to_int(), 0, 99))
	# A reusable, deterministic paint-wear mask: chipped edges and fine scratches.
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47021
	for y in range(256):
		for x in range(256):
			var pattern := sin(float(x) * 0.07 + sin(float(y) * 0.04) * 2.0) + cos(float(y) * 0.06 + float(x) * 0.025)
			var shade := 0.65 if skin.camouflage and pattern > 0.8 else 1.0
			var edge := mini(mini(x, 255 - x), mini(y, 255 - y))
			if edge < 9 and rng.randf() < (9.0 - edge) * 0.018: shade = rng.randf_range(0.35, 0.62)
			image.set_pixel(x, y, Color(shade, shade, shade, 1))
	for i in range(95):
		var x := rng.randi_range(3, 244)
		var y := rng.randi_range(3, 252)
		var length := rng.randi_range(2, 11)
		var shade := rng.randf_range(0.42, 0.78)
		for j in range(length):
			image.set_pixel(x + j, y + int(j / 5), Color(shade, shade, shade, 1))
	var wear := ImageTexture.create_from_image(image)
	metal.albedo_texture = wear
	accent.albedo_texture = wear

func set_robot_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = 2
	for child in node.get_children(): set_robot_layer(child)

func set_chassis(id: String) -> void:
	if id not in ChassisCatalog.CHASSIS_IDS:
		id = "colossus"
	if chassis_id == id:
		return
	chassis_id = id
	scale = ChassisCatalog.model_scale(id)
	_build_chassis(id)
	signature = ""
	refresh()


func refresh() -> void:
	if not state or not is_instance_valid(parts): return
	var next := chassis_id + "|" + str(state.levels)
	if next == signature: return
	signature = next
	for child in parts.get_children():
		parts.remove_child(child)
		child.queue_free()
	for id in definitions:
		var definition: UpgradeDefinition = definitions[id]
		var level := state.level(id)
		if level == 0 or not definition.visual_script or not sockets.has(definition.socket): continue
		var module: Node3D = definition.visual_script.new()
		parts.add_child(module)
		var socket_name: String = state.arm_socket(id) if (id in state.ARM_WEAPONS or id in state.EVOLVED_ARM_WEAPONS) else definition.socket
		module.set_meta("socket", socket_name)
		module.set_meta("module_id", id)
		module.set_meta("level", level)
		module.build(id, level, metal, dark, glow, accent)
		set_robot_layer(module)
		if id == "swarm":
			var other: Node3D = definition.visual_script.new()
			parts.add_child(other)
			other.set_meta("socket", "left_shoulder")
			other.set_meta("module_id", id)
			other.set_meta("level", level)
			other.build(id, level, metal, dark, glow, accent)
			set_robot_layer(other)
	var mod_script := preload("res://scripts/module_visual_3d.gd")
	if chassis_id == "vanguard":
		for side_sock in ["left_shoulder", "right_shoulder"]:
			var fin_mod: Node3D = mod_script.new()
			parts.add_child(fin_mod)
			fin_mod.set_meta("socket", side_sock)
			fin_mod.set_meta("module_id", "chassis_fin")
			fin_mod.set_meta("level", 1)
			fin_mod.build("thruster", 4, metal, dark, glow, accent)
			set_robot_layer(fin_mod)
	elif chassis_id == "bastion_mech":
		for side_sock in ["left_shoulder", "right_shoulder"]:
			var plate_mod: Node3D = mod_script.new()
			parts.add_child(plate_mod)
			plate_mod.set_meta("socket", side_sock)
			plate_mod.set_meta("module_id", "chassis_plate")
			plate_mod.set_meta("level", 1)
			plate_mod.build("armor", 5, metal, dark, glow, accent)
			set_robot_layer(plate_mod)
	update_parts()

func update_parts() -> void:
	for part in parts.get_children():
		var mod_id: String = part.get_meta("module_id")
		var sock_name: String = "left_arm" if mod_id in ["saw", "shredder"] else str(part.get_meta("socket"))
		var socket: Marker3D = sockets[sock_name]
		follow_bone(part, socket, true)
		if mod_id in ["saw", "shredder"]:
			part.position += part.basis.orthonormalized() * Vector3(-0.18, -0.08, 0.02)
		if mod_id in ["minigun", "laser", "rocket", "turret", "swarm", "vulcan", "prism_laser", "inferno", "singularity", "bastion", "hive_drone"]:
			part.scale *= 1.4 * (1.0 + 0.075 * (int(part.get_meta("level")) - 1))
		if part.get_meta("socket") in ["left_shoulder", "right_shoulder"]:
			var side := 1.0 if part.get_meta("socket") == "left_shoulder" else -1.0
			part.position += part.basis.orthonormalized() * Vector3(side * 0.36, 0.13, 0)

func follow_bone(part: Node3D, marker: Marker3D, weapon: bool) -> void:
	var local_transform := global_transform.affine_inverse() * marker.global_transform
	var rest_basis: Basis = marker.get_meta("rest_basis")
	var delta_basis := local_transform.basis.orthonormalized() * rest_basis.inverse()
	part.transform = Transform3D((delta_basis * Basis(Vector3.UP, PI if weapon else 0.0)).scaled(Vector3.ONE * (0.8 if weapon else 1.0)), local_transform.origin)

func trigger_weapon_fire(weapon_id: String, strength := 1.0) -> void:
	var alias := {
		"vulcan": "minigun",
		"prism_laser": "laser",
		"inferno": "flamethrower",
		"singularity": "plasma",
		"bastion": "turret",
		"hive_drone": "drone",
		"shredder": "saw",
	}
	var base_id: String = alias.get(weapon_id, weapon_id)
	for part in parts.get_children():
		var mid: String = str(part.get_meta("module_id"))
		var m_base: String = alias.get(mid, mid)
		if (mid == weapon_id or m_base == base_id) and part.has_method("trigger_fire"):
			part.trigger_fire(strength)
	if base_id in ["rocket", "turret", "plasma", "laser", "minigun"]:
		var body_impulse := 0.55 if base_id in ["rocket", "turret"] else (0.35 if base_id in ["plasma", "laser"] else 0.16)
		body_recoil = clampf(body_recoil + body_impulse * strength, 0.0, 1.0)

func _process(delta: float) -> void:
	clock += delta
	var speed := global_position.distance_to(last_position) / maxf(delta, 0.001)
	last_position = global_position
	motion = move_toward(motion, clampf(speed / 1.5, 0.0, 1.0), delta * 5.0)
	if get_parent() is ScrapWorld3D:
		var game = get_parent().game
		if game and game.mode == "playing":
			if game.fire_clock > previous_fire_clock + 0.04 and state and not state.levels.is_empty():
				recoil = 1.0
			previous_fire_clock = game.fire_clock
	recoil = move_toward(recoil, 0.0, delta * 6.0)
	var yaw_delta := wrapf(rotation.y - last_facing_y, -PI, PI)
	last_facing_y = rotation.y
	aim_yaw = lerpf(aim_yaw, clampf(yaw_delta * 3.5, -0.26, 0.26), minf(1.0, delta * 10.0))
	body_recoil_vel += (-body_recoil * 90.0 - body_recoil_vel * 14.0) * delta
	body_recoil = clampf(body_recoil + body_recoil_vel * delta, -0.2, 1.0)
	if animation.is_playing():
		var stride := sin(clock * 7.0) * motion
		var lean := motion * 0.05 - body_recoil * 0.09
		var sway := sin(clock * 3.5) * motion * 0.035
		if get_parent() is ScrapWorld3D and motion > 0.25:
			var game = get_parent().game
			if game and game.mode == "playing":
				var step_half := int(floor(clock * 7.0 / PI))
				if step_half != last_step_half:
					last_step_half = step_half
					var am := get_node_or_null("/root/AudioManager")
					if am: am.play(&"mech_step", game.player)
		if chassis_skeleton and not chassis_bones.is_empty():
			var pose := func(key: String, rot: Vector3) -> void:
				if chassis_bones.has(key):
					chassis_skeleton.set_bone_pose_rotation(chassis_bones[key], chassis_bone_rest[key] * Quaternion.from_euler(rot))
			pose.call("thigh_l", Vector3(stride * 0.34, 0, 0))
			pose.call("thigh_r", Vector3(-stride * 0.34, 0, 0))
			pose.call("shin_l", Vector3(maxf(0.0, -stride) * 0.28, 0, 0))
			pose.call("shin_r", Vector3(maxf(0.0, stride) * 0.28, 0, 0))
			pose.call("arm_l", Vector3(-stride * 0.14 - recoil * 0.12, 0, 0))
			pose.call("arm_r", Vector3(stride * 0.14 - recoil * 0.12, 0, 0))
			pose.call("torso", Vector3(lean, aim_yaw, sway))
		elif not chassis.is_empty():
			(chassis["thigh_l"] as Node3D).rotation.x = stride * 0.32
			(chassis["thigh_r"] as Node3D).rotation.x = -stride * 0.32
			(chassis["shin_l"] as Node3D).rotation.x = maxf(0.0, -stride) * 0.25
			(chassis["shin_r"] as Node3D).rotation.x = maxf(0.0, stride) * 0.25
			(chassis["upper_arm_l"] as Node3D).rotation.x = -stride * 0.12 - recoil * 0.13
			(chassis["upper_arm_r"] as Node3D).rotation.x = stride * 0.12 - recoil * 0.13
			(chassis["torso"] as Node3D).rotation = Vector3(lean, aim_yaw, sway)
		model.position.x = sin(clock * 3.5) * motion * 0.03
		model.position.y = model_base_y + absf(sin(clock * 7.0)) * motion * 0.025 + sin(clock * 1.8) * 0.006 - absf(body_recoil) * 0.032
		model.position.z = -body_recoil * 0.05
	for part in parts.get_children():
		if "move_intensity" in part:
			part.move_intensity = motion
	refresh()
	update_parts()
