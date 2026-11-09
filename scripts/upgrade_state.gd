extends RefCounted
class_name UpgradeState

var levels: Dictionary = {}

func level(id: String) -> int:
    return int(levels.get(id, 0))

const ARM_WEAPONS = ["minigun", "laser", "flamethrower", "plasma", "saw"]

func arm_socket(id: String) -> String:
    if id not in ARM_WEAPONS or level(id) == 0: return ""
    var arms: Array = []
    for weapon in levels:
        if weapon in ARM_WEAPONS and level(weapon) > 0: arms.append(weapon)
    var index := arms.find(id)
    return "right_arm" if index == 0 else "left_arm"

func can_upgrade(id: String) -> bool:
    if level(id) >= 5: return false
    if id in ARM_WEAPONS and level(id) == 0:
        var count := 0
        for weapon in ARM_WEAPONS:
            if level(weapon) > 0: count += 1
        return count < 2
    return true

func upgrade(id: String) -> bool:
    if not can_upgrade(id):
        return false
    levels[id] = level(id) + 1
    return true

func can_evolve() -> bool:
    return level("rocket") == 5 and level("radar") == 5 and level("swarm") == 0

func evolve() -> bool:
    if not can_evolve():
        return false
    levels["rocket"] = 0
    levels["radar"] = 0
    levels["swarm"] = 1
    return true
