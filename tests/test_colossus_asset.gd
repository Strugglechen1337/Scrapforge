extends SceneTree

func _initialize() -> void:
    var scene := load("res://assets/third_party/sketchfab/colossus/colossus-static.glb") as PackedScene
    if scene == null:
        push_error("Colossus GLB did not load as a PackedScene")
        quit(1)
        return
    var instance := scene.instantiate()
    if instance == null:
        push_error("Colossus GLB did not instantiate")
        quit(1)
        return
    instance.free()
    print("Colossus GLB load test passed")
    quit(0)
