class_name ArenaProps
extends RefCounted
## Places weathered industrial scenery props (CC BY 4.0 & CC0, see CREDITS.md)
## around the arena perimeter and corners using MultiMeshInstance3D.
## Props are pure decoration: gameplay collision is handled in 2D by main.gd.

const SKETCHFAB_DIR := "res://assets/third_party/sketchfab/props/"
const POLYHAVEN_DIR := "res://assets/third_party/polyhaven/"

const PROP_PATHS := {
	"crate_basic": SKETCHFAB_DIR + "crate_basic.glb",
	"crate_scifi": SKETCHFAB_DIR + "crate_scifi.glb",
	"crate_cargo": SKETCHFAB_DIR + "crate_cargo.glb",
	"crate_v2": SKETCHFAB_DIR + "crate_v2.glb",
	"barrel": SKETCHFAB_DIR + "barrel.glb",
	"container": SKETCHFAB_DIR + "container.glb",
	"pipe_straight": SKETCHFAB_DIR + "pipe_straight.glb",
	"pipe_cluster": SKETCHFAB_DIR + "pipe_cluster.glb",
	"pipe_bent": SKETCHFAB_DIR + "pipe_bent.glb",
	"old_tyre": POLYHAVEN_DIR + "old_tyre/old_tyre.glb",
	"rusted_wheel_rim": POLYHAVEN_DIR + "rusted_wheel_rim_01/rusted_wheel_rim.glb",
	"old_compressor": POLYHAVEN_DIR + "old_military_compressor/old_compressor.glb",
}
const PROPS := [
	"crate_basic", "crate_scifi", "crate_cargo", "crate_v2",
	"barrel", "container", "pipe_straight", "pipe_cluster",
	"pipe_bent", "old_tyre", "rusted_wheel_rim", "old_compressor",
]
const STACK_TOP := {"crate_cargo": 1.92, "crate_v2": 1.52, "crate_basic": 0.93}

static var _scenes: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _last_counts: Dictionary = {}


static func scene(prop_name: String) -> PackedScene:
	if not _scenes.has(prop_name):
		_scenes[prop_name] = load(PROP_PATHS[prop_name])
	return _scenes[prop_name]


static func extract_mesh_info(packed: PackedScene) -> Dictionary:
	var inst := packed.instantiate() as Node3D
	var mesh_inst := _find_first_mesh(inst)
	var info := {"mesh": null, "transform": Transform3D.IDENTITY}
	if mesh_inst != null:
		info["mesh"] = mesh_inst.mesh
		info["transform"] = _relative_transform(inst, mesh_inst)
	inst.free()
	return info


static func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


static func _relative_transform(ancestor: Node3D, target: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cur: Node = target
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xform = (cur as Node3D).transform * xform
		cur = cur.get_parent()
	return xform


static func _mesh_info(prop_name: String) -> Dictionary:
	if not _mesh_cache.has(prop_name):
		_mesh_cache[prop_name] = extract_mesh_info(scene(prop_name))
	return _mesh_cache[prop_name]


static func create_multimesh(parent: Node3D, node_name: String, packed: PackedScene,
		transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var info := extract_mesh_info(packed)
	return _build_multimesh_node(parent, node_name, info, transforms)


static func _build_multimesh_node(parent: Node3D, node_name: String, info: Dictionary,
		transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	if transforms.is_empty() or info["mesh"] == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = info["mesh"]
	mm.instance_count = transforms.size()
	var local_xform: Transform3D = info["transform"]
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i] * local_xform)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta("instance_transforms", transforms)
	parent.add_child(mmi)
	return mmi


static func _add_instance(buckets: Dictionary, prop_name: String, pos: Vector3,
		yaw: float, tilt_x := 0.0, tilt_z := 0.0, scale := 1.0) -> void:
	if not buckets.has(prop_name):
		var arr: Array[Transform3D] = []
		buckets[prop_name] = arr
	var basis := Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3.ONE * scale)
	buckets[prop_name].append(Transform3D(basis, pos))


## Builds perimeter container rows, crate stacks, pipe runs, and corner scrap heaps.
## Keeps the interior playfield clear so nothing obscures player, enemies, or projectiles.
static func build(parent: Node3D, half_x := 36.0, half_z := 24.0, seed_value := 4711) -> int:
	var root := Node3D.new()
	root.name = "ArenaProps"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buckets: Dictionary = {}

	# North wall: container/crate groups, stacks, and pipe runs.
	var nx := -half_x + 5.0
	while nx < half_x - 4.5:
		var pick: String = ["crate_cargo", "crate_v2", "crate_scifi", "container", "crate_basic"][rng.randi() % 5]
		var nz := -half_z + rng.randf_range(0.8, 1.5)
		var yaw := rng.randf_range(-0.18, 0.18) + (PI * 0.5) * float(rng.randi() % 4)
		_add_instance(buckets, pick, Vector3(nx, 0.0, nz), yaw)
		if STACK_TOP.has(pick) and rng.randf() < 0.45:
			var top: String = ["crate_basic", "crate_v2", "barrel"][rng.randi() % 3]
			_add_instance(buckets, top, Vector3(nx, STACK_TOP[pick], nz), rng.randf_range(-0.4, 0.4))
		if rng.randf() < 0.55:
			_add_instance(buckets, "barrel", Vector3(nx + rng.randf_range(1.2, 1.8), 0.0, nz + 0.35), rng.randf_range(0, TAU))
		nx += rng.randf_range(3.2, 4.6)

	for px in range(-28, 29, 8):
		_add_instance(buckets, "pipe_straight", Vector3(float(px), 0.25, -half_z + 0.35), PI * 0.5)
		if px % 16 == 0:
			_add_instance(buckets, "pipe_cluster", Vector3(float(px) + 2.2, 0.0, -half_z + 0.65), 0.0)

	# South edge (toward camera): low props only so they never obscure the playfield.
	var sx := -half_x + 6.0
	while sx < half_x - 5.5:
		var spick: String = ["barrel", "old_tyre", "crate_basic", "rusted_wheel_rim"][rng.randi() % 4]
		var sz := half_z - rng.randf_range(0.7, 1.2)
		_add_instance(buckets, spick, Vector3(sx, 0.0, sz), rng.randf_range(0, TAU))
		sx += rng.randf_range(3.8, 5.4)

	# West and East walls: crates, barrels, compressors, and pipe runs.
	for side_x: float in [-half_x, half_x]:
		var inward := -signf(side_x)
		var wz := -half_z + 5.5
		while wz < half_z - 5.0:
			var wpick: String = ["crate_v2", "crate_scifi", "container", "barrel", "old_compressor"][rng.randi() % 5]
			var wx := side_x + inward * rng.randf_range(0.85, 1.55)
			var wyaw := (PI * 0.5 if inward < 0 else -PI * 0.5) + rng.randf_range(-0.2, 0.2)
			_add_instance(buckets, wpick, Vector3(wx, 0.0, wz), wyaw)
			if STACK_TOP.has(wpick) and rng.randf() < 0.35:
				_add_instance(buckets, "crate_basic", Vector3(wx, STACK_TOP[wpick], wz), rng.randf_range(-0.5, 0.5))
			wz += rng.randf_range(3.4, 4.8)
		for pz in range(-16, 17, 8):
			_add_instance(buckets, "pipe_straight", Vector3(side_x + inward * 0.35, 0.25, float(pz)), 0.0)

	# 4 Corner scrap heaps & wrecks.
	for cx in [-half_x + 2.4, half_x - 2.4]:
		for cz in [-half_z + 2.0, half_z - 2.0]:
			_add_scrap_heap(buckets, rng, Vector3(cx, 0.0, cz), signf(-cx), signf(-cz))

	var total := 0
	var by_type: Dictionary = {}
	for prop_name in PROPS:
		if buckets.has(prop_name):
			var list: Array[Transform3D] = buckets[prop_name]
			_build_multimesh_node(root, prop_name.capitalize().replace(" ", "") + "MultiMesh",
				_mesh_info(prop_name), list)
			by_type[prop_name] = list.size()
			total += list.size()
	_last_counts = {"total": total, "multimesh_nodes": root.get_child_count(), "by_type": by_type}
	return total


static func _add_scrap_heap(buckets: Dictionary, rng: RandomNumberGenerator,
		corner: Vector3, in_x: float, in_z: float) -> void:
	_add_instance(buckets, "old_compressor", corner, rng.randf_range(-0.4, 0.4) + (PI * 0.35 if in_x < 0 else -PI * 0.35))
	_add_instance(buckets, "pipe_bent", corner + Vector3(in_x * 1.4, 0.0, in_z * 0.4), rng.randf_range(0, TAU))
	for i in range(3):
		var off := Vector3(in_x * rng.randf_range(0.3, 2.0), 0.0, in_z * rng.randf_range(0.2, 1.5))
		_add_instance(buckets, "old_tyre", corner + off, rng.randf_range(0, TAU),
			rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
	for i in range(2):
		var off2 := Vector3(in_x * rng.randf_range(0.2, 1.8), 0.12, in_z * rng.randf_range(0.3, 1.6))
		_add_instance(buckets, "rusted_wheel_rim", corner + off2, rng.randf_range(0, TAU),
			rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
	_add_instance(buckets, "barrel", corner + Vector3(in_x * 0.6, 0.32, in_z * 1.5),
		rng.randf_range(0, TAU), PI * 0.48, rng.randf_range(-0.2, 0.2))


static func get_last_counts() -> Dictionary:
	return _last_counts.duplicate(true)
