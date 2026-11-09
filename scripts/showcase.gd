extends Node3D

func _ready() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("10151d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("a4b7cb")
    env.ambient_light_energy = 1.0
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.0
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
    camera.size = 6.4
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
    for id in ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "swarm", "drone"]:
        defs[id] = load("res://data/" + id + ".tres")
    for stage in range(4):
        var r := Robot3D.new()
        r.state = UpgradeState.new()
        r.definitions = defs
        if stage >= 1:
            for n in range(3): r.state.upgrade("minigun")
        if stage >= 2:
            for n in range(3): r.state.upgrade("rocket")
        if stage >= 3:
            for id in ["armor", "drone", "thruster"]:
                for n in range(3): r.state.upgrade(id)
        r.position.x = (stage - 1.5) * 2.15
        add_child(r)
        var platform := MeshInstance3D.new()
        var disc := CylinderMesh.new()
        disc.top_radius = 0.95
        disc.bottom_radius = 0.95
        disc.height = 0.12
        platform.mesh = disc
        var base_mat := StandardMaterial3D.new()
        base_mat.albedo_color = Color("30333a")
        platform.material_override = base_mat
        platform.position = Vector3(r.position.x, -0.08, 0)
        add_child(platform)
        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.87
        ring_mesh.outer_radius = 0.91
        ring.mesh = ring_mesh
        var orange := StandardMaterial3D.new()
        orange.albedo_color = Color("ff7010")
        orange.emission_enabled = true
        orange.emission = Color("ff7010")
        ring.material_override = orange
        ring.position = Vector3(r.position.x, 0, 0)
        add_child(ring)
    var layer := CanvasLayer.new()
    add_child(layer)
    var title := Label.new()
    title.text = "SCRAPFORGE  |  ENTWICKLUNG DURCH UPGRADES"
    title.position = Vector2(75, 75)
    title.add_theme_font_size_override("font_size", 30)
    layer.add_child(title)
    var labels := ["BASIS-CHASSIS", "+ MINIGUN", "+ RAKETEN", "+ DROHNEN & PANZERUNG"]
    for i in range(4):
        var label := Label.new()
        label.text = labels[i]
        label.position = Vector2(145 + i * 300, 590)
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
    for child in get_children():
        if child is Robot3D: child.queue_free()
    for i in range(5):
        var r := Robot3D.new()
        r.state = UpgradeState.new()
        r.state.upgrade("minigun")
        r.definitions = defs
        r.position.x = (i - 2) * 1.9
        add_child(r)
        r.set_skin(load("res://data/skins/" + ["standard", "red", "green", "yellow", "blue"][i] + ".tres"))
    title.text = "SCRAPFORGE  |  SKINS"
    for child in layer.get_children():
        if child != title: child.queue_free()
    await get_tree().create_timer(2.0).timeout
    await RenderingServer.frame_post_draw
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot-dir="):
            get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot-dir=").path_join("roboter-skins.png"))
    get_tree().quit()
