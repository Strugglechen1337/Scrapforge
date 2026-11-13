extends SceneTree
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var one := ArenaFloor.build(holder, false)
	var two := ArenaFloor.build(holder, false)
	var mobile := ArenaFloor.build(holder, true)
	var floor_node := one.get_node("Floor") as MeshInstance3D
	var mat := floor_node.material_override as ShaderMaterial
	assert(mat != null and mat.shader != null)
	for param in ["metal_color", "metal_normal", "metal_rough", "concrete_color", "floor_mask"]:
		assert(mat.get_shader_parameter(param) != null, param)
	assert(ArenaFloor.MAX_DECALS <= 24)
	assert(ArenaFloor.STATIC_DECALS + ArenaFloor.RESERVED_SCORCH_DECALS <= ArenaFloor.MAX_DECALS)
	assert(one.get_child_count() == ArenaFloor.STATIC_DECALS + 1)
	for i in range(1, one.get_child_count()):
		var a := one.get_child(i) as Decal
		var b := two.get_child(i) as Decal
		assert(a != null and a.transform == b.transform and a.size == b.size)
		assert(absf(a.position.x) <= 36 and absf(a.position.z) <= 24)
		assert(a.texture_albedo != null)
		assert(a.cull_mask == floor_node.layers and a.distance_fade_enabled)
	var old := mobile.get_node("Floor") as MeshInstance3D
	assert(old.material_override is StandardMaterial3D)
	assert(mobile.get_child_count() == 76)
	for child in mobile.get_children():
		assert(not child is Decal)
	one.free()
	two.free()
	mobile.free()
	print("Arena floor tests passed: %d decals; mobile 75 stains" % ArenaFloor.STATIC_DECALS)
	quit(0)
