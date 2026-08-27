class_name ThunderGodRuntime
extends RefCounted


const BASE_DAMAGE := 18.0
const BASE_CHAIN_TARGETS := 2
const CHAIN_RANGE := 240.0
const SHOCK_DURATION := 1.0
const SHOCK_MAX_STACKS := 1
const EVENTS_PER_ATTACK := 40
const FORK_CHANCE := 0.50
const FORK_DAMAGE_MULTIPLIER := 0.50
const PULSE_HITS_REQUIRED := 8
const PULSES_REQUIRED := 3
const THUNDER_METER_MAX := 100.0
const THUNDER_GAIN_PER_HIT := 4.0
const EYE_DURATION := 5.0
const EYE_RADIUS := 350.0
const NEURAL_DURATION := 5.0
const KineticChargeHudLayerScript := preload("res://Scripts/ui/kinetic_charge_hud_layer.gd")

var host: PlayerWeaponSystem
var player: Koda
var pipeline: Node
var random := RandomNumberGenerator.new()
var chain_hit_progress: int = 0
var stored_pulses: int = 0
var pulse_pending: bool = false
var thunder_meter: float = 0.0
var eye_remaining: float = 0.0
var eye_damage_tick: float = 0.0
var neural_remaining: float = 0.0
var neural_attack_tick: float = 0.0
var singularity_tick: float = 0.0
var overridden_enemies: Dictionary = {}
var shock_visual_tick: float = 0.0
var player_aura: Node2D
var player_aura_sprite: AnimatedSprite2D
var status_layer: CanvasLayer
var status_bar: ProgressBar
var status_label: Label
var ready_announced: bool = false
var unshaded_vfx_material: CanvasItemMaterial


func setup(owner: PlayerWeaponSystem, combat_pipeline: Node) -> void:
	host = owner
	player = owner.player
	pipeline = combat_pipeline
	unshaded_vfx_material = CanvasItemMaterial.new()
	unshaded_vfx_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	random.randomize()
	_install_status_hud()
	if pipeline != null and not pipeline.target_killed.is_connected(_on_target_killed):
		pipeline.target_killed.connect(_on_target_killed)


func shutdown() -> void:
	if pipeline != null and pipeline.target_killed.is_connected(_on_target_killed):
		pipeline.target_killed.disconnect(_on_target_killed)
	if is_instance_valid(status_layer):
		status_layer.queue_free()
	_release_looped_vfx(player_aura_sprite)
	player_aura_sprite = null
	if is_instance_valid(player_aura):
		player_aura.queue_free()
	player_aura = null
	status_layer = null
	_restore_overridden_enemies()


func update(delta: float) -> void:
	eye_remaining = maxf(eye_remaining - delta, 0.0)
	eye_damage_tick = maxf(eye_damage_tick - delta, 0.0)
	neural_remaining = maxf(neural_remaining - delta, 0.0)
	neural_attack_tick = maxf(neural_attack_tick - delta, 0.0)
	singularity_tick = maxf(singularity_tick - delta, 0.0)
	shock_visual_tick = maxf(shock_visual_tick - delta, 0.0)
	if shock_visual_tick <= 0.0:
		shock_visual_tick = 0.20
		_cleanup_shock_visuals()
	_update_eye_of_the_storm()
	_update_neural_thunder()
	_update_singularity_core()
	_update_player_aura(eye_remaining > 0.0 or neural_remaining > 0.0)
	player.set_meta("eye_of_storm_active", eye_remaining > 0.0)
	player.set_meta("neural_thunder_active", neural_remaining > 0.0)
	_update_status_hud()


func perform_attack(primary_target: Node2D) -> bool:
	if player.get_upgrade_level(&"arc_heart") <= 0:
		return false
	if not _is_living_enemy(primary_target):
		return false
	host.play_build_sound(&"electric_cast", -7.0)
	var state := {
		"budget": EVENTS_PER_ATTACK,
	}
	var context := ProcContext.new(2)
	_run_chain(primary_target, &"main_chain", context, state, true)
	player.attack_timer.wait_time = maxf(player.attack_interval, 0.25)
	if pulse_pending:
		pulse_pending = false
		_emit_pulse_discharge()
	return true


func _run_chain(
	first_target: Node2D,
	source_type: StringName,
	context: ProcContext,
	state: Dictionary,
	allow_capacitor: bool
) -> void:
	var current_target := first_target
	var origin := player.get_electric_muzzle_position(
		first_target.global_position
	)
	var source_anchor: Node2D = player
	var last_target: Node2D = null
	var target_count := BASE_CHAIN_TARGETS + mini(_level(&"arc_relay"), 1)
	var base_damage := maxf(player.attack_damage, BASE_DAMAGE)
	for jump_index in range(target_count):
		if current_target == null or int(state["budget"]) <= 0:
			break
		if not context.visit(current_target):
			break
		var damage := base_damage * pow(0.9, jump_index)
		_hit_target(current_target, damage, source_type, context, state, allow_capacitor)
		last_target = current_target
		_draw_lightning(
			origin,
			current_target.global_position,
			1.0,
			false,
			source_anchor,
			current_target
		)
		host.play_build_sound(&"electric_chain_jump", -12.0)
		if source_type == &"main_chain":
			_register_chain_hit()
			_try_forked_arc(current_target, damage, context, state, 0)
		origin = current_target.global_position
		source_anchor = current_target
		current_target = _nearest_unvisited(origin, _chain_range(), context.visited_targets)
	if is_instance_valid(last_target):
		host.play_build_vfx(&"shock_proc", last_target.global_position, 0.52)


func _hit_target(
	target: Node2D,
	amount: float,
	source_id: StringName,
	context: ProcContext,
	state: Dictionary,
	allow_capacitor: bool
) -> void:
	if not _is_living_enemy(target) or int(state["budget"]) <= 0:
		return
	state["budget"] = int(state["budget"]) - 1
	if _should_override(target, amount, source_id):
		_override_enemy(target)
		return
	var event := DamageEvent.create(
		target,
		amount,
		player,
		source_id,
		FleshdriveCatalog.ELECTRIC
	)
	event.damage_type = DamageEvent.DamageType.DIRECT
	event.can_crit = true
	event.critical_chance = float(player.get_meta("critical_chance", 0.05))
	event.critical_multiplier = float(player.get_meta("critical_multiplier", 1.5))
	event.proc_context = context
	event.metadata["thunder_shocked"] = _shock_stacks(target) > 0 or _level(&"conductive_fur") > 0
	event.metadata["thunder_source"] = source_id
	if _level(&"conductive_fur") > 0:
		event.add_status({
			"id": &"shock",
			"duration": SHOCK_DURATION,
			"stack_gain": 1,
			"max_stacks": SHOCK_MAX_STACKS,
			"affinity": FleshdriveCatalog.ELECTRIC,
		})
	if host.build_runtime != null:
		event.amount = host.build_runtime.modify_damage(
			source_id, FleshdriveCatalog.ELECTRIC, event.amount, event.damage_type
		)
	if pipeline != null:
		pipeline.call("apply_damage", event)
	elif target.has_method("take_damage"):
		target.call("take_damage", event.amount)
	host.play_build_sound(&"electric_impact_cue", -15.0)
	if _level(&"conductive_fur") > 0 and is_instance_valid(target):
		_show_shock_crown(target, 1)
		_try_feedback_jump(target)
	_charge_thunder_meter()


func _try_forked_arc(
	source: Node2D,
	damage: float,
	context: ProcContext,
	state: Dictionary,
	depth: int
) -> void:
	if _level(&"forked_arc_node") <= 0 or random.randf() > FORK_CHANCE:
		return
	if depth > 0 and _level(&"storm_core") <= 0:
		return
	var forked := 0
	for target in host.nearest_enemies_for_build(
		source.global_position, _chain_range(), 12
	):
		if int(state["budget"]) <= 0 or forked >= 2:
			break
		if not context.visit(target):
			continue
		var fork_damage := damage * FORK_DAMAGE_MULTIPLIER
		_hit_target(target, fork_damage, &"forked_arc_node", context, state, false)
		_draw_lightning(source.global_position, target.global_position, 0.72, true)
		forked += 1
		if depth == 0 and _level(&"storm_core") > 0:
			_try_forked_arc(target, fork_damage, context, state, 1)


func _register_chain_hit() -> void:
	if _level(&"pulse_capacitor") <= 0:
		return
	chain_hit_progress += 1
	if chain_hit_progress < PULSE_HITS_REQUIRED:
		return
	chain_hit_progress -= PULSE_HITS_REQUIRED
	stored_pulses += 1
	if stored_pulses >= PULSES_REQUIRED:
		stored_pulses = 0
		pulse_pending = true


func _emit_pulse_discharge() -> void:
	_show_discharge_burst(player.global_position)
	var starts := host.nearest_enemies_for_build(player.global_position, 350.0, 3)
	for first in starts:
		var context := ProcContext.new(1)
		if not context.visit(first):
			continue
		var state := {"budget": 4}
		var damage := maxf(player.attack_damage, BASE_DAMAGE) * 0.70
		_hit_target(first, damage, &"pulse_capacitor", context, state, false)
		_draw_lightning(player.global_position, first.global_position, 0.94, true)
		var second := _nearest_unvisited(
			first.global_position, _chain_range(), context.visited_targets
		)
		if second != null and context.visit(second):
			_hit_target(second, damage * 0.85, &"pulse_capacitor", context, state, false)
			_draw_lightning(first.global_position, second.global_position, 0.78, true)


func _try_feedback_jump(source: Node2D) -> void:
	if _level(&"feedback_loop") <= 0 or random.randf() > 0.50:
		return
	var target := _nearest_unvisited(
		source.global_position, _chain_range() * 0.75,
		{source.get_instance_id(): true}
	)
	if target == null or _shock_stacks(target) > 0:
		return
	pipeline.call("apply_status", target, {
		"id": &"shock",
		"duration": SHOCK_DURATION,
		"stack_gain": 1,
		"max_stacks": SHOCK_MAX_STACKS,
		"affinity": FleshdriveCatalog.ELECTRIC,
	}, player, &"feedback_loop")
	_show_shock_crown(target, 1)
	_draw_lightning(source.global_position, target.global_position, 0.58, true)


func _on_target_killed(target: Node2D, event: DamageEvent) -> void:
	if event == null or event.source != player or _level(&"ionized_blood") <= 0:
		return
	if not bool(event.metadata.get("thunder_shocked", false)):
		return
	if event.source_id in [&"ionized_blood", &"neural_thunder_detonation"]:
		return
	if random.randf() > 0.60:
		return
	_burst_ionized(target.global_position, target)


func _update_eye_of_the_storm() -> void:
	if eye_remaining <= 0.0:
		return
	if eye_damage_tick > 0.0:
		return
	eye_damage_tick = 0.50
	var state := {"budget": 24}
	for target in host.enemies_in_radius_for_build(player.global_position, EYE_RADIUS):
		_hit_target(
			target, maxf(player.attack_damage, BASE_DAMAGE) * 0.30,
			&"eye_of_the_storm", ProcContext.new(0), state, false
		)
	_show_discharge_burst(player.global_position)


func _update_singularity_core() -> void:
	if _level(&"singularity_core") <= 0 or singularity_tick > 0.0:
		return
	singularity_tick = 1.0
	var relays := 0
	for source in host.living_enemies_for_build():
		if _shock_stacks(source) <= 0 or bool(source.get_meta("neural_overridden", false)):
			continue
		var target := _nearest_unvisited(
			source.global_position, _chain_range() * 0.8,
			{source.get_instance_id(): true}
		)
		if target == null:
			continue
		_hit_target(
			target, maxf(player.attack_damage, BASE_DAMAGE) * 0.35,
			&"singularity_core", ProcContext.new(0), {"budget": 1}, false
		)
		_draw_lightning(source.global_position, target.global_position, 0.68, true)
		relays += 1
		if relays >= 4:
			break


func activate_thunder_capstone() -> bool:
	if thunder_meter < THUNDER_METER_MAX:
		return false
	if _level(&"eye_of_the_storm") > 0:
		thunder_meter = 0.0
		eye_remaining = EYE_DURATION
		eye_damage_tick = 0.0
		_show_thunderstate_activation()
		return true
	if _level(&"neural_thunder") > 0:
		thunder_meter = 0.0
		neural_remaining = NEURAL_DURATION
		neural_attack_tick = 0.0
		_show_thunderstate_activation()
		return true
	return false


func has_capstone_active_skill() -> bool:
	return _level(&"eye_of_the_storm") > 0 or _level(&"neural_thunder") > 0


func get_active_skill_status() -> Dictionary:
	var title := ""
	if _level(&"eye_of_the_storm") > 0:
		title = "EYE OF THE STORM"
	elif _level(&"neural_thunder") > 0:
		title = "NEURAL THUNDER"
	return {
		"id": &"thunder_capstone",
		"title": title,
		"affinity": &"electric",
		"unlocked": not title.is_empty(),
		"aiming": false,
		"ready": thunder_meter >= THUNDER_METER_MAX,
		"cooldown": THUNDER_METER_MAX - thunder_meter,
		"max_cooldown": THUNDER_METER_MAX,
	}


func _charge_thunder_meter() -> void:
	if not has_capstone_active_skill():
		return
	if eye_remaining > 0.0 or neural_remaining > 0.0:
		return
	thunder_meter = minf(thunder_meter + THUNDER_GAIN_PER_HIT, THUNDER_METER_MAX)


func _should_override(
	target: Node2D,
	amount: float,
	source_id: StringName
) -> bool:
	if (
		neural_remaining <= 0.0
		or source_id == &"neural_thunder_detonation"
		or bool(target.get_meta("neural_overridden", false))
		or not ("current_health" in target)
	):
		return false
	return amount >= float(target.get("current_health"))


func _override_enemy(target: Node2D) -> void:
	var id := target.get_instance_id()
	target.set_meta("neural_overridden", true)
	target.set("current_health", maxf(float(target.get("current_health")), 1.0))
	overridden_enemies[id] = {
		"ref": weakref(target),
		"physics_processing": target.is_physics_processing(),
	}
	target.set_physics_process(false)
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO
	_show_shock_crown(target, 1)
	host.play_build_vfx(&"status_haste", target.global_position, 1.05)


func _update_neural_thunder() -> void:
	if neural_remaining > 0.0:
		if neural_attack_tick > 0.0:
			return
		neural_attack_tick = 0.55
		for data_variant in overridden_enemies.values():
			var data := Dictionary(data_variant)
			var enemy_ref := data.get("ref") as WeakRef
			var source := enemy_ref.get_ref() as Node2D if enemy_ref != null else null
			if not is_instance_valid(source):
				continue
			var target := _nearest_unvisited(
				source.global_position, 280.0,
				{source.get_instance_id(): true}
			)
			if target == null:
				continue
			host.damage_enemy_for_build(
				target, maxf(player.attack_damage, BASE_DAMAGE) * 0.45,
				&"neural_thunder", DamageEvent.HitRole.SECONDARY, false
			)
			_draw_lightning(source.global_position, target.global_position, 0.84, true)
		return
	if not overridden_enemies.is_empty():
		_detonate_overridden_enemies()


func _detonate_overridden_enemies() -> void:
	var entries := overridden_enemies.values()
	overridden_enemies.clear()
	for data_variant in entries:
		var data := Dictionary(data_variant)
		var enemy_ref := data.get("ref") as WeakRef
		var enemy := enemy_ref.get_ref() as Node2D if enemy_ref != null else null
		if not is_instance_valid(enemy):
			continue
		enemy.remove_meta("neural_overridden")
		enemy.set_physics_process(bool(data.get("physics_processing", true)))
		var center := enemy.global_position
		if _level(&"ionized_blood") > 0:
			_burst_ionized(center, enemy)
		_hit_target(
			enemy, maxf(float(enemy.get("current_health")), 1.0) + 100000.0,
			&"neural_thunder_detonation", ProcContext.new(0), {"budget": 1}, false
		)
		_show_ionized_explosion(center)


func _restore_overridden_enemies() -> void:
	for data_variant in overridden_enemies.values():
		var data := Dictionary(data_variant)
		var enemy_ref := data.get("ref") as WeakRef
		var enemy := enemy_ref.get_ref() as Node2D if enemy_ref != null else null
		if not is_instance_valid(enemy):
			continue
		enemy.remove_meta("neural_overridden")
		enemy.set_physics_process(bool(data.get("physics_processing", true)))
	overridden_enemies.clear()


func _burst_ionized(center: Vector2, excluded: Node2D = null) -> void:
	var context := ProcContext.new(0)
	var state := {"budget": 12}
	for enemy in host.enemies_in_radius_for_build(center, 120.0):
		if enemy == excluded or not context.visit(enemy):
			continue
		_hit_target(
			enemy, maxf(player.attack_damage, BASE_DAMAGE) * 0.50,
			&"ionized_blood", context, state, false
		)
	_show_ionized_explosion(center)


func _nearest_unvisited(center: Vector2, radius: float, visited: Dictionary) -> Node2D:
	for enemy in host.nearest_enemies_for_build(center, radius, 24):
		if _is_living_enemy(enemy) and not visited.has(enemy.get_instance_id()):
			return enemy
	return null


func _shock_stacks(target: Node2D) -> int:
	if pipeline == null or not is_instance_valid(target):
		return 0
	return int(Dictionary(pipeline.call("get_status", target, &"shock")).get("stacks", 0))


func _chain_range() -> float:
	return CHAIN_RANGE * (1.10 if _level(&"arc_relay") > 0 else 1.0)


func _level(upgrade_id: StringName) -> int:
	return player.get_upgrade_level(upgrade_id) if player != null else 0


func _is_living_enemy(target: Node2D) -> bool:
	return (
		is_instance_valid(target)
		and target.is_in_group("enemies")
		and target.get("is_dead") != true
		and not bool(target.get_meta("neural_overridden", false))
	)


func _draw_lightning(
	from: Vector2,
	to: Vector2,
	intensity: float,
	branch: bool,
	source_anchor: Node2D = null,
	target_anchor: Node2D = null
) -> void:
	if host == null or not host.is_inside_tree():
		return
	var delta := to - from
	var distance := delta.length()
	if distance < 2.0:
		return
	var visual_effects := host.get_tree().root.get_node_or_null("VisualEffects")
	var arc: AnimatedSprite2D = null
	if visual_effects != null:
		arc = visual_effects.call(
			"play",
			&"electric_chain_arc",
			from.lerp(to, 0.5),
			1.0,
			delta.angle()
		) as AnimatedSprite2D
	if arc != null:
		_fit_lightning_asset(arc, from, to, intensity, branch)
		arc.flip_v = random.randf() > 0.5
		arc.z_as_relative = false
		arc.z_index = 74
		arc.name = "ThunderAssetBolt"
		arc.add_to_group("thunder_vfx")
		arc.set_meta("autoattack_lightning", true)
		arc.set_meta("tracks_player_source", source_anchor == player)
		if is_instance_valid(source_anchor) and is_instance_valid(target_anchor):
			var visual_effects_generation := int(
				arc.get_meta("vfx_generation", -1)
			)
			_track_lightning_asset(
				arc,
				source_anchor,
				target_anchor,
				intensity,
				branch,
				visual_effects_generation
			)


func _fit_lightning_asset(
	arc: AnimatedSprite2D,
	from: Vector2,
	to: Vector2,
	intensity: float,
	branch: bool
) -> void:
	var delta := to - from
	# The painted bolt occupies roughly 210 px of its 256 px canvas. Fit the
	# authored animation exactly between anchors while retaining its branches.
	arc.global_position = from.lerp(to, 0.5)
	arc.rotation = delta.angle()
	arc.scale = Vector2(
		delta.length() / 210.0,
		(0.68 if not branch else 0.56) * maxf(intensity, 0.72)
	)


func _track_lightning_asset(
	arc: AnimatedSprite2D,
	source_anchor: Node2D,
	target_anchor: Node2D,
	intensity: float,
	branch: bool,
	generation: int
) -> void:
	while (
		is_instance_valid(arc)
		and arc.visible
		and int(arc.get_meta("vfx_generation", -1)) == generation
		and is_instance_valid(source_anchor)
		and is_instance_valid(target_anchor)
	):
		var live_from := source_anchor.global_position
		if source_anchor == player:
			live_from = player.get_electric_muzzle_position(
				target_anchor.global_position
			)
		_fit_lightning_asset(
			arc,
			live_from,
			target_anchor.global_position,
			intensity,
			branch
		)
		await host.get_tree().process_frame


func _show_shock_crown(target: Node2D, stacks: int) -> void:
	if not is_instance_valid(target) or target.get("is_dead") == true:
		return
	var existing: AnimatedSprite2D
	var existing_ref := (
		target.get_meta("status_vfx_shock") as WeakRef
		if target.has_meta("status_vfx_shock")
		else null
	)
	if existing_ref != null:
		existing = existing_ref.get_ref() as AnimatedSprite2D
	if existing != null:
		existing.modulate.a = 0.50 + 0.08 * float(stacks)
		existing.scale = Vector2.ONE * (0.92 + 0.06 * float(stacks))
		return
	var visual_effects := host.get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return
	var crown := visual_effects.call(
		"play_attached", &"shock_status", target,
		Vector2(0.0, -7.0), 0.92 + 0.06 * float(stacks), 0.0
	) as AnimatedSprite2D
	if crown != null:
		crown.name = "StatusVFX_shock"
		crown.z_index = 24
		target.set_meta("status_vfx_shock", weakref(crown))


func _cleanup_shock_visuals() -> void:
	for enemy in host.living_enemies_for_build():
		var crown: AnimatedSprite2D
		var crown_ref := (
			enemy.get_meta("status_vfx_shock") as WeakRef
			if enemy.has_meta("status_vfx_shock")
			else null
		)
		if crown_ref != null:
			crown = crown_ref.get_ref() as AnimatedSprite2D
		if crown != null and _shock_stacks(enemy) <= 0:
			_release_looped_vfx(crown)
			enemy.remove_meta("status_vfx_shock")


func _update_player_aura(active: bool) -> void:
	if not active:
		if is_instance_valid(player_aura_sprite):
			player_aura_sprite.hide()
		return
	if not is_instance_valid(player_aura):
		player_aura = Node2D.new()
		player_aura.name = "ThunderGodAura"
		player_aura.z_index = 22
		player.add_child(player_aura)
		var visual_effects := host.get_tree().root.get_node_or_null("VisualEffects")
		if visual_effects != null:
			player_aura_sprite = visual_effects.call(
				"play_attached", &"shock_status", player_aura,
				Vector2(0.0, -8.0), 1.35, 0.0
			) as AnimatedSprite2D
			if player_aura_sprite != null:
				player_aura_sprite.name = "ThunderGodAuraAsset"
	if is_instance_valid(player_aura_sprite):
		player_aura_sprite.show()
	player_aura.scale = Vector2.ONE * (
		1.18 if eye_remaining > 0.0 else 1.08
	)


func _show_discharge_burst(center: Vector2) -> void:
	host.play_build_vfx(&"shock_proc", center, 0.72)
	host.play_build_vfx(&"electro_shock", center, 3.2)
	host.play_build_vfx(
		StringName("storm_strike_%02d" % randi_range(1, 6)),
		center,
		1.05
	)
	host.play_build_sound(&"raiju_attack_spark", -1.0)


func _show_ionized_explosion(center: Vector2) -> void:
	host.play_build_vfx(&"electro_shock", center, 2.5)
	host.play_build_vfx(&"electric_impact", center, 2.2)
	host.play_build_vfx(&"electric_heavy_chain", center, 1.2)


func _show_thunderstate_activation() -> void:
	host.play_build_vfx(&"electro_shock", player.global_position, 5.2)
	host.play_build_vfx(&"arc_muzzle", player.global_position, 2.4)
	host.play_build_vfx(&"electric_lance", player.global_position, 1.3)
	host.play_build_sound(&"raiju_attack_spark", 1.0)


func _install_status_hud() -> void:
	status_layer = KineticChargeHudLayerScript.new()
	status_layer.name = "ThunderBuildStatusHUD"
	status_layer.layer = 130
	player.add_child.call_deferred(status_layer)
	var panel := PanelContainer.new()
	panel.name = "ThunderBuildMeter"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Keep the meter inside the permanent top HUD band instead of floating over
	# enemies and attack telegraphs in the playfield.
	panel.position = Vector2(-430.0, 20.0)
	panel.size = Vector2(250.0, 46.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.022, 0.04, 0.92)
	style.border_color = Color(0.20, 0.72, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	status_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	stack.add_child(status_label)
	status_bar = ProgressBar.new()
	status_bar.show_percentage = false
	status_bar.custom_minimum_size = Vector2(0.0, 12.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.045, 0.075, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.20, 0.74, 1.0, 1.0)
	status_bar.add_theme_stylebox_override("background", background)
	status_bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(status_bar)
	status_layer.hide()


func _update_status_hud() -> void:
	if not is_instance_valid(status_layer) or not is_instance_valid(status_bar):
		return
	var visible := _level(&"arc_heart") > 0 and _level(&"static_claws") <= 0
	status_layer.call("set_build_visible", visible)
	if not visible:
		return
	var ready_now := thunder_meter >= THUNDER_METER_MAX
	if has_capstone_active_skill():
		status_bar.max_value = 100.0
		status_bar.value = thunder_meter
		status_label.text = "THUNDER METER  %d / 100%s" % [
			roundi(thunder_meter),
			"  READY - %s" % _activation_key_text() if ready_now else ""
		]
	elif _level(&"pulse_capacitor") > 0:
		status_bar.max_value = PULSES_REQUIRED
		status_bar.value = stored_pulses
		status_label.text = "PULSES  %d / %d  HITS %d / %d" % [
			stored_pulses, PULSES_REQUIRED,
			chain_hit_progress, PULSE_HITS_REQUIRED,
		]
	else:
		var shocked := 0
		for enemy in host.living_enemies_for_build():
			if _shock_stacks(enemy) > 0:
				shocked += 1
		status_bar.max_value = 1.0
		status_bar.value = mini(shocked, 1)
		status_label.text = "SHOCKED TARGETS  %d" % shocked
	if ready_now and not ready_announced:
		_announce_build_ready()
	ready_announced = ready_now


func _activation_key_text() -> String:
	var settings := player.get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return "Q" if _level(&"polarity_shift") > 0 else "E"
	if _level(&"polarity_shift") > 0:
		return String(settings.call("get_secondary_active_skill_key_text"))
	return String(settings.call("get_active_skill_key_text"))


func _announce_build_ready() -> void:
	if host == null or player == null:
		return
	host.play_build_sound(&"capacitor_ready", -2.0)
	host.play_build_vfx(&"ui_energy_confirm", player.global_position + Vector2(0.0, -8.0), 0.86)


func _release_looped_vfx(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	var live_node := node as Node
	if live_node == null:
		return
	var tree := live_node.get_tree()
	if tree == null:
		return
	var visual_effects := tree.root.get_node_or_null("VisualEffects")
	if live_node is AnimatedSprite2D and visual_effects != null:
		visual_effects.call("stop_effect", live_node)
		return
	for child in live_node.get_children():
		if child is AnimatedSprite2D and visual_effects != null:
			visual_effects.call("stop_effect", child)
	live_node.queue_free()
