extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var spawner = game.get_node("EnemySpawner")
	spawner.stop_spawning()
	var player := get_first_node_in_group("player") as Koda
	var weapon_system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var runtime_pool := root.get_node("RuntimePool")
	spawner.spawning_enabled = true
	spawner.spawn_timer.stop()
	spawner._process(0.016)
	_check(
		not spawner.spawn_timer.is_stopped(),
		"A lost spawn timer self-recovers during an active run"
	)
	spawner.stop_spawning()

	# A run used to stop after enough kills because pooled enemies retained the
	# `enemies` group and permanently filled both spawn budgets.
	var baseline_enemy_count := get_nodes_in_group("enemies").size()
	for cycle in range(40):
		var enemy := runtime_pool.call(
			"acquire",
			spawner.crawler_scene,
			game.get_node("Entities/Enemies")
		) as Node2D
		_check(enemy != null and enemy.is_in_group("enemies"), "Acquired enemy %d is active" % cycle)
		runtime_pool.call("release", enemy)
		await process_frame
		await process_frame
		_check(
			get_nodes_in_group("enemies").size() == baseline_enemy_count,
			"Released enemy %d no longer consumes the live spawn budget" % cycle
		)

	player.upgrade_levels.clear()
	player.configure_fleshdrive(FleshdriveCatalog.ELECTRIC, 1)
	_check(
		not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
		"Electric E skill stays locked until its weapon is selected"
	)
	player.upgrade_levels[&"shock_ram"] = 1
	_check(
		not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
		"Shock Ram remains an automatic Electric weapon"
	)

	player.upgrade_levels.clear()
	player.configure_fleshdrive(FleshdriveCatalog.FIRE, 1)
	_check(
		not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
		"Fire E skill stays locked until an active-capable weapon is selected"
	)
	player.upgrade_levels[&"magma_spear"] = 1
	_check(
		StringName(weapon_system.get_active_skill_status().get("id", &"")) == &"magma_spear",
		"Selected Magma Spear owns the Fire E slot"
	)

	player.upgrade_levels.clear()
	player.configure_fleshdrive(FleshdriveCatalog.TELEKINETIC, 1)
	_check(
		not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
		"Noetic E skill stays locked until Repulse Wave is selected"
	)
	player.upgrade_levels[&"repulse_wave"] = 1
	_check(
		not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
		"Repulse Wave remains an automatic Noetic weapon"
	)

	paused = false
	game.queue_free()
	await process_frame
	if failures == 0:
		print("RUN INTEGRITY REGRESSION TEST PASSED")
		quit(0)
		return
	push_error("RUN INTEGRITY REGRESSION TEST FAILED: %d failure(s)" % failures)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
