extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.updater.show_release({"tag_name": "v9.9.9", "body": "Test", "html_url": "https://github.com/Strugglechen1337/Scrapforge/releases/latest", "assets": []})
    await process_frame
    var focus := root.gui_get_focus_owner()
    assert(focus is Button and focus.text == "Herunterladen")
    game.updater.close()
    await process_frame
    assert(root.gui_get_focus_owner() is Button)
    game.queue_free()
    root.get_node("AudioManager").stop_all()
    await create_timer(1.0).timeout
    print("Update-Dialog-Tests bestanden")
    quit()
