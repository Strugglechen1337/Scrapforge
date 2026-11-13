extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func count_nodes(node: Node) -> int:
    var count := 1
    for child in node.get_children():
        count += count_nodes(child)
    return count

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.start_game()
    await process_frame
    var fx = game.world_3d.effects_3d
    if OS.has_feature("mobile"):
        assert(fx.light_pool.is_empty() and fx.muzzle_pool.is_empty() and fx.shell_pool.is_empty() and fx.smoke_pool.is_empty())
        assert(game.world_3d.projectile_nodes[0].get_node("Smoke") is CPUParticles3D)
    else:
        assert(fx.light_pool.size() == fx.MAX_LIGHTS and fx.MAX_LIGHTS == 8)
        assert(fx.muzzle_pool.size() == fx.MAX_MUZZLES)
        assert(fx.shell_pool.size() == fx.MAX_SHELLS)
        assert(fx.smoke_pool.size() == fx.MAX_MUZZLE_SMOKE)
        for lamp in fx.light_pool:
            assert(not lamp.shadow_enabled)
        for item in fx.smoke_pool:
            assert(item.node is GPUParticles3D and item.node.amount == fx.SMOKE_PARTICLES)
        assert(game.world_3d.projectile_nodes.size() == game.world_3d.MAX_ROCKET_SMOKE_SYSTEMS)
        for projectile in game.world_3d.projectile_nodes:
            assert(projectile.get_node("Smoke") is GPUParticles3D)
            assert(projectile.get_node("Smoke").amount == game.world_3d.ROCKET_SMOKE_PARTICLES)
        fx._process(1.0)
        var before := count_nodes(fx)
        for i in range(200):
            fx.muzzle(Vector2.ZERO, Vector2.RIGHT, ["minigun", "rocket", "swarm", "laser", "plasma", "turret", "flamethrower"][i % 7])
            if i % 10 == 0:
                fx.burst(Vector2.ZERO, "explosion")
            assert(fx.light_count <= fx.MAX_LIGHTS)
        assert(count_nodes(fx) == before)
        assert(fx.light_count == fx.MAX_LIGHTS)
        assert(fx.muzzle_pool.filter(func(slot): return slot.life > 0).size() <= fx.MAX_MUZZLES)
        assert(fx.shell_pool.filter(func(slot): return slot.life > 0).size() <= fx.MAX_SHELLS)
        assert(fx.smoke_pool.filter(func(slot): return slot.life > 0).size() <= fx.MAX_MUZZLE_SMOKE)
        fx._process(1.0)
        assert(fx.light_count == 0)
        for slot in fx.muzzle_pool:
            assert(not slot.node.visible and slot.life <= 0)
        for slot in fx.shell_pool:
            assert(not slot.node.visible and slot.life <= 0)
        for slot in fx.smoke_pool:
            assert(not slot.node.emitting and slot.life <= 0)
        fx.muzzle(Vector2.ZERO, Vector2.RIGHT, "minigun")
        fx.muzzle(Vector2.ZERO, Vector2.RIGHT, "minigun")
        assert(fx.light_count == 1)
        fx._process(1.0)
        assert(fx.light_count == 0)
        assert(count_nodes(fx) == before)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await process_frame
    await create_timer(1.0).timeout
    print("Waffen-Effektpools bestanden")
    quit()
