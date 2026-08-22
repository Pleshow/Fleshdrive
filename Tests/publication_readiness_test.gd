extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MAIN_MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const REQUIRED_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_display_and_accessibility_contracts()
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var spawner := game.get_node("EnemySpawner")
	spawner.stop_spawning()
	var player := get_first_node_in_group("player") as Koda
	var hud := game.get_node("UI/HUD")
	var manager := game.get_node("RunManager") as RunManager
	var feedback := game.get_node("CombatFeedback") as CombatFeedback
	var post_process := game.get_node("PostProcess/ScreenFilter")
	_check(player != null and hud != null, "Publication scene exposes player and HUD")
	if player != null:
		_test_progression_pacing(player)
		var camera := player.get_node("Camera2D") as Camera2D
		_check(
			camera.zoom.is_equal_approx(Vector2(1.30, 1.30)),
			"Gameplay camera uses the 1.30 readability zoom"
		)
	_test_enemy_and_arena_readability(game, spawner)
	_check(
		feedback.combine_damage_numbers
		and feedback.damage_merge_window >= 0.20
		and feedback.damage_merge_window <= 0.30,
		"Small damage numbers aggregate in the 0.20-0.30 second window"
	)
	_check(
		float(post_process.get("vignette_strength")) <= 0.70,
		"Gameplay vignette no longer crushes the visible playfield"
	)
	_test_menu_time_telemetry(manager)
	var progression := root.get_node_or_null("MetaProgression")
	var previous_runs := int(progression.get("total_runs")) if progression != null else 0
	if progression != null:
		progression.set("total_runs", maxi(previous_runs, 1))
	hud.complete_onboarding()
	await process_frame
	await _test_card_and_organ_ui(hud, player)
	_test_vfx_scale_contract()
	paused = false
	game.queue_free()
	if progression != null:
		progression.set("total_runs", previous_runs)
	await process_frame
	await _test_main_menu_copy()
	_finish()


func _test_progression_pacing(player: Koda) -> void:
	var early := player.get_level_pacing_contract(2)
	var middle := player.get_level_pacing_contract(6)
	var late := player.get_level_pacing_contract(9)
	_check(
		float(early.minimum) == 15.0
		and float(early.target_maximum) == 20.0,
		"Levels 1-3 target a 15-20 second combat cadence"
	)
	_check(
		float(middle.minimum) == 25.0
		and float(middle.target_maximum) == 35.0,
		"Levels 4-8 target a 25-35 second combat cadence"
	)
	_check(
		float(late.minimum) == 35.0
		and float(late.target_maximum) == 50.0,
		"Later levels target a 35-50 second combat cadence"
	)


func _test_enemy_and_arena_readability(game: Node, spawner: Node) -> void:
	_check(
		float(spawner.spitter_unlock_progress) * 720.0 >= 60.0
		and float(spawner.spitter_unlock_progress) * 720.0 <= 90.0,
		"The ranged enemy joins the run between 60 and 90 seconds"
	)
	var arena := game.get_node("Arena")
	_check(
		arena is DuskGardenArena
		and arena.get_node_or_null("MapComposite") != null
		and arena.get_node_or_null("GardenBoundary") != null,
		"Dusk Garden exposes its authored floor and solid boundary"
	)
	var props := arena.get_node_or_null("YSortedProps")
	_check(
		props != null
		and props.get_child_count() >= 4
		and arena.get_node_or_null("PixelMotes") != null,
		"Dusk Garden has layered occluding landmarks and ambient motion"
	)


func _test_menu_time_telemetry(manager: RunManager) -> void:
	manager.active_play_seconds = 81.0
	manager.menu_overlay_seconds = 19.0
	_check(
		manager.get_menu_time_ratio() < 0.20,
		"Run telemetry exposes the under-20-percent menu-time publication target"
	)


func _test_card_and_organ_ui(hud: Node, player: Koda) -> void:
	var controller = hud.card_selection
	var costs: Array[int] = []
	player.free_upgrade_rerolls = 0
	for paid_count in range(4):
		controller.paid_reroll_count = paid_count
		costs.append(int(hud.call("_get_upgrade_reroll_cost")))
	_check(
		costs == [2, 3, 5, -1],
		"Paid rerolls cost 2, 3 and 5 Blood Memory, then stop for the offer"
	)
	controller.reset_offer()
	hud.show_level_up_panel(2)
	await process_frame
	var cards_valid: bool = bool(hud.level_up_panel.visible)
	var visible_card_count := 0
	for card in hud.upgrade_cards:
		if not card.visible:
			continue
		visible_card_count += 1
		var illustration := card.find_child("LabNoteIllustration", true, false) as Control
		var description := card.find_child("Description", true, false) as Label
		var next_change := card.find_child("NextLevelChange", true, false) as Label
		cards_valid = (
			cards_valid
			and illustration != null
			and illustration.custom_minimum_size.x >= 64.0
			and description != null
			and description.get_theme_font_size("font_size") >= 16
			and next_change != null
			and next_change.get_theme_font_size("font_size") >= 16
			and not next_change.text.contains("->")
			and not next_change.text.strip_edges().ends_with(":")
		)
	cards_valid = (
		cards_valid
		and visible_card_count == hud.displayed_upgrades.size()
	)
	_check(
		cards_valid,
		"Cards use readable lab-note icons and concrete 16 px next-level changes"
	)
	var selected_upgrade: UpgradeData = hud.displayed_upgrades[0]
	var level_before := player.get_upgrade_level(selected_upgrade.upgrade_id)
	hud.on_upgrade_selected(0)
	var first_click_only_selected: bool = (
		hud.selected_upgrade_card_index == 0
		and player.get_upgrade_level(selected_upgrade.upgrade_id) == level_before
	)
	hud.on_upgrade_selected(0)
	var second_click_accepted: bool = (
		hud.organ_screen.visible
		if selected_upgrade.upgrade_kind == UpgradeData.UpgradeKind.ORGAN
		else player.get_upgrade_level(selected_upgrade.upgrade_id) == level_before + 1
	)
	_check(
		first_click_only_selected and second_click_accepted,
		"First click selects a card and the second click confirms it"
	)
	var all_cards_described := true
	var balance := root.get_node_or_null("BalanceDatabase")
	for upgrade in hud.upgrade_pool:
		if upgrade == null:
			continue
		var changes := UpgradeProgressionPresenter.describe(upgrade, 0, balance)
		all_cards_described = all_cards_described and not changes.is_empty()
	_check(all_cards_described, "Every public mutation has a non-empty progression description")
	var operation := hud.fleshdrive_operation_screen as FleshdriveOperationScreen
	var level_one_copy := String(operation.call(
		"_get_core_bonus_description", FleshdriveCatalog.ELECTRIC, 1
	))
	_check(
		level_one_copy.contains(
			tr("CORE LV %d: +%d%% BASE ATTACK DAMAGE") % [1, 0]
		)
		and level_one_copy.contains(
			tr(" / +%d%% CHAIN DAMAGE") % 0
		),
		"Level-one Voltaic copy exposes its exact +0 percent baseline"
	)
	var organ_screen := hud.organ_screen as Control
	var close_button := hud.organ_close_button as Control
	var slots_valid := true
	for slot in [hud.brain_slot, hud.heart_slot, hud.legs_slot]:
		slots_valid = (
			slots_valid
			and slot.size.x >= 130.0
			and slot.find_child("SlotTypeLabel", false, false) is Label
		)
	_check(
		slots_valid
		and close_button.get_rect().end.x <= organ_screen.size.x - 32.0,
		"Organ targets are enlarged, typed, and retain a 32 px safe margin"
	)
	var brain_instruction := String(hud.call(
		"_get_organ_install_instruction",
		UpgradeData.OrganSlot.BRAIN
	))
	_check(
		brain_instruction.contains(tr("BRAIN"))
		and brain_instruction.contains(tr("BRAIN SLOT").replace(tr("BRAIN"), tr("HEAD"))),
		"Brain surgery guidance names both the organ and the head slot"
	)
	await process_frame


func _test_vfx_scale_contract() -> void:
	var effects := root.get_node_or_null("VisualEffects")
	_check(
		effects != null
		and is_equal_approx(float(effects.call(
			"_get_readable_effect_scale", &"electric_chain_arc", 5.0
		)), 5.0)
		and float(effects.call(
			"_get_readable_effect_scale", &"electric_chain_arc", 3.0
		)) <= 1.6
		and float(effects.call(
			"_get_readable_effect_scale", &"storm_strike_01", 3.0
		)) <= 1.35,
		"Normal electric VFX are capped while explicit keystone effects stay large"
	)


func _test_display_and_accessibility_contracts() -> void:
	var settings := root.get_node_or_null("GameSettings")
	var constants := Dictionary(settings.get_script().get_script_constant_map())
	var presets := Array(constants.get("RESOLUTION_PRESETS", []))
	var required_present := true
	for resolution in REQUIRED_RESOLUTIONS:
		required_present = required_present and resolution in presets
	_check(required_present, "UI publication resolutions are exposed from 1280x720 to 2560x1440")
	_check(
		ProjectSettings.get_setting("display/window/stretch/mode", "") == "viewport"
		and ProjectSettings.get_setting("display/window/stretch/aspect", "") == "expand"
		and int(ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter", -1
		)) == 0,
		"Fractional 16:9 layouts retain nearest-filtered pixel art"
	)
	_check(
		settings.has_method("set_crt_intensity")
		and settings.has_method("set_bloom_intensity")
		and settings.has_method("set_chromatic_aberration")
		and settings.has_method("set_bus_volume")
		and settings.has_method("set_gameplay_setting"),
		"CRT, flash/VFX, shake and audio controls remain independently adjustable"
	)
	_check(FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md"), "Publication asset notice manifest is present")


func _test_main_menu_copy() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	var all_text := _collect_label_text(menu)
	var demo_label_count := 0
	for text in all_text:
		if text.contains("PRE-ALPHA DEMO"):
			demo_label_count += 1
	_check(
		demo_label_count == 1
		and "PLAYABLE PROTOTYPE" not in all_text,
		"Main menu uses one PRE-ALPHA DEMO label without repeated prototype copy"
	)
	menu.queue_free()
	await process_frame


func _collect_label_text(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_collect_label_text(child))
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	paused = false
	if failures == 0:
		print("PUBLICATION READINESS TEST PASSED")
		quit(0)
		return
	push_error("PUBLICATION READINESS TEST FAILED: %d failure(s)" % failures)
	quit(1)
