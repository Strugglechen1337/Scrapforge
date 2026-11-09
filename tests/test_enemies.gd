extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var swarm := EnemySwarm3D.new()
    root.add_child(swarm)
    var spider_scene := load("res://assets/third_party/sketchfab/mech_spider/mech_spider.glb") as PackedScene
    assert(spider_scene != null)
    var spider_instance := spider_scene.instantiate()
    var imported_mesh := swarm.find_mesh(spider_instance)
    assert(imported_mesh != null)
    assert(swarm.spider.multimesh.mesh == imported_mesh)
    assert(imported_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2].size() > 0)
    spider_instance.free()
    assert(is_equal_approx(swarm.enemy_scale(0), 0.45))
    assert(is_equal_approx(swarm.enemy_scale(1), 0.80))
    assert(is_equal_approx(swarm.enemy_scale(2), 0.60))
    assert(is_equal_approx(swarm.enemy_scale(3), 2.50))

    var s0 := swarm.body_dimensions(0)
    var s1 := swarm.body_dimensions(1)
    var s2 := swarm.body_dimensions(2)
    assert(s0.x < s2.x and s2.x < s1.x)
    assert(s0.z < s2.z and s2.z < s1.z)

    assert(swarm.leg_count(0) == 8)
    assert(swarm.leg_count(1) == 6)
    assert(swarm.leg_count(2) == 8)
    assert(swarm.leg_count(3) == 8)

    assert(not swarm.has_turret(0))
    assert(not swarm.has_turret(1))
    assert(swarm.has_turret(2))
    assert(swarm.has_turret(3))

    var enemies := [
        {"pos": Vector2(100, 0), "kind": 0, "flash": 0.0},
        {"pos": Vector2(200, 0), "kind": 1, "flash": 0.0},
        {"pos": Vector2(300, 0), "kind": 2, "flash": 0.0},
        {"pos": Vector2(400, 0), "kind": 3, "flash": 0.0}
    ]
    swarm.update_swarm(enemies, Vector2.ZERO, 0.016)
    assert(swarm.spider.multimesh.visible_instance_count == 4)
    enemies[0].flash = 1.0
    swarm.update_swarm(enemies, Vector2.ZERO, 0.016)
    enemies[0].kind = 1
    swarm.update_swarm(enemies, Vector2.ZERO, 0.016)
    assert(swarm.previous_kinds[0] == 1)
    enemies[0].kind = 0
    swarm.update_swarm(enemies, Vector2.ZERO, 0.016)
    assert(swarm.previous_kinds[0] == 0)
    assert(swarm.bodies.multimesh.visible_instance_count == 4)
    assert(swarm.heads.multimesh.visible_instance_count == 4)
    assert(swarm.armor.multimesh.visible_instance_count == 4)
    assert(swarm.eyes.multimesh.visible_instance_count == 16)
    assert(swarm.seams.multimesh.visible_instance_count == 12)
    assert(swarm.accents.multimesh.visible_instance_count == 8)
    assert(swarm.legs.multimesh.visible_instance_count == 64)
    assert(swarm.guns.multimesh.visible_instance_count == 8)
    assert(swarm.boss_lights.multimesh.visible_instance_count == 8)
    assert(swarm.boss_rig.visible)
    assert(swarm.boss_leg_pivots.size() == 8)
    assert(swarm.boss_turrets.size() == 2)
    assert(swarm.legs.material_override is ShaderMaterial)

    swarm.queue_free()
    print("GegnergrÃ¶ÃŸen- und Typen-Tests bestanden")
    quit()

