extends Node


signal enemy_spawned(enemy: Node2D)
signal enemy_defeated(enemy: Node2D)


@export_category("Spawn Settings")
@export var crawler_scene: PackedScene
@export var spitter_scene: PackedScene
@export var charger_scene: PackedScene
@export var spawn_interval: float = 1.18
@export var minimum_spawn_interval: float = 0.55
@export var spawn_distance: float = 560.0
@export var spawn_distance_variation: float = 90.0
@export var maximum_enemies: int = 24
@export var maximum_enemies_end: int = 55
@export var arena_bounds: Rect2 = Rect2(96.0, 176.0, 2368.0, 1110.0)
@export var viewport_half_extent: Vector2 = Vector2(640.0, 296.0)
@export var offscreen_margin: float = 36.0
@export var spawn_warning_duration: float = 1.0
@export_category("Swarm Density")
@export var early_batch_min: int = 2
@export var early_batch_max: int = 3

@export var mid_batch_min: int = 3
@export var mid_batch_max: int = 5

@export var late_batch_min: int = 4
@export var late_batch_max: int = 7

@export var batch_spawn_spacing: float = 0.045


@export_category("Enemy Mix")
@export_range(0.0, 1.0) var spitter_unlock_progress: float = 0.09
@export_range(0.0, 1.0) var charger_unlock_progress: float = 0.25
@export var spitter_end_weight: float = 0.54
@export var charger_end_weight: float = 0.48
@export var rush_spitter_weight_multiplier: float = 0.72
@export var rush_charger_weight_multiplier: float = 1.75

@export_category("Elite Mutations")
@export_range(0.0, 1.0) var elite_unlock_progress: float = 0.18
@export_range(0.0, 1.0) var elite_start_chance: float = 0.05
@export_range(0.0, 1.0) var elite_end_chance: float = 0.18
@export var elite_rush_bonus: float = 0.08

@export_category("Rush")
@export var rush_spawn_multiplier: float = 3.6
@export var rush_enemy_budget_bonus: int = 42
@export var rush_initial_burst: int = 18
@export var recovery_duration: float = 7.0
@export var recovery_interval_multiplier: float = 1.65
@export var recovery_enemy_budget_reduction: int = 8

@export_category("Encounter Rhythm")
@export var encounter_duration: float = 19.0
@export var profile_weight_bonus: float = 0.72
@export var maximum_same_type_in_a_row: int = 4

@onready var spawn_timer: Timer = $SpawnTimer
@onready var enemies_container: Node2D = $"../Entities/Enemies"

var player: Node2D
var starting_maximum_enemies: int
var current_run_progress: float = 0.0
var rush_active: bool = false
var recovery_time_remaining: float = 0.0
var encounter_time_remaining: float = 0.0
var encounter_profile: StringName = &"mixed"
var encounter_index: int = 0
var last_spawn_type: StringName = &""
var consecutive_same_type: int = 0
var director_pressure: float = 1.0
var director_pressure_reason: StringName = &"nominal"
var director_threat_budget: float = 18.0
var director_spawn_rate: float = 1.0
var director_profiles: Array = [&"mixed"]
var director_elite_cap: float = 1.0
var director_spitter_cap: float = 0.30
var director_charger_cap: float = 0.20
var director_phase_end_progress: float = 1.0
var global_spitter_cap: float = 0.30
var global_charger_cap: float = 0.20
var threat_costs: Dictionary = {
	&"crawler": 1.0,
	&"spitter": 2.3,
	&"charger": 3.4,
	&"elite_bonus": 1.8,
}
var minimum_player_distance: float = 610.0
var spawn_clearance_radius: float = 46.0
var occupied_clearance_radius: float = 52.0
var formation_queue: Array[Vector2] = []
var formation_serial: int = 0
var spawning_enabled: bool = true
var special_sequence_active: bool = false
var opening_wave_spawned: bool = false
var active_arena: Node
var pending_spawn_count: int = 0
var pending_spawn_threat: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	var spawn_profile: Dictionary = {}
	if balance != null:
		spawn_profile = Dictionary(balance.call("get_spawn_profile"))
	arena_bounds = Rect2(spawn_profile.get(
		"arena_bounds",
		Rect2(96.0, 176.0, 2368.0, 1110.0)
	))
	spawn_interval = float(spawn_profile.get(
		"spawn_interval",
		spawn_interval
	))
	minimum_spawn_interval = float(spawn_profile.get(
		"minimum_spawn_interval",
		minimum_spawn_interval
	))
	maximum_enemies = int(spawn_profile.get(
		"maximum_enemies",
		maximum_enemies
	))
	maximum_enemies_end = int(spawn_profile.get(
		"maximum_enemies_end",
		maximum_enemies_end
	))
	minimum_player_distance = float(spawn_profile.get(
		"minimum_player_distance",
		minimum_player_distance
	))
	spawn_clearance_radius = float(spawn_profile.get(
		"spawn_clearance_radius",
		spawn_clearance_radius
	))
	occupied_clearance_radius = float(spawn_profile.get(
		"occupied_clearance_radius",
		occupied_clearance_radius
	))
	global_spitter_cap = float(spawn_profile.get(
		"maximum_spitter_ratio",
		global_spitter_cap
	))
	global_charger_cap = float(spawn_profile.get(
		"maximum_charger_ratio",
		global_charger_cap
	))
	rush_enemy_budget_bonus = int(spawn_profile.get(
		"rush_enemy_budget_bonus",
		rush_enemy_budget_bonus
	))
	director_spitter_cap = global_spitter_cap
	director_charger_cap = global_charger_cap
	threat_costs.merge(
		Dictionary(spawn_profile.get("threat_costs", {})),
		true
	)
	starting_maximum_enemies = maximum_enemies

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start(0.45)
	encounter_time_remaining = encounter_duration
	_resolve_active_arena()


func configure_arena(arena: Node) -> void:
	active_arena = arena
	if (
		is_instance_valid(active_arena)
		and active_arena.has_method("get_play_bounds")
	):
		arena_bounds = Rect2(active_arena.call("get_play_bounds"))
	formation_queue.clear()


func _resolve_active_arena() -> Node:
	if is_instance_valid(active_arena):
		return active_arena
	if not is_inside_tree():
		return null
	active_arena = get_tree().get_first_node_in_group("walkable_arena")
	return active_arena


func _process(delta: float) -> void:
	# A gameplay spawner may only be stopped deliberately by a special
	# formation, the boss transition, death, or scene teardown. Recover from a
	# lost/stopped timer instead of silently leaving the remainder of the run
	# empty.
	if spawning_enabled and not special_sequence_active and spawn_timer.is_stopped():
		spawn_timer.start(maxf(spawn_timer.wait_time, 0.12))
	if recovery_time_remaining > 0.0:
		recovery_time_remaining = maxf(
			recovery_time_remaining - delta,
			0.0
		)
		if is_zero_approx(recovery_time_remaining):
			_refresh_spawn_settings()

	if rush_active:
		return

	encounter_time_remaining -= delta
	if encounter_time_remaining <= 0.0:
		_advance_encounter_profile()


func spawn_enemy() -> void:
	if not spawning_enabled:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	if (
		get_tree().get_nodes_in_group("enemies").size()
		+ pending_spawn_count
		>= maximum_enemies
	):
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_enemy")):
		return
	if (
		budget != null
		and float(budget.call("get_spawn_pressure_scale")) < 0.99
		and randf() > float(budget.call("get_spawn_pressure_scale"))
	):
		return

	var enemy_scene := _select_enemy_scene()

	if enemy_scene == null:
		push_warning("EnemySpawner: No enemy scene is available.")
		return

	var enemy_type := _enemy_type_for_scene(enemy_scene)
	if (
		get_current_threat()
		+ pending_spawn_threat
		+ float(threat_costs.get(enemy_type, 1.0))
		> get_effective_threat_budget()
	):
		return
	var spawn_position := _get_next_spawn_position()
	if not _is_valid_spawn_position(spawn_position):
		return
	_schedule_enemy_spawn(enemy_scene, enemy_type, spawn_position)

func _on_spawn_timer_timeout() -> void:
	if not spawning_enabled:
		return

	var batch_size := _get_current_batch_size()

	for index in range(batch_size):
		if not spawning_enabled:
			break

		spawn_enemy()

		if index < batch_size - 1:
			await get_tree().create_timer(
				batch_spawn_spacing,
				false
			).timeout

func _get_current_batch_size() -> int:
	if rush_active:
		return randi_range(6, 10)

	if current_run_progress < 0.25:
		return randi_range(
			early_batch_min,
			early_batch_max
		)

	if current_run_progress < 0.60:
		return randi_range(
			mid_batch_min,
			mid_batch_max
		)

	return randi_range(
		late_batch_min,
		late_batch_max
	)

func _spawn_rush_crawler_partner(anchor: Vector2) -> void:
	if crawler_scene == null:
		return
	var tangent := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var candidate := _clamp_to_arena(anchor + tangent * randf_range(58.0, 104.0))
	if not _is_valid_spawn_position(candidate):
		return
	_schedule_enemy_spawn(crawler_scene, &"crawler", candidate, false)


func spawn_opening_wave() -> void:
	if opening_wave_spawned or not spawning_enabled:
		return
	opening_wave_spawned = true
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or crawler_scene == null:
		return
	# Authored opening pressure: visible quickly, but far enough to react.
	var angles := [-0.62, -0.38, -0.12, 0.18, 0.44, 2.48, 2.72, 2.96]
	for index in range(angles.size()):
		var distance := 405.0 + float(index % 2) * 46.0
		var candidate := _clamp_to_arena(
			player.global_position
			+ Vector2.RIGHT.rotated(float(angles[index])) * distance
		)
		if not _is_valid_spawn_position(candidate):
			continue
		_schedule_enemy_spawn(crawler_scene, &"crawler", candidate, false)
	spawn_timer.start(0.55)


func spawn_boss_reinforcements(count: int = 14) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or crawler_scene == null:
		return
	_play_boss_reinforcement_wave.call_deferred(maxi(count, 1))


func _play_boss_reinforcement_wave(count: int) -> void:
	formation_queue.clear()
	var spawned := 0
	var attempts := 0
	while spawned < count and attempts < count * 4:
		attempts += 1
		if not is_inside_tree():
			return
		var scene := crawler_scene
		var enemy_type: StringName = &"crawler"
		if spitter_scene != null and spawned % 5 == 4:
			scene = spitter_scene
			enemy_type = &"spitter"
		var spawn_position := _find_spawn_position()
		if not _is_valid_spawn_position(spawn_position):
			spawn_position = _get_next_spawn_position()
		if not _is_valid_spawn_position(spawn_position):
			continue
		if _schedule_enemy_spawn(scene, enemy_type, spawn_position, false):
			spawned += 1
		await get_tree().create_timer(0.045, false).timeout


func _schedule_enemy_spawn(
	scene: PackedScene,
	enemy_type: StringName,
	spawn_position: Vector2,
	allow_rush_partners: bool = true
) -> bool:
	if scene == null or not spawning_enabled or not is_inside_tree():
		return false
	var threat_cost := float(threat_costs.get(enemy_type, 1.0))
	if (
		get_tree().get_nodes_in_group("enemies").size()
		+ pending_spawn_count
		>= maximum_enemies
	):
		return false
	if (
		get_current_threat() + pending_spawn_threat + threat_cost
		> get_effective_threat_budget()
	):
		return false
	pending_spawn_count += 1
	pending_spawn_threat += threat_cost
	var warning := _create_spawn_warning(spawn_position, enemy_type)
	_complete_telegraphed_spawn(
		scene,
		enemy_type,
		spawn_position,
		threat_cost,
		allow_rush_partners,
		warning
	)
	return true


func _complete_telegraphed_spawn(
	scene: PackedScene,
	enemy_type: StringName,
	spawn_position: Vector2,
	threat_cost: float,
	allow_rush_partners: bool,
	warning: Node2D
) -> void:
	await get_tree().create_timer(spawn_warning_duration, false).timeout
	pending_spawn_count = maxi(pending_spawn_count - 1, 0)
	pending_spawn_threat = maxf(pending_spawn_threat - threat_cost, 0.0)
	if is_instance_valid(warning):
		warning.queue_free()
	if not spawning_enabled or not is_inside_tree():
		return
	var enemy := _acquire_enemy(scene)
	if enemy == null:
		return
	enemy.global_position = spawn_position
	enemy.reset_physics_interpolation()
	enemy.set_meta("enemy_type", enemy_type)
	enemy.set_meta("threat_cost", threat_cost)
	enemy.set_meta("formation_serial", formation_serial)
	_try_apply_elite_modifier(enemy)
	# Mass crawlers remain clean and cheap. Specials arrive through a compact
	# smoke veil after their one-second X telegraph has completed.
	if enemy_type != &"crawler":
		var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
		if visual_effects != null:
			visual_effects.call(
				"play", &"enemy_spawn", spawn_position,
				0.82 if enemy_type == &"charger" else 0.68
			)
	if enemy.has_signal("died"):
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy)
	# Rush crawler picks arrive as a pair. Each partner gets its own full
	# one-second warning, so added swarm pressure never becomes a contact trap.
	if allow_rush_partners and rush_active and enemy_type == &"crawler":
		_spawn_rush_crawler_partner(spawn_position)
		_spawn_rush_crawler_partner(spawn_position)


func _create_spawn_warning(
	spawn_position: Vector2,
	enemy_type: StringName
) -> Node2D:
	var warning := Node2D.new()
	warning.name = "EnemySpawnWarning"
	warning.global_position = spawn_position
	warning.z_index = 18
	warning.add_to_group("spawn_warnings")
	var size := 25.0
	if enemy_type == &"spitter":
		size = 30.0
	elif enemy_type == &"charger":
		size = 40.0
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for is_shadow in [true, false]:
		for diagonal in [-1.0, 1.0]:
			var stroke := Line2D.new()
			stroke.antialiased = false
			stroke.width = 9.0 if is_shadow else 4.0
			stroke.default_color = (
				Color("450327") if is_shadow else Color("ff0546")
			)
			stroke.material = unshaded
			stroke.add_point(Vector2(-size, -size * diagonal))
			stroke.add_point(Vector2(size, size * diagonal))
			warning.add_child(stroke)
	var parent := get_tree().get_first_node_in_group("effects_container")
	if parent == null:
		parent = enemies_container.get_parent()
	parent.add_child(warning)
	warning.global_position = spawn_position
	var pulse := warning.create_tween()
	pulse.set_loops(2)
	pulse.tween_property(warning, "scale", Vector2.ONE * 1.10, spawn_warning_duration * 0.25)
	pulse.tween_property(warning, "scale", Vector2.ONE * 0.88, spawn_warning_duration * 0.25)
	return warning


func _acquire_enemy(scene: PackedScene) -> Node2D:
	if scene == null or not is_instance_valid(enemies_container):
		return null
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null:
		return runtime_pool.call("acquire", scene, enemies_container) as Node2D
	var enemy := scene.instantiate() as Node2D
	if enemy != null:
		enemies_container.add_child(enemy)
	return enemy


func _try_apply_elite_modifier(enemy: Node2D) -> void:
	if current_run_progress < elite_unlock_progress:
		return
	var elite_phase := inverse_lerp(
		elite_unlock_progress,
		1.0,
		current_run_progress
	)
	var chance := lerpf(elite_start_chance, elite_end_chance, elite_phase)
	if current_run_progress <= director_phase_end_progress + 0.02:
		chance = minf(chance, director_elite_cap)
	if rush_active:
		chance += elite_rush_bonus
	if randf() > chance:
		return
	var modifier := EliteModifier.new()
	enemy.add_child(modifier)
	modifier.initialize(
		enemy,
		randi_range(
			EliteModifier.Type.ARMORED,
			EliteModifier.Type.REGENERATIVE
		)
	)
	enemy.set_meta(
		"threat_cost",
		float(enemy.get_meta("threat_cost", 1.0))
		+ float(threat_costs.get(&"elite_bonus", 1.8))
	)


func _select_enemy_scene() -> PackedScene:
	var weights := get_spawn_weights()
	if (
		consecutive_same_type >= maximum_same_type_in_a_row
		and weights.size() > 1
		and weights.has(last_spawn_type)
	):
		weights[last_spawn_type] = (
			float(weights[last_spawn_type]) * 0.04
		)
	var total_weight: float = 0.0

	for weight in weights.values():
		total_weight += float(weight)

	if total_weight <= 0.0:
		return crawler_scene

	var roll := randf() * total_weight
	var running_weight := 0.0

	for enemy_type: StringName in weights:
		running_weight += float(weights[enemy_type])

		if roll <= running_weight:
			_record_spawn_type(enemy_type)
			match enemy_type:
				&"crawler":
					return crawler_scene
				&"spitter":
					return spitter_scene
				&"charger":
					return charger_scene

	_record_spawn_type(&"crawler")
	return crawler_scene


func _record_spawn_type(enemy_type: StringName) -> void:
	if enemy_type == last_spawn_type:
		consecutive_same_type += 1
	else:
		last_spawn_type = enemy_type
		consecutive_same_type = 1


func get_spawn_weights() -> Dictionary:
	var weights: Dictionary = {}

	if crawler_scene != null:
		weights[&"crawler"] = 1.18

	if spitter_scene != null and current_run_progress >= spitter_unlock_progress:
		var spitter_phase := inverse_lerp(
			spitter_unlock_progress,
			1.0,
			current_run_progress
		)
		var spitter_weight := lerpf(0.22, spitter_end_weight, spitter_phase)

		if rush_active:
			spitter_weight *= rush_spitter_weight_multiplier

		weights[&"spitter"] = spitter_weight

	if charger_scene != null and current_run_progress >= charger_unlock_progress:
		var charger_phase := inverse_lerp(
			charger_unlock_progress,
			1.0,
			current_run_progress
		)
		var charger_weight := lerpf(0.16, charger_end_weight, charger_phase)

		if rush_active:
			charger_weight *= rush_charger_weight_multiplier

		weights[&"charger"] = charger_weight

	if not rush_active:
		match encounter_profile:
			&"swarm":
				if weights.has(&"crawler"):
					weights[&"crawler"] = (
						float(weights[&"crawler"]) + profile_weight_bonus
					)
			&"crossfire":
				if weights.has(&"spitter"):
					weights[&"spitter"] = (
						float(weights[&"spitter"])
						+ profile_weight_bonus
					)
			&"assault":
				if weights.has(&"charger"):
					weights[&"charger"] = (
						float(weights[&"charger"])
						+ profile_weight_bonus
					)

	_apply_enemy_ratio_caps(weights)

	return weights


func _apply_enemy_ratio_caps(weights: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var spitter_count := 0
	var charger_count := 0
	for enemy in enemies:
		var enemy_type := _enemy_type_for_node(enemy)
		if enemy_type == &"spitter":
			spitter_count += 1
		elif enemy_type == &"charger":
			charger_count += 1
	var future_total := float(enemies.size() + 1)
	var use_director_caps := (
		current_run_progress <= director_phase_end_progress + 0.02
	)
	var spitter_cap := (
		director_spitter_cap if use_director_caps else global_spitter_cap
	)
	var charger_cap := (
		director_charger_cap if use_director_caps else global_charger_cap
	)
	if (
		weights.has(&"spitter")
		and float(spitter_count + 1) / future_total > spitter_cap
	):
		weights[&"spitter"] = 0.0
	if (
		weights.has(&"charger")
		and float(charger_count + 1) / future_total > charger_cap
	):
		weights[&"charger"] = 0.0


func _advance_encounter_profile() -> void:
	var profiles: Array[StringName] = [
		&"mixed",
		&"swarm",
		&"crossfire",
		&"mixed",
		&"assault",
	]
	var available: Array[StringName] = [&"mixed", &"swarm"]
	if current_run_progress >= spitter_unlock_progress:
		available.append(&"crossfire")
	if current_run_progress >= charger_unlock_progress:
		available.append(&"assault")
	encounter_index = (encounter_index + 1) % profiles.size()
	encounter_profile = profiles[encounter_index]
	if encounter_profile not in available:
		encounter_profile = available[encounter_index % available.size()]
	encounter_time_remaining = encounter_duration * randf_range(0.86, 1.14)


func _find_spawn_position() -> Vector2:
	var camera_center := _get_camera_center()
	var minimum_distance := maxf(
		spawn_distance * 0.70,
		minimum_player_distance
	)
	var arena := _resolve_active_arena()
	if arena != null and arena.has_method("get_random_edge_spawn_position"):
		for _attempt in range(96):
			var candidate := Vector2(arena.call(
				"get_random_edge_spawn_position",
				spawn_clearance_radius
			))
			if (
				candidate.distance_to(player.global_position) >= minimum_distance
				and _is_offscreen(candidate, camera_center)
				and _is_valid_spawn_position(candidate)
			):
				return candidate
		for _attempt in range(64):
			var candidate := Vector2(arena.call(
				"get_random_walkable_position",
				spawn_clearance_radius
			))
			if (
				candidate.distance_to(player.global_position) >= minimum_distance
				and _is_offscreen(candidate, camera_center)
				and _is_valid_spawn_position(candidate)
			):
				return candidate

	for _attempt in range(36):
		var candidate := _random_spawn_zone_position()

		if (
			candidate.distance_to(player.global_position) >= minimum_distance
			and _is_offscreen(candidate, camera_center)
			and _is_valid_spawn_position(candidate)
		):
			return candidate

	for _attempt in range(36):
		var candidate := Vector2(
			randf_range(arena_bounds.position.x, arena_bounds.end.x),
			randf_range(arena_bounds.position.y, arena_bounds.end.y)
		)

		if (
			_is_offscreen(candidate, camera_center)
			and candidate.distance_to(player.global_position)
			>= minimum_distance
			and _is_valid_spawn_position(candidate)
		):
			return candidate

	var fallback := _get_farthest_arena_corner(camera_center)
	return _clamp_to_arena(
		fallback.move_toward(arena_bounds.get_center(), 72.0)
	)


func _get_next_spawn_position() -> Vector2:
	while not formation_queue.is_empty():
		var queued: Vector2 = formation_queue.pop_front()
		if _is_valid_spawn_position(queued):
			return queued
	var anchor := _find_spawn_position()
	formation_serial += 1
	_queue_formation_positions(anchor)
	return anchor


func _queue_formation_positions(anchor: Vector2) -> void:
	var group_size := (
		randi_range(7, 11)
		if rush_active
		else randi_range(3, 6)
	)
	if group_size <= 1:
		return
	var toward_player := anchor.direction_to(player.global_position)
	var tangent := Vector2(-toward_player.y, toward_player.x)
	for index in range(1, group_size):
		var side := -1.0 if index % 2 == 0 else 1.0
		var rank := float((index + 1) / 2)
		var candidate := anchor + tangent * side * rank * 56.0
		if encounter_profile in [&"assault", &"crossfire"]:
			candidate += toward_player * rank * 28.0
		elif encounter_profile == &"swarm":
			candidate += toward_player.rotated(side * 0.42) * rank * 24.0
		candidate = _clamp_to_arena(candidate)
		if (
			_is_offscreen(candidate, _get_camera_center())
			and _is_valid_spawn_position(candidate)
		):
			formation_queue.append(candidate)


func queue_special_encounter(encounter_id: StringName) -> void:
	if special_sequence_active or not spawning_enabled:
		return
	special_sequence_active = true
	encounter_profile = (
		&"crossfire" if encounter_id == &"crossfire" else &"assault"
	)
	formation_queue.clear()
	formation_serial += 1
	var first_anchor := _find_spawn_position()
	var opposite_anchor := _clamp_to_arena(
		arena_bounds.get_center() * 2.0 - first_anchor
	)
	_queue_special_side(first_anchor, 4)
	_queue_special_side(opposite_anchor, 4)
	spawn_timer.stop()
	_play_special_sequence.call_deferred()


func _queue_special_side(anchor: Vector2, count: int) -> void:
	var toward_player := anchor.direction_to(player.global_position)
	var tangent := Vector2(-toward_player.y, toward_player.x)
	for index in range(count):
		var centered_index := float(index) - float(count - 1) * 0.5
		var candidate := _clamp_to_arena(
			anchor + tangent * centered_index * 78.0
		)
		if (
			_is_offscreen(candidate, _get_camera_center())
			and _is_valid_spawn_position(candidate)
		):
			formation_queue.append(candidate)


func _play_special_sequence() -> void:
	var blocked_attempts := 0
	while not formation_queue.is_empty() and spawning_enabled:
		var queued_before := formation_queue.size()
		spawn_enemy()
		if formation_queue.size() == queued_before:
			blocked_attempts += 1
		else:
			blocked_attempts = 0
		# A saturated threat budget or temporarily blocked formation must not
		# leave the regular spawn timer stopped forever.
		if blocked_attempts >= 18:
			break
		await get_tree().create_timer(0.22, false).timeout
	special_sequence_active = false
	if spawning_enabled:
		_refresh_spawn_settings()
		spawn_timer.start()


func _random_spawn_zone_position() -> Vector2:
	var arena := _resolve_active_arena()
	if arena != null and arena.has_method("get_random_edge_spawn_position"):
		return Vector2(arena.call(
			"get_random_edge_spawn_position",
			spawn_clearance_radius
		))
	var inset := 58.0
	var left := arena_bounds.position.x + inset
	var right := arena_bounds.end.x - inset
	var top := arena_bounds.position.y + inset
	var bottom := arena_bounds.end.y - inset
	match randi_range(0, 3):
		0:
			return Vector2(randf_range(left, right), top)
		1:
			return Vector2(right, randf_range(top, bottom))
		2:
			return Vector2(randf_range(left, right), bottom)
		_:
			return Vector2(left, randf_range(top, bottom))


func _is_valid_spawn_position(candidate: Vector2) -> bool:
	if not arena_bounds.grow(-24.0).has_point(candidate):
		return false
	var arena := _resolve_active_arena()
	if (
		arena != null
		and arena.has_method("is_walkable_position")
		and not bool(arena.call(
			"is_walkable_position",
			candidate,
			spawn_clearance_radius
		))
	):
		return false
	if not is_instance_valid(player):
		return false
	if _is_position_occupied(candidate):
		return false
	if _physics_space_is_blocked(candidate):
		return false
	if not _has_viable_route(candidate):
		return false
	return true


func _is_position_occupied(candidate: Vector2) -> bool:
	var clearance_squared := occupied_clearance_radius * occupied_clearance_radius
	var local_density := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var distance_squared := (
			(enemy as Node2D).global_position.distance_squared_to(candidate)
		)
		if distance_squared < clearance_squared:
			return true
		if distance_squared < 230.0 * 230.0:
			local_density += 1
	if rush_active and local_density >= 5:
		return true
	return false


func _physics_space_is_blocked(candidate: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var shape := CircleShape2D.new()
	shape.radius = spawn_clearance_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if player is CollisionObject2D:
		query.exclude = [(player as CollisionObject2D).get_rid()]
	return not player.get_world_2d().direct_space_state.intersect_shape(
		query,
		1
	).is_empty()


func _has_viable_route(candidate: Vector2) -> bool:
	var arena := _resolve_active_arena()
	if arena != null and arena.has_method("has_walkable_route"):
		return bool(arena.call(
			"has_walkable_route",
			candidate,
			player.global_position
		))
	var space: PhysicsDirectSpaceState2D = (
		player.get_world_2d().direct_space_state
	)
	var direction := candidate.direction_to(player.global_position)
	var tangent := Vector2(-direction.y, direction.x) * 54.0
	var clear_rays := 0
	for offset in [Vector2.ZERO, tangent, -tangent]:
		var query := PhysicsRayQueryParameters2D.create(
			candidate + offset,
			player.global_position + offset,
			1
		)
		query.collide_with_areas = false
		if player is CollisionObject2D:
			query.exclude = [(player as CollisionObject2D).get_rid()]
		if space.intersect_ray(query).is_empty():
			clear_rays += 1
	return clear_rays > 0


func _get_camera_center() -> Vector2:
	var camera := player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		return player.global_position

	return camera.get_screen_center_position()


func _clamp_to_arena(position_to_clamp: Vector2) -> Vector2:
	var arena := _resolve_active_arena()
	if arena != null and arena.has_method("get_closest_walkable_position"):
		return Vector2(arena.call(
			"get_closest_walkable_position",
			position_to_clamp,
			spawn_clearance_radius
		))
	return Vector2(
		clampf(
			position_to_clamp.x,
			arena_bounds.position.x,
			arena_bounds.end.x
		),
		clampf(
			position_to_clamp.y,
			arena_bounds.position.y,
			arena_bounds.end.y
		)
	)


func _is_offscreen(
	position_to_check: Vector2,
	camera_center: Vector2
) -> bool:
	var offset := (position_to_check - camera_center).abs()

	return (
		offset.x > viewport_half_extent.x + offscreen_margin
		or offset.y > viewport_half_extent.y + offscreen_margin
	)


func _get_farthest_arena_corner(camera_center: Vector2) -> Vector2:
	var corners: Array[Vector2] = [
		arena_bounds.position,
		Vector2(arena_bounds.end.x, arena_bounds.position.y),
		arena_bounds.end,
		Vector2(arena_bounds.position.x, arena_bounds.end.y)
	]
	var farthest_corner := corners[0]
	var farthest_distance := -1.0

	for corner in corners:
		var distance := corner.distance_squared_to(camera_center)

		if distance > farthest_distance:
			farthest_distance = distance
			farthest_corner = corner

	return farthest_corner


func set_run_progress(progress: float) -> void:
	current_run_progress = clampf(progress, 0.0, 1.0)
	_refresh_spawn_settings()


func apply_director_phase(phase: Dictionary) -> void:
	director_threat_budget = maxf(
		float(phase.get("threat_budget", 18.0)),
		0.0
	)
	director_spawn_rate = maxf(
		float(phase.get("spawn_rate", 1.0)),
		0.2
	)
	director_profiles = Array(phase.get("profiles", [&"mixed"]))
	director_elite_cap = clampf(
		float(phase.get("elite_cap", 1.0)),
		0.0,
		1.0
	)
	director_spitter_cap = clampf(
		float(phase.get("spitter_cap", director_spitter_cap)),
		0.0,
		1.0
	)
	director_charger_cap = clampf(
		float(phase.get("charger_cap", director_charger_cap)),
		0.0,
		1.0
	)
	director_phase_end_progress = clampf(
		float(phase.get("end", 720.0)) / 720.0,
		0.0,
		1.0
	)
	if not director_profiles.is_empty():
		encounter_profile = StringName(director_profiles.pick_random())
	formation_queue.clear()
	_refresh_spawn_settings()


func set_director_pressure(
	scale: float,
	reason: StringName = &"nominal"
) -> void:
	director_pressure = clampf(scale, 0.45, 1.15)
	director_pressure_reason = reason
	_refresh_spawn_settings()


func get_current_threat() -> float:
	var total := 0.0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if enemy.is_in_group("boss"):
			continue

		var enemy_type := _enemy_type_for_node(enemy)

		# Crawlers are swarm population, not strategic threat.
		if enemy_type == &"crawler":
			continue

		total += float(
			enemy.get_meta(
				"threat_cost",
				threat_costs.get(enemy_type, 1.0)
			)
		)

	return total


func get_effective_threat_budget() -> float:
	if rush_active:
		return (
			director_threat_budget
			+ float(rush_enemy_budget_bonus) * 1.2
		) * director_pressure
	return director_threat_budget * director_pressure


func _enemy_type_for_scene(scene: PackedScene) -> StringName:
	if scene == spitter_scene:
		return &"spitter"
	if scene == charger_scene:
		return &"charger"
	return &"crawler"


func _enemy_type_for_node(enemy: Variant) -> StringName:
	if not is_instance_valid(enemy):
		return &"crawler"
	var metadata := StringName(enemy.get_meta("enemy_type", &""))
	if not metadata.is_empty():
		return metadata
	if enemy is Spitter:
		return &"spitter"
	if enemy is Charger:
		return &"charger"
	return &"crawler"


func set_rush_active(active: bool) -> void:
	var rush_just_started := active and not rush_active
	rush_active = active
	_refresh_spawn_settings()

	if rush_just_started:
		recovery_time_remaining = 0.0
		spawn_timer.start(0.1)

		if rush_just_started:
			recovery_time_remaining = 0.0
			spawn_timer.start(0.1)
			_spawn_rush_initial_burst.call_deferred()

func _spawn_rush_initial_burst() -> void:
	for index in range(rush_initial_burst):
		if not spawning_enabled or not rush_active:
			return

		spawn_enemy()

		await get_tree().create_timer(
			0.035,
			false
		).timeout

func begin_recovery(duration: float = -1.0) -> void:
	recovery_time_remaining = (
		recovery_duration if duration < 0.0 else maxf(duration, 0.0)
	)
	encounter_profile = &"mixed"
	encounter_time_remaining = recovery_time_remaining
	_refresh_spawn_settings()


func is_recovery_active() -> bool:
	return recovery_time_remaining > 0.0


func _refresh_spawn_settings() -> void:
	var interval := lerpf(
		spawn_interval,
		minimum_spawn_interval,
		pow(current_run_progress, 0.82)
	)

	if rush_active:
		interval /= rush_spawn_multiplier
	elif is_recovery_active():
		interval *= recovery_interval_multiplier
	if current_run_progress < 0.99:
		interval *= director_spawn_rate
	if director_pressure_reason != &"imprint_assist":
		interval /= maxf(director_pressure, 0.45)

	spawn_timer.wait_time = maxf(interval, 0.12)

	maximum_enemies = roundi(lerpf(
		float(starting_maximum_enemies),
		float(maximum_enemies_end),
		current_run_progress
	))

	if rush_active:
		maximum_enemies += rush_enemy_budget_bonus
	elif is_recovery_active():
		maximum_enemies = maxi(
			maximum_enemies - recovery_enemy_budget_reduction,
			starting_maximum_enemies
		)
	maximum_enemies = maxi(
		int(float(maximum_enemies) * director_pressure),
		starting_maximum_enemies
	)


func stop_spawning() -> void:
	spawning_enabled = false
	spawn_timer.stop()
	formation_queue.clear()
	for warning in get_tree().get_nodes_in_group("spawn_warnings"):
		if is_instance_valid(warning):
			warning.queue_free()


func get_boss_spawn_position() -> Vector2:
	var arena := _resolve_active_arena()
	if arena != null and arena.has_method("get_random_edge_spawn_position"):
		var camera_center := _get_camera_center()
		var boss_clearance := maxf(spawn_clearance_radius, 66.0)
		for _attempt in range(128):
			var candidate := Vector2(arena.call(
				"get_random_edge_spawn_position",
				boss_clearance
			))
			if (
				bool(arena.call(
					"is_walkable_position",
					candidate,
					boss_clearance
				))
				and candidate.distance_to(player.global_position)
				>= minimum_player_distance
				and _is_offscreen(candidate, camera_center)
			):
				return candidate
	return _find_spawn_position()


func _on_enemy_died(enemy: Node2D) -> void:
	enemy_defeated.emit(enemy)
