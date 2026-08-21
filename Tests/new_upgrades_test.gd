extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_game := load("res://Scenes/game.tscn") as PackedScene
	var game := packed_game.instantiate()
	root.add_child(game)
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var hud := game.get_node("UI/HUD")
	var spawner := game.get_node("EnemySpawner")
	var enemies := game.get_node("Entities/Enemies")
	var visual_effects := root.get_node_or_null("VisualEffects")
	spawner.stop_spawning()
	hud._on_fleshdrive_selected(FleshdriveCatalog.ELECTRIC)
	hud.complete_onboarding()
	await process_frame
	_check(
		visual_effects != null
		and visual_effects.call("has_effect", &"electric_impact")
		and visual_effects.call("has_effect", &"electro_shock")
		and visual_effects.call("has_effect", &"slash_circular")
		and visual_effects.call("has_effect", &"arc_muzzle")
		and visual_effects.call("has_effect", &"spitter_impact")
		and visual_effects.call("has_effect", &"charger_impact")
		and visual_effects.call("has_effect", &"boss_slam")
		and visual_effects.call("has_effect", &"boss_death"),
		"Generated player, enemy and boss VFX are available"
	)
	var stats_panel := hud.get_node("OrganScreen/StatsBackground") as Control
	var weapons_panel := hud.get_node("OrganScreen/WeaponsBackground") as Control
	var items_panel := hud.get_node("OrganScreen/ItemsBackground") as Control
	var right_panel := hud.get_node("OrganScreen/RightBackground") as Control
	var brain_slot := hud.get_node("OrganScreen/BrainSlot") as Control
	var heart_slot := hud.get_node("OrganScreen/HeartSlot") as Control
	var legs_slot := hud.get_node("OrganScreen/LegsSlot") as Control
	_check(
		stats_panel.position.x < 20.0
		and stats_panel.position.y < 30.0
		and stats_panel.position.y + stats_panel.size.y
		<= weapons_panel.position.y,
		"Organ Screen keeps stats in a non-overlapping left column"
	)
	_check(
		weapons_panel.position.x + weapons_panel.size.x
		<= items_panel.position.x,
		"Weapon and item loadout boxes are separated"
	)
	_check(
		right_panel.position.x >= 900.0
		and right_panel.position.y + right_panel.size.y
		<= weapons_panel.position.y
		and hud.get_node_or_null("OrganScreen/FleshdrivePanel") != null,
		"Pending organs and the active Fleshdrive use the right column"
	)
	_check(
		(brain_slot.position + brain_slot.size * 0.5).distance_to(
			Vector2(407.0, 317.5)
		) < 2.0
		and (heart_slot.position + heart_slot.size * 0.5).distance_to(
			Vector2(556.0, 402.0)
		) < 2.0
		and (legs_slot.position + legs_slot.size * 0.5).distance_to(
			Vector2(387.0, 535.5)
		) < 2.0,
		"Active organ slots align with Koda's head, torso and front leg"
	)

	var expected_upgrades: Dictionary = {
		&"biomass_lure": "res://Assets/ui/items/07_biomass_lure.png",
		&"hemo_recycler": "res://Assets/ui/items/08_hemo_recycler.png",
		&"overload_vent": "res://Assets/ui/items/09_overload_vent.png",
		&"kill_switch_nodes": "res://Assets/ui/items/10_kill_switch_nodes.png",
		&"reflex_spurs": "res://Assets/ui/items/11_reflex_spurs.png",
		&"quill_burst": "res://Assets/ui/weapons/electric/ion_quill.png",
		&"shock_ram": "res://Assets/ui/weapons/electric/shock_ram.png",
		&"tail_lash": "res://Assets/ui/weapons/electric/tesla_lash.png",
		&"arc_spear": "res://Assets/ui/weapons/electric/arc_spear.png",
		&"bone_shard_volley": "res://Assets/ui/weapons/electric/volt_shard_volley.png",
	}

	for upgrade_id: StringName in expected_upgrades:
		var upgrade := _find_upgrade(hud.upgrade_pool, upgrade_id)
		_check(upgrade != null, "%s is in the upgrade pool" % upgrade_id)
		if upgrade != null:
			_check(
				upgrade.card_texture.resource_path == expected_upgrades[upgrade_id],
				"%s uses its supplied card" % upgrade_id
			)
			_check(upgrade.max_level > 1, "%s supports level scaling" % upgrade_id)

	player.current_level = 6
	hud.show_level_up_panel(6)
	var levels_before := player.upgrade_levels.duplicate()
	hud.on_upgrade_selected(0)
	_check(
		player.upgrade_levels == levels_before
		and hud.level_up_panel.visible
		and hud.selected_upgrade_card_index == 0
		and hud.upgrade_confirm_button.visible,
		"Cards select immediately without applying before confirmation"
	)
	_check(
		not hud.card_selection_locked
		and not hud.upgrade_card_1.disabled
		and hud.upgrade_confirm_button.has_focus(),
		"Card confirmation is immediately available"
	)
	hud.level_up_panel.hide()
	game.get_node("RunManager").exit_level_up()
	player.confirm_level_up()

	var lure_radius_before := player.biomass_pickup_radius
	player.apply_upgrade(&"biomass_lure")
	_check(
		player.biomass_pickup_radius > lure_radius_before,
		"Biomass Lure expands pickup attraction"
	)

	player.take_damage(30.0)
	var health_before_heal := player.current_health
	player.apply_upgrade(&"hemo_recycler")
	player.register_enemy_kill(12)
	_check(
		player.current_health > health_before_heal,
		"Hemo Recycler heals on its kill cadence"
	)
	player.apply_upgrade(&"scavenger_stomach")
	player.current_health = player.max_health - 10.0
	var health_before_scavenging := player.current_health
	for _pickup in range(15):
		player.weapon_system.notify_biomass_collected()
	_check(
		is_equal_approx(
			player.current_health,
			health_before_scavenging + 5.0
		),
		"Scavenger Stomach restores five health every fifteenth biomass"
	)

	var weapon_cooldown_before := player.weapon_cooldown_multiplier
	player.apply_upgrade(&"overload_vent")
	_check(
		player.weapon_cooldown_multiplier < weapon_cooldown_before,
		"Overload Vent accelerates weapon recovery"
	)

	var reflex_spurs := _find_upgrade(hud.upgrade_pool, &"reflex_spurs")
	player.dash_unlocked = false
	_check(
		not hud.is_upgrade_available(reflex_spurs),
		"Reflex Spurs waits for the dash organ"
	)
	player.apply_upgrade(&"impulse_gland")
	var cooldown_before := player.dash_cooldown
	player.apply_upgrade(&"reflex_spurs")
	_check(
		player.dash_cooldown < cooldown_before
		and hud.is_upgrade_available(reflex_spurs),
		"Reflex Spurs upgrades an unlocked dash"
	)
	player.weapon_system.set_physics_process(false)

	var crawler_scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	var quill_target := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(160.0, 0.0)
	)
	player.apply_upgrade(&"quill_burst")
	var quill_health := quill_target.current_health
	player.weapon_system._fire_quill_burst(1)
	await create_timer(0.35).timeout
	_check(
		quill_target.current_health < quill_health,
		"Quill Burst damages nearby enemies"
	)

	var tail_target := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(90.0, 0.0)
	)
	player.apply_upgrade(&"tail_lash")
	_check(
		player.get_upgrade_level(&"tail_lash") == 0,
		"A new weapon is blocked until three more levels pass"
	)
	player.current_level += player.MIN_WEAPON_UNLOCK_LEVEL_GAP
	player.apply_upgrade(&"tail_lash")
	var tail_health := tail_target.current_health
	player.weapon_system._fire_tail_lash(1)
	_check(
		tail_target.current_health < tail_health,
		"Tail Lash sweeps enemies around Koda"
	)

	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame

	var spear_near := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(190.0, 0.0)
	)
	var spear_far := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(320.0, 0.0)
	)
	spear_near.max_health = 500.0
	spear_near.current_health = 500.0
	spear_far.max_health = 500.0
	spear_far.current_health = 500.0
	player.current_level += player.MIN_WEAPON_UNLOCK_LEVEL_GAP
	player.apply_upgrade(&"arc_spear")
	var attacks := game.get_node("Entities/Attacks")
	var attacks_before := attacks.get_child_count()
	player.weapon_system._fire_arc_spear(1)
	_check(
		attacks.get_child_count() == attacks_before + 1,
		"Arc Spear launches a moving projectile"
	)
	await create_timer(0.65).timeout
	_check(
		is_instance_valid(spear_near)
		and is_instance_valid(spear_far)
		and spear_near.current_health < spear_near.max_health
		and spear_far.current_health < spear_far.max_health,
		"Arc Spear projectile pierces enemies in a line"
	)

	var volley_target := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(230.0, 20.0)
	)
	player.last_direction = Vector2.RIGHT
	var volley_health := volley_target.current_health
	player.weapon_system._fire_bone_shard_volley(1)
	await create_timer(0.45).timeout
	_check(
		volley_target.current_health < volley_health,
		"Bone Shard Volley damages enemies in a facing cone"
	)

	var ram_target := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(45.0, 0.0)
	)
	player.upgrade_levels[&"shock_ram"] = 1
	player.is_dashing = true
	player.dash_direction = Vector2.RIGHT
	var ram_health := ram_target.current_health
	player.weapon_system._update_dash_ram()
	_check(
		ram_target.current_health < ram_health,
		"Shock Ram damages enemies during dash"
	)
	player.is_dashing = false
	player.upgrade_levels.erase(&"shock_ram")

	player.current_level += player.MIN_WEAPON_UNLOCK_LEVEL_GAP
	player.apply_upgrade(&"bone_shard_volley")
	_check(
		player.get_upgrade_level(&"bone_shard_volley") == 0
		and player.get_unlocked_extra_weapon_count()
		== player.MAX_EXTRA_WEAPONS,
		"A fourth extra weapon is blocked"
	)

	var pulse_target := _spawn_crawler(
		crawler_scene,
		enemies,
		player.global_position + Vector2(120.0, 0.0)
	)
	player.apply_upgrade(&"kill_switch_nodes")
	var pulse_health := pulse_target.current_health
	player.register_enemy_kill(15)
	_check(
		pulse_target.current_health < pulse_health,
		"Kill Switch Nodes emits its scheduled shock pulse"
	)
	hud.refresh_organ_overview()
	await process_frame
	_check(
		hud.weapon_summary.get_child_count() == player.MAX_EXTRA_WEAPONS
		and hud.item_summary.get_child_count() > 0,
		"Organ Screen separates equipped weapons and items"
	)
	_check(
		not (
			hud.weapon_summary.get_child(0) as Control
		).tooltip_text.is_empty()
		and not (
			hud.item_summary.get_child(0) as Control
		).tooltip_text.is_empty(),
		"Organ Screen weapon and item cards expose hover details"
	)

	paused = false
	game.queue_free()
	await process_frame
	if failure_count == 0:
		print("NEW UPGRADES TEST PASSED")
		quit(0)
		return
	push_error("NEW UPGRADES TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _find_upgrade(
	pool: Array[UpgradeData],
	upgrade_id: StringName
) -> UpgradeData:
	for upgrade in pool:
		if upgrade != null and upgrade.upgrade_id == upgrade_id:
			return upgrade
	return null


func _spawn_crawler(
	scene: PackedScene,
	container: Node2D,
	position: Vector2
) -> Crawler:
	var crawler := scene.instantiate() as Crawler
	container.add_child(crawler)
	crawler.global_position = position
	return crawler


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)
