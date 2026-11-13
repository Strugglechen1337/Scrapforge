extends Node

# A deterministic, quiet stage using the same camera and projectile pools as play.
var game: Node
const WEAPONS := ["minigun", "rakete", "laser", "plasma", "flammenwerfer", "schulterturm", "schwarm-werfer", "gegnerschuss"]
const EFFECTS := ["treffer", "tod-schwarm", "tod-brute", "tod-boss", "schadenszahlen"]
const TIMES := [0.005, 0.2, 0.5]

func _ready() -> void:
    call_deferred("run")

func run() -> void:
    game.panel.visible = false
    # One warm-up frame lets the normal world prewarm finish.
    game.world_3d.update_view()
    await get_tree().process_frame
    game.world_3d.update_view()
    while true:
        for weapon in WEAPONS + EFFECTS:
            game.bullets.clear()
            game.enemy_shots.clear()
            game.enemies.clear()
            game.world_3d.update_view()
            # Allow the previous weapon's transient particles to dissipate.
            await get_tree().create_timer(0.85).timeout
            game.state = UpgradeState.new()
            var module: String = {"minigun": "minigun", "rakete": "rocket", "laser": "laser", "plasma": "plasma", "flammenwerfer": "flamethrower", "schulterturm": "turret", "schwarm-werfer": "swarm"}.get(weapon, "minigun")
            game.state.upgrade(module)
            game.enemies.append(game.make_enemy(2, Vector2(390, -120)))
            var origin := Vector2(48, -16)
            var direction := Vector2(1, -0.3).normalized()
            if weapon in WEAPONS and weapon != "gegnerschuss" and not OS.has_feature("mobile"):
                var kind: String = {"rakete": "rocket", "schulterturm": "turret", "schwarm-werfer": "swarm", "flammenwerfer": "flamethrower"}.get(weapon, weapon)
                game.world_3d.effects_3d.muzzle(game.player + direction * 60, direction, kind)
            match weapon:
                "treffer":
                    game.enemies[0].pos = Vector2(200, -60)
                    game.enemies[0].flash = 0.15
                    for k in range(3):
                        game.world_3d.effects_3d.hit(Vector2(190, -57) + Vector2(0, k * 6), direction)
                    game.world_3d.effects_3d.damage(Vector2(200, -60), 24)
                "tod-schwarm":
                    game.enemies.clear()
                    for k in range(6):
                        game.world_3d.effects_3d.enemy_death(Vector2(170 + k * 28, -50 - (k % 3) * 22), 0)
                "tod-brute":
                    game.enemies.clear()
                    game.world_3d.effects_3d.enemy_death(Vector2(200, -60), 1)
                "tod-boss":
                    game.enemies.clear()
                    game.world_3d.effects_3d.enemy_death(Vector2(200, -60), 3)
                "schadenszahlen":
                    game.enemies[0].pos = Vector2(200, -60)
                    for k in range(5):
                        game.world_3d.effects_3d.damage(Vector2(120 + k * 70, 20 - (k % 2) * 90), 12 + k * 6)
                    game.world_3d.effects_3d.damage(Vector2(170, -140), 54, true)
                    game.world_3d.effects_3d.damage(Vector2(300, -10), 66, true)
                "minigun":
                    game.bullets.append({"pos": origin, "vel": direction * 560, "life": 2.0})
                "rakete":
                    game.bullets.append({"pos": origin, "vel": direction * 560, "life": 2.0, "rocket": true})
                "laser":
                    game.weapons.show_beam(game, direction, 650 if OS.has_feature("mobile") else 400.0, Color("b749ff") if OS.has_feature("mobile") else Color("ff7a1a"), true)
                "plasma":
                    game.bullets.append({"pos": origin, "vel": direction * 420, "life": 2.0, "plasma": true})
                "flammenwerfer":
                    game.weapons.show_flames(game, direction)
                "schulterturm":
                    game.bullets.append({"pos": origin, "vel": direction * 560, "life": 2.0, "visual": "turret"})
                "schwarm-werfer":
                    for angle in [-0.25, -0.12, 0.12, 0.25]:
                        game.bullets.append({"pos": origin, "vel": direction.rotated(angle) * 460, "life": 2.0, "visual": "swarm"})
                "gegnerschuss":
                    game.enemy_shots.append({"pos": Vector2(290, -90), "vel": -direction * 240, "life": 4.0})
            var elapsed := 0.0
            var sample := 0
            while sample < TIMES.size():
                var dt: float = get_process_delta_time()
                elapsed += dt
                for bullet in game.bullets:
                    bullet.pos += bullet.vel * dt
                for bullet in game.enemy_shots:
                    bullet.pos += bullet.vel * dt
                if weapon == "laser" and fmod(elapsed, 0.1) < dt:
                    game.weapons.show_beam(game, direction, 650 if OS.has_feature("mobile") else 400.0, Color("ff7a1a"), true)
                if weapon == "flammenwerfer" and fmod(elapsed, 0.15) < dt:
                    game.weapons.show_flames(game, direction)
                game.world_3d.update_view()
                if elapsed >= TIMES[sample]:
                    game.capture_demo("vfx-%s-%d" % [weapon, sample + 1])
                    sample += 1
                await get_tree().process_frame
            if weapon == "plasma" and not OS.has_feature("mobile"):
                game.world_3d.effects_3d.plasma_impact(Vector2(390, -120), 100.0)
                game.bullets.clear()
                game.world_3d.update_view()
                var t := 0.0
                while t < 0.14:
                    t += get_process_delta_time()
                    game.world_3d.update_view()
                    await get_tree().process_frame
                game.capture_demo("vfx-plasma-treffer")
                await get_tree().process_frame
        game.bullets.clear()
        game.enemies.clear()
        game.enemy_shots.clear()
        for i in range(176):
            var angle := PI * 0.32 + TAU * 0.78 * (float(i) / 176.0) + float(i % 5) * 0.03
            game.enemies.append(game.make_enemy(2 if i % 14 == 0 else 0, Vector2.from_angle(angle) * (230.0 + 32.0 * (i % 12))))
        for i in range(32):
            var angle := TAU * i / 32.0
            game.enemy_shots.append({"pos": Vector2.from_angle(angle) * (140.0 + 15.0 * (i % 5)), "vel": -Vector2.from_angle(angle) * 240, "life": 4.0})
        game.world_3d.update_view()
        game.capture_demo("gegnerfeuer-dicht")
        if not OS.has_feature("mobile"):
            game.enemy_shots.clear()
            var t2 := 0.0
            while t2 < 0.4:
                t2 += get_process_delta_time()
                game.weapons.show_beam(game, Vector2(1, 0.1).normalized(), 400.0, Color("ff7a1a"), true)
                game.weapons.show_flames(game, Vector2(-0.8, 0.6).normalized())
                game.world_3d.update_view()
                await get_tree().process_frame
            game.capture_demo("laser-flammen-schwarm")
        await RenderingServer.frame_post_draw
        await get_tree().process_frame
        if not game.shot_dir.is_empty():
            for task in game.screenshot_tasks:
                WorkerThreadPool.wait_for_task_completion(task)
            get_tree().quit()
            return


