extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_scene := load("res://Scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.get_node("UI/HUD").complete_onboarding()
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var run_manager := get_first_node_in_group("run_manager") as RunManager
	var spawner := game.get_node("EnemySpawner")

	player.max_health = 100000.0
	player.current_health = player.max_health
	run_manager.set_process(false)
	spawner.set_run_progress(1.0)
	# Guarantee that the stress population exercises both strategic threats;
	# the rest of the horde remains driven by the real rush scheduler.
	spawner.call(
		"_schedule_enemy_spawn",
		spawner.spitter_scene,
		&"spitter",
		Vector2(spawner.call("_find_spawn_position")),
		false
	)
	spawner.call(
		"_schedule_enemy_spawn",
		spawner.charger_scene,
		&"charger",
		Vector2(spawner.call("_find_spawn_position")),
		false
	)
	run_manager.trigger_rush()

	var sampled_frame_times: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	for _frame in range(360):
		await physics_frame
		var tick := Time.get_ticks_usec()
		sampled_frame_times.append(float(tick - last_tick) / 1000.0)
		last_tick = tick

	var crawler_count := 0
	var spitter_count := 0
	var charger_count := 0

	for enemy in get_nodes_in_group("enemies"):
		if enemy is Crawler:
			crawler_count += 1
		elif enemy is Spitter:
			spitter_count += 1
		elif enemy is Charger:
			charger_count += 1

	print(
		"STRESS MIX: crawler=%d spitter=%d charger=%d total=%d cap=%d pending=%d"
		% [
			crawler_count,
			spitter_count,
			charger_count,
			crawler_count + spitter_count + charger_count,
			spawner.maximum_enemies,
			spawner.pending_spawn_count,
		]
	)
	var final_spawn_position := Vector2(spawner.call("_get_next_spawn_position"))
	var previous_pending_threat: float = spawner.pending_spawn_threat
	spawner.pending_spawn_threat = spawner.get_effective_threat_budget()
	var blocked_over_budget_spawn := not bool(spawner.call(
		"_schedule_enemy_spawn",
		spawner.crawler_scene,
		&"crawler",
		final_spawn_position,
		false
	))
	spawner.pending_spawn_threat = previous_pending_threat
	var total_frame_time := 0.0
	var peak_frame_time := 0.0
	for frame_time in sampled_frame_times:
		total_frame_time += frame_time
		peak_frame_time = maxf(peak_frame_time, frame_time)
	var average_frame_time := (
		total_frame_time / maxf(float(sampled_frame_times.size()), 1.0)
	)
	print(
		"STRESS FRAME TIME: average=%.2fms peak=%.2fms"
		% [average_frame_time, peak_frame_time]
	)

	var passed: bool = (
		crawler_count > 0
		and spitter_count > 0
		and charger_count > 0
		and crawler_count + spitter_count + charger_count
			<= spawner.maximum_enemies + spawner.rush_enemy_budget_bonus
		and blocked_over_budget_spawn
		and average_frame_time < 50.0
	)

	paused = false
	game.queue_free()
	await process_frame

	if passed:
		print("ENEMY MIX STRESS TEST PASSED")
		quit(0)
		return

	push_error("ENEMY MIX STRESS TEST FAILED: mix, budget or frame-time contract")
	quit(1)
