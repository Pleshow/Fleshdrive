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


func _find_upgrade(pool: Array[UpgradeData], id: StringName) -> UpgradeData:
	for upgrade in pool:
		if upgrade != null and upgrade.upgrade_id == id:
			return upgrade
	return null


func _run() -> void:
	var packed := load("res://Scenes/game.tscn") as PackedScene
	_check(packed != null, "Volt Hound game scene loads")
	if packed == null:
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	paused = false
	game.get_node("EnemySpawner").stop_spawning()
	var player := game.get_node("Entities/Koda") as Koda
	var system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var hud := game.get_node("UI/HUD")
	player.current_level = 20
	player.apply_upgrade(&"ball_lightning")
	player.current_level = 24
	player.apply_upgrade(&"static_claws")
	player.apply_upgrade(&"arc_heart")
	_check(
		player.get_upgrade_level(&"ball_lightning") == 1
		and player.get_upgrade_level(&"static_claws") == 1
		and player.chain_unlocked,
		"Chain, Ball and Static Lightning can coexist in one Voltaic run"
	)
	_check(player.dash_unlocked, "Static Claws unlocks the Volt Hound combat dash")
	player.velocity = Vector2(210.0, 0.0)
	system.volt_hound.update(1.0)
	_check(
		system.volt_hound.momentum >= 6.0
		and system.volt_hound.momentum_layer.visible,
		"Movement builds Momentum and exposes the dedicated HUD meter"
	)
	for id in [
		&"voltaic_tendons", &"phantom_current", &"predators_static",
		&"flash_step", &"magnetic_predator", &"nerve_overclock",
		&"lightspeed", &"capacitor_marrow", &"predator_coil",
		&"charged_paw_pads", &"ionized_spine", &"purple_heart",
		&"double_exposure", &"ballistic_nervous_system",
	]:
		player.apply_upgrade(id)
	system.volt_hound.momentum = 100.0
	system.volt_hound.update(0.01)
	_check(
		system.volt_hound.ready
		and is_zero_approx(system.volt_hound.overdrive_remaining),
		"100 Momentum arms Kinetic Overdrive without spending it early"
	)
	player.is_dashing = true
	system.volt_hound.update(0.01)
	_check(
		system.volt_hound.overdrive_remaining >= 2.4
		and system.volt_hound.movement_multiplier() > 1.3
		and is_equal_approx(
			system.volt_hound.dash_cooldown_multiplier(), 0.72
		)
		and is_zero_approx(system.volt_hound.modify_incoming_damage(null, 10.0)),
		"A full-charge dash spends READY and grants the complete Overdrive benefits"
	)
	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var enemy := crawler_scene.instantiate() as Crawler
	game.get_node("Entities").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(70.0, 0.0)
	enemy.max_health = 5000.0
	enemy.current_health = enemy.max_health
	var hp_before := enemy.current_health
	system.volt_hound._process_dash_segment(
		player.global_position, player.global_position + Vector2(140.0, 0.0), false
	)
	_check(
		enemy.current_health < hp_before
		and system.volt_hound.static_marks.has(enemy.get_instance_id()),
		"Dash traversal deals Momentum-scaled damage and applies Static Mark"
	)
	system.volt_hound.contact_cooldowns.clear()
	var marked_hp := enemy.current_health
	system.volt_hound._process_dash_segment(
		player.global_position, player.global_position + Vector2(140.0, 0.0), false
	)
	_check(
		not system.volt_hound.static_marks.has(enemy.get_instance_id())
		and enemy.current_health < marked_hp,
		"A second pass detonates Static Mark"
	)
	system.volt_hound.contact_cooldowns.clear()
	system.volt_hound._finish_dash_path(
		player.global_position, player.global_position + Vector2(140.0, 0.0)
	)
	_check(
		system.volt_hound.afterimages.size() > 0
		and get_nodes_in_group("volt_hound_vfx").size() > 0,
		"Phantom Current records a readable magenta afterimage route"
	)
	var arc := _find_upgrade(hud.upgrade_pool, &"arc_heart")
	var ball := _find_upgrade(hud.upgrade_pool, &"ball_lightning")
	var claws := _find_upgrade(hud.upgrade_pool, &"static_claws")
	var organ := _find_upgrade(hud.upgrade_pool, &"impulse_gland")
	var universal := _find_upgrade(hud.upgrade_pool, &"scavenger_gland")
	_check(
		arc != null and ball != null and claws != null
		and hud._get_upgrade_card_color(arc) == Color("329dff")
		and hud._get_upgrade_card_color(ball) == Color("258cff")
		and hud._get_upgrade_card_color(claws) == Color("a84dff"),
		"Voltaic weapon cards use coherent blue and violet build colors"
	)
	_check(
		organ != null and universal != null
		and hud._get_upgrade_card_color(organ) == Color("ff5b9f")
		and hud._get_upgrade_card_color(universal) == Color(0.55, 0.58, 0.62),
		"Unaffiliated organs are pink and general cards are neutral gray"
	)
	game.queue_free()
	await process_frame
	if failures == 0:
		print("VOLT HOUND PROTOTYPE TEST PASSED")
	quit(failures)
