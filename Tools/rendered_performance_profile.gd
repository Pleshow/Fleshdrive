extends SceneTree


const WARMUP_FRAMES := 480
const SAMPLE_FRAMES := 900
const REPORT_PATH := "res://Reports/rendered_performance_profile.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://Scenes/game.tscn") as PackedScene
	if packed == null:
		_fail("Game scene could not be loaded")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var hud := game.get_node("UI/HUD")
	hud._on_fleshdrive_selected(FleshdriveCatalog.ELECTRIC)
	await process_frame
	hud.complete_onboarding()
	paused = false
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var manager := get_first_node_in_group("run_manager") as RunManager
	var spawner := game.get_node("EnemySpawner")
	player.max_health = 1000000.0
	player.current_health = player.max_health
	# Apply the authored late phase before freezing the clock. With explicit
	# 1/2/3/7 threat costs, run progress alone is not the authoritative budget.
	manager.elapsed_seconds = 600.0
	spawner.set_run_progress(1.0)
	if manager.encounter_director != null:
		manager.encounter_director.call("_process", 0.51)
	manager.set_process(false)
	manager.trigger_rush()

	for _index in range(WARMUP_FRAMES):
		await process_frame

	var samples: Array[float] = []
	var visual_effects := root.get_node_or_null("VisualEffects")
	var max_active_vfx := 0
	var last_tick := Time.get_ticks_usec()
	for _index in range(SAMPLE_FRAMES):
		await process_frame
		var tick := Time.get_ticks_usec()
		samples.append(float(tick - last_tick) / 1000.0)
		if visual_effects != null:
			max_active_vfx = maxi(
				max_active_vfx,
				int(visual_effects.active_sprites.size())
			)
		last_tick = tick

	samples.sort()
	var total := 0.0
	var over_25_ms := 0
	for sample in samples:
		total += sample
		if sample > 25.0:
			over_25_ms += 1
	var average := total / float(samples.size())
	var p95 := _percentile(samples, 0.95)
	var p99 := _percentile(samples, 0.99)
	var peak := samples[-1]
	var enemy_count := get_nodes_in_group("enemies").size()
	var effect_count: int = (
		int(visual_effects.active_sprites.size())
		if visual_effects != null
		else 0
	)
	var passed := (
		enemy_count >= 90
		and p95 <= 22.0
		and p99 <= 33.34
		and float(over_25_ms) / float(samples.size()) <= 0.02
	)
	var report := {
		"version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"sample_frames": samples.size(),
		"enemy_count": enemy_count,
		"active_vfx_at_end": effect_count,
		"max_active_vfx": max_active_vfx,
		"average_ms": snappedf(average, 0.01),
		"p95_ms": snappedf(p95, 0.01),
		"p99_ms": snappedf(p99, 0.01),
		"peak_ms": snappedf(peak, 0.01),
		"frames_over_25_ms": over_25_ms,
		"passed": passed,
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(REPORT_PATH).get_base_dir()
	)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write rendered profile report")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RENDERED PERFORMANCE PROFILE: ", JSON.stringify(report))
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _percentile(sorted_samples: Array[float], fraction: float) -> float:
	var index := clampi(
		ceili(float(sorted_samples.size()) * fraction) - 1,
		0,
		sorted_samples.size() - 1
	)
	return sorted_samples[index]


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
