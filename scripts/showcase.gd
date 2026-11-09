extends Node3D

func _ready() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("10151d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("a4b7cb")
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 0.8
    env.glow_enabled = true
    var w := WorldEnvironment.new()
    w.environment = env
    add_child(w)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -25, 0)
    sun.light_energy = 1.0
    add_child(sun)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 8.5
    camera.position = Vector3(0, 6.0, 13)
    camera.look_at_from_position(camera.position, Vector3(0, 1.2, 0))
    add_child(camera)
    for x in [-5.0, 0.0, 5.0]:
        var fill := OmniLight3D.new()
        fill.position = Vector3(x, 3, 4)
        fill.light_color = Color("e0e0df")
        fill.light_energy = 2.0
        fill.omni_range = 12
        add_child(fill)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-25, 150, 0)
    rim.light_color = Color("76adc3")
    rim.light_energy = 0.8
    add_child(rim)
    var defs: Dictionary = {}
    for id in ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "swarm"]:
        defs[id] = load("res://data/" + id + ".tres")
    for stage in range(5):
        var r := Robot3D.new()
        r.state = UpgradeState.new()
        r.definitions = defs
        if stage >= 1:
            for n in range(3): r.state.upgrade("minigun")
        if stage >= 2:
            for n in range(3): r.state.upgrade("rocket")
        if stage >= 3:
            for id in ["armor", "shield", "thruster", "saw", "radar", "laser", "magnet", "cooldown"]:
                for n in range(5): r.state.upgrade(id)
            for n in range(2):
                r.state.upgrade("minigun")
                r.state.upgrade("rocket")
        if stage == 4:
            r.state.evolve()
        r.position.x = (stage - 2) * 2.45
        add_child(r)
    var layer := CanvasLayer.new()
    add_child(layer)
    var title := Label.new()
    title.text = "SCRAPFORGE  |  ENTWICKLUNG DURCH UPGRADES"
    title.position = Vector2(75, 75)
    title.add_theme_font_size_override("font_size", 30)
    layer.add_child(title)
    var labels := ["BASIS-CHASSIS", "+ MINIGUN 3", "+ RAKETEN 3", "VOLLAUSBAU", "ENTWICKLUNG"]
    for i in range(5):
        var label := Label.new()
        label.text = labels[i]
        label.position = Vector2(60 + i * 240, 590)
        label.size = Vector2(225, 50)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 18)
        layer.add_child(label)
    await get_tree().create_timer(2.0).timeout
    await RenderingServer.frame_post_draw
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot-dir="):
            var path := arg.trim_prefix("--shot-dir=")
            DirAccess.make_dir_recursive_absolute(path)
            var result := get_viewport().get_texture().get_image().save_png(path.path_join("roboter-stufen.png"))
            print("Showcase: ", result)
    get_tree().quit()
