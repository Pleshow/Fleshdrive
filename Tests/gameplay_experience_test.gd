extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MAIN_MENU_SCENE := preload("res://Scenes/main_menu.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("GameSettings")
	settings.set_gameplay_setting(&"screen_shake", 0.35, false)
	settings.set_gameplay_setting(&"controller_deadzone", 0.31, false)
	settings.set_gameplay_setting(&"crosshair_scale", 1.25, false)
	settings.set_gameplay_setting(&"damage_numbers", false, false)
	_check(is_equal_approx(settings.screen_shake_intensity, 0.35), "Camera shake setting is stored")
	_check(is_equal_approx(InputMap.action_get_deadzone(&"move_left"), 0.31), "Controller deadzone is applied to movement")

	var menu := MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.find_child("GameplaySettings", true, false) != null, "Main menu exposes mix and accessibility controls")
	menu.queue_free()
	await process_frame

	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.get_node("UI/HUD")
	hud.complete_onboarding()
	await process_frame
	var player := get_first_node_in_group("player") as Koda
	var camera := player.get_node("Camera2D") as CameraFeedback
	var crosshair := game.get_node("UI/HUD/GameplayCrosshair") as GameplayCrosshair
	_check(hud.pause_settings_panel.find_child("GameplaySettings", true, false) != null, "Pause settings exposes the same gameplay controls")

	player.dash_unlocked = true
	player.last_direction = Vector2.RIGHT
	player.dash_cooldown_timer.start(0.02)
	player.dash_buffer_remaining = player.dash_input_buffer
	player.try_start_dash()
	_check(not player.is_dashing, "Buffered dash waits for cooldown completion")
	await create_timer(0.03).timeout
	player.try_start_dash()
	_check(player.is_dashing and player.dash_direction == Vector2.RIGHT, "Buffered dash starts with a stable locked direction")
	player.finish_dash()

	player.velocity = Vector2(200.0, 0.0)
	camera._physics_process(0.1)
	_check(camera.look_offset.length() > 0.0, "Camera spring look-ahead follows movement and aim")
	camera.add_trauma(0.5)
	camera._physics_process(0.01)
	_check(camera.offset.length() > 0.0, "Scaled camera shake remains active")
	crosshair._process(0.01)
	_check(is_equal_approx(crosshair.scale.x, 1.25), "Crosshair size setting is applied live")

	var audio := root.get_node("AudioEffects")
	audio.clear_play_counts()
	audio.play(&"enemy_hit")
	audio.play(&"enemy_hit")
	_check(audio.get_play_count(&"enemy_hit") == 1, "Repeated hit sounds are concurrency throttled")

	settings.set_gameplay_setting(&"damage_numbers", true, false)
	settings.set_gameplay_setting(&"screen_shake", 0.72, false)
	settings.set_gameplay_setting(&"controller_deadzone", 0.20, false)
	settings.set_gameplay_setting(&"crosshair_scale", 1.0, false)
	paused = false
	game.queue_free()
	await process_frame
	if failures == 0:
		print("GAMEPLAY EXPERIENCE TEST PASSED")
		quit(0)
		return
	push_error("GAMEPLAY EXPERIENCE TEST FAILED: %d failure(s)" % failures)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
