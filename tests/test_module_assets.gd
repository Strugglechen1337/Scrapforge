extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    for id in ["minigun", "laser", "turret", "rocket", "drone", "shield"]:
        var scene := load("res://assets/third_party/sketchfab/modules/" + id + ".glb") as PackedScene
        assert(scene != null, "Missing module " + id)
        var instance := scene.instantiate()
        assert(instance != null)
        instance.free()
    var robot := Robot3D.new()
    root.add_child(robot)
    robot.state = UpgradeState.new()
    for id in ["minigun", "laser", "turret", "rocket", "drone", "shield"]:
        robot.definitions[id] = load("res://data/" + id + ".tres")
        robot.state.upgrade(id)
    robot.refresh()
    var expected := {"minigun": "right_arm", "laser": "left_arm", "turret": "left_shoulder", "rocket": "right_shoulder", "drone": "back", "shield": "back"}
    for module in robot.parts.get_children():
        var id: String = module.get_meta("module_id")
        assert(module.get_node_or_null("asset_" + id) != null)
        assert(module.get_meta("socket") == expected[id])
        var socket: Marker3D = robot.sockets[module.get_meta("socket")]
        assert(module.position.distance_to(robot.to_local(socket.global_position)) < 0.4)
    assert(robot.sockets["right_arm"].get_parent() == robot.chassis["forearm_r"])
    assert(robot.sockets["left_arm"].get_parent() == robot.chassis["forearm_l"])
    assert(robot.sockets["back"].get_parent() == robot.chassis["torso"])
    robot.state = UpgradeState.new()
    robot.definitions = {"swarm": load("res://data/swarm.tres")}
    robot.state.upgrade("swarm")
    robot.refresh()
    assert(robot.parts.get_child_count() == 2)
    var swarm_sockets := []
    for module in robot.parts.get_children(): swarm_sockets.append(module.get_meta("socket"))
    assert("left_shoulder" in swarm_sockets and "right_shoulder" in swarm_sockets)
    robot.free()
    print("Module assets and sockets passed")
    quit()
