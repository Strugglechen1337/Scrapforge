extends Node

const MAX_SAME := 6
const MAX_VOICES := 32
const SETTINGS_PATH := "user://settings.cfg"
const SOUND_ROOT := "res://assets/third_party/kenney/sci-fi-sounds/"
const SFX_ROOT := "res://assets/audio/sfx/"
const SOUNDS := {
	&"minigun": [SFX_ROOT + "minigun_0.ogg", SFX_ROOT + "minigun_1.ogg"],
	&"rocket": [SFX_ROOT + "rocket.ogg"],
	&"explosion": [SOUND_ROOT + "explosionCrunch_000.ogg", SOUND_ROOT + "explosionCrunch_001.ogg", SOUND_ROOT + "explosionCrunch_002.ogg"],
	&"laser": [SFX_ROOT + "laser.ogg"],
	&"flame": [SFX_ROOT + "flame_loop.ogg"],
	&"plasma": [SFX_ROOT + "plasma.ogg"],
	&"turret": [SFX_ROOT + "turret.ogg"],
	&"drone": [SFX_ROOT + "drone.ogg"],
	&"mech_step": [SFX_ROOT + "mech_step_0.ogg", SFX_ROOT + "mech_step_1.ogg"],
	&"enemy_hit": [SOUND_ROOT + "impactMetal_000.ogg"],
	&"player_hit": [SOUND_ROOT + "impactMetal_001.ogg"],
	&"pickup": [SOUND_ROOT + "computerNoise_001.ogg"],
	&"level_up": [SFX_ROOT + "level_up.ogg"],
	&"upgrade": [SOUND_ROOT + "doorOpen_000.ogg"],
	&"boss": [SFX_ROOT + "boss_spawn.ogg"],
	&"victory": [SOUND_ROOT + "doorOpen_000.ogg"],
	&"game_over": [SOUND_ROOT + "doorClose_000.ogg"],
	&"menu_focus": [SOUND_ROOT + "computerNoise_000.ogg"],
	&"menu_confirm": [SOUND_ROOT + "computerNoise_001.ogg"],
}
const MAX_PER_TYPE := {
	&"minigun": 4,
	&"rocket": 4,
	&"laser": 3,
	&"plasma": 3,
	&"turret": 3,
	&"drone": 3,
	&"mech_step": 2,
	&"explosion": 3,
	&"enemy_hit": 3,
	&"player_hit": 2,
	&"pickup": 3,
}
const BUS_NAMES := ["Master", "Musik", "Effekte"]
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var music: Array[AudioStreamPlayer] = []
var current_music := ""
var music_index := 0
var music_tween: Tween
var flame_player: AudioStreamPlayer
var flame_until := 0.0
var sound_cooldowns := {}
var listener := Vector2.ZERO
var listener_set := false

func _ready() -> void:
	for bus in ["Musik", "Effekte"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	load_settings()
	for key in SOUNDS:
		var options: Array[AudioStream] = []
		for path in SOUNDS[key]:
			var stream := load(path) as AudioStream
			if stream: options.append(stream)
		streams[key] = options
	for i in range(MAX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effekte"
		add_child(voice)
		voices.append(voice)
	for i in range(2):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Musik"
		add_child(voice)
		music.append(voice)
	flame_player = AudioStreamPlayer.new()
	flame_player.bus = "Effekte"
	flame_player.volume_db = -17.0
	var flame_stream: AudioStreamOggVorbis = streams[&"flame"][0].duplicate()
	flame_stream.loop = true
	flame_player.stream = flame_stream
	add_child(flame_player)

func stop_all() -> void:
	if music_tween and music_tween.is_valid(): music_tween.kill()
	for voice in voices: voice.stop()
	for voice in music: voice.stop()
	if flame_player: flame_player.stop()
	current_music = ""

func _exit_tree() -> void:
	stop_all()
	for voice in voices:
		voice.stop()
		voice.stream = null
	for voice in music:
		voice.stop()
		voice.stream = null
	if flame_player:
		flame_player.stop()
		flame_player.stream = null
	streams.clear()

func set_volume(bus: String, value: float, persist := true) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or bus not in BUS_NAMES: return
	var volume := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume == 0.0)
	if persist: save_settings()

func get_volume(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index): return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))

func save_settings(path := SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)
	for bus in BUS_NAMES: config.set_value("audio", bus, get_volume(bus))
	for old_key in ["master_volume", "music_volume", "sfx_volume"]:
		if config.has_section_key("audio", old_key): config.erase_section_key("audio", old_key)
	return config.save(path)

func load_settings(path := SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var legacy := {"Master": "master_volume", "Musik": "music_volume", "Effekte": "sfx_volume"}
	var defaults := {"Master": 0.85, "Musik": 0.75, "Effekte": 0.85}
	for bus in BUS_NAMES:
		set_volume(bus, float(config.get_value("audio", bus, config.get_value("audio", legacy[bus], defaults[bus]))), false)

func active_count(id: StringName) -> int:
	var count := 0
	for voice in voices:
		if voice.playing and voice.get_meta("sound_id", &"") == id: count += 1
	return count

func set_listener(position: Vector2) -> void:
	listener = position
	listener_set = true

func max_voices_for(id: StringName) -> int:
	return int(MAX_PER_TYPE.get(id, MAX_SAME))

func play(id: StringName, position := Vector2.INF) -> bool:
	if not streams.has(id) or streams[id].is_empty(): return false
	if active_count(id) >= max_voices_for(id): return false
	var now := Time.get_ticks_msec()
	var cooldown := 90 if id in [&"explosion", &"enemy_hit"] else (300 if id == &"player_hit" else 0)
	if cooldown and now < int(sound_cooldowns.get(id, 0)): return false
	for voice in voices:
		if not voice.playing:
			sound_cooldowns[id] = now + cooldown
			voice.stream = streams[id].pick_random()
			voice.set_meta("sound_id", id)
			if id in [&"minigun", &"rocket", &"laser", &"plasma", &"turret", &"drone", &"mech_step"]:
				voice.pitch_scale = randf_range(0.90, 1.10)
			elif id in [&"explosion", &"enemy_hit", &"player_hit"]:
				voice.pitch_scale = randf_range(0.84, 0.96)
			else:
				voice.pitch_scale = randf_range(0.97, 1.03)
			if id in [&"minigun", &"enemy_hit", &"menu_focus", &"mech_step"]:
				voice.volume_db = -13.5
			elif id in [&"boss", &"level_up"]:
				voice.volume_db = -6.0
			else:
				voice.volume_db = -9.0
			if position.is_finite() and listener_set:
				voice.volume_db -= clampf(position.distance_to(listener) / 120.0, 0.0, 18.0)
			voice.play()
			return true
	return false

func flame_active() -> void:
	flame_until = Time.get_ticks_msec() / 1000.0 + 0.35
	if not flame_player.playing: flame_player.play()

func _process(_delta: float) -> void:
	if flame_player and flame_player.playing and Time.get_ticks_msec() / 1000.0 > flame_until:
		flame_player.stop()

func play_music(which: String) -> void:
	if which == current_music: return
	var path := "res://assets/third_party/music/" + which + ".ogg"
	if not ResourceLoader.exists(path): return
	var stream := (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	if music_tween and music_tween.is_valid(): music_tween.kill()
	var old := music[music_index]
	music_index = 1 - music_index
	var incoming := music[music_index]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	current_music = which
	music_tween = create_tween().set_parallel(true)
	music_tween.tween_property(incoming, "volume_db", -7.0, 1.0)
	music_tween.tween_property(old, "volume_db", -60.0, 1.0)
	music_tween.chain().tween_callback(old.stop)
