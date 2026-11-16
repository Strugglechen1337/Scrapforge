class_name RunSimulation
extends RefCounted


static func make_enemy(kind: int, position: Vector2, elite := false) -> Dictionary:
	var initial_attack := randf_range(2.5, 6.5) if kind == 2 else (1.0 if kind in [3, 5] else 2.0)
	var stop_d := 72.0 if kind == 5 else (68.0 if kind == 3 else (220.0 if kind == 2 else (24.0 if kind == 4 else 30.0)))
	var max_hp: int = [24, 70, 34, 1800, 52, 2600][kind]
	var speed: float = [120.0, 50.0, 75.0, 45.0, 155.0, 52.0][kind]
	if elite:
		max_hp = int(round(max_hp * 3.5))
		speed *= 1.15
	return {
		"pos": position,
		"hp": max_hp,
		"max_hp": max_hp,
		"kind": kind,
		"elite": elite,
		"speed": speed,
		"attack": initial_attack,
		"jump_clock": 6.0,
		"jump_warning": 0.0,
		"jump_target": position,
		"flash": 0.0,
		"stop_dist": stop_d,
		"fresh": true,
		"intro": 0.0,
		"stage_lost": 0,
	}


static func spawn_boss(game) -> void:
	if game.boss_spawned:
		return
	game.boss_spawned = true
	game.play_sfx(&"boss")
	game.play_music("boss")
	var b_kind: int = 5 if (game.progress.selected_arena == "rainyard" or game.has_any_evolution()) else 3
	var boss := make_enemy(b_kind, game.player + Vector2(215, 25))
	boss["intro"] = 1.35
	game.enemies.append(boss)


static func shoot_enemy(game, origin: Vector2, direction: Vector2, speed := 240.0) -> void:
	if game.enemy_shots.size() >= 32:
		return
	game.enemy_shots.append({"pos": origin, "vel": direction.normalized() * speed, "life": 4.0})


static func spawn_waves(game, delta: float) -> void:
	game.spawn_clock -= delta
	if game.spawn_clock > 0:
		return
	if game.autoplay and game.demo_stage >= 2:
		game.spawn_clock = 0.22 if game.enemies.size() < 168 else 0.85
		var roll_auto := randi() % 12
		var kind_auto := 0 if roll_auto < 9 else (1 if roll_auto < 11 else 2)
		var a_auto := PI * 0.32 + randf() * TAU * 0.78
		var e_auto := make_enemy(kind_auto, game.player + Vector2.from_angle(a_auto) * 460)
		if kind_auto != 2:
			e_auto["slot"] = Vector2.from_angle(a_auto) * randf_range(65.0, 280.0)
		game.enemies.append(e_auto)
		return
	if game.elapsed >= game.next_elite_at:
		game.next_elite_at += 28.0
		var elite_angle := randf() * TAU
		var elite_kind := 1 if randi() % 2 == 0 else 2
		game.enemies.append(make_enemy(elite_kind, game.player + Vector2.from_angle(elite_angle) * 520.0, true))
	game.spawn_clock = lerpf(2.2, 0.28, clampf(game.elapsed / 240.0, 0.0, 1.0))
	var wave_count := 2 if (game.elapsed < 2.0 or game.elapsed >= 180.0) else 1
	for w in range(wave_count):
		var roll := randi() % 100
		var kind := 0
		if game.progress.selected_arena == "rainyard" and game.elapsed >= 15.0 and roll >= 75:
			kind = 4
		elif game.elapsed >= 60.0:
			kind = 0 if roll < 72 else (1 if roll < 92 else 2)
		elif game.elapsed >= 25.0:
			kind = 0 if roll < 80 else 1
		var angle := randf() * TAU
		var spawn_dist := 280.0 if game.elapsed < 5.0 else 580.0
		game.enemies.append(make_enemy(kind, game.player + Vector2.from_angle(angle) * spawn_dist))


static func update_enemies(game, delta: float) -> void:
	var is_shredder: bool = game.state.level("shredder") > 0
	var saw_count: int = 6 if is_shredder else game.state.level("saw")
	var saw_radius: float = 108.0 if is_shredder else 78.0
	var saw_speed: float = 2.6 if is_shredder else 1.8
	var saw_hit_r: float = 30.0 if is_shredder else 23.0
	var saw_dps: float = (56.0 if is_shredder else 24.0) * game.progress.damage_multiplier()
	for enemy in game.enemies:
		var diff: Vector2 = game.player - enemy.pos
		enemy.flash = maxf(0.0, enemy.get("flash", 0.0) - delta)
		var goal: Vector2 = game.player + enemy.get("slot", Vector2.ZERO)
		var to_goal: Vector2 = goal - enemy.pos
		var stop_dist: float = enemy.get("stop_dist", 32.0)
		if enemy.has("slot"):
			if to_goal.length() > 12.0:
				enemy.pos += to_goal.normalized() * enemy.speed * delta
		elif diff.length() > stop_dist:
			enemy.pos += diff.normalized() * enemy.speed * delta
		if enemy.kind in [2, 3, 5]:
			enemy.attack = enemy.get("attack", 2.0) - delta
			if enemy.attack <= 0:
				enemy.attack = randf_range(5.8, 8.5) if enemy.kind == 2 else (2.6 if enemy.kind == 5 else 3.2)
				if enemy.kind == 2:
					shoot_enemy(game, enemy.pos, diff)
				elif enemy.kind == 5:
					for k in range(8):
						shoot_enemy(game, enemy.pos, Vector2.from_angle(TAU * float(k) / 8.0), 260.0)
				else:
					for spread in [-0.5, -0.25, 0.0, 0.25, 0.5]:
						shoot_enemy(game, enemy.pos, diff.rotated(spread), 280.0)
			if enemy.kind in [3, 5]:
				update_boss(game, enemy, delta)
		for i in range(saw_count):
			var blade: Vector2 = game.player + Vector2.from_angle(game.elapsed * saw_speed + TAU * i / saw_count) * saw_radius
			if enemy.pos.distance_to(blade) < saw_hit_r:
				enemy.hp -= delta * saw_dps
				if is_instance_valid(game.world_3d) and is_instance_valid(game.world_3d.robot):
					game.world_3d.robot.trigger_weapon_fire("shredder" if is_shredder else "saw", 1.0)
				if enemy.flash <= 0.0:
					enemy.flash = 0.14
					game.world_3d.effects_3d.hit(enemy.pos, (enemy.pos - blade).normalized())
		if diff.length() < 36:
			var armor_red: float = minf(0.65, game.state.level("armor") * 0.05 + ChassisCatalog.armor_bonus(game.progress.selected_chassis))
			game.weapons.damage(game, delta * 8.0 * (1.0 - armor_red))
			game.hit_flash = 0.4


static func update_boss(game, enemy: Dictionary, delta: float) -> void:
	if enemy.get("intro", 0.0) > 0.0:
		enemy.intro -= delta
		if enemy.intro <= 0.0:
			enemy.intro = 0.0
			if OS.has_feature("mobile"):
				game.world_3d.effects_3d.burst(enemy.pos, "explosion")
			else:
				game.world_3d.effects_3d.explode(enemy.pos, 2)
			game.play_sfx(&"explosion", enemy.pos)
			game.feedback("boss_slam")
	var hp_ratio: float = float(enemy.hp) / maxf(float(enemy.get("max_hp", 1800)), 1.0)
	var lost: int = int(enemy.get("stage_lost", 0))
	if (lost == 0 and hp_ratio < 0.70) or (lost == 1 and hp_ratio < 0.35):
		enemy["stage_lost"] = lost + 1
		if OS.has_feature("mobile"):
			game.world_3d.effects_3d.burst(enemy.pos, "explosion")
		else:
			game.world_3d.effects_3d.explode(enemy.pos, 1)
		game.play_sfx(&"explosion", enemy.pos)
		game.feedback("boss_slam")
	enemy.jump_clock = enemy.get("jump_clock", 6.0) - delta
	if enemy.jump_clock <= 0 and enemy.get("jump_warning", 0.0) <= 0:
		enemy.jump_target = game.player
		enemy.jump_warning = 1.1
		enemy.jump_clock = 8.0
	if enemy.get("jump_warning", 0.0) > 0:
		enemy.jump_warning -= delta
		if enemy.jump_warning <= 0:
			enemy.pos = enemy.jump_target
			game.world_3d.effects_3d.burst(enemy.pos, "explosion")
			game.play_sfx(&"explosion", enemy.pos)
			game.feedback("boss_slam")
			if enemy.pos.distance_to(game.player) < 100:
				game.weapons.damage(game, 25)


static func process_deaths(game) -> void:
	for enemy in game.enemies:
		if enemy.hp <= 0:
			game.crystals.append(enemy.pos)
			if enemy.get("elite", false):
				game.crates.append(enemy.pos)
				game.spark(enemy.pos, Color("c65cff"), 24)
			game.kills += 1
			game.spark(enemy.pos, game.PINK, 16)
			game.world_3d.effects_3d.enemy_death(enemy.pos, enemy.kind)
			game.play_sfx(&"explosion", enemy.pos)
			if enemy.kind in [CameraFeedback.KIND_BOSS, 5]:
				game.won = true
				game.feedback("boss_death")
			elif enemy.kind == CameraFeedback.KIND_BRUTE:
				game.feedback("brute_death")
	game.enemies = game.enemies.filter(func(e): return e.hp > 0)


static func update_boss_bar_and_end(game) -> void:
	if is_instance_valid(game.boss_bar):
		var bosses: Array = game.enemies.filter(func(e): return e.kind in [3, 5])
		game.boss_bar.visible = not bosses.is_empty()
		game.boss_label.visible = game.boss_bar.visible
		if is_instance_valid(game.boss_panel):
			game.boss_panel.visible = game.boss_bar.visible
		if not bosses.is_empty():
			game.boss_bar.max_value = float(bosses[0].get("max_hp", 1800))
			game.boss_bar.value = maxf(0.0, bosses[0].hp)
			game.boss_label.text = "WARNUNG // BOSS: BELAGERUNGS-KOLOSS" if bosses[0].kind == 5 else "WARNUNG // BOSS: SPINNEN-MECH"
	if game.hp <= 0 or game.won or game.elapsed >= 600:
		game.show_end(game.won or game.hp > 0)
