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
    game.queue_free()
    print("Boss- und Rundenende-Tests bestanden")
    quit()
