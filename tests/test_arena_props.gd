extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	for prop_name in ArenaProps.PROPS:
		var packed := ArenaProps.scene(prop_name)
		assert(packed != null, "missing prop " + prop_name)
		var node := packed.instantiate()
		assert(node is Node3D)
		node.free()
	var holder := Node3D.new()
	root.add_child(holder)
	var placed := ArenaProps.build(holder)
	assert(placed >= 60, "too few props: %d" % placed)
	var props_root := holder.get_node("ArenaProps")
	assert(props_root.get_child_count() == placed)
	for child in props_root.get_children():
		var p: Vector3 = child.position
		assert(absf(p.x) <= 36.5 and absf(p.z) <= 24.5, "prop outside arena: %s" % p)
	holder.queue_free()
	print("Kulissen-Tests bestanden (%d Objekte)" % placed)
	quit(0)
