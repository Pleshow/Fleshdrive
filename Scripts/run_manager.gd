class_name RunManager
extends Node


enum RunState {
	PLAYING,
	OPERATION,
	ONBOARDING,
	PAUSED,
	LEVEL_UP,
	AIMING,
	BOSS_INTRO,
	DYING,
	REBIRTH,
	GAME_OVER,
	VICTORY
}


signal time_changed(elapsed_seconds: float, remaining_seconds: float)
signal state_changed(state: RunState)
signal difficulty_changed(progress: float)
signal rush_started(rush_number: int, duration_seconds: float)
signal rush_ended(rush_number: int)
signal encounter_phase_changed(phase_id: StringName, title: String)
signal boss_warning_started(message: String, duration: float)
signal arena_lock_changed(locked: bool)
signal boss_started(boss: Node2D)
signal boss_health_changed(current_health: float, max_health: float)
signal boss_phase_changed(phase: int)
signal boss_defeated
signal rebirth_started(
	instance_number: int,
	run_summary: Dictionary,
	lifetime_statistics: Dictionary
)
signal run_finished(
	victory: bool,
	elapsed_seconds: float,
	kill_count: int,
	biomass_collected: float,
	level_reached: int,
	run_details: Dictionary
)


@export_category("Run")
@export var run_duration_seconds: float = 720.0
@export var red_gem_scene: PackedScene
@export var gem_drop_kill_interval: int = 25
@export var boss_scene: PackedScene
@export var boss_spawn_time_seconds: float = 660.0
@export var boss_victory_delay_seconds: float = 3.15
@export var death_menu_delay_seconds: float = 3.0

@export_category("Difficulty")
@export var difficulty_update_interval: float = 0.25
@export var rush_times_seconds: Array[float] = [180.0, 360.0, 540.0]
@export var rush_duration_seconds: float = 14.0

@onready var player: Koda = get_tree().get_first_node_in_group(
	"player"
) as Koda
@onready var enemy_spawner: Node = get_node_or_null(
	"../EnemySpawner"
)
@onready var music_player: AudioStreamPlayer = get_node_or_null("../Music")

var state: RunState = RunState.PLAYING
var elapsed_seconds: float = 0.0
var kill_count: int = 0
var rush_active: bool = false
var boss_spawned: bool = false
var boss_defeated_flag: bool = false
var active_boss: VisceralWarden
var encounter_director: EncounterDirector
var affinity_offer_pressure: float = 1.0

var _difficulty_update_remaining: float = 0.0
var _last_displayed_second: int = -1
var _next_rush_index: int = 0
var _rush_time_remaining: float = 0.0
var _rush_warning_indices: Dictionary = {}
var pause_overlay_locked: bool = false
var progression_result_recorded: bool = false
var music_warning_dip: float = 0.0
var music_intensity: float = 0.0
var boss_preparation_granted: bool = false
var active_play_seconds: float = 0.0
var menu_overlay_seconds: float = 0.0


func _ready() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("force_state", &"PLAYING", false)
	if player == null:
		push_error("RunManager: Player not found.")
		return

	player.died.connect(_on_player_died)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("start_run", player.active_fleshdrive_id)

	if enemy_spawner != null:
		if enemy_spawner.has_signal("enemy_defeated"):
			enemy_spawner.enemy_defeated.connect(
				_on_enemy_defeated
			)
	else:
		push_warning("RunManager: Enemy spawner not found.")

	encounter_director = EncounterDirector.new()
	encounter_director.name = "EncounterDirector"
	add_child(encounter_director)
	encounter_director.phase_changed.connect(
		func(phase_id: StringName, title: String) -> void:
			encounter_phase_changed.emit(phase_id, title)
	)
	encounter_director.boss_warning_started.connect(
		func(message: String, duration: float) -> void:
			music_warning_dip = maxf(music_warning_dip, minf(duration, 2.0))
			boss_warning_started.emit(message, duration)
	)
	encounter_director.arena_lock_changed.connect(
		func(locked: bool) -> void:
			arena_lock_changed.emit(locked)
	)
	encounter_director.setup(self, enemy_spawner, player)

	_emit_time_changed(true)
	_apply_difficulty(0.0)
	state_changed.emit(state)


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	if state == RunState.PLAYING and not pause_overlay_locked:
		set_manual_pause(true)


func _process(delta: float) -> void:
	_handle_pause_input()
	_update_music_intensity(delta)
	if state in [RunState.PLAYING, RunState.AIMING, RunState.BOSS_INTRO]:
		active_play_seconds += delta
	elif state in [RunState.OPERATION, RunState.ONBOARDING, RunState.PAUSED, RunState.LEVEL_UP]:
		menu_overlay_seconds += delta

	if state not in [RunState.PLAYING, RunState.AIMING]:
		return

	elapsed_seconds = minf(
		elapsed_seconds + delta,
		run_duration_seconds
	)

	_emit_time_changed()
	_update_rush_timeline(delta)
	_update_boss_encounter()

	_difficulty_update_remaining -= delta

	if _difficulty_update_remaining <= 0.0:
		_difficulty_update_remaining = difficulty_update_interval
		_apply_difficulty(get_run_progress())

	if elapsed_seconds >= run_duration_seconds and boss_scene == null:
		finish_run(true)


func _update_music_intensity(delta: float) -> void:
	if not is_instance_valid(music_player):
		return
	music_warning_dip = maxf(music_warning_dip - delta, 0.0)
	var target_intensity := 0.0
	if rush_active:
		target_intensity = 0.72
	if boss_spawned and not boss_defeated_flag:
		target_intensity = 1.0
	if enemy_spawner != null and bool(enemy_spawner.call("is_recovery_active")):
		target_intensity = minf(target_intensity, 0.18)
	music_intensity = move_toward(music_intensity, target_intensity, delta * 0.75)
	var low_health_pulse := 0.0
	if is_instance_valid(player) and player.current_health <= player.max_health * 0.28:
		low_health_pulse = (sin(Time.get_ticks_msec() * 0.009) + 1.0) * 0.35
	var warning_attenuation := -3.5 if music_warning_dip > 0.0 else 0.0
	music_player.volume_db = -10.0 + music_intensity * 3.0 + low_health_pulse + warning_attenuation
	music_player.pitch_scale = 1.0 + music_intensity * 0.025


func _handle_pause_input() -> void:
	if pause_overlay_locked:
		return

	if not Input.is_action_just_pressed("pause"):
		return
	if is_instance_valid(player):
		var weapon_system := player.get_node_or_null("PlayerWeaponSystem")
		if weapon_system != null and weapon_system.has_method("get_active_skill_status"):
			var active_status := Dictionary(weapon_system.call("get_active_skill_status"))
			if bool(active_status.get("aiming", false)):
				weapon_system.call("cancel_active_skill")
				return

	match state:
		RunState.PLAYING:
			set_manual_pause(true)
		RunState.PAUSED:
			set_manual_pause(false)
		_:
			pass


func get_run_progress() -> float:
	if run_duration_seconds <= 0.0:
		return 1.0

	return clampf(
		elapsed_seconds / run_duration_seconds,
		0.0,
		1.0
	)


func get_remaining_seconds() -> float:
	return maxf(run_duration_seconds - elapsed_seconds, 0.0)


func trigger_rush() -> void:
	if state != RunState.PLAYING or rush_active:
		return

	_start_rush(_next_rush_index + 1)


func start_boss_encounter() -> bool:
	if state != RunState.PLAYING or boss_spawned:
		return false

	if boss_scene == null:
		push_warning("RunManager: Boss scene is not assigned.")
		return false

	var enemies_container := get_tree().get_first_node_in_group(
		"enemies_container"
	)
	if enemies_container == null:
		enemies_container = get_node_or_null("../Entities/Enemies")

	if enemies_container == null:
		push_warning("RunManager: Enemy container not found.")
		return false

	var boss := boss_scene.instantiate() as VisceralWarden
	if boss == null:
		push_warning("RunManager: Boss scene could not be instantiated.")
		return false

	boss_spawned = true
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("mark_boss_reached", elapsed_seconds)
	active_boss = boss

	if rush_active:
		_end_rush()

	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(false)
		if enemy_spawner.has_method("begin_recovery"):
			enemy_spawner.begin_recovery()
		if enemy_spawner.has_method("stop_spawning"):
			enemy_spawner.stop_spawning()

	enemies_container.add_child(boss)
	if (
		enemy_spawner != null
		and enemy_spawner.has_method("get_boss_spawn_position")
	):
		boss.global_position = enemy_spawner.get_boss_spawn_position()
	else:
		boss.global_position = player.global_position + Vector2(700.0, 0.0)
	boss.reset_physics_interpolation()

	boss.died.connect(_on_boss_died)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss_started.emit(boss)
	_set_state(RunState.BOSS_INTRO)
	var camera := player.get_node_or_null("Camera2D")
	if camera != null and camera.has_method("play_boss_intro"):
		camera.call("play_boss_intro", boss, 1.8)
	boss_health_changed.emit(boss.current_health, boss.max_health)
	_complete_boss_intro.call_deferred(1.8)
	return true


func _complete_boss_intro(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if state == RunState.BOSS_INTRO:
		_set_state(RunState.PLAYING)


func enter_level_up() -> bool:
	if state != RunState.PLAYING:
		return false

	return _set_state(RunState.LEVEL_UP)


func enter_targeting() -> bool:
	if state != RunState.PLAYING:
		return false
	return _set_state(RunState.AIMING)


func exit_targeting() -> bool:
	if state != RunState.AIMING:
		return false
	return _set_state(RunState.PLAYING)


func enter_onboarding() -> bool:
	if state != RunState.PLAYING:
		return false

	return _set_state(RunState.ONBOARDING)


func enter_operation() -> bool:
	if state != RunState.PLAYING:
		return false
	return _set_state(RunState.OPERATION)


func exit_operation() -> void:
	if state != RunState.OPERATION:
		return
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("set_build", player.active_fleshdrive_id)
	_set_state(RunState.PLAYING)


func exit_onboarding() -> void:
	if state != RunState.ONBOARDING:
		return

	_set_state(RunState.PLAYING)
	if (
		enemy_spawner != null
		and enemy_spawner.has_method("spawn_opening_wave")
	):
		enemy_spawner.call_deferred("spawn_opening_wave")


func set_pause_overlay_locked(locked: bool) -> void:
	pause_overlay_locked = locked


func exit_level_up() -> void:
	if state != RunState.LEVEL_UP:
		return

	_set_state(RunState.PLAYING)


func set_manual_pause(should_pause: bool) -> void:
	if should_pause:
		if state not in [RunState.PLAYING, RunState.AIMING]:
			return

		_set_state(RunState.PAUSED)
		_cancel_player_active_targeting()
		return

	if state != RunState.PAUSED:
		return

	_set_state(RunState.PLAYING)


func _cancel_player_active_targeting() -> void:
	if not is_instance_valid(player):
		return
	var weapon_system := player.get_node_or_null("PlayerWeaponSystem")
	if weapon_system != null and weapon_system.has_method("cancel_active_skill"):
		weapon_system.call("cancel_active_skill")


func finish_run(victory: bool) -> void:
	if state in [
		RunState.REBIRTH,
		RunState.GAME_OVER,
		RunState.VICTORY
	]:
		return
	if not victory:
		_begin_rebirth()
		return

	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(false)

		if enemy_spawner.has_method("stop_spawning"):
			enemy_spawner.stop_spawning()

	if is_instance_valid(player):
		player.set_physics_process(false)

	var final_state := (
		RunState.VICTORY if victory else RunState.GAME_OVER
	)
	_set_state(final_state)

	var final_biomass := 0.0
	var final_level := 1

	if is_instance_valid(player):
		final_biomass = player.total_biomass_collected
		final_level = player.current_level
	var progression_result := _record_progression_result(true)
	var run_details := (
		player.get_combat_summary()
		if is_instance_valid(player)
		else {}
	)
	run_details["reward_message"] = String(
		progression_result.get("reward_message", "")
	)
	run_details["blueprint_unlocked"] = progression_result.get(
		"blueprint_unlocked",
		&""
	)
	run_details["fleshdrive_leveled"] = progression_result.get(
		"fleshdrive_leveled",
		&""
	)
	run_details["fleshdrive_level"] = int(
		progression_result.get("fleshdrive_level", 0)
	)
	run_details["active_play_seconds"] = active_play_seconds
	run_details["menu_overlay_seconds"] = menu_overlay_seconds
	run_details["menu_time_ratio"] = get_menu_time_ratio()

	run_finished.emit(
		victory,
		elapsed_seconds,
		kill_count,
		final_biomass,
		final_level,
		run_details
	)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"record_menu_timing",
			active_play_seconds,
			menu_overlay_seconds
		)
		telemetry.call("finish_run", victory, elapsed_seconds, &"")


func get_menu_time_ratio() -> float:
	var measured_total := active_play_seconds + menu_overlay_seconds
	if measured_total <= 0.0:
		return 0.0
	return menu_overlay_seconds / measured_total


func restart_run() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("prepare_scene_change")
	else:
		var lifecycle := get_tree().root.get_node_or_null("SceneLifecycle")
		if lifecycle != null:
			lifecycle.call("cancel_transients")
	get_tree().paused = false
	get_tree().reload_current_scene()


func open_flesh_tree() -> void:
	var meta_progression := _get_meta_progression()
	if meta_progression != null:
		meta_progression.call("request_flesh_tree_on_menu")
	return_to_main_menu()


func return_to_main_menu() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("prepare_scene_change")
	else:
		var lifecycle := get_tree().root.get_node_or_null("SceneLifecycle")
		if lifecycle != null:
			lifecycle.call("cancel_transients")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _set_state(new_state: RunState) -> bool:
	if state == new_state:
		return true
	var current_name := StringName(RunState.keys()[state])
	var target_name := StringName(RunState.keys()[new_state])
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null and not bool(flow.call(
		"request_state", current_name, target_name
	)):
		return false

	state = new_state
	state_changed.emit(state)
	return true


func _emit_time_changed(force: bool = false) -> void:
	var displayed_second := int(ceil(get_remaining_seconds()))

	if not force and displayed_second == _last_displayed_second:
		return

	_last_displayed_second = displayed_second
	time_changed.emit(elapsed_seconds, get_remaining_seconds())


func _apply_difficulty(progress: float) -> void:
	if enemy_spawner != null:
		if enemy_spawner.has_method("set_run_progress"):
			enemy_spawner.set_run_progress(progress)

	difficulty_changed.emit(progress)


func _update_rush_timeline(delta: float) -> void:
	if rush_active:
		_rush_time_remaining -= delta

		if _rush_time_remaining <= 0.0:
			_end_rush()

	if rush_active:
		return

	if _next_rush_index >= rush_times_seconds.size():
		return
	if (
		not _rush_warning_indices.has(_next_rush_index)
		and elapsed_seconds >= rush_times_seconds[_next_rush_index] - 2.4
	):
		_rush_warning_indices[_next_rush_index] = true
		boss_warning_started.emit(
			"BIOMASS SURGE DETECTED // RUSH INCOMING",
			2.1
		)

	if elapsed_seconds < rush_times_seconds[_next_rush_index]:
		return

	var rush_number := _next_rush_index + 1
	_next_rush_index += 1
	_start_rush(rush_number)


func _update_boss_encounter() -> void:
	if boss_spawned:
		return
	if (
		not boss_preparation_granted
		and elapsed_seconds >= boss_spawn_time_seconds - 12.0
	):
		boss_preparation_granted = true
		if is_instance_valid(player):
			player.heal(player.max_health * 0.22)
			var missing_biomass := maxf(
				player.biomass_required - player.current_biomass,
				0.0
			)
			if missing_biomass > 0.0:
				player.add_biomass(missing_biomass)
		boss_warning_started.emit(
			tr("BIOFABRICATOR CACHE // FINAL MUTATION AND REPAIR"),
			3.2
		)
		if enemy_spawner != null and enemy_spawner.has_method("begin_recovery"):
			enemy_spawner.begin_recovery()
		return

	if elapsed_seconds < boss_spawn_time_seconds:
		return

	start_boss_encounter()


func _start_rush(rush_number: int) -> void:
	rush_active = true
	_rush_time_remaining = rush_duration_seconds

	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(true)

	rush_started.emit(rush_number, rush_duration_seconds)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"begin_rush",
			rush_number,
			elapsed_seconds,
			player.current_health
		)


func _end_rush() -> void:
	if not rush_active:
		return

	rush_active = false
	_rush_time_remaining = 0.0

	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(false)
		if enemy_spawner.has_method("begin_recovery"):
			enemy_spawner.call("begin_recovery", 10.0)

	rush_ended.emit(_next_rush_index)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"end_rush",
			_next_rush_index,
			elapsed_seconds,
			player.current_health
		)


func _on_player_died() -> void:
	if state in [
		RunState.DYING,
		RunState.GAME_OVER,
		RunState.VICTORY
	]:
		return

	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(false)
		if enemy_spawner.has_method("stop_spawning"):
			enemy_spawner.stop_spawning()

	_set_state(RunState.DYING)
	var lifecycle := get_tree().root.get_node_or_null("SceneLifecycle")
	var transition_token := -1
	if lifecycle != null:
		transition_token = int(lifecycle.call(
			"begin_transition",
			&"death_to_rebirth"
		))

	await get_tree().create_timer(
		death_menu_delay_seconds,
		true,
		false,
		true
	).timeout

	if (
		state == RunState.DYING
		and (
			lifecycle == null
			or (
				transition_token >= 0
				and bool(lifecycle.call(
					"is_token_current",
					transition_token
				))
			)
		)
	):
		if lifecycle != null:
			lifecycle.call("finish_transition", transition_token)
		_begin_rebirth()


func _begin_rebirth() -> void:
	if state == RunState.REBIRTH:
		return
	if enemy_spawner != null:
		if enemy_spawner.has_method("set_rush_active"):
			enemy_spawner.set_rush_active(false)
		if enemy_spawner.has_method("stop_spawning"):
			enemy_spawner.stop_spawning()
	if is_instance_valid(player):
		player.set_physics_process(false)

	var final_biomass := 0.0
	var final_level := 1
	if is_instance_valid(player):
		final_biomass = player.total_biomass_collected
		final_level = player.current_level

	var statistics := _record_progression_result(false)
	var summary := {
		"elapsed_seconds": elapsed_seconds,
		"kills": kill_count,
		"biomass": final_biomass,
		"level": final_level,
	}
	if is_instance_valid(player):
		summary.merge(player.get_combat_summary(), true)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"finish_run",
			false,
			elapsed_seconds,
			&"player_health_depleted"
		)
	_set_state(RunState.REBIRTH)
	rebirth_started.emit(
		int(statistics.get("instance_number", 1)),
		summary,
		statistics
	)


func _record_progression_result(victory: bool) -> Dictionary:
	var meta_progression := _get_meta_progression()
	if meta_progression == null:
		return {
			"instance_number": 1,
			"deaths": 0,
			"runs": 0,
			"boss_victories": 0,
			"best_time": 0.0,
			"total_kills": 0,
		}
	if progression_result_recorded:
		return meta_progression.call("get_statistics") as Dictionary
	progression_result_recorded = true
	return meta_progression.call(
		"record_run_result",
		victory,
		elapsed_seconds,
		kill_count,
		(
			player.active_fleshdrive_id
			if is_instance_valid(player)
			else &""
		)
	) as Dictionary


func _get_meta_progression() -> Node:
	return get_tree().root.get_node_or_null("MetaProgression")


func _on_boss_health_changed(
	current_health: float,
	max_health: float
) -> void:
	boss_health_changed.emit(current_health, max_health)


func _on_boss_phase_changed(new_phase: int) -> void:
	boss_phase_changed.emit(new_phase)
	if new_phase >= 2:
		boss_warning_started.emit(
			"WARDEN REINFORCEMENTS // INCOMING",
			2.8
		)
		var camera := player.get_node_or_null("Camera2D")
		if camera != null and camera.has_method("play_boss_intro"):
			camera.call("play_boss_intro", active_boss, 1.25)
		if (
			enemy_spawner != null
			and enemy_spawner.has_method("spawn_boss_reinforcements")
		):
			enemy_spawner.call_deferred("spawn_boss_reinforcements", 24)


func _on_boss_died(_boss: Node2D) -> void:
	if boss_defeated_flag:
		return

	boss_defeated_flag = true
	var camera := player.get_node_or_null("Camera2D")
	if camera != null and camera.has_method("add_trauma_profile"):
		camera.call("add_trauma_profile", &"boss_death")
	kill_count += 1
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_kill")
		telemetry.call("mark_boss_killed", elapsed_seconds)
	boss_defeated.emit()
	boss_warning_started.emit(
		"WARDEN CORE RECOVERED // BLUEPRINT IMPRINTED",
		3.0
	)

	await get_tree().create_timer(
		boss_victory_delay_seconds,
		true,
		false,
		true
	).timeout

	if state == RunState.PLAYING:
		finish_run(true)


func _on_enemy_defeated(_enemy: Node2D) -> void:
	kill_count += 1
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_kill")
	if is_instance_valid(player):
		player.register_enemy_kill(kill_count)
	if (
		gem_drop_kill_interval > 0
		and kill_count % gem_drop_kill_interval == 0
	):
		_drop_red_gem(_enemy.global_position)
	elif bool(_enemy.get_meta("is_elite", false)):
		_drop_red_gem(_enemy.global_position)


func _drop_red_gem(drop_position: Vector2) -> void:
	if red_gem_scene == null:
		return
	var pickup_container := get_tree().get_first_node_in_group(
		"pickup_container"
	)
	if pickup_container == null:
		return
	_spawn_red_gem_deferred.call_deferred(pickup_container, drop_position)


func _spawn_red_gem_deferred(container: Node, drop_position: Vector2) -> void:
	if not is_instance_valid(container):
		return
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	var gem := (
		runtime_pool.call("acquire", red_gem_scene, container) as Node2D
		if runtime_pool != null
		else red_gem_scene.instantiate() as Node2D
	)
	if gem == null:
		return
	if gem.get_parent() == null:
		container.add_child(gem)
	gem.global_position = drop_position
