extends Node3D
class_name ScrapWorld3D

var game: Node
var robot: Robot3D
var camera: Camera3D
var entities: Node3D
var enemy_nodes: Array[Node3D] = []
var projectile_nodes: Array[Node3D] = []
var crystal_nodes: Array[Node3D] = []
var collection_ring: MeshInstance3D
var metal := StandardMaterial3D.new()
var red := StandardMaterial3D.new()
var cyan := StandardMaterial3D.new()
var orange := StandardMaterial3D.new()
var elapsed := 0.0

func _ready() -> void:
    metal.albedo_color = Color("30343d")
    metal.metallic = 0.6
    metal.roughness = 0.7
    red = emissive(Color("ff3428"))
    cyan = emissive(Color("33f5ff"))
    orange = emissive(Color("ff7a1a"))
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("10131b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("798a9c")
    env.ambient_light_energy = 0.6
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.glow_enabled = true
    env.fog_enabled = true
    env.fog_light_color = Color("202b39")
    env.fog_density = 0.008
    var environment := WorldEnvironment.new()
    environment.environment = env
    add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -35, 0)
    light.light_energy = 1.6
    light.shadow_enabled = true
    add_child(light)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 20
    camera.position = Vector3(0, 18, 12)
    camera.rotation_degrees.x = -56
    add_child(camera)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("8e98a8")
    floor_material.metallic = 0.4
    floor_material.roughness = 0.85
    floor_material.albedo_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Color.jpg")
    floor_material.normal_enabled = true
    floor_material.normal_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_NormalGL.jpg")
    floor_material.roughness_texture = load("res://assets/third_party/ambientcg/MetalPlates001/MetalPlates001_1K-JPG_Roughness.jpg")
    floor_material.uv1_scale = Vector3(20, 14, 1)
    box(self, Vector3(80, 0.2, 55), Vector3(0, -0.2, 0), floor_material)
    for x in range(-20, 21):
        box(self, Vector3(0.035, 0.012, 55), Vector3(x * 2, -0.09, 0), metal)
    for z in range(-14, 15):
        box(self, Vector3(80, 0.012, 0.035), Vector3(0, -0.09, z * 2), metal)
    for x in range(-18, 19, 2):
        box(self, Vector3(0.8, 0.02, 0.08), Vector3(x * 2, -0.08, -25), orange)
        box(self, Vector3(0.8, 0.02, 0.08), Vector3(x * 2, -0.08, 25), cyan)
    for z in [-8.0, 8.0]:
        box(self, Vector3(35, 0.02, 0.11), Vector3(0, -0.07, z), orange if z < 0 else cyan)
        for i in range(-14, 15):
            var stripe := MeshInstance3D.new()
            var mesh := BoxMesh.new()
            mesh.size = Vector3(0.55, 0.015, 0.15)
            stripe.mesh = mesh
            stripe.material_override = orange if z < 0 else cyan
            stripe.position = Vector3(i * 1.2, -0.06, z + 0.22)
            stripe.rotation.y = 0.6
            add_child(stripe)
    var prop_paths := ["barrel", "machine-generator", "pipe-straight", "monorail-traincargo"]
    for i in range(32):
        var packed: PackedScene = load("res://assets/third_party/kenney/space-kit/" + prop_paths[i % prop_paths.size()] + ".glb")
        var prop := packed.instantiate() as Node3D
        add_child(prop)
        shade_prop(prop)
        prop.position = Vector3((i % 16 - 7.5) * 4.5, 0, -10.0 if i < 16 else 10.0)
        prop.rotation.y = float(i % 4) * PI / 2.0
        prop.scale = Vector3.ONE * 1.4
    for z in [-8.0, 8.0]:
        for x in [-12.0, 0.0, 12.0]:
            var lamp := OmniLight3D.new()
            lamp.position = Vector3(x, 1.0, z)
            lamp.light_color = Color("ff7a1a") if z < 0 else Color("33f5ff")
            lamp.light_energy = 1.2
            lamp.omni_range = 5.0
            add_child(lamp)
    robot = Robot3D.new()
    add_child(robot)
    robot.rotation.y = PI
    collection_ring = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 1.15
    ring.outer_radius = 1.18
    collection_ring.mesh = ring
    collection_ring.material_override = cyan
    add_child(collection_ring)
    entities = Node3D.new()
    add_child(entities)

func emissive(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.5
    return material

func shade_prop(node: Node) -> void:
    if node is MeshInstance3D:
        node.material_override = metal
    for child in node.get_children(): shade_prop(child)

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = material
    parent.add_child(instance)

func create_enemy() -> Node3D:
    var enemy := Node3D.new()
    entities.add_child(enemy)
    box(enemy, Vector3(0.7, 0.3, 0.55), Vector3(0, 0.35, 0), metal)
    box(enemy, Vector3(0.38, 0.08, 0.08), Vector3(0, 0.38, -0.3), red)
    for side in [-1, 1]:
        for i in range(3):
            var leg := Node3D.new()
            leg.position = Vector3(side * 0.45, 0.25, (i - 1) * 0.25)
            leg.rotation_degrees.z = side * 25
            enemy.add_child(leg)
            box(leg, Vector3(0.5, 0.07, 0.07), Vector3(side * 0.15, 0, 0), metal)
    return enemy

func sync_nodes(nodes: Array[Node3D], count: int, kind: String) -> void:
    while nodes.size() < count:
        var node: Node3D
        if kind == "enemy": node = create_enemy()
        else:
            node = Node3D.new()
            entities.add_child(node)
            box(node, Vector3(0.15, 0.15, 0.3) if kind == "bullet" else Vector3(0.2, 0.4, 0.2), Vector3(0, 0.3, 0), orange if kind == "bullet" else cyan)
        nodes.append(node)
    for i in range(nodes.size()): nodes[i].visible = i < count

func update_view() -> void:
    if not game: return
    visible = game.mode != "menu" and game.mode != "settings"
    robot.state = game.state
    robot.definitions = game.definitions
    var center := Vector3(game.player.x / 50.0, 0, game.player.y / 50.0)
    robot.position = center
    collection_ring.position = center + Vector3(0, 0.03, 0)
    collection_ring.scale = Vector3.ONE * (1.0 + game.state.level("magnet") * 0.2)
    camera.position = center + Vector3(0, 18, 12)
    sync_nodes(enemy_nodes, game.enemies.size(), "enemy")
    sync_nodes(projectile_nodes, game.bullets.size(), "bullet")
    sync_nodes(crystal_nodes, game.crystals.size(), "crystal")
    for i in range(game.enemies.size()):
        var e: Dictionary = game.enemies[i]
        enemy_nodes[i].position = Vector3(e.pos.x / 50.0, 0, e.pos.y / 50.0)
        enemy_nodes[i].scale = Vector3.ONE * ([1.0, 1.5, 1.1, 3.0][e.kind])
        enemy_nodes[i].look_at(center + Vector3(0, 0.01, 0))
    for i in range(game.bullets.size()):
        var p: Vector2 = game.bullets[i].pos
        projectile_nodes[i].position = Vector3(p.x / 50.0, 0.5, p.y / 50.0)
    for i in range(game.crystals.size()):
        var p: Vector2 = game.crystals[i]
        crystal_nodes[i].position = Vector3(p.x / 50.0, 0, p.y / 50.0)
