extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const CRAWLER_SCENE := preload("res://Scenes/enemies/crawler.tscn")
const BOSS_PROJECTILE_SCENE := preload(
	"res://Scenes/enemies/boss_projectile.tscn"
)

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
	var spawner = game.get_node("EnemySpawner")
	var enemies := game.get_node("Entities/Enemies")
	var attacks := game.get_node("Entities/Attacks")
	var feedback := get_first_node_in_group("combat_feedback")
	var projectile_pool := root.get_node_or_null("ProjectilePool")
	spawner.stop_spawning()

	_check(
		spawner.spawn_interval <= 1.2
		and spawner.maximum_enemies >= 24,
		"Opening minutes use the faster polished spawn cadence"
	)
	spawner.set_run_progress(0.65)
	spawner.set_rush_active(true)
	var rush_interval: float = spawner.spawn_timer.wait_time
	spawner.set_rush_active(false)
	spawner.begin_recovery(7.0)
	_check(
		spawner.is_recovery_active()
		and spawner.spawn_timer.wait_time > rush_interval
		and spawner.maximum_enemies < spawner.maximum_enemies_end,
		"Rushes transition into a lower-pressure recovery window"
	)
	var encountered_profiles: Dictionary = {}
	for _index in range(8):
		spawner._advance_encounter_profile()
		encountered_profiles[spawner.encounter_profile] = true
	_check(
		encountered_profiles.size() >= 3,
		"Spawner cycles through varied combat encounter profiles"
	)

	player.current_level = 2
	player.configure_fleshdrive(FleshdriveCatalog.ELECTRIC, 1)
	var early_offer_sets: Array[Dictionary] = []
	var early_survival_guaranteed := true
	var two_level_repeat_found := false
	for offer_level in [2, 3, 4]:
		player.current_level = offer_level
		hud.show_level_up_panel(offer_level)
		await process_frame
		var offer_ids: Dictionary = {}
		var has_survival_offer := false
		for offer: UpgradeData in hud.displayed_upgrades:
			offer_ids[offer.upgrade_id] = true
			has_survival_offer = (
				has_survival_offer
				or hud._is_defensive_or_healing_upgrade(offer)
			)
		for previous_set in early_offer_sets:
			for offered_id in offer_ids:
				if previous_set.has(offered_id):
					two_level_repeat_found = true
		early_survival_guaranteed = (
			early_survival_guaranteed and has_survival_offer
		)
		early_offer_sets.append(offer_ids)
		hud.level_up_panel.hide()
		hud.run_manager.exit_level_up()
	_check(
		not two_level_repeat_found,
		"A displayed skill cannot return in either of the next two level-up offers"
	)
	_check(
		early_survival_guaranteed,
		"Every early-game offer contains a defensive or healing skill"
	)

	player.current_level = 12
	for drive_id in [
		FleshdriveCatalog.ELECTRIC,
		FleshdriveCatalog.FIRE,
		FleshdriveCatalog.TELEKINETIC,
	]:
		player.configure_fleshdrive(drive_id, 1)
		var candidates: Array[UpgradeData] = []
		for upgrade: UpgradeData in hud.upgrade_pool:
			if hud.is_upgrade_available(upgrade):
				candidates.append(upgrade)
		var guaranteed: UpgradeData = hud._take_weighted_upgrade(
			candidates,
			true
		)
		_check(
			guaranteed != null
			and guaranteed.fleshdrive_affinity == String(drive_id),
			"%s offer guarantees an active-build mutation"
			% String(drive_id).capitalize()
		)

	player.configure_fleshdrive(FleshdriveCatalog.TELEKINETIC, 1)
	hud.show_level_up_panel(player.current_level)
	await process_frame
	var affinity_found := false
	var badges_valid := true
	var offers_valid := true
	for index in range(hud.displayed_upgrades.size()):
		var offer: UpgradeData = hud.displayed_upgrades[index]
		affinity_found = (
			affinity_found
			or offer.fleshdrive_affinity == "telekinetic"
		)
		offers_valid = (
			offers_valid
			and player.get_upgrade_level(offer.upgrade_id) < offer.max_level
		)
		var badge := hud.upgrade_cards[index].get_node_or_null(
			"OfferBadge"
		) as Label
		var next_level_change := hud.upgrade_cards[index].find_child(
			"NextLevelChange", true, false
		) as Label
		badges_valid = (
			badges_valid
			and badge != null
			and not badge.text.is_empty()
			and next_level_change != null
			and not next_level_change.text.is_empty()
		)
	_check(
		affinity_found and offers_valid,
		"Level-up set contains no unusable card and keeps build affinity"
	)
	_check(
		badges_valid,
		"Every offer exposes category and next-level information"
	)
	hud.level_up_panel.hide()
	hud.complete_level_up()

	var crawler := CRAWLER_SCENE.instantiate() as Crawler
	enemies.add_child(crawler)
	crawler.global_position = player.global_position + Vector2(180.0, 0.0)
	crawler.apply_external_impulse(Vector2(420.0, 0.0))
	_check(
		crawler.external_impulse.x > 400.0,
		"External-force channel preserves telekinetic displacement"
	)
	feedback.register_damage(
		crawler,
		7.0,
		FleshdriveCatalog.TELEKINETIC,
		false,
		true
	)
	feedback.register_damage(
		crawler,
		5.0,
		FleshdriveCatalog.TELEKINETIC,
		false,
		true
	)
	var damage_entry: Dictionary = feedback.pending_damage.get(
		crawler.get_instance_id(),
		{}
	)
	_check(
		is_equal_approx(float(damage_entry.get("amount", 0.0)), 12.0),
		"Rapid hits aggregate into one readable damage number"
	)
	var damage_label := damage_entry.get("label") as Label
	_check(
		damage_label != null
		and damage_label.get_theme_font("font").resource_path.ends_with(
			"PixeloidSans-Bold.ttf"
		)
		and damage_label.get_theme_color("font_color").b
		> damage_label.get_theme_color("font_color").r
		and damage_label.material is CanvasItemMaterial
		and (damage_label.material as CanvasItemMaterial).light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED
		and absf(
			damage_label.global_position.y
			- crawler.global_position.y
		) <= 50.0,
		"Damage numbers use a readable unshaded blue face close to their target"
	)

	var charged := projectile_pool.call(
		"acquire",
		BOSS_PROJECTILE_SCENE,
		attacks
	) as BossProjectile
	charged.configure(Vector2.LEFT, 20.0, 400.0, true)
	_check(
		not charged.reverse_to_nearest_enemy(),
		"Charged boss projectile is clearly non-reversible"
	)
	projectile_pool.call("release", charged)
	await process_frame
	_check(
		int(projectile_pool.call(
			"get_pooled_count",
			BOSS_PROJECTILE_SCENE.resource_path
		)) >= 1,
		"Enemy projectile is recycled into the object pool"
	)

	_check(
		game.get_node("Entities/Effects").is_in_group(
			"effects_container"
		)
		and feedback.maximum_damage_labels <= 28,
		"Effects and damage labels obey explicit visual budgets"
	)

	paused = false
	game.queue_free()
	await process_frame
	if failures == 0:
		print("CORE LOOP POLISH TEST PASSED")
		quit(0)
		return
	push_error("CORE LOOP POLISH TEST FAILED: %d failure(s)" % failures)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
