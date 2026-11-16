extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	# 1. All 8 evolution recipes exist, have valid definitions, and evolve cleanly.
	assert(UpgradeState.EVOLUTIONS.size() == 8)
	for evo_id: String in UpgradeState.EVOLUTIONS:
		var definition := load("res://data/" + evo_id + ".tres")
		assert(definition != null and definition.values.size() == 5)
		var recipe: Dictionary = UpgradeState.EVOLUTIONS[evo_id]
		var state := UpgradeState.new()
		for i in range(5):
			assert(state.upgrade(recipe["weapon"]))
			assert(state.upgrade(recipe["support"]))
		assert(evo_id in state.available_evolutions())
		assert(state.evolve_id(evo_id))
		assert(state.level(evo_id) == 1)
		assert(state.level(recipe["weapon"]) == 0)
		assert(not state.can_upgrade(recipe["weapon"]))
		assert(not state.can_evolve_id(evo_id))

	# 2. Evolved arm weapons occupy arm sockets and respect the 2-arm-weapon limit.
	var arm_state := UpgradeState.new()
	for i in range(5):
		assert(arm_state.upgrade("minigun"))
		assert(arm_state.upgrade("cooldown"))
	assert(arm_state.evolve_id("vulcan"))
	assert(arm_state.arm_socket("vulcan") == "right_arm")
	assert(arm_state.upgrade("laser"))
	assert(arm_state.arm_socket("laser") == "left_arm")
	assert(not arm_state.can_upgrade("plasma"))

	# 3. Elite enemy stats, crate drop on death, and crate pickup logic.
	var elite := RunSimulation.make_enemy(1, Vector2(100, 0), true)
	assert(elite["elite"] == true)
	assert(elite["max_hp"] == int(round(70 * 3.5)))
	assert(is_equal_approx(elite["speed"], 50.0 * 1.15))

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.start_game()
	scene.enemies.clear()
	scene.crates.clear()
	var dead_elite := RunSimulation.make_enemy(1, Vector2(50, 0), true)
	dead_elite["hp"] = 0
	scene.enemies.append(dead_elite)
	RunSimulation.process_deaths(scene)
	assert(scene.crates.size() == 1)

	# Picking up a crate without available evolution grants scrap + heal.
	scene.player = Vector2(50, 0)
	scene.hp = 60.0
	var scrap_before: int = scene.total_scrap
	WeaponLogic.update_pickups(scene, 0.016)
	assert(scene.crates.is_empty())
	assert(scene.total_scrap == scrap_before + 15)
	assert(is_equal_approx(scene.hp, 80.0))

	# Picking up a crate with an available evolution opens the crate evolution UI.
	for i in range(5):
		scene.state.upgrade("minigun")
		scene.state.upgrade("cooldown")
	scene.crates.append(Vector2(50, 0))
	WeaponLogic.update_pickups(scene, 0.016)
	assert(scene.mode == "upgrade")
	assert(scene.upgrade_cards.size() == 1)
	assert(scene.upgrade_cards[0].get_meta("upgrade_id") == "vulcan")
	scene.upgrade_cards[0].pressed.emit()
	assert(scene.state.level("vulcan") == 1)
	assert(scene.mode == "playing")

	print("Evolutions-, Elite- und Kisten-Tests bestanden")
	quit()
