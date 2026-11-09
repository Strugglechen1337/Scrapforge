extends Node3D
class_name CombatEffects3D

const MAX_BURSTS := 20
const MAX_LABELS := 32
const MAX_LIGHTS := 8
var orange := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var burst_pool: Array[Dictionary] = []
var label_pool: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var light_count := 0
var orange_particles: SphereMesh
var cyan_particles: SphereMesh

func _ready() -> void:
    orange.albedo_color = Color("ff851a")
    orange.emission_enabled = true
    orange.emission = Color("ff5d05")
    orange.emission_energy_multiplier = 2.0
    cyan.albedo_color = Color("66fbff")
    cyan.emission_enabled = true
    cyan.emission = Color("13e6ef")
    cyan.emission_energy_multiplier = 1.2
    dark.albedo_color = Color("69727b")
    dark.metallic = 0.65
    var draw := SphereMesh.new()
    draw.radius = 0.075
    draw.height = 0.15
    draw.material = orange
    orange_particles = draw
    cyan_particles = draw.duplicate()
    cyan_particles.material = cyan
    var orb_mesh := SphereMesh.new()
    orb_mesh.radius = 0.3
    orb_mesh.height = 0.6
    var scrap_mesh := BoxMesh.new()
    scrap_mesh.size = Vector3(0.15,0.1,0.2)
    var process := ParticleProcessMaterial.new()
    process.direction = Vector3.UP
    process.spread = 180
    process.initial_velocity_min = 1.0
    process.initial_velocity_max = 4.0
    process.gravity = Vector3(0,-4,0)
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
            spark.initial_velocity_min = 1.0
            spark.initial_velocity_max = 4.0
            spark.gravity = Vector3(0,-4,0)
        spark.amount = 18
        spark.lifetime = 0.5
        spark.one_shot = true
        spark.explosiveness = 1.0
        spark.emitting = false
        var lamp := OmniLight3D.new()
        lamp.light_color = Color("ff771b")
        lamp.light_energy = 2.0
        lamp.omni_range = 3.0
        lamp.visible = false
        holder.add_child(lamp)
        var orb := MeshInstance3D.new()
        orb.mesh = orb_mesh
        orb.material_override = orange
        holder.add_child(orb)
        var debris: Array[Dictionary] = []
        for j in range(4):
            var piece := MeshInstance3D.new()
            piece.mesh = scrap_mesh
            piece.material_override = dark
            holder.add_child(piece)
            debris.append({"node":piece,"velocity":Vector3.ZERO})
        holder.visible = false
        burst_pool.append({"node":holder,"spark":spark,"lamp":lamp,"orb":orb,"debris":debris,"active":false,"light_on":false})
    for i in range(MAX_LABELS):
        var label := Label3D.new()
        label.font_size = 38
        label.outline_size = 7
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.visible = false
        add_child(label)
        label_pool.append({"node":label,"active":false})
    # Compile the common particle and light paths before the stress wave arrives.
    call_deferred("prewarm")

func prewarm() -> void:
    burst(Vector2(0,0),"explosion")
    burst(Vector2(0,0),"pickup")

func point(p: Vector2, height := 0.5) -> Vector3:
    return Vector3(p.x/50.0,height,p.y/50.0)

func burst(p: Vector2, kind: String) -> void:
    var slot: Dictionary = {}
    for candidate in burst_pool:
        if not candidate.active:
            slot = candidate
            break
    if slot.is_empty(): return
    slot.active = true
    slot.kind = kind
    slot.life = 0.65
    slot.node.position = point(p)
    slot.node.visible = true
    slot.orb.visible = kind == "explosion"
    if slot.spark is GPUParticles3D:
        slot.spark.draw_pass_1 = cyan_particles if kind == "pickup" else orange_particles
    else:
        slot.spark.mesh = cyan_particles if kind == "pickup" else orange_particles
    slot.spark.restart()
    slot.spark.emitting = true
    slot.light_on = kind in ["explosion","muzzle"] and light_count < MAX_LIGHTS
    slot.lamp.visible = slot.light_on
    if slot.light_on: light_count += 1
    for piece in slot.debris:
        piece.node.visible = kind == "explosion"
        piece.node.position = Vector3(randf_range(-0.3,0.3),randf_range(0.1,0.4),randf_range(-0.3,0.3))
        piece.velocity = Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2))
    effects.append(slot)

func damage(p: Vector2, value: int) -> void:
    for slot in label_pool:
        if not slot.active:
            slot.active = true
            slot.label = true
            slot.life = 0.8
            slot.node.text = str(value)
            slot.node.modulate = Color.WHITE
            slot.node.position = point(p,1.2)
            slot.node.visible = true
            effects.append(slot)
            return

func _process(delta: float) -> void:
    for e in effects:
        e.life -= delta
        if e.get("label",false):
            e.node.position.y += delta * 1.1
            e.node.modulate.a = clampf(e.life/0.8,0,1)
        else:
            for piece in e.debris:
                piece.node.position += piece.velocity * delta
                piece.velocity.y -= 5.0 * delta
                piece.node.rotate_x(delta * 5)
        if e.life <= 0:
            if e.get("light_on",false):
                light_count -= 1
                e.light_on = false
            if e.has("lamp"): e.lamp.visible = false
            e.node.visible = false
            e.active = false
    effects = effects.filter(func(e): return e.life > 0)
