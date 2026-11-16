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

func show_beam(game: Node, direction: Vector2, length: float, color: Color, hit := false) -> void:
	if not OS.has_feature("mobile"):
		var start: Vector2 = game.player + direction * 60
		game.world_3d.effects_3d.beam(start, direction, maxf(length - 60.0, 10.0), hit)
		return
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
	if not OS.has_feature("mobile"):
		game.world_3d.effects_3d.flame(game.player + direction * 60, direction)
		return
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
	var weapon_pairs := [
		["laser", "prism_laser"],
		["flamethrower", "inferno"],
		["plasma", "singularity"],
		["turret", "bastion"],
		["drone", "hive_drone"],
	]
	for pair in weapon_pairs:
		var id: String = pair[0]
		var evo_id: String = pair[1]
		var is_evo: bool = game.state.level(evo_id) > 0
		var level: int = 5 if is_evo else game.state.level(id)
		if level == 0:
			continue
		var clock_key: String = evo_id if is_evo else id
		clocks[clock_key] = float(clocks.get(clock_key, 0.0)) - delta
		if clocks[clock_key] > 0 or game.enemies.is_empty():
			continue
		var nearest: Dictionary = game.enemies[0]
		for enemy in game.enemies:
			if game.player.distance_squared_to(enemy.pos) < game.player.distance_squared_to(nearest.pos):
				nearest = enemy
		var distance: float = game.player.distance_to(nearest.pos)
		if distance > 500.0 + game.state.level("sensor") * 40.0 + (150.0 if is_evo else 0.0):
			continue
		var direction: Vector2 = (nearest.pos - game.player).normalized()
		if id == "flamethrower":
			clocks[clock_key] = 0.14 if is_evo else 0.18
		elif id == "plasma":
			clocks[clock_key] = 1.15 if is_evo else 1.4
		elif id == "turret":
			clocks[clock_key] = 0.42 if is_evo else 0.65
		elif id == "drone":
			clocks[clock_key] = 0.38 if is_evo else 0.65
		else:
			clocks[clock_key] = 0.55 if is_evo else 0.65
		var active_id: String = evo_id if is_evo else id
		var damage: float = game.definitions[active_id].values[level - 1] * game.progress.damage_multiplier()
		if not OS.has_feature("mobile"):
			game.world_3d.effects_3d.muzzle(game.player + direction * 60, direction, id)
		if id == "laser":
			AudioManager.play(&"laser", game.player)
			var beam_range: float = 900.0 if is_evo else (650.0 + (level - 1) * 35.0)
			var beam_width: float = 54.0 if is_evo else (23.0 + (level - 1) * 4.5)
			var reach := 0.0
			for enemy in game.enemies:
				var offset: Vector2 = enemy.pos - game.player
				if offset.dot(direction) > 0 and offset.dot(direction) < beam_range and absf(offset.cross(direction)) < beam_width:
					reach = maxf(reach, offset.dot(direction))
			var beam_color := Color("c65cff") if (is_evo or OS.has_feature("mobile")) else Color("ff7a1a")
			show_beam(game, direction, reach if reach > 0.0 and not OS.has_feature("mobile") else beam_range, beam_color, reach > 0.0)
			for enemy in game.enemies:
				var offset: Vector2 = enemy.pos - game.player
				if offset.dot(direction) > 0 and offset.dot(direction) < beam_range and absf(offset.cross(direction)) < beam_width:
					enemy.hp -= damage
					game.world_3d.effects_3d.hit(enemy.pos, direction)
					AudioManager.play(&"enemy_hit", enemy.pos)
					enemy.flash = 0.15
		elif id == "flamethrower":
			AudioManager.flame_active()
			show_flames(game, direction)
			var flame_range: float = 340.0 if is_evo else (220.0 + (level - 1) * 20.0)
			var flame_dot: float = 0.50 if is_evo else (0.86 - (level - 1) * 0.04)
			for enemy in game.enemies:
				var offset: Vector2 = enemy.pos - game.player
				if offset.length() < flame_range and offset.normalized().dot(direction) > flame_dot:
					enemy.hp -= damage * 0.18
					AudioManager.play(&"enemy_hit", enemy.pos)
					enemy.flash = 0.15
		elif id == "plasma":
			AudioManager.play(&"plasma", game.player)
			var splash_r: float = 210.0 if is_evo else (100.0 + (level - 1) * 15.0)
			var orbs: Array = [-0.14, 0.14] if (not is_evo and level >= 5) else [0.0]
			for ang in orbs:
				game.bullets.append({
					"pos": game.player,
					"vel": direction.rotated(ang) * 420,
					"life": 2.0,
					"damage": damage,
					"plasma": true,
					"singularity": is_evo,
					"splash_radius": splash_r,
				})
		elif id == "turret":
			AudioManager.play(&"turret", game.player)
			var spread: Array = [-0.15, -0.05, 0.05, 0.15] if is_evo else ([-0.10, 0.0, 0.10] if level >= 5 else ([-0.06, 0.06] if level >= 3 else [0.0]))
			for ang in spread:
				game.bullets.append({"pos": game.player, "vel": direction.rotated(ang) * 580, "life": 2.0, "damage": damage, "visual": "turret"})
		else:
			AudioManager.play(&"drone", game.player)
			var targets: Array = game.enemies.duplicate()
			targets.sort_custom(func(a, b): return game.player.distance_squared_to(a.pos) < game.player.distance_squared_to(b.pos))
			var max_targets := 4 if is_evo else (3 if level >= 5 else (2 if level >= 3 else 1))
			for ti in range(mini(max_targets, targets.size())):
				var tdir: Vector2 = (targets[ti].pos - game.player).normalized()
				game.bullets.append({"pos": game.player, "vel": tdir * 580, "life": 2.0, "damage": damage, "visual": "drone"})
