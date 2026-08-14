class_name EncounterDirector
extends Node


signal phase_changed(phase_id: StringName, title: String)
signal pressure_changed(scale: float, reason: StringName)
signal boss_warning_started(message: String, duration: float)
signal arena_lock_changed(locked: bool)

const PRESSURE_SAMPLE_INTERVAL := 0.5
const PINCER_ENCOUNTER_TIME := 555.0
const CROSSFIRE_ENCOUNTER_TIME := 615.0
const BOSS_WARNING_TIME := 630.0
const ARENA_LOCK_TIME := 654.0

var run_manager: RunManager
var enemy_spawner: Node
var player: Koda
var phases: Array[Dictionary] = []
var current_phase_index: int = -1
var pressure_scale: float = 1.0
var pressure_reason: StringName = &"nominal"
var sample_remaining: float = 0.0
var boss_warning_emitted: bool = false
var arena_locked: bool = false
var repeated_death_factor: float = 1.0
var special_encounters_triggered: Dictionary = {}


func setup(
	manager: RunManager,
	spawner: Node,
	run_player: Koda
) -> void:
	run_manager = manager
	enemy_spawner = spawner
	player = run_player
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	if balance != null and balance.has_method("get_encounter_phases"):
		phases = balance.call("get_encounter_phases")
	if phases.is_empty():
		phases = _fallback_phases()
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		var stats := Dictionary(meta_progression.call("get_statistics"))
		var deaths := int(stats.get("deaths", 0))
		repeated_death_factor = (
			0.88 if deaths >= 8 else (0.94 if deaths >= 3 else 1.0)
		)
	_update_phase(0.0, true)


func _process(delta: float) -> void:
	if (
		run_manager == null
		or player == null
		or run_manager.state != RunManager.RunState.PLAYING
	):
		return
	var elapsed := run_manager.elapsed_seconds
	_update_phase(elapsed)
	_update_special_encounters(elapsed)
	if not boss_warning_emitted and elapsed >= BOSS_WARNING_TIME:
		boss_warning_emitted = true
		boss_warning_started.emit(
			"WARDEN SIGNAL DETECTED // CONTAINMENT SEALING",
			3.2
		)
		if enemy_spawner != null:
			enemy_spawner.call("begin_recovery", 18.0)
	if not arena_locked and elapsed >= ARENA_LOCK_TIME:
		arena_locked = true
		arena_lock_changed.emit(true)
		if enemy_spawner != null:
			enemy_spawner.call("stop_spawning")

	sample_remaining -= delta
	if sample_remaining <= 0.0:
		sample_remaining = PRESSURE_SAMPLE_INTERVAL
		_update_adaptive_pressure(elapsed)
		_record_telemetry_sample(elapsed)


func _update_special_encounters(elapsed: float) -> void:
	if (
		elapsed >= PINCER_ENCOUNTER_TIME
		and not special_encounters_triggered.has(&"pincer")
	):
		_trigger_special_encounter(
			&"pincer",
			"HOSTILES FLANKING // KEEP MOVING"
		)
	if (
		elapsed >= CROSSFIRE_ENCOUNTER_TIME
		and not special_encounters_triggered.has(&"crossfire")
	):
		_trigger_special_encounter(
			&"crossfire",
			"RANGED SIGNATURES // CROSSFIRE FORMING"
		)


func _trigger_special_encounter(
	encounter_id: StringName,
	warning: String
) -> void:
	special_encounters_triggered[encounter_id] = true
	if enemy_spawner != null:
		enemy_spawner.call("queue_special_encounter", encounter_id)
	boss_warning_started.emit(warning, 2.2)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"record_encounter_phase",
			StringName("special_%s" % String(encounter_id)),
			run_manager.elapsed_seconds
		)


func _update_phase(elapsed: float, force: bool = false) -> void:
	var next_index := _phase_index_for_time(elapsed)
	if not force and next_index == current_phase_index:
		return
	current_phase_index = next_index
	var phase := phases[current_phase_index]
	if enemy_spawner != null:
		enemy_spawner.call("apply_director_phase", phase)
	phase_changed.emit(
		StringName(phase.get("id", "phase_%d" % current_phase_index)),
		String(phase.get("title", "ENCOUNTER"))
	)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"record_encounter_phase",
			StringName(phase.get("id", "")),
			elapsed
		)


func _update_adaptive_pressure(elapsed: float) -> void:
	var next_scale := 1.0
	var next_reason: StringName = &"nominal"
	var health_ratio := (
		player.current_health / maxf(player.max_health, 1.0)
	)
	if health_ratio <= 0.28:
		next_scale = 0.58
		next_reason = &"critical_health"
	elif health_ratio <= 0.48:
		next_scale = 0.78
		next_reason = &"low_health"

	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	var density_limit := 50
	if enemy_spawner != null:
		density_limit = maxi(
			int(enemy_spawner.get("maximum_enemies")),
			1
		)
	if enemy_count >= int(float(density_limit) * 0.94):
		next_scale = minf(next_scale, 0.62)
		next_reason = &"density_relief"
	elif enemy_count >= int(float(density_limit) * 0.82):
		next_scale = minf(next_scale, 0.82)
		next_reason = &"density_guard"

	if elapsed < 180.0:
		next_scale *= repeated_death_factor
		if repeated_death_factor < 1.0 and next_reason == &"nominal":
			next_reason = &"imprint_assist"

	if (
		enemy_spawner != null
		and bool(enemy_spawner.call("is_recovery_active"))
	):
		next_scale = minf(next_scale, 0.70)
		next_reason = &"post_rush_recovery"

	next_scale = clampf(next_scale, 0.50, 1.0)
	if (
		absf(next_scale - pressure_scale) > 0.02
		or next_reason != pressure_reason
	):
		pressure_scale = next_scale
		pressure_reason = next_reason
		if enemy_spawner != null:
			enemy_spawner.call(
				"set_director_pressure",
				pressure_scale,
				pressure_reason
			)
		run_manager.affinity_offer_pressure = (
			1.65 if _is_build_behind_curve() else 1.0
		)
		pressure_changed.emit(pressure_scale, pressure_reason)


func _is_build_behind_curve() -> bool:
	var owned_levels := 0
	for level in player.upgrade_levels.values():
		owned_levels += int(level)
	var expected := maxi(player.current_level - 1, 1)
	return owned_levels < int(float(expected) * 0.72)


func _record_telemetry_sample(elapsed: float) -> void:
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry == null:
		return
	telemetry.call(
		"record_runtime_sample",
		elapsed,
		get_tree().get_nodes_in_group("enemies").size(),
		(
			get_tree().get_nodes_in_group("enemy_projectiles").size()
			+ get_tree().get_nodes_in_group("player_projectiles").size()
		),
		int(_active_vfx_count()),
		pressure_scale,
		pressure_reason
	)


func _active_vfx_count() -> int:
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return 0
	return Array(visual_effects.get("active_sprites")).size()


func _phase_index_for_time(elapsed: float) -> int:
	for index in range(phases.size()):
		var phase := phases[index]
		if (
			elapsed >= float(phase.get("start", 0.0))
			and elapsed < float(phase.get("end", INF))
		):
			return index
	return maxi(phases.size() - 1, 0)


func _fallback_phases() -> Array[Dictionary]:
	return [
		{"id": "awakening", "title": "AWAKENING", "start": 0.0, "end": 120.0, "threat_budget": 18.0},
		{"id": "adaptation", "title": "ADAPTATION", "start": 120.0, "end": 240.0, "threat_budget": 28.0},
		{"id": "build_check", "title": "SYSTEM STRESS", "start": 240.0, "end": 360.0, "threat_budget": 39.0},
		{"id": "compound_pressure", "title": "COMPOUND PRESSURE", "start": 360.0, "end": 540.0, "threat_budget": 52.0},
		{"id": "containment_failure", "title": "CONTAINMENT FAILURE", "start": 540.0, "end": 660.0, "threat_budget": 62.0},
		{"id": "warden_protocol", "title": "WARDEN PROTOCOL", "start": 660.0, "end": 720.0, "threat_budget": 0.0},
	]
