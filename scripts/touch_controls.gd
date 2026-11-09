extends Control
class_name TouchControls

const RADIUS := 80.0
var game: Node
var active_id := -1
var origin := Vector2.ZERO
var direction := Vector2.ZERO

static func direction_for(displacement: Vector2, radius: float = RADIUS) -> Vector2:
    if radius <= 0: return Vector2.ZERO
    return displacement.limit_length(radius) / radius

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for action in ["touch_left", "touch_right", "touch_up", "touch_down"]:
        if not InputMap.has_action(action): InputMap.add_action(action)
    queue_redraw()

func set_direction(value: Vector2) -> void:
    direction = value
    for entry in [["touch_left", -value.x], ["touch_right", value.x], ["touch_up", -value.y], ["touch_down", value.y]]:
        if entry[1] > 0: Input.action_press(entry[0], entry[1])
        else: Input.action_release(entry[0])
    queue_redraw()

func cancel() -> void:
    active_id = -1
    set_direction(Vector2.ZERO)

func _input(event: InputEvent) -> void:
    if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if event is InputEventJoypadMotion and absf(event.axis_value) < 0.2: return
        cancel()
        return
    if not game or game.mode != "playing" or (game.updater and is_instance_valid(game.updater.overlay)):
        if active_id != -1: cancel()
        return
    if event is InputEventScreenTouch:
        if event.pressed and active_id == -1 and event.position.x < size.x * 0.5:
            active_id = event.index
            var safe := DisplayServer.get_display_safe_area()
            var window_size := Vector2(DisplayServer.window_get_size())
            if window_size.x <= 0 or window_size.y <= 0: window_size = size
            var safe_min := Vector2(safe.position) * size / window_size
            var safe_max := Vector2(safe.end) * size / window_size
            if safe.size == Vector2i.ZERO: safe_min = Vector2.ZERO; safe_max = size
            origin = event.position.clamp(safe_min + Vector2.ONE * RADIUS, safe_max - Vector2.ONE * RADIUS)
            set_direction(Vector2.ZERO)
        elif not event.pressed and event.index == active_id: cancel()
    elif event is InputEventScreenDrag and event.index == active_id:
        set_direction(direction_for(event.position - origin))

func _process(_delta: float) -> void:
    if active_id != -1 and game and (game.mode != "playing" or (game.updater and is_instance_valid(game.updater.overlay))): cancel()

func _draw() -> void:
    if active_id == -1: return
    draw_circle(origin, RADIUS, Color(0.02, 0.08, 0.12, 0.55))
    draw_arc(origin, RADIUS, 0, TAU, 64, Color(0.27, 0.96, 0.94, 0.75), 3)
    draw_circle(origin + direction * RADIUS, 24, Color(0.27, 0.96, 0.94, 0.45))
