class_name ArenaBoundary
extends RefCounted
## Builds the physical industrial arena boundary (walls, piers, chainlink fences,
## concrete barriers, and wall-mounted pipes) using MultiMeshInstance3D.
## Replaces the old BoxMesh walls and glowing boundary strips on PC.

const POLYHAVEN_DIR := "res://assets/third_party/polyhaven/"
const SKETCHFAB_DIR := "res://assets/third_party/sketchfab/props/"

const MODULE_PATHS := {
	"wall_panel": POLYHAVEN_DIR + "modular_factory_facade/wall_panel.glb",
	"wall_bay": POLYHAVEN_DIR + "modular_factory_facade/wall_bay.glb",
	"wall_pier": POLYHAVEN_DIR + "modular_factory_facade/wall_pier.glb",
	"fence_panel": POLYHAVEN_DIR + "modular_chainlink_fence/fence_panel.glb",
	"fence_post": POLYHAVEN_DIR + "modular_chainlink_fence/fence_post.glb",
	"concrete_barrier": POLYHAVEN_DIR + "concrete_road_barrier_02/concrete_barrier.glb",
	"wall_pipe": SKETCHFAB_DIR + "pipe_straight.glb",
}

static var _scenes: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _last_counts: Dictionary = {}


static func scene(mod_name: String) -> PackedScene:
	if not _scenes.has(mod_name):
		_scenes[mod_name] = load(MODULE_PATHS[mod_name])
	return _scenes[mod_name]


static func _mesh_info(mod_name: String) -> Dictionary:
	if not _mesh_cache.has(mod_name):
		_mesh_cache[mod_name] = ArenaProps.extract_mesh_info(scene(mod_name))
	return _mesh_cache[mod_name]


static func _add(buckets: Dictionary, mod_name: String, pos: Vector3, yaw: float) -> void:
	if not buckets.has(mod_name):
		var arr: Array[Transform3D] = []
		buckets[mod_name] = arr
	buckets[mod_name].append(Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos))


static func build(parent: Node3D, half_x := 36.0, half_z := 24.0) -> Node3D:
	var root := Node3D.new()
	root.name = "ArenaBoundary"
	parent.add_child(root)
	var buckets: Dictionary = {}
	var bx := half_x + 0.6
	var bz := half_z + 0.6

	# North wall (z = -bz, facing +Z): alternating 3m wall panels and 6m bay doors with piers.
	var x := -half_x
	var idx := 0
	while x < half_x - 0.1:
		_add(buckets, "wall_pier", Vector3(x, 0.0, -bz), 0.0)
		if idx % 3 == 1 and x + 6.0 <= half_x + 0.1:
			_add(buckets, "wall_bay", Vector3(x + 3.0, 0.0, -bz), 0.0)
			x += 6.0
		else:
			_add(buckets, "wall_panel", Vector3(x + 1.5, 0.0, -bz), 0.0)
			x += 3.0
		idx += 1
	_add(buckets, "wall_pier", Vector3(half_x, 0.0, -bz), 0.0)
	var npx := -half_x + 1.8
	while npx < half_x - 1.5:
		_add(buckets, "wall_pipe", Vector3(npx, 2.75, -bz + 0.18), PI * 0.5)
		npx += 3.55

	# West (x = -bx) and East (x = +bx) walls: solid industrial wall on north/mid,
	# transitioning to low chainlink fence + concrete barriers toward the south camera side.
	for side: float in [-1.0, 1.0]:
		var wx := side * bx
		var yaw := -PI * 0.5 if side > 0.0 else PI * 0.5
		var z := -half_z
		while z < 9.0 - 0.1:
			_add(buckets, "wall_pier", Vector3(wx, 0.0, z), yaw)
			_add(buckets, "wall_panel", Vector3(wx, 0.0, z + 1.5), yaw)
			z += 3.0
		_add(buckets, "wall_pier", Vector3(wx, 0.0, z), yaw)
		while z < half_z - 0.1:
			_add(buckets, "fence_post", Vector3(wx, 0.0, z), yaw)
			_add(buckets, "fence_panel", Vector3(wx, 0.0, z + 1.0), yaw)
			z += 2.0
		_add(buckets, "fence_post", Vector3(wx, 0.0, half_z), yaw)
		for bz_bar in [-18.0, -6.0, 6.0, 16.0]:
			_add(buckets, "concrete_barrier", Vector3(wx - side * 0.5, 0.0, bz_bar), yaw)
		var wpz := -half_z + 1.8
		while wpz < 8.0:
			_add(buckets, "wall_pipe", Vector3(wx - side * 0.18, 2.75, wpz), 0.0)
			wpz += 3.55

	# South boundary (z = +bz, toward camera): low chainlink fence + concrete barriers.
	var sx := -half_x
	while sx < half_x - 0.1:
		_add(buckets, "fence_post", Vector3(sx, 0.0, bz), 0.0)
		_add(buckets, "fence_panel", Vector3(sx + 1.0, 0.0, bz), 0.0)
		sx += 2.0
	_add(buckets, "fence_post", Vector3(half_x, 0.0, bz), 0.0)
	for bx_bar in range(-32, 33, 8):
		_add(buckets, "concrete_barrier", Vector3(float(bx_bar), 0.0, bz - 0.45), 0.0)

	var total := 0
	var by_type: Dictionary = {}
	for mod_name in MODULE_PATHS.keys():
		if buckets.has(mod_name):
			var list: Array[Transform3D] = buckets[mod_name]
			ArenaProps._build_multimesh_node(root, mod_name.capitalize().replace(" ", "") + "MultiMesh",
				_mesh_info(mod_name), list)
			by_type[mod_name] = list.size()
			total += list.size()
	_last_counts = {"total": total, "multimesh_nodes": root.get_child_count(), "by_type": by_type}
	return root


static func get_last_counts() -> Dictionary:
	return _last_counts.duplicate(true)
