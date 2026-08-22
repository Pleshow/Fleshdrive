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
	_check(int(build_counts.get(&"chainstorm", 0)) == 3, "Chainstorm owns exactly three legacy build items")
	_check(int(build_counts.get(&"thunder_ram", 0)) == 3, "Thunder Ram owns exactly three legacy build items")
	_check(
		VoltaicBalanceContract.PATHS.has(&"orange_tempest"),
		"Orange Tempest is defined by its dedicated Voltaic progression path"
	)
	_check(is_equal_approx(BuildItemCatalog.value(&"forked_arc_node", "fork_chance"), 0.45), "Chainstorm uses the spreadsheet fork chance")
	_check(is_equal_approx(BuildItemCatalog.value(&"kinetic_capacitor", "distance"), 280.0), "Thunder Ram uses the authored movement-charge distance")
	_check(is_equal_approx(BuildItemCatalog.value(&"galvanic_tendons", "radius_per_level"), 0.07), "Thunder Ram scales contact radius predictably")
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
		player.current_level = 10
		var reservoir: UpgradeData
		for candidate in hud.upgrade_pool:
			if candidate.upgrade_id == &"static_reservoir":
				reservoir = candidate
				break
		_check(reservoir != null, "Build resource is exposed to the offer system")
		if reservoir != null:
			_check(not hud.is_upgrade_available(reservoir), "Build item is hidden before its weapon prerequisite")
			player.upgrade_levels[&"arc_heart"] = 1
			_check(hud.is_upgrade_available(reservoir), "Build item becomes offerable after its weapon prerequisite")
		var initial_chain_range := player.chain_range
		player.apply_upgrade(&"grounding_filaments")
		_check(
			is_equal_approx(player.chain_range, initial_chain_range + 12.0),
			"Grounding Filaments applies its exact per-level chain range"
		)
		var initial_move_speed := player.move_speed
		player.apply_upgrade(&"galvanic_tendons")
		_check(
			is_equal_approx(player.move_speed, initial_move_speed * 1.04),
			"Galvanic Tendons applies its exact per-level movement bonus"
		)
	game.queue_free()
	await process_frame
