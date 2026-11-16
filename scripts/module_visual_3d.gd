extends Node3D

const SAW_RADIUS := 1.18
const SAW_HEIGHT := 1.02
const SAW_ORBIT_SPEED := 1.8
const SAW_SPIN_SPEED := 14.0

static var plates_normal: Texture2D
static var plates_roughness: Texture2D

var animated: Array[Node3D] = []
var blades: Array[Node3D] = []
var orbiters: Array[Node3D] = []
var time := 0.0
var mat_map: Dictionary = {}
var blade_radius := SAW_RADIUS
var blade_orbit_speed := SAW_ORBIT_SPEED

func _ensure_pbr_textures() -> void:
	if plates_normal == null:
		plates_normal = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
	if plates_roughness == null:
		plates_roughness = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")

func _pbr_variant(base: Material, metallic_val: float, rough_val: float) -> StandardMaterial3D:
	_ensure_pbr_textures()
	var mat := (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
	mat.metallic = metallic_val
	mat.roughness = rough_val
	mat.normal_enabled = true
	mat.normal_texture = plates_normal
	mat.normal_scale = 0.65
	mat.roughness_texture = plates_roughness
	return mat

func add_model(id: String, size := 1.0, offset := Vector3.ZERO, rot_deg := Vector3.ZERO, node_name := "") -> Node3D:
	var packed := load("res://assets/models/modules/" + id + ".glb") as PackedScene
	var model := packed.instantiate() as Node3D
	model.name = node_name if not node_name.is_empty() else "asset_" + id
	model.position = offset
	model.rotation_degrees = rot_deg
	model.scale = Vector3.ONE * size
	add_child(model)
	_apply_materials(model)
	return model

func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.get_active_material(surface)
			if original and mat_map.has(original.resource_name):
				mesh_node.set_surface_override_material(surface, mat_map[original.resource_name])
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_materials(child)

func drone(parent: Node3D) -> Node3D:
	var body := add_sketchfab("drone", 0.34)
	if parent != self:
		body.reparent(parent)
	return body

func add_sketchfab(id: String, size: float, offset := Vector3.ZERO) -> Node3D:
	var packed := load("res://assets/third_party/sketchfab/modules/" + id + ".glb") as PackedScene
	var model := packed.instantiate() as Node3D
	model.name = "asset_" + id
	model.position = offset
	model.scale = Vector3.ONE * size
	add_child(model)
	tint_asset(model)
	return model

func tint_asset(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.get_active_material(surface) as StandardMaterial3D
			if original:
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color *= Color(0.82, 0.79, 0.74)
				material.roughness = maxf(material.roughness, 0.58)
				mesh_node.set_surface_override_material(surface, material)
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		tint_asset(child)

func exhaust(pos: Vector3, is_cyan: bool) -> void:
	var flame: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat := CombatEffects3D.soft_material(true)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.25, 0.92, 1.0, 0.85) if is_cyan else Color(1.0, 0.52, 0.12, 0.85)
	quad.material = mat
	if flame is GPUParticles3D:
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.DOWN
		process.spread = 15
		process.initial_velocity_min = 0.4
		process.initial_velocity_max = 1.0
		process.gravity = Vector3.ZERO
		flame.process_material = process
		flame.draw_pass_1 = quad
	else:
		flame.mesh = quad
		flame.direction = Vector3.DOWN
		flame.spread = 15
		flame.initial_velocity_min = 0.4
		flame.initial_velocity_max = 1.0
		flame.gravity = Vector3.ZERO
	flame.amount = 3 if OS.has_feature("mobile") else 6
	flame.lifetime = 0.35
	flame.position = pos
	add_child(flame)

func build(id: String, level: int, metal: Material, dark: Material, glow: Material, accent: Material = null) -> void:
	if accent == null:
		accent = metal
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color("087b83")
	cyan.emission_enabled = true
	cyan.emission = Color("15cbd4")
	cyan.emission_energy_multiplier = 1.2
	var sensor_red := StandardMaterial3D.new()
	sensor_red.albedo_color = Color("d50913")
	sensor_red.emission_enabled = true
	sensor_red.emission = Color("ff1020")
	sensor_red.emission_energy_multiplier = 1.6
	mat_map = {
		"mat_metal": _pbr_variant(metal, 0.35, 0.62),
		"mat_dark": _pbr_variant(dark, 0.72, 0.44),
		"mat_accent": _pbr_variant(accent, 0.25, 0.58),
		"mat_glow": glow,
		"mat_cyan": cyan,
		"mat_red": sensor_red,
	}
	var evo_base := {
		"vulcan": "minigun",
		"prism_laser": "laser",
		"inferno": "flamethrower",
		"singularity": "plasma",
		"bastion": "turret",
		"hive_drone": "drone",
	}
	var is_evo := id in evo_base or id in ["swarm", "shredder"]
	if id in evo_base:
		id = evo_base[id]
		level = 5
	if is_evo:
		var evo_glow := StandardMaterial3D.new()
		evo_glow.albedo_color = Color("c65cff")
		evo_glow.emission_enabled = true
		evo_glow.emission = Color("c65cff")
		evo_glow.emission_energy_multiplier = 2.2
		mat_map["mat_glow"] = evo_glow
	match id:
		"laser":
			add_sketchfab("laser", 1.0)
			add_model("mount_bracket", 0.85, Vector3(0, 0, 0.08))
			for i in range(maxi(0, level - 1)):
				add_model("laser_coil", 0.85, Vector3(0, 0.02, -0.05 - i * 0.12), Vector3.ZERO, "coil_" + str(i))
		"minigun":
			add_sketchfab("minigun", 1.05)
			add_model("mount_bracket", 0.85, Vector3(0, 0, 0.08))
			if level >= 2:
				add_model("armor_plate", 0.7, Vector3(0, 0.16, -0.04), Vector3(90, 0, 0), "shield_top")
			if level >= 3:
				add_model("gun_drum", 0.95, Vector3.ZERO, Vector3.ZERO, "drum_1")
			if level >= 4:
				add_sketchfab("minigun", 0.65, Vector3(0.16, -0.18, 0))
			if level >= 5:
				add_model("gun_drum", 0.95, Vector3(0.32, -0.18, 0), Vector3(0, 180, 0), "drum_2")
		"rocket":
			add_sketchfab("rocket", 0.90 + 0.08 * (level - 1))
		"swarm":
			add_sketchfab("rocket", 0.8)
			add_model("swarm_pod", 0.65, Vector3(0, 0.02, -0.14), Vector3.ZERO, "pod")
		"flamethrower":
			add_model("flamethrower", 1.0)
			add_model("mount_bracket", 0.85, Vector3(0, 0, 0.08))
			add_model("flamethrower_tank", 0.95, Vector3(-0.19, -0.02, 0.02), Vector3.ZERO, "tank_1")
			if level >= 2:
				add_model("laser_coil", 0.85, Vector3(0, 0.04, -0.25), Vector3.ZERO, "shroud")
			if level >= 3:
				add_model("flamethrower_tank", 0.95, Vector3(0.19, -0.02, 0.02), Vector3.ZERO, "tank_2")
			if level >= 4:
				add_model("armor_plate", 0.75, Vector3(0, 0.16, -0.02), Vector3(90, 0, 0), "heat_shield")
			if level >= 5:
				add_model("flamethrower", 0.72, Vector3(0.14, -0.14, -0.05), Vector3.ZERO, "flamer_aux")
			exhaust(Vector3(0, 0, -0.82), false)
		"plasma":
			add_model("plasma", 1.0)
			add_model("mount_bracket", 0.85, Vector3(0, 0, 0.08))
			for i in range(maxi(0, level - 1)):
				add_model("plasma_coil", 0.95, Vector3(0, 0, -0.22 - i * 0.14), Vector3.ZERO, "coil_" + str(i))
		"turret":
			add_sketchfab("turret", 0.85 + 0.04 * (level - 1))
			add_model("turret_pod", 0.95 + 0.06 * (level - 1), Vector3(0, -0.02, 0.0), Vector3.ZERO, "pod")
			if level >= 2:
				add_model("gun_drum", 0.75, Vector3(0, 0.06, 0.05), Vector3.ZERO, "feed")
			if level >= 3:
				add_model("armor_plate", 0.7, Vector3(-0.22, 0.08, -0.04), Vector3(0, 90, 0), "cheek_l")
			if level >= 4:
				add_model("armor_plate", 0.7, Vector3(0.22, 0.08, -0.04), Vector3(0, -90, 0), "cheek_r")
			if level >= 5:
				add_sketchfab("turret", 0.55, Vector3(0.22, 0.12, -0.02))
		"sensor":
			add_sketchfab("sensor", 1.0)
			if level >= 2:
				add_model("sensor_pod", 0.9, Vector3(-0.20, 0.14, 0.02), Vector3.ZERO, "pod_l")
			if level >= 3:
				add_model("radar_array", 0.75, Vector3(0, -0.06, 0.02), Vector3.ZERO, "sweep")
			if level >= 4:
				add_model("sensor_pod", 0.9, Vector3(0.20, 0.14, 0.02), Vector3.ZERO, "pod_r")
			if level >= 5:
				add_model("armor_plate", 0.7, Vector3(0, 0.24, 0.04), Vector3(75, 0, 0), "brow")
		"drone":
			add_model("drone_dock", 1.0, Vector3.ZERO, Vector3.ZERO, "dock")
			if level >= 3:
				add_model("magnet_coil", 0.7, Vector3(-0.20, 0.08, 0.06), Vector3.ZERO, "relay_l")
			if level >= 5:
				add_model("magnet_coil", 0.7, Vector3(0.20, 0.08, 0.06), Vector3.ZERO, "relay_r")
			for i in range(1 + int(level / 2)):
				var d := add_sketchfab("drone", 0.42 + level * 0.03)
				d.position = Vector3((i * 2 - 1) * 0.7, 0.5, 0)
				orbiters.append(d)
		"armor":
			add_model("armor", 1.0)
			var offsets := [
				Vector3(-0.22, 0.08, 0.10),
				Vector3(0.22, 0.08, 0.10),
				Vector3(-0.20, -0.10, 0.08),
				Vector3(0.20, -0.10, 0.08),
			]
			for i in range(mini(level - 1, offsets.size())):
				add_model("armor_plate", 0.95, offsets[i], Vector3(0, -18 if i % 2 == 0 else 18, 0), "plate_" + str(i))
		"magnet":
			add_model("magnet", 1.0)
			var coil_pos := [
				Vector3(-0.24, 0.0, 0.08),
				Vector3(0.24, 0.0, 0.08),
				Vector3(-0.24, 0.14, 0.06),
				Vector3(0.24, 0.14, 0.06),
			]
			var count := 0 if level < 2 else (2 if level < 4 else 4)
			for i in range(count):
				add_model("magnet_coil", 0.9, coil_pos[i], Vector3.ZERO, "mcoil_" + str(i))
		"cooldown":
			add_model("cooldown", 1.0)
			if level >= 2:
				add_model("cooldown_tank", 0.95, Vector3(-0.25, 0.0, 0.0), Vector3.ZERO, "ctank_l")
			if level >= 4:
				add_model("cooldown_tank", 0.95, Vector3(0.25, 0.0, 0.0), Vector3.ZERO, "ctank_r")
		"radar":
			var dish := add_sketchfab("radar", 0.95 + level * 0.05)
			animated.append(dish)
			if level >= 3:
				var arr := add_model("radar_array", 1.0, Vector3.ZERO, Vector3.ZERO, "array")
				animated.append(arr)
			for i in range(int(level / 2)):
				var d := drone(self)
				d.position = Vector3((i * 2 - 1) * 0.7, 0.5, 0)
				orbiters.append(d)
		"thruster":
			add_sketchfab("thruster", 0.95 + level * 0.05)
			if level >= 3:
				add_model("thruster_fin", 0.95 + level * 0.03, Vector3.ZERO, Vector3.ZERO, "fins")
			for side in [-1, 1]:
				exhaust(Vector3(side * 0.29, -0.35, 0.03), true)
		"saw", "shredder":
			var blade_count := 6 if id == "shredder" else level
			blade_radius = SAW_RADIUS * (1.38 if id == "shredder" else 1.0)
			blade_orbit_speed = SAW_ORBIT_SPEED * (1.44 if id == "shredder" else 1.0)
			for i in range(blade_count):
				var pivot := Node3D.new()
				var angle := TAU * i / blade_count
				pivot.position = Vector3(cos(angle) * blade_radius, SAW_HEIGHT, sin(angle) * blade_radius)
				add_child(pivot)
				var blade := add_sketchfab("saw", 1.35 if id == "shredder" else 1.15)
				blade.name = "asset_saw" if i == 0 else "saw_" + str(i)
				blade.rotation_degrees = Vector3(10, 0, 0)
				blade.reparent(pivot)
				blade.position = Vector3.ZERO
				blades.append(pivot)
		"shield":
			add_sketchfab("shield", 0.42 + 0.025 * level, Vector3(0, 0, 0.1))
			add_model("shield_emitter", 1.05, Vector3(0, 0, -0.32), Vector3.ZERO, "emitter")
			for i in range(level):
				var a := TAU * i / maxf(level, 1)
				var pylon := add_model("shield_pylon", 0.9, Vector3(cos(a) * 0.36, sin(a) * 0.36, -0.30), Vector3(0, 0, rad_to_deg(a) - 90), "pylon_" + str(i))
				pylon.name = "pylon_" + str(i)

func _process(delta: float) -> void:
	time += delta
	for n in animated:
		n.rotate_y(delta * 3.2)
	for i in range(blades.size()):
		var angle := time * blade_orbit_speed + TAU * i / blades.size()
		blades[i].position = Vector3(cos(angle) * blade_radius, SAW_HEIGHT, sin(angle) * blade_radius)
		if blades[i].get_child_count() > 0:
			blades[i].get_child(0).rotate_y(delta * SAW_SPIN_SPEED)
	for i in range(orbiters.size()):
		var angle := time * 1.1 + TAU * i / orbiters.size()
		orbiters[i].position = Vector3(cos(angle) * 0.55, 0.45, sin(angle) * 0.40)
