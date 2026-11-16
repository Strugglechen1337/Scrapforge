extends Node2D

signal ui_focus_changed(control: Control)
signal ui_confirmed(control: Control)

const IDS = ["minigun", "laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "flamethrower", "plasma", "turret", "sensor", "drone"]
const EVO_IDS = ["swarm", "vulcan", "prism_laser", "inferno", "singularity", "bastion", "hive_drone", "shredder"]
const SKIN_IDS = ["standard", "red", "green", "yellow", "blue"]
const SETTINGS_PATH = "user://settings.cfg"
const BG = Color("080f1c")
const CYAN = Color("33f5ff")
const ORANGE = Color("ff7a1a")
const PINK = Color("ff568d")

var weapons = preload("res://scripts/weapons_3d.gd").new()
var state = UpgradeState.new()
var progress := ProgressState.new()
var run_scrap_banked := false
var last_banked_scrap := 0
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
var crates: Array[Vector2] = []
var next_elite_at := 28.0
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
	for evo_id in EVO_IDS:
		definitions[evo_id] = load("res://data/" + evo_id + ".tres")
	for skin_id in SKIN_IDS:
		skins[skin_id] = load("res://data/skins/" + skin_id + ".tres")
	load_settings()
	if DisplayServer.get_name() != "headless":
		progress.load_from()
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
	elif "--vfx-demo" in OS.get_cmdline_user_args():
		start_game()
		var demo = preload("res://scripts/vfx_demo.gd").new()
		demo.game = self
		add_child(demo)
		set_process(false)
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
	return GameMenus.button(self, text, action, accent, min_size)


func heading(text: String, size := 36, color: Color = ScrapUI.ORANGE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return GameMenus.heading(text, size, color, align)


func wire_vertical_focus(buttons: Array[Control]) -> void:
	GameMenus.wire_vertical_focus(buttons)


func wire_horizontal_focus(buttons: Array[Button]) -> void:
	GameMenus.wire_horizontal_focus(buttons)


func show_menu() -> void:
	GameMenus.show_menu(self)


func show_credits() -> void:
	GameMenus.show_credits(self)


func show_hangar() -> void:
	GameMenus.show_hangar(self)


func show_settings() -> void:
	GameMenus.show_settings(self)


func show_pause() -> void:
	GameMenus.show_pause(self)


func max_hp() -> float:
	return ChassisCatalog.base_hp(progress.selected_chassis) + progress.max_hp_bonus()


func has_any_evolution() -> bool:
	for evo_id: String in EVO_IDS:
		if state.level(evo_id) > 0:
			return true
	return false


func show_unlocks() -> void:
	GameMenus.show_unlocks(self)


func show_end(victory: bool) -> void:
	if not run_scrap_banked and not autoplay:
		run_scrap_banked = true
		var evo_count := 0
		for evo_id: String in EVO_IDS:
			if state.level(evo_id) > 0:
				evo_count += 1
		last_banked_scrap = progress.add_run_scrap(total_scrap)
		progress.record_run(kills, victory, evo_count)
		progress.save()
	GameMenus.show_end(self, victory)


func build_hud() -> void:
	GameHUD.build(self)


func make_boss_bar() -> void:
	GameHUD.make_boss_bar(self)


func update_hud() -> void:
	GameHUD.update(self)


func choose_upgrade(force_show := false) -> void:
	UpgradeScreen.choose(self, force_show)


func open_crate() -> void:
	UpgradeScreen.open_crate(self)


func make_enemy(kind: int, position: Vector2, elite := false) -> Dictionary:
	return RunSimulation.make_enemy(kind, position, elite)


func spawn_boss() -> void:
	RunSimulation.spawn_boss(self)


func shoot_enemy(origin: Vector2, direction: Vector2, speed := 240.0) -> void:
	RunSimulation.shoot_enemy(self, origin, direction, speed)


func play_sfx(id: StringName, pos := Vector2.INF) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play(id, pos)


func play_music(which: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_music(which)


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
	state.upgrade(ChassisCatalog.start_weapon(progress.selected_chassis))
	player = Vector2.ZERO
	enemies.clear()
	bullets.clear()
	enemy_shots.clear()
	crystals.clear()
	crates.clear()
	next_elite_at = 28.0
	elapsed = 0.0
	spawn_clock = 0.85
	fire_clock = 0.0
	shot_index = 0
	hp = max_hp()
	run_scrap_banked = false
	last_banked_scrap = 0
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


func _step_autoplay(delta: float) -> bool:
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
		var has_explosion := world_3d.effects_3d.effects.any(func(e): return e.get("kind", "") == "explosion") or world_3d.effects_3d.active_blasts() > 0
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
		return true
	return false


func _process(delta: float) -> void:
	release_hitstop()
	if autoplay and _step_autoplay(delta):
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
	var base_spd: float = ChassisCatalog.base_speed(progress.selected_chassis)
	player += direction.limit_length(1.0) * (base_spd + state.level("thruster") * 12.0) * progress.speed_multiplier() * delta
	player = player.clamp(Vector2(-1800, -1200), Vector2(1800, 1200))
	RunSimulation.spawn_waves(self, delta)
	AudioManager.set_listener(player)
	WeaponLogic.update_player_fire(self, delta)
	RunSimulation.update_enemies(self, delta)
	WeaponLogic.update_bullets(self, delta)
	WeaponLogic.update_enemy_shots(self, delta)
	RunSimulation.process_deaths(self)
	WeaponLogic.update_pickups(self, delta)
	if autoplay:
		hp = max_hp()
	run_scrap_banked = false
	last_banked_scrap = 0
	update_hud()
	RunSimulation.update_boss_bar_and_end(self)
	queue_redraw()


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
	var saved_levels := world_3d.menu_state.levels.duplicate()
	for id in ["minigun", "laser", "rocket", "turret", "drone", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar", "sensor"]:
		world_3d.menu_state.levels[id] = 5
	world_3d.hangar_robot.refresh()
	await get_tree().create_timer(0.8).timeout
	capture_demo("hangar-max")
	await get_tree().create_timer(0.4).timeout
	world_3d.menu_state.levels = saved_levels
	world_3d.hangar_robot.refresh()
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
