class_name CameraFeedback
extends RefCounted
## Decides when the camera shakes and when the game briefly freezes (hit-stop).
## Roadmap Phase 3: subtle shake only on heavy events, short hit-stop on boss hits
## and on the death of large enemies. Ordinary hits and contact damage give no shake.

const KIND_BRUTE := 1
const KIND_BOSS := 3

## Shake amplitude per event. main.gd decays it and world_3d.gd applies it to the camera.
const SHAKE := {
	"player_shot": 1.6,
	"brute_death": 1.5,
	"boss_slam": 3.0,
	"boss_death": 4.5,
}

## Hit-stop length in seconds of real time per event.
const HITSTOP := {
	"boss_hit": 0.035,
	"brute_death": 0.05,
	"boss_death": 0.12,
}

## Minimum real-time gap between two hit-stops of the same kind. A minigun hits the
## boss many times per second, so boss hits must not freeze the game continuously.
const HITSTOP_MIN_GAP := {
	"boss_hit": 0.45,
	"brute_death": 0.15,
	"boss_death": 0.0,
}
const HITSTOP_GLOBAL_GAP := 0.12
const HITSTOP_SCALE := 0.05
const HITSTOP_MAX := 0.15

var _last_any := -100.0
var _last_by_event := {}

## Returns {"shake": float, "hitstop": float} for an event at real time `now` (seconds).
## When the player turned the setting off, both values are zero.
func event(event_name: String, now: float, enabled: bool) -> Dictionary:
	if not enabled:
		return {"shake": 0.0, "hitstop": 0.0}
	var shake: float = SHAKE.get(event_name, 0.0)
	var hitstop: float = minf(HITSTOP.get(event_name, 0.0), HITSTOP_MAX)
	if hitstop > 0.0:
		var gap: float = HITSTOP_MIN_GAP.get(event_name, HITSTOP_GLOBAL_GAP)
		var last_same: float = _last_by_event.get(event_name, -100.0)
		var blocked := now - last_same < gap or (event_name != "boss_death" and now - _last_any < HITSTOP_GLOBAL_GAP)
		if blocked:
			hitstop = 0.0
		else:
			_last_by_event[event_name] = now
			_last_any = now
	return {"shake": shake, "hitstop": hitstop}
