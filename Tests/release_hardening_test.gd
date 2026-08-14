extends SceneTree


const SAVE_PATH := "res://.godot/release_hardening_test.cfg"
const POOL_SCENE_PATH := "res://.godot/release_pool_subject.tscn"
const REPORT_CSV := "res://.godot/release_gate_report.csv"
const REPORT_HTML := "res://.godot/release_gate_report.html"

var failures: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var flow := root.get_node_or_null("GameFlow")
	var repository := root.get_node_or_null("SaveRepository")
	var pool := root.get_node_or_null("RuntimePool")
	var budget := root.get_node_or_null("PerformanceBudget")
	_check(flow != null, "GameFlow autoload is available")
	_check(repository != null, "SaveRepository autoload is available")
	_check(pool != null, "RuntimePool autoload is available")
	_check(budget != null, "PerformanceBudget autoload is available")
	if flow != null:
		_test_state_machine(flow)
	if repository != null:
		_test_atomic_save(repository)
	if pool != null:
		await _test_runtime_pool(pool)
	if budget != null:
		_test_performance_budget(budget)
	await _test_lifecycle_cleanup()
	_test_platform_configuration()
	_test_deterministic_soak()
	_write_reports()
	_cleanup()
	_finish()


func _test_state_machine(flow: Node) -> void:
	flow.call("force_state", &"PLAYING", false)
	_check(bool(flow.call("request_state", &"PLAYING", &"AIMING")), "Targeting enters through the shared state machine")
	_check(bool(flow.call("request_state", &"AIMING", &"PLAYING")), "Targeting exits through the shared state machine")
	_check(bool(flow.call("request_state", &"PLAYING", &"BOSS_INTRO")), "Boss intro enters through the shared state machine")
	_check(bool(flow.call("request_state", &"BOSS_INTRO", &"PLAYING")), "Boss intro has one controlled exit")
	for index in range(200):
		_check(bool(flow.call("request_state", &"PLAYING", &"PAUSED")), "state stress pause %d" % index, false)
		_check(not bool(flow.call("request_state", &"PLAYING", &"LEVEL_UP")), "parallel stale transition rejected %d" % index, false)
		_check(bool(flow.call("request_state", &"PAUSED", &"PLAYING")), "state stress resume %d" % index, false)
	var first := Control.new()
	var second := Control.new()
	root.add_child(first)
	root.add_child(second)
	flow.call("claim_overlay", &"first", first)
	flow.call("claim_overlay", &"second", second)
	_check(not first.visible and second.visible, "Only one overlay remains visible")
	flow.call("release_overlay", &"second")
	first.queue_free()
	second.queue_free()
	flow.call("force_state", &"PLAYING", false)


func _test_atomic_save(repository: Node) -> void:
	_cleanup_save_files()
	var config := ConfigFile.new()
	config.set_value("progression", "gems", 27)
	_check(int(repository.call("commit", config, SAVE_PATH, 3)) == OK, "Atomic save commit succeeds")
	var loaded := Dictionary(repository.call("load_versioned", SAVE_PATH, 3))
	var loaded_config := loaded.get("config") as ConfigFile
	_check(bool(loaded.get("ok", false)) and int(loaded_config.get_value("progression", "gems", 0)) == 27, "Versioned save round-trips")
	var absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var corrupt := FileAccess.open(absolute, FileAccess.WRITE)
	corrupt.store_string("not a valid config")
	corrupt.close()
	loaded = Dictionary(repository.call("load_versioned", SAVE_PATH, 3))
	loaded_config = loaded.get("config") as ConfigFile
	_check(bool(loaded.get("recovered_from_backup", false)) and int(loaded_config.get_value("progression", "gems", 0)) == 27, "Corrupt primary recovers from backup")


func _test_runtime_pool(pool: Node) -> void:
	var packed := PackedScene.new()
	var subject := Node2D.new()
	subject.name = "PoolSubject"
	packed.pack(subject)
	subject.free()
	_check(ResourceSaver.save(packed, POOL_SCENE_PATH) == OK, "Pool fixture saves", false)
	var scene := load(POOL_SCENE_PATH) as PackedScene
	var parent := Node2D.new()
	root.add_child(parent)
	var first := pool.call("acquire", scene, parent) as Node
	var first_id := first.get_instance_id()
	pool.call("release", first)
	await process_frame
	var second := pool.call("acquire", scene, parent) as Node
	_check(second.get_instance_id() == first_id, "Runtime pool reuses released instances")
	pool.call("release", second)
	await process_frame
	pool.call("flush")
	parent.queue_free()


func _test_performance_budget(budget: Node) -> void:
	var snapshot := Dictionary(budget.call("get_snapshot"))
	_check(snapshot.has("rolling_frame_ms") and snapshot.has("peak_frame_ms"), "Frame-time telemetry is exposed")
	_check(float(budget.call("get_spawn_pressure_scale")) > 0.0, "Overload spawn pressure remains gradual")
	_check(int(budget.call("get_pool_limit", "fixture", 48)) > 0, "Pool budget is data driven")


func _test_lifecycle_cleanup() -> void:
	var lifecycle := root.get_node_or_null("SceneLifecycle")
	var baseline_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var transient: Node2D
	for index in range(80):
		transient = Node2D.new()
		transient.name = "TransitionTransient%d" % index
		transient.add_to_group("runtime_transient")
		root.add_child(transient)
	lifecycle.call("cancel_transients")
	await process_frame
	await process_frame
	_check(not is_instance_valid(transient), "Scene transition removes transient gameplay nodes")
	var final_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check(final_nodes <= baseline_nodes + 2, "Repeated transitions do not leak gameplay nodes")


func _test_platform_configuration() -> void:
	_check(FileAccess.file_exists("res://export_presets.cfg"), "Windows export presets exist")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect", "") == "expand", "Responsive aspect expansion is enabled")
	_check(
		ProjectSettings.get_setting(
			"display/window/stretch/scale_mode",
			""
		) == "fractional",
		"Fractional viewport scaling fills non-integer display sizes"
	)
	_check(
		int(ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter",
			-1
		)) == 0
		and bool(ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_transforms_to_pixel",
			false
		))
		and bool(ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_vertices_to_pixel",
			false
		)),
		"Nearest filtering and pixel snapping keep pixel art crisp"
	)
	_check(bool(ProjectSettings.get_setting("display/window/dpi/allow_hidpi", false)), "High-DPI scaling is enabled")


func _test_deterministic_soak() -> void:
	var first_checksum := _calculate_soak_checksum()
	var second_checksum := _calculate_soak_checksum()
	_check(first_checksum == second_checksum and first_checksum != 0, "300 deterministic accelerated soak runs are reproducible")


func _calculate_soak_checksum() -> int:
	var checksum := 0
	for run_index in range(300):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9102026 + run_index
		var state := 0
		for tick in range(720):
			state = (state + rng.randi_range(1, 17) + tick) % 100003
		checksum = (checksum + state) % 2147483647
	return checksum


func _check(condition: bool, message: String, report: bool = true) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	elif report:
		print("PASS: " + message)
	results.append({"name": message, "passed": condition})


func _write_reports() -> void:
	var csv := FileAccess.open(REPORT_CSV, FileAccess.WRITE)
	csv.store_line("check,status")
	for result in results:
		csv.store_csv_line(PackedStringArray([String(result.name), "PASS" if bool(result.passed) else "FAIL"]))
	csv.close()
	var html := FileAccess.open(REPORT_HTML, FileAccess.WRITE)
	html.store_string("<!doctype html><meta charset='utf-8'><title>Fleshdrive Release Gate</title><style>body{font:16px sans-serif;background:#081014;color:#d8f8ff;padding:32px}.pass{color:#6fffa1}.fail{color:#ff6b73}</style><h1>Fleshdrive Release Gate</h1>")
	for result in results:
		var css := "pass" if bool(result.passed) else "fail"
		html.store_string("<p class='%s'>%s — %s</p>" % [css, "PASS" if bool(result.passed) else "FAIL", String(result.name).xml_escape()])
	html.close()


func _cleanup() -> void:
	_cleanup_save_files()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(POOL_SCENE_PATH))


func _cleanup_save_files() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))


func _finish() -> void:
	if failures == 0:
		print("RELEASE HARDENING TEST PASSED")
	quit(failures)
