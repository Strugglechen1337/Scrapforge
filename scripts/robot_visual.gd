extends Node2D
class_name RobotVisual

var state: UpgradeState
var clock := 0.0
const INK = Color("0a1320")
const METAL = Color("68879a")
const LIGHT = Color("c8e3e5")
const CYAN = Color("5ffbf0")
const MAGENTA = Color("ff658e")
const GOLD = Color("ffcc72")

func _ready() -> void:
    for entry in [["left_arm",Vector2(-29,-5)],["right_arm",Vector2(29,-5)],["left_shoulder",Vector2(-27,-24)],["right_shoulder",Vector2(27,-24)],["back",Vector2.ZERO],["head",Vector2(0,-35)],["legs",Vector2(0,30)],["core",Vector2.ZERO]]:
        var marker := Marker2D.new()
        marker.name = entry[0]
        marker.position = entry[1]
        add_child(marker)

func _process(delta: float) -> void:
    clock += delta
    queue_redraw()

func lvl(id: String) -> int:
    return state.level(id) if state else 0

func plate(rect: Rect2, color: Color) -> void:
    draw_rect(rect.grow(3), INK)
    draw_rect(rect, color)

func _draw() -> void:
    var shield := lvl("shield")
    if shield:
        for ring in range(1, shield + 1):
            draw_arc(Vector2.ZERO, 54 + ring * 3, 0, TAU, 80, Color(0.25, 0.95, 1.0, 0.1 + 0.08 * ring), 2)
        draw_arc(Vector2.ZERO, 54 + shield * 3, clock * 0.3, clock * 0.3 + 1.2, 40, CYAN, 3)
    # Main chassis, legs and head.
    for side in [-1, 1]:
        plate(Rect2(Vector2(side * 19 - 8, 19), Vector2(16, 23)), METAL)
        plate(Rect2(Vector2(side * 21 - 10, 38), Vector2(20, 10)), LIGHT)
        plate(Rect2(Vector2(side * 29 - 9, -17), Vector2(18, 29)), METAL)
    plate(Rect2(-23, -25, 46, 52), METAL)
    plate(Rect2(-18, -41, 36, 20), LIGHT)
    draw_rect(Rect2(-13, -36, 26, 6), INK)
    draw_rect(Rect2(-10, -35, 20, 3), CYAN)
    var armor := lvl("armor")
    for i in range(armor):
        draw_line(Vector2(-19, -16 + i * 7), Vector2(-12, -16 + i * 7), LIGHT, 3)
        draw_line(Vector2(12, -16 + i * 7), Vector2(19, -16 + i * 7), LIGHT, 3)
    draw_circle(Vector2.ZERO, 13, INK)
    draw_circle(Vector2.ZERO, 7 + lvl("cooldown"), Color(0.22 + 0.12 * lvl("cooldown"), 1.0, 0.9))
    for i in range(lvl("magnet")):
        draw_arc(Vector2.ZERO, 17 + i * 3, -2.6, -0.5, 30, GOLD, 2)
    var laser := lvl("laser")
    if laser:
        plate(Rect2(-53, -13, 25 + laser * 3, 16), Color("35536b"))
        for i in range(laser): draw_line(Vector2(-51, -10 + i * 2.4), Vector2(-35, -10 + i * 2.4), CYAN, 2)
        draw_circle(Vector2(-54, -5), 3 + laser, CYAN)
    var minigun := lvl("minigun")
    if minigun:
        plate(Rect2(28, -13, 25 + minigun * 3, 16), Color("35536b"))
        for i in range(minigun + 1): draw_line(Vector2(37, -10 + i * 2.4), Vector2(56, -10 + i * 2.4), LIGHT, 2)
    var rockets := lvl("rocket")
    if rockets and not lvl("swarm"):
        plate(Rect2(20, -37, 20 + rockets * 3, 13), Color("526278"))
        for i in range(rockets): draw_circle(Vector2(24 + i * 5, -31), 2.5, MAGENTA)
    var radar := lvl("radar")
    if radar and not lvl("swarm"):
        draw_line(Vector2(0,-41),Vector2(0,-48-radar*2),LIGHT,2)
        for i in range(radar): draw_arc(Vector2(0,-48), 4 + i * 3, -2.8, -0.35, 20, CYAN, 1.5)
    if lvl("swarm"):
        plate(Rect2(21,-42,42,22), Color("685476"))
        for i in range(5): draw_circle(Vector2(28 + i*7,-31),3, GOLD)
        draw_arc(Vector2(42,-31), 28, clock, clock+2, 30, MAGENTA, 3)
    var saw := lvl("saw")
    if saw:
        for i in range(saw):
            var p := Vector2.from_angle(clock * 1.8 + TAU * i / saw) * 78
            draw_line(Vector2(29,-5), p, Color(0.4,0.8,0.9,0.25), 1)
            draw_circle(p, 10, GOLD)
            draw_circle(p, 5, INK)
            for tooth in range(6): draw_line(p + Vector2.from_angle(clock*4+tooth*TAU/6)*8, p + Vector2.from_angle(clock*4+tooth*TAU/6)*13, LIGHT, 2)
    var thrust := lvl("thruster")
    if thrust:
        for side in [-1,1]:
            plate(Rect2(side*21-7, 42, 14, 9), METAL)
            draw_colored_polygon(PackedVector2Array([Vector2(side*21-5,50),Vector2(side*21+5,50),Vector2(side*21,55+thrust*4+sin(clock*20)*3)]), MAGENTA)
