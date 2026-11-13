extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var directory := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			directory = arg.trim_prefix("--shot-dir=")
	if directory.is_empty():
		push_error("--shot-dir is required")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	ScrapEnvironment3D.build(world, false, "hoch")
	ArenaFloor.build(world, false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 40
	var second := "--second" in OS.get_cmdline_user_args()
	var center := Vector3(9, 0, 5) if second else Vector3(-7, 0, -5)
	camera.position = center + Vector3(2.0, 7.0, 4.0)
	camera.look_at(center)
	camera.current = true
	for i in range(50):
		await process_frame
	await RenderingServer.frame_post_draw
	var filename := "boden-nah-2.png" if second else "boden-nah-1.png"
	var result := root.get_texture().get_image().save_png(directory.path_join(filename))
	quit(0 if result == OK else 1)
