extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	# 9c: Chassis definitions, start weapons, and Robot3D silhouette
	assert(ChassisCatalog.CHASSIS_IDS.size() == 3)
	assert(ChassisCatalog.start_weapon("colossus") == "minigun")
	assert(ChassisCatalog.start_weapon("vanguard") == "laser")
	assert(ChassisCatalog.start_weapon("bastion_mech") == "flamethrower")
	assert(is_equal_approx(ChassisCatalog.base_hp("bastion_mech"), 135.0))
	assert(is_equal_approx(ChassisCatalog.base_speed("vanguard"), 225.0))

	# 9d: Arena catalog and new enemy kind 4
	assert(ArenaCatalog.ARENA_IDS.size() == 2)
	assert(not ArenaCatalog.has_rain("foundry"))
	assert(ArenaCatalog.has_rain("rainyard"))
	var drone := RunSimulation.make_enemy(4, Vector2(100, 0))
	assert(drone["max_hp"] == 52 and is_equal_approx(drone["speed"], 155.0))

	# 9e: Unlock goals evaluation and bonus scrap
	var p := ProgressState.new()
	assert(p.is_chassis_unlocked("colossus"))
	assert(not p.is_chassis_unlocked("vanguard"))
	assert(not p.is_arena_unlocked("rainyard"))
	var newly := p.record_run(55, true, 3)
	assert("chassis_vanguard" in newly)
	assert("arena_rainyard" in newly)
	assert("chassis_bastion" in newly)
	assert("evo_master" in newly)
	assert("boss_slayer" in newly)
	assert(p.scrap == 75)
	assert(p.is_chassis_unlocked("vanguard"))
	assert(p.is_chassis_unlocked("bastion_mech"))
	assert(p.is_arena_unlocked("rainyard"))

	# Integration in main.tscn: chassis loadout, rainyard arena, conditional boss kind 5, hangar & unlocks UI
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.progress = p
	scene.progress.selected_chassis = "vanguard"
	scene.progress.selected_arena = "rainyard"
	scene.start_game()
	assert(scene.state.level("laser") == 1)
	assert(is_equal_approx(scene.hp, 85.0))
	assert(scene.world_3d.applied_arena_id == "rainyard")
	assert(scene.world_3d.robot.chassis_id == "vanguard")

	# Conditional boss kind 5 in rainyard (or with evolution)
	scene.enemies.clear()
	scene.boss_spawned = false
	RunSimulation.spawn_boss(scene)
	assert(scene.enemies.size() == 1 and scene.enemies[0]["kind"] == 5)
	assert(scene.enemies[0]["max_hp"] == 2600)

	# Hangar & Unlocks UI
	scene.show_hangar()
	var c_btns: Array = scene.panel.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("chassis_id"))
	var a_btns: Array = scene.panel.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("arena_id"))
	assert(c_btns.size() == 1 and c_btns[0].get_meta("chassis_id") == "colossus" and a_btns.size() == 2)
	scene.show_unlocks()
	var g_rows: Array = scene.panel.find_children("*", "PanelContainer", true, false).filter(func(n): return n.has_meta("unlock_goal_id"))
	assert(g_rows.size() == UnlockCatalog.GOAL_IDS.size())

	print("Phase 9c/9d/9e Chassis-, Arena-, Boss- und Freischalt-Tests bestanden")
	quit()
