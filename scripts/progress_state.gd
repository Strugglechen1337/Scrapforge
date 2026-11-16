extends RefCounted
class_name ProgressState

const PROGRESS_PATH := "user://progress.cfg"
const UPGRADE_IDS := ["hull", "damage", "speed", "scrap", "magnet"]
const UPGRADES := {
	"hull": {
		"title": "HÜLLEN-PANZERUNG",
		"desc": "+15 Max-Hülle pro Stufe",
		"max_level": 5,
		"base_cost": 20,
		"step_cost": 15,
	},
	"damage": {
		"title": "WAFFEN-KALIBRIERUNG",
		"desc": "+8 % Schaden pro Stufe",
		"max_level": 5,
		"base_cost": 25,
		"step_cost": 20,
	},
	"speed": {
		"title": "SERVOMOTOREN",
		"desc": "+6 % Tempo pro Stufe",
		"max_level": 5,
		"base_cost": 20,
		"step_cost": 15,
	},
	"scrap": {
		"title": "SCHROTT-RECYCLER",
		"desc": "+20 % Schrott-Ausbeute pro Stufe",
		"max_level": 5,
		"base_cost": 25,
		"step_cost": 20,
	},
	"magnet": {
		"title": "MAGNETFELD-KERN",
		"desc": "+15 Sammelradius pro Stufe",
		"max_level": 5,
		"base_cost": 15,
		"step_cost": 15,
	},
}

var scrap: int = 0
var levels: Dictionary = {}
var selected_chassis: String = "colossus"
var selected_arena: String = "foundry"
var stats: Dictionary = {
	"total_kills": 0,
	"runs_completed": 0,
	"bosses_defeated": 0,
	"evolutions_unlocked": 0,
}
var unlocked_goals: Array[String] = []


func is_chassis_unlocked(id: String) -> bool:
	match id:
		"vanguard":
			return "chassis_vanguard" in unlocked_goals
		"bastion_mech":
			return "chassis_bastion" in unlocked_goals
		_:
			return true


func is_arena_unlocked(id: String) -> bool:
	if id == "rainyard":
		return "arena_rainyard" in unlocked_goals
	return true


func record_run(run_kills: int, won: bool, evo_count: int) -> Array[String]:
	stats["total_kills"] = int(stats.get("total_kills", 0)) + maxi(0, run_kills)
	stats["runs_completed"] = int(stats.get("runs_completed", 0)) + 1
	if won:
		stats["bosses_defeated"] = int(stats.get("bosses_defeated", 0)) + 1
	stats["evolutions_unlocked"] = int(stats.get("evolutions_unlocked", 0)) + maxi(0, evo_count)
	var newly := UnlockCatalog.evaluate(stats, unlocked_goals)
	if "evo_master" in newly:
		scrap += 25
	if "boss_slayer" in newly:
		scrap += 50
	return newly


func level(id: String) -> int:
	return int(levels.get(id, 0))


func cost(id: String) -> int:
	var cfg: Dictionary = UPGRADES.get(id, {})
	if cfg.is_empty():
		return 0
	return int(cfg["base_cost"]) + level(id) * int(cfg["step_cost"])


func can_buy(id: String) -> bool:
	var cfg: Dictionary = UPGRADES.get(id, {})
	if cfg.is_empty():
		return false
	if level(id) >= int(cfg["max_level"]):
		return false
	return scrap >= cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	scrap -= cost(id)
	levels[id] = level(id) + 1
	return true


func reset_upgrades() -> int:
	var refunded := 0
	for id: String in UPGRADE_IDS:
		var cfg: Dictionary = UPGRADES[id]
		var lv := level(id)
		for i in range(lv):
			refunded += int(cfg["base_cost"]) + i * int(cfg["step_cost"])
		levels[id] = 0
	scrap += refunded
	return refunded


func add_run_scrap(base_scrap: int) -> int:
	var gained := int(round(float(maxi(0, base_scrap)) * scrap_multiplier()))
	scrap += gained
	return gained


func max_hp_bonus() -> float:
	return float(level("hull")) * 15.0


func damage_multiplier() -> float:
	return 1.0 + float(level("damage")) * 0.08


func speed_multiplier() -> float:
	return 1.0 + float(level("speed")) * 0.06


func scrap_multiplier() -> float:
	return 1.0 + float(level("scrap")) * 0.20


func magnet_bonus() -> float:
	return float(level("magnet")) * 15.0


func save(path: String = PROGRESS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "scrap", scrap)
	cfg.set_value("progress", "chassis", selected_chassis)
	cfg.set_value("progress", "arena", selected_arena)
	cfg.set_value("progress", "unlocked", unlocked_goals)
	for k: String in stats:
		cfg.set_value("stats", k, int(stats[k]))
	for id: String in UPGRADE_IDS:
		cfg.set_value("upgrades", id, level(id))
	cfg.save(path)


func load_from(path: String = PROGRESS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	scrap = maxi(0, int(cfg.get_value("progress", "scrap", 0)))
	var loaded_chassis := str(cfg.get_value("progress", "chassis", "colossus"))
	selected_chassis = loaded_chassis if (loaded_chassis in ChassisCatalog.CHASSIS_IDS and ChassisCatalog.has_unique_model(loaded_chassis)) else "colossus"
	var loaded_arena := str(cfg.get_value("progress", "arena", "foundry"))
	selected_arena = loaded_arena if (loaded_arena in ArenaCatalog.ARENA_IDS and ArenaCatalog.has_unique_scene(loaded_arena)) else "foundry"
	var loaded_unlocks = cfg.get_value("progress", "unlocked", [])
	unlocked_goals.clear()
	if loaded_unlocks is Array:
		for g in loaded_unlocks:
			unlocked_goals.append(str(g))
	for k: String in stats.keys():
		stats[k] = maxi(0, int(cfg.get_value("stats", k, 0)))
	for id: String in UPGRADE_IDS:
		var max_lv := int(UPGRADES[id]["max_level"])
		levels[id] = clampi(int(cfg.get_value("upgrades", id, 0)), 0, max_lv)
