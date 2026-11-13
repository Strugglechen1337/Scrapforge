extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	assert(ArenaAtmosphere.build(holder, true) == null)
	assert(holder.get_child_count() == 0)
	var scenery := ArenaAtmosphere.build(holder, false)
	var lights := 0
	var fires := 0
	var halls := 0
	var warnings := 0
	for child in scenery.get_children():
		if child.name.begins_with("FireSource"):
			fires += 1
			assert(child.has_node("Barrel") and child.has_node("Flame") and child.has_node("Smoke") and child.has_node("Sparks"))
		if child.name.begins_with("HallSource") or child.name.begins_with("WarningSource"):
			assert(child.has_node("Housing") and child.has_node("Lens"))
			var lens := child.get_node("Lens") as MeshInstance3D
			assert((lens.material_override as StandardMaterial3D).emission_enabled)
			if child.name.begins_with("HallSource"):
				halls += 1
				assert(child.has_node("LightHint"))
			else:
				warnings += 1
		if child.has_node("SourceLight"):
			var lamp := child.get_node("SourceLight") as OmniLight3D
			assert(not lamp.shadow_enabled)
			assert(child.has_node("Lens") or child.has_node("Flame"))
			assert(absf(child.position.x) <= 36 and absf(child.position.z) <= 24)
			lights += 1
	assert(lights == 6 and fires == 2 and halls == 2 and warnings == 2)
	assert(count_lights(scenery) == 6)
	assert(scenery.has_node("DistantHall") and scenery.has_node("DistantPiers") and scenery.has_node("CraneRails") and scenery.has_node("DistantMarkers"))
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(src.contains("player.clamp(Vector2(-1800, -1200), Vector2(1800, 1200))"))
	holder.free()
	print("Arena atmosphere tests passed: %d lights, %d fires" % [lights, fires])
	quit(0)

func count_lights(node: Node) -> int:
	var total := 1 if node is Light3D else 0
	for child in node.get_children():
		total += count_lights(child)
	return total
