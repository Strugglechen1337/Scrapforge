extends SceneTree

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
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
