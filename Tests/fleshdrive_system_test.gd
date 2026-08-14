extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_game := load("res://Scenes/game.tscn") as PackedScene
	_check(packed_game != null, "Game scene loads with Fleshdrive resources")
	if packed_game == null:
		_finish()
		return
	var game := packed_game.instantiate()
	root.add_child(game)
	await process_frame
	var player := get_first_node_in_group("player") as Koda
	var hud := game.get_node("UI/HUD")
	var run_manager := game.get_node("RunManager") as RunManager
	var spawner := game.get_node("EnemySpawner")
	spawner.stop_spawning()

	_check(
		run_manager.state == RunManager.RunState.OPERATION
		and hud.fleshdrive_operation_screen.visible,
		"Operation screen blocks the run until a class is selected"
	)
	hud._on_fleshdrive_selected(FleshdriveCatalog.FIRE)
	_check(
		player.active_fleshdrive_id == FleshdriveCatalog.FIRE
		and player.player_light.color.r > player.player_light.color.b,
		"Pyre Heart changes Koda's sprites and light palette"
	)
	hud.complete_onboarding()
	await process_frame
	var weapon_system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var freed_burn_target := Node2D.new()
	root.add_child(freed_burn_target)
	weapon_system.apply_burn(freed_burn_target, 2.0, 3.0)
	var freed_burn_target_id := freed_burn_target.get_instance_id()
	freed_burn_target.free()
	weapon_system._update_burns(0.1)
	_check(
		not weapon_system.active_burns.has(freed_burn_target_id),
		"Burn tracking safely discards enemies freed between damage ticks"
	)
	var burn_audio_target_scene := load(
		"res://Scenes/enemies/crawler.tscn"
	) as PackedScene
	var burn_audio_target := burn_audio_target_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(burn_audio_target)
	await process_frame
	burn_audio_target.set_physics_process(false)
	var audio_effects := root.get_node_or_null("AudioEffects")
	audio_effects.call("clear_play_counts")
	weapon_system._damage_enemy(burn_audio_target, 1.0, false)
	_check(
		audio_effects.call("get_play_count", &"enemy_hit") == 0,
		"Periodic burn damage does not play the enemy hit sound"
	)
	weapon_system._damage_enemy(burn_audio_target, 1.0)
	_check(
		audio_effects.call("get_play_count", &"enemy_hit") == 1,
		"Direct weapon damage keeps the enemy hit sound"
	)
	burn_audio_target.queue_free()
	var fire_ids := [
		&"cinder_volley",
		&"blazing_stride",
		&"inferno_ring",
		&"magma_spear",
		&"ashen_eruption",
		&"combustion_sac",
		&"thermal_lattice",
		&"cauterizing_blood",
		&"flashpoint_nodes",
	]
	for upgrade_id: StringName in fire_ids:
		var upgrade := _find_upgrade(hud.upgrade_pool, upgrade_id)
		_check(
			upgrade != null
			and upgrade.fleshdrive_affinity == "fire"
			and hud.is_upgrade_available(upgrade)
			== (
				player.current_level >= upgrade.minimum_player_level
				and (
					upgrade.upgrade_kind
					!= UpgradeData.UpgradeKind.WEAPON
					or player.can_unlock_weapon(upgrade_id)
				)
			),
			"%s belongs to the Fire build path" % upgrade_id
		)
	var electric_upgrade := _find_upgrade(hud.upgrade_pool, &"arc_spear")
	_check(
		not hud.is_upgrade_available(electric_upgrade),
		"Electric cards are excluded from a Fire run"
	)
	var visual_effects := root.get_node_or_null("VisualEffects")
	_check(
		visual_effects.call("has_effect", &"fire_impact")
		and visual_effects.call("has_effect", &"fire_muzzle")
		and visual_effects.call("has_effect", &"inferno_ring")
		and visual_effects.call("has_effect", &"ashen_eruption"),
		"Fire build exposes its own animated VFX set"
	)
	var core_panel := hud.get_node("OrganScreen/FleshdrivePanel")
	hud.refresh_organ_overview()
	_check(
		core_panel.tooltip_text.contains("PYRE HEART")
		and hud.fleshdrive_name_label.text == "PYRE HEART",
		"Organ Screen shows active Core level, build and hover details"
	)

	paused = false
	game.queue_free()
	await process_frame
	_finish()


func _find_upgrade(
	pool: Array[UpgradeData],
	upgrade_id: StringName
) -> UpgradeData:
	for upgrade in pool:
		if upgrade != null and upgrade.upgrade_id == upgrade_id:
			return upgrade
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failure_count == 0:
		print("FLESHDRIVE SYSTEM TEST PASSED")
		quit(0)
		return
	push_error(
		"FLESHDRIVE SYSTEM TEST FAILED: %d failure(s)" % failure_count
	)
	quit(1)
