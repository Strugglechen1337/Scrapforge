class_name WeaponLogic
extends RefCounted


static func update_player_fire(game, delta: float) -> void:
	game.weapons.update(game, delta)
	game.fire_clock -= delta
	if game.fire_clock <= 0 and not game.enemies.is_empty():
		var is_vulcan: bool = game.state.level("vulcan") > 0
		var mini_lv: int = game.state.level("minigun")
		var has_minigun: bool = is_vulcan or mini_lv > 0
		var rocket_lv: int = game.state.level("rocket")
		var has_swarm: bool = game.state.level("swarm") > 0
		if not has_minigun and rocket_lv == 0 and not has_swarm:
			return
		var base_cd := maxf(0.12, 0.65 - game.state.level("cooldown") * 0.05)
		game.fire_clock = base_cd * (0.65 if is_vulcan else 1.0)
		var nearest: Dictionary = game.enemies[0]
		for enemy in game.enemies:
			if game.player.distance_squared_to(enemy.pos) < game.player.distance_squared_to(nearest.pos):
				nearest = enemy
		var dir: Vector2 = (nearest.pos - game.player).normalized()
		game.shot_index += 1
		var rocket_interval := 2 if rocket_lv >= 3 else 3
		var rocket_shot: bool = rocket_lv > 0 and game.shot_index % rocket_interval == 0
		if not has_minigun and not rocket_shot and not has_swarm:
			return
		if rocket_shot:
			game.play_sfx(&"rocket", game.player)
		elif has_minigun:
			game.play_sfx(&"minigun", game.player)
		if is_instance_valid(game.world_3d) and is_instance_valid(game.world_3d.robot):
			if rocket_shot:
				game.world_3d.robot.trigger_weapon_fire("rocket", 1.15)
			if has_minigun:
				game.world_3d.robot.trigger_weapon_fire("vulcan" if is_vulcan else "minigun", 0.75)
		var dmg_mult: float = game.progress.damage_multiplier()
		var gun_world := Vector3(game.player.x / 50.0 + dir.x * 0.40, 0.85, game.player.y / 50.0 + dir.y * 0.40)
		var rocket_world := gun_world
		if is_instance_valid(game.world_3d) and is_instance_valid(game.world_3d.robot):
			if has_minigun:
				gun_world = game.world_3d.robot.weapon_muzzle_world("vulcan" if is_vulcan else "minigun", game.player, dir)
			if rocket_shot:
				rocket_world = game.world_3d.robot.weapon_muzzle_world("rocket", game.player, dir)
		var gun_pos := Vector2(gun_world.x * 50.0, gun_world.z * 50.0)
		var rocket_pos := Vector2(rocket_world.x * 50.0, rocket_world.z * 50.0)
		if is_vulcan:
			for angle in [-0.10, 0.0, 0.10]:
				var use_rocket: bool = rocket_shot and angle == 0.0
				game.bullets.append({
					"pos": rocket_pos if use_rocket else gun_pos,
					"y": rocket_world.y if use_rocket else gun_world.y,
					"vel": dir.rotated(angle) * 680,
					"life": 2.0,
					"damage": int(round(34.0 * dmg_mult)),
					"rocket": use_rocket,
					"rocket_radius": 90.0 if rocket_lv >= 5 else 65.0,
				})
		elif has_minigun:
			var angles: Array = [-0.08, 0.0, 0.08] if mini_lv >= 5 else ([-0.04, 0.04] if mini_lv >= 3 else [0.0])
			var dmg: int = int(round((12 + mini_lv * 6 + rocket_lv * 5) * dmg_mult))
			for angle in angles:
				var use_rocket: bool = rocket_shot and angle == angles[0]
				game.bullets.append({
					"pos": rocket_pos if use_rocket else gun_pos,
					"y": rocket_world.y if use_rocket else gun_world.y,
					"vel": dir.rotated(angle) * 560,
					"life": 2.0,
					"damage": dmg,
					"rocket": use_rocket,
					"rocket_radius": 90.0 if rocket_lv >= 5 else (70.0 if rocket_lv >= 3 else 0.0),
				})
			if rocket_shot and rocket_lv >= 5:
				for r_ang in [-0.09, 0.09]:
					game.bullets.append({"pos": rocket_pos, "y": rocket_world.y, "vel": dir.rotated(r_ang) * 540, "life": 2.0, "damage": dmg, "rocket": true, "rocket_radius": 90.0})
		elif rocket_shot:
			var dmg: int = int(round((12 + rocket_lv * 5) * dmg_mult))
			var r_angles: Array = [-0.09, 0.0, 0.09] if rocket_lv >= 5 else [0.0]
			for r_ang in r_angles:
				game.bullets.append({
					"pos": rocket_pos,
					"y": rocket_world.y,
					"vel": dir.rotated(r_ang) * 560,
					"life": 2.0,
					"damage": dmg,
					"rocket": true,
					"rocket_radius": 90.0 if rocket_lv >= 5 else (70.0 if rocket_lv >= 3 else 0.0),
				})
		if has_minigun:
			game.spark(gun_pos, game.CYAN, 4)
			if OS.has_feature("mobile"):
				game.world_3d.effects_3d.burst(gun_pos, "muzzle")
			else:
				game.world_3d.effects_3d.muzzle(gun_pos, dir, "minigun", gun_world)
		if rocket_shot:
			if OS.has_feature("mobile"):
				game.world_3d.effects_3d.burst(rocket_pos, "muzzle")
			else:
				game.world_3d.effects_3d.muzzle(rocket_pos, dir, "rocket", rocket_world)
		if has_swarm:
			var sw_w: Vector3 = game.world_3d.robot.weapon_muzzle_world("swarm", game.player, dir) if (is_instance_valid(game.world_3d) and is_instance_valid(game.world_3d.robot)) else rocket_world
			var sw_pos := Vector2(sw_w.x * 50.0, sw_w.z * 50.0)
			if OS.has_feature("mobile"):
				game.world_3d.effects_3d.burst(sw_pos, "muzzle")
			else:
				game.world_3d.effects_3d.muzzle(sw_pos, dir, "swarm", sw_w)
			for angle in [-0.25, -0.12, 0.0, 0.12, 0.25]:
				game.bullets.append({"pos": sw_pos, "y": sw_w.y, "vel": dir.rotated(angle) * 460, "life": 2.0, "damage": 36, "visual": "swarm"})


static func update_bullets(game, delta: float) -> void:
	for bullet in game.bullets:
		bullet.pos += bullet.vel * delta
		bullet.life -= delta
		for enemy in game.enemies:
			if bullet.pos.distance_to(enemy.pos) < 22:
				if bullet.get("plasma", false) or bullet.get("singularity", false):
					var splash_r: float = bullet.get("splash_radius", 100.0)
					var is_singularity: bool = bullet.get("singularity", false)
					for victim in game.enemies:
						if victim.pos.distance_to(enemy.pos) < splash_r:
							victim.hp -= bullet.damage
							if is_singularity:
								victim.pos = victim.pos.move_toward(enemy.pos, 95.0)
					if OS.has_feature("mobile"):
						game.world_3d.effects_3d.burst(bullet.pos, "explosion")
					else:
						game.world_3d.effects_3d.plasma_impact(bullet.pos, splash_r)
				else:
					enemy.hp -= bullet.damage
					var r_rad: float = bullet.get("rocket_radius", 0.0)
					if bullet.get("rocket", false) and r_rad > 0.0:
						for victim in game.enemies:
							if victim != enemy and victim.pos.distance_to(enemy.pos) < r_rad:
								victim.hp -= bullet.damage * 0.6
				enemy.flash = 0.15
				game.play_sfx(&"enemy_hit", enemy.pos)
				if bullet.get("rocket", false) or bullet.get("plasma", false):
					game.play_sfx(&"explosion", bullet.pos)
				if bullet.get("rocket", false):
					game.world_3d.effects_3d.burst(bullet.pos, "explosion")
				game.hit_flash = 0.15
				if enemy.kind == CameraFeedback.KIND_BOSS:
					game.feedback("boss_hit")
				game.spark(bullet.pos, game.CYAN, 5)
				game.damage_texts.append({"pos": enemy.pos, "value": bullet.damage, "life": 0.7})
				game.world_3d.effects_3d.damage(enemy.pos, bullet.damage, bullet.get("rocket", false) or bullet.get("plasma", false))
				game.world_3d.effects_3d.hit(bullet.pos, bullet.vel.normalized(), bullet.get("rocket", false) or bullet.get("plasma", false))
				bullet.life = 0
				break
	game.bullets = game.bullets.filter(func(b): return b.life > 0)


static func update_enemy_shots(game, delta: float) -> void:
	for shot in game.enemy_shots:
		shot.pos += shot.vel * delta
		shot.life -= delta
		if shot.pos.distance_to(game.player) < 25:
			game.weapons.damage(game, 8)
			game.feedback("player_shot")
			shot.life = 0
	game.enemy_shots = game.enemy_shots.filter(func(b): return b.life > 0)


static func update_pickups(game, delta: float) -> void:
	for i in range(game.crates.size() - 1, -1, -1):
		if game.player.distance_to(game.crates[i]) < 46.0:
			var crate_pos: Vector2 = game.crates[i]
			game.world_3d.effects_3d.burst(crate_pos, "pickup")
			game.play_sfx(&"level_up", crate_pos)
			game.crates.remove_at(i)
			game.open_crate()
			return
	for i in range(game.crystals.size() - 1, -1, -1):
		var distance: float = game.player.distance_to(game.crystals[i])
		var magnet_range: float = 35 + game.state.level("magnet") * 20 + game.state.level("sensor") * 20 + game.progress.magnet_bonus()
		if distance < magnet_range * 2 and distance > 8:
			game.crystals[i] = game.crystals[i].move_toward(game.player, 180 * delta)
		if game.player.distance_to(game.crystals[i]) < magnet_range:
			game.world_3d.effects_3d.burst(game.crystals[i], "pickup")
			game.play_sfx(&"pickup", game.crystals[i])
			game.crystals.remove_at(i)
			game.xp += 1
			game.total_scrap += 1
			if game.xp >= game.level * 5:
				game.xp = 0
				game.level += 1
				game.play_sfx(&"level_up")
				game.choose_upgrade()
				break
