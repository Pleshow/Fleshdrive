extends SceneTree


var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	var scene := load("res://Scenes/game.tscn") as PackedScene
	_check(scene != null, "Thunder God game scene loads")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	paused = false
	var player := game.get_node("Entities/Koda") as Koda
	var system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var operation := game.get_node("UI/HUD/FleshdriveOperationScreen") as FleshdriveOperationScreen
	_check(operation.fire_card.disabled, "Pyre Heart remains visible but disabled during development")
	_check(operation.telekinetic_card.disabled, "Noetic Heart is disabled in the prototype")
	_check(not operation.electric_card.disabled, "Voltaic Heart is the only enabled Heart")
	operation._select_fleshdrive(FleshdriveCatalog.FIRE)
	_check(
		operation.details_text.text == "IN DEVELOPMENT"
		and operation.selected_fleshdrive_id == FleshdriveCatalog.ELECTRIC,
		"Clicking Pyre explains that it is unavailable without selecting it"
	)
	var thunder_ids: Array[StringName] = [
		&"conductive_fur", &"arc_relay", &"capacitor_organ",
		&"storm_core", &"ionized_blood", &"neural_thunder",
		&"feedback_loop", &"overload_heart", &"eye_of_the_storm",
		&"singularity_core",
	]
	for upgrade_id in thunder_ids:
		player.upgrade_levels[upgrade_id] = 1
	player.upgrade_levels[&"arc_heart"] = 1
	player.upgrade_levels[&"arc_relay"] = 4
	player.configure_fleshdrive(FleshdriveCatalog.ELECTRIC, 1)
	var chest_socket := player.get_electric_muzzle_position(
		player.global_position + Vector2.RIGHT * 100.0
	)
	_check(
		chest_socket.x > player.global_position.x
		and chest_socket.y < player.global_position.y,
		"Voltaic autoattack starts forward from Koda's upper chest"
	)
	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var enemies: Array[Node2D] = []
	for index in range(9):
		var enemy := crawler_scene.instantiate() as Node2D
		game.get_node("Entities").add_child(enemy)
		enemy.global_position = player.global_position + Vector2(110.0 + 72.0 * float(index), 0.0)
		if "max_health" in enemy:
			enemy.max_health = 5000.0
			enemy.current_health = 5000.0
		enemies.append(enemy)
	await process_frame
	system.thunder_god.random.seed = 7
	var fired := system.perform_thunder_god_attack(enemies[0])
	_check(fired, "Base attack starts the Thunder God network")
	var pipeline := root.get_node("CombatPipeline")
	var shocked_targets := 0
	var tracked_shock_duration := 0.0
	var shock_crowns_follow_targets := true
	for enemy in enemies:
		var shock := Dictionary(pipeline.call("get_status", enemy, &"shock"))
		if int(shock.get("stacks", 0)) > 0:
			shocked_targets += 1
			tracked_shock_duration = maxf(
				tracked_shock_duration,
				float(shock.get("remaining", 0.0))
			)
			var crown := enemy.get_node_or_null("ThunderShockCrown") as Line2D
			shock_crowns_follow_targets = (
				shock_crowns_follow_targets
				and crown != null
				and crown.get_parent() == enemy
				and not crown.is_set_as_top_level()
			)
	_check(shocked_targets >= 2, "Base Chain Lightning reaches at least two unique enemies")
	_check(shocked_targets <= 9, "Chain targeting never loops beyond unique enemies")
	_check(
		tracked_shock_duration >= 5.9 and shock_crowns_follow_targets,
		"Conductive Fur shock lasts six seconds and follows each target"
	)
	_check(system.thunder_god.capacitor_charge <= 6, "One attack respects the six-charge Capacitor cap")
	_check(player.attack_timer.wait_time >= 0.25, "Feedback Loop respects the absolute cooldown floor")
	var thunder_effects := get_nodes_in_group("thunder_vfx")
	_check(not thunder_effects.is_empty(), "Chain Lightning creates an animated asset VFX")
	var bolt := thunder_effects[0] as AnimatedSprite2D if not thunder_effects.is_empty() else null
	_check(
		bolt != null
		and bolt.z_index >= 70
		and bolt.sprite_frames.get_frame_count(&"play") == 4
		and bolt.material is ShaderMaterial
		and bool((bolt.material as ShaderMaterial).get_shader_parameter("force_electric_blue")),
		"Autoattack uses the licensed four-frame blue lightning above enemies"
	)
	var player_bolt: AnimatedSprite2D = null
	for effect in thunder_effects:
		if bool(effect.get_meta("tracks_player_source", false)):
			player_bolt = effect as AnimatedSprite2D
			break
	_check(player_bolt != null, "Primary Voltaic bolt tracks Koda's chest socket")
	if player_bolt != null:
		var bolt_position_before_move := player_bolt.global_position
		player.global_position += Vector2(18.0, 6.0)
		await process_frame
		_check(
			player_bolt.global_position.distance_to(bolt_position_before_move) > 2.0,
			"Active lightning stays attached while Koda moves"
		)
	system.thunder_god.lightning_activity = 49
	system.perform_thunder_god_attack(enemies[0])
	_check(system.thunder_god.thunderstate_remaining > 0.0, "Fifty Lightning events activate THUNDERSTATE")
	for index in range(4):
		system.perform_thunder_god_attack(enemies[0])
	_check(system.thunder_god.capacitor_charge < 20, "Capacitor automatically discharges and preserves remainder")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("THUNDER GOD PROTOTYPE TEST PASSED")
	quit(failures)
