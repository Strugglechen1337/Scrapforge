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
    game.fire_clock = 100
    game._process(0.2)
    assert(game.enemies[0].hp < 24 and game.enemies[1].hp < 24)
    game.start_game()
    game.state.upgrade("shield")
    game.weapons.damage(game, 8)
    assert(game.hp == 100)
    game.weapons.damage(game, 8)
    assert(game.hp == 92)
    game.queue_free()
    print("Waffen-Tests bestanden")
    quit()
