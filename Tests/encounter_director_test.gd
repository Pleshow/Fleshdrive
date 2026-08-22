extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MAIN_MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const SKILL_TREE_SCENE := preload(
	"res://Scenes/ui/skill_tree_panel.tscn"
)
const CRAWLER_SCENE := preload("res://Scenes/enemies/crawler.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.get_node("UI/HUD")
	hud.complete_onboarding()
	await process_frame
	var player := get_first_node_in_group("player") as Koda
	var manager := game.get_node("RunManager") as RunManager
	var spawner = game.get_node("EnemySpawner")
	var director := manager.encounter_director
	spawner.spawn_timer.stop()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame

	_check(
		director.phases.size() == 6
		and float(director.phases[0]["start"]) == 0.0
		and float(director.phases[5]["start"]) == 660.0,
		"Director defines all six sections of the twelve-minute run"
	)
	manager.elapsed_seconds = 130.0
	director._process(0.51)
	_check(
		String(director.phases[director.current_phase_index]["id"])
		== "adaptation"
		and spawner.director_threat_budget >= 34.0,
		"Director applies the reinforced ranged-and-elite adaptation budget"
	)

	var spatial_positions_valid := true
	for _index in range(16):
		var candidate: Vector2 = spawner._find_spawn_position()
		spatial_positions_valid = (
			spatial_positions_valid
			and spawner.arena_bounds.has_point(candidate)
			and spawner._is_offscreen(
				candidate,
				spawner._get_camera_center()
			)
			and candidate.distance_to(player.global_position)
			>= spawner.minimum_player_distance
		)
	_check(
		spatial_positions_valid,
		"Spatial spawn zones stay inside the arena and outside Koda's view"
	)

	player.current_health = player.max_health * 0.20
	director._process(0.51)
	_check(
		director.pressure_scale <= 0.60
		and director.pressure_reason == &"critical_health",
		"Critical health creates a subtle temporary pressure reduction"
	)

	manager.elapsed_seconds = 555.0
	director._process(0.51)
	_check(
		director.special_encounters_triggered.has(&"pincer"),
		"Pre-boss phase schedules a two-sided pincer encounter"
	)
	manager.elapsed_seconds = 655.0
	director._process(0.51)
	_check(
		director.arena_locked
		and not spawner.spawning_enabled
		and hud.boss_warning_label.text.contains("ARENA SEALED"),
		"Boss introduction seals the arena and stops normal spawning"
	)

	var base_lure_range := player.biomass_pickup_radius
	player.apply_biomass_lure()
	_check(
		base_lure_range >= 100.0
		and player.biomass_pickup_radius > base_lure_range,
		"Koda begins with a useful biomass lure and upgrades extend it"
	)

	player.configure_fleshdrive(FleshdriveCatalog.TELEKINETIC, 1)
	player.apply_upgrade(&"orbiting_debris")
	var near_enemy := CRAWLER_SCENE.instantiate() as Crawler
	var far_enemy := CRAWLER_SCENE.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(near_enemy)
	game.get_node("Entities/Enemies").add_child(far_enemy)
	near_enemy.global_position = player.global_position + Vector2(245.0, 0.0)
	far_enemy.global_position = player.global_position + Vector2(315.0, 0.0)
	player.weapon_system.capture_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.05)
	var capture: Dictionary = player.weapon_system.captured_enemies[0]
	_check(
		capture.get("enemy") == near_enemy
		and StringName(capture.get("phase")) == &"pulling"
		and near_enemy.external_impulse.dot(
			near_enemy.global_position.direction_to(
				player.global_position
			)
		) > 0.0,
		"Kinetic Captivity selects the nearest target and pulls it visibly"
	)
	player.weapon_system._release_all_captured_enemies()
	near_enemy.queue_free()
	far_enemy.queue_free()

	var crosshair := game.get_node_or_null(
		"UI/HUD/GameplayCrosshair"
	) as GameplayCrosshair
	_check(
		crosshair != null and crosshair.z_index >= 400,
		"Gameplay uses a precise high-layer crosshair"
	)

	var skill_tree := SKILL_TREE_SCENE.instantiate()
	var backdrop := skill_tree.get_node("Backdrop") as TextureRect
	var backdrop_shade := skill_tree.get_node("BackdropShade") as ColorRect
	var tree_shade := skill_tree.get_node(
		"TreeViewport/Background"
	) as ColorRect
	_check(
		backdrop.texture != null
		and backdrop.texture.resource_path.ends_with(
			"flesh_tree_background.png"
		)
		and backdrop.modulate.r >= 0.85
		and is_zero_approx(backdrop_shade.color.a)
		and is_zero_approx(tree_shade.color.a),
		"Flesh Tree shows its background without black overlay layers"
	)
	skill_tree.free()

	var main_menu := MAIN_MENU_SCENE.instantiate()
	var fullscreen := main_menu.find_child(
		"FullscreenToggle",
		true,
		false
	) as CheckButton
	_check(
		fullscreen != null
		and bool(fullscreen.get_meta("ui_polish_skip", false))
		and fullscreen.get_theme_color("font_color")
		!= fullscreen.get_theme_color("font_hover_color"),
		"Fullscreen toggle keeps the authored readable hover state"
	)
	main_menu.free()

	var telemetry := root.get_node("RunTelemetry")
	telemetry.start_run(&"electric")
	telemetry.record_player_damage(7.0, &"crawler", 34.0)
	telemetry.record_biomass_spawned(20.0)
	telemetry.record_biomass_collected(10.0)
	telemetry.record_kill(&"crawler", 35.0)
	telemetry.record_level_reached(4)
	telemetry.record_reroll(true, 2)
	telemetry.record_offer_skipped()
	telemetry.record_power_checkpoint(&"early", 28.0, 1.4, 2.2, 1.1)
	telemetry.record_runtime_sample(
		34.0,
		12,
		8,
		5,
		0.78,
		&"low_health"
	)
	var report: Dictionary = telemetry.finish_run(false, 50.0, &"crawler")
	_check(
		is_equal_approx(float(report["first_damage_seconds"]), 34.0)
		and is_equal_approx(float(report["biomass_missed"]), 10.0)
		and int(Dictionary(report["maxima"])["enemies"]) == 12
		and is_equal_approx(
			float(Dictionary(report["enemy_damage"])["crawler"]),
			7.0
		)
		and int(Dictionary(report["kills_by_enemy"])["crawler"]) == 1
		and int(report["highest_level"]) == 4
		and int(Dictionary(report["rerolls"])["currency_spent"]) == 2
		and int(report["offers_skipped"]) == 1
		and Array(report["power_checkpoints"]).size() == 1,
		"Run telemetry records pacing, missed pickups, damage and load peaks"
	)

	paused = false
	game.queue_free()
	await process_frame
	if failures == 0:
		print("ENCOUNTER DIRECTOR TEST PASSED")
		quit(0)
		return
	push_error("ENCOUNTER DIRECTOR TEST FAILED: %d failure(s)" % failures)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
