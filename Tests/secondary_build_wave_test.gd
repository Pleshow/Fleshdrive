extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const FIREBALL_SCENE := preload("res://Scenes/player/fireball_projectile.tscn")
const DEBUG_LOADOUTS := preload("res://Scripts/debug/build_debug_loadouts.gd")

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
	_validate_catalog_and_resources()
	await _validate_fireball_and_loadouts()
	if failures == 0:
		print("SECONDARY BUILD WAVE TEST PASSED")
	quit(failures)


func _validate_catalog_and_resources() -> void:
	var pool: Array[UpgradeData] = []
	UpgradeRegistry.append_build_items(pool)
	_check(pool.size() == 36, "All Phase A and Phase C resources load")
	var build_counts: Dictionary = {}
	for upgrade in pool:
		build_counts[upgrade.build_archetype] = int(build_counts.get(upgrade.build_archetype, 0)) + 1
		_check(upgrade.offer_weight > 0.0, "%s has explicit offer weight" % upgrade.upgrade_id)
		_check(not upgrade.required_weapons.is_empty(), "%s has explicit weapon prerequisite" % upgrade.upgrade_id)
		_check(not upgrade.prerequisites_met({}), "%s cannot appear without its weapon" % upgrade.upgrade_id)
		_check(upgrade.prerequisites_met({upgrade.required_weapons[0]: 1}), "%s appears with its weapon" % upgrade.upgrade_id)
	for build_id in BuildItemCatalog.BUILD_IDS:
		_check(int(build_counts.get(build_id, 0)) == 3, "%s has exactly three cards" % build_id)
	_check(is_equal_approx(BuildItemCatalog.value(&"linear_inductor", "damage"), 0.65), "Rail Predator damage matches workbook")
	_check(is_equal_approx(BuildItemCatalog.value(&"obsidian_throat", "lane_duration"), 3.0), "Magma lane duration matches workbook")
	_check(is_equal_approx(BuildItemCatalog.value(&"execution_fold", "threshold"), 0.20), "Captive execute threshold matches workbook")
	_check(is_equal_approx(BuildItemCatalog.value(&"thought_echo", "delay"), 0.45), "Neural echo delay matches workbook")


func _validate_fireball_and_loadouts() -> void:
	var projectile := FIREBALL_SCENE.instantiate() as FireballProjectile
	_check(projectile != null, "Fire Heart base attack uses a dedicated projectile scene")
	if projectile != null:
		_check(projectile.collision_mask == 2, "Fireball collides with enemy bodies")
		_check(projectile.move_speed > 0.0, "Fireball has real travel speed")
		projectile.free()

	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var player := get_first_node_in_group("player") as Koda
	var hud := game.get_node("UI/HUD")
	player.current_level = 20
	for affinity in [FleshdriveCatalog.ELECTRIC, FleshdriveCatalog.FIRE, FleshdriveCatalog.TELEKINETIC]:
		player.configure_fleshdrive(affinity, 1)
		for build_id in BuildItemCatalog.BUILD_IDS:
			for upgrade in hud.upgrade_pool:
				if upgrade.build_archetype != build_id or upgrade.fleshdrive_affinity != String(affinity):
					continue
				player.upgrade_levels[upgrade.required_weapons[0]] = 1
				_check(hud.is_upgrade_available(upgrade), "%s deterministic loadout card is offerable" % upgrade.upgrade_id)
				player.upgrade_levels.erase(upgrade.required_weapons[0])
	for build_id in BuildItemCatalog.BUILD_IDS:
		_check(DEBUG_LOADOUTS.apply_to(player, build_id), "%s debug loadout applies deterministically" % build_id)
	_check(is_equal_approx(player.weapon_system.build_runtime.arc_damage_multiplier(), 1.0), "Non-rail debug loadout clears into its own state")
	DEBUG_LOADOUTS.apply_to(player, &"rail_predator")
	_check(is_equal_approx(player.weapon_system.build_runtime.arc_damage_multiplier(), 1.65), "Rail Predator applies the exact rail damage modifier")
	DEBUG_LOADOUTS.apply_to(player, &"quill_tempest")
	_check(player.weapon_system.build_runtime.quill_projectile_count_bonus() == 3, "Quill Tempest level five gains three projectiles")
	DEBUG_LOADOUTS.apply_to(player, &"magma_artillery")
	player.weapon_system.build_runtime.update(4.6)
	_check(player.weapon_system.build_runtime.magma_damage_multiplier() > 3.0, "Magma Artillery consumes stored Pressure into its shot")
	DEBUG_LOADOUTS.apply_to(player, &"captive_moon")
	_check(player.weapon_system.build_runtime.orbit_capacity_bonus() == 2, "Captive Moon gains two capture slots")
	DEBUG_LOADOUTS.apply_to(player, &"neural_executioner")
	_check(player.weapon_system.build_runtime.neural_damage_multiplier(660.0) >= 3.5, "Neural Executioner combines rail and distance scaling")

	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(target)
	target.global_position = player.global_position + Vector2(180.0, 0.0)
	target.set_physics_process(false)
	player.configure_fleshdrive(FleshdriveCatalog.FIRE, 1)
	var before_fire := target.current_health
	player._perform_fire_attack(target)
	_check(is_equal_approx(target.current_health, before_fire), "Fireball does not apply instant tracer damage")
	var live_fireball := get_first_node_in_group("player_projectiles") as FireballProjectile
	_check(live_fireball != null, "Fire auto-attack spawns a live projectile node")
	if live_fireball != null:
		var start_position := live_fireball.global_position
		live_fireball._physics_process(0.10)
		_check(live_fireball.global_position.distance_to(start_position) > 40.0, "Fireball advances through world space")
		live_fireball._on_body_entered(target)
		_check(target.current_health < before_fire, "Fireball collision damages its target through the combat pipeline")
	game.queue_free()
	await process_frame
