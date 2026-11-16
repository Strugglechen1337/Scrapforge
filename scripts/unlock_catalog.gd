extends RefCounted
class_name UnlockCatalog

const GOAL_IDS := [
	"chassis_vanguard",
	"arena_rainyard",
	"chassis_bastion",
	"evo_master",
	"boss_slayer",
]

const GOALS := {
	"chassis_vanguard": {
		"title": "STURM-FREIGABE",
		"desc": "Erreiche insgesamt 50 Abschüsse.",
		"reward": "Schaltet Chassis VANGUARD MK-I frei",
		"stat": "total_kills",
		"target": 50,
	},
	"arena_rainyard": {
		"title": "AUSSENEINSATZ",
		"desc": "Schließe 1 Einsatz ab (Sieg oder Niederlage).",
		"reward": "Schaltet Arena VERLADEHOF (Regen) frei",
		"stat": "runs_completed",
		"target": 1,
	},
	"chassis_bastion": {
		"title": "BELAGERUNGS-KERN",
		"desc": "Schalte mindestens 1 Waffen-Evolution frei.",
		"reward": "Schaltet Chassis BASTION MK-IV frei",
		"stat": "evolutions_unlocked",
		"target": 1,
	},
	"evo_master": {
		"title": "WAFFENSCHMIED",
		"desc": "Erreiche 3 Waffen-Evolutionen insgesamt.",
		"reward": "+25 Bonus-Schrott",
		"stat": "evolutions_unlocked",
		"target": 3,
	},
	"boss_slayer": {
		"title": "KOLOSS-BEZWINGER",
		"desc": "Besiege 1 Boss-Gegner.",
		"reward": "+50 Bonus-Schrott",
		"stat": "bosses_defeated",
		"target": 1,
	},
}


static func is_goal_met(goal_id: String, stats: Dictionary) -> bool:
	var cfg: Dictionary = GOALS.get(goal_id, {})
	if cfg.is_empty():
		return false
	return int(stats.get(cfg["stat"], 0)) >= int(cfg["target"])


static func evaluate(stats: Dictionary, unlocked: Array[String]) -> Array[String]:
	var newly_unlocked: Array[String] = []
	for gid: String in GOAL_IDS:
		if gid not in unlocked and is_goal_met(gid, stats):
			unlocked.append(gid)
			newly_unlocked.append(gid)
	return newly_unlocked
