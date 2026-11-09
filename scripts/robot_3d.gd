extends Node3D
class_name Robot3D

var state: UpgradeState
var definitions: Dictionary = {}
var signature := ""
var skin: Resource
var body_material: StandardMaterial3D
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

func _ready() -> void:
    metal.albedo_color = Color("d8d4c8")
    accent.albedo_color = Color("e97220")
    accent.metallic = 0.4
    accent.roughness = 0.6
    metal.metallic = 0.72
    metal.roughness = 0.38
    dark.albedo_color = Color("192431")
    dark.metallic = 0.72
    dark.roughness = 0.42
    glow.albedo_color = Color("e94e04")
    glow.emission_enabled = true
    glow.emission = Color("ff620d")
    glow.emission_energy_multiplier = 2.0
    visor_glow.albedo_color = Color("21dbea")
    visor_glow.emission_enabled = true
    visor_glow.emission = Color("31eaff")
    visor_glow.emission_energy_multiplier = 2.5
    var model := (load("res://assets/third_party/quaternius/animated-mech/George.gltf") as PackedScene).instantiate() as Node3D
    model.scale = Vector3.ONE * 0.33
    add_child(model)
    var skeleton := model.get_node("RobotArmature/Skeleton3D") as Skeleton3D
    var body := skeleton.get_node("George") as MeshInstance3D
    var material := body.get_active_material(0).duplicate() as StandardMaterial3D
    material.albedo_color = Color("e1e5e3")
    material.metallic = 0.45
    material.roughness = 0.55
    body.material_override = material
    body_material = material
    animation = model.get_node("AnimationPlayer") as AnimationPlayer
    var walk := animation.get_animation("Walk")
    walk.loop_mode = Animation.LOOP_LINEAR
    animation.play("Walk")
    for entry in [["left_arm", "LowerArm.L"], ["right_arm", "LowerArm.R"], ["left_shoulder", "Shoulder.L"], ["right_shoulder", "Shoulder.R"], ["head", "Head"], ["back", "Chest"], ["legs", "Body"], ["core", "Chest"]]:
        var attachment := BoneAttachment3D.new()
        attachment.name = "attachment_" + entry[0]
        attachment.bone_name = entry[1]
        skeleton.add_child(attachment)
        var marker := Marker3D.new()
        marker.name = entry[0]
        attachment.add_child(marker)
        marker.set_meta("rest_basis", skeleton.get_bone_global_rest(skeleton.find_bone(entry[1])).basis.orthonormalized())
        sockets[entry[0]] = marker
    parts = Node3D.new()
    add_child(parts)
    base_parts = Node3D.new()
    add_child(base_parts)
    for entry in [["core", "chassis_core"], ["left_shoulder", "chassis_shoulder"], ["right_shoulder", "chassis_shoulder"]]:
        add_base_plate(sockets[entry[0]], entry[1])
    for bone in ["UpperLeg.L", "UpperLeg.R"]:
        var attachment := BoneAttachment3D.new()
        attachment.bone_name = bone
        skeleton.add_child(attachment)
        var marker := Marker3D.new()
        attachment.add_child(marker)
        marker.set_meta("rest_basis", skeleton.get_bone_global_rest(skeleton.find_bone(bone)).basis.orthonormalized())
        add_base_plate(marker, "chassis_thigh")
    for pair in [["LowerLeg.L", "chassis_shin"], ["LowerLeg.R", "chassis_shin"], ["Foot.L", "chassis_foot"], ["Foot.R", "chassis_foot"], ["UpperArm.L", "chassis_upper_arm"], ["UpperArm.R", "chassis_upper_arm"]]:
        var attachment := BoneAttachment3D.new()
        attachment.bone_name = pair[0]
        skeleton.add_child(attachment)
        var marker := Marker3D.new()
        attachment.add_child(marker)
        marker.set_meta("rest_basis", skeleton.get_bone_global_rest(skeleton.find_bone(pair[0])).basis.orthonormalized())
        add_base_plate(marker, pair[1])
    visor = MeshInstance3D.new()
    var visor_mesh := BoxMesh.new()
    visor_mesh.size = Vector3(0.24, 0.065, 0.04)
    visor.mesh = visor_mesh
    visor.material_override = visor_glow
    add_child(visor)
    set_skin(load("res://data/skins/standard.tres"))
    set_robot_layer(self)

func set_skin(value: Resource) -> void:
    skin = value
    if not skin: return
    metal.albedo_color = skin.armor_color
    accent.albedo_color = skin.accent_color
    if body_material: body_material.albedo_color = skin.armor_color
    if skin.camouflage:
        var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
        for y in range(128):
            for x in range(128):
                var pattern := sin(float(x) * 0.14 + sin(float(y) * 0.08) * 2.0) + cos(float(y) * 0.12 + float(x) * 0.05)
                image.set_pixel(x, y, Color(0.55, 0.55, 0.55) if pattern > 0.8 else Color.WHITE)
        metal.albedo_texture = ImageTexture.create_from_image(image)
    else: metal.albedo_texture = null

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
        module.build(id, level, metal, dark, glow, accent)
        set_robot_layer(module)
    update_parts()

func update_parts() -> void:
    if is_instance_valid(visor):
        visor.position = to_local(sockets["head"].global_position) + Vector3(0, 0.12, 0.20)
    for part in parts.get_children():
        var socket: Marker3D = sockets[part.get_meta("socket")]
        follow_bone(part, socket, true)
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
    refresh()
    update_parts()
