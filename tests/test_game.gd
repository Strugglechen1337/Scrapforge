extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.start_game()
    assert(game.state.level("minigun") == 1 and game.state.level("laser") == 0)
    for kind in range(3):
        var variant: Dictionary = game.make_enemy(kind, Vector2(300,0))
        assert(variant.kind == kind and variant.hp > 0 and variant.speed > 0)
    var shooter: Dictionary = game.make_enemy(2, Vector2(300,0))
    shooter.attack = 0.0
    game.enemies.append(shooter)
    game._process(0.01)
    assert(not game.enemy_shots.is_empty())
    game.start_game()
    game.spawn_boss()
    var boss_attack: Dictionary = game.enemies[0]
    boss_attack.attack = 0.0
    boss_attack.jump_clock = 0.0
    game._process(0.01)
    assert(game.enemy_shots.size() >= 5)
    assert(boss_attack.jump_warning > 0)
    assert(game.boss_bar.visible)
    assert(game.world_3d.swarm.boss_lights.multimesh.visible_instance_count == 8)
    assert(game.world_3d.swarm.legs.multimesh.visible_instance_count >= 16)
    var target: Vector2 = boss_attack.jump_target
    game._process(1.2)
    assert(boss_attack.pos.distance_to(target) < 0.01)
    game.start_game()
    game.elapsed = 300.0
    game._process(0.01)
    assert(game.boss_spawned)
    var boss = game.enemies.filter(func(e): return e.kind == 3)[0]
    boss.hp = 0
    game._process(0.01)
    assert(game.mode == "end" and game.won)
    game.start_game()
    game.hp = 0
    game._process(0.01)
    assert(game.mode == "end" and not game.won)
    game.start_game()
    for frame in range(80): game._process(0.1)
    assert(game.enemies.size() < 15)
    var fx: CombatEffects3D = game.world_3d.effects_3d
    for i in range(30): fx.burst(Vector2.ZERO,"explosion")
    assert(fx.burst_pool.size() == 20 and fx.light_count <= 8)
    fx._process(1.0)
    assert(fx.light_count == 0)
    game.enemy_shots.clear()
    for i in range(50): game.shoot_enemy(Vector2.ZERO,Vector2.RIGHT)
    assert(game.enemy_shots.size() == 32)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await create_timer(1.0).timeout
    print("Boss- und Rundenende-Tests bestanden")
    quit()
