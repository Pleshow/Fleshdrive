extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_scene := load("res://Scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.get_node("UI/HUD").complete_onboarding()
	await process_frame

	var spawner := game.get_node("EnemySpawner")
	var enemies := game.get_node("Entities/Enemies")
	var effects := game.get_node("Entities/Effects")
	var feedback := get_first_node_in_group("combat_feedback")
	var camera := get_first_node_in_group("camera_feedback")
	var player := get_first_node_in_group("player") as Koda
	var audio_effects := root.get_node_or_null("AudioEffects")
	spawner.stop_spawning()

	_check(feedback != null, "Combat feedback controller exists")
	_check(camera != null, "Feedback camera exists")
	_check(effects.is_in_group("effects_container"), "World effects use their own container")
	_check(audio_effects != null, "Combat audio effects player exists")
	if audio_effects != null:
		audio_effects.call("clear_play_counts")

	feedback.shake_camera(0.5)
	_check(camera.trauma > 0.0, "Camera shake receives trauma")

	feedback.base_hit_stop_seconds = 0.01
	feedback.hit_stop(0.5)
	_check(Engine.time_scale < 1.0, "Hit stop temporarily slows the game")
	await create_timer(0.05, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hit stop restores normal time scale")

	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var crawler := crawler_scene.instantiate()
	enemies.add_child(crawler)
	crawler.global_position = Vector2(1280.0, 720.0)
	var effect_count_before := effects.get_child_count()
	player.perform_attack(crawler)
	_check(
		effects.get_child_count() >= effect_count_before + 2,
		"Koda attack creates separate muzzle and impact VFX"
	)
	_check(
		get_nodes_in_group("electric_flash").size() >= 2,
		"Koda's muzzle and impact create real blue light flashes"
	)
	var effect_count_after_attack := effects.get_child_count()
	if audio_effects != null:
		_check(
			audio_effects.call("get_play_count", &"raiju_attack") == 1
			and audio_effects.call(
				"get_play_count",
				&"raiju_attack_spark"
			) == 1
			and audio_effects.call("get_play_count", &"enemy_hit") == 1,
			"Layered Koda attack and enemy hit sounds are triggered"
		)
	crawler.take_damage(crawler.max_health)
	_check(crawler.is_dead, "Lethal damage marks the enemy dead")
	_check(
		effects.get_child_count() >= effect_count_after_attack + 1,
		"Enemy death creates a world-space affinity animation"
	)
	if audio_effects != null:
		_check(
			audio_effects.call("get_play_count", &"enemy_death") == 1,
			"Enemy death sound is triggered"
		)

	player.dash_unlocked = true
	Input.action_press("dash")
	player.try_start_dash()
	Input.action_release("dash")
	if audio_effects != null:
		_check(
			audio_effects.call("get_play_count", &"raiju_dash") == 1,
			"Koda dash sound is triggered"
		)

	var pickup_scene := load(
		"res://Scenes/pickups/biomass_pickup.tscn"
	) as PackedScene
	var pickup := pickup_scene.instantiate() as BiomassPickup
	game.get_node("Entities/Pickups").add_child(pickup)
	pickup.biomass_value = 1.0
	pickup.can_be_collected = true
	pickup.on_body_entered(player)
	if audio_effects != null:
		_check(
			audio_effects.call("get_play_count", &"biomass_pickup") == 1,
			"Biomass pickup sound is triggered"
		)

	await create_timer(0.1, true, false, true).timeout
	Engine.time_scale = 1.0
	paused = false
	game.queue_free()
	await process_frame

	if failure_count == 0:
		print("COMBAT FEEDBACK TEST PASSED")
		quit(0)
		return

	push_error("COMBAT FEEDBACK TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	failure_count += 1
	push_error("FAIL: " + message)
