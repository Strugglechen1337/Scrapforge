extends Node3D
class_name Robot3D

var state: UpgradeState
var definitions: Dictionary = {}
var signature := ""
var skin: Resource
var body_material: ShaderMaterial
var accent := StandardMaterial3D.new()
var metal := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var glow := StandardMaterial3D.new()
var visor_glow := StandardMaterial3D.new()
var sockets: Dictionary = {}
var parts: Node3D
var base_parts: Node3D
var animation: AnimationPlayer
var clock := 0.0
var visor: MeshInstance3D
var model: Node3D
var chassis: Dictionary = {}
var last_position := Vector3.ZERO
var motion := 0.0
var recoil := 0.0
var previous_fire_clock := 0.0

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
    model = (load("res://assets/third_party/sketchfab/colossus/colossus-parts.glb") as PackedScene).instantiate() as Node3D
    model.position.y = 0.956
    add_child(model)
    for part_name in ["torso", "head", "shoulder_l", "shoulder_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
        var node := model.find_child(part_name, true, false) as MeshInstance3D
        chassis[part_name] = node
    var original := (chassis["torso"] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
    body_material = ShaderMaterial.new()
    body_material.shader = load("res://scripts/colossus_paint.gdshader")
    body_material.set_shader_parameter("base_texture", original.albedo_texture)
    for node in chassis.values():
        (node as MeshInstance3D).material_override = body_material
    # The AnimationPlayer provides a pause control for the existing hangar and
    # showcase; the actual rigid-part motion is generated below.
    animation = AnimationPlayer.new()
    var library := AnimationLibrary.new()
    var walk := Animation.new()
    walk.length = 1.0
    walk.loop_mode = Animation.LOOP_LINEAR
    library.add_animation("Walk", walk)
    animation.add_animation_library("", library)
    add_child(animation)
    animation.play("Walk")
    for entry in [
        ["left_arm", "forearm_l", Vector3(-0.02, -0.29, 0.14)],
        ["right_arm", "forearm_r", Vector3(0.05, 0.0, 0.22)],
        ["left_shoulder", "shoulder_l", Vector3(-0.10, 0.13, 0.0)],
        ["right_shoulder", "shoulder_r", Vector3(0.10, 0.13, 0.0)],
        ["head", "head", Vector3(0, 0.12, 0.25)],
        ["back", "torso", Vector3(0, 0.20, -0.34)],
        ["legs", "torso", Vector3(0, -0.20, 0)],
        ["core", "torso", Vector3(0, 0.10, 0.22)]]:
        sockets[entry[0]] = make_marker(chassis[entry[1]], entry[0], entry[2])
    parts = Node3D.new()
    add_child(parts)
    base_parts = Node3D.new()
    add_child(base_parts)
    for entry in [["core", "chassis_core"], ["left_shoulder", "chassis_shoulder"], ["right_shoulder", "chassis_shoulder"]]:
        add_base_plate(sockets[entry[0]], entry[1])
    for entry in [["thigh_l", "chassis_thigh", Vector3.ZERO], ["thigh_r", "chassis_thigh", Vector3.ZERO], ["shin_l", "chassis_shin", Vector3.ZERO], ["shin_r", "chassis_shin", Vector3.ZERO], ["shin_l", "chassis_foot", Vector3(0,-0.34,0.08)], ["shin_r", "chassis_foot", Vector3(0,-0.34,0.08)], ["upper_arm_l", "chassis_upper_arm", Vector3.ZERO], ["upper_arm_r", "chassis_upper_arm", Vector3.ZERO]]:
        add_base_plate(make_marker(chassis[entry[0]], "plate", entry[2]), entry[1])
    # Dark mechanical joints cover the spatial cuts at the main pivots.
    for part_name in ["shoulder_l", "shoulder_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
        var joint := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.09
        sphere.height = 0.18
        joint.mesh = sphere
        joint.material_override = dark
        (chassis[part_name] as Node3D).add_child(joint)
    visor = MeshInstance3D.new()
    var visor_mesh := BoxMesh.new()
    visor_mesh.size = Vector3(0.24, 0.055, 0.035)
    visor.mesh = visor_mesh
    visor.material_override = visor_glow
    sockets["head"].add_child(visor)
    set_skin(load("res://data/skins/standard.tres"))
    set_robot_layer(self)

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
    metal.albedo_color = skin.armor_color
    accent.albedo_color = skin.accent_color
    if body_material: body_material.set_shader_parameter("paint_color", skin.armor_color)
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

func add_base_plate(marker: Marker3D, id: String) -> void:
    var module: Node3D = load("res://scripts/module_visual_3d.gd").new()
    base_parts.add_child(module)
    module.set_meta("marker", marker)
    module.build(id, 1, metal, dark, glow, accent)

func refresh() -> void:
    if not state or not is_instance_valid(parts): return
    var next := str(state.levels)
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
        var socket_name: String = state.arm_socket(id) if id in state.ARM_WEAPONS else definition.socket
        module.set_meta("socket", socket_name)
        module.set_meta("module_id", id)
        module.build(id, level, metal, dark, glow, accent)
        set_robot_layer(module)
    update_parts()

func update_parts() -> void:
    for part in parts.get_children():
        var socket: Marker3D = sockets[part.get_meta("socket")]
        follow_bone(part, socket, true)
        if part.get_meta("module_id") == "minigun": part.scale *= 1.45
        if part.get_meta("socket") in ["left_shoulder", "right_shoulder"]:
            var side := 1.0 if part.get_meta("socket") == "left_shoulder" else -1.0
            part.position += part.basis.orthonormalized() * Vector3(side * 0.22, 0.13, 0)
    for part in base_parts.get_children():
        follow_bone(part, part.get_meta("marker"), false)

func follow_bone(part: Node3D, marker: Marker3D, weapon: bool) -> void:
    var local_transform := global_transform.affine_inverse() * marker.global_transform
    var rest_basis: Basis = marker.get_meta("rest_basis")
    var delta_basis := local_transform.basis.orthonormalized() * rest_basis.inverse()
    part.transform = Transform3D((delta_basis * Basis(Vector3.UP, PI if weapon else 0.0)).scaled(Vector3.ONE * (0.8 if weapon else 1.0)), local_transform.origin)

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
    if animation.is_playing():
        var stride := sin(clock * 7.0) * motion
        (chassis["thigh_l"] as Node3D).rotation.x = stride * 0.32
        (chassis["thigh_r"] as Node3D).rotation.x = -stride * 0.32
        (chassis["shin_l"] as Node3D).rotation.x = maxf(0.0, -stride) * 0.25
        (chassis["shin_r"] as Node3D).rotation.x = maxf(0.0, stride) * 0.25
        (chassis["upper_arm_l"] as Node3D).rotation.x = -stride * 0.12 - recoil * 0.13
        (chassis["upper_arm_r"] as Node3D).rotation.x = stride * 0.12 - recoil * 0.13
        (chassis["torso"] as Node3D).rotation.z = sin(clock * 3.5) * motion * 0.025
        model.position.y = 0.956 + absf(sin(clock * 7.0)) * motion * 0.025 + sin(clock * 1.8) * 0.006
    refresh()
    update_parts()
