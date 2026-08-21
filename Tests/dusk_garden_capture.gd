extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const CRAWLER_SCENE := preload("res://Scenes/enemies/crawler.tscn")
const SPITTER_SCENE := preload("res://Scenes/enemies/spitter.tscn")
const PROJECTILE_SCENE := preload("res://Scenes/enemies/spitter_projectile.tscn")
const BIOMASS_SCENE := preload("res://Scenes/pickups/biomass_pickup.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var flow := root.get_node_or_null("GameFlow")
	if flow == null:
		quit(1)
		return
	var original_arena := StringName(flow.get("selected_arena_id"))
	flow.call("set_selected_arena", &"dusk_garden")
	var game := GAME_SCENE.instantiate() as GameArenaController
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var spawner := game.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.call("stop_spawning")
	var hud := game.get_node_or_null("UI/HUD")
	if hud != null and hud.has_method("complete_onboarding"):
		hud.call("complete_onboarding")
	paused = false
	var player := game.get_node("Entities/Koda") as Koda
	var entities := game.get_node("Entities")
	await create_timer(0.30).timeout
	var offsets := [
		Vector2(-250, -120), Vector2(-190, 130), Vector2(260, 5),
		Vector2(225, 145), Vector2(-365, 25), Vector2(370, 35),
		Vector2(260, 35),
	]
	for index in range(offsets.size()):
		var enemy := (
			CRAWLER_SCENE.instantiate()
			if index % 2 == 0
			else SPITTER_SCENE.instantiate()
		) as Node2D
		entities.add_child(enemy)
		enemy.global_position = player.global_position + offsets[index]
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var biomass := BIOMASS_SCENE.instantiate() as BiomassPickup
	entities.add_child(biomass)
	biomass.global_position = player.global_position + Vector2(-92.0, 58.0)
	var projectile := PROJECTILE_SCENE.instantiate() as SpitterProjectile
	entities.add_child(projectile)
	projectile.global_position = player.global_position + Vector2(150.0, 20.0)
	projectile.configure(Vector2.LEFT, 0.0, 0.0)
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		var strike := visual_effects.call(
			"play",
			&"storm_strike_03",
			player.global_position + Vector2(330.0, -125.0),
			0.9
		) as AnimatedSprite2D
		_pause_at_middle_frame(strike)
		var chain := visual_effects.call(
			"play",
			&"electric_chain_arc",
			player.global_position + Vector2(-250.0, -110.0),
			0.9
		) as AnimatedSprite2D
		_pause_at_middle_frame(chain)
		var original_color_samples := [
			[&"ball_lightning_idle", Vector2(-145.0, 45.0), 1.25],
			[&"kinetic_charge_lightning", Vector2(20.0, -15.0), 1.1],
			[&"shock_status", Vector2(175.0, 65.0), 1.0],
			[&"holy_heal", Vector2(25.0, 115.0), 1.0],
			[&"decoy_smoke", Vector2(-210.0, 120.0), 1.0],
		]
		for sample in original_color_samples:
			var sprite := visual_effects.call(
				"play", sample[0], player.global_position + Vector2(sample[1]),
				float(sample[2])
			) as AnimatedSprite2D
			_pause_at_middle_frame(sprite)
	var player_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player_sprite.animation = &"right"
	player_sprite.frame = 0
	player_sprite.pause()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("Dusk Garden capture requires a rendering display driver.")
		flow.call("set_selected_arena", original_arena)
		quit(2)
		return
	var output_path := "res://.godot/dusk_garden_capture.png"
	var error := image.save_png(output_path)
	flow.call("set_selected_arena", original_arena)
	if error == OK:
		print("DUSK GARDEN CAPTURED: ", ProjectSettings.globalize_path(output_path))
		quit(0)
		return
	push_error("Dusk Garden capture failed: %s" % error_string(error))
	quit(1)


func _pause_at_middle_frame(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var count := sprite.sprite_frames.get_frame_count(&"play")
	sprite.pause()
	sprite.frame = mini(maxi(count / 2, 0), count - 1)
