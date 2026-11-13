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
const MAX_BEAMS := 4
const BEAM_TIME := 0.16
const MAX_RINGS := 4
const RING_TIME := 0.4
const FLAME_HOLD := 0.3
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
var flash_materials := {}
var beam_pool: Array[Dictionary] = []
var ring_pool: Array[Dictionary] = []
var flame_systems: Array[GPUParticles3D] = []
var flame_holder: Node3D
var flame_time := 0.0
var flash_meshes := {}
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
static var soft_tex: Texture2D

static func soft_texture() -> Texture2D:
	if soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		soft_tex = t
	return soft_tex

# Soft billboard particle material (additive for fire, alpha for smoke).
static func soft_material(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = soft_texture()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# Gradient from start to a fully transparent end colour.
static func fade_ramp(start: Color, mid: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([start, mid, Color(mid.r, mid.g, mid.b, 0.0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func flash_star(spikes: int, outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := spikes * 2
	for i in range(n):
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		var ra := outer if i % 2 == 0 else inner
		var rb := outer if (i + 1) % 2 == 0 else inner
		st.set_color(Color(1, 1, 1, 1))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(1, 1, 1, 0.35 if ra == outer else 0.8))
		st.add_vertex(Vector3(cos(a) * ra, 0, sin(a) * ra))
		st.set_color(Color(1, 1, 1, 0.35 if rb == outer else 0.8))
		st.add_vertex(Vector3(cos(b) * rb, 0, sin(b) * rb))
	return st.commit()

# Forward-pointing cone/spike along +X.
func flash_cone(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.15, 0, 0), Vector3(0, 0, -width), Vector3(length, 0, 0), Vector3(-0.15, 0, 0), Vector3(length, 0, 0), Vector3(0, 0, width), Vector3(-0.15, 0, 0), Vector3(0, 0, width), Vector3(-0.3, 0, 0), Vector3(-0.15, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, -width)]
	for v in pts:
		st.set_color(Color(1, 1, 1, clampf(1.0 - v.x / length, 0.0, 1.0) * (0.45 if absf(v.z) > 0.0 else 1.0)))
		st.add_vertex(v)
	return st.commit()

# Small brass casing: hexagonal prism, not a primitive node.
func casing_mesh(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.035
	var h := 0.09
	for i in range(6):
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		var p0 := Vector3(cos(a) * r, sin(a) * r, -h)
		var p1 := Vector3(cos(b) * r, sin(b) * r, -h)
		var p2 := Vector3(cos(b) * r, sin(b) * r, h)
		var p3 := Vector3(cos(a) * r, sin(a) * r, h)
		for v in [p0, p1, p2, p0, p2, p3]:
			st.add_vertex(v)
		var c0 := Vector3(0, 0, -h)
		var c1 := Vector3(0, 0, h)
		for v in [c0, p1, p0, c1, p3, p2]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

func setup_weapon_pools() -> void:
	for i in range(MAX_LIGHTS):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ff7a1a")
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		light_pool.append(lamp)
	for key in ["orange", "hot"]:
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var col := Color("ff7a1a") if key == "orange" else Color("ffe2b0")
		fm.albedo_color = col
		fm.emission_enabled = true
		fm.emission = col
		fm.emission_energy_multiplier = 5.0 if key == "orange" else 2.6
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.vertex_color_use_as_albedo = true
		flash_materials[key] = fm
	flash_meshes = {
		"star": flash_star(8, 0.55, 0.13),
		"burst": flash_star(12, 0.6, 0.3),
		"cone": flash_cone(1.1, 0.34),
		"spike": flash_cone(1.7, 0.12),
	}
	for i in range(MAX_MUZZLES):
		var flash := MeshInstance3D.new()
		flash.mesh = flash_meshes["star"]
		flash.material_override = flash_materials["orange"]
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		add_child(flash)
		muzzle_pool.append({"node": flash, "life": 0.0, "lamp": null})
	var casing_mat := StandardMaterial3D.new()
	casing_mat.albedo_color = Color("b08a4a")
	casing_mat.metallic = 0.8
	casing_mat.roughness = 0.4
	var shell_mesh := casing_mesh(casing_mat)
	for i in range(MAX_SHELLS):
		var shell := MeshInstance3D.new()
		shell.mesh = shell_mesh
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.visible = false
		add_child(shell)
		shell_pool.append({"node": shell, "life": 0.0, "velocity": Vector3.ZERO})
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2.ONE
	smoke_quad.material = soft_material(false)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 45.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0, 0.5, 0)
	process.scale_min = 0.3
	process.scale_max = 0.5
	process.scale_curve = grow_curve()
	process.color_ramp = fade_ramp(Color(0.6, 0.58, 0.55, 0.5), Color(0.35, 0.34, 0.33, 0.3))
	for i in range(MAX_MUZZLE_SMOKE):
		var smoke := GPUParticles3D.new()
		smoke.process_material = process
		smoke.draw_pass_1 = smoke_quad
		smoke.amount = SMOKE_PARTICLES
		smoke.lifetime = 0.6
		smoke.one_shot = true
		smoke.explosiveness = 0.6
		smoke.emitting = false
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smoke)
		smoke_pool.append({"node": smoke, "life": 0.0})
	setup_beam_flame_pools()

static func grow_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	var t := CurveTexture.new()
	t.curve = c
	return t

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
	var shape := "star"
	var mat := "orange"
	var size := 1.0
	var energy := 1.6
	var radius := 2.4
	match kind:
		"minigun":
			size = 0.8
		"rocket":
			size = 1.9
			energy = 3.2
			radius = 4.0
		"swarm":
			shape = "burst"
			size = 1.5
			energy = 2.6
			radius = 3.4
		"laser":
			shape = "spike"
			mat = "hot"
			size = 1.1
			energy = 2.2
		"plasma":
			shape = "burst"
			mat = "hot"
			size = 1.1
			energy = 2.8
			radius = 3.4
		"flamethrower":
			shape = "cone"
			size = 1.3
			energy = 2.0
		"turret":
			mat = "hot"
			size = 0.7
			energy = 1.2
			radius = 2.0
		"drone":
			size = 0.6
			energy = 1.0
			radius = 1.8
	for slot in muzzle_pool:
		if slot.life <= 0.0:
			slot.life = MUZZLE_TIME
			slot.node.mesh = flash_meshes[shape]
			slot.node.material_override = flash_materials[mat]
			slot.node.position = pos
			slot.node.rotation.y = -direction.angle()
			slot.node.scale = Vector3(size, 1, size)
			slot.node.visible = true
			slot.lamp = null
			if kind != "minigun" or minigun_light_cooldown <= 0.0:
				slot.lamp = acquire_light(pos, energy, radius)
				if slot.lamp != null:
					slot.lamp.light_color = Color("ffcf94") if mat == "hot" else Color("ff7a1a")
				if kind == "minigun":
					minigun_light_cooldown = 0.24
			break
	if kind in ["minigun", "rocket", "swarm"]:
		for slot in smoke_pool:
			if slot.life <= 0.0:
				slot.life = 0.65
				slot.node.position = pos + Vector3(direction.x, 0, direction.y) * 0.3
				slot.node.scale = Vector3.ONE * (1.6 if kind != "minigun" else 0.7)
				slot.node.restart()
				slot.node.emitting = true
				break
	if kind == "minigun":
		for slot in shell_pool:
			if slot.life <= 0.0:
				slot.life = 0.6
				slot.node.position = pos
				slot.node.visible = true
				slot.node.rotation = Vector3(0, -direction.angle(), 0)
				var side := Vector2(-direction.y, direction.x) * (2.2 + randf() * 0.8)
				slot.velocity = Vector3(side.x, 2.4 + randf(), side.y)
				break

# ---- 3a-3: laser beam, flame cone, plasma ring (PC only, all pooled) ----
func ribbon_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-0.5, 0.5]:
		var quad := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, side), Vector3(0, 0, 0), Vector3(1, 0, side), Vector3(0, 0, side)]
		for v in quad:
			st.set_color(Color(1, 1, 1, 1.0 if v.z == 0.0 else 0.0))
			st.add_vertex(v)
	return st.commit()

func ring_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 32
	for i in range(n):
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		var radii := [0.8, 0.94, 1.0]
		var alphas := [0.0, 1.0, 0.0]
		for k in range(2):
			var r0: float = radii[k]
			var r1: float = radii[k + 1]
			var a0: float = alphas[k]
			var a1: float = alphas[k + 1]
			var corners := [[a, r0, a0], [a, r1, a1], [b, r1, a1], [a, r0, a0], [b, r1, a1], [b, r0, a0]]
			for c in corners:
				st.set_color(Color(1, 1, 1, c[2]))
				st.add_vertex(Vector3(cos(c[0]) * c[1], 0, sin(c[0]) * c[1]))
	return st.commit()

func additive_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func soft_system(amount: int, life: float, one_shot: bool, additive: bool, proc: ParticleProcessMaterial, size := 1.0) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = soft_material(additive)
	var ps := GPUParticles3D.new()
	ps.process_material = proc
	ps.draw_pass_1 = quad
	ps.amount = amount
	ps.lifetime = life
	ps.one_shot = one_shot
	ps.explosiveness = 1.0 if one_shot else 0.0
	ps.emitting = false
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ps

func proc_material(dir: Vector3, spread: float, vmin: float, vmax: float, gravity: Vector3, smin: float, smax: float, ramp: GradientTexture1D, grow := true) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = gravity
	pm.scale_min = smin
	pm.scale_max = smax
	if grow:
		pm.scale_curve = grow_curve()
	pm.color_ramp = ramp
	return pm

func setup_beam_flame_pools() -> void:
	var ribbon := ribbon_mesh()
	var glow_mat := additive_material(Color("ff7a1a"), 1.6)
	var core_mat := additive_material(Color("ffe0b0"), 2.4)
	var up := Vector3.UP
	var glow_proc := proc_material(up, 0, 0, 0, Vector3.ZERO, 0.9, 1.1, fade_ramp(Color(1, 0.8, 0.45, 1), Color(1, 0.4, 0.08, 0.7)))
	var spark_proc := proc_material(up, 180, 2.0, 4.5, Vector3(0, -4, 0), 0.08, 0.14, fade_ramp(Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.1, 0.9)), false)
	for i in range(MAX_BEAMS):
		var glow := MeshInstance3D.new()
		glow.mesh = ribbon
		glow.material_override = glow_mat
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = false
		add_child(glow)
		var core := MeshInstance3D.new()
		core.mesh = ribbon
		core.material_override = core_mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.visible = false
		add_child(core)
		var impact_glow := soft_system(3, 0.3, true, true, glow_proc)
		add_child(impact_glow)
		var impact_sparks := soft_system(8, 0.4, true, true, spark_proc)
		add_child(impact_sparks)
		beam_pool.append({"glow": glow, "core": core, "impact_glow": impact_glow, "impact_sparks": impact_sparks, "life": 0.0, "impact": 0.0, "length": 1.0})
	flame_holder = Node3D.new()
	add_child(flame_holder)
	var fwd := Vector3(1, 0, 0)
	var fire := soft_system(64, 0.45, false, true, proc_material(fwd, 12, 6.0, 9.0, Vector3(0, 0.6, 0), 0.6, 0.95, fade_ramp(Color(1, 0.85, 0.4, 0.55), Color(1, 0.3, 0.04, 0.4))))
	fire.process_material.damping_min = 0.8
	fire.process_material.damping_max = 1.2
	var soot := soft_system(14, 0.75, false, false, proc_material(fwd, 16, 3.0, 5.0, Vector3(0, 0.5, 0), 0.3, 0.5, fade_ramp(Color(0.08, 0.07, 0.06, 0.55), Color(0.05, 0.05, 0.05, 0.4))))
	var sparks := soft_system(16, 0.5, false, true, proc_material(fwd, 22, 5.0, 10.0, Vector3(0, -3, 0), 0.07, 0.12, fade_ramp(Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.9)), false))
	var heat := soft_system(6, 0.6, false, true, proc_material(fwd, 22, 3.0, 5.0, Vector3(0, 0.8, 0), 0.9, 1.3, fade_ramp(Color(1, 0.8, 0.6, 0.07), Color(1, 0.7, 0.5, 0.05))))
	for ps in [fire, soot, sparks, heat]:
		flame_holder.add_child(ps)
		flame_systems.append(ps)
	var rmesh := ring_mesh()
	var rmat := additive_material(Color("ff7a1a"), 2.2)
	for i in range(MAX_RINGS):
		var ring := MeshInstance3D.new()
		ring.mesh = rmesh
		ring.material_override = rmat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		ring_pool.append({"node": ring, "life": 0.0, "radius": 1.0})

# Laser: continuous ribbon from muzzle to hit point / end of range.
func beam(start: Vector2, direction: Vector2, length: float, hit: bool) -> void:
	if OS.has_feature("mobile"):
		return
	for slot in beam_pool:
		if slot.life <= 0.0:
			slot.life = BEAM_TIME
			slot.length = length / 50.0
			var pos := point(start, 0.8)
			for key in ["glow", "core"]:
				slot[key].position = pos + (Vector3(0, 0.01, 0) if key == "core" else Vector3.ZERO)
				slot[key].rotation.y = -direction.angle()
				slot[key].visible = true
			slot.impact = 0.0
			if hit:
				slot.impact = 0.35
				var end := point(start + direction * length, 0.8)
				for key in ["impact_glow", "impact_sparks"]:
					slot[key].position = end
					slot[key].restart()
					slot[key].emitting = true
			update_beam(slot)
			return

func update_beam(slot: Dictionary) -> void:
	var fade: float = clampf(slot.life / BEAM_TIME, 0.0, 1.0)
	var flicker := 0.85 + randf() * 0.3
	slot.glow.scale = Vector3(slot.length, 1, 0.6 * flicker * (0.4 + 0.6 * fade))
	slot.core.scale = Vector3(slot.length, 1, 0.16 * flicker * (0.4 + 0.6 * fade))

# Flame cone: one emitter set, kept alive while the weapon keeps firing.
func flame(start: Vector2, direction: Vector2) -> void:
	if OS.has_feature("mobile"):
		return
	flame_holder.position = point(start, 0.8)
	flame_holder.rotation.y = -direction.angle()
	flame_time = FLAME_HOLD
	for ps in flame_systems:
		ps.emitting = true

func plasma_impact(p: Vector2, radius: float) -> void:
	burst(p, "explosion")
	if OS.has_feature("mobile"):
		return
	for slot in ring_pool:
		if slot.life <= 0.0:
			slot.life = RING_TIME
			slot.radius = radius / 50.0
			slot.node.position = point(p, 0.12)
			slot.node.visible = true
			slot.node.scale = Vector3.ONE * 0.2
			slot.node.transparency = 0.0
			break

func update_beams_flames_rings(delta: float) -> void:
	for slot in beam_pool:
		if slot.life > 0.0:
			slot.life -= delta
			if slot.life <= 0.0:
				slot.glow.visible = false
				slot.core.visible = false
			else:
				update_beam(slot)
		if slot.impact > 0.0:
			slot.impact -= delta
			if slot.impact <= 0.0:
				slot.impact_glow.emitting = false
				slot.impact_sparks.emitting = false
	if flame_time > 0.0:
		flame_time -= delta
		if flame_time <= 0.0:
			for ps in flame_systems:
				ps.emitting = false
	for slot in ring_pool:
		if slot.life > 0.0:
			slot.life -= delta
			var t := clampf(1.0 - slot.life / RING_TIME, 0.0, 1.0)
			slot.node.scale = Vector3.ONE * lerpf(0.2, slot.radius, 1.0 - pow(1.0 - t, 2.0))
			slot.node.transparency = t
			if slot.life <= 0.0:
				slot.node.visible = false

func update_weapon_pools(delta: float) -> void:
	update_beams_flames_rings(delta)
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
