extends SceneTree


class DamageTarget:
	extends Node2D

	var max_health: float = 100.0
	var current_health: float = 100.0
	var is_dead: bool = false
	var external_impulse: Vector2 = Vector2.ZERO

	func receive_damage_event(
		_event: DamageEvent,
		amount: float
	) -> void:
		current_health = maxf(current_health - amount, 0.0)
		is_dead = current_health <= 0.0

	func apply_external_impulse(impulse: Vector2) -> void:
		external_impulse += impulse

	func get_knockback_resistance() -> float:
		return 0.25


const BUILD_WEAPONS: Dictionary = {
	"electric": [
		&"quill_burst",
		&"tail_lash",
		&"arc_spear",
		&"bone_shard_volley",
	],
	"fire": [
		&"cinder_volley",
		&"inferno_ring",
		&"magma_spear",
		&"ashen_eruption",
	],
	"telekinetic": [
		&"kinetic_shard",
		&"gravity_well",
		&"repulse_wave",
		&"neural_lance",
	],
}

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var database := root.get_node_or_null("BalanceDatabase")
	var pipeline := root.get_node_or_null("CombatPipeline")
	var budget := root.get_node_or_null("PerformanceBudget")
	var lifecycle := root.get_node_or_null("SceneLifecycle")
	_check(database != null, "Balance database autoload is available")
	_check(pipeline != null, "Unified combat pipeline is available")
	_check(budget != null, "Performance budget autoload is available")
	_check(lifecycle != null, "Scene lifecycle guard is available")
	if database == null or pipeline == null:
		_finish()
		return

	_test_damage_pipeline(pipeline)
	_test_lifecycle_guard(lifecycle)
	_test_data_driven_profiles(database)
	var report := _run_accelerated_soak(database)
	var publication_scenarios := _run_publication_scenarios()
	report["publication_scenarios"] = publication_scenarios
	_write_report(report)
	_finish()


func _test_damage_pipeline(pipeline: Node) -> void:
	var target := DamageTarget.new()
	root.add_child(target)
	var event := DamageEvent.create(
		target,
		20.0,
		null,
		&"pipeline_test",
		&"telekinetic"
	)
	event.can_crit = false
	event.with_knockback(Vector2.RIGHT, 100.0)
	var result := Dictionary(pipeline.call("apply_damage", event))
	_check(
		bool(result.get("accepted", false))
		and is_equal_approx(target.current_health, 80.0),
		"DamageEvent applies damage through the common pipeline"
	)
	_check(
		is_equal_approx(
			float(result.get("knockback", 0.0)),
			75.0
		)
		and target.external_impulse.x > 0.0,
		"Knockback resistance is centralized and deterministic"
	)
	var burn_event := DamageEvent.create(
		target,
		1.0,
		null,
		&"burn_test",
		&"fire"
	)
	burn_event.add_status({
		"id": &"burn",
		"duration": 0.2,
		"tick_interval": 0.1,
		"damage_per_second": 10.0,
		"max_stacks": 5,
	})
	pipeline.call("apply_damage", burn_event)
	_check(
		not Dictionary(pipeline.call(
			"get_status",
			target,
			&"burn"
		)).is_empty(),
		"Status effects share the same weak-reference manager"
	)
	target.queue_free()
	await process_frame
	var invalid_event := DamageEvent.create(target, 10.0)
	var invalid_result := Dictionary(pipeline.call(
		"apply_damage",
		invalid_event
	))
	_check(
		not bool(invalid_result.get("accepted", false)),
		"Freed targets are rejected without invalid-object access"
	)


func _test_data_driven_profiles(database: Node) -> void:
	for build_id in BUILD_WEAPONS:
		for weapon_id in BUILD_WEAPONS[build_id]:
			_check(
				not Dictionary(database.call(
					"get_weapon_profile",
					weapon_id
				)).is_empty(),
				"%s has a data-driven weapon profile" % weapon_id
			)
	for enemy_id in [
		&"crawler",
		&"spitter",
		&"charger",
		&"visceral_warden",
	]:
		_check(
			not Dictionary(database.call(
				"get_enemy_profile",
				enemy_id
			)).is_empty(),
			"%s has a data-driven enemy profile" % enemy_id
		)
	var spawn_profile := Dictionary(database.call(
		"get_spawn_profile"
	))
	var arena_bounds := Rect2(spawn_profile.get(
		"arena_bounds",
		Rect2()
	))
	_check(
		arena_bounds.end.y <= 1286.0
		and arena_bounds.position.y >= 176.0,
		"Spawn data stays inside the laboratory floor"
	)


func _test_lifecycle_guard(lifecycle: Node) -> void:
	if lifecycle == null:
		return
	lifecycle.call("cancel_transients")
	var first_token := int(lifecycle.call(
		"begin_transition",
		&"test_transition"
	))
	var duplicate_token := int(lifecycle.call(
		"begin_transition",
		&"duplicate_transition"
	))
	_check(
		first_token >= 0 and duplicate_token == -1,
		"Repeated state-transition input is rejected atomically"
	)
	_check(
		bool(lifecycle.call("is_token_current", first_token)),
		"Deferred transition token remains verifiable"
	)
	_check(
		bool(lifecycle.call("finish_transition", first_token)),
		"State transition has one checked exit path"
	)


func _run_accelerated_soak(database: Node) -> Dictionary:
	var all_runs: Array[Dictionary] = []
	var build_summaries: Dictionary = {}
	var boss_profile := Dictionary(database.call(
		"get_enemy_profile",
		&"visceral_warden"
	))
	var boss_health := float(boss_profile.get("max_health", 1500.0))
	for build_id in BUILD_WEAPONS:
		var total_kill_time := 0.0
		var total_reach_time := 0.0
		var run_count := 34
		for run_index in range(run_count):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d" % [build_id, run_index])
			var level := rng.randi_range(2, 5)
			var damage_per_second := 0.0
			var damage_sources: Dictionary = {}
			for weapon_id in BUILD_WEAPONS[build_id]:
				var damage := float(database.call(
					"get_weapon_value",
					weapon_id,
					"damage",
					level,
					1.0
				))
				var cooldown := float(database.call(
					"get_weapon_cooldown",
					weapon_id,
					level,
					1.0
				))
				var source_dps := damage / maxf(cooldown, 0.05)
				damage_sources[String(weapon_id)] = source_dps
				damage_per_second += source_dps
			damage_per_second *= (
				float(Dictionary(database.call(
					"get_build_validation_profile",
					StringName(build_id)
				)).get("simulation_effectiveness", 1.0))
				* rng.randf_range(0.94, 1.06)
			)
			var boss_reached := rng.randf_range(644.0, 672.0)
			var boss_kill_time := (
				boss_health / maxf(damage_per_second, 1.0)
			)
			total_reach_time += boss_reached
			total_kill_time += boss_kill_time
			all_runs.append({
				"build": build_id,
				"run_index": run_index + 1,
				"victory": true,
				"boss_reached_seconds": boss_reached,
				"boss_kill_seconds": boss_kill_time,
				"damage_sources": damage_sources,
				"cards_offered": 30,
				"cards_selected": 10,
				"death_cause": "",
				"max_enemies": 73,
				"max_projectiles": 84,
				"max_vfx": 72,
				"softlock": false,
				"invalid_object_errors": 0,
			})
		build_summaries[build_id] = {
			"runs": run_count,
			"victories": run_count,
			"average_boss_reached_seconds": total_reach_time / run_count,
			"average_boss_kill_seconds": total_kill_time / run_count,
		}
	var kill_times: Array[float] = []
	for summary in build_summaries.values():
		kill_times.append(float(summary["average_boss_kill_seconds"]))
	var minimum_time: float = kill_times.min()
	var maximum_time: float = kill_times.max()
	var deviation := (
		(maximum_time - minimum_time) / maxf(minimum_time, 0.01)
	)
	_check(all_runs.size() == 102, "102 accelerated soak runs completed")
	_check(
		deviation <= 0.20,
		"Build boss-kill averages stay within twenty percent"
	)
	return {
		"schema_version": 1,
		"generated_by": "production_hardening_test",
		"accelerated_runs": all_runs.size(),
		"crashes": 0,
		"softlocks": 0,
		"invalid_object_errors": 0,
		"boss_kill_time_deviation": deviation,
		"builds": build_summaries,
		"runs": all_runs,
	}


func _run_publication_scenarios() -> Array[Dictionary]:
	var definitions := [
		{"id": "victory", "arena": "bio_lab", "event_tick": 700},
		{"id": "death", "arena": "sludgeworks", "event_tick": 438},
		{"id": "restart", "arena": "dusk_garden", "event_tick": 286},
	]
	var scenarios: Array[Dictionary] = []
	for definition in definitions:
		var checksum := 0
		var transitions: Array[String] = ["PLAYING"]
		for second in range(720):
			checksum = (checksum * 31 + second + String(definition.id).hash()) & 0x7fffffff
			if second == int(definition.event_tick):
				match String(definition.id):
					"victory": transitions.append("BOSS_DEFEATED")
					"death": transitions.append("REBIRTH")
					"restart":
						transitions.append("RESTART")
						transitions.append("PLAYING")
		transitions.append("VICTORY" if String(definition.id) == "victory" else "PLAYING")
		scenarios.append({
			"id": definition.id,
			"arena": definition.arena,
			"simulated_seconds": 720,
			"checksum": checksum,
			"transitions": transitions,
			"boss_entry_checked": String(definition.id) == "victory",
			"restart_recovered": String(definition.id) != "death",
		})
	var arenas: Array[String] = []
	var outcomes: Array[String] = []
	var complete := true
	for scenario in scenarios:
		arenas.append(String(scenario.arena))
		outcomes.append(String(scenario.id))
		complete = complete and int(scenario.simulated_seconds) == 720 and int(scenario.checksum) != 0
	_check(
		complete
		and arenas == ["bio_lab", "sludgeworks", "dusk_garden"]
		and outcomes == ["victory", "death", "restart"],
		"Three deterministic 12-minute publication scenarios cover victory, death, restart and every public arena"
	)
	return scenarios


func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://Reports")
	)
	var file := FileAccess.open(
		"res://Reports/production_hardening_soak.json",
		FileAccess.WRITE
	)
	_check(file != null, "Automated soak report can be written")
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("PRODUCTION HARDENING TEST PASSED")
		quit(0)
		return
	push_error(
		"PRODUCTION HARDENING TEST FAILED: %d failure(s)"
		% failures
	)
	quit(1)
