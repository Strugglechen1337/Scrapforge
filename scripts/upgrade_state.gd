extends RefCounted
class_name UpgradeState

var levels: Dictionary = {}

func level(id: String) -> int:
	return int(levels.get(id, 0))

const ARM_WEAPONS = ["minigun", "laser", "flamethrower", "plasma"]
const EVOLVED_ARM_WEAPONS = {
	"vulcan": "minigun",
	"prism_laser": "laser",
	"inferno": "flamethrower",
	"singularity": "plasma",
}
const EVOLUTIONS = {
	"swarm": {"weapon": "rocket", "support": "radar"},
	"vulcan": {"weapon": "minigun", "support": "cooldown"},
	"prism_laser": {"weapon": "laser", "support": "sensor"},
	"inferno": {"weapon": "flamethrower", "support": "thruster"},
	"singularity": {"weapon": "plasma", "support": "magnet"},
	"bastion": {"weapon": "turret", "support": "shield"},
	"hive_drone": {"weapon": "drone", "support": "cooldown"},
	"shredder": {"weapon": "saw", "support": "armor"},
}

func arm_socket(id: String) -> String:
	var is_arm := id in ARM_WEAPONS or id in EVOLVED_ARM_WEAPONS
	if not is_arm or level(id) == 0:
		return ""
	var arms: Array = []
	for weapon in levels:
		if (weapon in ARM_WEAPONS or weapon in EVOLVED_ARM_WEAPONS) and level(weapon) > 0:
			arms.append(weapon)
	var index := arms.find(id)
	return "right_arm" if index == 0 else "left_arm"

func can_upgrade(id: String) -> bool:
	for evo_id in EVOLUTIONS:
		if EVOLUTIONS[evo_id]["weapon"] == id and level(evo_id) > 0:
			return false
	if level(id) >= 5:
		return false
	if id in ARM_WEAPONS and level(id) == 0:
		var count := 0
		for weapon in ARM_WEAPONS:
			if level(weapon) > 0:
				count += 1
		for evo_id in EVOLVED_ARM_WEAPONS:
			if level(evo_id) > 0:
				count += 1
		return count < 2
	return true

func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	levels[id] = level(id) + 1
	return true

func can_evolve_id(evo_id: String) -> bool:
	if not EVOLUTIONS.has(evo_id) or level(evo_id) > 0:
		return false
	var recipe: Dictionary = EVOLUTIONS[evo_id]
	return level(recipe["weapon"]) == 5 and level(recipe["support"]) == 5

func available_evolutions() -> Array[String]:
	var result: Array[String] = []
	for evo_id: String in EVOLUTIONS:
		if can_evolve_id(evo_id):
			result.append(evo_id)
	return result

func can_evolve() -> bool:
	return not available_evolutions().is_empty()

func evolve_id(evo_id: String) -> bool:
	if not can_evolve_id(evo_id):
		return false
	var recipe: Dictionary = EVOLUTIONS[evo_id]
	levels[recipe["weapon"]] = 0
	if evo_id == "swarm":
		levels[recipe["support"]] = 0
	levels[evo_id] = 1
	return true

func evolve() -> bool:
	var avail := available_evolutions()
	if avail.is_empty():
		return false
	return evolve_id(avail[0])
