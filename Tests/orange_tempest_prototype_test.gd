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
	_check(packed != null, "Orange Tempest game scene loads")
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
	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var enemy := crawler_scene.instantiate() as Crawler
	game.get_node("Entities").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(140.0, 0.0)
	enemy.max_health = 5000.0
	enemy.current_health = enemy.max_health
	_check(
		not system.perform_thunder_god_attack(enemy),
		"Chain Lightning is unavailable before Arc Heart"
	)
	player.apply_upgrade(&"ball_lightning")
	player.apply_upgrade(&"ionized_membrane")
	player.apply_upgrade(&"plasma_expansion")
	player.apply_upgrade(&"static_replication")
	player.apply_upgrade(&"residual_charge")
	player.apply_upgrade(&"orbital_charge")
	player.apply_upgrade(&"electric_gravity")
	player.apply_upgrade(&"plasma_shepherd")
	player.apply_upgrade(&"star_collapse")
	player.apply_upgrade(&"chain_reactor")
	player.apply_upgrade(&"polarity_shift")
	var camera := player.get_node("Camera2D") as CameraFeedback
	camera.trauma = 0.0
	system._damage_enemy(
		enemy,
		8.0,
		true,
		&"ball_lightning",
		DamageEvent.HitRole.SECONDARY,
		false
	)
	_check(
		is_zero_approx(camera.trauma),
		"Ball Lightning damage does not add screen shake"
	)
	system.orange_tempest.update(0.05)
	await process_frame
	var orb_visual := system.orange_tempest.orbs[0]["visual"] as Node
	var visual_effects := root.get_node_or_null("VisualEffects")
	var ball_texture := load(
		"res://Assets/vfx/licensed/pixel_juice/ball_lightning_v1.png"
	) as Texture2D
	_check(
		system.orange_tempest.orbs.size() == 1
		and String(orb_visual.name) == "BallLightning"
		and visual_effects != null
		and visual_effects.has_effect(&"ball_lightning_idle")
		and ball_texture != null
		and orb_visual.get_node_or_null("ElectricGlow") == null
		and orb_visual.get_node_or_null("ElectricOutline") == null
		and system.orange_tempest.MAX_ORBS == 12,
		"Ball Lightning uses the authored v1 idle animation without generated rings"
	)
	var first := system.orange_tempest.orbs[0]
	system.orange_tempest._spawn_ball(true, Vector2(first["position"]) + Vector2(8.0, 0.0))
	system.orange_tempest.orbs[0]["charge"] = 3
	system.orange_tempest.orbs[1]["charge"] = 3
	system.orange_tempest._resolve_orb_proximity()
	_check(
		system.orange_tempest.orbs.size() == 1
		and bool(system.orange_tempest.orbs[0]["sun"]),
		"Two supercharged spheres collapse into a persistent Storm Core"
	)
	_check(
		StringName(system.get_active_skill_status().get("id", &"")) == &"polarity_shift"
		and bool(system.get_active_skill_status().get("ready", false))
		and system._activate_or_aim_active_skill(),
		"Polarity Shift appears on the HUD and activates through the active-skill input path"
	)
	_check(
		get_nodes_in_group("orange_tempest_vfx").size() > 0,
		"Ball Lightning exposes authored asset VFX nodes"
	)
	var expired_target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities").add_child(expired_target)
	expired_target.global_position = player.global_position + Vector2(90.0, 0.0)
	var target_orb: Dictionary = system.orange_tempest.orbs[0]
	target_orb["target"] = expired_target
	expired_target.free()
	system.orange_tempest._apply_orb_steering(target_orb, 0.016)
	var replacement_target: Variant = target_orb.get("target")
	_check(
		replacement_target == null or is_instance_valid(replacement_target),
		"Ball Lightning safely retargets when its tracked enemy is freed"
	)
	var drop_bonus_before := player.biomass_drop_chance_bonus
	player.apply_upgrade(&"scavenger_gland")
	_check(
		player.biomass_drop_chance_bonus > drop_bonus_before,
		"Scavenger Gland raises biomass drop chance"
	)
	var reflex := _find_upgrade(hud.upgrade_pool, &"reflex_cortex")
	player.current_level = 20
	player.apply_upgrade(&"reflex_cortex")
	player.remove_organ_upgrade(&"reflex_cortex")
	_check(
		reflex != null and not hud.is_upgrade_available(reflex),
		"Reflex Cortex never returns after it has been selected"
	)
	var charger_scene := load("res://Scenes/enemies/charger.tscn") as PackedScene
	var charger := charger_scene.instantiate() as Charger
	game.get_node("Entities").add_child(charger)
	await process_frame
	_check(
		charger.health_bar != null
		and charger.health_bar.max_value == charger.max_health
		and charger.health_bar.position.y < 0.0,
		"Chargers display a compact red health bar above their head"
	)
	var balance := CombatBalanceData.new()
	_check(
		float(balance.enemy_profiles[&"crawler"]["max_health"]) >= 30.0
		and float(balance.enemy_profiles[&"spitter"]["max_health"]) >= 54.0
		and float(balance.enemy_profiles[&"charger"]["max_health"]) >= 180.0
		and enemy.biomass_drop_chance < 1.0
		and charger.biomass_drop_chance < 1.0,
		"Fodder, ranged and elite durability preserve the authored power curve"
	)
	var ball := _find_upgrade(hud.upgrade_pool, &"ball_lightning")
	var arc := _find_upgrade(hud.upgrade_pool, &"arc_heart")
	player.apply_upgrade(&"arc_heart")
	_check(
		ball != null and arc != null
		and ball.prerequisites_met(player.upgrade_levels)
		and arc.prerequisites_met(player.upgrade_levels)
		and player.get_upgrade_level(&"ball_lightning") > 0
		and player.get_upgrade_level(&"arc_heart") > 0,
		"Ball Lightning is an additional weapon and coexists with Chain Lightning"
	)
	game.queue_free()
	await process_frame
	if failures == 0:
		print("ORANGE TEMPEST PROTOTYPE TEST PASSED")
	quit(failures)
