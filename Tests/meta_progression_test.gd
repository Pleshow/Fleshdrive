extends SceneTree


var failure_count: int = 0
const TEST_SAVE_PATH := "res://.godot/fleshdrive_meta_progression_test.cfg"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var absolute_test_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	_remove_test_save_family(absolute_test_path)
	var manager_script := load(
		"res://Scripts/meta_progression.gd"
	) as Script
	var manager: Node = manager_script.new()
	manager.save_path = TEST_SAVE_PATH
	root.add_child(manager)
	await process_frame

	manager.add_gems(5)
	_check(manager.red_gems == 5, "Red gems are added")
	_check(
		manager.get_upgrade_cost(&"vitality") == 2,
		"First vitality level costs two gems"
	)
	_check(
		manager.purchase_upgrade(&"vitality"),
		"Permanent vitality upgrade can be purchased"
	)
	_check(
		manager.red_gems == 3
		and manager.get_upgrade_level(&"vitality") == 1,
		"Purchase spends gems and stores its level"
	)
	_check(
		manager.UPGRADE_DEFINITIONS.size() == 13,
		"Meta progression exposes thirteen skills"
	)
	var all_icons_are_new_pixel_art := true
	for definition: Dictionary in manager.UPGRADE_DEFINITIONS.values():
		var icon := load(String(definition.icon)) as Texture2D
		all_icons_are_new_pixel_art = (
			all_icons_are_new_pixel_art
			and icon != null
			and icon.get_width() == 256
			and icon.get_height() == 256
			and String(definition.icon).begins_with(
				"res://Assets/ui/meta/skill_"
			)
		)
	_check(
		all_icons_are_new_pixel_art,
		"Flesh Tree uses the new consistent pixel-art icon set"
	)
	var refunded: int = manager.respec_upgrades()
	_check(
		refunded == 2
		and manager.red_gems == 5
		and manager.get_upgrade_level(&"vitality") == 0,
		"Respec refunds spent gems without deleting currency"
	)
	var death_statistics: Dictionary = manager.record_run_result(
		false,
		75.0,
		12
	)
	_check(
		death_statistics.instance_number == 2
		and death_statistics.deaths == 1
		and death_statistics.runs == 1
		and death_statistics.total_kills == 12
		and death_statistics.instance_label == "K0D4-002",
		"Death advances the persistent K0D4 instance and statistics"
	)
	var victory_statistics: Dictionary = manager.record_run_result(
		true,
		720.0,
		80,
		FleshdriveCatalog.ELECTRIC
	)
	_check(
		victory_statistics.instance_number == 2
		and victory_statistics.boss_victories == 1
		and victory_statistics.runs == 2
		and is_equal_approx(
			float(victory_statistics.best_time),
			720.0
		),
		"Victories and best time are recorded without replacing the body"
	)
	_check(
		manager.is_fleshdrive_unlocked(FleshdriveCatalog.ELECTRIC)
		and manager.is_fleshdrive_unlocked(FleshdriveCatalog.FIRE)
		and manager.is_fleshdrive_unlocked(
			FleshdriveCatalog.TELEKINETIC
		)
		and manager.get_fleshdrive_level(FleshdriveCatalog.ELECTRIC) == 2
		and manager.get_fleshdrive_level(FleshdriveCatalog.FIRE) == 1,
		"First victory unlocks Noetic and evolves the victorious Fleshdrive"
	)
	manager.purchase_upgrade(&"vitality")
	manager.queue_free()
	await process_frame

	var reloaded_manager: Node = manager_script.new()
	reloaded_manager.save_path = TEST_SAVE_PATH
	root.add_child(reloaded_manager)
	await process_frame
	_check(
		reloaded_manager.red_gems == 3
		and reloaded_manager.get_upgrade_level(&"vitality") == 1,
		(
			"Meta currency and skill levels survive a reload "
			+ "(got %d gems, vitality %d)"
		) % [
			reloaded_manager.red_gems,
			reloaded_manager.get_upgrade_level(&"vitality"),
		]
	)
	_check(
		reloaded_manager.instance_number == 2
		and reloaded_manager.total_runs == 2
		and reloaded_manager.total_deaths == 1
		and reloaded_manager.boss_victories == 1
		and reloaded_manager.total_kills == 92,
		"Run statistics survive a reload"
	)
	_check(
		reloaded_manager.get_fleshdrive_level(
			FleshdriveCatalog.ELECTRIC
		) == 2
		and reloaded_manager.is_fleshdrive_unlocked(
			FleshdriveCatalog.TELEKINETIC
		),
		"Fleshdrive blueprint and core evolution survive a reload"
	)
	var electric_metrics: Dictionary = (
		reloaded_manager.get_fleshdrive_metrics(
			FleshdriveCatalog.ELECTRIC
		)
	)
	_check(
		int(electric_metrics.runs) == 1
		and int(electric_metrics.victories) == 1
		and is_equal_approx(
			float(electric_metrics.best_boss_time),
			720.0
		),
		"Per-Fleshdrive boss timing metrics persist for balance analysis"
	)
	var versioned_config := ConfigFile.new()
	versioned_config.load(TEST_SAVE_PATH)
	_check(
		int(versioned_config.get_value("system", "save_version", 0))
			== 3,
		"Progression save carries an explicit migration version"
	)
	var corrupt_file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("not a valid config")
	corrupt_file.close()
	var recovered_manager: Node = manager_script.new()
	recovered_manager.save_path = TEST_SAVE_PATH
	root.add_child(recovered_manager)
	await process_frame
	_check(
		recovered_manager.red_gems >= 0
		and recovered_manager.total_runs >= 1
		and recovered_manager.instance_number >= 2,
		"Corrupt primary progression recovers a coherent prior backup"
	)
	recovered_manager.queue_free()
	await process_frame
	reloaded_manager.reset_all_progress()
	_check(
		reloaded_manager.red_gems == 0
		and reloaded_manager.get_upgrade_level(&"vitality") == 0
		and reloaded_manager.instance_number == 1
		and reloaded_manager.total_runs == 0
		and reloaded_manager.total_deaths == 0,
		"Full reset clears progression and restores K0D4-001"
	)
	_check(
		reloaded_manager.get_fleshdrive_level(
			FleshdriveCatalog.ELECTRIC
		) == 1
		and reloaded_manager.get_fleshdrive_level(
			FleshdriveCatalog.FIRE
		) == 1,
		"Full reset restores starter Fleshdrive Core levels"
	)

	var packed_game := load("res://Scenes/game.tscn") as PackedScene
	var game := packed_game.instantiate()
	root.add_child(game)
	await process_frame
	var run_manager := game.get_node("RunManager") as RunManager
	var pickups := game.get_node("Entities/Pickups")
	var enemy := Node2D.new()
	game.get_node("Entities/Enemies").add_child(enemy)
	enemy.global_position = Vector2(700, 500)
	run_manager.kill_count = 24
	var pickup_count_before := pickups.get_child_count()
	run_manager._on_enemy_defeated(enemy)
	await process_frame
	await process_frame
	_check(
		pickups.get_child_count() == pickup_count_before + 1,
		"Every twenty-fifth kill drops a permanent red gem"
	)
	var gem := (
		pickups.get_child(pickups.get_child_count() - 1)
		if pickups.get_child_count() > pickup_count_before
		else null
	)
	_check(
		gem is RedGemPickup
		and gem.is_in_group("permanent_currency_pickup"),
		"Dropped red gem is a collectible animated pickup"
	)

	paused = false
	game.queue_free()
	reloaded_manager.queue_free()
	await process_frame
	_remove_test_save_family(absolute_test_path)
	_finish()


func _remove_test_save_family(absolute_path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(absolute_path + suffix)
	var directory := absolute_path.get_base_dir()
	var prefix := absolute_path.get_file() + ".corrupt-"
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with(prefix):
			DirAccess.remove_absolute(directory.path_join(file_name))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failure_count == 0:
		print("META PROGRESSION TEST PASSED")
		quit(0)
		return
	push_error(
		"META PROGRESSION TEST FAILED: %d failure(s)" % failure_count
	)
	quit(1)
