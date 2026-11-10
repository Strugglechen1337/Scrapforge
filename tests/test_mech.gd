extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var state := UpgradeState.new()
    assert(state.upgrade("minigun"))
    assert(state.arm_socket("minigun") == "right_arm")
    assert(state.upgrade("laser"))
    assert(state.arm_socket("laser") == "left_arm")
    assert(not state.can_upgrade("plasma"))
    assert(not state.upgrade("flamethrower"))
    assert(state.upgrade("laser"))
    for id in ["laser", "flamethrower", "plasma", "turret", "sensor", "shield", "drone"]:
        var definition: UpgradeDefinition = load("res://data/" + id + ".tres")
        assert(definition and definition.values.size() == 5 and not definition.socket.is_empty())
        var counts := []
        for level in range(1, 6):
            var visual = definition.visual_script.new()
            visual.build(id, level, StandardMaterial3D.new(), StandardMaterial3D.new(), StandardMaterial3D.new())
            counts.append(visual.get_child_count())
            visual.free()
        for i in range(1, 5): assert(counts[i] > counts[i - 1])
    var robot := Robot3D.new()
    root.add_child(robot)
    for id in ["standard", "red", "green", "yellow", "blue"]:
        var skin: SkinDefinition = load("res://data/skins/" + id + ".tres")
        assert(skin)
        robot.set_skin(skin)
        assert(robot.metal.albedo_color == skin.armor_color * Color(0.55, 0.55, 0.55))
        assert(robot.metal.albedo_texture != null)
        assert(robot.metal.roughness >= 0.6 and robot.metal.metallic <= 0.15)
    robot.queue_free()
    print("Mech-Tests bestanden")
    quit()
