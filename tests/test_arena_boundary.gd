extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	for mod_name in ArenaBoundary.MODULE_PATHS.keys():
		var packed := ArenaBoundary.scene(mod_name)
		assert(packed != null, "missing boundary module " + mod_name)
		var info := ArenaProps.extract_mesh_info(packed)
		assert(info["mesh"] != null, "missing mesh in " + mod_name)

	var holder_a := Node3D.new()
	root.add_child(holder_a)
	var bound_a := ArenaBoundary.build(holder_a)
	var counts_a := ArenaBoundary.get_last_counts()

	var holder_b := Node3D.new()
	root.add_child(holder_b)
	var bound_b := ArenaBoundary.build(holder_b)
	var counts_b := ArenaBoundary.get_last_counts()

	assert(counts_a["total"] == counts_b["total"] and counts_a["total"] > 100)
	assert(counts_a["multimesh_nodes"] == bound_a.get_child_count())
	assert(bound_a.get_child_count() == bound_b.get_child_count())

	var total_checked := 0
	for i in range(bound_a.get_child_count()):
		var mmi_a := bound_a.get_child(i) as MultiMeshInstance3D
		var mmi_b := bound_b.get_child(i) as MultiMeshInstance3D
		assert(mmi_a != null and mmi_b != null)
		assert(mmi_a.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var mm_a := mmi_a.multimesh
		var mm_b := mmi_b.multimesh
		assert(mm_a.instance_count == mm_b.instance_count)
		# Verify no emissive materials on boundary modules.
		for s in range(mm_a.mesh.get_surface_count()):
			var mat := mm_a.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				assert(not (mat as BaseMaterial3D).emission_enabled, "unexpected emission on boundary: %s" % mmi_a.name)
		var xs_a: Array = mmi_a.get_meta("instance_transforms")
		var xs_b: Array = mmi_b.get_meta("instance_transforms")
		assert(xs_a.size() == mm_a.instance_count and xs_b.size() == mm_b.instance_count)
		for idx in range(mm_a.instance_count):
			var xa: Transform3D = xs_a[idx]
			var xb: Transform3D = xs_b[idx]
			assert(xa.is_equal_approx(xb))
			var p: Vector3 = xa.origin
			assert(absf(p.x) <= 37.5 and absf(p.z) <= 25.5, "boundary outside perimeter: %s" % p)
			assert(absf(p.x) >= 35.5 or absf(p.z) >= 23.5, "boundary inside playfield: %s" % p)
			total_checked += 1

	assert(total_checked == counts_a["total"])
	# Verify mobile path and playfield clamp remain unchanged in source.
	var world_src := FileAccess.get_file_as_string("res://scripts/world_3d.gd")
	assert(world_src.contains("if OS.has_feature(\"mobile\"):"))
	assert(world_src.contains("ArenaBoundary.build(self)"))
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.contains("player.clamp(Vector2(-1800, -1200), Vector2(1800, 1200))"))

	holder_a.free()
	holder_b.free()
	print("Arena boundary tests passed (%d parts in %d MultiMeshes)" % [counts_a["total"], counts_a["multimesh_nodes"]])
	quit(0)
