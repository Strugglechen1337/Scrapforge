extends RefCounted
class_name ArenaCatalog

const ARENA_IDS := ["foundry", "rainyard"]
const ARENAS := {
	"foundry": {
		"title": "SCHROTT-HALLE",
		"subtitle": "INDUSTRIEHALLE · NACHT",
		"desc": "Verlassene Werkhalle mit warmen Feuern und Hallenstrahlern.",
		"rain": false,
		"fog_color": Color("0e1726"),
		"ambient_tint": Color("1a2638"),
		"sun_color": Color("9ec5ff"),
		"floor_tint": Color(1.0, 1.0, 1.0),
		"floor_roughness": 0.72,
		"boss_kind": 3,
		"boss_title": "WARNUNG // BOSS: SPINNEN-MECH",
		"has_unique_scene": true,
	},
	"rainyard": {
		"title": "VERLADEHOF",
		"subtitle": "AUSSENGELÄNDE · REGEN",
		"desc": "Nasser Schrottplatz bei Nachtregen mit Sturm-Drohnen und Belagerungs-Koloss.",
		"rain": true,
		"fog_color": Color("08131e"),
		"ambient_tint": Color("102235"),
		"sun_color": Color("7bb8ff"),
		"floor_tint": Color(0.68, 0.78, 0.88),
		"floor_roughness": 0.28,
		"boss_kind": 5,
		"boss_title": "WARNUNG // BOSS: BELAGERUNGS-KOLOSS",
		"has_unique_scene": false,
	},
}


static func get_def(id: String) -> Dictionary:
	return ARENAS.get(id, ARENAS["foundry"])


static func has_rain(id: String) -> bool:
	return bool(get_def(id)["rain"])


static func boss_kind(id: String) -> int:
	return int(get_def(id)["boss_kind"])


static func has_unique_scene(id: String) -> bool:
	return bool(get_def(id).get("has_unique_scene", false))
