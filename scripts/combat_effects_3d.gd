extends Node3D
class_name CombatEffects3D

const MAX_BURSTS := 20
const MAX_LABELS := 32
const MAX_LIGHTS := 8
const MAX_MUZZLES := 16
const MAX_SHELLS := 32
const MAX_MUZZLE_SMOKE := 12
const SMOKE_PARTICLES := 8
const MUZZLE_TIME := 0.075
var orange := StandardMaterial3D.new()
var hot_core := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var burst_pool: Array[Dictionary] = []
var label_pool: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var light_count := 0
var light_pool: Array[OmniLight3D] = []
var muzzle_pool: Array[Dictionary] = []
var shell_pool: Array[Dictionary] = []
var smoke_pool: Array[Dictionary] = []
var minigun_light_cooldown := 0.0
var orange_particles: SphereMesh
var cyan_particles: SphereMesh

func _ready() -> void:
	orange.albedo_color = Color("ff9326")
	orange.emission_enabled = true
	orange.emission = Color("ff6508")
	orange.emission_energy_multiplier = 2.8
	hot_core.albedo_color = Color("fff2b8")
	hot_core.emission_enabled = true
	hot_core.emission = Color("ff8c1a")
	hot_core.emission_energy_multiplier = 3.6
	cyan.albedo_color = Color("66fbff")
	cyan.emission_enabled = true
	cyan.emission = Color("13e6ef")
	cyan.emission_energy_multiplier = 1.6
	dark.albedo_color = Color("282e36")
	dark.metallic = 0.75
	dark.roughness = 0.42
	var draw := SphereMesh.new()
	draw.radius = 0.065
	draw.height = 0.13
	draw.material = orange
	orange_particles = draw
	cyan_particles = draw.duplicate()
	cyan_particles.material = cyan
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.24
	orb_mesh.height = 0.48
	var scrap_mesh := BoxMesh.new()
	scrap_mesh.size = Vector3(0.14, 0.08, 0.18)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 4.6
	process.gravity = Vector3(0, -5.0, 0)
	if not OS.has_feature("mobile"):
		setup_weapon_pools()
	for i in range(MAX_BURSTS):
		var holder := Node3D.new()
		add_child(holder)
		var spark: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
		if OS.has_feature("mobile"): spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(spark)
		if spark is GPUParticles3D:
			spark.process_material = process
			spark.draw_pass_1 = draw
		else:
			spark.mesh = draw
			spark.direction = Vector3.UP
			spark.spread = 180
			spark.initial_velocity_min = 1.4
			spark.initial_velocity_max = 4.6
			spark.gravity = Vector3(0, -5.0, 0)
		spark.amount = 9 if OS.has_feature("mobile") else 18
		spark.lifetime = 0.45
		spark.one_shot = true
		spark.explosiveness = 0.95
		spark.emitting = false
		var lamp: OmniLight3D = null
		if OS.has_feature("mobile"):
			lamp = OmniLight3D.new()
			lamp.light_color = Color("ff7b1c")
			lamp.light_energy = 2.2
			lamp.omni_range = 3.2
			lamp.visible = false
			holder.add_child(lamp)
		var orb := MeshInstance3D.new()
		orb.mesh = orb_mesh
		orb.material_override = hot_core
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(orb)
		var debris: Array[Dictionary] = []
		for j in range(4):
			var piece := MeshInstance3D.new()
			piece.mesh = scrap_mesh
			piece.material_override = dark
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(piece)
			debris.append({"node": piece, "velocity": Vector3.ZERO})
		holder.visible = false
		burst_pool.append({"node": holder, "spark": spark, "lamp": lamp, "orb": orb, "debris": debris, "active": false, "light_on": false})
	for i in range(MAX_LABELS):
		var label := Label3D.new()
		label.font_size = 38
		label.outline_size = 7
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.visible = false
		add_child(label)
		label_pool.append({"node": label, "active": false})
	call_deferred("prewarm")

# PC-only pools; existing explosion lights share the same eight slots.
func setup_weapon_pools() -> void:
	for i in range(MAX_LIGHTS):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ff7a1a")
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		light_pool.append(lamp)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color("ff7a1a")
	flash_mat.emission_enabled = true
	flash_mat.emission = Color("ff7a1a")
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a := TAU * i / 8.0
		var b := TAU * (i + 1) / 8.0
		var ra := 0.48 if i % 2 == 0 else 0.12
		var rb := 0.48 if (i + 1) % 2 == 0 else 0.12
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a) * ra, 0, sin(a) * ra))
		st.add_vertex(Vector3(cos(b) * rb, 0, sin(b) * rb))
	var flash_mesh := st.commit()
	for i in range(MAX_MUZZLES):
		var flash := MeshInstance3D.new()
		flash.mesh = flash_mesh
		flash.material_override = flash_mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		add_child(flash)
		muzzle_pool.append({"node": flash, "life": 0.0, "lamp": null})
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(0.06, 0.06, 0.14)
	var casing_mat := StandardMaterial3D.new()
	casing_mat.albedo_color = Color("8c7761")
	casing_mat.metallic = 0.75
	casing_mat.roughness = 0.45
	shell_mesh.material = casing_mat
	for i in range(MAX_SHELLS):
		var shell := MeshInstance3D.new()
		shell.mesh = shell_mesh
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.visible = false
		add_child(shell)
		shell_pool.append({"node": shell, "life": 0.0, "velocity": Vector3.ZERO})
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.34, 0.33, 0.31, 0.35)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.06
	smoke_mesh.height = 0.12
	smoke_mesh.material = smoke_mat
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 45.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0, 0.4, 0)
	for i in range(MAX_MUZZLE_SMOKE):
		var smoke := GPUParticles3D.new()
		smoke.process_material = process
		smoke.draw_pass_1 = smoke_mesh
		smoke.amount = SMOKE_PARTICLES
		smoke.lifetime = 0.5
		smoke.one_shot = true
		smoke.explosiveness = 0.95
		smoke.emitting = false
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smoke)
		smoke_pool.append({"node": smoke, "life": 0.0})

func acquire_light(pos: Vector3, energy: float, radius: float) -> OmniLight3D:
	for lamp in light_pool:
		if not lamp.visible:
			lamp.position = pos
			lamp.light_energy = energy
			lamp.omni_range = radius
			lamp.visible = true
			light_count += 1
			return lamp
	return null

func release_light(lamp: OmniLight3D) -> void:
	if lamp != null and lamp.visible:
		lamp.visible = false
		light_count -= 1

func muzzle(p: Vector2, direction: Vector2, kind: String) -> void:
	if OS.has_feature("mobile"):
		return
	var pos := point(p, 0.8)
	var size := Vector2(0.65, 0.85)
	match kind:
		"rocket": size = Vector2(1.4, 1.4)
		"swarm": size = Vector2(1.45, 0.85)
		"laser": size = Vector2(0.5, 1.35)
		"plasma": size = Vector2(1.05, 1.05)
		"flamethrower": size = Vector2(0.65, 1.35)
		"turret": size = Vector2(0.5, 0.65)
		"drone": size = Vector2(0.55, 0.75)
	for slot in muzzle_pool:
		if slot.life <= 0.0:
			slot.life = MUZZLE_TIME
			slot.node.position = pos
			slot.node.rotation.y = -direction.angle()
			slot.node.scale = Vector3(size.x, 1, size.y)
			slot.node.visible = true
			slot.lamp = null
			if kind != "minigun" or minigun_light_cooldown <= 0.0:
				slot.lamp = acquire_light(pos, 2.4 if kind in ["rocket", "swarm"] else 1.5, 3.0 if kind in ["rocket", "swarm"] else 2.0)
				if kind == "minigun":
					minigun_light_cooldown = 0.24
			break
	if kind in ["minigun", "rocket", "swarm"]:
		for slot in smoke_pool:
			if slot.life <= 0.0:
				slot.life = 0.55
				slot.node.position = pos
				slot.node.scale = Vector3.ONE * (1.8 if kind in ["rocket", "swarm"] else 0.65)
				slot.node.restart()
				slot.node.emitting = true
				break
	if kind == "minigun":
		for slot in shell_pool:
			if slot.life <= 0.0:
				slot.life = 0.6
				slot.node.position = pos
				slot.node.visible = true
				slot.velocity = Vector3(-direction.y * 2.5, 2.2, direction.x * 2.5)
				break

func update_weapon_pools(delta: float) -> void:
	minigun_light_cooldown = maxf(0.0, minigun_light_cooldown - delta)
	for slot in muzzle_pool:
		if slot.life > 0.0:
			slot.life -= delta
			if slot.life <= 0.0:
				slot.node.visible = false
				release_light(slot.lamp)
				slot.lamp = null
	for slot in shell_pool:
		if slot.life > 0.0:
			slot.life -= delta
			slot.node.position += slot.velocity * delta
			slot.velocity.y -= 7.0 * delta
			slot.node.rotate_x(delta * 9.0)
			if slot.life <= 0.0:
				slot.node.visible = false
	for slot in smoke_pool:
		if slot.life > 0.0:
			slot.life -= delta
			if slot.life <= 0.0:
				slot.node.emitting = false

func prewarm() -> void:
	burst(Vector2(0, 0), "explosion")
	burst(Vector2(10, 0), "pickup")
	burst(Vector2(-10, 0), "muzzle")
	damage(Vector2(0, 0), 24)
	for e in effects:
		e.life = 0.06

func point(p: Vector2, height := 0.42) -> Vector3:
	return Vector3(p.x / 50.0, height, p.y / 50.0)

func burst(p: Vector2, kind: String) -> void:
	var slot: Dictionary = {}
	for candidate in burst_pool:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		return
	slot.active = true
	slot.kind = kind
	slot.life = 0.55 if kind == "explosion" else 0.35
	slot.node.position = point(p)
	slot.node.visible = true
	slot.orb.visible = kind == "explosion"
	slot.orb.scale = Vector3.ONE
	if slot.spark is GPUParticles3D:
		slot.spark.draw_pass_1 = cyan_particles if kind == "pickup" else orange_particles
	else:
		slot.spark.mesh = cyan_particles if kind == "pickup" else orange_particles
	slot.spark.restart()
	slot.spark.emitting = true
	slot.light_on = kind in ["explosion", "muzzle"] and light_count < MAX_LIGHTS
	if OS.has_feature("mobile"):
		slot.lamp.visible = slot.light_on
		if slot.light_on:
			light_count += 1
	else:
		slot.lamp = acquire_light(slot.node.position, 2.2, 3.2) if slot.light_on else null
		slot.light_on = slot.lamp != null
	for piece in slot.debris:
		piece.node.visible = kind == "explosion"
		piece.node.position = Vector3(randf_range(-0.25, 0.25), randf_range(0.08, 0.32), randf_range(-0.25, 0.25))
		piece.velocity = Vector3(randf_range(-2.4, 2.4), randf_range(1.2, 3.2), randf_range(-2.4, 2.4))
	effects.append(slot)

func damage(p: Vector2, value: int) -> void:
	for slot in label_pool:
		if not slot.active:
			slot.active = true
			slot.label = true
			slot.life = 0.75
			slot.node.text = str(value)
			slot.node.modulate = Color.WHITE
			slot.node.position = point(p, 0.95)
			slot.node.visible = true
			effects.append(slot)
			return

func _process(delta: float) -> void:
	if not OS.has_feature("mobile"):
		update_weapon_pools(delta)
	for e in effects:
		e.life -= delta
		if e.get("label", false):
			e.node.position.y += delta * 1.15
			e.node.modulate.a = clampf(e.life / 0.75, 0.0, 1.0)
		else:
			if e.orb.visible:
				var ratio := clampf(e.life / 0.55, 0.0, 1.0)
				e.orb.scale = Vector3.ONE * (0.15 + ratio * 0.95)
			for piece in e.debris:
				piece.node.position += piece.velocity * delta
				piece.velocity.y -= 5.5 * delta
				piece.node.rotate_x(delta * 5.0)
		if e.life <= 0:
			if e.get("light_on", false):
				release_light(e.lamp)
				e.light_on = false
			if e.get("lamp") != null:
				e.lamp.visible = false
			e.node.visible = false
			e.active = false
	effects = effects.filter(func(e): return e.life > 0)
