extends SceneTree

class MockGame extends Node:
    var mode := "playing"
    var updater: Node

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    assert(TouchControls.direction_for(Vector2.ZERO) == Vector2.ZERO)
    assert(TouchControls.direction_for(Vector2(40, 0)).is_equal_approx(Vector2(0.5, 0)))
    assert(TouchControls.direction_for(Vector2(0, -160)).is_equal_approx(Vector2(0, -1)))
    assert(is_equal_approx(TouchControls.direction_for(Vector2(100, 100)).length(), 1.0))
    assert(TouchControls.direction_for(Vector2(5, 5), 0) == Vector2.ZERO)
    var controls := TouchControls.new()
    root.add_child(controls)
    controls.set_direction(Vector2(0.5, -0.75))
    assert(is_equal_approx(Input.get_action_strength("touch_right"), 0.5))
    assert(is_equal_approx(Input.get_action_strength("touch_up"), 0.75))
    controls.cancel()
    assert(Input.get_action_strength("touch_right") == 0 and Input.get_action_strength("touch_up") == 0)
    var game := MockGame.new()
    root.add_child(game)
    controls.game = game
    controls.set_anchors_preset(Control.PRESET_TOP_LEFT)
    controls.size = Vector2(1280, 800)
    var press := InputEventScreenTouch.new()
    press.index = 3
    press.pressed = true
    press.position = Vector2(200, 400)
    controls._input(press)
    assert(controls.active_id == 3)
    var drag := InputEventScreenDrag.new()
    drag.index = 3
    drag.position = controls.origin + Vector2(40, 0)
    controls._input(drag)
    assert(is_equal_approx(Input.get_action_strength("touch_right"), 0.5))
    press.pressed = false
    controls._input(press)
    assert(controls.active_id == -1 and Input.get_action_strength("touch_right") == 0)
    game.queue_free()
    controls.queue_free()
    print("Touch-Tests bestanden")
    quit()
