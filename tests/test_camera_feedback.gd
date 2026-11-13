extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var fb := CameraFeedback.new()

	# Setting off: no shake and no hit-stop for any event.
	for event_name in ["player_shot", "boss_hit", "boss_slam", "boss_death", "brute_death"]:
		var off := fb.event(event_name, 10.0, false)
		assert(off.shake == 0.0 and off.hitstop == 0.0, "setting off must silence " + event_name)

	# Ordinary events give nothing (contact damage and normal enemy hits have no event at all).
	var none := fb.event("enemy_hit", 20.0, true)
	assert(none.shake == 0.0 and none.hitstop == 0.0)
	var unknown := fb.event("does_not_exist", 20.0, true)
	assert(unknown.shake == 0.0 and unknown.hitstop == 0.0)

	# Heavy events shake, and the boss death is the strongest.
	var slam := fb.event("boss_slam", 30.0, true)
	var shot := fb.event("player_shot", 30.0, true)
	var death := fb.event("boss_death", 30.0, true)
	assert(shot.shake > 0.0 and slam.shake > shot.shake and death.shake > slam.shake)
	assert(slam.hitstop == 0.0 and shot.hitstop == 0.0, "slam and player hits do not freeze the game")

	# Boss hits freeze once, then are rate limited so the minigun cannot freeze continuously.
	var fb2 := CameraFeedback.new()
	var first := fb2.event("boss_hit", 40.0, true)
	assert(first.hitstop > 0.0 and first.shake == 0.0)
	var count := 0
	var t := 40.0
	while t < 41.0:
		t += 0.05
		if fb2.event("boss_hit", t, true).hitstop > 0.0:
			count += 1
	assert(count <= 2, "at most two further boss hit-stops per second, got %d" % count)
	var later := fb2.event("boss_hit", 45.0, true)
	assert(later.hitstop > 0.0, "hit-stop is available again after the gap")

	# Large deaths freeze briefly; the boss death is the longest. Nothing exceeds the cap.
	var fb3 := CameraFeedback.new()
	var brute := fb3.event("brute_death", 50.0, true)
	assert(brute.hitstop > 0.0 and brute.shake > 0.0)
	var boss_death := fb3.event("boss_death", 50.01, true)
	assert(boss_death.hitstop > brute.hitstop, "boss death is never swallowed by the global gap")
	for event_name in CameraFeedback.HITSTOP:
		assert(CameraFeedback.HITSTOP[event_name] <= CameraFeedback.HITSTOP_MAX)
	assert(CameraFeedback.HITSTOP_SCALE > 0.0 and CameraFeedback.HITSTOP_SCALE < 1.0)

	print("Kamera-Feedback-Tests bestanden")
	quit(0)
