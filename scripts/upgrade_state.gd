extends RefCounted
class_name UpgradeState

var levels: Dictionary = {}

func level(id: String) -> int:
    return int(levels.get(id, 0))

func upgrade(id: String) -> bool:
    if level(id) >= 5:
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
