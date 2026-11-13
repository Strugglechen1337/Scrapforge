extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.start_game()
    var world = game.world_3d
    if OS.has_feature("mobile"):
        assert(world.enemy_orb_mesh is SphereMesh)
        assert(world.plasma_orb_mesh is SphereMesh)
        assert(world.bullet_core_mesh is BoxMesh)
    else:
        for mesh in [world.enemy_orb_mesh, world.enemy_halo_mesh, world.bullet_core_mesh, world.bullet_tail_mesh, world.rocket_body_mesh, world.rocket_nose_mesh, world.plasma_orb_mesh]:
            assert(mesh is ArrayMesh)
        assert(world.tracer.emission == Color("ff7a1a"))
        assert(world.plasma_glow.emission == Color("ff7a1a"))
        assert(world.ruby.emission == Color("ff2a2a"))
        assert(world.ruby.emission_energy_multiplier > world.plasma_glow.emission_energy_multiplier)
        assert(world.enemy_halo_mesh.get_aabb().size.x > world.plasma_orb_mesh.get_aabb().size.x)
        assert(world.projectile_nodes.size() == world.MAX_PLAYER_PROJECTILES)
        assert(world.enemy_projectile_nodes.size() == world.MAX_ENEMY_PROJECTILES)
        var first = world.projectile_nodes[0]
        var core_mesh = first.get_node("Core").mesh
        var material = first.get_node("Core").material_override
        for i in range(200):
            game.bullets.clear()
            for j in range(140):
                game.bullets.append({"pos": Vector2(j, 0), "vel": Vector2.RIGHT, "life": 2.0})
            game.world_3d.update_view()
            game.bullets.clear()
            game.world_3d.update_view()
        assert(world.projectile_nodes.size() == world.MAX_PLAYER_PROJECTILES)
        assert(world.projectile_nodes[0] == first)
        assert(first.get_node("Core").mesh == core_mesh)
        assert(first.get_node("Core").material_override == material)
        assert(world.projectile_nodes[1].get_node("Core").mesh == core_mesh)
        assert(not first.visible)
        var enemy_first = world.enemy_projectile_nodes[0]
        for i in range(200):
            game.enemy_shots.clear()
            for j in range(40):
                game.enemy_shots.append({"pos": Vector2(j, 0), "vel": Vector2.LEFT, "life": 2.0})
            world.update_view()
        assert(world.enemy_projectile_nodes.size() == world.MAX_ENEMY_PROJECTILES)
        assert(world.enemy_projectile_nodes[0] == enemy_first)
        game.enemy_shots.clear()
        world.update_view()
        assert(not enemy_first.visible)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await process_frame
    await create_timer(1.0).timeout
    print("Projektil-Pool und Materialien bestanden")
    quit()

