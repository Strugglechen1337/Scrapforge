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
        assert(fx.blast_pool.is_empty() and fx.hit_pool.is_empty() and fx.scorch_pool.is_empty() and fx.label_pool.size() == fx.MAX_LABELS and fx.beam_pool.is_empty() and fx.ring_pool.is_empty() and fx.flame_systems.is_empty() and fx.light_pool.is_empty() and fx.muzzle_pool.is_empty() and fx.shell_pool.is_empty() and fx.smoke_pool.is_empty())
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
        var w = game.world_3d
        assert(w.rocket_trails.size() == w.MAX_ROCKET_TRAILS)
        for trail in w.rocket_trails:
            assert(trail.get_node("Fire") is GPUParticles3D and trail.get_node("Fire").amount == w.ROCKET_FIRE_PARTICLES)
            assert(trail.get_node("Smoke") is GPUParticles3D and trail.get_node("Smoke").amount == w.ROCKET_SMOKE_PARTICLES)
        for projectile in w.projectile_nodes:
            assert(not projectile.has_node("Smoke"))
        var world_before := count_nodes(w)
        game.bullets.clear()
        for i in range(100):
            game.bullets.append({"pos": Vector2(i * 3, 0), "vel": Vector2(300, 0), "life": 2.0, "damage": 1, "rocket": true})
        for i in range(200):
            w.update_view()
        assert(w.rocket_trails.filter(func(tr): return tr.get_node("Fire").emitting).size() == w.MAX_ROCKET_TRAILS)
        assert(count_nodes(w) == world_before)
        game.bullets.clear()
        w.update_view()
        assert(w.rocket_trails.filter(func(tr): return tr.get_node("Fire").emitting or tr.get_node("Smoke").emitting).is_empty())
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
        # 3a-3: beam, flame, plasma ring pools
        assert(fx.beam_pool.size() == fx.MAX_BEAMS and fx.ring_pool.size() == fx.MAX_RINGS)
        assert(fx.flame_systems.size() == 4)
        var before3 := count_nodes(fx)
        for i in range(200):
            fx.beam(Vector2.ZERO, Vector2.RIGHT, 400.0, i % 2 == 0)
            fx.flame(Vector2.ZERO, Vector2.RIGHT)
            fx.plasma_impact(Vector2(i, 0), 100.0)
            assert(fx.beam_pool.filter(func(s): return s.life > 0).size() <= fx.MAX_BEAMS)
            assert(fx.ring_pool.filter(func(s): return s.life > 0).size() <= fx.MAX_RINGS)
            assert(fx.light_count <= fx.MAX_LIGHTS)
            fx._process(0.01)
        assert(fx.beam_pool.any(func(s): return s.glow.visible))
        assert(fx.flame_systems.all(func(ps): return ps.emitting))
        assert(count_nodes(fx) == before3)
        fx._process(1.0)
        fx._process(1.0)
        for slot in fx.beam_pool:
            assert(not slot.glow.visible and not slot.core.visible and slot.life <= 0 and slot.impact <= 0)
            assert(not slot.impact_glow.emitting and not slot.impact_sparks.emitting)
        for slot in fx.ring_pool:
            assert(not slot.node.visible and slot.life <= 0)
        assert(fx.flame_systems.all(func(ps): return not ps.emitting))
        assert(fx.light_count == 0)
        assert(count_nodes(fx) == before3)
        # 3b: hits, deaths, scorch decals, damage numbers
        assert(fx.blast_pool.size() == fx.MAX_BLASTS and fx.hit_pool.size() == fx.MAX_HIT_SPARKS)
        assert(fx.scorch_pool.size() == ArenaFloor.RESERVED_SCORCH_DECALS and ArenaFloor.RESERVED_SCORCH_DECALS <= 8)
        assert(fx.label_pool.size() == fx.PC_LABELS)
        var before4 := count_nodes(fx)
        var max_blast_seen := 0
        var max_scorch_seen := 0
        var max_labels_seen := 0
        for i in range(200):
            fx.enemy_death(Vector2(i * 40, 0), i % 4)
            fx.hit(Vector2(i, 0), Vector2.RIGHT, i % 5 == 0)
            fx.hit(Vector2(i, 3), Vector2.RIGHT)
            fx.hit(Vector2(i, 6), Vector2.RIGHT)
            fx.hit(Vector2(i, 9), Vector2.RIGHT)
            assert(fx.hit_sparks_frame <= fx.MAX_HIT_SPARKS_PER_FRAME)
            fx.damage(Vector2(i * 60, 0), 10 + i, i % 2 == 0)
            max_blast_seen = maxi(max_blast_seen, fx.active_blasts())
            max_scorch_seen = maxi(max_scorch_seen, fx.scorch_pool.filter(func(s): return s.node.visible).size())
            max_labels_seen = maxi(max_labels_seen, fx.label_pool.filter(func(s): return s.active).size())
            assert(fx.light_count <= fx.MAX_LIGHTS)
            fx._process(0.01)
        assert(max_blast_seen <= fx.MAX_BLASTS and max_blast_seen > 0)
        assert(max_scorch_seen <= 8 and max_scorch_seen == 8)
        assert(max_labels_seen <= fx.PC_LABELS)
        assert(count_nodes(fx) == before4)
        # colours: normal orange, strong white-yellow
        fx._process(2.0)
        fx.damage(Vector2(5000, 0), 12, false)
        fx.damage(Vector2(7000, 0), 90, true)
        var live: Array = fx.label_pool.filter(func(s): return s.active)
        assert(live.size() == 2)
        assert(live[0].node.modulate.is_equal_approx(fx.NORMAL_COLOR))
        assert(live[1].node.modulate.is_equal_approx(fx.STRONG_COLOR))
        assert(fx.LABEL_TIME < 0.6)
        # merge: same spot adds up instead of a second label
        fx.damage(Vector2(5000, 0), 8, false)
        assert(fx.label_pool.filter(func(s): return s.active).size() == 2 and live[0].value == 20)
        # boss: three blasts within 0.5 s
        fx._process(2.0)
        fx.enemy_death(Vector2.ZERO, 3)
        assert(fx.boss_queue.size() == 3)
        fx._process(0.0)
        fx._process(0.5)
        assert(fx.boss_queue.is_empty())
        # everything ends: scorch fades out, blasts, lamps, labels
        fx._process(fx.SCORCH_TIME + 1.0)
        fx._process(2.0)
        assert(fx.active_blasts() == 0 and fx.light_count == 0)
        assert(fx.scorch_pool.all(func(s): return not s.node.visible and s.life <= 0))
        assert(fx.label_pool.all(func(s): return not s.active))
        assert(fx.hit_pool.all(func(s): return s.life <= 0 and not s.ps.emitting))
        assert(count_nodes(fx) == before4)
        assert(count_nodes(fx) == before)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await process_frame
    await create_timer(1.0).timeout
    print("Waffen-Effektpools bestanden")
    quit()
