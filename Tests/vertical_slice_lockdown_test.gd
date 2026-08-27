extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const WARDEN_SCENE := preload("res://Scenes/enemies/visceral_warden.tscn")
const ARC_HEART_UPGRADE := preload("res://Resources/Upgrades/arc_heart.tres")
const BALL_LIGHTNING_UPGRADE := preload(
	"res://Resources/Upgrades/OrangeTempest/ball_lightning.tres"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.get_node("UI/HUD")
	var player := get_first_node_in_group("player") as Koda
	var manager := game.get_node("RunManager") as RunManager
	var operation = hud.fleshdrive_operation_screen
	operation._select_fleshdrive(FleshdriveCatalog.FIRE)
	operation._confirm_selection()
	await process_frame
	_check(
		player.active_fleshdrive_id == FleshdriveCatalog.ELECTRIC
		and manager.state in [
			RunManager.RunState.ONBOARDING,
			RunManager.RunState.PLAYING,
		],
		"Disabled Pyre Heart cannot replace the prototype Voltaic Heart"
	)
	if manager.state == RunManager.RunState.ONBOARDING:
		hud.complete_onboarding()
		await process_frame
	_check(
		player.active_fleshdrive_id == FleshdriveCatalog.ELECTRIC,
		"Onboarding preserves the prototype Voltaic Heart"
	)
	Input.action_press(&"pause")
	await process_frame
	Input.action_release(&"pause")
	_check(
		manager.state == RunManager.RunState.PAUSED and paused,
		"ESC pause action remains available after Fleshdrive selection"
	)
	manager.set_manual_pause(false)
	await process_frame
	var spawner = game.get_node("EnemySpawner")
	spawner.stop_spawning()
	var weapon_system := player.get_node("WeaponSystem") as PlayerWeaponSystem
	var universal_ids: Dictionary = {}
	for upgrade in hud.upgrade_pool:
		if upgrade != null:
			universal_ids[upgrade.upgrade_id] = true
	for expected_id in [
		&"spine_launcher", &"bone_saw", &"parasite_maw", &"blood_needle",
		&"acid_gland", &"jaw_reflex", &"surgical_drone", &"implosion_sac",
		&"reserve_bladder", &"bone_plating", &"split_nervous_system",
		&"electric_kinetic_predator_capacitor",
	]:
		_check(universal_ids.has(expected_id), "%s is available in the universal mutation pool" % String(expected_id))
	for inactive_id in [
		&"electric_kinetic_expanded_capacitor",
		&"electric_kinetic_compressed_charge", &"shock_ram",
		&"capacitor_organ", &"voltaic_tendons",
	]:
		_check(
			not universal_ids.has(inactive_id),
			"%s is removed from the current offer pool" % String(inactive_id)
		)
	_check(
		weapon_system.universal_mutations != null
		and weapon_system.universal_mutations.handles(&"spine_launcher"),
		"Universal weapon runtime handles the new arsenal"
	)
	var kinetic_layer := weapon_system.volt_hound.momentum_layer
	_check(
		is_instance_valid(kinetic_layer) and kinetic_layer.layer > 110,
		"Kinetic Charge HUD renders above gameplay UI and vignette"
	)
	if is_instance_valid(kinetic_layer) and kinetic_layer.get_child_count() > 0:
		var kinetic_panel := kinetic_layer.get_child(0) as Control
		_check(
			kinetic_panel != null and kinetic_panel.position.y >= 70.0 and kinetic_panel.position.y + kinetic_panel.size.y <= 132.0,
			"Kinetic Charge HUD stays inside the top safe area below XP"
		)
	player.upgrade_levels[&"static_claws"] = 1
	weapon_system.volt_hound.update(0.0)
	await process_frame
	_check(kinetic_layer.visible, "Kinetic Charge HUD is visible during active gameplay")
	manager.set_manual_pause(true)
	await process_frame
	_check(not kinetic_layer.visible, "Kinetic Charge HUD is hidden while the pause menu is open")
	manager.set_manual_pause(false)
	await process_frame
	_check(kinetic_layer.visible, "Kinetic Charge HUD returns after gameplay resumes")
	weapon_system.volt_hound.momentum = 100.0
	weapon_system.volt_hound.ready = true
	weapon_system.volt_hound.was_dashing = false
	player.is_dashing = true
	weapon_system.volt_hound._update_dash_state()
	_check(
		weapon_system.volt_hound.overdrive_remaining >= 1.99
		and not weapon_system.volt_hound.ready,
		"Kinetic READY waits for the next Dash and activates a two-second Overdrive"
	)
	var enemy_source := Node2D.new()
	root.add_child(enemy_source)
	enemy_source.add_to_group("enemies")
	var contact_probe := DamageEvent.create(player, 10.0, enemy_source, &"contact_probe")
	contact_probe.damage_type = DamageEvent.DamageType.CONTACT
	var projectile_probe := DamageEvent.create(player, 10.0, null, &"projectile_probe")
	projectile_probe.damage_type = DamageEvent.DamageType.PROJECTILE
	_check(
		is_zero_approx(weapon_system.volt_hound.modify_incoming_damage(contact_probe, 10.0))
		and is_equal_approx(weapon_system.volt_hound.modify_incoming_damage(projectile_probe, 10.0), 10.0)
		and weapon_system.volt_hound.is_overdrive_active(),
		"Overdrive blocks enemy contact damage but preserves projectile damage"
	)
	enemy_source.queue_free()
	player.is_dashing = false
	weapon_system.volt_hound.was_dashing = false
	weapon_system.volt_hound._end_overdrive()
	player.upgrade_levels.erase(&"static_claws")

	_check(
		InputMap.has_action(&"active_skill")
		and InputMap.has_action(&"secondary_active_skill")
		and InputMap.has_action(&"active_confirm")
		and InputMap.has_action(&"active_cancel"),
		"Active skills expose unified keyboard and controller actions"
	)
	var active_skill_requirements := {
		FleshdriveCatalog.ELECTRIC: &"shock_ram",
		FleshdriveCatalog.FIRE: &"magma_spear",
		FleshdriveCatalog.TELEKINETIC: &"repulse_wave",
	}
	for drive_id: StringName in active_skill_requirements:
		player.upgrade_levels.clear()
		player.configure_fleshdrive(drive_id, 1)
		_check(
			not bool(weapon_system.get_active_skill_status().get("unlocked", false)),
			"%s does not grant an unselected E skill" % String(drive_id).capitalize()
		)
		player.upgrade_levels[active_skill_requirements[drive_id]] = 1
		var status := weapon_system.get_active_skill_status()
		if drive_id == FleshdriveCatalog.FIRE:
			_check(
				bool(status.get("unlocked", false))
				and StringName(status.get("id", &"")) == &"magma_spear",
				"Magma Spear exposes the selected Fire active skill"
			)
		else:
			_check(
				not bool(status.get("unlocked", false)),
				"%s weapon remains automatic instead of occupying E" % String(drive_id).capitalize()
			)

	var health_before := player.current_health
	manager.set_manual_pause(true)
	var paused_event := DamageEvent.create(player, 25.0, null, &"pause_probe")
	var pipeline := root.get_node("CombatPipeline")
	var paused_result := Dictionary(pipeline.call("apply_damage", paused_event))
	_check(
		paused_result.get("accepted", false) == false
		and is_equal_approx(player.current_health, health_before),
		"Paused gameplay rejects delayed combat damage"
	)
	manager.set_manual_pause(false)

	player.current_level = 6
	player.current_biomass = 1000.0
	var meta := root.get_node("MetaProgression")
	var previous_meta_path := String(meta.save_path)
	var previous_memory := int(meta.red_gems)
	var previous_persistence := bool(meta.persist_blood_memory_spending)
	meta.save_path = "user://vertical_slice_blood_memory_test.cfg"
	meta.persist_blood_memory_spending = false
	meta.red_gems = 3
	kinetic_layer.call("set_build_visible", true)
	hud.show_level_up_panel(player.current_level)
	await process_frame
	_check(not kinetic_layer.visible, "Kinetic Charge HUD is hidden during card selection")
	var first_card_surface: Node = hud.upgrade_cards[0].get_node_or_null("CardSurface")
	_check(
		first_card_surface != null
		and first_card_surface.find_child("Preview", true, false) == null
		and first_card_surface.find_child("Description", true, false) is Label,
		"Mutation cards are text-and-stats only, without legacy generated artwork"
	)
	player.upgrade_levels[&"ball_lightning"] = 1
	hud._set_upgrade_card_content(hud.upgrade_cards[0], BALL_LIGHTNING_UPGRADE)
	var next_level_label := hud.upgrade_cards[0].find_child(
		"NextLevelChange", true, false
	) as Label
	_check(
		next_level_label != null
		and next_level_label.text.contains("8 becomes 10")
		and next_level_label.text.contains("1.40 s becomes 1.32 s"),
		"Next Level states the exact numeric change produced by this upgrade"
	)
	player.upgrade_levels.erase(&"ball_lightning")
	var universal_pool: Array[UpgradeData] = []
	UpgradeRegistry.append_universal_mutations(universal_pool)
	var spine_launcher: UpgradeData
	for universal_upgrade in universal_pool:
		if universal_upgrade.upgrade_id == &"spine_launcher":
			spine_launcher = universal_upgrade
			break
	player.upgrade_levels[&"spine_launcher"] = 1
	hud._set_upgrade_card_content(hud.upgrade_cards[0], spine_launcher)
	next_level_label = hud.upgrade_cards[0].find_child(
		"NextLevelChange", true, false
	) as Label
	_check(
		next_level_label != null
		and next_level_label.text.contains("32.0 becomes 37.8")
		and next_level_label.text.contains("660 px/s becomes 700 px/s")
		and next_level_label.text.contains("1.50 s becomes 1.45 s"),
		"Universal weapon cards expose their exact per-level runtime scaling"
	)
	player.upgrade_levels.erase(&"spine_launcher")
	hud._set_upgrade_card_content(hud.upgrade_cards[0], ARC_HEART_UPGRADE)
	var organ_type_label := hud.upgrade_cards[0].find_child(
		"OrganType", true, false
	) as Label
	_check(
		organ_type_label != null
		and organ_type_label.text.contains(tr("HEART")),
		"Organ cards state their anatomical organ type"
	)
	hud._set_upgrade_card_content(hud.upgrade_cards[0], hud.displayed_upgrades[0])
	hud.on_upgrade_selected(0)
	_check(
		hud.selected_upgrade_card_index == 0
		and hud.upgrade_confirm_button.visible,
		"Card selection is immediate and remains confirmation-gated"
	)
	var biomass_before := player.current_biomass
	var memory_before := int(meta.get_blood_memory())
	hud._reroll_upgrade_offers()
	await process_frame
	_check(
		hud.upgrade_reroll_count == 1
		and is_equal_approx(player.current_biomass, biomass_before)
		and int(meta.get_blood_memory()) == memory_before - 2
		and hud.upgrade_currency_label.text.contains(str(int(meta.get_blood_memory()))),
		"Reroll spends visible Blood Memory without consuming run biomass"
	)
	player.upgrade_levels[&"experimental_tissue"] = 1
	player.free_upgrade_rerolls = 4
	player.current_level = 8
	player._refresh_level_up_reroll_entitlement()
	var even_level_entitlement := player.free_upgrade_rerolls
	player.current_level = 9
	player._refresh_level_up_reroll_entitlement()
	_check(
		even_level_entitlement == 1 and player.free_upgrade_rerolls == 0,
		"Experimental Tissue grants one offer-bound free reroll and never stacks leftovers"
	)
	player.upgrade_levels.erase(&"experimental_tissue")
	meta.red_gems = previous_memory
	meta.save_path = previous_meta_path
	meta.persist_blood_memory_spending = previous_persistence
	hud._skip_upgrade_offer()
	await process_frame
	kinetic_layer.call("set_build_visible", false)

	var warden := WARDEN_SCENE.instantiate() as VisceralWarden
	game.get_node("Entities/Enemies").add_child(warden)
	warden.global_position = player.global_position + Vector2(220.0, 0.0)
	await process_frame
	warden.force_attack(&"slam")
	_check(
		warden.interrupt_active_attack(FleshdriveCatalog.TELEKINETIC, 1.0)
		and warden.state == VisceralWarden.State.RECOVERY,
		"Fleshdrive active skills can interrupt a Warden wind-up"
	)

	paused = false
	game.queue_free()
	await process_frame
	if failures == 0:
		print("VERTICAL SLICE LOCKDOWN TEST PASSED")
		quit(0)
		return
	push_error("VERTICAL SLICE LOCKDOWN TEST FAILED: %d failure(s)" % failures)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
