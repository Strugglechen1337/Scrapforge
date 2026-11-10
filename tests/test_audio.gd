extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var audio = root.get_node("AudioManager")
    for voice in audio.voices: voice.stop()
    for i in range(audio.MAX_SAME): assert(audio.play(&"minigun"))
    assert(audio.active_count(&"minigun") == audio.MAX_SAME)
    assert(not audio.play(&"minigun"))
    assert(audio.play(&"laser"))
    audio.voices[0].stop()
    assert(audio.play(&"minigun"))
    audio.play_music("menu")
    assert(audio.current_music == "menu" and audio.music[audio.music_index].stream.loop)
    audio.play_music("combat")
    assert(audio.current_music == "combat" and audio.music[audio.music_index].stream.loop)
    var original := {}
    for bus in audio.BUS_NAMES: original[bus] = audio.get_volume(bus)
    audio.set_volume("Master", 0.65, false)
    audio.set_volume("Musik", 0.25, false)
    audio.set_volume("Effekte", 0.0, false)
    var path := "user://audio-test-settings.cfg"
    var seed := ConfigFile.new()
    seed.set_value("player", "skin", "blue")
    seed.set_value("audio", "master_volume", 0.4)
    assert(seed.save(path) == OK)
    assert(audio.save_settings(path) == OK)
    var saved := ConfigFile.new()
    assert(saved.load(path) == OK)
    assert(saved.get_value("player", "skin") == "blue")
    assert(not saved.has_section_key("audio", "master_volume"))
    for bus in audio.BUS_NAMES: audio.set_volume(bus, 1.0, false)
    audio.load_settings(path)
    assert(is_equal_approx(audio.get_volume("Master"), 0.65))
    assert(is_equal_approx(audio.get_volume("Musik"), 0.25))
    assert(audio.get_volume("Effekte") == 0)
    for bus in audio.BUS_NAMES: audio.set_volume(bus, original[bus], false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    audio.stop_all()
    await create_timer(1.0).timeout
    print("Audio-Tests bestanden")
    quit()
