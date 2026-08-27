extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.get_node("UI/HUD")
	var player := game.get_node("Entities/Koda") as Koda
	hud.complete_onboarding()
	await process_frame

	await _check_build_offer(hud, player, 2, &"arc_heart")
	player.apply_upgrade(&"arc_heart")
	player.apply_upgrade(&"static_claws")
	await _check_build_offer(hud, player, 5, &"")
	player.apply_upgrade(&"arc_relay")
	await _check_build_offer(hud, player, 8, &"forked_arc_node")
	player.apply_upgrade(&"forked_arc_node")
	await _check_build_offer(hud, player, 11, &"pulse_capacitor")
	player.apply_upgrade(&"pulse_capacitor")
	await _check_build_offer(hud, player, 14, &"storm_core")
	player.apply_upgrade(&"storm_core")
	await _check_build_offer(hud, player, 17, &"eye_of_the_storm")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("VOLTAIC OFFER ROTATION TEST PASSED")
	quit(failures)


func _check_build_offer(
	hud,
	player: Koda,
	level: int,
	expected_thunder_id: StringName
) -> void:
	player.current_level = level
	hud.show_level_up_panel(level)
	await process_frame
	var ids: Array[StringName] = []
	var thunder_found := false
	var volt_found := false
	for offer: UpgradeData in hud.displayed_upgrades:
		ids.append(offer.upgrade_id)
		thunder_found = thunder_found or offer.build_archetype == &"thunder_god"
		volt_found = volt_found or offer.build_archetype == &"volt_hound"
	_check(
		thunder_found and (
			expected_thunder_id.is_empty()
			or expected_thunder_id in ids
		),
		"Level %d visibly offers a valid Thunder God card (%s)"
		% [level, ", ".join(ids)]
	)
	_check(
		volt_found,
		"Level %d visibly offers Volt Hound alongside Thunder God" % level
	)
	_check(
		hud.displayed_upgrades.size() == hud.upgrade_cards.size(),
		"Level %d exposes exactly the three visible card choices" % level
	)
	hud.level_up_panel.hide()
	hud.run_manager.exit_level_up()
