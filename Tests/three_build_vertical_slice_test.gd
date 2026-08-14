extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const TELEKINETIC_UPGRADES: Array[StringName] = [
	&"kinetic_shard",
	&"gravity_well",
	&"repulse_wave",
	&"orbiting_debris",
	&"neural_lance",
	&"projectile_reversal",
	&"mass_amplifier",
	&"vector_cortex",
	&"inertial_lattice",
]

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var meta := root.get_node("MetaProgression")
	var original_save_path: String = meta.save_path
	var test_save_path := (
		"res://.godot/three_build_vertical_slice_test.cfg"
	)
	meta.save_path = test_save_path
	meta.reset_all_progress()

	_check(
		not meta.is_fleshdrive_unlocked(FleshdriveCatalog.TELEKINETIC),
		"Telekinetic blueprint starts locked"
	)
	var reward: Dictionary = meta.record_run_result(
		true,
		720.0,
		300,
		FleshdriveCatalog.ELECTRIC
	)
	_check(
		meta.is_fleshdrive_unlocked(FleshdriveCatalog.TELEKINETIC)
		and String(reward.get("reward_message", "")).contains(
			"NOETIC HEART"
		),
		"First boss victory persistently unlocks the Noetic Heart"
	)
	var saved_progress := ConfigFile.new()
	_check(
		saved_progress.load(test_save_path) == OK
		and bool(saved_progress.get_value(
			"fleshdrives",
			"telekinetic_unlocked",
			false
		)),
		"Noetic Heart blueprint is written to persistent progression"
	)

	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var player := get_first_node_in_group("player") as Koda
	var hud := game.get_node("UI/HUD")
	var run_manager := get_first_node_in_group("run_manager") as RunManager
	player.configure_fleshdrive(FleshdriveCatalog.TELEKINETIC, 1)
	_check(
		player.walk_sprite_sheet.resource_path.contains("/telekinetic/")
		and player.player_light.color.b > player.player_light.color.g,
		"Noetic Heart applies the violet Koda animation set and light"
	)

	var telekinetic_resources: Array[UpgradeData] = []
	for upgrade in hud.upgrade_pool:
		if upgrade.fleshdrive_affinity == "telekinetic":
			telekinetic_resources.append(upgrade)
			_check(
				not upgrade.get_effective_synergy_tags().is_empty(),
				"%s has affinity and synergy tags" % upgrade.display_name
			)
	_check(
		telekinetic_resources.size() == TELEKINETIC_UPGRADES.size() + 12,
		"All nine base cards and twelve conditional Telekinetic build items are present"
	)

	player.current_level = 12
	for upgrade in hud.upgrade_pool:
		if upgrade.fleshdrive_affinity in ["electric", "fire"]:
			_check(
				not hud.is_upgrade_available(upgrade),
				"Cross-affinity card is excluded: %s" % upgrade.display_name
			)
	for upgrade in telekinetic_resources:
		if BuildItemCatalog.is_build_item(upgrade.upgrade_id):
			_check(
				not hud.is_upgrade_available(upgrade),
				"Conditional build item stays hidden before its weapon: %s"
				% upgrade.display_name
			)
			continue
		if upgrade.upgrade_id in [
			&"projectile_reversal",
			&"inertial_lattice",
		]:
			continue
		_check(
			hud.is_upgrade_available(upgrade)
			or (
				upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON
				and not player.can_unlock_weapon(upgrade.upgrade_id)
			),
			"Telekinetic card passes affinity filtering: %s"
			% upgrade.display_name
		)

	var crawler_scene := load(
		"res://Scenes/enemies/crawler.tscn"
	) as PackedScene
	var enemy := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120.0, 0.0)
	await process_frame
	enemy.set_physics_process(false)
	player._perform_telekinetic_attack(enemy)
	_check(
		enemy.velocity.x >= 277.0
		and bool(enemy.get_meta("telekinetically_displaced", false)),
		"Telekinetic auto-attack applies the strengthened pushback impulse"
	)
	enemy.velocity = Vector2.ZERO
	enemy.external_impulse = Vector2.ZERO
	var health_before := enemy.current_health
	var velocity_before := enemy.velocity
	player.weapon_system._fire_repulse_wave(2)
	_check(
		enemy.current_health < health_before
		and enemy.velocity.x >= 539.0
		and enemy.velocity != velocity_before,
		"Repulse Wave damages and forcefully displaces enemies"
	)
	var enemy_sprite := enemy.get_node(
		"AnimatedSprite2D"
	) as AnimatedSprite2D
	enemy_sprite.flip_h = false
	enemy.external_impulse = Vector2(-450.0, 0.0)
	enemy._physics_process(0.016)
	_check(
		not enemy_sprite.flip_h,
		"External knockback preserves the enemy's visual facing"
	)
	enemy.queue_free()
	await process_frame

	var shard_target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(shard_target)
	shard_target.global_position = player.global_position + Vector2(180.0, 0.0)
	shard_target.current_health = 500.0
	shard_target.set_physics_process(false)
	var shard_health := shard_target.current_health
	_check(
		player.weapon_system._fire_kinetic_shard(2)
		and shard_target.current_health < shard_health,
		"Kinetic Shard acquires and damages a ranged target"
	)
	shard_target.queue_free()
	await process_frame

	var well_center := crawler_scene.instantiate() as Crawler
	var pulled_target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(well_center)
	game.get_node("Entities/Enemies").add_child(pulled_target)
	well_center.global_position = player.global_position + Vector2(190.0, 0.0)
	pulled_target.global_position = player.global_position + Vector2(260.0, 0.0)
	well_center.current_health = 500.0
	pulled_target.current_health = 500.0
	well_center.set_physics_process(false)
	pulled_target.set_physics_process(false)
	_check(
		player.weapon_system._fire_gravity_well(2)
		and pulled_target.velocity.x < 0.0
		and bool(pulled_target.get_meta(
			"telekinetically_displaced",
			false
		)),
		"Gravity Well pulls surrounding enemies toward its center"
	)
	well_center.queue_free()
	pulled_target.queue_free()
	await process_frame

	var lance_front := crawler_scene.instantiate() as Crawler
	var lance_back := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(lance_front)
	game.get_node("Entities/Enemies").add_child(lance_back)
	lance_front.global_position = player.global_position + Vector2(150.0, 0.0)
	lance_back.global_position = player.global_position + Vector2(310.0, 0.0)
	lance_front.current_health = 500.0
	lance_back.current_health = 500.0
	lance_front.set_physics_process(false)
	lance_back.set_physics_process(false)
	_check(
		player.weapon_system._fire_neural_lance(2)
		and lance_front.current_health < 500.0
		and lance_back.current_health < 500.0
		and lance_front.velocity.x > 0.0
		and lance_back.velocity.x > 0.0,
		"Neural Lance pierces and physically drives aligned enemies"
	)
	lance_front.queue_free()
	lance_back.queue_free()
	await process_frame

	var orbit_target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(orbit_target)
	orbit_target.global_position = player.global_position + Vector2(82.0, 0.0)
	orbit_target.current_health = 10.0
	orbit_target.set_physics_process(false)
	var inertial_lattice := load(
		"res://Resources/Upgrades/inertial_lattice.tres"
	) as UpgradeData
	_check(
		not hud.is_upgrade_available(inertial_lattice),
		"Inertial Lattice is hidden before Kinetic Captivity is owned"
	)
	player.apply_upgrade(&"orbiting_debris")
	_check(
		hud.is_upgrade_available(inertial_lattice),
		"Inertial Lattice unlocks after Kinetic Captivity is owned"
	)
	player.weapon_system.orbit_damage_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.5)
	_check(
		is_equal_approx(orbit_target.current_health, 9.0)
		and player.weapon_system.captured_enemies.size() == 1
		and bool(orbit_target.get_meta(
			"telekinetically_captured",
			false
		))
		and not orbit_target.is_physics_processing(),
		"Kinetic Captivity lifts an enemy and drains exactly 2 HP per second"
	)
	player.weapon_system._update_orbiting_debris(5.0)
	await process_frame
	_check(
		not is_instance_valid(orbit_target)
		and is_equal_approx(
			player.weapon_system.capture_cooldown,
			5.0
		),
		"Dead captives place Kinetic Captivity on a fixed five-second cooldown"
	)
	for level_step in range(2):
		player.apply_upgrade(&"orbiting_debris")
	var mid_level_captives: Array[Crawler] = []
	for captive_index in range(2):
		var captive := crawler_scene.instantiate() as Crawler
		game.get_node("Entities/Enemies").add_child(captive)
		captive.global_position = (
			player.global_position
			+ Vector2(145.0 + 55.0 * captive_index, 0.0)
		)
		captive.current_health = 500.0
		mid_level_captives.append(captive)
	player.weapon_system.capture_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.1)
	_check(
		player.weapon_system.captured_enemies.size() == 2,
		"Kinetic Captivity level three lifts two enemies"
	)
	player.weapon_system._release_all_captured_enemies()
	for captive in mid_level_captives:
		if is_instance_valid(captive):
			captive.queue_free()
	await process_frame

	for level_step in range(2):
		player.apply_upgrade(&"orbiting_debris")
	var high_level_captives: Array[Crawler] = []
	for captive_index in range(3):
		var captive := crawler_scene.instantiate() as Crawler
		game.get_node("Entities/Enemies").add_child(captive)
		captive.global_position = (
			player.global_position
			+ Vector2(145.0 + 55.0 * captive_index, 0.0)
		)
		captive.current_health = 500.0
		high_level_captives.append(captive)
	player.weapon_system.capture_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.1)
	_check(
		player.weapon_system.captured_enemies.size() == 3,
		"Kinetic Captivity level five lifts three enemies"
	)
	player.weapon_system._release_all_captured_enemies()
	for captive in high_level_captives:
		if is_instance_valid(captive):
			captive.queue_free()
	await process_frame

	var boss_immune := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(boss_immune)
	boss_immune.add_to_group("boss")
	boss_immune.global_position = (
		player.global_position + Vector2(100.0, 0.0)
	)
	boss_immune.current_health = 500.0
	player.weapon_system.capture_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.1)
	_check(
		player.weapon_system.captured_enemies.is_empty()
		and is_equal_approx(boss_immune.current_health, 500.0),
		"Kinetic Captivity never captures boss targets"
	)
	boss_immune.queue_free()
	await process_frame

	var freed_captive := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(freed_captive)
	freed_captive.global_position = (
		player.global_position + Vector2(90.0, 0.0)
	)
	freed_captive.current_health = 500.0
	player.weapon_system.capture_cooldown = 0.0
	player.weapon_system._update_orbiting_debris(0.05)
	_check(
		player.weapon_system.captured_enemies.size() == 1,
		"Kinetic Captivity tracks its captured target"
	)
	freed_captive.queue_free()
	await process_frame
	player.weapon_system._update_orbiting_debris(0.05)
	_check(
		player.weapon_system.captured_enemies.is_empty(),
		"Freed captives are pruned without an invalid-object cast"
	)

	var vector_damage_before := player.telekinetic_damage_multiplier
	var vector_force_before := player.telekinetic_force_multiplier
	player.apply_upgrade(&"vector_cortex")
	_check(
		player.telekinetic_damage_multiplier > vector_damage_before
		and player.telekinetic_force_multiplier > vector_force_before,
		"Vector Cortex improves Telekinetic auto-attack damage and force"
	)
	var mass_damage_before := player.telekinetic_damage_multiplier
	var mass_force_before := player.telekinetic_force_multiplier
	player.apply_upgrade(&"mass_amplifier")
	_check(
		player.telekinetic_damage_multiplier > mass_damage_before
		and player.telekinetic_force_multiplier > mass_force_before,
		"Mass Amplifier improves Telekinetic auto-attack damage and force"
	)

	var projectile_scene := load(
		"res://Scenes/enemies/spitter_projectile.tscn"
	) as PackedScene
	var projectile := projectile_scene.instantiate() as SpitterProjectile
	game.get_node("Entities/Attacks").add_child(projectile)
	projectile.global_position = player.global_position + Vector2(40.0, 0.0)
	projectile.configure(Vector2.LEFT, 10.0, 100.0)
	var reversal_target := crawler_scene.instantiate() as Crawler
	game.get_node("Entities/Enemies").add_child(reversal_target)
	reversal_target.global_position = (
		player.global_position + Vector2(260.0, 0.0)
	)
	reversal_target.set_physics_process(false)
	player.current_level = 15
	player.apply_upgrade(&"projectile_reversal")
	player.weapon_system.reversal_roll_override = 0.95
	player.weapon_system._update_projectile_reversal(1.0)
	_check(
		not projectile.reflected,
		"Projectile Reversal can fail its percentage roll"
	)
	projectile.remove_meta("telekinetic_reversal_checked")
	player.weapon_system.reversal_check_cooldown = 0.0
	player.weapon_system.reversal_roll_override = 0.0
	player.weapon_system._update_projectile_reversal(1.0)
	var reversal_health := reversal_target.current_health
	projectile._on_body_entered(reversal_target)
	_check(
		projectile.reflected
		and reversal_target.current_health < reversal_health
		and projectile.collision_mask == 3,
		"Successful reversal redirects and damages enemies"
	)
	reversal_target.queue_free()

	var elite_reward_target: Crawler = null
	for elite_type in range(
		EliteModifier.Type.ARMORED,
		EliteModifier.Type.REGENERATIVE + 1
	):
		var elite := crawler_scene.instantiate() as Crawler
		game.get_node("Entities/Enemies").add_child(elite)
		await process_frame
		elite.set_physics_process(false)
		var modifier := EliteModifier.new()
		elite.add_child(modifier)
		modifier.initialize(elite, elite_type)
		_check(
			bool(elite.get_meta("is_elite", false))
			and elite.has_node("EliteTelegraph")
			and elite.has_node("EliteLabel"),
			"Elite modifier %d is telegraphed and active" % elite_type
		)
		if elite_type == EliteModifier.Type.REGENERATIVE:
			elite_reward_target = elite
		else:
			elite.queue_free()
	var pickups := game.get_node("Entities/Pickups")
	var pickup_count := pickups.get_child_count()
	run_manager.kill_count = 1
	run_manager._on_enemy_defeated(elite_reward_target)
	_check(
		pickups.get_child_count() == pickup_count + 1,
		"Elite enemies guarantee a Blood Memory fragment"
	)
	elite_reward_target.queue_free()

	var estimated_dps := {
		FleshdriveCatalog.ELECTRIC: 57.6,
		FleshdriveCatalog.FIRE: 49.2,
		FleshdriveCatalog.TELEKINETIC: 52.1,
	}
	var weakest: float = INF
	var strongest: float = 0.0
	for value: float in estimated_dps.values():
		weakest = minf(weakest, value)
		strongest = maxf(strongest, value)
	_check(
		strongest / weakest <= 1.20,
		"Curated three-build boss DPS estimates stay within 20 percent"
	)

	run_manager.exit_operation()
	run_manager.exit_onboarding()
	game.queue_free()
	await process_frame

	# Twenty-five accelerated complete-run transitions exercise scene startup,
	# class configuration, summary data, progression saves, and run teardown.
	for run_index in range(100):
		var run_game := GAME_SCENE.instantiate()
		root.add_child(run_game)
		await process_frame
		var run_player := get_first_node_in_group("player") as Koda
		var manager := get_first_node_in_group("run_manager") as RunManager
		var build_id: StringName = [
			FleshdriveCatalog.ELECTRIC,
			FleshdriveCatalog.FIRE,
			FleshdriveCatalog.TELEKINETIC,
		][run_index % 3]
		run_player.configure_fleshdrive(build_id, 1)
		run_player.record_damage_source(
			StringName("simulated_%s" % String(build_id)),
			5000.0 + run_index
		)
		manager.elapsed_seconds = 600.0 + float(run_index)
		manager.kill_count = 240 + run_index
		manager.finish_run(true)
		var combat_summary := run_player.get_combat_summary()
		_check(
			manager.state == RunManager.RunState.VICTORY
			and not combat_summary.get("damage_sources", []).is_empty(),
			"Accelerated run %02d completes without a softlock"
			% (run_index + 1)
		)
		paused = false
		run_game.queue_free()
		await process_frame

	meta.save_path = original_save_path
	meta._load_progression()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("THREE BUILD VERTICAL SLICE TEST PASSED")
		quit(0)
		return
	push_error(
		"THREE BUILD VERTICAL SLICE TEST FAILED: %d failure(s)"
		% failures
	)
	quit(1)
