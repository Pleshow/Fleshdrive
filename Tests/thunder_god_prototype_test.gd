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
		&"conductive_fur", &"feedback_loop", &"singularity_core",
		&"ionized_blood", &"neural_thunder",
	]
	for upgrade_id in thunder_ids:
		player.upgrade_levels[upgrade_id] = 1
	player.upgrade_levels[&"arc_heart"] = 1
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
			var crown_ref := enemy.get_meta("status_vfx_shock", null) as WeakRef
			var crown := crown_ref.get_ref() as AnimatedSprite2D if crown_ref != null else null
			var follow_ref := crown.get_meta("follow_target", null) as WeakRef if crown != null else null
			shock_crowns_follow_targets = (
				shock_crowns_follow_targets
				and crown != null
				and follow_ref != null
				and follow_ref.get_ref() == enemy
				and crown.material == null
				and crown.sprite_frames.get_frame_count(&"play") == 10
			)
	_check(shocked_targets >= 2, "Base Chain Lightning reaches at least two unique enemies")
	_check(shocked_targets <= 9, "Chain targeting never loops beyond unique enemies")
	_check(
		tracked_shock_duration >= 0.9 and shock_crowns_follow_targets,
		"Conductive Fur immobilizes targets for one refreshed second"
	)
	_check(
		system.thunder_god.thunder_meter > 0.0,
		"Lightning hits charge the Thunder Meter"
	)
	var thunder_effects := get_nodes_in_group("thunder_vfx")
	_check(not thunder_effects.is_empty(), "Chain Lightning creates an animated asset VFX")
	var bolt := thunder_effects[0] as AnimatedSprite2D if not thunder_effects.is_empty() else null
	_check(
		bolt != null
		and bolt.z_index >= 70
		and bolt.sprite_frames.get_frame_count(&"play") == 4
		and bolt.visible,
		"Autoattack uses the licensed four-frame lightning above enemies"
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
		var visual_effects := root.get_node("VisualEffects")
		var previous_generation := int(
			player_bolt.get_meta("vfx_generation", -1)
		)
		visual_effects.call("stop_effect", player_bolt)
		var recycled_bolt := visual_effects.call(
			"play", &"electric_chain_arc", Vector2(777.0, 777.0), 0.55, 0.0
		) as AnimatedSprite2D
		if recycled_bolt != null:
			var recycled_position := recycled_bolt.global_position
			player.global_position += Vector2(24.0, 0.0)
			enemies[0].global_position += Vector2(0.0, 24.0)
			await process_frame
			_check(
				recycled_bolt == player_bolt
				and int(recycled_bolt.get_meta("vfx_generation", -1))
				!= previous_generation
				and recycled_bolt.global_position.is_equal_approx(recycled_position),
				"Recycled VFX cannot be moved by a stale lightning tracker"
			)
		else:
			_check(false, "Recycled VFX cannot be moved by a stale lightning tracker")
	system.thunder_god.thunder_meter = 99.0
	system.perform_thunder_god_attack(enemies[0])
	_check(
		system.thunder_god.thunder_meter >= 100.0
		and system.thunder_god.activate_thunder_capstone()
		and system.thunder_god.neural_remaining >= 4.99,
		"The active-skill input spends a full meter on Neural Thunder"
	)
	var shocked_enemy := enemies[0]
	var shock_ref := shocked_enemy.get_meta("status_vfx_shock", null) as WeakRef
	var shock_visual := shock_ref.get_ref() as AnimatedSprite2D if shock_ref != null else null
	pipeline.status_effects.notify_target_killed(shocked_enemy)
	_check(
		not shocked_enemy.has_meta("status_vfx_shock")
		and (not is_instance_valid(shock_visual) or not shock_visual.visible),
		"Shock VFX disappears in the same frame its target dies"
	)
	var stale_aura := AnimatedSprite2D.new()
	game.add_child(stale_aura)
	system.thunder_god.player_aura_sprite = stale_aura
	stale_aura.free()
	system.thunder_god.shutdown()
	_check(true, "Thunder God shutdown safely ignores an already-freed VFX reference")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("THUNDER GOD PROTOTYPE TEST PASSED")
	quit(failures)
