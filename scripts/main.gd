extends Node2D

const IDS = ["laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar"]
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

func _ready() -> void:
    randomize()
    for binding in [["ui_left", KEY_A], ["ui_right", KEY_D], ["ui_up", KEY_W], ["ui_down", KEY_S]]:
        var key := InputEventKey.new()
        key.physical_keycode = binding[1]
        InputMap.action_add_event(binding[0], key)
    for id in IDS:
        definitions[id] = load("res://data/" + id + ".tres")
    autoplay = "--autoplay" in OS.get_cmdline_user_args()
    if autoplay:
        start_game()
    else:
        show_menu()

func clear_ui() -> void:
    if is_instance_valid(panel):
        panel.queue_free()
    panel = Control.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)

func button(text: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(360, 58)
    b.add_theme_font_size_override("font_size", 22)
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
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_child(center)
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
    box.add_child(button("BEENDEN", func(): get_tree().quit()))
    start.grab_focus()
    queue_redraw()

func start_game() -> void:
    state = UpgradeState.new()
    state.upgrade("laser")
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
    clear_ui()
    status = Label.new()
    status.position = Vector2(30, 24)
    status.add_theme_font_size_override("font_size", 24)
    panel.add_child(status)
    if autoplay:
        for id in ["rocket", "shield", "saw", "thruster", "radar"]:
            for n in range(3): state.upgrade(id)

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
    if mode != "playing":
        return
    elapsed += delta
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
        bullets.append({"pos": player, "vel": dir * 560, "life": 2.0, "damage": 12 + state.level("laser") * 6 + state.level("rocket") * 5})
    for enemy in enemies:
        var diff: Vector2 = player - enemy.pos
        enemy.pos += diff.normalized() * enemy.speed * delta
        if diff.length() < 33:
            hp -= delta * (8.0 - state.level("shield"))
    for bullet in bullets:
        bullet.pos += bullet.vel * delta
        bullet.life -= delta
        for enemy in enemies:
            if bullet.pos.distance_to(enemy.pos) < 22:
                enemy.hp -= bullet.damage
                bullet.life = 0
                break
    bullets = bullets.filter(func(b): return b.life > 0)
    for enemy in enemies:
        if enemy.hp <= 0:
            crystals.append(enemy.pos)
            kills += 1
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
    if hp <= 0 or elapsed >= 600:
        show_end(hp > 0)
    queue_redraw()

func choose_upgrade() -> void:
    if autoplay:
        var candidates := IDS.filter(func(id): return state.level(id) < 5)
        if not candidates.is_empty(): state.upgrade(candidates.pick_random())
        return
    mode = "upgrade"
    clear_ui()
    var box := column()
    box.add_child(heading("AUFSTIEG", 48))
    box.add_child(heading("WÄHLE EIN BAUTEIL", 18))
    var candidates := IDS.filter(func(id): return state.level(id) < 5)
    candidates.shuffle()
    for id in candidates.slice(0, 3):
        var definition = definitions[id]
        var b := button("%s  ·  STUFE %d\n%s" % [definition.title, state.level(id) + 1, definition.description], func():
            state.upgrade(id)
            mode = "playing"
            clear_ui()
            status = Label.new()
            status.position = Vector2(30, 24)
            status.add_theme_font_size_override("font_size", 24)
            panel.add_child(status)
        )
        box.add_child(b)
        if box.get_child_count() == 3: b.grab_focus()

func show_end(won: bool) -> void:
    mode = "end"
    clear_ui()
    var box := column()
    box.add_child(heading("SIEG" if won else "SYSTEM AUSGEFALLEN", 48))
    box.add_child(heading("%d GEGNER  ·  LEVEL %d  ·  %02d:%02d" % [kills, level, int(elapsed) / 60, int(elapsed) % 60], 22))
    var b := button("ZUM MENÜ", show_menu)
    box.add_child(b)
    b.grab_focus()

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    var offset := Vector2(fposmod(-player.x + size.x / 2, 80), fposmod(-player.y + size.y / 2, 80))
    for x in range(-1, int(size.x / 80) + 2):
        draw_line(Vector2(x * 80 + offset.x, 0), Vector2(x * 80 + offset.x, size.y), Color("172b3b"), 1)
    for y in range(-1, int(size.y / 80) + 2):
        draw_line(Vector2(0, y * 80 + offset.y), Vector2(size.x, y * 80 + offset.y), Color("172b3b"), 1)
    if mode == "menu": return
    var center := size / 2
    for crystal in crystals:
        var p: Vector2 = crystal - player + center
        draw_colored_polygon(PackedVector2Array([p + Vector2(0,-8),p + Vector2(6,0),p + Vector2(0,8),p + Vector2(-6,0)]), CYAN)
    for enemy in enemies:
        var p: Vector2 = enemy.pos - player + center
        draw_circle(p, [15, 24, 18][enemy.kind], [PINK, Color("ffb55a"), Color("a96cff")][enemy.kind])
        draw_circle(p, 6, BG)
    for bullet in bullets:
        draw_circle(bullet.pos - player + center, 5, CYAN)
    draw_circle(center, 35 + state.level("shield") * 3, Color(0.2, 0.9, 1.0, 0.12))
    draw_rect(Rect2(center + Vector2(-22,-25),Vector2(44,50)), Color("7893a6"))
    draw_rect(Rect2(center + Vector2(-15,-35),Vector2(30,19)), Color("c4d9df"))
    draw_circle(center, 8 + state.level("armor"), CYAN)
    draw_line(center + Vector2(-18,20), center + Vector2(-25,36), Color("c4d9df"), 8)
    draw_line(center + Vector2(18,20), center + Vector2(25,36), Color("c4d9df"), 8)
    draw_line(center + Vector2(-20,-8), center + Vector2(-40,-8), CYAN, 7)
    if state.level("rocket") > 0:
        for i in range(state.level("rocket")):
            draw_circle(center + Vector2(27 + i * 6, -25), 4, PINK)
    if state.level("saw") > 0:
        draw_circle(center + Vector2.from_angle(elapsed * 3) * 65, 10 + state.level("saw"), Color("ffb55a"))
    if state.level("thruster") > 0:
        draw_circle(center + Vector2(-25,40), 4 + state.level("thruster"), PINK)
        draw_circle(center + Vector2(25,40), 4 + state.level("thruster"), PINK)
