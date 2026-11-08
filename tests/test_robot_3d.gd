extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var robot := Robot3D.new()
    root.add_child(robot)
    robot.state = UpgradeState.new()
    robot.definitions["minigun"] = load("res://data/minigun.tres")
    robot.state.upgrade("minigun")
    robot.refresh()
    assert(robot.parts.get_child_count() == 1)
    var first := robot.parts.get_child(0).get_child_count()
    robot.state.upgrade("minigun")
    robot.refresh()
    assert(robot.parts.get_child(0).get_child_count() > first)
    assert(robot.sockets.size() == 8)
    robot.queue_free()
    print("3D-Bauteiltests bestanden")
    quit()
