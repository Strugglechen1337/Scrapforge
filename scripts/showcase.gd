extends Node3D

var camera: Camera3D
var display: Node3D
var layer: CanvasLayer
var title: Label
var definitions := {}
var shot_dir := ""

func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot-dir="): shot_dir = arg.trim_prefix("--shot-dir=")
    if not shot_dir.is_empty(): DirAccess.make_dir_recursive_absolute(shot_dir)
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("10151d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("c1c5c7")
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.0
    env.glow_enabled = true
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38, -25, 0)
    sun.light_energy = 1.35
    add_child(sun)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-25, 150, 0)
    rim.light_color = Color("8aa7b6")
    rim.light_energy = 0.8
    add_child(rim)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 7.3
    camera.position = Vector3(0, 5.0, 15)
    add_child(camera)
    camera.look_at(Vector3(0, 1.0, 0))
    for id in ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "swarm", "drone"]:
        definitions[id] = load("res://data/" + id + ".tres")
    display = Node3D.new()
    add_child(display)
    layer = CanvasLayer.new()
    add_child(layer)
    title = Label.new()
    title.position = Vector2(60, 48)
    title.add_theme_font_size_override("font_size", 28)
    layer.add_child(title)
    var labels := ["BASIS-CHASSIS", "+ MINIGUN", "+ RAKETEN", "+ DROHNEN & PANZERUNG"]
    title.text = "SCRAPFORGE  |  ENTWICKLUNG DURCH UPGRADES"
    for stage in range(4):
        var x := (stage - 1.5) * 2.45
        var robot := create_robot(x)
        if stage >= 1: robot.state.upgrade("minigun")
        if stage >= 2:
            for n in range(3): robot.state.upgrade("rocket")
        if stage >= 3:
            for id in ["armor", "drone", "thruster"]:
                for n in range(3): robot.state.upgrade(id)
        add_label(labels[stage], x)
    await capture("roboter-stufen.png")
    display.queue_free()
    for child in layer.get_children():
        if child != title: child.queue_free()
    display = Node3D.new()
    add_child(display)
    title.text = "SCRAPFORGE  |  SKINS"
    var skins := ["standard", "red", "green", "yellow", "blue"]
    var names := ["STANDARD", "ROT", "GRÜN", "GELB", "BLAU"]
    for i in range(5):
        var x := (i - 2) * 2.2
        var robot := create_robot(x)
        robot.state.upgrade("minigun")
        robot.set_skin(load("res://data/skins/" + skins[i] + ".tres"))
        add_label(names[i], x)
    await capture("roboter-skins.png")
    display.queue_free()
    for child in layer.get_children():
        if child != title: child.queue_free()
    display = Node3D.new()
    add_child(display)
    title.text = "SCRAPFORGE  |  BAUTEILE STUFE 5"
    var module_ids := ["minigun", "laser", "rocket", "turret", "drone", "shield", "swarm", "radar", "plasma", "flamethrower", "sensor", "thruster", "saw", "armor", "magnet", "cooldown"]
    var module_names := ["Minigun", "Laserkanone", "Raketenwerfer", "Schulterturm", "Drohne", "Schildgenerator", "Schwarm-Werfer", "Radar", "Plasmakanone", "Flammenwerfer", "Sensor", "Schubdüsen", "Sägeblatt", "Panzerung", "Magnet", "Kühlung"]
    camera.size = 8.4
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("56524d")
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color("1c242c")
    var glow := StandardMaterial3D.new()
    glow.albedo_color = Color("ff7a1a")
    glow.emission_enabled = true
    glow.emission = Color("ff7a1a")
    glow.emission_energy_multiplier = 1.5
    for i in range(module_ids.size()):
        var module: Node3D = load("res://scripts/module_visual_3d.gd").new()
        display.add_child(module)
        module.position = Vector3((i % 8 - 3.5) * 1.48, 2.2 - int(i / 8) * 2.3, 0)
        module.rotation_degrees.y = 155
        module.build(module_ids[i], 5, metal, dark, glow)
        var label := Label.new()
        label.text = module_names[i]
        label.size = Vector2(125, 30)
        var screen := camera.unproject_position(module.position + Vector3(0, -0.65, 0))
        label.position = Vector2(screen.x - 62.5, screen.y)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 15)
        layer.add_child(label)
    await capture("bauteile.png")
    get_tree().quit()

func create_robot(x: float) -> Robot3D:
    var robot := Robot3D.new()
    robot.state = UpgradeState.new()
    robot.definitions = definitions
    robot.position.x = x
    robot.rotation_degrees.y = -30
    display.add_child(robot)
    robot.animation.pause()
    var platform := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 0.91
    disc.bottom_radius = 0.91
    disc.height = 0.12
    platform.mesh = disc
    var base := StandardMaterial3D.new()
    base.albedo_color = Color("30333a")
    base.roughness = 0.8
    platform.material_override = base
    platform.position = Vector3(x, -0.08, 0)
    display.add_child(platform)
    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.84
    ring_mesh.outer_radius = 0.88
    ring.mesh = ring_mesh
    var orange := StandardMaterial3D.new()
    orange.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    orange.albedo_color = Color("ff7a1a")
    orange.emission_enabled = true
    orange.emission = Color("ff7a1a")
    orange.emission_energy_multiplier = 0.35
    ring.material_override = orange
    ring.position = Vector3(x, -0.005, 0)
    display.add_child(ring)
    return robot

func add_label(text: String, x: float) -> void:
    var label := Label.new()
    label.text = text
    label.size = Vector2(235, 35)
    var screen := camera.unproject_position(Vector3(x, -0.35, 0))
    label.position = Vector2(screen.x - label.size.x / 2, screen.y + 35)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    layer.add_child(label)

func capture(filename: String) -> void:
    await get_tree().create_timer(2.0).timeout
    await RenderingServer.frame_post_draw
    if not shot_dir.is_empty():
        var result := get_viewport().get_texture().get_image().save_png(shot_dir.path_join(filename))
        print("Showcase ", filename, ": ", result)
