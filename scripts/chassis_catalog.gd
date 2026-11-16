extends RefCounted
class_name ChassisCatalog

const CHASSIS_IDS := ["colossus", "vanguard", "bastion_mech"]
const CHASSIS := {
	"colossus": {
		"title": "COLOSSUS MK-II",
		"role": "ALLROUNDER",
		"desc": "Ausgewogener Standard-Kampfmech mit Minigun.",
		"start_weapon": "minigun",
		"base_hp": 100.0,
		"base_speed": 190.0,
		"armor_bonus": 0.0,
		"scale": Vector3(1.0, 1.0, 1.0),
		"has_model": true,
	},
	"vanguard": {
		"title": "VANGUARD MK-I",
		"role": "STURM-MECH",
		"desc": "Leicht und schnell. Startet mit dem Laser.",
		"start_weapon": "laser",
		"base_hp": 85.0,
		"base_speed": 225.0,
		"armor_bonus": 0.0,
		"scale": Vector3(0.86, 0.92, 0.86),
		"has_model": false,
	},
	"bastion_mech": {
		"title": "BASTION MK-IV",
		"role": "BELAGERUNGS-MECH",
		"desc": "Schwere Panzerung (+12 % Schutz). Startet mit Flammenwerfer.",
		"start_weapon": "flamethrower",
		"base_hp": 135.0,
		"base_speed": 165.0,
		"armor_bonus": 0.12,
		"scale": Vector3(1.18, 1.06, 1.18),
		"has_model": false,
	},
}


static func get_def(id: String) -> Dictionary:
	return CHASSIS.get(id, CHASSIS["colossus"])


static func start_weapon(id: String) -> String:
	return str(get_def(id)["start_weapon"])


static func base_hp(id: String) -> float:
	return float(get_def(id)["base_hp"])


static func base_speed(id: String) -> float:
	return float(get_def(id)["base_speed"])


static func armor_bonus(id: String) -> float:
	return float(get_def(id)["armor_bonus"])


static func model_scale(id: String) -> Vector3:
	return get_def(id)["scale"]


static func has_unique_model(id: String) -> bool:
	return bool(get_def(id).get("has_model", false))
