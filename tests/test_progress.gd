extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var p := ProgressState.new()
	assert(p.scrap == 0)
	assert(is_equal_approx(p.max_hp_bonus(), 0.0))
	assert(is_equal_approx(p.damage_multiplier(), 1.0))
	assert(is_equal_approx(p.speed_multiplier(), 1.0))
	assert(is_equal_approx(p.scrap_multiplier(), 1.0))
	assert(is_equal_approx(p.magnet_bonus(), 0.0))

	# Buying, max level, and 100% refund reset
	p.add_run_scrap(200)
	assert(p.scrap == 200)
	assert(p.can_buy("hull"))
	assert(p.buy("hull"))
	assert(p.level("hull") == 1 and p.scrap == 180)
	assert(is_equal_approx(p.max_hp_bonus(), 15.0))
	assert(p.buy("damage"))
	assert(p.level("damage") == 1 and p.scrap == 155)
	assert(is_equal_approx(p.damage_multiplier(), 1.08))
	var refunded := p.reset_upgrades()
	assert(refunded == 45 and p.scrap == 200)
	assert(p.level("hull") == 0 and p.level("damage") == 0)

	# Persistence save/load
	var test_path := "user://test_progress_phase9b.cfg"
	p.buy("scrap")
	p.save(test_path)
	var loaded := ProgressState.new()
	loaded.load_from(test_path)
	assert(loaded.scrap == p.scrap and loaded.level("scrap") == 1)
	assert(is_equal_approx(loaded.scrap_multiplier(), 1.20))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

	# Integration with main scene: scrap banking on run end, max_hp on start, hangar UI
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.progress = ProgressState.new()
	scene.progress.scrap = 100
	scene.progress.buy("hull")
	scene.start_game()
	assert(is_equal_approx(scene.hp, 115.0))
	assert(is_equal_approx(scene.max_hp(), 115.0))
	scene.total_scrap = 30
	var before_scrap: int = scene.progress.scrap
	# Prevent test from overwriting user://progress.cfg by checking banked amount and restoring
	var orig_path := ProjectSettings.globalize_path(ProgressState.PROGRESS_PATH)
	var had_orig := FileAccess.file_exists(ProgressState.PROGRESS_PATH)
	var orig_bytes := FileAccess.get_file_as_bytes(ProgressState.PROGRESS_PATH) if had_orig else PackedByteArray()
	scene.show_end(false)
	assert(scene.progress.scrap == before_scrap + 30)
	scene.show_hangar()
	var buy_btns: Array = scene.panel.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("progress_buy_id"))
	assert(buy_btns.size() == ProgressState.UPGRADE_IDS.size())
	var reset_btns: Array = scene.panel.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("progress_reset"))
	assert(reset_btns.size() == 1 and not reset_btns[0].disabled)
	if had_orig:
		var f := FileAccess.open(ProgressState.PROGRESS_PATH, FileAccess.WRITE)
		f.store_buffer(orig_bytes)
	else:
		DirAccess.remove_absolute(orig_path)

	# Hidden chassis/arena saved in config must fall back to visible default
	var fb_path := "user://test_progress_fallback.cfg"
	var fb := ProgressState.new()
	fb.selected_chassis = "unknown_chassis"
	fb.selected_arena = "rainyard"
	fb.save(fb_path)
	var fb_loaded := ProgressState.new()
	fb_loaded.load_from(fb_path)
	assert(fb_loaded.selected_chassis == "colossus")
	assert(fb_loaded.selected_arena == "rainyard")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fb_path))

	print("Fortschritts- und Hangar-Upgrade-Tests bestanden")
	quit()
