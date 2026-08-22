extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_game := load("res://Scenes/game.tscn") as PackedScene
	_check(packed_game != null, "Boss test can load the game scene")
	if packed_game == null:
		_finish()
		return

	var game := packed_game.instantiate()
	root.add_child(game)
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var run_manager := get_first_node_in_group(
		"run_manager"
	) as RunManager
	var spawner := game.get_node("EnemySpawner")
	var hud := game.get_node("UI/HUD")
	var attack_container := game.get_node("Entities/Attacks")

	hud.complete_onboarding()
	await process_frame
	paused = false
	spawner.stop_spawning()

	_check(
		run_manager.boss_scene != null,
		"Run manager has the Visceral Warden scene"
	)
	_check(
		run_manager.start_boss_encounter(),
		"Boss encounter can be started directly for testing"
	)
	await process_frame

	var boss := run_manager.active_boss as VisceralWarden
	_check(
		boss != null
		and boss.is_in_group("boss")
		and boss.is_in_group("enemies"),
		"Visceral Warden spawns as a damageable boss enemy"
	)
	var boss_sprite := boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(
		boss_sprite.sprite_frames.get_frame_count(&"idle") == 4
		and boss_sprite.sprite_frames.get_frame_count(&"cast") == 4
		and boss_sprite.sprite_frames.get_frame_count(&"charge") == 4
		and boss_sprite.sprite_frames.get_frame_count(&"enraged") == 4,
		"Redesigned boss uses four animated pixel-art states"
	)
	_check(
		hud.boss_panel.visible
		and hud.boss_health_bar.value == boss.max_health
		and hud.boss_panel.size.x <= 380.0
		and hud.boss_panel.position.y >= 96.0
		and hud.boss_panel.position.y <= 190.0,
		"Compact boss HUD appears below the timer with full health"
	)
	_check(
		spawner.spawn_timer.is_stopped(),
		"Normal enemy spawning stops for the finale"
	)

	boss._on_state_timer_timeout()
	_check(
		boss.state == VisceralWarden.State.HUNT,
		"Boss intro enters the hunt state"
	)

	boss.volley_windup = 0.05
	boss.force_attack(&"volley")
	_check(
		boss.state == VisceralWarden.State.WINDUP_VOLLEY
		and boss.aim_line.visible,
		"Projectile fan has a visible windup"
	)
	boss._on_state_timer_timeout()
	await process_frame
	_check(
		attack_container.get_child_count()
		>= boss.volley_projectile_count,
		"Projectile fan fires its configured spread"
	)

	boss.slam_windup = 0.05
	for projectile in attack_container.get_children():
		projectile.queue_free()
	await process_frame
	player.global_position = boss.global_position + Vector2(60.0, 0.0)
	player.current_health = player.max_health
	player.invulnerability_timer.stop()
	paused = false
	var health_before_slam := player.current_health
	boss.force_attack(&"slam")
	_check(
		boss.state == VisceralWarden.State.WINDUP_SLAM
		and boss.slam_telegraph.visible,
		"Ground slam displays its danger zone"
	)
	boss._on_state_timer_timeout()
	await process_frame
	_check(
		player.current_health < health_before_slam,
		"Ground slam damages players inside the telegraph"
	)

	boss.take_damage(boss.max_health * 0.51)
	await process_frame
	_check(
		boss.phase == 2
		and boss.sprite.animation == &"enraged"
		and hud.boss_phase_label.text == "PHASE II",
		"Boss enters its second phase below half health"
	)
	boss.pending_combo_attack = &"volley"
	boss._start_recovery()
	boss._finish_recovery()
	_check(
		boss.state == VisceralWarden.State.WINDUP_VOLLEY
		and boss.pending_combo_attack.is_empty(),
		"Phase II chains a follow-up pattern instead of only speeding up"
	)

	boss.charge_windup = 0.05
	player.global_position = boss.global_position + Vector2(320.0, 0.0)
	boss.force_attack(&"charge")
	_check(
		boss.state == VisceralWarden.State.WINDUP_CHARGE
		and boss.charge_line.visible,
		"Charge attack has a visible trajectory telegraph"
	)
	boss._on_state_timer_timeout()
	_check(
		boss.state == VisceralWarden.State.CHARGE,
		"Charge windup transitions into the charge state"
	)

	boss.take_damage(boss.max_health * 2.0)
	await process_frame
	await create_timer(
		run_manager.boss_victory_delay_seconds + 0.12,
		true,
		false,
		true
	).timeout
	_check(
		run_manager.boss_defeated_flag
		and run_manager.state == RunManager.RunState.VICTORY,
		"Boss death completes the run with victory"
	)
	_check(
		hud.get_node("RunEndPanel").visible,
		"Boss victory displays the run summary"
	)

	paused = false
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	failure_count += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failure_count == 0:
		print("BOSS ENCOUNTER TEST PASSED")
		quit(0)
		return

	push_error(
		"BOSS ENCOUNTER TEST FAILED: %d failure(s)" % failure_count
	)
	quit(1)
