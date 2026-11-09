extends Node3D
class_name EnemySwarm3D

var bodies: MultiMeshInstance3D
var armor: MultiMeshInstance3D
var eyes: MultiMeshInstance3D
var legs: MultiMeshInstance3D
var guns: MultiMeshInstance3D
var time := 0.0
const CAPACITY := 600

func _ready() -> void:
    var shell := StandardMaterial3D.new()
    shell.albedo_color = Color("9da4ae")
    shell.metallic = 0.45
    shell.roughness = 0.75
    shell.vertex_color_use_as_albedo = true
    var eye := StandardMaterial3D.new()
    eye.albedo_color = Color("df2518")
    eye.emission_enabled = true
    eye.emission = Color("ff1208")
    eye.emission_energy_multiplier = 2.0
    var ball := SphereMesh.new()
    ball.radius = 0.5
    ball.height = 1.0
    ball.radial_segments = 10
    ball.rings = 5
    var limb := BoxMesh.new()
    limb.size = Vector3.ONE
    bodies = batch(ball, shell, CAPACITY, true)
    armor = batch(ball, shell, CAPACITY, true)
    eyes = batch(ball, eye, CAPACITY * 2, false)
    legs = batch(limb, shell, CAPACITY * 6, true)
    guns = batch(limb, shell, CAPACITY, true)

func batch(mesh: Mesh, material: Material, count: int, colors: bool) -> MultiMeshInstance3D:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = colors
    mm.instance_count = count
    mm.visible_instance_count = 0
    mm.mesh = mesh
    mm.custom_aabb = AABB(Vector3(-100,-10,-100),Vector3(200,50,200))
    var instance := MultiMeshInstance3D.new()
    instance.multimesh = mm
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    return instance

func transform_at(base: Vector3, yaw: float, offset: Vector3, scale: Vector3) -> Transform3D:
    var rotation := Basis(Vector3.UP,yaw)
    return Transform3D(rotation * Basis.from_scale(scale), base + rotation * offset)

func update_swarm(enemies: Array, player: Vector2, delta: float) -> void:
    time += delta
    var count := mini(enemies.size(),CAPACITY)
    for node in [bodies, armor, guns]: node.multimesh.visible_instance_count = count
    eyes.multimesh.visible_instance_count = count * 2
    legs.multimesh.visible_instance_count = count * 6
    for i in range(count):
        var e: Dictionary = enemies[i]
        var kind: int = e.kind
        var size: float = [1.0,1.45,0.9,5.5][kind]
        var pos := Vector3(e.pos.x/50.0, 0, e.pos.y/50.0)
        var yaw := atan2(player.x-e.pos.x,player.y-e.pos.y)
        var flash: bool = e.get("flash",0.0) > 0.0
        var color: Color = Color.WHITE if flash else [Color("363a40"),Color("60656a"),Color("474e55"),Color("555b62")][kind]
        var shape: Vector3 = [Vector3(0.85,0.38,0.65),Vector3(1.05,0.65,0.95),Vector3(0.72,0.48,0.9),Vector3(1.0,0.5,0.8)][kind] * size
        bodies.multimesh.set_instance_transform(i,transform_at(pos,yaw,Vector3(0,0.42*size,0),shape))
        bodies.multimesh.set_instance_color(i,color)
        armor.multimesh.set_instance_transform(i,transform_at(pos,yaw,Vector3(0,0.65*size,0.1*size),shape*Vector3(0.78,0.45,0.65)))
        armor.multimesh.set_instance_color(i,color.lightened(0.2))
        for j in range(2):
            var off := Vector3((j*2-1)*0.20,0.48,0.36)*size
            eyes.multimesh.set_instance_transform(i*2+j,transform_at(pos,yaw,off,Vector3.ONE*0.11*size))
        for j in range(6):
            var side := -1 if j < 3 else 1
            var row := j % 3
            var phase := sin(time*10.0 + i*0.6 + row*1.7 + side)*0.18
            var off := Vector3(side*(0.50+phase),0.22,(row-1)*0.23)*size
            var basis := Basis(Vector3.UP,yaw) * Basis(Vector3.UP,side*(0.45+(row-1)*0.35)) * Basis(Vector3.FORWARD,side*(0.3+phase))
            legs.multimesh.set_instance_transform(i*6+j,Transform3D(basis * Basis.from_scale(Vector3(0.75,0.08,0.09)*size),pos+Basis(Vector3.UP,yaw)*off))
            legs.multimesh.set_instance_color(i*6+j,color.darkened(0.15))
        var gun_size := Vector3(0.13,0.13,0.75)*size if kind == 2 else Vector3(0.001,0.001,0.001)
        guns.multimesh.set_instance_transform(i,transform_at(pos,yaw,Vector3(0,0.68,0.45)*size,gun_size))
        guns.multimesh.set_instance_color(i,color)
