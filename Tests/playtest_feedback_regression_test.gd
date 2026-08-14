extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MAIN_MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const FIREBALL_SCENE := preload("res://Scenes/player/fireball_projectile.tscn")
const MAGMA_SCENE := preload("res://Scenes/player/magma_spear_projectile.tscn")
const WARDEN_SCENE := preload("res://Scenes/enemies/visceral_warden.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fireball := FIREBALL_SCENE.instantiate() as FireballProjectile
	root.add_child(fireball)
	await process_frame
	_check(
		is_equal_approx(fireball.move_speed, 410.0)
		and fireball.projectile_texture.resource_path.ends_with(
			"fireball_autoattack_sheet.png"
		),
		"Fire autoattack uses its unique, slower fireball asset"
	)
	_check(
		fireball.sprite.sprite_frames.get_frame_count(&"flight") == 4,
		"Fireball flight animation contains four clean frames"
	)
	fireball.queue_free()

	var magma := MAGMA_SCENE.instantiate() as MagmaSpearProjectile
	root.add_child(magma)
	await process_frame
	_check(
		is_equal_approx(magma.move_speed, 690.0)
		and magma.collision_mask == 3
		and magma.projectile_texture.resource_path.ends_with(
			"magma_spear_sheet.png"
		),
		"Manual Magma Spear has a distinct asset and world collision"
	)
	_check(
		magma.sprite.sprite_frames.get_frame_count(&"flight") == 4,
		"Magma Spear flight animation contains four frames"
	)
	magma.queue_free()

	var warden := WARDEN_SCENE.instantiate()
	root.add_child(warden)
	await process_frame
	var spotlight := warden.get_node_or_null("WardenSpotlight") as PointLight2D
	_check(
		spotlight != null and spotlight.energy >= 1.5,
		"Visceral Warden carries a strong tracking reveal light"
	)
	warden.queue_free()

	var balance := CombatBalanceData.new()
	var display_settings := root.get_node_or_null("GameSettings")
	var resolution_options: Array = display_settings.call(
		"get_resolution_options"
	) if display_settings != null else []
	var resolutions_are_safe := resolution_options.size() >= 5
	for option in resolution_options:
		var resolution := Vector2i(option.get("size", Vector2i.ZERO))
		if resolution == Vector2i.ZERO:
			continue
		resolutions_are_safe = (
			resolutions_are_safe
			and resolution.x >= 960
			and resolution.y >= 540
			and absf(
				float(resolution.x) / float(resolution.y)
				- 16.0 / 9.0
			) < 0.02
		)
	_check(
		resolutions_are_safe,
		"Selectable display modes preserve readable 16:9 layouts"
	)
	var charger_profile: Dictionary = balance.enemy_profiles.get(&"charger", {})
	var spawn_profile: Dictionary = balance.spawn_profile
	_check(
		float(charger_profile.get("max_health", 0.0)) >= 150.0,
		"Charger health is significantly reinforced"
	)
	_check(
		float(spawn_profile.get("spawn_interval", 9.0)) <= 0.9
		and int(spawn_profile.get("maximum_enemies_end", 0)) >= 60,
		"Crawler pressure and late-run enemy capacity are increased"
	)
	_check(
		int(spawn_profile.get("rush_enemy_budget_bonus", 0)) >= 36
		and float(spawn_profile.get("maximum_spitter_ratio", 1.0)) <= 0.26,
		"Rushes receive extra crawler capacity while ranged saturation is capped"
	)

	var magma_upgrade := load(
		"res://Resources/Upgrades/magma_spear.tres"
	) as UpgradeData
	_check(
		magma_upgrade.description.contains("Press E")
		and magma_upgrade.description.contains("Right Mouse")
		and magma_upgrade.description.contains("first obstacle"),
		"Magma Spear card explains its complete manual control contract"
	)

	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.get_node("UI/HUD")
	var player := get_first_node_in_group("player") as Koda
	var operation := hud.fleshdrive_operation_screen as FleshdriveOperationScreen
	hud.sync_pause_volume_control()
	_check(
		hud.pause_resolution_option.item_count
		== resolution_options.size(),
		"Pause settings expose every supported resolution"
	)
	_check(
		operation.fire_card.visible
		and operation.fire_card.disabled
		and operation.fire_level.text
		== tr("IN DEVELOPMENT"),
		"Pyre Heart matches the disabled prototype state of Noetic Heart"
	)
	_check(
		operation.telekinetic_card.visible
		and operation.telekinetic_card.disabled
		and operation.telekinetic_icon.visible
		and operation.telekinetic_name.text != tr("EMPTY SLOT"),
		"Noetic Heart remains visible as the disabled third prototype heart"
	)
	game.get_node("EnemySpawner").stop_spawning()
	hud.complete_onboarding()
	await process_frame
	player.update_attack_range_indicator()
	_check(
		not player.attack_range_indicator.visible,
		"Permanent range circle stays hidden during gameplay"
	)

	var health_before_probe := player.current_health
	player.take_damage(
		7.0,
		null,
		&"regression_visibility_probe",
		DamageEvent.DamageType.PROJECTILE
	)
	var damage_flash := player.get_node_or_null(
		"DamageFeedbackLayer/DamageScreenFlash"
	) as ColorRect
	_check(
		player.current_health < health_before_probe
		and player.get_meta("last_damage_source_id", &"")
		== &"regression_visibility_probe"
		and damage_flash != null
		and damage_flash.color.a > 0.0,
		"Player damage records its source and immediately produces a red screen flash"
	)

	var visual_effects := root.get_node_or_null("VisualEffects")
	var game_settings := root.get_node_or_null("GameSettings")
	if game_settings != null:
		game_settings.vfx_intensity = 1.0
	var light_count_before := get_nodes_in_group("transient_lights").size()
	var chain_visual = visual_effects.call(
		"play",
		&"electric_chain_arc",
		player.global_position + Vector2(96.0, 0.0),
		1.0
	) if visual_effects != null else null
	_check(
		chain_visual is AnimatedSprite2D
		and chain_visual.sprite_frames.get_frame_count(&"play") == 4
		and get_nodes_in_group("transient_lights").size() > light_count_before,
		"Chain lightning keeps a hard pixel-stepped transient world light"
	)
	var effect_frame_contracts := {
		&"storm_strike_01": 48,
		&"static_strike": 48,
		&"ball_lightning_burst": 48,
		&"fire_explosion_spiked": 8,
		&"slash_heavy": 5,
		&"status_burn": 16,
	}
	var effect_contracts_valid := visual_effects != null
	for effect_id in effect_frame_contracts:
		var effect = visual_effects.call(
			"play",
			effect_id,
			player.global_position + Vector2(120.0, 0.0),
			0.8
		) if visual_effects != null else null
		effect_contracts_valid = (
			effect_contracts_valid
			and effect is AnimatedSprite2D
			and effect.sprite_frames.get_frame_count(&"play")
			== int(effect_frame_contracts[effect_id])
		)
	_check(
		effect_contracts_valid,
		"Curated lightning, fire, slash and status atlases expose their complete frame sets"
	)

	player.current_level = 5
	hud.show_level_up_panel(player.current_level)
	await process_frame
	hud.on_upgrade_selected(0)
	await process_frame
	var cards_fit := true
	var panel_rect: Rect2 = hud.level_up_panel.get_global_rect()
	for card in hud.upgrade_cards:
		cards_fit = (
			cards_fit
			and card.get_global_rect().end.y <= panel_rect.end.y + 0.5
			and card.size.y <= 396.0
		)
	_check(
		hud.level_up_panel.visible
		and hud.selected_upgrade_card_index == 0
		and hud.upgrade_confirm_button.visible
		and not hud.upgrade_confirm_button.disabled,
		"Cards are immediately selectable but still require confirmation"
	)
	_check(
		cards_fit,
		"Every mutation card stays inside the level-up viewport"
	)

	paused = false
	if visual_effects != null:
		visual_effects.call("clear_all")
	await process_frame
	game.queue_free()
	await process_frame

	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("hu")
	var main_menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	root.add_child(main_menu)
	await process_frame
	main_menu.call("_refresh_prototype_profile")
	var profile_record := main_menu.get_node(
		"PrototypeInfoPanel/Margin/Content/Build"
	) as Label
	var profile_heading := main_menu.get_node(
		"PrototypeInfoPanel/Margin/Content/BuildHeader"
	) as Label
	_check(
		main_menu.resolution_option.item_count
		== resolution_options.size(),
		"Main-menu settings expose every supported resolution"
	)
	_check(
		profile_heading.text == "PÉLDÁNY-NYILVÁNTARTÁS"
		and profile_record.text.contains("KODA-PÉLDÁNY")
		and profile_record.text.contains("K0D4-")
		and not profile_record.text.contains("HEART"),
		"Prototype profile shows localized persistent instance data without heart/build copy"
	)
	main_menu.queue_free()
	TranslationServer.set_locale(previous_locale)
	await process_frame
	if failures == 0:
		print("PLAYTEST FEEDBACK REGRESSION TEST PASSED")
		quit(0)
		return
	push_error(
		"PLAYTEST FEEDBACK REGRESSION TEST FAILED: %d failure(s)"
		% failures
	)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
