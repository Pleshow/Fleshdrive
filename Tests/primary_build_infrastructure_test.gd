extends SceneTree


const VoltaicBalanceContract := preload(
	"res://Scripts/balance/voltaic_balance_contract.gd"
)

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
	_validate_proc_context()
	_validate_build_resources()
	_validate_status_consumption()
	await _validate_game_scene()
	if failures == 0:
		print("PRIMARY BUILD INFRASTRUCTURE TEST PASSED")
	quit(failures)


func _validate_proc_context() -> void:
	var context := ProcContext.new(2)
	var target := Node.new()
	_check(context.visit(target), "Proc context accepts a new target")
	_check(not context.visit(target), "Proc context blocks revisiting a target")
	_check(context.allow_proc(&"explosion", 1), "Proc limiter accepts first proc")
	_check(not context.allow_proc(&"explosion", 1), "Proc limiter enforces its cap")
	var child := context.fork()
	_check(child.root_cast_id == context.root_cast_id, "Fork preserves root cast identity")
	_check(child.generation == 1, "Fork advances proc generation")
	target.free()


func _validate_build_resources() -> void:
	var pool: Array[UpgradeData] = []
	UpgradeRegistry.append_build_items(pool)
	_check(pool.size() == 36, "All thirty-six build items load")
	var ids: Dictionary = {}
	var build_counts: Dictionary = {}
	for upgrade in pool:
		_check(upgrade != null, "Build item resource is valid")
		if upgrade == null:
			continue
		ids[upgrade.upgrade_id] = true
		build_counts[upgrade.build_archetype] = int(build_counts.get(upgrade.build_archetype, 0)) + 1
		_check(not upgrade.required_weapons.is_empty(), "%s has a weapon prerequisite" % upgrade.upgrade_id)
		_check(upgrade.card_texture != null, "%s has a replaceable card asset" % upgrade.upgrade_id)
		_check(upgrade.prerequisites_met({upgrade.required_weapons[0]: 1}), "%s unlocks with its weapon" % upgrade.upgrade_id)
		_check(not upgrade.prerequisites_met({}), "%s stays hidden without its weapon" % upgrade.upgrade_id)
	_check(ids.size() == 36, "Build item identifiers are unique")
	_check(int(build_counts.get(&"chainstorm", 0)) == 2, "Two inactive legacy Chainstorm items remain save-compatible")
	_check(int(build_counts.get(&"thunder_ram", 0)) == 2, "Two inactive legacy Thunder Ram items remain save-compatible")
	_check(int(build_counts.get(&"thunder_god", 0)) == 1, "Forked Arc Node belongs to the redesigned Thunder God path")
	_check(int(build_counts.get(&"volt_hound", 0)) == 1, "Kinetic Capacitor belongs to the redesigned Volt Hound path")
	_check(
		VoltaicBalanceContract.PATHS.has(&"orange_tempest"),
		"Orange Tempest is defined by its dedicated Voltaic progression path"
	)
	_check(
		VoltaicCardCatalog.progression_allows(&"arc_relay", {&"arc_heart": 1})
		and not VoltaicCardCatalog.progression_allows(&"forked_arc_node", {&"arc_heart": 1}),
		"Thunder God cards unlock one authored build level at a time"
	)
	_check(
		not VoltaicCardCatalog.progression_allows(
			&"conductive_fur", {&"arc_heart": 1, &"arc_relay": 1}
		),
		"Selecting one Thunder God lane locks the opposite lane"
	)
	_check(BuildItemCatalog.BUILD_IDS == [&"chainstorm", &"thunder_ram", &"orange_tempest"], "Public build catalog contains only the three Voltaic paths")


func _validate_status_consumption() -> void:
	var manager := StatusEffectManager.new()
	root.add_child(manager)
	manager.setup(null)
	var target := Node2D.new()
	root.add_child(target)
	manager.apply_status(target, {
		"id": &"burn", "duration": 2.0, "stack_gain": 5,
		"max_stacks": 5,
	})
	_check(manager.consume_stacks(target, &"burn", 2) == 2, "Status manager consumes requested stacks")
	_check(int(manager.get_status(target, &"burn").get("stacks", 0)) == 3, "Unconsumed status stacks remain")
	_check(manager.consume_stacks(target, &"burn", -1) == 3, "Status manager can consume all stacks")
	_check(manager.get_status(target, &"burn").is_empty(), "Consumed status is removed cleanly")
	manager.queue_free()
	target.queue_free()


func _validate_game_scene() -> void:
	var scene := load("res://Scenes/game.tscn") as PackedScene
	_check(scene != null, "Game scene parses after build integration")
	if scene == null:
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var hud := game.get_node_or_null("UI/HUD")
	_check(hud != null, "HUD instantiates with the upgraded registry")
	if hud != null:
		_check(hud.upgrade_pool.size() >= 56, "HUD merges build items into its existing pool")
		var player := game.get_node("Entities/Koda") as Koda
		player.current_level = 11
		var arc_relay: UpgradeData
		var conductive_fur: UpgradeData
		var forked_arc: UpgradeData
		var charged_paws: UpgradeData
		var static_reservoir_found := false
		for candidate in hud.upgrade_pool:
			match candidate.upgrade_id:
				&"arc_relay": arc_relay = candidate
				&"conductive_fur": conductive_fur = candidate
				&"forked_arc_node": forked_arc = candidate
				&"charged_paw_pads": charged_paws = candidate
				&"static_reservoir": static_reservoir_found = true
		_check(not static_reservoir_found, "Inactive Thunder cards are absent from offers")
		player.upgrade_levels[&"arc_heart"] = 1
		player.upgrade_levels[&"static_claws"] = 1
		_check(
			arc_relay != null and conductive_fur != null
			and hud.is_upgrade_available(arc_relay)
			and hud.is_upgrade_available(conductive_fur),
			"Both Thunder God lanes remain available alongside Volt Hound"
		)
		_check(
			charged_paws != null and hud.is_upgrade_available(charged_paws),
			"Volt Hound and Thunder God can progress in the same run"
		)
		player.upgrade_levels[&"arc_relay"] = 1
		_check(
			forked_arc != null and hud.is_upgrade_available(forked_arc)
			and not hud.is_upgrade_available(conductive_fur),
			"The chosen Thunder lane unlocks only its next card"
		)
		player.current_level = 12
		_check(
			not hud.is_upgrade_available(forked_arc)
			and not hud.is_upgrade_available(charged_paws),
			"Build cards wait for the next dedicated build level"
		)
		_check(
			hud._level_up_focus(11) == &"build"
			and hud._level_up_focus(12) == &"fleshdrive"
			and hud._level_up_focus(13) == &"passive"
			and hud._level_up_focus(14) == &"build"
			and hud._level_up_focus(15) == &"universal_weapon"
			and hud._level_up_focus(16) == &"defensive",
			"Build levels recur every three levels while all four supporting focuses rotate"
		)
		player.current_level = 11
		var build_candidates: Array[UpgradeData] = []
		for candidate in hud.upgrade_pool:
			if hud.is_upgrade_available(candidate):
				build_candidates.append(candidate)
		hud.displayed_upgrades.clear()
		hud._append_build_focus_offers(build_candidates)
		var offered_archetypes: Dictionary = {}
		for offered in hud.displayed_upgrades:
			offered_archetypes[offered.build_archetype] = true
		_check(
			offered_archetypes.has(&"thunder_god")
			and offered_archetypes.has(&"volt_hound"),
			"Dedicated build levels guarantee both available Voltaic builds"
		)
	game.queue_free()
	await process_frame
