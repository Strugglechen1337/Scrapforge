extends Node3D
class_name CombatEffects3D

const MAX_BURSTS := 20
const MAX_LABELS := 32
const MAX_LIGHTS := 8
var orange := StandardMaterial3D.new()
var hot_core := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var burst_pool: Array[Dictionary] = []
var label_pool: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var light_count := 0
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
	for i in range(MAX_BURSTS):
		var holder := Node3D.new()
		add_child(holder)
		var spark: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
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
		spark.amount = 18
		spark.lifetime = 0.45
		spark.one_shot = true
		spark.explosiveness = 0.95
		spark.emitting = false
		var lamp := OmniLight3D.new()
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
	slot.lamp.visible = slot.light_on
	if slot.light_on:
		light_count += 1
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
				light_count -= 1
				e.light_on = false
			if e.has("lamp"):
				e.lamp.visible = false
			e.node.visible = false
			e.active = false
	effects = effects.filter(func(e): return e.life > 0)
