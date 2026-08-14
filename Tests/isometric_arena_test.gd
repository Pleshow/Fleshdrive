extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MENU_SCENE := preload("res://Scenes/main_menu.tscn")

var failure_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flow := root.get_node_or_null("GameFlow")
	_check(flow != null, "GameFlow is available for arena selection")
	if flow == null:
		_finish()
		return
	var original_arena := StringName(flow.get("selected_arena_id"))
	flow.call("set_selected_arena", &"sludgeworks")

	var menu := MENU_SCENE.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(
		menu.arena_option != null
		and menu.arena_option.item_count == 3
		and menu.arena_option.selected == 1,
		"New-run menu exposes all arenas and restores the selected site"
	)
	menu._on_arena_selected(0)
	_check(
		StringName(flow.get("selected_arena_id")) == &"bio_lab",
		"Laboratory can be selected for the next run"
	)
	menu._on_arena_selected(1)
	_check(
		StringName(flow.get("selected_arena_id")) == &"sludgeworks"
		and menu.arena_description_label.text.contains("IMPASSABLE"),
		"Sludgeworks selection communicates the toxic runoff rule"
	)
	menu.queue_free()
	await process_frame

	var game := GAME_SCENE.instantiate() as GameArenaController
	root.add_child(game)
	await process_frame
	await process_frame
	var arena := game.get_node_or_null("Arena") as IsometricSlimeArena
	var player := game.get_node_or_null("Entities/Koda") as Koda
	var spawner := game.get_node_or_null("EnemySpawner")
	var run_manager := game.get_node_or_null("RunManager") as RunManager
	var hud := game.get_node_or_null("UI/HUD") as Control
	var darkness := game.get_node_or_null("WorldDarkness") as CanvasModulate
	_check(arena != null, "Selected run instantiates the isometric arena")
	if arena == null:
		_cleanup(game, flow, original_arena)
		return
	spawner.call("stop_spawning")

	var map_sprite := arena.get_node_or_null("MapComposite") as Sprite2D
	var walls := arena.get_node_or_null("SlimeBoundary") as StaticBody2D
	var lights := arena.get_node_or_null("SlimeLights")
	_check(
		map_sprite != null
		and map_sprite.texture.resource_path
		== "res://Assets/environment/isometric/map-composite.png",
		"Authored isometric composite is the arena floor"
	)
	_check(
		arena.walkable_polygon.size() >= 60
		and walls != null
		and walls.get_child_count() == arena.walkable_polygon.size(),
		"Gray platform outline has a continuous solid shoreline"
	)
	_check(
		lights != null
		and arena.shoreline_lights.size() >= 9
		and arena.get_node_or_null("BasinAtmosphere") != null,
		"Runoff has animated green lighting and atmospheric motion"
	)
	var all_lights_on_slime := true
	for light in arena.shoreline_lights:
		if arena.is_walkable_position(light.global_position, 0.0):
			all_lights_on_slime = false
			break
	_check(all_lights_on_slime, "Every green basin light is anchored in runoff")

	_check(
		player != null
		and arena.is_walkable_position(player.global_position, 22.0),
		"Koda starts safely on the connected gray deck"
	)
	_check(
		player.get_node_or_null("PlayerLight") is PointLight2D
		and (player.get_node("PlayerLight") as PointLight2D).energy >= 2.0,
		"Koda remains a strong local light source in the dark basin"
	)
	_check(
		darkness != null
		and darkness.color.r <= 0.16
		and darkness.color.g <= 0.18
		and darkness.color.b <= 0.16,
		"Isometric world uses the same deep-dark presentation range"
	)
	_check(
		not arena.is_walkable_position(Vector2(372.0, 135.0), 0.0)
		and not arena.is_walkable_position(Vector2(1807.0, 840.0), 0.0),
		"Outer slime and the central green inlet are not walkable"
	)

	var random_positions_valid := true
	for _sample in range(48):
		var candidate := arena.get_random_edge_spawn_position(46.0)
		if not arena.is_walkable_position(candidate, 46.0):
			random_positions_valid = false
			break
	_check(
		random_positions_valid,
		"Arena-specific edge candidates always keep enemy clearance on gray"
	)
	var offscreen_spawns_valid := true
	spawner.set("spawning_enabled", false)
	var camera_center := Vector2(spawner.call("_get_camera_center"))
	for _sample in range(24):
		var candidate := Vector2(spawner.call("_find_spawn_position"))
		if (
			not arena.is_walkable_position(candidate, 46.0)
			or not bool(spawner.call(
				"_is_offscreen",
				candidate,
				camera_center
			))
		):
			offscreen_spawns_valid = false
			break
	_check(
		offscreen_spawns_valid,
		"Regular, rush, reinforcement and boss spawn search stays offscreen and on gray"
	)
	var boss_position := Vector2(spawner.call("get_boss_spawn_position"))
	_check(
		arena.is_walkable_position(boss_position, 66.0)
		and run_manager != null
		and is_equal_approx(run_manager.run_duration_seconds, 720.0)
		and is_equal_approx(run_manager.boss_spawn_time_seconds, 660.0),
		"Existing twelve-minute run and Warden timing carry over to the arena"
	)
	if hud != null:
		hud.call("complete_onboarding")
	await process_frame
	spawner.call("stop_spawning")
	_check(
		run_manager.start_boss_encounter(),
		"Warden encounter starts normally in the isometric arena"
	)
	await process_frame
	var boss := run_manager.active_boss as VisceralWarden
	_check(
		boss != null
		and arena.is_walkable_position(boss.global_position, 55.0)
		and boss.is_in_group("boss"),
		"Warden enters offscreen with full body clearance on the gray deck"
	)

	player.global_position = Vector2(370.0, 135.0)
	arena._enforce_walkable_actors()
	_check(
		arena.is_walkable_position(player.global_position, 18.0),
		"Safety recovery returns displaced actors from runoff to the deck"
	)

	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call(
			"play",
			&"electric_impact",
			player.global_position + Vector2(80.0, 0.0),
			1.0
		)
	_check(
		visual_effects != null
		and get_nodes_in_group("electric_flash").size() > 0,
		"Lightning VFX casts a hard pixel-stepped light across the isometric floor"
	)

	_cleanup(game, flow, original_arena)


func _cleanup(game: Node, flow: Node, original_arena: StringName) -> void:
	paused = false
	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("clear_all")
	if is_instance_valid(game):
		game.queue_free()
	flow.call("set_selected_arena", original_arena)
	await process_frame
	_finish()


func _finish() -> void:
	if failure_count == 0:
		print("ISOMETRIC ARENA TEST PASSED")
		quit(0)
		return
	push_error("ISOMETRIC ARENA TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)
