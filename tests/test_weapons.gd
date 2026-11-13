extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.start_game()
    game.state.upgrade("laser")
    game.enemies.append(game.make_enemy(0, Vector2(100,0)))
    game.enemies.append(game.make_enemy(0, Vector2(180,0)))
    game.weapons.update(game, 0.01)
    assert(game.enemies[0].hp < 24 and game.enemies[1].hp < 24)
    game.start_game()
    game.state.upgrade("plasma")
    game.enemies.append(game.make_enemy(0, Vector2(100,0)))
    game.enemies.append(game.make_enemy(0, Vector2(130,0)))
    game.weapons.update(game, 0.01)
    assert(game.bullets.any(func(b): return b.get("plasma", false)))
    game.world_3d.update_view()
    var plasma_node: Node3D = game.world_3d.projectile_nodes[0]
    assert(plasma_node.get_node("PlasmaOrb").visible)
    assert(plasma_node.get_node("PlasmaOrb").mesh is SphereMesh if OS.has_feature("mobile") else plasma_node.get_node("PlasmaOrb").mesh is ArrayMesh)
    assert(not plasma_node.get_child(0).visible)
    game.fire_clock = 100
    game._process(0.2)
    assert(game.enemies[0].hp < 24 and game.enemies[1].hp < 24)
    game.start_game()
    game.state.upgrade("shield")
    game.weapons.damage(game, 8)
    assert(game.hp == 100)
    game.weapons.damage(game, 8)
    assert(game.hp == 92)
    # Flames continue applying damage on successive ticks to enemies in the cone.
    game.start_game()
    assert(game.state.upgrade("flamethrower"))
    var flame_target: Dictionary = game.make_enemy(1, Vector2(100,0))
    var outside_cone: Dictionary = game.make_enemy(1, Vector2(100,180))
    game.enemies.append(flame_target)
    game.enemies.append(outside_cone)
    var initial_hp: float = flame_target.hp
    game.weapons.update(game, 0.01)
    var first_hp: float = flame_target.hp
    assert(first_hp < initial_hp and outside_cone.hp == 70)
    game.weapons.update(game, 0.1)
    assert(flame_target.hp == first_hp)
    game.weapons.update(game, 0.1)
    assert(flame_target.hp < first_hp)
    # Turret acquires the nearest enemy without input and aims its projectile at it.
    game.start_game()
    assert(game.state.upgrade("turret"))
    game.enemies.append(game.make_enemy(1, Vector2(300,0)))
    game.enemies.append(game.make_enemy(1, Vector2(0,100)))
    game.weapons.update(game, 0.01)
    assert(game.bullets.size() == 1)
    var turret_bullet: Dictionary = game.bullets[0]
    assert(turret_bullet.vel.normalized().distance_to(Vector2.DOWN) < 0.001)
    assert(turret_bullet.damage == game.definitions["turret"].values[0])
    game.fire_clock = 100
    game._process(0.15)
    assert(game.enemies[1].hp < 70 and game.enemies[0].hp == 70)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await create_timer(1.0).timeout
    print("Waffen-Tests bestanden")
    quit()
