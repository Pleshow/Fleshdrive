extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const DEATH_VFX_SCENE := preload("res://Scenes/enemies/enemy_death_vfx.tscn")
const ARC_SPEAR_SCENE := preload("res://Scenes/player/arc_spear_projectile.tscn")
const MAGMA_SPEAR_SCENE := preload("res://Scenes/player/magma_spear_projectile.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	root.get_node("GameFlow").call("set_selected_arena", &"dusk_garden")
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var spawner := game.get_node("EnemySpawner")
	spawner.call("stop_spawning")
	var run_manager := game.get_node("RunManager") as RunManager
	if run_manager.state == RunManager.RunState.OPERATION:
		run_manager.exit_operation()
	paused = false

	var player := get_first_node_in_group("player") as Koda
	var sheet := player.get_character_sheet()
	var ids: Array[StringName] = []
	for row: Dictionary in sheet.get("stats", []):
		ids.append(StringName(row["id"]))
	_check(ids.size() == 10 and ids.has(&"lifesteal") and ids.has(&"ability_haste"), "Koda exposes the ten-stat extensible character sheet")
	_check(not Array(sheet.get("abilities", [])).is_empty(), "Koda's base ability is listed on the character sheet")

	var operation := game.get_node("UI/HUD/FleshdriveOperationScreen")
	_check(operation.get_node_or_null("CharacterSheetButton") != null and operation.get_node_or_null("CharacterSheetPanel") != null, "Fleshdrive implantation exposes Koda's character sheet")
	var hud := game.get_node("UI/HUD")
	hud.call("refresh_organ_overview")
	var organ_stats := game.get_node("UI/HUD/OrganScreen/StatsLabel") as Label
	_check(organ_stats.text.contains("ARMOR") and organ_stats.text.contains("LIFESTEAL") and organ_stats.text.contains("ABILITIES"), "Organ Screen shows all character-sheet categories and abilities")

	var death_vfx := DEATH_VFX_SCENE.instantiate() as EnemyDeathVFX
	game.add_child(death_vfx)
	await process_frame
	var death_animation := death_vfx.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var death_frames := death_animation.sprite_frames
	var first_death_frame := death_frames.get_frame_texture(&"death", 0) as AtlasTexture
	_check(death_frames.get_frame_count(&"death") == 12 and first_death_frame.atlas.resource_path.ends_with("organic_burst.png"), "Crawler death VFX contains an organic burst and no Charger silhouette")
	death_vfx.queue_free()

	var arc := ARC_SPEAR_SCENE.instantiate() as ArcSpearProjectile
	var magma := MAGMA_SPEAR_SCENE.instantiate() as MagmaSpearProjectile
	_check(is_equal_approx(arc.move_speed, 360.0) and is_equal_approx(magma.move_speed, 345.0) and is_equal_approx(PlayerWeaponSystem.PLAYER_PROJECTILE_SPEED_MULTIPLIER, 0.5), "Every Koda projectile path uses the requested 50 percent speed contract")
	arc.free()
	magma.free()

	var arena := game.get_node("Arena") as DuskGardenArena
	var wall := arena.get_node_or_null("SouthWallForeground")
	_check(wall != null and wall.get_child_count() >= 39 and (wall.get_child(0) as Sprite2D).z_index > 0, "South wall is segmented into a true foreground occluder")
	var wall_underlay := arena.get_node_or_null("SouthWallFloorUnderlay") as Sprite2D
	_check(
		wall_underlay != null
		and wall_underlay.z_index < 0
		and wall_underlay.texture.get_height() == 48
		and wall_underlay.position.y + wall_underlay.texture.get_height()
		<= arena.get_play_bounds().end.y,
		"South wall underlay stops at the playable edge instead of repeating floor outside the arena"
	)
	player.global_position = Vector2(1000.0, 1195.0)
	arena.call("_update_south_wall_occlusion")
	var faded_segment_found := false
	for child in wall.get_children():
		var segment := child as Sprite2D
		if (
			segment.modulate.a < 0.9
			and not is_zero_approx(segment.modulate.a)
		):
			faded_segment_found = true
			break
	_check(faded_segment_found, "Occupied south-wall segments return to the original even transparency")

	var crawler := (load("res://Scenes/enemies/crawler.tscn") as PackedScene).instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(crawler)
	crawler.global_position = Vector2(700.0, 650.0)
	await process_frame
	var visual_effects := root.get_node("VisualEffects")
	var electric_hit := visual_effects.call("play", &"electric_impact", Vector2(600.0, 600.0), 1.0) as AnimatedSprite2D
	var electric_frame := electric_hit.sprite_frames.get_frame_texture(&"play", 0) as AtlasTexture
	_check(electric_frame.region.position.y >= 64.0, "Autoattack lightning skips the sprite sheet's white-circle ghost frames")
	visual_effects.call("stop_effect", electric_hit)
	var visual_center := Vector2(visual_effects.call("_get_target_visual_center", crawler))
	_check(visual_center.is_equal_approx((crawler.get_node("AnimatedSprite2D") as AnimatedSprite2D).position), "Shock VFX centers on each enemy's authored sprite origin")
	var weapon_system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var saved_biomass := player.current_biomass
	var saved_requirement := player.biomass_required
	player.current_biomass = player.biomass_required
	weapon_system.volt_hound.overdrive_remaining = 0.5
	var level_before_charge := player.current_level
	_check(not player.call("_try_trigger_level_up") and player.current_level == level_before_charge and is_equal_approx(player.current_biomass, player.biomass_required), "Level-up waits without consuming biomass while Kinetic Charge is active")
	weapon_system.volt_hound.overdrive_remaining = 0.0
	player.current_biomass = saved_biomass
	player.biomass_required = saved_requirement
	weapon_system.call(
		"_launch_readable_projectile", crawler, 860.0, 1, 0.16, false,
		func(_target: Node2D) -> void: pass
	)
	var launched_projectile: ReadablePlayerProjectile
	for child in game.get_node("Entities/Attacks").get_children():
		if child is ReadablePlayerProjectile:
			launched_projectile = child
			break
	_check(launched_projectile != null and is_equal_approx(launched_projectile.speed, 430.0), "Ion Quill's runtime projectile speed is exactly halved")
	if launched_projectile != null:
		launched_projectile.queue_free()

	player.global_position = Vector2(500.0, 650.0)
	crawler.global_position = Vector2(700.0, 650.0)
	crawler.max_health = 1000.0
	crawler.current_health = 1000.0
	var second_crawler := (load("res://Scenes/enemies/crawler.tscn") as PackedScene).instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(second_crawler)
	second_crawler.global_position = Vector2(730.0, 650.0)
	second_crawler.max_health = 1000.0
	second_crawler.current_health = 1000.0
	weapon_system.call("_fire_kill_switch", 1)
	var kill_switch_vfx: AnimatedSprite2D
	for active_sprite in visual_effects.active_sprites:
		if is_instance_valid(active_sprite) and StringName(active_sprite.get_meta("effect_id", &"")) == &"electro_shock":
			kill_switch_vfx = active_sprite
	_check(kill_switch_vfx != null and kill_switch_vfx.global_position.distance_to(player.global_position) > 100.0 and (crawler.current_health < 1000.0 or second_crawler.current_health < 1000.0), "Kill Switch targets a nearby enemy cluster and places both AoE damage and VFX away from Koda")
	crawler.queue_free()
	second_crawler.queue_free()
	await process_frame

	player.global_position = Vector2(1280.0, 720.0)
	spawner.spawn_warning_duration = 0.05
	spawner.call("spawn_boss_reinforcements", 100)
	await process_frame
	await process_frame
	var ring_warnings := get_nodes_in_group("spawn_warnings")
	var min_radius := INF
	var max_radius := 0.0
	for warning_node in ring_warnings:
		var distance := (warning_node as Node2D).global_position.distance_to(player.global_position)
		min_radius = minf(min_radius, distance)
		max_radius = maxf(max_radius, distance)
	_check(ring_warnings.size() == 100 and max_radius - min_radius < 0.1, "Warden phase-two reinforcement telegraphs form an exact 100-enemy circle around Koda")
	await create_timer(0.08, false).timeout
	await process_frame
	var reinforcement_count := 0
	for enemy in get_nodes_in_group("enemies"):
		if bool(enemy.get_meta("boss_reinforcement", false)):
			reinforcement_count += 1
	_check(reinforcement_count == 100, "The stopped boss spawner still delivers all 100 phase-two reinforcements")
	for enemy in get_nodes_in_group("enemies"):
		if bool(enemy.get_meta("boss_reinforcement", false)):
			enemy.queue_free()
	await process_frame

	var bio := game.get_node("UI/HUD/BiofabricatorSequence") as BiofabricatorSequence
	bio.start(2, {
		"kills": 12,
		"damage_sources": {"base_arc": 120.0, "quill_burst": 80.0},
		"enemy_damage": {"crawler_contact": 40.0},
		"death_cause": "crawler_contact",
		"total_damage_dealt": 200.0,
		"damage_received": 40.0,
	}, {"runs": 1, "deaths": 1})
	await process_frame
	var stats_panel := bio.get_node_or_null("RunStatisticsPanel") as RunStatisticsPanel
	_check(stats_panel != null and stats_panel.visible and stats_panel.title_label.text == tr("RUN STATISTICS") and stats_panel.position == RunStatisticsPanel.COMPACT_POSITION and stats_panel.size.x <= 240.0 and stats_panel.size.y <= 205.0, "Refabrication installs a compact previous-run statistics card in the middle column")
	_check(stats_panel.find_children("*", "ProgressBar", true, false).is_empty() and bio.dialogue_panel.z_index > stats_panel.z_index, "Compact statistics show only headline numbers and never cover Mimichu dialogue")
	stats_panel.call("_toggle_expanded")
	_check(stats_panel.expanded and stats_panel.size == RunStatisticsPanel.EXPANDED_SIZE, "Run statistics expand into a detailed chart view")
	var dialogue := Array(bio.call("_get_mimichu_dialogue", 1))
	_check(dialogue.size() >= 3 and String(dialogue[1]["text"]).to_lower().contains("crawler"), "Mimichu explains statistics and reacts to a crawler death")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("REQUESTED FIXES REGRESSION TEST PASSED")
		quit(0)
	else:
		push_error("REQUESTED FIXES REGRESSION TEST FAILED: %d" % failures)
		quit(1)
