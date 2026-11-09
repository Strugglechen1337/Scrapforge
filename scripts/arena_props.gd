class_name ArenaProps
extends RefCounted
## Places the Sketchfab scenery props (CC BY 4.0, see CREDITS.md) around the arena.
## Props are pure decoration: gameplay collision is handled in 2D by main.gd.

const PROP_DIR := "res://assets/third_party/sketchfab/props/"
const PROPS := ["crate_basic", "crate_scifi", "crate_cargo", "crate_v2", "barrel", "container"]
## Props that are stable enough to carry a second prop on top.
const STACK_BASE := ["crate_cargo", "crate_v2", "crate_basic"]
const STACK_TOP := {"crate_cargo": 1.92, "crate_v2": 1.52, "crate_basic": 0.93}

static var _scenes: Dictionary = {}

static func scene(prop_name: String) -> PackedScene:
	if not _scenes.has(prop_name):
		_scenes[prop_name] = load(PROP_DIR + prop_name + ".glb")
	return _scenes[prop_name]

static func spawn(parent: Node3D, prop_name: String, pos: Vector3, yaw: float, scale := 1.0) -> Node3D:
	var prop := scene(prop_name).instantiate() as Node3D
	prop.name = prop_name.capitalize().replace(" ", "")
	prop.position = pos
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * scale
	parent.add_child(prop)
	_tune_for_performance(prop)
	return prop

## Decoration only: no shadow casting and a visibility range keep the shadow pass and draw calls small.
static func _tune_for_performance(node: Node) -> void:
	if node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geo.visibility_range_end = 45.0
	for child in node.get_children():
		_tune_for_performance(child)

## Builds wall rows, corner stacks and salvage clusters. Returns the number of props placed.
static func build(parent: Node3D, half_x := 36.0, half_z := 24.0, seed_value := 4711) -> int:
	var root := Node3D.new()
	root.name = "ArenaProps"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := 0
	# Rows along the long walls.
	for z in [-half_z, half_z]:
		var x := -half_x + 1.5
		while x < half_x - 1.0:
			count += _place_slot(root, rng, Vector3(x, 0, z - signf(z) * rng.randf_range(0.6, 1.4)))
			x += rng.randf_range(2.2, 3.4)
	# Rows along the short walls.
	for x2 in [-half_x, half_x]:
		var z2 := -half_z + 3.0
		while z2 < half_z - 2.5:
			count += _place_slot(root, rng, Vector3(x2 - signf(x2) * rng.randf_range(0.6, 1.4), 0, z2))
			z2 += rng.randf_range(2.4, 3.6)
	# Salvage clusters that frame the play area (replace the old box barriers).
	for z3 in [-10.0, 10.0]:
		for cx in [-14.0, 12.0]:
			var center := Vector3(cx, 0, z3)
			count += _cluster(root, rng, center)
	return count

static func _place_slot(root: Node3D, rng: RandomNumberGenerator, pos: Vector3) -> int:
	var pick: String = PROPS[rng.randi() % PROPS.size()]
	spawn(root, pick, pos, rng.randf_range(-0.35, 0.35) + (PI / 2.0) * float(rng.randi() % 4))
	var placed := 1
	if STACK_TOP.has(pick) and rng.randf() < 0.35:
		var top: String = ["crate_basic", "crate_v2", "barrel"][rng.randi() % 3]
		spawn(root, top, pos + Vector3(0, STACK_TOP[pick], 0), rng.randf_range(-0.6, 0.6))
		placed += 1
	return placed

static func _cluster(root: Node3D, rng: RandomNumberGenerator, center: Vector3) -> int:
	var placed := 0
	spawn(root, "crate_cargo", center, rng.randf_range(-0.3, 0.3))
	spawn(root, "crate_basic", center + Vector3(0, STACK_TOP["crate_cargo"], 0), rng.randf_range(-0.8, 0.8))
	placed += 2
	for i in range(3):
		var offset := Vector3(rng.randf_range(-2.6, 2.6), 0, rng.randf_range(-1.2, 1.2))
		if offset.length() < 1.6:
			offset = offset.normalized() * 1.8
		var pick: String = ["barrel", "container", "crate_scifi", "crate_v2"][rng.randi() % 4]
		spawn(root, pick, center + offset, rng.randf_range(0, TAU))
		placed += 1
	return placed
