extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_scene := load("res://Scenes/game.tscn") as PackedScene
	_check(game_scene != null, "Game scene loads with the new arena")
	if game_scene == null:
		_finish()
		return

	var game := game_scene.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	game.get_node("UI/HUD").complete_onboarding()
	await process_frame

	var arena := game.get_node_or_null("Arena") as PlaceholderArena
	var walls := game.get_node_or_null("Arena/Walls")
	var obstacles := game.get_node_or_null("Arena/Obstacles")
	var decorations := game.get_node_or_null("Arena/GroundDecorations")
	var stations := game.get_node_or_null("Arena/LabStations")
	var boundary_visuals := game.get_node_or_null("Arena/BoundaryVisuals")
	var lights := game.get_node_or_null("Arena/LaboratoryLights")
	var atmosphere := (
		game.get_node_or_null("Arena/Atmosphere") as CPUParticles2D
	)
	var background := game.get_node_or_null("Arena/ArenaFloor") as TextureRect

	_check(arena != null, "Arena instance exists")
	_check(
		game.y_sort_enabled
		and arena != null
		and arena.y_sort_enabled
		and obstacles != null
		and obstacles.y_sort_enabled,
		"World, entities and laboratory props share Y-based depth sorting"
	)
	_check(
		background != null
		and background.texture.resource_path
		== "res://Assets/environment/lab/lab_floor_tile.png",
		"Generated laboratory tileset is used as the arena floor"
	)
	_check(
		background != null
		and background.stretch_mode == TextureRect.STRETCH_TILE
		and background.texture_repeat
		== CanvasItem.TEXTURE_REPEAT_ENABLED,
		"Laboratory floor repeats as a crisp seamless tile"
	)
	if background != null:
		var floor_image := background.texture.get_image()
		var floor_edges_are_seamless := true
		for y in range(floor_image.get_height()):
			if (
				floor_image.get_pixel(0, y)
				!= floor_image.get_pixel(floor_image.get_width() - 1, y)
			):
				floor_edges_are_seamless = false
				break
		if floor_edges_are_seamless:
			for x in range(floor_image.get_width()):
				if (
					floor_image.get_pixel(x, 0)
					!= floor_image.get_pixel(
						x,
						floor_image.get_height() - 1
					)
				):
					floor_edges_are_seamless = false
					break
		_check(
			floor_edges_are_seamless,
			"Large laboratory floor panels have pixel-perfect seamless edges"
		)
	_check(walls != null and walls.get_child_count() == 4, "Arena has four solid boundary walls")
	_check(obstacles != null and obstacles.get_child_count() == 8, "Arena has eight laboratory collision obstacles")
	_check(
		decorations != null and decorations.get_child_count() == 10,
		"Ground details are limited to deliberate laboratory clusters"
	)
	_check(
		stations != null and stations.get_child_count() == 4,
		"Props are grouped on four functional laboratory service pads"
	)
	_check(boundary_visuals != null and boundary_visuals.get_child_count() >= 50, "Modular laboratory walls surround the arena")
	_check(lights != null and lights.get_child_count() >= 8, "Arena has local cyan and emergency lighting")
	if lights != null:
		var specimen_light := (
			lights.get_node_or_null("LabLight02") as PointLight2D
		)
		var specimen_glow := (
			lights.get_node_or_null("ElectricalGlow02") as Sprite2D
		)
		_check(
			specimen_light != null
			and specimen_light.energy >= 1.3
			and specimen_glow != null
			and specimen_glow.material is CanvasItemMaterial
			and (
				specimen_glow.material as CanvasItemMaterial
			).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"Specimen tanks and powered props cast an additive cyan glow"
		)
	_check(
		atmosphere != null
		and atmosphere.amount >= 64
		and atmosphere.texture != null,
		"Arena has a subtle airborne atmosphere layer"
	)
	if walls != null:
		var left_wall := walls.get_node("Left") as CollisionShape2D
		var left_shape := left_wall.shape as RectangleShape2D
		var left_inner_edge := left_wall.position.x + left_shape.size.x * 0.5
		_check(
			left_inner_edge >= 54.0 and left_inner_edge <= 58.0,
			"Low-profile bulkhead collision aligns with its visible inner edge"
		)
		var bottom_wall := walls.get_node("Bottom") as CollisionShape2D
		var bottom_shape := bottom_wall.shape as RectangleShape2D
		var bottom_inner_edge := (
			bottom_wall.position.y - bottom_shape.size.y * 0.5
		)
		_check(
			is_equal_approx(bottom_inner_edge, 1320.0),
			"Bottom wall is inset into the camera view with matching collision"
		)
	if boundary_visuals != null and boundary_visuals.get_child_count() > 0:
		var wall_visual := boundary_visuals.get_child(0) as Sprite2D
		_check(
			wall_visual != null and wall_visual.scale.x <= 0.35,
			"Boundary wall art stays low enough to preserve arena visibility"
		)

	if obstacles != null and obstacles.get_child_count() > 0:
		var test_obstacle := obstacles.get_child(0) as StaticBody2D
		var obstacle_visual := (
			test_obstacle.get_node("Visual") as Sprite2D
		)
		var footprint_collision := (
			test_obstacle.get_node("FootprintCollision")
			as CollisionShape2D
		)
		var footprint_shape := (
			footprint_collision.shape as RectangleShape2D
		)
		_check(
			obstacle_visual.position.y < -30.0
			and footprint_collision.position == Vector2.ZERO
			and footprint_shape.size.y <= 60.0,
			"Tall props extend upward from a compact ground footprint"
		)
		_check(
			obstacle_visual.modulate.b > obstacle_visual.modulate.r
			and obstacle_visual.modulate.a < 1.0,
			"Prop palette is graded into the cool laboratory floor"
		)

		var player_node := get_first_node_in_group("player") as Node2D
		if player_node != null:
			player_node.global_position = (
				test_obstacle.global_position + Vector2(0.0, -80.0)
			)
			arena._update_obstacle_occlusion(1.0)
			_check(
				obstacle_visual.self_modulate.a < 0.5,
				"Prop becomes translucent while Koda passes behind it"
			)
			player_node.global_position = (
				test_obstacle.global_position + Vector2(0.0, 80.0)
			)
			arena._update_obstacle_occlusion(1.0)
			_check(
				is_equal_approx(
					obstacle_visual.self_modulate.a,
					1.0
				),
				"Prop returns to full opacity when it no longer covers Koda"
			)
			var test_enemy := Node2D.new()
			test_enemy.add_to_group("enemies")
			game.get_node("Entities/Enemies").add_child(test_enemy)
			test_enemy.global_position = (
				test_obstacle.global_position + Vector2(0.0, -80.0)
			)
			arena._update_obstacle_occlusion(1.0)
			_check(
				obstacle_visual.self_modulate.a < 0.7,
				"Prop also becomes translucent over covered enemies"
			)
			test_enemy.queue_free()

	var center := Vector2(1280.0, 720.0)
	var space_state: PhysicsDirectSpaceState2D = game.get_world_2d().direct_space_state
	var center_query := PhysicsPointQueryParameters2D.new()
	center_query.position = center
	center_query.collision_mask = 1
	var player := get_first_node_in_group("player") as CollisionObject2D
	if player != null:
		center_query.exclude = [player.get_rid()]
	var center_hits: Array[Dictionary] = space_state.intersect_point(center_query)
	_check(center_hits.is_empty(), "Player spawn area remains clear")

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failure_count == 0:
		print("ARENA TEST PASSED")
		quit(0)
		return
	push_error("ARENA TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)
