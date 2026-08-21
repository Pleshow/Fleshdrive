class_name ThunderGodRuntime
extends RefCounted


const BASE_DAMAGE := 18.0
const BASE_CHAIN_TARGETS := 2
const CHAIN_RANGE := 240.0
const SHOCK_DURATION := 6.0
const SHOCK_MAX_STACKS := 5
const SHOCK_DAMAGE_PER_STACK := 0.08
const CAPACITOR_THRESHOLD := 20
const EVENTS_PER_ATTACK := 40
const KineticChargeHudLayerScript := preload("res://Scripts/ui/kinetic_charge_hud_layer.gd")

var host: PlayerWeaponSystem
var player: Koda
var pipeline: Node
var random := RandomNumberGenerator.new()
var capacitor_charge: int = 0
var neural_jump_counter: int = 0
var lightning_activity: int = 0
var thunderstate_remaining: float = 0.0
var thunderstate_tick: float = 0.0
var eye_discharge_tick: float = 0.0
var overload: float = 0.0
var shock_visual_tick: float = 0.0
var player_aura: Node2D
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


func update(delta: float) -> void:
	overload = maxf(overload - delta * 5.0, 0.0)
	thunderstate_remaining = maxf(thunderstate_remaining - delta, 0.0)
	thunderstate_tick = maxf(thunderstate_tick - delta, 0.0)
	eye_discharge_tick = maxf(eye_discharge_tick - delta, 0.0)
	shock_visual_tick = maxf(shock_visual_tick - delta, 0.0)
	if shock_visual_tick <= 0.0:
		shock_visual_tick = 0.20
		_cleanup_shock_visuals()
	_update_eye_of_the_storm()
	_update_player_aura(
		bool(player.get_meta("eye_of_storm_active", false))
		or thunderstate_remaining > 0.0
	)
	if thunderstate_remaining > 0.0 and thunderstate_tick <= 0.0:
		thunderstate_tick = 0.18
		_emit_thunderstate_relays()
	player.set_meta("thunder_overload", overload)
	player.set_meta("thunderstate_active", thunderstate_remaining > 0.0)
	_update_status_hud()


func perform_attack(primary_target: Node2D) -> bool:
	if player.get_upgrade_level(&"arc_heart") <= 0:
		return false
	if not _is_living_enemy(primary_target):
		return false
	host.play_build_sound(&"electric_cast", -7.0)
	var state := {
		"budget": EVENTS_PER_ATTACK,
		"charge_generated": 0,
		"feedback_targets": {},
		"storm_targets": {},
	}
	var context := ProcContext.new(2)
	_run_chain(primary_target, &"main_chain", context, state, true)
	var feedback_count := Dictionary(state["feedback_targets"]).size()
	var cooldown := player.attack_interval
	if _level(&"feedback_loop") > 0:
		cooldown -= minf(
			0.03 * float(feedback_count),
			player.attack_interval * 0.20
		)
	player.attack_timer.wait_time = maxf(cooldown, 0.25)
	if _level(&"capacitor_organ") > 0 and capacitor_charge >= CAPACITOR_THRESHOLD:
		_announce_build_ready()
		capacitor_charge -= CAPACITOR_THRESHOLD
		var discharge_target := _nearest_unvisited(
			player.global_position, _chain_range(), {}
		)
		if discharge_target != null:
			_show_discharge_burst(player.global_position)
			_run_chain(
				discharge_target,
				&"capacitor_chain",
				ProcContext.new(1),
				{"budget": 20, "charge_generated": 6, "feedback_targets": {}, "storm_targets": {}},
				false
			)
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
	var target_count := BASE_CHAIN_TARGETS + mini(_level(&"arc_relay"), 4)
	var base_damage := maxf(player.attack_damage, BASE_DAMAGE)
	for jump_index in range(target_count):
		if current_target == null or int(state["budget"]) <= 0:
			break
		if not context.visit(current_target):
			break
		var falloff := 1.0 if _ignore_falloff() else pow(0.9, jump_index)
		var arc_heart_multiplier := 1.0 + 0.12 * float(maxi(_level(&"arc_heart") - 1, 0))
		var damage := base_damage * arc_heart_multiplier * falloff * _overload_damage_multiplier()
		var was_shocked := _shock_stacks(current_target) > 0
		_hit_target(current_target, damage, source_type, context, state, allow_capacitor)
		_draw_lightning(
			origin,
			current_target.global_position,
			1.0,
			false,
			source_anchor,
			current_target
		)
		host.play_build_sound(&"electric_chain_jump", -12.0)
		if was_shocked:
			Dictionary(state["feedback_targets"])[current_target.get_instance_id()] = true
		if source_type in [&"main_chain", &"capacitor_chain"]:
			neural_jump_counter += 1
			if neural_jump_counter >= 8:
				neural_jump_counter -= 8
				_try_neural_thunder(current_target, damage, context, state, allow_capacitor)
		_try_storm_core(current_target, damage, context, state, allow_capacitor)
		origin = current_target.global_position
		source_anchor = current_target
		current_target = _nearest_unvisited(origin, _chain_range(), context.visited_targets)


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
	var existing_stacks := _shock_stacks(target)
	var event := DamageEvent.create(
		target,
		amount * (1.0 + SHOCK_DAMAGE_PER_STACK * float(existing_stacks)),
		player,
		source_id,
		FleshdriveCatalog.ELECTRIC
	)
	event.damage_type = DamageEvent.DamageType.DIRECT
	event.can_crit = true
	event.critical_chance = float(player.get_meta("critical_chance", 0.05))
	event.critical_multiplier = float(player.get_meta("critical_multiplier", 1.5))
	event.proc_context = context
	event.metadata["thunder_shocked"] = existing_stacks > 0 or _level(&"conductive_fur") > 0
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
		_show_shock_crown(target, mini(existing_stacks + 1, SHOCK_MAX_STACKS))
	if allow_capacitor and _level(&"capacitor_organ") > 0 and int(state["charge_generated"]) < 6:
		state["charge_generated"] = int(state["charge_generated"]) + 1
		capacitor_charge += 1
	lightning_activity += 1
	if _level(&"overload_heart") > 0:
		overload = minf(overload + 1.25, 100.0)
	if _level(&"singularity_core") > 0 and lightning_activity >= 50:
		lightning_activity -= 50
		thunderstate_remaining = 3.0
		_show_thunderstate_activation()


func _try_storm_core(
	source: Node2D,
	damage: float,
	context: ProcContext,
	state: Dictionary,
	allow_capacitor: bool
) -> void:
	if _level(&"storm_core") <= 0 or random.randf() > 0.40:
		return
	var storm_targets := Dictionary(state["storm_targets"])
	if storm_targets.has(source.get_instance_id()):
		return
	storm_targets[source.get_instance_id()] = true
	var target := _nearest_unvisited(source.global_position, _chain_range() * 0.8, context.visited_targets)
	if target == null:
		return
	context.visit(target)
	_hit_target(target, damage * 0.45, &"storm_core", context, state, allow_capacitor)
	_draw_lightning(source.global_position, target.global_position, 0.66, true)


func _try_neural_thunder(
	source: Node2D,
	damage: float,
	context: ProcContext,
	state: Dictionary,
	allow_capacitor: bool
) -> void:
	if _level(&"neural_thunder") <= 0 or random.randf() > 0.40:
		return
	var branches := 0
	for target in host.nearest_enemies_for_build(source.global_position, _chain_range(), 8):
		if int(state["budget"]) <= 0 or branches >= 3:
			break
		if not context.visit(target):
			continue
		_hit_target(target, damage * 0.62, &"neural_thunder", context, state, allow_capacitor)
		_draw_lightning(source.global_position, target.global_position, 0.84, true)
		branches += 1


func _on_target_killed(target: Node2D, event: DamageEvent) -> void:
	if event == null or event.source != player or _level(&"ionized_blood") <= 0:
		return
	if not bool(event.metadata.get("thunder_shocked", false)):
		return
	if event.source_id == &"ionized_blood" or random.randf() > 0.60:
		return
	var center := target.global_position
	var context := ProcContext.new(0)
	var state := {"budget": 12, "charge_generated": 6, "feedback_targets": {}, "storm_targets": {}}
	for enemy in host.enemies_in_radius_for_build(center, 120.0):
		if enemy == target or not context.visit(enemy):
			continue
		_hit_target(enemy, maxf(player.attack_damage, BASE_DAMAGE) * 0.50, &"ionized_blood", context, state, false)
	_show_ionized_explosion(center)


func _update_eye_of_the_storm() -> void:
	if _level(&"eye_of_the_storm") <= 0:
		player.set_meta("thunder_move_multiplier", 1.0)
		player.set_meta("thunder_dash_multiplier", 1.0)
		player.set_meta("eye_of_storm_active", false)
		return
	var shocked: Array[Node2D] = []
	for enemy in host.enemies_in_radius_for_build(player.global_position, 300.0):
		if _shock_stacks(enemy) > 0:
			shocked.append(enemy)
	var active := shocked.size() >= 5
	player.set_meta("thunder_move_multiplier", 1.15 if active else 1.0)
	player.set_meta("thunder_dash_multiplier", 0.80 if active else 1.0)
	player.set_meta("eye_of_storm_active", active)
	if active and eye_discharge_tick <= 0.0:
		eye_discharge_tick = 0.65
		var target := shocked[random.randi_range(0, shocked.size() - 1)]
		var state := {"budget": 1, "charge_generated": 6, "feedback_targets": {}, "storm_targets": {}}
		_hit_target(target, maxf(player.attack_damage, BASE_DAMAGE) * 0.30, &"eye_of_the_storm", ProcContext.new(0), state, false)
		_draw_lightning(player.global_position, target.global_position, 0.72, true)


func _emit_thunderstate_relays() -> void:
	var nodes: Array[Node2D] = []
	for enemy in host.nearest_enemies_for_build(player.global_position, 520.0, 16):
		if _shock_stacks(enemy) > 0:
			nodes.append(enemy)
	if nodes.size() < 2:
		return
	var state := {"budget": 8, "charge_generated": 4, "feedback_targets": {}, "storm_targets": {}}
	for index in range(mini(nodes.size() - 1, 8)):
		var source := nodes[index]
		var target := nodes[index + 1]
		_hit_target(target, maxf(player.attack_damage, BASE_DAMAGE) * 0.34, &"singularity", ProcContext.new(0), state, false)
		_draw_lightning(source.global_position, target.global_position, 0.72, true)


func _nearest_unvisited(center: Vector2, radius: float, visited: Dictionary) -> Node2D:
	for enemy in host.nearest_enemies_for_build(center, radius, 24):
		if not visited.has(enemy.get_instance_id()):
			return enemy
	return null


func _shock_stacks(target: Node2D) -> int:
	if pipeline == null or not is_instance_valid(target):
		return 0
	return int(Dictionary(pipeline.call("get_status", target, &"shock")).get("stacks", 0))


func _chain_range() -> float:
	var result := (
		CHAIN_RANGE * pow(1.20, float(_level(&"pulse_capacitor")))
		+ 18.0 * float(_level(&"arc_relay"))
		+ 12.0 * float(_level(&"grounding_filaments"))
	)
	if overload > 50.0 and _level(&"overload_heart") > 0:
		result *= 1.0 + floorf((overload - 50.0) / 10.0) * 0.05
	return result


func _overload_damage_multiplier() -> float:
	if overload <= 50.0 or _level(&"overload_heart") <= 0:
		return 1.0
	return 1.0 + floorf((overload - 50.0) / 10.0) * 0.08


func _ignore_falloff() -> bool:
	return _level(&"overload_heart") > 0 and overload >= 80.0


func _level(upgrade_id: StringName) -> int:
	return player.get_upgrade_level(upgrade_id) if player != null else 0


func _is_living_enemy(target: Node2D) -> bool:
	return is_instance_valid(target) and target.is_in_group("enemies") and target.get("is_dead") != true


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
			_track_lightning_asset(
				arc,
				source_anchor,
				target_anchor,
				intensity,
				branch
			)
	host.play_build_vfx(&"electric_impact", to, 0.85 + intensity * 0.45)


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
	branch: bool
) -> void:
	while (
		is_instance_valid(arc)
		and arc.visible
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
	if not is_instance_valid(target):
		return
	var existing := target.get_node_or_null("ThunderShockCrown") as Line2D
	if existing != null:
		existing.default_color.a = 0.34 + 0.10 * float(stacks)
		return
	var crown := Line2D.new()
	crown.name = "ThunderShockCrown"
	crown.position = Vector2.ZERO
	crown.set_as_top_level(false)
	crown.width = 2.0
	crown.default_color = Color(0.25, 0.88, 1.0, 0.58)
	crown.material = unshaded_vfx_material
	crown.z_index = 24
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		var radius := 24.0 + (4.0 if index % 2 == 0 else -2.0)
		points.append(Vector2.from_angle(angle) * radius + Vector2(0.0, -8.0))
	crown.points = points
	target.add_child(crown)
	var tween := crown.create_tween().set_loops()
	tween.tween_property(crown, "modulate:a", 0.35, 0.24)
	tween.tween_property(crown, "modulate:a", 1.0, 0.24)


func _cleanup_shock_visuals() -> void:
	for enemy in host.living_enemies_for_build():
		var crown := enemy.get_node_or_null("ThunderShockCrown")
		if crown != null and _shock_stacks(enemy) <= 0:
			crown.queue_free()


func _update_player_aura(active: bool) -> void:
	if not active:
		if is_instance_valid(player_aura):
			player_aura.hide()
		return
	if not is_instance_valid(player_aura):
		player_aura = Node2D.new()
		player_aura.name = "ThunderGodAura"
		player_aura.z_index = 22
		player.add_child(player_aura)
		for ring_index in range(2):
			var ring := Line2D.new()
			ring.width = 3.0 if ring_index == 0 else 7.0
			ring.default_color = (
				Color(0.60, 0.95, 1.0, 0.82)
				if ring_index == 0
				else Color(0.05, 0.62, 1.0, 0.18)
			)
			ring.material = unshaded_vfx_material
			var points := PackedVector2Array()
			for index in range(25):
				var angle := TAU * float(index) / 24.0
				var radius := 54.0 + float(ring_index * 12) + (5.0 if index % 3 == 0 else -2.0)
				points.append(Vector2.from_angle(angle) * radius)
			ring.points = points
			player_aura.add_child(ring)
	player_aura.show()
	player_aura.rotation += 0.055
	player_aura.scale = Vector2.ONE * (
		1.12 if thunderstate_remaining > 0.0 else 1.0
	)


func _show_discharge_burst(center: Vector2) -> void:
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
	var visible := _level(&"arc_heart") > 0 and (
		_level(&"conductive_fur") > 0
		or _level(&"capacitor_organ") > 0
		or _level(&"overload_heart") > 0
	) and _level(&"static_claws") <= 0
	status_layer.call("set_build_visible", visible)
	if not visible:
		return
	var ready_now := false
	if _level(&"overload_heart") > 0:
		status_bar.max_value = 100.0
		status_bar.value = overload
		status_label.text = "OVERLOAD  %d / 100%s" % [
			roundi(overload), "  READY" if overload >= 80.0 else ""
		]
		ready_now = overload >= 80.0
	elif _level(&"capacitor_organ") > 0:
		status_bar.max_value = CAPACITOR_THRESHOLD
		status_bar.value = mini(capacitor_charge, CAPACITOR_THRESHOLD)
		status_label.text = "NEXT DISCHARGE  %d / %d" % [
			mini(capacitor_charge, CAPACITOR_THRESHOLD), CAPACITOR_THRESHOLD
		]
		ready_now = capacitor_charge >= CAPACITOR_THRESHOLD
	else:
		var shocked := 0
		for enemy in host.living_enemies_for_build():
			if _shock_stacks(enemy) > 0:
				shocked += 1
		status_bar.max_value = 5.0
		status_bar.value = mini(shocked, 5)
		status_label.text = "SHOCKED TARGETS  %d / 5" % mini(shocked, 5)
	if ready_now and not ready_announced:
		_announce_build_ready()
	ready_announced = ready_now


func _announce_build_ready() -> void:
	if host == null or player == null:
		return
	host.play_build_sound(&"capacitor_ready", -2.0)
	var outline := Line2D.new()
	outline.name = "BuildReadyOutline"
	outline.width = 3.0
	outline.default_color = Color(0.48, 0.92, 1.0, 0.94)
	outline.material = unshaded_vfx_material
	outline.closed = true
	outline.antialiased = false
	outline.points = PackedVector2Array([
		Vector2(-24, -30), Vector2(24, -30), Vector2(32, 0),
		Vector2(24, 30), Vector2(-24, 30), Vector2(-32, 0),
		Vector2(-24, -30),
	])
	outline.z_index = 28
	player.add_child(outline)
	var tween := outline.create_tween()
	tween.tween_interval(0.52)
	tween.tween_property(outline, "modulate:a", 0.0, 0.24)
	tween.tween_callback(outline.queue_free)
