extends SceneTree

func _initialize() -> void:
	var state = UpgradeState.new()
	assert(state.level("rocket") == 0)
	for i in range(5): assert(state.upgrade("rocket"))
	assert(not state.upgrade("rocket"))
	assert(not state.can_evolve())
	for i in range(5): assert(state.upgrade("radar"))
	assert(state.evolve())
	assert(not state.evolve())
	assert(state.level("rocket") == 0 and state.level("radar") == 0 and state.level("swarm") == 1)
	for id in ["laser", "rocket", "shield", "saw", "thruster", "armor", "magnet", "cooldown", "radar"]:
		var definition = load("res://data/" + id + ".tres")
		assert(definition != null and definition.values.size() == 5)
	# Saw does not occupy an arm socket and can be equipped alongside two arm weapons.
	var arm_test = UpgradeState.new()
	assert("saw" not in UpgradeState.ARM_WEAPONS)
	assert(arm_test.upgrade("minigun"))
	assert(arm_test.upgrade("laser"))
	assert(not arm_test.can_upgrade("flamethrower"))
	assert(arm_test.can_upgrade("saw"))
	assert(arm_test.upgrade("saw"))
	assert(load("res://data/saw.tres").socket != "right_arm")
	print("Upgrade-Tests bestanden")
	quit()
