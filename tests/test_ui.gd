extends SceneTree

var focus_events := 0
var confirm_events := 0

func send_joy_button(button_index: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button_index
	press.pressed = true
	root.push_input(press)
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = button_index
	release.pressed = false
	root.push_input(release)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var theme_res := load("res://ui/theme.tres") as Theme
	assert(theme_res != null)

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.ui_focus_changed.connect(func(_c): focus_events += 1)
	game.ui_confirmed.connect(func(_c): confirm_events += 1)
	await process_frame

	# 1. Main menu initial focus & gamepad D-Pad navigation
	assert(game.mode == "menu")
	assert(game.panel.theme == theme_res)
	assert(game.menu_buttons.size() == 5)
	for b in game.menu_buttons:
		assert(b.custom_minimum_size.y >= 48)
	assert(root.gui_get_focus_owner() == game.menu_buttons[0])

	send_joy_button(JOY_BUTTON_DPAD_DOWN)
	await process_frame
	assert(root.gui_get_focus_owner() == game.menu_buttons[1])
	assert(focus_events > 0)

	send_joy_button(JOY_BUTTON_DPAD_DOWN)
	await process_frame
	assert(root.gui_get_focus_owner() == game.menu_buttons[2])

	send_joy_button(JOY_BUTTON_DPAD_UP)
	await process_frame
	assert(root.gui_get_focus_owner() == game.menu_buttons[1])

	# 2. Hangar & saving/loading skin in user://settings.cfg
	var test_cfg := "user://test_ui_settings.cfg"
	game.select_skin("blue", test_cfg)
	assert(game.selected_skin == "blue")
	assert(FileAccess.file_exists(test_cfg))
	assert(game.world_3d.robot.skin == game.skins["blue"])

	game.selected_skin = "standard"
	game.load_settings(test_cfg)
	assert(game.selected_skin == "blue")
	game.fullscreen_enabled = true
	game.save_settings(test_cfg)
	game.fullscreen_enabled = false
	game.load_settings(test_cfg)
	assert(game.fullscreen_enabled)
	game.fullscreen_enabled = false

	# Restore default skin in settings
	game.select_skin("standard", test_cfg)
	assert(game.selected_skin == "standard")

	# 3. Upgrade selection (Aufstiegs-Auswahl) gamepad focus navigation & confirmation
	game.start_game()
	game.choose_upgrade(true)
	await process_frame
	assert(game.mode == "upgrade")
	assert(game.upgrade_cards.size() == 3)
	for card in game.upgrade_cards:
		assert(card.custom_minimum_size.y >= 48 and card.custom_minimum_size.x >= 48)
	assert(root.gui_get_focus_owner() == game.upgrade_cards[0])

	send_joy_button(JOY_BUTTON_DPAD_RIGHT)
	await process_frame
	assert(root.gui_get_focus_owner() == game.upgrade_cards[1])

	send_joy_button(JOY_BUTTON_DPAD_RIGHT)
	await process_frame
	assert(root.gui_get_focus_owner() == game.upgrade_cards[2])

	send_joy_button(JOY_BUTTON_DPAD_LEFT)
	await process_frame
	assert(root.gui_get_focus_owner() == game.upgrade_cards[1])

	var chosen_id: String = game.upgrade_cards[1].get_meta("upgrade_id")
	var prev_lv: int = game.state.level(chosen_id)
	send_joy_button(JOY_BUTTON_A)
	await process_frame
	assert(game.mode == "playing")
	assert(game.state.level(chosen_id) == prev_lv + 1)
	assert(confirm_events > 0)

	game.queue_free()
	print("UI-, Controller-Fokus- und Skin-Tests bestanden")
	quit()
