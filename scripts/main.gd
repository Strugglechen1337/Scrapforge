extends Node2D

signal ui_focus_changed(control: Control)
signal ui_confirmed(control: Control)

const IDS = ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "flamethrower", "plasma", "turret", "sensor", "drone"]
const SKIN_IDS = ["standard", "red", "green", "yellow", "blue"]
const SETTINGS_PATH = "user://settings.cfg"
const BG = Color("080f1c")
const CYAN = Color("33f5ff")
const ORANGE = Color("ff7a1a")
const PINK = Color("ff568d")

var weapons = preload("res://scripts/weapons_3d.gd").new()
var state = UpgradeState.new()
var definitions: Dictionary = {}
var skins: Dictionary = {}
var selected_skin := "standard"
var language := "de"
var fullscreen_enabled := false
var graphics_quality := "hoch"

var player := Vector2.ZERO
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var crystals: Array[Vector2] = []
var elapsed := 0.0
var spawn_clock := 0.0
var fire_clock := 0.0
var shot_index := 0
var hp := 100.0
var xp := 0
var total_scrap := 0
var level := 1
var kills := 0
var mode := "menu"
var panel: Control
var status: Label
var hp_bar: ProgressBar
var hp_value_label: Label
var xp_bar: ProgressBar
var xp_value_label: Label
var level_badge_label: Label
var time_label: Label
var scrap_label: Label
var kills_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label
var module_bar: HBoxContainer
var hud_module_sig := ""

var updater: ReleaseUpdater
var touch_controls: TouchControls
var autoplay := false
var shot_menu := false
var camera_shot_mode := ""
var demo_time := 0.0
var demo_stage := 0
var robot: RobotVisual
var world_3d: ScrapWorld3D
var boss_spawned := false
var won := false
var shake_enabled := true
var shake := 0.0
var shake_offset := Vector2.ZERO
var camera_feedback := CameraFeedback.new()
var hitstop_until_msec := 0
var hit_flash := 0.0
var particles: Array[Dictionary] = []
var damage_texts: Array[Dictionary] = []
var shot_dir := ""
var shot_suffix := ""
var shot_frame := Vector2i.ZERO
var resume_mode := "menu"
var fps_samples := 0
var fps_seconds := 0.0
var fps_min := INF
var fps_peak_enemies := 0
var previous_frame_usec := 0
var fps_worst_at := 0.0
## Per-frame samples (demo time, frame seconds) for the 1 % low and the list of worst frames.
var fps_frames: Array[Vector2] = []
var screenshot_stats: Array[String] = []
var screenshot_tasks: Array[int] = []
var menu_buttons: Array[Button] = []
var upgrade_cards: Array[Button] = []
var hangar_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	for id in IDS:
		definitions[id] = load("res://data/" + id + ".tres")
	definitions["swarm"] = load("res://data/swarm.tres")
	for skin_id in SKIN_IDS:
		skins[skin_id] = load("res://data/skins/" + skin_id + ".tres")
	load_settings()
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if "--showcase" in OS.get_cmdline_user_args():
		mode = "showcase"
		var showcase = load("res://scripts/showcase.gd").new()
		add_child(showcase)
		set_process(false)
		return
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	ui_focus_changed.connect(func(_control): AudioManager.play(&"menu_focus"))
	ui_confirmed.connect(func(_control): AudioManager.play(&"menu_confirm"))
	updater = ReleaseUpdater.new()
	touch_controls = TouchControls.new()
	touch_controls.game = self
	add_child(touch_controls)
	robot = RobotVisual.new()
	robot.visible = false
	add_child(robot)
	world_3d = ScrapWorld3D.new()
	world_3d.game = self
	add_child(world_3d)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality=") and not OS.has_feature("mobile"):
			var quality := arg.trim_prefix("--quality=")
			if quality in ["hoch", "mittel", "niedrig"]:
				graphics_quality = quality
				ScrapEnvironment3D.apply_quality(world_3d.lighting.environment, world_3d.lighting.sun, quality)
		if arg.begins_with("--shot-dir="):
			shot_dir = arg.trim_prefix("--shot-dir=")
		elif arg.begins_with("--shot-suffix="):
			shot_suffix = arg.trim_prefix("--shot-suffix=")
		elif arg.begins_with("--shot-frame="):
			var dimensions := arg.trim_prefix("--shot-frame=").split("x")
			if dimensions.size() == 2:
				shot_frame = Vector2i(int(dimensions[0]), int(dimensions[1]))
	for binding in [["ui_left", KEY_A], ["ui_right", KEY_D], ["ui_up", KEY_W], ["ui_down", KEY_S]]:
		var key := InputEventKey.new()
		key.physical_keycode = binding[1]
		InputMap.action_add_event(binding[0], key)
	for joy_bind in [
		["ui_left", JOY_BUTTON_DPAD_LEFT],
		["ui_right", JOY_BUTTON_DPAD_RIGHT],
		["ui_up", JOY_BUTTON_DPAD_UP],
		["ui_down", JOY_BUTTON_DPAD_DOWN],
		["ui_accept", JOY_BUTTON_A],
		["ui_cancel", JOY_BUTTON_B],
	]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = joy_bind[1]
		InputMap.action_add_event(joy_bind[0], jb)
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	shot_menu = "--shot-menu" in OS.get_cmdline_user_args()
	if "--arena-overview" in OS.get_cmdline_user_args():
		call_deferred("run_arena_overview_shots")
	elif "--edge-shot" in OS.get_cmdline_user_args():
		call_deferred("run_edge_shot")
	elif autoplay:
		start_game()
	else:
		show_menu()
	add_child(updater)
	if shot_menu:
		call_deferred("run_menu_shots")
	get_viewport().size_changed.connect(_update_safe_layout)


func _on_gui_focus_changed(control: Control) -> void:
	if is_instance_valid(control):
		ui_focus_changed.emit(control)


func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("player", "skin", selected_skin)
	cfg.set_value("display", "shake_enabled", shake_enabled)
	cfg.set_value("display", "language", language)
	cfg.set_value("display", "fullscreen", fullscreen_enabled)
	cfg.set_value("display", "graphics_quality", graphics_quality)
	cfg.save(path)


func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var loaded_skin := str(cfg.get_value("player", "skin", "standard"))
		if loaded_skin in SKIN_IDS:
			selected_skin = loaded_skin
		shake_enabled = bool(cfg.get_value("display", "shake_enabled", true))
		language = str(cfg.get_value("display", "language", "de"))
		fullscreen_enabled = bool(cfg.get_value("display", "fullscreen", false))
		var quality := str(cfg.get_value("display", "graphics_quality", "hoch"))
		if quality in ["hoch", "mittel", "niedrig"]:
			graphics_quality = quality


func select_skin(skin_id: String, path: String = SETTINGS_PATH) -> void:
	if skin_id not in SKIN_IDS:
		return
	selected_skin = skin_id
	save_settings(path)
	if is_instance_valid(world_3d):
		world_3d.update_view()


func get_selected_skin_resource() -> Resource:
	return skins.get(selected_skin, skins.get("standard"))


func clear_ui() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = Control.new()
	panel.theme = ScrapUI.get_theme()
	add_child(panel)
	_update_safe_layout()


func _update_safe_layout() -> void:
	if is_instance_valid(panel):
		ScrapUI.apply_safe_layout(panel)


func button(text: String, action: Callable, accent: Color = ScrapUI.ORANGE, min_size := Vector2(380, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	ScrapUI.style_button(b, accent, min_size)
	b.pressed.connect(func():
		ui_confirmed.emit(b)
		action.call()
	)
	return b


func heading(text: String, size := 36, color: Color = ScrapUI.ORANGE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func wire_vertical_focus(buttons: Array[Control]) -> void:
	var count := buttons.size()
	for i in range(count):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + count) % count].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % count].get_path()


func wire_horizontal_focus(buttons: Array[Button]) -> void:
	var count := buttons.size()
	for i in range(count):
		buttons[i].focus_neighbor_left = buttons[(i - 1 + count) % count].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % count].get_path()


func show_menu() -> void:
	AudioManager.play_music("menu")
	mode = "menu"
	clear_ui()
	menu_buttons.clear()
	var left_col := VBoxContainer.new()
	left_col.position = Vector2(54, 34)
	left_col.add_theme_constant_override("separation", 18)
	panel.add_child(left_col)

	var logo := ScrapUI.LogoControl.new(Vector2(450, 134))
	left_col.add_child(logo)

	var menu_frame := PanelContainer.new()
	var frame_style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.88), ScrapUI.BORDER_STEEL, 2, 12, 5)
	frame_style.content_margin_left = 22
	frame_style.content_margin_right = 22
	frame_style.content_margin_top = 20
	frame_style.content_margin_bottom = 20
	menu_frame.add_theme_stylebox_override("panel", frame_style)
	left_col.add_child(menu_frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu_frame.add_child(box)

	var entries := [
		["START", start_game, ScrapUI.ORANGE],
		["DEIN HANGAR", show_hangar, ScrapUI.CYAN],
		["EINSTELLUNGEN", func(): resume_mode = "menu"; show_settings(), ScrapUI.ORANGE],
		["NACH UPDATES SUCHEN", func(): updater.check(true), ScrapUI.CYAN],
		["MITWIRKENDE", show_credits, ScrapUI.CYAN],
		["BEENDEN", func(): get_tree().quit(), ScrapUI.ORANGE],
	]
	var focus_controls: Array[Control] = []
	for entry in entries:
		var b := button(entry[0], entry[1], entry[2], Vector2(400, 54))
		box.add_child(b)
		menu_buttons.append(b)
		focus_controls.append(b)
	wire_vertical_focus(focus_controls)

	# Right side Mech platform badge & version label
	var skin_res: SkinDefinition = get_selected_skin_resource()
	var skin_title := skin_res.title.to_upper() if skin_res else "STANDARD"
	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.82), ScrapUI.ORANGE, 1, 8, 4))
	badge_panel.position = Vector2(740, 36)
	panel.add_child(badge_panel)
	ScrapUI.anchor_horizontal(badge_panel, 1.0)
	var badge_lbl := heading("HANGAR-EINHEIT  //  SKIN: " + skin_title, 15, ScrapUI.CYAN)
	badge_panel.add_child(badge_lbl)

	var ver_str := "v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	var ver_lbl := heading("SCRAPFORGE " + ver_str, 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	ver_lbl.position = Vector2(980, 756)
	ver_lbl.custom_minimum_size = Vector2(268, 28)
	panel.add_child(ver_lbl)
	ScrapUI.anchor_horizontal(ver_lbl, 1.0)

	if not menu_buttons.is_empty():
		menu_buttons[0].grab_focus()
	if is_instance_valid(world_3d):
		world_3d.update_view()
	queue_redraw()


func show_credits() -> void:
	mode = "credits"
	clear_ui()
	var frame := PanelContainer.new()
	frame.position = Vector2(54, 34)
	frame.custom_minimum_size = Vector2(1100, 720)
	frame.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.96), ScrapUI.CYAN, 2, 12, 6))
	panel.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	box.add_child(heading("MITWIRKENDE", 28, ScrapUI.CYAN))
	var credits := RichTextLabel.new()
	credits.custom_minimum_size = Vector2(1000, 560)
	credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	credits.scroll_active = true
	credits.text = FileAccess.get_file_as_string("res://CREDITS.md")
	credits.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(credits)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	var up := button("?", func(): credits.get_v_scroll_bar().value -= 180, ScrapUI.CYAN, Vector2(90, 52))
	var down := button("?", func(): credits.get_v_scroll_bar().value += 180, ScrapUI.CYAN, Vector2(90, 52))
	var back := button("ZUR?CK (ESC / B)", show_menu, ScrapUI.ORANGE, Vector2(300, 52))
	for control in [up, down, back]:
		controls.add_child(control)
	wire_horizontal_focus([up, down, back])
	down.grab_focus()
	if is_instance_valid(world_3d):
		world_3d.update_view()
	queue_redraw()


func show_hangar() -> void:
	mode = "hangar"
	clear_ui()
	hangar_buttons.clear()
	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.90), ScrapUI.CYAN, 2, 12, 6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(54, 42)
	frame.custom_minimum_size = Vector2(470, 710)
	panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	box.add_child(heading("DEIN HANGAR", 34, ScrapUI.ORANGE))
	box.add_child(heading("MECH-LACKIERUNG & STILVARIANTEN", 15, ScrapUI.CYAN))

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(1.0, 0.48, 0.10, 0.65)
	box.add_child(sep)

	var focus_controls: Array[Control] = []
	for skin_id: String in SKIN_IDS:
		var skin_def: SkinDefinition = skins[skin_id]
		var is_active: bool = (skin_id == selected_skin)
		var suffix: String = "   [ AKTIV ]" if is_active else ("   · TARN" if skin_def.camouflage else "")
		var b := button("      " + skin_def.title.to_upper() + suffix, func():
			select_skin(skin_id)
			show_hangar()
		, ScrapUI.CYAN if is_active else ScrapUI.ORANGE, Vector2(420, 58))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Color swatches inside button
		var swatch_armor := ColorRect.new()
		swatch_armor.color = skin_def.armor_color
		swatch_armor.position = Vector2(18, 13)
		swatch_armor.size = Vector2(20, 32)
		swatch_armor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(swatch_armor)
		var swatch_accent := ColorRect.new()
		swatch_accent.color = skin_def.accent_color
		swatch_accent.position = Vector2(38, 13)
		swatch_accent.size = Vector2(12, 32)
		swatch_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(swatch_accent)
		b.focus_entered.connect(func():
			select_skin(skin_id)
		)
		box.add_child(b)
		hangar_buttons.append(b)
		focus_controls.append(b)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	box.add_child(spacer)

	var back := button("ZURÜCK ZUM HAUPTMENÜ", show_menu, ScrapUI.ORANGE, Vector2(420, 54))
	box.add_child(back)
	focus_controls.append(back)
	wire_vertical_focus(focus_controls)

	var active_idx := maxi(0, SKIN_IDS.find(selected_skin))
	hangar_buttons[active_idx].grab_focus()
	if is_instance_valid(world_3d):
		world_3d.update_view()
	queue_redraw()


func show_settings() -> void:
	mode = "settings"
	clear_ui()
	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.92), ScrapUI.ORANGE, 2, 12, 6)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(54, 38)
	frame.custom_minimum_size = Vector2(550, 720)
	panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	box.add_child(heading("EINSTELLUNGEN", 34, ScrapUI.ORANGE))
	box.add_child(heading("AUDIO · ANZEIGE · SYSTEM", 15, ScrapUI.CYAN))

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.2, 0.96, 1.0, 0.55)
	box.add_child(sep)

	var focus_controls: Array[Control] = []

	var slider_defs := [
		["GESAMTLAUTSTÄRKE", AudioManager.get_volume("Master"), func(v: float): AudioManager.set_volume("Master", v)],
		["MUSIKLAUTSTÄRKE", AudioManager.get_volume("Musik"), func(v: float): AudioManager.set_volume("Musik", v)],
		["EFFEKTLAUTSTÄRKE", AudioManager.get_volume("Effekte"), func(v: float): AudioManager.set_volume("Effekte", v)],
	]
	for sdef in slider_defs:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var top_row := HBoxContainer.new()
		var title_lbl := heading(sdef[0], 17, ScrapUI.TEXT_LIGHT)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val_lbl := heading("%d %%" % int(round(float(sdef[1]) * 100.0)), 17, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
		top_row.add_child(title_lbl)
		top_row.add_child(val_lbl)
		row.add_child(top_row)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(sdef[1])
		slider.custom_minimum_size = Vector2(480, 38)
		var cb: Callable = sdef[2]
		slider.value_changed.connect(func(v: float):
			val_lbl.text = "%d %%" % int(round(v * 100.0))
			cb.call(v)
		)
		row.add_child(slider)
		box.add_child(row)
		focus_controls.append(slider)

	var shake_button := CheckButton.new()
	shake_button.text = "BILDSCHIRMWACKELN UND TREFFERSTOPP"
	shake_button.button_pressed = shake_enabled
	shake_button.custom_minimum_size = Vector2(480, 52)
	shake_button.toggled.connect(func(v: bool):
		ui_confirmed.emit(shake_button)
		shake_enabled = v
		save_settings()
	)
	box.add_child(shake_button)
	focus_controls.append(shake_button)

	var fullscreen := CheckButton.new()
	fullscreen.text = "VOLLBILDMODUS"
	fullscreen.button_pressed = fullscreen_enabled
	fullscreen.custom_minimum_size = Vector2(480, 52)
	fullscreen.toggled.connect(func(v: bool):
		ui_confirmed.emit(fullscreen)
		fullscreen_enabled = v
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
		save_settings()
	)
	box.add_child(fullscreen)
	focus_controls.append(fullscreen)

	if not OS.has_feature("mobile"):
		var quality_button := OptionButton.new()
		quality_button.custom_minimum_size = Vector2(480, 48)
		for label in ["GRAFIK: HOCH", "GRAFIK: MITTEL", "GRAFIK: NIEDRIG"]:
			quality_button.add_item(label)
		quality_button.select(["hoch", "mittel", "niedrig"].find(graphics_quality))
		quality_button.item_selected.connect(func(index: int):
			graphics_quality = ["hoch", "mittel", "niedrig"][index]
			ScrapEnvironment3D.apply_quality(world_3d.lighting.environment, world_3d.lighting.sun, graphics_quality)
			save_settings()
		)
		box.add_child(quality_button)
		focus_controls.append(quality_button)

	var lang_btn := button("SPRACHE: DEUTSCH", func():
		language = "de"
		save_settings()
	, ScrapUI.CYAN, Vector2(480, 52))
	box.add_child(lang_btn)
	focus_controls.append(lang_btn)

	var back_target := func():
		if resume_mode == "pause":
			show_pause()
		else:
			show_menu()
	var back := button("ZURÜCK (ESC / B)", back_target, ScrapUI.ORANGE, Vector2(480, 54))
	box.add_child(back)
	focus_controls.append(back)

	wire_vertical_focus(focus_controls)
	focus_controls[0].grab_focus()
	if is_instance_valid(world_3d):
		world_3d.update_view()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(updater) and is_instance_valid(updater.overlay):
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		if mode == "playing":
			show_pause()
			get_viewport().set_input_as_handled()
		elif mode == "pause":
			resume_game()
			get_viewport().set_input_as_handled()
		elif mode == "settings":
			if resume_mode == "pause":
				show_pause()
			else:
				show_menu()
			get_viewport().set_input_as_handled()
		elif mode == "hangar" or mode == "credits":
			show_menu()
			get_viewport().set_input_as_handled()


func save_image(path: String) -> void:
	await RenderingServer.frame_post_draw
	var before := Time.get_ticks_usec()
	var image := get_viewport().get_texture().get_image()
	if shot_frame.x > 0 and shot_frame.y > 0:
		# Viewport readback excludes the keep-aspect letterbox. Reconstruct it
		# at the requested window dimensions, preserving the rendered aspect.
		var source_size := image.get_size()
		var factor := minf(float(shot_frame.x) / source_size.x, float(shot_frame.y) / source_size.y)
		var content_size := Vector2i(roundi(source_size.x * factor), roundi(source_size.y * factor))
		image.resize(content_size.x, content_size.y, Image.INTERPOLATE_LANCZOS)
		var framed := Image.create(shot_frame.x, shot_frame.y, false, Image.FORMAT_RGBA8)
		framed.fill(Color.BLACK)
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		framed.blit_rect(image, Rect2i(Vector2i.ZERO, content_size), (shot_frame - content_size) / 2)
		print("Screenshot viewport ", source_size, " framed to ", shot_frame)
		image = framed
	var readback := Time.get_ticks_usec()
	previous_frame_usec = readback
	screenshot_stats.append("%s at %.3fs: main-thread readback %.1fms; PNG encoded asynchronously" % [path.get_file(), demo_time, (readback - before) / 1000.0])
	var task := WorkerThreadPool.add_task(func():
		var result := image.save_png(path)
		print("Screenshot: ", path, " (", result, ")")
	)
	screenshot_tasks.append(task)


func capture_demo(name: String) -> void:
	if not shot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shot_dir)
		save_image(shot_dir.path_join(name + shot_suffix + ".png"))


func spark(at: Vector2, color: Color, count: int) -> void:
	if particles.size() > 64:
		return
	for i in range(count):
		particles.append({"pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(40, 180), "life": randf_range(0.2, 0.6), "color": color})


func start_game() -> void:
	AudioManager.play_music("combat")
	weapons = preload("res://scripts/weapons_3d.gd").new()
	state = UpgradeState.new()
	state.upgrade("minigun")
	player = Vector2.ZERO
	enemies.clear()
	bullets.clear()
	enemy_shots.clear()
	crystals.clear()
	elapsed = 0.0
	spawn_clock = 0.85
	fire_clock = 0.0
	shot_index = 0
	hp = 100.0
	xp = 0
	total_scrap = 0
	level = 1
	kills = 0
	mode = "playing"
	boss_spawned = false
	won = false
	particles.clear()
	damage_texts.clear()
	hud_module_sig = ""
	robot.state = state
	robot.visible = false
	build_hud()
	if is_instance_valid(world_3d):
		world_3d.update_view()


func build_hud() -> void:
	clear_ui()
	# Keep hidden legacy status label for any external script/test compatibility
	status = Label.new()
	status.visible = false
	panel.add_child(status)

	# Top-Left: Hull (Orange) & XP (Cyan) with Level badge
	var tl_panel := PanelContainer.new()
	tl_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.BORDER_STEEL, 2, 10, 5))
	tl_panel.position = Vector2(26, 18)
	tl_panel.custom_minimum_size = Vector2(360, 104)
	panel.add_child(tl_panel)

	var tl_box := VBoxContainer.new()
	tl_box.add_theme_constant_override("separation", 8)
	tl_panel.add_child(tl_box)

	var hp_header := HBoxContainer.new()
	var hp_title := heading("HÜLLE", 16, ScrapUI.ORANGE)
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_value_label = heading("100 / 100", 16, ScrapUI.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	hp_header.add_child(hp_title)
	hp_header.add_child(hp_value_label)
	tl_box.add_child(hp_header)

	hp_bar = ProgressBar.new()
	hp_bar.max_value = 100.0
	hp_bar.value = hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(316, 16)
	var hp_bg := ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.07, 0.95), Color("3c4e63"), 1, 4)
	var hp_fill := ScrapUI.make_chamfer_style(ScrapUI.ORANGE, Color("ffb366"), 1, 4)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	tl_box.add_child(hp_bar)

	var xp_header := HBoxContainer.new()
	level_badge_label = heading("LEVEL 1", 16, ScrapUI.CYAN)
	level_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_value_label = heading("EP 0 / 5", 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	xp_header.add_child(level_badge_label)
	xp_header.add_child(xp_value_label)
	tl_box.add_child(xp_header)

	xp_bar = ProgressBar.new()
	xp_bar.max_value = 5.0
	xp_bar.value = 0.0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(316, 12)
	var xp_bg := ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.07, 0.95), Color("2f4b5e"), 1, 4)
	var xp_fill := ScrapUI.make_chamfer_style(ScrapUI.CYAN, Color("b8fcff"), 1, 4)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	tl_box.add_child(xp_bar)

	# Top-Center: Mission Timer
	var tc_panel := PanelContainer.new()
	var tc_style := ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.ORANGE, 2, 10)
	tc_style.content_margin_top = 8
	tc_style.content_margin_bottom = 8
	tc_panel.add_theme_stylebox_override("panel", tc_style)
	tc_panel.position = Vector2(535, 18)
	tc_panel.custom_minimum_size = Vector2(210, 68)
	panel.add_child(tc_panel)
	ScrapUI.anchor_horizontal(tc_panel, 0.5)

	var tc_box := VBoxContainer.new()
	tc_box.add_theme_constant_override("separation", 0)
	tc_panel.add_child(tc_box)
	tc_box.add_child(heading("EINSATZZEIT", 12, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	time_label = heading("00:00", 28, ScrapUI.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	tc_box.add_child(time_label)

	# Top-Right: Scrap & Kills + Touch Pause Button (>= 48dp)
	var tr_panel := PanelContainer.new()
	tr_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.CYAN, 2, 10, 4))
	tr_panel.position = Vector2(856, 18)
	tr_panel.custom_minimum_size = Vector2(328, 68)
	panel.add_child(tr_panel)
	ScrapUI.anchor_horizontal(tr_panel, 1.0)

	var tr_box := HBoxContainer.new()
	tr_box.add_theme_constant_override("separation", 18)
	tr_panel.add_child(tr_box)
	scrap_label = heading("◆ 0 SCHROTT", 18, ScrapUI.CYAN)
	scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kills_label = heading("⌖ 0 KILLS", 18, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_RIGHT)
	tr_box.add_child(scrap_label)
	tr_box.add_child(kills_label)

	var pause_btn := button("II", show_pause, ScrapUI.ORANGE, Vector2(58, 68))
	pause_btn.position = Vector2(1196, 18)
	pause_btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(pause_btn)
	ScrapUI.anchor_horizontal(pause_btn, 1.0)

	# Bottom-Left: Equipped Module Icons Bar
	module_bar = HBoxContainer.new()
	module_bar.position = Vector2(26, 704)
	module_bar.add_theme_constant_override("separation", 8)
	panel.add_child(module_bar)
	hud_module_sig = ""

	make_boss_bar()
	update_hud()


func make_boss_bar() -> void:
	boss_panel = PanelContainer.new()
	var bstyle := ScrapUI.make_chamfer_style(Color(0.06, 0.03, 0.04, 0.90), ScrapUI.ORANGE, 2, 8, 5)
	bstyle.content_margin_left = 16
	bstyle.content_margin_right = 16
	bstyle.content_margin_top = 8
	bstyle.content_margin_bottom = 8
	boss_panel.add_theme_stylebox_override("panel", bstyle)
	boss_panel.position = Vector2(380, 94)
	boss_panel.custom_minimum_size = Vector2(520, 56)
	boss_panel.visible = false
	panel.add_child(boss_panel)
	ScrapUI.anchor_horizontal(boss_panel, 0.5)

	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 4)
	boss_panel.add_child(bbox)

	boss_label = heading("WARNUNG  //  BOSS: SPINNEN-MECH", 14, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.visible = false
	bbox.add_child(boss_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(484, 18)
	boss_bar.max_value = 1800
	boss_bar.show_percentage = false
	boss_bar.visible = false
	var bg_style := ScrapUI.make_chamfer_style(Color("161018"), Color("6e3a32"), 1, 4)
	boss_bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := ScrapUI.make_chamfer_style(Color("ff3d1a"), ScrapUI.ORANGE, 1, 4)
	boss_bar.add_theme_stylebox_override("fill", fill_style)
	bbox.add_child(boss_bar)


func update_hud() -> void:
	if not is_instance_valid(hp_bar):
		return
	var hull_int := maxi(0, int(round(hp)))
	hp_bar.value = clampf(hp, 0.0, 100.0)
	hp_value_label.text = "%d / 100" % hull_int
	level_badge_label.text = "LEVEL %d" % level
	var max_xp := maxi(1, level * 5)
	xp_bar.max_value = max_xp
	xp_bar.value = clampf(float(xp), 0.0, float(max_xp))
	xp_value_label.text = "EP %d / %d" % [xp, max_xp]
	time_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	scrap_label.text = "◆ %d SCHROTT" % total_scrap
	kills_label.text = "⌖ %d KILLS" % kills
	status.text = "HÜLLE %d   ·   LEVEL %d   ·   EP %d/%d   ·   %02d:%02d   ·   %d SCHROTT" % [hull_int, level, xp, max_xp, int(elapsed) / 60, int(elapsed) % 60, kills]

	var sig := str(state.levels)
	if sig != hud_module_sig and is_instance_valid(module_bar):
		hud_module_sig = sig
		for child in module_bar.get_children():
			module_bar.remove_child(child)
			child.queue_free()
		for id: String in ["swarm"] + IDS:
			var lv: int = state.level(id)
			if lv <= 0:
				continue
			var slot := PanelContainer.new()
			var accent := ScrapUI.module_accent(id)
			var sstyle := ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.90), accent, 2, 6)
			sstyle.content_margin_left = 6
			sstyle.content_margin_right = 6
			sstyle.content_margin_top = 4
			sstyle.content_margin_bottom = 4
			slot.add_theme_stylebox_override("panel", sstyle)
			slot.custom_minimum_size = Vector2(56, 72)
			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 2)
			slot.add_child(vbox)
			var icon := ScrapUI.ModuleIcon.new(id, true)
			vbox.add_child(icon)
			var lv_txt := "EVO" if id == "swarm" else ("S%d" % lv)
			vbox.add_child(heading(lv_txt, 13, accent, HORIZONTAL_ALIGNMENT_CENTER))
			module_bar.add_child(slot)


func make_enemy(kind: int, position: Vector2) -> Dictionary:
	var initial_attack := randf_range(2.5, 6.5) if kind == 2 else (1.0 if kind == 3 else 2.0)
	var stop_d := 68.0 if kind == 3 else (220.0 if kind == 2 else 30.0)
	return {"pos": position, "hp": [24, 70, 34, 1800][kind], "kind": kind, "speed": [120.0, 50.0, 75.0, 45.0][kind], "attack": initial_attack, "jump_clock": 6.0, "jump_warning": 0.0, "jump_target": position, "flash": 0.0, "stop_dist": stop_d, "fresh": true}


func spawn_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	AudioManager.play(&"boss")
	enemies.append(make_enemy(3, player + Vector2(215, 25)))


func shoot_enemy(origin: Vector2, direction: Vector2, speed := 240.0) -> void:
	if enemy_shots.size() >= 32:
		return
	enemy_shots.append({"pos": origin, "vel": direction.normalized() * speed, "life": 4.0})


func write_fps_report() -> void:
	if fps_samples == 0 or shot_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var file := FileAccess.open(shot_dir.path_join("fps.txt"), FileAccess.WRITE)
	if file:
		var result := "FPS min %.1f average %.1f samples %d peak_enemies %d (only frames with >=150 enemies)" % [fps_min, fps_samples / fps_seconds, fps_samples, fps_peak_enemies]
		file.store_line(result)
		file.store_line("worst_frame_at %.3fs" % fps_worst_at)
		# The single worst frame is a hitch metric; the 1 % low shows sustained smoothness.
		var sorted_frames := fps_frames.duplicate()
		sorted_frames.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
		var low_count := maxi(1, sorted_frames.size() / 100)
		var low_seconds := 0.0
		for i in range(low_count):
			low_seconds += sorted_frames[i].y
		file.store_line("FPS 1%% low %.1f (slowest %d frames averaged)" % [low_count / low_seconds, low_count])
		var worst: PackedStringArray = []
		for i in range(mini(8, sorted_frames.size())):
			worst.append("%.1fms@%.2fs" % [sorted_frames[i].y * 1000.0, sorted_frames[i].x])
		file.store_line("worst_frames " + ", ".join(worst))
		for stat in screenshot_stats:
			file.store_line(stat)
		print(result)


func _process(delta: float) -> void:
	release_hitstop()
	if autoplay:
		var now := Time.get_ticks_usec()
		if previous_frame_usec > 0 and mode == "playing" and enemies.size() >= 150:
			var frame_time := float(now - previous_frame_usec) / 1000000.0
			if frame_time > 0:
				fps_samples += 1
				fps_seconds += frame_time
				fps_frames.append(Vector2(demo_time, frame_time))
				if 1.0 / frame_time < fps_min:
					fps_min = 1.0 / frame_time
					fps_worst_at = demo_time
				fps_peak_enemies = maxi(fps_peak_enemies, enemies.size())
		previous_frame_usec = now
		demo_time += delta
		if demo_stage == 0 and demo_time >= 2:
			capture_demo("spiel-start")
			demo_stage = 1
		elif demo_stage == 1 and demo_time >= 5.5 and level == 1:
			for id in ["minigun", "rocket", "turret", "shield", "saw", "thruster", "radar", "armor"]:
				for n in range(3):
					state.upgrade(id)
			level = 9
			update_hud()
		elif demo_stage == 1 and demo_time >= 6:
			for i in range(175):
				var angle := PI * 0.32 + TAU * 0.78 * (float(i) / 175.0) + float(i % 5) * 0.03
				var ring := i % 12
				var distance := 230.0 + ring * 32.0
				var kind := 2 if i % 14 == 0 else (1 if i % 5 == 0 else 0)
				var e := make_enemy(kind, player + Vector2.from_angle(angle) * distance)
				if kind != 2:
					var hold_r := 65.0 + float(ring) * 24.0 + float(i % 4) * 8.0
					e["slot"] = Vector2.from_angle(angle) * hold_r
				enemies.append(e)
			world_3d.swarm.update_swarm(enemies, player, 0.0)
			previous_frame_usec = Time.get_ticks_usec()
			demo_stage = 2
		elif demo_stage == 2 and demo_time >= 8:
			var has_explosion := world_3d.effects_3d.effects.any(func(e): return e.get("kind", "") == "explosion")
			var has_damage := world_3d.effects_3d.effects.any(func(e): return e.get("label", false))
			if (has_explosion and has_damage) or demo_time >= 11:
				capture_demo("spiel-spaet")
				capture_demo("spiel-hud")
				demo_stage = 3
		elif demo_stage == 3 and demo_time >= 18:
			spawn_boss()
			demo_stage = 4
		elif demo_stage == 4 and demo_time >= 19.4:
			capture_demo("boss")
			demo_stage = 5
		elif demo_stage == 5 and demo_time >= 57:
			show_end(false)
			demo_stage = 6
		elif demo_stage == 6 and demo_time >= 58:
			capture_demo("ende")
			demo_stage = 7
		elif demo_stage == 7 and demo_time >= 60:
			for task in screenshot_tasks:
				WorkerThreadPool.wait_for_task_completion(task)
			write_fps_report()
			get_tree().quit()
			return
	robot.visible = false
	world_3d.update_view()
	if mode != "playing":
		queue_redraw()
		return
	elapsed += delta
	hit_flash = maxf(0.0, hit_flash - delta * 3)
	shake = maxf(0.0, shake - delta * 15)
	shake_offset = Vector2.ZERO
	if shake_enabled and shake > 0:
		shake_offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	for particle in particles:
		particle.pos += particle.vel * delta
		particle.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	for label in damage_texts:
		label.pos.y -= delta * 35
		label.life -= delta
	damage_texts = damage_texts.filter(func(d): return d.life > 0)
	if elapsed >= 300 and not boss_spawned:
		spawn_boss()
	var direction := Vector2(Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"), Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	direction += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)).limit_length(1.0)
	direction += Vector2(Input.get_action_strength("touch_right") - Input.get_action_strength("touch_left"), Input.get_action_strength("touch_down") - Input.get_action_strength("touch_up"))
	if autoplay:
		direction = Vector2(cos(elapsed * 0.4), sin(elapsed * 0.4))
		if demo_stage in [2, 4]:
			direction = Vector2.ZERO
	player += direction.limit_length(1.0) * (190.0 + state.level("thruster") * 12.0) * delta
	player = player.clamp(Vector2(-1800, -1200), Vector2(1800, 1200))
	spawn_clock -= delta
	if spawn_clock <= 0:
		if autoplay and demo_stage >= 2:
			spawn_clock = 0.22 if enemies.size() < 168 else 0.85
			var roll_auto := randi() % 12
			var kind_auto := 0 if roll_auto < 9 else (1 if roll_auto < 11 else 2)
			var a_auto := PI * 0.32 + randf() * TAU * 0.78
			var e_auto := make_enemy(kind_auto, player + Vector2.from_angle(a_auto) * 460)
			if kind_auto != 2:
				e_auto["slot"] = Vector2.from_angle(a_auto) * randf_range(65.0, 280.0)
			enemies.append(e_auto)
		else:
			spawn_clock = lerpf(2.2, 0.28, clampf(elapsed / 240.0, 0.0, 1.0))
			var wave_count := 2 if (elapsed < 2.0 or elapsed >= 180.0) else 1
			for w in range(wave_count):
				var roll := randi() % 100
				var kind := 0
				if elapsed >= 60.0:
					kind = 0 if roll < 72 else (1 if roll < 92 else 2)
				elif elapsed >= 25.0:
					kind = 0 if roll < 80 else 1
				var angle := randf() * TAU
				var spawn_dist := 280.0 if elapsed < 5.0 else 580.0
				enemies.append(make_enemy(kind, player + Vector2.from_angle(angle) * spawn_dist))
	AudioManager.set_listener(player)
	weapons.update(self, delta)
	fire_clock -= delta
	if fire_clock <= 0 and not enemies.is_empty():
		fire_clock = maxf(0.12, 0.65 - state.level("cooldown") * 0.05)
		var nearest: Dictionary = enemies[0]
		for enemy in enemies:
			if player.distance_squared_to(enemy.pos) < player.distance_squared_to(nearest.pos):
				nearest = enemy
		var dir: Vector2 = (nearest.pos - player).normalized()
		shot_index += 1
		var rocket_shot := state.level("rocket") > 0 and shot_index % 3 == 0
		AudioManager.play(&"rocket" if rocket_shot else &"minigun", player)
		bullets.append({"pos": player, "vel": dir * 560, "life": 2.0, "damage": 12 + state.level("minigun") * 6 + state.level("rocket") * 5, "rocket": rocket_shot})
		spark(player + dir * 35, CYAN, 4)
		world_3d.effects_3d.burst(player + dir * 28, "muzzle")
		if state.level("swarm"):
			for angle in [-0.25, -0.12, 0.12, 0.25]:
				bullets.append({"pos": player, "vel": dir.rotated(angle) * 460, "life": 2.0, "damage": 36})
	for enemy in enemies:
		var diff: Vector2 = player - enemy.pos
		enemy.flash = maxf(0.0, enemy.get("flash", 0.0) - delta)
		var goal: Vector2 = player + enemy.get("slot", Vector2.ZERO)
		var to_goal: Vector2 = goal - enemy.pos
		var stop_dist: float = enemy.get("stop_dist", 32.0)
		if enemy.has("slot"):
			if to_goal.length() > 12.0:
				enemy.pos += to_goal.normalized() * enemy.speed * delta
		elif diff.length() > stop_dist:
			enemy.pos += diff.normalized() * enemy.speed * delta
		if enemy.kind in [2, 3]:
			enemy.attack = enemy.get("attack", 2.0) - delta
			if enemy.attack <= 0:
				enemy.attack = randf_range(5.8, 8.5) if enemy.kind == 2 else 3.2
				if enemy.kind == 2:
					shoot_enemy(enemy.pos, diff)
				else:
					for spread in [-0.5, -0.25, 0.0, 0.25, 0.5]:
						shoot_enemy(enemy.pos, diff.rotated(spread), 280.0)
			if enemy.kind == 3:
				enemy.jump_clock = enemy.get("jump_clock", 6.0) - delta
				if enemy.jump_clock <= 0 and enemy.get("jump_warning", 0.0) <= 0:
					enemy.jump_target = player
					enemy.jump_warning = 1.1
					enemy.jump_clock = 8.0
				if enemy.get("jump_warning", 0.0) > 0:
					enemy.jump_warning -= delta
					if enemy.jump_warning <= 0:
						enemy.pos = enemy.jump_target
						world_3d.effects_3d.burst(enemy.pos, "explosion")
						AudioManager.play(&"explosion", enemy.pos)
						feedback("boss_slam")
						if enemy.pos.distance_to(player) < 100:
							weapons.damage(self, 25)
		var saw := state.level("saw")
		for i in range(saw):
			var blade := player + Vector2.from_angle(elapsed * 1.8 + TAU * i / saw) * 78
			if enemy.pos.distance_to(blade) < 23:
				enemy.hp -= delta * 24
		if diff.length() < 36:
			weapons.damage(self, delta * 8.0 * (1.0 - state.level("armor") * 0.05))
			hit_flash = 0.4
	for bullet in bullets:
		bullet.pos += bullet.vel * delta
		bullet.life -= delta
		for enemy in enemies:
			if bullet.pos.distance_to(enemy.pos) < 22:
				if bullet.get("plasma", false):
					for victim in enemies:
						if victim.pos.distance_to(enemy.pos) < 100:
							victim.hp -= bullet.damage
					world_3d.effects_3d.burst(bullet.pos, "explosion")
				else:
					enemy.hp -= bullet.damage
				enemy.flash = 0.15
				AudioManager.play(&"enemy_hit", enemy.pos)
				if bullet.get("rocket", false) or bullet.get("plasma", false):
					AudioManager.play(&"explosion", bullet.pos)
				if bullet.get("rocket", false):
					world_3d.effects_3d.burst(bullet.pos, "explosion")
				hit_flash = 0.15
				if enemy.kind == CameraFeedback.KIND_BOSS:
					feedback("boss_hit")
				spark(bullet.pos, CYAN, 5)
				damage_texts.append({"pos": enemy.pos, "value": bullet.damage, "life": 0.7})
				world_3d.effects_3d.damage(enemy.pos, bullet.damage)
				bullet.life = 0
				break
	bullets = bullets.filter(func(b): return b.life > 0)
	for shot in enemy_shots:
		shot.pos += shot.vel * delta
		shot.life -= delta
		if shot.pos.distance_to(player) < 25:
			weapons.damage(self, 8)
			feedback("player_shot")
			shot.life = 0
	enemy_shots = enemy_shots.filter(func(b): return b.life > 0)
	for enemy in enemies:
		if enemy.hp <= 0:
			crystals.append(enemy.pos)
			kills += 1
			spark(enemy.pos, PINK, 16)
			world_3d.effects_3d.burst(enemy.pos, "explosion")
			AudioManager.play(&"explosion", enemy.pos)
			if enemy.kind == CameraFeedback.KIND_BOSS:
				won = true
				feedback("boss_death")
			elif enemy.kind == CameraFeedback.KIND_BRUTE:
				feedback("brute_death")
	enemies = enemies.filter(func(e): return e.hp > 0)
	for i in range(crystals.size() - 1, -1, -1):
		var distance := player.distance_to(crystals[i])
		var magnet_range := 35 + state.level("magnet") * 20 + state.level("sensor") * 20
		if distance < magnet_range * 2 and distance > 8:
			crystals[i] = crystals[i].move_toward(player, 180 * delta)
		if player.distance_to(crystals[i]) < 35 + state.level("magnet") * 20 + state.level("sensor") * 20:
			world_3d.effects_3d.burst(crystals[i], "pickup")
			AudioManager.play(&"pickup", crystals[i])
			crystals.remove_at(i)
			xp += 1
			total_scrap += 1
			if xp >= level * 5:
				xp = 0
				level += 1
				AudioManager.play(&"level_up")
				choose_upgrade()
				break
	if autoplay:
		hp = 100.0
	update_hud()
	if is_instance_valid(boss_bar):
		var bosses := enemies.filter(func(e): return e.kind == 3)
		boss_bar.visible = not bosses.is_empty()
		boss_label.visible = boss_bar.visible
		if is_instance_valid(boss_panel):
			boss_panel.visible = boss_bar.visible
		if not bosses.is_empty():
			boss_bar.value = maxf(0.0, bosses[0].hp)
	if hp <= 0 or won or elapsed >= 600:
		show_end(won or hp > 0)
	queue_redraw()


func choose_upgrade(force_show := false) -> void:
	if autoplay and not force_show:
		var auto_candidates := IDS.filter(func(id): return state.can_upgrade(id) and not (state.level("swarm") > 0 and id in ["rocket", "radar"]))
		if not auto_candidates.is_empty():
			state.upgrade(auto_candidates.pick_random())
			AudioManager.play(&"upgrade")
		return
	mode = "upgrade"
	clear_ui()
	upgrade_cards.clear()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.84)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_box := VBoxContainer.new()
	root_box.position = Vector2(60, 44)
	root_box.custom_minimum_size = Vector2(1160, 710)
	root_box.add_theme_constant_override("separation", 18)
	panel.add_child(root_box)
	ScrapUI.anchor_horizontal(root_box, 0.5)

	root_box.add_child(heading("SYSTEM-AUFSTIEG  //  LEVEL %d" % level, 40, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	root_box.add_child(heading("WÄHLE EIN MODULARES BAUTEIL FÜR DEINEN MECH", 16, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var candidates := IDS.filter(func(id): return state.can_upgrade(id) and not (state.level("swarm") > 0 and id in ["rocket", "radar"]))
	if not force_show:
		candidates.shuffle()
	if state.can_evolve():
		candidates.push_front("swarm")
	if candidates.is_empty():
		resume_game()
		return

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 24)
	root_box.add_child(cards_row)

	var shown: Array = candidates.slice(0, 3)
	for id: String in shown:
		var definition: UpgradeDefinition = definitions[id]
		var is_evo: bool = (id == "swarm")
		var cur_lv: int = state.level(id)
		var next_lv: int = 1 if is_evo else (cur_lv + 1)
		var card_accent: Color = ScrapUI.CYAN if is_evo else ScrapUI.ORANGE
		var card := Button.new()
		card.custom_minimum_size = Vector2(356, 460)
		card.focus_mode = Control.FOCUS_ALL
		card.text = ""
		card.set_meta("upgrade_id", id)

		var c_normal := ScrapUI.make_chamfer_style(Color(0.055, 0.082, 0.128, 0.94), ScrapUI.CYAN if is_evo else ScrapUI.BORDER_STEEL, 3 if is_evo else 2, 12, 4)
		var c_hover := ScrapUI.make_chamfer_style(Color(0.11, 0.155, 0.225, 0.98), card_accent, 3, 12, 6, Color(card_accent.r, card_accent.g, card_accent.b, 0.42), 10)
		var c_focus := ScrapUI.make_chamfer_style(Color(0.135, 0.185, 0.265, 0.99), card_accent, 4, 12, 8, Color(card_accent.r, card_accent.g, card_accent.b, 0.65), 14)
		card.add_theme_stylebox_override("normal", c_normal)
		card.add_theme_stylebox_override("hover", c_hover)
		card.add_theme_stylebox_override("focus", c_focus)
		card.add_theme_stylebox_override("pressed", c_focus)

		var inner := VBoxContainer.new()
		inner.position = Vector2(22, 18)
		inner.custom_minimum_size = Vector2(312, 424)
		inner.add_theme_constant_override("separation", 10)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)

		var sock_txt := ScrapUI.socket_label(id, definition.socket)
		var sock_lbl := heading(sock_txt, 14, ScrapUI.CYAN if is_evo else ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(sock_lbl)

		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := ScrapUI.ModuleIcon.new(id, false)
		icon_center.add_child(icon)
		inner.add_child(icon_center)

		var title_lbl := heading(definition.title.to_upper(), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(title_lbl)

		var step_txt := "★ ENTWICKLUNG ★" if is_evo else ("NEU  ·  STUFE 1" if cur_lv == 0 else ("STUFE %d → %d" % [cur_lv, next_lv]))
		var step_lbl := heading(step_txt, 17, ScrapUI.CYAN if (is_evo or cur_lv > 0) else ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(step_lbl)

		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(0, 2)
		sep.color = Color(card_accent.r, card_accent.g, card_accent.b, 0.5)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sep)

		var desc_lbl := Label.new()
		desc_lbl.text = definition.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.custom_minimum_size = Vector2(304, 68)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", ScrapUI.TEXT_LIGHT)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(desc_lbl)

		var stat_val := definition.values[clampi(next_lv - 1, 0, definition.values.size() - 1)] if not definition.values.is_empty() else 0.0
		if int(round(stat_val)) != 0:
			var stat_lbl := heading("MODULLEISTUNG: %d" % int(round(stat_val)), 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			inner.add_child(stat_lbl)

		var action_lbl := heading("[ BAUTEIL MONTIEREN ]", 16, card_accent, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(action_lbl)

		card.pivot_offset = Vector2(178, 230)
		card.focus_entered.connect(func():
			card.scale = Vector2(1.035, 1.035)
		)
		card.focus_exited.connect(func():
			card.scale = Vector2.ONE
		)
		card.pressed.connect(func():
			ui_confirmed.emit(card)
			AudioManager.play(&"upgrade")
			if id == "swarm":
				state.evolve()
			else:
				state.upgrade(id)
			resume_game()
		)
		cards_row.add_child(card)
		upgrade_cards.append(card)

	wire_horizontal_focus(upgrade_cards)
	if not upgrade_cards.is_empty():
		upgrade_cards[0].grab_focus()


func show_pause() -> void:
	mode = "pause"
	clear_ui()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.78)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.05, 0.075, 0.118, 0.95), ScrapUI.ORANGE, 2, 12, 6, Color(1.0, 0.48, 0.1, 0.35), 12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(460, 0)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)

	box.add_child(heading("PAUSE", 38, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(heading("SYSTEME IN BEREITSCHAFT", 15, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var b_resume := button("WEITER", resume_game, ScrapUI.ORANGE, Vector2(390, 54))
	var b_settings := button("EINSTELLUNGEN", func():
		resume_mode = "pause"
		show_settings()
	, ScrapUI.CYAN, Vector2(390, 54))
	var b_quit := button("AUFGEBEN", func(): show_end(false), ScrapUI.ORANGE, Vector2(390, 54))
	box.add_child(b_resume)
	box.add_child(b_settings)
	box.add_child(b_quit)
	wire_vertical_focus([b_resume, b_settings, b_quit])
	b_resume.grab_focus()


func resume_game() -> void:
	mode = "playing"
	build_hud()


## Camera shake and hit-stop for heavy events only (see CameraFeedback).
## Both follow the "screen shake" setting. Hit-stop is skipped on Android.
func feedback(event_name: String) -> void:
	var result := camera_feedback.event(event_name, Time.get_ticks_msec() / 1000.0, shake_enabled)
	shake = maxf(shake, result.shake)
	if result.hitstop > 0.0 and not OS.has_feature("mobile"):
		Engine.time_scale = CameraFeedback.HITSTOP_SCALE
		hitstop_until_msec = Time.get_ticks_msec() + int(result.hitstop * 1000.0)

func release_hitstop() -> void:
	if Engine.time_scale != 1.0 and Time.get_ticks_msec() >= hitstop_until_msec:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func show_end(victory: bool) -> void:
	AudioManager.play(&"victory" if victory else &"game_over")
	AudioManager.play_music("menu")
	mode = "end"
	clear_ui()
	if is_instance_valid(world_3d):
		world_3d.update_view()

	# Left side: "DEIN ROBOTER" showcase header above the rotating 3D Mech on the platform
	var left_badge := PanelContainer.new()
	left_badge.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.88), ScrapUI.ORANGE, 2, 10, 5))
	left_badge.position = Vector2(54, 36)
	left_badge.custom_minimum_size = Vector2(440, 82)
	panel.add_child(left_badge)

	var lb_box := VBoxContainer.new()
	lb_box.add_theme_constant_override("separation", 2)
	left_badge.add_child(lb_box)
	lb_box.add_child(heading("DEIN ROBOTER", 28, ScrapUI.ORANGE))
	var skin_res: SkinDefinition = get_selected_skin_resource()
	var skin_name := skin_res.title.to_upper() if skin_res else "STANDARD"
	lb_box.add_child(heading("ENDKONFIGURATION  ·  SKIN: " + skin_name, 14, ScrapUI.CYAN))

	# Right side: Victory/Game-Over Banner, Statistics, Equipped Modules List, and Action Buttons
	var right_frame := PanelContainer.new()
	var rstyle := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.92), ScrapUI.CYAN if victory else ScrapUI.ORANGE, 2, 12, 6)
	rstyle.content_margin_left = 26
	rstyle.content_margin_right = 26
	rstyle.content_margin_top = 20
	rstyle.content_margin_bottom = 20
	right_frame.add_theme_stylebox_override("panel", rstyle)
	right_frame.position = Vector2(560, 36)
	right_frame.custom_minimum_size = Vector2(666, 728)
	panel.add_child(right_frame)
	ScrapUI.anchor_horizontal(right_frame, 1.0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	right_frame.add_child(box)

	box.add_child(heading("SIEG  //  ARENA GESICHERT" if victory else "SYSTEM AUSGEFALLEN", 34, ScrapUI.CYAN if victory else ScrapUI.ORANGE))
	box.add_child(heading("EINSATZBERICHT & BAUTEIL-ÜBERSICHT", 15, ScrapUI.TEXT_MUTED))

	# Stats Grid
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.075, 0.92), ScrapUI.BORDER_STEEL, 1, 8))
	box.add_child(stats_panel)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(stats_grid)

	var equipped_ids := (["swarm"] + IDS).filter(func(id): return state.level(id) > 0)
	for pair in [
		["ZEIT", "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], ScrapUI.TEXT_LIGHT],
		["ABSCHÜSSE", str(kills), ScrapUI.ORANGE],
		["SCHROTT", str(total_scrap), ScrapUI.CYAN],
		["STUFE", "LEVEL %d" % level, ScrapUI.ORANGE],
	]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(heading(pair[0], 13, ScrapUI.TEXT_MUTED))
		cell.add_child(heading(pair[1], 22, pair[2]))
		stats_grid.add_child(cell)

	box.add_child(heading("INSTALLIERTE BAUTEILE (%d)" % equipped_ids.size(), 16, ScrapUI.CYAN))

	var module_scroll := ScrollContainer.new()
	module_scroll.custom_minimum_size = Vector2(0, 240)
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(module_scroll)
	var mod_grid := GridContainer.new()
	mod_grid.columns = 2
	mod_grid.add_theme_constant_override("h_separation", 10)
	mod_grid.add_theme_constant_override("v_separation", 8)
	module_scroll.add_child(mod_grid)

	for id: String in equipped_ids:
		var def: UpgradeDefinition = definitions[id]
		var lv: int = state.level(id)
		var mcard := PanelContainer.new()
		var maccent := ScrapUI.module_accent(id)
		var mstyle := ScrapUI.make_chamfer_style(Color(0.035, 0.055, 0.088, 0.92), maccent, 1, 6, 3)
		mstyle.content_margin_left = 10
		mstyle.content_margin_right = 10
		mstyle.content_margin_top = 6
		mstyle.content_margin_bottom = 6
		mcard.add_theme_stylebox_override("panel", mstyle)
		mcard.custom_minimum_size = Vector2(298, 52)
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		mcard.add_child(mrow)
		mrow.add_child(ScrapUI.ModuleIcon.new(id, true))
		var mtxt := VBoxContainer.new()
		mtxt.add_theme_constant_override("separation", 0)
		mtxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mtxt.add_child(heading(def.title.to_upper(), 15, ScrapUI.TEXT_LIGHT))
		mtxt.add_child(heading(ScrapUI.socket_label(id, def.socket), 11, ScrapUI.TEXT_MUTED))
		mrow.add_child(mtxt)
		mrow.add_child(heading("EVO" if id == "swarm" else ("STUFE %d" % lv), 15, maccent, HORIZONTAL_ALIGNMENT_RIGHT))
		mod_grid.add_child(mcard)

	var saved := heading("", 14, ScrapUI.CYAN)
	var btn_save := button("SCREENSHOT SPEICHERN", func():
		var path := "user://scrapforge-%d.png" % int(Time.get_unix_time_from_system())
		save_image(path)
		saved.text = "GESPEICHERT: " + ProjectSettings.globalize_path(path)
	, ScrapUI.CYAN, Vector2(600, 52))
	var btn_retry := button("NOCHMAL SPIELEN", start_game, ScrapUI.ORANGE, Vector2(600, 52))
	var btn_menu := button("HAUPTMENÜ", show_menu, ScrapUI.CYAN, Vector2(600, 52))
	box.add_child(btn_save)
	box.add_child(saved)
	box.add_child(btn_retry)
	box.add_child(btn_menu)
	wire_vertical_focus([btn_save, btn_retry, btn_menu])
	btn_save.grab_focus()


func run_edge_shot() -> void:
	start_game()
	player = Vector2(-750, -1000)
	world_3d.update_view()
	await get_tree().create_timer(2.0).timeout
	capture_demo("rand-spielkamera")
	await get_tree().create_timer(0.5).timeout
	for task in screenshot_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	get_tree().quit()


func run_arena_overview_shots() -> void:
	start_game()
	clear_ui()
	camera_shot_mode = "overview"
	world_3d.update_view()
	await get_tree().create_timer(0.6).timeout
	capture_demo("arena-uebersicht")
	await get_tree().create_timer(0.4).timeout
	camera_shot_mode = "boundary_north"
	world_3d.update_view()
	await get_tree().create_timer(0.4).timeout
	capture_demo("rand-nord")
	await get_tree().create_timer(0.4).timeout
	camera_shot_mode = "boundary_south"
	world_3d.update_view()
	await get_tree().create_timer(0.4).timeout
	capture_demo("rand-sued")
	await get_tree().create_timer(0.4).timeout
	for task in screenshot_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	get_tree().quit()


func run_menu_shots() -> void:
	var original_skin := selected_skin
	show_menu()
	await get_tree().create_timer(1.2).timeout
	capture_demo("menue")
	await get_tree().create_timer(0.4).timeout

	show_hangar()
	select_skin("red")
	show_hangar()
	await get_tree().create_timer(0.8).timeout
	capture_demo("hangar")
	await get_tree().create_timer(0.4).timeout
	select_skin(original_skin)

	show_settings()
	await get_tree().create_timer(0.6).timeout
	capture_demo("einstellungen")
	await get_tree().create_timer(0.4).timeout

	start_game()
	for id in ["minigun", "rocket", "turret", "shield", "saw", "thruster"]:
		for n in range(2):
			state.upgrade(id)
	level = 6
	xp = 18
	total_scrap = 42
	kills = 38
	elapsed = 74.0
	for i in range(28):
		var a := TAU * float(i) / 28.0
		enemies.append(make_enemy(i % 3, player + Vector2.from_angle(a) * (150.0 + (i % 4) * 45.0)))
	update_hud()
	world_3d.update_view()
	await get_tree().create_timer(0.6).timeout
	capture_demo("spiel-hud")
	await get_tree().create_timer(0.4).timeout

	choose_upgrade(true)
	await get_tree().create_timer(0.6).timeout
	capture_demo("level-up")
	await get_tree().create_timer(0.4).timeout

	show_pause()
	await get_tree().create_timer(0.6).timeout
	capture_demo("pause")
	await get_tree().create_timer(0.4).timeout

	show_end(true)
	await get_tree().create_timer(0.8).timeout
	capture_demo("ende")
	await get_tree().create_timer(0.6).timeout

	for task in screenshot_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	get_tree().quit()


func _draw() -> void:
	if hit_flash > 0 and mode == "playing":
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(1.0, 0.15, 0.2, hit_flash * 0.08))
