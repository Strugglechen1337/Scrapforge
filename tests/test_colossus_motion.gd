extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var robot := Robot3D.new()
    root.add_child(robot)
    robot.set_process(false)
    robot.state = UpgradeState.new()
    robot.clock = 0.0
    robot.position.x = 1.0
    robot._process(0.12)
    var left: Node3D = robot.chassis["thigh_l"]
    var right: Node3D = robot.chassis["thigh_r"]
    assert(absf(left.rotation.x) > 0.01)
    assert(is_equal_approx(left.rotation.x, -right.rotation.x))
    var arm: Node3D = robot.chassis["forearm_l"]
    var socket: Marker3D = robot.sockets["left_arm"]
    var before := socket.global_position
    arm.rotation.x += 0.4
    assert(not socket.global_position.is_equal_approx(before))
    robot.free()
    print("Colossus motion and socket following passed")
    quit()
