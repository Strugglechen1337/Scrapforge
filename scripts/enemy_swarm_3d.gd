extends Node3D
class_name EnemySwarm3D

var bodies: MultiMeshInstance3D
var heads: MultiMeshInstance3D
var armor: MultiMeshInstance3D
var seams: MultiMeshInstance3D
var eyes: MultiMeshInstance3D
var legs: MultiMeshInstance3D
var guns: MultiMeshInstance3D
var boss_lights: MultiMeshInstance3D
var time := 0.0
var leg_phase := 0
const CAPACITY := 600

func _ready() -> void:
    var shell := StandardMaterial3D.new()
    shell.albedo_color = Color("b0b4bb")
    shell.metallic = 0.48
    shell.roughness = 0.78
    shell.vertex_color_use_as_albedo = true
    var eye := StandardMaterial3D.new()
    eye.albedo_color = Color(0.85,0.006,0.003)
    eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    eye.emission_enabled = true
    eye.emission = Color(0.85,0.005,0.002)
    eye.emission_energy_multiplier = 0.5
    var block := BoxMesh.new()
    block.size = Vector3.ONE
    var rounded := SphereMesh.new()
    rounded.radius = 0.5
    rounded.height = 1.0
    rounded.radial_segments = 8
    rounded.rings = 4
    bodies = batch(rounded, shell, CAPACITY, true)
    heads = batch(block, shell, CAPACITY, true)
    armor = batch(block, shell, CAPACITY, true)
    seams = batch(block, shell, CAPACITY * 3, true)
    eyes = batch(rounded, eye, CAPACITY * 4, false)
    boss_lights = batch(rounded, eye, 8, false)
    legs = batch(block, shell, CAPACITY * 16, true)
    guns = batch(block, shell, CAPACITY * 2, true)

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

func transform_at(base: Vector3, rotation: Basis, offset: Vector3, scale: Vector3) -> Transform3D:
    return Transform3D(rotation * Basis.from_scale(scale), base + rotation * offset)

func segment(a: Vector3, b: Vector3, width: float) -> Transform3D:
    var direction := b - a
    var orientation := Basis.looking_at(direction,Vector3.UP)
    return Transform3D(orientation * Basis.from_scale(Vector3(width,width,direction.length())),(a+b)*0.5)

func update_swarm(enemies: Array, player: Vector2, delta: float) -> void:
    time += delta
    leg_phase = 1 - leg_phase
    var count := mini(enemies.size(),CAPACITY)
    for node in [bodies, heads, armor]: node.multimesh.visible_instance_count = count
    seams.multimesh.visible_instance_count = count * 3
    eyes.multimesh.visible_instance_count = count * 4
    legs.multimesh.visible_instance_count = count * 16
    guns.multimesh.visible_instance_count = count * 2
    boss_lights.multimesh.visible_instance_count = 0
    for i in range(count):
        var e: Dictionary = enemies[i]
        var kind: int = e.kind
        var size: float = [0.55,0.9,0.66,3.0][kind]
        var pos := Vector3(e.pos.x/50.0, 0, e.pos.y/50.0)
        var yaw := atan2(player.x-e.pos.x,player.y-e.pos.y)
        var rotation := Basis(Vector3.UP,yaw)
        var flash: bool = e.get("flash",0.0) > 0.0
        var color: Color = Color.WHITE if flash else [Color("30343a"),Color("51555a"),Color("3a4148"),Color("474b50")][kind]
        var width := 1.2 if kind == 1 else 0.9
        var body_size := Vector3(width,0.40,0.80)*size
        bodies.multimesh.set_instance_transform(i,transform_at(pos,rotation,Vector3(0,0.5,-0.12)*size,body_size))
        bodies.multimesh.set_instance_color(i,color)
        heads.multimesh.set_instance_transform(i,transform_at(pos,rotation,Vector3(0,0.46,0.38)*size,Vector3(0.48,0.26,0.37)*size))
        heads.multimesh.set_instance_color(i,color.darkened(0.12))
        armor.multimesh.set_instance_transform(i,transform_at(pos,rotation,Vector3(0,0.71,-0.12)*size,Vector3(width*0.78,0.12,0.63)*size))
        armor.multimesh.set_instance_color(i,color.lightened(0.16))
        for k in range(3):
            var panel_z := (-0.36 + k*0.25)*size
            seams.multimesh.set_instance_transform(i*3+k,transform_at(pos,rotation,Vector3(0,0.78*size,panel_z),Vector3(width*0.72,0.03,0.025)*size))
            seams.multimesh.set_instance_color(i*3+k,color.darkened(0.35))
        for j in range(4):
            var off := Vector3((float(j)-1.5)*0.105,0.50,0.58)*size
            eyes.multimesh.set_instance_transform(i*4+j,transform_at(pos,rotation,off,Vector3.ONE*0.075*size))
        if kind == 3:
            boss_lights.multimesh.visible_instance_count = 8
            for j in range(8):
                var off := Vector3((j%4-1.5)*0.18,0.80,(int(j/4)-0.5)*0.45)*size
                boss_lights.multimesh.set_instance_transform(j,transform_at(pos,rotation,off,Vector3.ONE*0.09*size))
        # Interleave leg updates across two frames; bodies and hit feedback remain per-frame.
        if i % 2 == leg_phase:
            for j in range(8):
                var side := -1 if j < 4 else 1
                var row := j%4
                var used := kind == 3 or row != 3
                var spread := float(row)-1.5
                var gait := sin(time*9.0 + i*0.47 + row*1.8 + side)*0.13
                var shoulder := pos + rotation * Vector3(side*0.36,0.45,spread*0.18)*size
                var knee := pos + rotation * Vector3(side*(0.72+gait),0.56,spread*0.28)*size
                var foot := pos + rotation * Vector3(side*(0.91+gait),0.04,spread*0.38)*size
                if not used: knee = shoulder + Vector3(0,0,0.001); foot = knee + Vector3(0,0,0.001)
                var leg_color := color.darkened(0.2)
                legs.multimesh.set_instance_transform(i*16+j*2,segment(shoulder,knee,0.085*size if used else 0.001))
                legs.multimesh.set_instance_transform(i*16+j*2+1,segment(knee,foot,0.07*size if used else 0.001))
                legs.multimesh.set_instance_color(i*16+j*2,leg_color)
                legs.multimesh.set_instance_color(i*16+j*2+1,leg_color)
        for j in range(2):
            var armed := kind == 3 or (kind == 2 and j == 0)
            var gun_size := Vector3(0.13,0.14,0.65)*size if armed else Vector3.ONE*0.001
            var gun_off := Vector3((j*2-1)*0.24,0.85,0.24)*size
            guns.multimesh.set_instance_transform(i*2+j,transform_at(pos,rotation,gun_off,gun_size))
            guns.multimesh.set_instance_color(i*2+j,color.lightened(0.12))
