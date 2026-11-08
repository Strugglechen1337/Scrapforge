extends Node3D
class_name Robot3D

var state: UpgradeState
var definitions: Dictionary = {}
var signature := ""
var metal := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var glow := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var sockets: Dictionary = {}
var parts: Node3D
var legs: Array[Node3D] = []
var clock := 0.0

func _ready() -> void:
    metal.albedo_color = Color("c5cbd2")
    metal.metallic = 0.18
    metal.roughness = 0.65
    metal.albedo_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
    metal.normal_enabled = true
    metal.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
    metal.roughness_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")
    dark.albedo_color = Color("242a32")
    dark.metallic = 0.7
    glow.albedo_color = Color("ff7a1a")
    glow.emission_enabled = true
    glow.emission = Color("ff7a1a")
    glow.emission_energy_multiplier = 3.0
    cyan.albedo_color = Color("33f5ff")
    cyan.emission_enabled = true
    cyan.emission = Color("33f5ff")
    cyan.emission_energy_multiplier = 1.5
    box(self, Vector3(0.85, 0.75, 0.48), Vector3(0, 1.35, 0), dark)
    box(self, Vector3(0.72, 0.45, 0.12), Vector3(0, 1.42, -0.27), metal)
    box(self, Vector3(0.45, 0.12, 0.05), Vector3(0, 1.45, -0.35), glow)
    for side in [-1, 1]:
        box(self, Vector3(0.07, 0.18, 0.035), Vector3(side * 0.22, 1.25, -0.34), cyan)
    box(self, Vector3(0.48, 0.35, 0.4), Vector3(0, 1.92, 0), metal)
    box(self, Vector3(0.35, 0.08, 0.04), Vector3(0, 1.95, -0.22), glow)
    box(self, Vector3(0.56, 0.08, 0.45), Vector3(0, 2.13, 0), dark)
    for side in [-1, 1]:
        box(self, Vector3(0.12, 0.29, 0.16), Vector3(side * 0.27, 1.94, -0.14), dark)
        box(self, Vector3(0.18, 0.32, 0.08), Vector3(side * 0.31, 1.41, -0.36), metal)
        var bevel := MeshInstance3D.new()
        var prism := PrismMesh.new()
        prism.size = Vector3(0.25, 0.3, 0.12)
        bevel.mesh = prism
        bevel.material_override = metal
        bevel.position = Vector3(side * 0.28, 1.18, -0.34)
        bevel.rotation.z = PI if side < 0 else 0.0
        add_child(bevel)
    for side in [-1, 1]:
        var leg := Node3D.new()
        leg.position = Vector3(side * 0.25, 0.9, 0)
        add_child(leg)
        legs.append(leg)
        box(leg, Vector3(0.26, 0.55, 0.28), Vector3(0, -0.22, 0), metal)
        box(leg, Vector3(0.3, 0.26, 0.1), Vector3(0, -0.18, -0.19), dark)
        box(leg, Vector3(0.33, 0.1, 0.18), Vector3(0, -0.37, -0.16), metal)
        box(leg, Vector3(0.3, 0.15, 0.48), Vector3(0, -0.57, -0.08), dark)
        box(self, Vector3(0.32, 0.45, 0.34), Vector3(side * 0.58, 1.34, 0), metal)
        box(self, Vector3(0.46, 0.19, 0.48), Vector3(side * 0.59, 1.64, 0), dark)
        box(self, Vector3(0.40, 0.11, 0.43), Vector3(side * 0.59, 1.75, -0.01), metal)
    for entry in [["left_arm", Vector3(-0.62, 1.25, 0)], ["right_arm", Vector3(0.62, 1.25, 0)], ["left_shoulder", Vector3(-0.55, 1.72, 0)], ["right_shoulder", Vector3(0.55, 1.72, 0)], ["head", Vector3(0, 2.12, 0)], ["back", Vector3(0, 1.45, 0.3)], ["legs", Vector3(0, 0.45, 0)], ["core", Vector3(0, 1.42, -0.35)]]:
        var marker := Marker3D.new()
        marker.name = entry[0]
        marker.position = entry[1]
        add_child(marker)
        sockets[entry[0]] = marker
    parts = Node3D.new()
    add_child(parts)

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
    var m := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    m.mesh = shape
    m.position = pos
    m.material_override = material
    parent.add_child(m)

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
        module.position = sockets[definition.socket].position
        module.build(id, level, metal, dark, glow)

func _process(delta: float) -> void:
    clock += delta
    refresh()
    for i in range(legs.size()): legs[i].rotation.x = sin(clock * 7 + i * PI) * 0.15
