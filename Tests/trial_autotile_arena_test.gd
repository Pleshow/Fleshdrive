extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var original_path := "res://Scenes/placeholder_arena.tscn"
	var trial_path := "res://Scenes/trial_autotile_arena.tscn"
	_check(ResourceLoader.exists(original_path), "Original arena was preserved", failures)
	_check(ResourceLoader.exists(trial_path), "Trial autotile arena exists", failures)

	var packed := load(trial_path) as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var floor := arena.get_node("AutotileFloor") as TileMapLayer
	var details := arena.get_node("ArenaDetailTiles") as TileMapLayer
	_check(floor != null, "Floor TileMapLayer is present", failures)
	_check(details != null, "Detail TileMapLayer is present", failures)
	_check(floor.tile_set != null, "Runtime TileSet was created", failures)
	_check(floor.tile_set.tile_size == Vector2i(16, 16), "Tile size is 16x16", failures)
	_check(floor.scale == Vector2.ONE, "Tile scale is native 1x", failures)
	_check(floor.position == Vector2.ZERO, "The 2560px tile grid needs no offset", failures)
	_check(floor.get_used_rect().size == Vector2i(158, 86), "Walkable floor grid is 158x86 inside the walls", failures)
	_check(floor.get_cell_source_id(Vector2i(0, 8)) == -1, "No floor tile leaks under the left wall", failures)
	_check(floor.get_cell_source_id(Vector2i(159, 8)) == -1, "No floor tile leaks under the right wall", failures)
	_check(floor.get_cell_source_id(Vector2i(12, 0)) == -1, "No floor tile leaks under the top wall", failures)
	_check(floor.get_cell_source_id(Vector2i(12, 89)) == -1, "No floor tile leaks under the bottom wall", failures)
	_check(arena.has_node("Walls"), "Gameplay boundary collisions remain active", failures)
	if not failures.is_empty():
		for failure in failures:
			push_error("Trial autotile arena test failed: " + failure)
		quit(1)
		return
	print("TRIAL AUTOTILE ARENA TEST PASSED")
	quit(0)


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
