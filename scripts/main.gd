extends Node2D

const IDS = ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar"]
const BG = Color("080f1c")
const CYAN = Color("46f6ef")
const PINK = Color("ff568d")
var state = UpgradeState.new()
var definitions: Dictionary = {}
var player := Vector2.ZERO
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var crystals: Array[Vector2] = []
var elapsed := 0.0
var spawn_clock := 0.0
var fire_clock := 0.0
var hp := 100.0
var xp := 0
var level := 1
var kills := 0
var mode := "menu"
var panel: Control
var status: Label
var touch_origin := Vector2.ZERO
var touch_direction := Vector2.ZERO
var touch_id := -1
var autoplay := false
var demo_time := 0.0
var demo_stage := 0
var robot: RobotVisual
var world_3d: ScrapWorld3D
var boss_spawned := false
var won := false
var shake_enabled := true
var shake := 0.0
var shake_offset := Vector2.ZERO
var hit_flash := 0.0
var particles: Array[Dictionary] = []
var damage_texts: Array[Dictionary] = []
var shot_dir := ""
var resume_mode := "playing"


func _ready() -> void:
    randomize()
    if "--showcase" in OS.get_cmdline_user_args():
        mode = "showcase"
        var showcase = load("res://scripts/showcase.gd").new()
        add_child(showcase)
        set_process(false)
        return
    robot = RobotVisual.new()
    add_child(robot)
    world_3d = ScrapWorld3D.new()
    world_3d.game = self
    add_child(world_3d)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot-dir="): shot_dir = arg.trim_prefix("--shot-dir=")
    for binding in [["ui_left", KEY_A], ["ui_right", KEY_D], ["ui_up", KEY_W], ["ui_down", KEY_S]]:
        var key := InputEventKey.new()
        key.physical_keycode = binding[1]
        InputMap.action_add_event(binding[0], key)
    for id in IDS:
        definitions[id] = load("res://data/" + id + ".tres")
    definitions["swarm"] = load("res://data/swarm.tres")
    autoplay = "--autoplay" in OS.get_cmdline_user_args()
    if autoplay:
        start_game()
    else:
        show_menu()

func clear_ui() -> void:
    if is_instance_valid(panel):
        panel.queue_free()
    panel = Control.new()
    add_child(panel)
    panel.size = get_viewport_rect().size

func button(text: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(360, 58)
    b.add_theme_font_size_override("font_size", 20)
    for style_name in ["normal", "hover", "pressed", "focus"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color("1b3445") if style_name in ["hover", "focus"] else Color("101f30")
        style.border_color = CYAN if style_name in ["hover", "focus"] else Color("34596a")
        style.set_border_width_all(2 if style_name in ["hover", "focus"] else 1)
        style.set_corner_radius_all(5)
        style.content_margin_top = 12
        style.content_margin_bottom = 12
        b.add_theme_stylebox_override(style_name, style)
    b.add_theme_color_override("font_color", Color("d5f3f4"))
    b.pressed.connect(action)
    return b

func heading(text: String, size := 42) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", CYAN)
    return label

func column() -> VBoxContainer:
    var center := CenterContainer.new()
    panel.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)
    return box

func show_menu() -> void:
    mode = "menu"
    clear_ui()
    var box := column()
    box.add_child(heading("S C R A P F O R G E", 54))
    box.add_child(heading("SCHMIEDE DEINEN ÜBERLEBENDEN", 16))
    var start := button("START", start_game)
    box.add_child(start)
    box.add_child(button("EINSTELLUNGEN", show_settings))
    box.add_child(button("BEENDEN", func(): get_tree().quit()))
    start.grab_focus()
    queue_redraw()

func show_settings() -> void:
    mode = "settings"
    clear_ui()
    var box := column()
    box.add_child(heading("EINSTELLUNGEN"))
    var volume := HSlider.new()
    volume.min_value = 0
    volume.max_value = 1
    volume.step = 0.05
    volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))
    volume.custom_minimum_size = Vector2(360, 48)
    volume.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(v)))
    box.add_child(heading("LAUTSTÄRKE", 20))
    box.add_child(volume)
    var shake_button := CheckButton.new()
    shake_button.text = "BILDSCHIRMWACKELN"
    shake_button.button_pressed = shake_enabled
    shake_button.toggled.connect(func(v): shake_enabled = v)
    box.add_child(shake_button)
    var fullscreen := CheckButton.new()
    fullscreen.text = "VOLLBILD"
    fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    fullscreen.toggled.connect(func(v): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED))
    box.add_child(fullscreen)
    var back := button("ZURÜCK", show_menu)
    box.add_child(back)
    volume.grab_focus()

func save_image(path: String) -> void:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var result := image.save_png(path)
    print("Screenshot: ", path, " (", result, ")")

func capture_demo(name: String) -> void:
    if not shot_dir.is_empty():
        DirAccess.make_dir_recursive_absolute(shot_dir)
        save_image(shot_dir.path_join(name + ".png"))

func spark(at: Vector2, color: Color, count: int) -> void:
    for i in range(count):
        particles.append({"pos": at, "vel": Vector2.from_angle(randf()*TAU)*randf_range(40,180), "life": randf_range(0.2,0.6), "color": color})


func start_game() -> void:
    state = UpgradeState.new()
    state.upgrade("minigun")
    player = Vector2.ZERO
    enemies.clear()
    bullets.clear()
    crystals.clear()
    elapsed = 0.0
    hp = 100.0
    xp = 0
    level = 1
    kills = 0
    mode = "playing"
    boss_spawned = false
    won = false
    particles.clear()
    damage_texts.clear()
    robot.state = state
    robot.visible = true
    clear_ui()
    status = Label.new()
    status.position = Vector2(30, 24)
    status.add_theme_font_size_override("font_size", 24)
    panel.add_child(status)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_id == -1:
            touch_id = event.index
            touch_origin = event.position
        elif event.index == touch_id and not event.pressed:
            touch_id = -1
            touch_direction = Vector2.ZERO
    if event is InputEventScreenDrag and event.index == touch_id:
        touch_direction = (event.position - touch_origin).limit_length(80.0) / 80.0

func _process(delta: float) -> void:
    if autoplay:
        demo_time += delta
        if demo_stage == 0 and demo_time >= 2:
            capture_demo("spiel-start")
            demo_stage = 1
        elif demo_stage == 1 and demo_time >= 20:
            choose_upgrade(true)
            demo_stage = 2
        elif demo_stage == 2 and demo_time >= 21:
            capture_demo("level-up")
            demo_stage = 3
        elif demo_stage == 3 and demo_time >= 24:
            state.upgrade("laser")
            resume_game()
            demo_stage = 4
        elif demo_stage == 4 and demo_time >= 57:
            show_end(false)
            demo_stage = 5
        elif demo_stage == 5 and demo_time >= 58:
            capture_demo("ende")
            demo_stage = 6
        elif demo_stage == 6 and demo_time >= 60:
            get_tree().quit()
            return
    robot.visible = false
    world_3d.update_view()
    robot.position = get_viewport_rect().size / 2
    robot.scale = Vector2.ONE * (2.4 if mode == "end" else 1.25)
    if mode == "end": robot.position = Vector2(300, 440)
    if mode != "playing":
        queue_redraw()
        return
    elapsed += delta
    hit_flash = maxf(0.0, hit_flash - delta * 3)
    shake = maxf(0.0, shake - delta * 15)
    shake_offset = Vector2.ZERO
    if shake_enabled and shake > 0:
        shake_offset = Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
        robot.position += shake_offset
    for particle in particles:
        particle.pos += particle.vel * delta
        particle.life -= delta
    particles = particles.filter(func(p): return p.life > 0)
    for label in damage_texts:
        label.pos.y -= delta * 35
        label.life -= delta
    damage_texts = damage_texts.filter(func(d): return d.life > 0)
    if elapsed >= 300 and not boss_spawned:
        boss_spawned = true
        enemies.append({"pos": player + Vector2(600,0), "hp": 1800, "kind": 3, "speed": 45.0})
    var direction := Vector2(Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"), Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
    direction += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)).limit_length(1.0)
    direction += touch_direction
    if autoplay:
        direction = Vector2(cos(elapsed * 0.4), sin(elapsed * 0.4))
    player += direction.limit_length(1.0) * (190.0 + state.level("thruster") * 12.0) * delta
    player = player.clamp(Vector2(-1800, -1200), Vector2(1800, 1200))
    spawn_clock -= delta
    if spawn_clock <= 0:
        spawn_clock = maxf(0.2, 1.15 - elapsed / 650.0)
        var kind := randi() % 3
        var angle := randf() * TAU
        enemies.append({"pos": player + Vector2.from_angle(angle) * 650, "hp": [24, 70, 34][kind], "kind": kind, "speed": [120.0, 50.0, 75.0][kind]})
    fire_clock -= delta
    if fire_clock <= 0 and not enemies.is_empty():
        fire_clock = maxf(0.12, 0.65 - state.level("cooldown") * 0.05)
        var nearest: Dictionary = enemies[0]
        for enemy in enemies:
            if player.distance_squared_to(enemy.pos) < player.distance_squared_to(nearest.pos): nearest = enemy
        var dir: Vector2 = (nearest.pos - player).normalized()
        bullets.append({"pos": player, "vel": dir * 560, "life": 2.0, "damage": 12 + state.level("minigun") * 6 + state.level("laser") * 6 + state.level("rocket") * 5})
        spark(player + dir * 35, CYAN, 4)
        if state.level("swarm"):
            for angle in [-0.25, -0.12, 0.12, 0.25]:
                bullets.append({"pos": player, "vel": dir.rotated(angle) * 460, "life": 2.0, "damage": 36})
    for enemy in enemies:
        var diff: Vector2 = player - enemy.pos
        enemy.pos += diff.normalized() * enemy.speed * delta
        var saw := state.level("saw")
        for i in range(saw):
            var blade := player + Vector2.from_angle(elapsed * 1.8 + TAU * i / saw) * 78
            if enemy.pos.distance_to(blade) < 23: enemy.hp -= delta * 24
        if diff.length() < 33:
            hp -= delta * (8.0 - state.level("shield")) * (1.0 - state.level("armor") * 0.05)
            hit_flash = 0.4
            shake = 2.0
    for bullet in bullets:
        bullet.pos += bullet.vel * delta
        bullet.life -= delta
        for enemy in enemies:
            if bullet.pos.distance_to(enemy.pos) < 22:
                enemy.hp -= bullet.damage
                hit_flash = 0.15
                shake = 3.0
                spark(bullet.pos, CYAN, 5)
                damage_texts.append({"pos": enemy.pos, "value": bullet.damage, "life": 0.7})
                bullet.life = 0
                break
    bullets = bullets.filter(func(b): return b.life > 0)
    for enemy in enemies:
        if enemy.hp <= 0:
            crystals.append(enemy.pos)
            kills += 1
            spark(enemy.pos, PINK, 16)
            if enemy.kind == 3: won = true
    enemies = enemies.filter(func(e): return e.hp > 0)
    for i in range(crystals.size() - 1, -1, -1):
        if player.distance_to(crystals[i]) < 35 + state.level("magnet") * 20:
            crystals.remove_at(i)
            xp += 1
            if xp >= level * 5:
                xp = 0
                level += 1
                choose_upgrade()
                break
    status.text = "HÜLLE %d   ·   LEVEL %d   ·   EP %d/%d   ·   %02d:%02d   ·   %d SCHROTT" % [hp, level, xp, level * 5, int(elapsed) / 60, int(elapsed) % 60, kills]
    if hp <= 0 or won or elapsed >= 600:
        show_end(won or hp > 0)
    queue_redraw()

func choose_upgrade(force_show := false) -> void:
    if autoplay and not force_show:
        var candidates := IDS.filter(func(id): return state.level(id) < 5 and not (state.level("swarm") > 0 and id in ["rocket", "radar"]))
        if not candidates.is_empty(): state.upgrade(candidates.pick_random())
        return
    mode = "upgrade"
    clear_ui()
    var shade := ColorRect.new()
    shade.color = Color(0.02,0.05,0.09,0.86)
    panel.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var box := column()
    box.add_child(heading("AUFSTIEG", 48))
    box.add_child(heading("WÄHLE EIN BAUTEIL", 18))
    var candidates := IDS.filter(func(id): return state.level(id) < 5 and not (state.level("swarm") > 0 and id in ["rocket", "radar"]))
    candidates.shuffle()
    if state.can_evolve(): candidates.push_front("swarm")
    if candidates.is_empty():
        resume_game()
        return
    for id in candidates.slice(0, 3):
        var definition = definitions[id]
        var b := button("%s  ·  STUFE %d\n%s" % [definition.title, state.level(id) + 1, definition.description], func():
            if id == "swarm": state.evolve()
            else: state.upgrade(id)
            mode = "playing"
            clear_ui()
            status = Label.new()
            status.position = Vector2(30, 24)
            status.add_theme_font_size_override("font_size", 24)
            panel.add_child(status)
        )
        box.add_child(b)
        if box.get_child_count() == 3: b.grab_focus()

func resume_game() -> void:
    mode = "playing"
    clear_ui()
    status = Label.new()
    status.position = Vector2(30,24)
    status.add_theme_font_size_override("font_size",24)
    panel.add_child(status)


func show_end(victory: bool) -> void:
    mode = "end"
    clear_ui()
    var box := VBoxContainer.new()
    box.position = Vector2(650, 225)
    box.add_theme_constant_override("separation", 18)
    panel.add_child(box)
    box.add_child(heading("SIEG" if victory else "SYSTEM AUSGEFALLEN", 42))
    box.add_child(heading("DEIN ROBOTER", 30))
    box.add_child(heading("%d GEGNER  ·  LEVEL %d  ·  %02d:%02d" % [kills, level, int(elapsed) / 60, int(elapsed) % 60], 18))
    var saved := heading("", 15)
    var save := button("BILD SPEICHERN", func():
        var path := "user://scrapforge-%d.png" % int(Time.get_unix_time_from_system())
        save_image(path)
        saved.text = "GESPEICHERT: " + ProjectSettings.globalize_path(path)
    )
    box.add_child(save)
    box.add_child(saved)
    var b := button("ZUM MENÜ", show_menu)
    box.add_child(b)
    save.grab_focus()


func _draw() -> void:
    if mode != "menu" and mode != "settings": return
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    var offset := Vector2(fposmod(-player.x + size.x / 2, 80), fposmod(-player.y + size.y / 2, 80))
    # Faint navigational rings and grid accents add depth without obscuring combat.
    for i in range(4):
        draw_arc(size/2, 200+i*160, 0, TAU, 100, Color(0.08,0.25,0.31,0.13), 1)
    for x in range(-1, int(size.x / 80) + 2):
        draw_line(Vector2(x * 80 + offset.x, 0), Vector2(x * 80 + offset.x, size.y), Color("172b3b"), 1)
    for y in range(-1, int(size.y / 80) + 2):
        draw_line(Vector2(0, y * 80 + offset.y), Vector2(size.x, y * 80 + offset.y), Color("172b3b"), 1)
    if mode == "menu" or mode == "settings": return
    var center := size / 2 + shake_offset
    for crystal in crystals:
        var p: Vector2 = crystal - player + center
        draw_colored_polygon(PackedVector2Array([p + Vector2(0,-8),p + Vector2(6,0),p + Vector2(0,8),p + Vector2(-6,0)]), CYAN)
    for enemy in enemies:
        var p: Vector2 = enemy.pos - player + center
        var radius: float = [15, 24, 18, 55][enemy.kind]
        var color: Color = [PINK, Color("ffb55a"), Color("a96cff"), Color("ff714e")][enemy.kind]
        draw_circle(p, radius+8, Color(color.r,color.g,color.b,0.08))
        draw_circle(p, radius, color)
        draw_circle(p, radius*0.7, Color("172237"))
        draw_circle(p, radius*0.28, color)
        for i in range(4):
            var point := p + Vector2.from_angle(i*TAU/4+elapsed*0.4)*radius
            draw_line(point, point+Vector2.from_angle(i*TAU/4+elapsed*0.4)*7, color, 3)
    for bullet in bullets:
        draw_circle(bullet.pos - player + center, 5, CYAN)
    for particle in particles:
        draw_circle(particle.pos - player + center, maxf(1.0, particle.life * 7), particle.color)
    for label in damage_texts:
        draw_string(ThemeDB.fallback_font, label.pos - player + center, str(label.value), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1,1,1,label.life))
    if hit_flash > 0:
        draw_rect(Rect2(Vector2.ZERO,size), Color(1.0,0.15,0.2,hit_flash*0.08))
