extends Node3D
class_name CombatEffects3D

var orange := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var effects: Array[Dictionary] = []

func _ready() -> void:
    orange.albedo_color = Color("ff851a")
    orange.emission_enabled = true
    orange.emission = Color("ff5d05")
    orange.emission_energy_multiplier = 3.0
    cyan.albedo_color = Color("66fbff")
    cyan.emission_enabled = true
    cyan.emission = Color("13e6ef")
    cyan.emission_energy_multiplier = 2.0
    dark.albedo_color = Color("69727b")
    dark.metallic = 0.65

func point(p: Vector2, height := 0.5) -> Vector3:
    return Vector3(p.x/50.0,height,p.y/50.0)

func burst(p: Vector2, kind: String) -> void:
    if effects.size() > 80: return
    var holder := Node3D.new()
    holder.position = point(p)
    add_child(holder)
    var spark: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
    holder.add_child(spark)
    var draw := SphereMesh.new()
    draw.radius = 0.045 if kind == "muzzle" else 0.085
    draw.height = draw.radius * 2
    draw.material = cyan if kind == "pickup" else orange
    if spark is GPUParticles3D:
        var material := ParticleProcessMaterial.new()
        material.direction = Vector3(0,1,0)
        material.spread = 180
        material.initial_velocity_min = 1.0
        material.initial_velocity_max = 4.0 if kind == "explosion" else 2.0
        material.gravity = Vector3(0,-4,0)
        spark.process_material = material
        spark.draw_pass_1 = draw
    else:
        spark.mesh = draw
        spark.direction = Vector3.UP
        spark.spread = 180
        spark.initial_velocity_min = 1.0
        spark.initial_velocity_max = 4.0
        spark.gravity = Vector3(0,-4,0)
    spark.amount = 18 if kind == "explosion" else 8
    spark.lifetime = 0.5
    spark.one_shot = true
    spark.explosiveness = 1.0
    spark.emitting = true
    if kind in ["explosion", "muzzle"]:
        var lamp := OmniLight3D.new()
        lamp.light_color = Color("ff771b")
        lamp.light_energy = 2.0
        lamp.omni_range = 3.0
        holder.add_child(lamp)
    var debris: Array[Dictionary] = []
    if kind == "explosion":
        var orb := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.3
        mesh.height = 0.6
        orb.mesh = mesh
        orb.material_override = orange
        holder.add_child(orb)
        for i in range(4):
            var piece := MeshInstance3D.new()
            var block := BoxMesh.new()
            block.size = Vector3(0.15,0.1,0.2)
            piece.mesh = block
            piece.material_override = dark
            holder.add_child(piece)
            piece.position = Vector3(randf_range(-0.5,0.5),randf_range(0.1,0.7),randf_range(-0.5,0.5))
            debris.append({"node":piece,"velocity":Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2))})
    effects.append({"node":holder,"life":0.65,"debris":debris,"kind":kind})

func damage(p: Vector2, value: int) -> void:
    if effects.size() > 80: return
    var label := Label3D.new()
    label.text = str(value)
    label.font_size = 38
    label.outline_size = 7
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.position = point(p,1.2)
    add_child(label)
    effects.append({"node":label,"life":0.8,"label":true})

func _process(delta: float) -> void:
    for e in effects:
        e.life -= delta
        if e.get("label",false):
            e.node.position.y += delta * 1.1
            e.node.modulate.a = clampf(e.life/0.8,0,1)
        for piece in e.get("debris",[]):
            piece.node.position += piece.velocity * delta
            piece.velocity.y -= 5.0 * delta
            piece.node.rotate_x(delta * 5)
        if e.life <= 0: e.node.queue_free()
    effects = effects.filter(func(e): return e.life > 0)
