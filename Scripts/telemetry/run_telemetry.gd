extends Node


var current_run: Dictionary = {}
var completed_runs: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.damage_applied.connect(_on_damage_applied)


func start_run(build_id: StringName = &"unselected") -> void:
	current_run = {
		"build": String(build_id),
		"damage_sources": {},
		"cards_offered": {},
		"cards_selected": {},
		"kills": 0,
		"death_cause": "",
		"first_damage_seconds": -1.0,
		"death_times": [],
		"enemy_damage": {},
		"rushes": {},
		"active_rush": 0,
		"biomass_spawned": 0.0,
		"biomass_collected": 0.0,
		"biomass_missed": 0.0,
		"offer_sets": [],
		"offer_quality_average": 0.0,
		"encounter_phases": [],
		"runtime_samples": 0,
		"boss_reached_seconds": -1.0,
		"boss_kill_seconds": -1.0,
		"invalid_object_events": 0,
		"maxima": {},
		"build_triggers": {},
		"cooldown_refunded": {},
		"crowd_control_seconds": 0.0,
		"proc_events": 0,
		"active_play_seconds": 0.0,
		"menu_overlay_seconds": 0.0,
		"menu_time_ratio": 0.0,
	}


func set_build(build_id: StringName) -> void:
	if current_run.is_empty():
		start_run(build_id)
	else:
		current_run["build"] = String(build_id)


func record_card_offered(card_id: StringName) -> void:
	_increment_nested("cards_offered", String(card_id))


func record_card_selected(card_id: StringName) -> void:
	_increment_nested("cards_selected", String(card_id))


func record_build_trigger(build_item_id: StringName) -> void:
	_increment_nested("build_triggers", String(build_item_id))
	current_run["proc_events"] = int(current_run.get("proc_events", 0)) + 1


func record_cooldown_refund(weapon_id: StringName, seconds: float) -> void:
	_ensure_run()
	var values := Dictionary(current_run.get("cooldown_refunded", {}))
	values[String(weapon_id)] = float(values.get(String(weapon_id), 0.0)) + maxf(seconds, 0.0)
	current_run["cooldown_refunded"] = values


func record_crowd_control(seconds: float, target_count: int = 1) -> void:
	_ensure_run()
	current_run["crowd_control_seconds"] = float(current_run.get("crowd_control_seconds", 0.0)) + maxf(seconds, 0.0) * float(maxi(target_count, 0))


func record_offer_set(
	offers: Array,
	active_affinity: StringName,
	affinity_matches: int
) -> void:
	_ensure_run()
	var offer_ids: Array[String] = []
	var usable_count := 0
	var synergy_count := 0
	for offer in offers:
		if offer == null:
			continue
		offer_ids.append(String(offer.upgrade_id))
		usable_count += 1
		if not offer.get_effective_synergy_tags().is_empty():
			synergy_count += 1
	var quality := (
		0.50 * float(affinity_matches) / maxf(float(offers.size()), 1.0)
		+ 0.30 * float(usable_count) / maxf(float(offers.size()), 1.0)
		+ 0.20 * float(synergy_count) / maxf(float(offers.size()), 1.0)
	)
	var sets: Array = Array(current_run.get("offer_sets", []))
	sets.append({
		"affinity": String(active_affinity),
		"offers": offer_ids,
		"affinity_matches": affinity_matches,
		"quality": quality,
	})
	current_run["offer_sets"] = sets
	var quality_total := 0.0
	for offer_set in sets:
		quality_total += float(offer_set.get("quality", 0.0))
	current_run["offer_quality_average"] = quality_total / maxf(
		float(sets.size()),
		1.0
	)


func record_kill() -> void:
	_ensure_run()
	current_run["kills"] = int(current_run.get("kills", 0)) + 1


func record_player_damage(
	amount: float,
	enemy_type: StringName,
	elapsed_seconds: float
) -> void:
	_ensure_run()
	if float(current_run.get("first_damage_seconds", -1.0)) < 0.0:
		current_run["first_damage_seconds"] = elapsed_seconds
	var enemy_damage := Dictionary(current_run.get("enemy_damage", {}))
	var key := String(enemy_type if not enemy_type.is_empty() else &"unknown")
	enemy_damage[key] = float(enemy_damage.get(key, 0.0)) + amount
	current_run["enemy_damage"] = enemy_damage
	var active_rush := int(current_run.get("active_rush", 0))
	if active_rush > 0:
		var rushes := Dictionary(current_run.get("rushes", {}))
		var rush := Dictionary(rushes.get(str(active_rush), {}))
		rush["damage_taken"] = (
			float(rush.get("damage_taken", 0.0)) + amount
		)
		rushes[str(active_rush)] = rush
		current_run["rushes"] = rushes


func begin_rush(
	rush_number: int,
	elapsed_seconds: float,
	starting_health: float
) -> void:
	_ensure_run()
	current_run["active_rush"] = rush_number
	var rushes := Dictionary(current_run.get("rushes", {}))
	rushes[str(rush_number)] = {
		"start_seconds": elapsed_seconds,
		"starting_health": starting_health,
		"damage_taken": 0.0,
	}
	current_run["rushes"] = rushes


func end_rush(
	rush_number: int,
	elapsed_seconds: float,
	ending_health: float
) -> void:
	_ensure_run()
	var rushes := Dictionary(current_run.get("rushes", {}))
	var rush := Dictionary(rushes.get(str(rush_number), {}))
	rush["end_seconds"] = elapsed_seconds
	rush["ending_health"] = ending_health
	rush["health_lost"] = maxf(
		float(rush.get("starting_health", ending_health)) - ending_health,
		0.0
	)
	rushes[str(rush_number)] = rush
	current_run["rushes"] = rushes
	current_run["active_rush"] = 0


func record_biomass_spawned(amount: float) -> void:
	_ensure_run()
	current_run["biomass_spawned"] = (
		float(current_run.get("biomass_spawned", 0.0)) + amount
	)


func record_biomass_collected(amount: float) -> void:
	_ensure_run()
	current_run["biomass_collected"] = (
		float(current_run.get("biomass_collected", 0.0)) + amount
	)


func record_encounter_phase(
	phase_id: StringName,
	elapsed_seconds: float
) -> void:
	_ensure_run()
	var phase_events: Array = Array(
		current_run.get("encounter_phases", [])
	)
	phase_events.append({
		"id": String(phase_id),
		"seconds": elapsed_seconds,
	})
	current_run["encounter_phases"] = phase_events


func record_runtime_sample(
	_elapsed_seconds: float,
	enemy_count: int,
	projectile_count: int,
	vfx_count: int,
	pressure_scale: float,
	pressure_reason: StringName
) -> void:
	_ensure_run()
	var maxima := Dictionary(current_run.get("maxima", {}))
	maxima["enemies"] = maxi(
		int(maxima.get("enemies", 0)),
		enemy_count
	)
	maxima["projectiles"] = maxi(
		int(maxima.get("projectiles", 0)),
		projectile_count
	)
	maxima["vfx"] = maxi(int(maxima.get("vfx", 0)), vfx_count)
	current_run["maxima"] = maxima
	current_run["runtime_samples"] = (
		int(current_run.get("runtime_samples", 0)) + 1
	)
	current_run["last_pressure_scale"] = pressure_scale
	current_run["last_pressure_reason"] = String(pressure_reason)


func record_menu_timing(
	active_play_seconds: float,
	menu_overlay_seconds: float
) -> void:
	_ensure_run()
	current_run["active_play_seconds"] = maxf(active_play_seconds, 0.0)
	current_run["menu_overlay_seconds"] = maxf(menu_overlay_seconds, 0.0)
	var total := active_play_seconds + menu_overlay_seconds
	current_run["menu_time_ratio"] = (
		menu_overlay_seconds / total if total > 0.0 else 0.0
	)


func mark_boss_reached(elapsed_seconds: float) -> void:
	current_run["boss_reached_seconds"] = elapsed_seconds


func mark_boss_killed(elapsed_seconds: float) -> void:
	current_run["boss_kill_seconds"] = elapsed_seconds


func finish_run(
	victory: bool,
	elapsed_seconds: float,
	death_cause: StringName = &""
) -> Dictionary:
	current_run["victory"] = victory
	current_run["elapsed_seconds"] = elapsed_seconds
	current_run["death_cause"] = String(death_cause)
	current_run["biomass_missed"] = maxf(
		float(current_run.get("biomass_spawned", 0.0))
		- float(current_run.get("biomass_collected", 0.0)),
		0.0
	)
	if not victory:
		var death_times: Array = Array(
			current_run.get("death_times", [])
		)
		death_times.append(elapsed_seconds)
		current_run["death_times"] = death_times
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null:
		current_run["performance"] = Dictionary(
			budget.call("get_snapshot")
		)
	var finished := current_run.duplicate(true)
	completed_runs.append(finished)
	return finished


func _on_damage_applied(
	event: DamageEvent,
	result: Dictionary
) -> void:
	if not bool(result.get("accepted", false)):
		return
	var sources := Dictionary(current_run.get("damage_sources", {}))
	var key := String(event.source_id)
	sources[key] = (
		float(sources.get(key, 0.0))
		+ float(result.get("damage", 0.0))
	)
	current_run["damage_sources"] = sources


func _increment_nested(section: String, key: String) -> void:
	_ensure_run()
	var values := Dictionary(current_run.get(section, {}))
	values[key] = int(values.get(key, 0)) + 1
	current_run[section] = values


func _ensure_run() -> void:
	if current_run.is_empty():
		start_run()
