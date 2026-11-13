extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	for prop_name in ArenaProps.PROPS:
		var packed := ArenaProps.scene(prop_name)
		assert(packed != null, "missing prop " + prop_name)
		var info := ArenaProps.extract_mesh_info(packed)
		assert(info["mesh"] != null, "missing mesh in " + prop_name)

	var holder := Node3D.new()
	root.add_child(holder)
	var placed_a := ArenaProps.build(holder)
	var counts_a := ArenaProps.get_last_counts()
	var root_a := holder.get_node("ArenaProps")

	var holder_b := Node3D.new()
	root.add_child(holder_b)
	var placed_b := ArenaProps.build(holder_b)
	var counts_b := ArenaProps.get_last_counts()
	var root_b := holder_b.get_node("ArenaProps")

	assert(placed_a >= 60, "too few props: %d" % placed_a)
	assert(placed_a == placed_b, "non-deterministic prop count: %d vs %d" % [placed_a, placed_b])
	assert(counts_a["multimesh_nodes"] == root_a.get_child_count())
	assert(counts_a["by_type"] == counts_b["by_type"])

	var checked := 0
	for i in range(root_a.get_child_count()):
		var mmi_a := root_a.get_child(i) as MultiMeshInstance3D
		var mmi_b := root_b.get_child(i) as MultiMeshInstance3D
		assert(mmi_a != null and mmi_b != null)
		assert(mmi_a.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var mm_a := mmi_a.multimesh
		var mm_b := mmi_b.multimesh
		assert(mm_a.instance_count == mm_b.instance_count)
		var xs_a: Array = mmi_a.get_meta("instance_transforms")
		var xs_b: Array = mmi_b.get_meta("instance_transforms")
		assert(xs_a.size() == mm_a.instance_count and xs_b.size() == mm_b.instance_count)
		for idx in range(mm_a.instance_count):
			var xa: Transform3D = xs_a[idx]
			var xb: Transform3D = xs_b[idx]
			assert(xa.is_equal_approx(xb), "non-deterministic transform at %s[%d]" % [mmi_a.name, idx])
			var p: Vector3 = xa.origin
			assert(absf(p.x) <= 36.5 and absf(p.z) <= 24.5, "prop outside arena: %s" % p)
			assert(absf(p.x) >= 31.0 or absf(p.z) >= 19.5, "prop inside playfield: %s" % p)
			checked += 1

	assert(checked == placed_a)
	holder.free()
	holder_b.free()
	print("Kulissen-Tests bestanden (%d Objekte in %d MultiMeshes)" % [placed_a, counts_a["multimesh_nodes"]])
	quit(0)
