extends RefCounted

var clocks := {}
var shield_cooldown := 0.0

func damage(game: Node, amount: float) -> void:
    var level: int = game.state.level("shield")
    if level > 0 and shield_cooldown <= 0:
        shield_cooldown = 10.0 - level
        return
    game.hp -= amount
    AudioManager.play(&"player_hit", game.player)

func show_beam(game: Node, direction: Vector2, length: float, color: Color) -> void:
    var beam := MeshInstance3D.new()
    if OS.has_feature("mobile"): beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.035
    mesh.bottom_radius = 0.035
    mesh.height = length / 50.0
    beam.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 2.0
    beam.material_override = material
    game.world_3d.add_child(beam)
    beam.position = Vector3((game.player.x + direction.x * length / 2) / 50.0, 0.8, (game.player.y + direction.y * length / 2) / 50.0)
    beam.rotation = Vector3(PI / 2, -atan2(direction.y, direction.x) + PI / 2, 0)
    game.get_tree().create_timer(0.12).timeout.connect(beam.queue_free)

func show_flames(game: Node, direction: Vector2) -> void:
    var particles := CPUParticles3D.new()
    if OS.has_feature("mobile"): particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mesh := SphereMesh.new()
    mesh.radius = 0.09
    mesh.height = 0.18
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("ff7b16")
    material.emission_enabled = true
    material.emission = Color("ff5700")
    mesh.material = material
    particles.mesh = mesh
    particles.amount = 10 if OS.has_feature("mobile") else 20
    particles.lifetime = 0.35
    particles.one_shot = true
    particles.direction = Vector3(direction.x, 0, direction.y)
    particles.spread = 22.0
    particles.initial_velocity_min = 4.0
    particles.initial_velocity_max = 10.0
    particles.gravity = Vector3.ZERO
    game.world_3d.add_child(particles)
    particles.position = Vector3(game.player.x / 50.0, 0.7, game.player.y / 50.0)
    particles.emitting = true
    game.get_tree().create_timer(0.8).timeout.connect(particles.queue_free)

func update(game: Node, delta: float) -> void:
    shield_cooldown = maxf(0.0, shield_cooldown - delta)
    for id in ["laser", "flamethrower", "plasma", "turret", "drone"]:
        var level: int = game.state.level(id)
        if level == 0: continue
        clocks[id] = float(clocks.get(id, 0.0)) - delta
        if clocks[id] > 0 or game.enemies.is_empty(): continue
        var nearest: Dictionary = game.enemies[0]
        for enemy in game.enemies:
            if game.player.distance_squared_to(enemy.pos) < game.player.distance_squared_to(nearest.pos): nearest = enemy
        var distance: float = game.player.distance_to(nearest.pos)
        if distance > 500.0 + game.state.level("sensor") * 40.0: continue
        var direction: Vector2 = (nearest.pos - game.player).normalized()
        clocks[id] = 0.18 if id == "flamethrower" else (1.4 if id == "plasma" else 0.65)
        var damage: float = game.definitions[id].values[level - 1]
        if id == "laser":
            AudioManager.play(&"laser", game.player)
            show_beam(game, direction, 650, Color("b749ff") if OS.has_feature("mobile") else Color("ff7a1a"))
            for enemy in game.enemies:
                var offset: Vector2 = enemy.pos - game.player
                if offset.dot(direction) > 0 and offset.dot(direction) < 650 and absf(offset.cross(direction)) < 23:
                    enemy.hp -= damage
                    AudioManager.play(&"enemy_hit", enemy.pos)
                    enemy.flash = 0.15
        elif id == "flamethrower":
            AudioManager.flame_active()
            show_flames(game, direction)
            for enemy in game.enemies:
                var offset: Vector2 = enemy.pos - game.player
                if offset.length() < 220 and offset.normalized().dot(direction) > 0.86:
                    enemy.hp -= damage * 0.18
                    AudioManager.play(&"enemy_hit", enemy.pos)
                    enemy.flash = 0.15
        elif id == "plasma":
            AudioManager.play(&"plasma", game.player)
            game.bullets.append({"pos": game.player, "vel": direction * 420, "life": 2.0, "damage": damage, "plasma": true})
        else:
            AudioManager.play(&"minigun", game.player)
            game.bullets.append({"pos": game.player, "vel": direction * 560, "life": 2.0, "damage": damage, "visual": "turret" if id == "turret" else "drone"})
