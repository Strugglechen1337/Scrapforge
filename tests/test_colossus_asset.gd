extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var robot := Robot3D.new()
    root.add_child(robot)
    for part in ["torso", "head", "shoulder_l", "shoulder_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
        assert(robot.chassis.get(part) is MeshInstance3D, "Missing part: " + part)
    for socket in ["left_arm", "right_arm", "left_shoulder", "right_shoulder", "head", "back", "legs", "core"]:
        assert(robot.sockets.get(socket) is Marker3D, "Missing socket: " + socket)
    var before: Color = robot.body_material.get_shader_parameter("paint_color")
    robot.set_skin(load("res://data/skins/red.tres"))
    assert(robot.body_material.get_shader_parameter("paint_color") != before)
    assert(robot.body_material.get_shader_parameter("paint_color") == robot.skin.armor_color)
    robot.free()
    print("Colossus parts, sockets and paint passed")
    quit()
