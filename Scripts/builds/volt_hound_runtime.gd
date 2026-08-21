class_name VoltHoundRuntime
extends RefCounted


const MAGENTA := Color("0098db")
const VIOLET := Color("1e579c")
const WHITE_CORE := Color("0ce6f2")
const PINK := Color("53c9ff")
const KineticChargeHudLayerScript := preload("res://Scripts/ui/kinetic_charge_hud_layer.gd")

var host: PlayerWeaponSystem
var player: Koda
var momentum: float = 0.0
var maximum_momentum: float = 100.0
var overdrive_remaining: float = 0.0
var overdrive_duration: float = 2.0
var overdrive_extension_used: float = 0.0
var ready: bool = false
var was_dashing: bool = false
var dash_start := Vector2.ZERO
var previous_position := Vector2.ZERO
var previous_direction := Vector2.ZERO
var contact_cooldowns: Dictionary = {}
var overdrive_hit_ids: Dictionary = {}
var near_miss_cooldowns: Dictionary = {}
var static_marks: Dictionary = {}
var afterimages: Array[Dictionary] = []
var damage_lockout: float = 0.0
var aura: Node2D
var kinetic_aura_sprite: AnimatedSprite2D
var unshaded_vfx_material: CanvasItemMaterial
var momentum_layer: CanvasLayer
var momentum_bar: ProgressBar
var momentum_label: Label


func setup(owner: PlayerWeaponSystem) -> void:
	host = owner
	player = owner.player
	unshaded_vfx_material = CanvasItemMaterial.new()
	unshaded_vfx_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	previous_position = player.global_position
	_install_aura()
	_install_momentum_hud()


func shutdown() -> void:
	for afterimage in afterimages:
		_free_afterimage(afterimage)
	afterimages.clear()
	if is_instance_valid(aura):
		aura.queue_free()
	if is_instance_valid(momentum_layer):
		momentum_layer.queue_free()


func update(delta: float) -> void:
	_update_timers(delta)
	_update_afterimages(delta)
	if player == null or player.is_dead:
		return
	var active := player.get_upgrade_level(&"static_claws") > 0
	if is_instance_valid(aura):
		aura.visible = active and overdrive_remaining > 0.0
	if is_instance_valid(momentum_layer):
		momentum_layer.call("set_build_visible", active)
	if not active:
		momentum = 0.0
		_update_momentum_hud()
		previous_position = player.global_position
		was_dashing = player.is_dashing
		return

	maximum_momentum = _kinetic_value("charge_max", 100.0)
	_update_momentum(delta)
	_update_dash_state()
	_update_static_claws(delta)
	_update_near_misses()
	_update_magnetic_predator(delta)
	_update_aura()
	_update_momentum_hud()
	previous_position = player.global_position
	previous_direction = player.velocity.normalized()


func on_player_damaged() -> void:
	damage_lockout = 0.42


func movement_multiplier() -> float:
	if player == null or player.get_upgrade_level(&"static_claws") <= 0:
		return 1.0
	var result := 1.0 + 0.15 * float(player.get_upgrade_level(&"voltaic_tendons") > 0)
	if overdrive_remaining > 0.0:
		result *= _kinetic_value("movement_multiplier", 1.15)
	return result


func dash_speed_multiplier() -> float:
	if player == null or player.get_upgrade_level(&"static_claws") <= 0:
		return 1.0
	var result := 1.0 + 0.20 * float(player.get_upgrade_level(&"charged_paw_pads") > 0)
	if player.get_upgrade_level(&"flash_step") > 0 and momentum >= 75.0:
		result *= 1.40
	if player.get_upgrade_level(&"lightspeed") > 0 and ready:
		result *= 1.28
	return result


func dash_cooldown_multiplier() -> float:
	return 0.72 if overdrive_remaining > 0.0 else 1.0


func modify_incoming_damage(event: DamageEvent, amount: float) -> float:
	if overdrive_remaining <= 0.0:
		return amount
	# READY is consumed on dash start and the complete Overdrive window is a
	# single, predictable invulnerability contract. This covers projectiles,
	# hazards and bosses too, rather than only ordinary contact events.
	return 0.0


func is_overdrive_active() -> bool:
	return overdrive_remaining > 0.0


func on_enemy_killed() -> void:
	if overdrive_remaining <= 0.0 or player.get_upgrade_level(&"electric_kinetic_predator_capacitor") <= 0:
		return
	var available := _kinetic_value("predator_capacitor_extension_cap", 1.0) - overdrive_extension_used
	var extension := minf(_kinetic_value("predator_capacitor_kill_extension", 0.08), available)
	if extension > 0.0:
		overdrive_remaining += extension
		overdrive_extension_used += extension


func _update_timers(delta: float) -> void:
	damage_lockout = maxf(damage_lockout - delta, 0.0)
	if overdrive_remaining > 0.0:
		overdrive_remaining = maxf(overdrive_remaining - delta, 0.0)
		if overdrive_remaining <= 0.0:
			_end_overdrive()
	for id in contact_cooldowns.keys():
		contact_cooldowns[id] = float(contact_cooldowns[id]) - delta
		if float(contact_cooldowns[id]) <= 0.0:
			contact_cooldowns.erase(id)
	for id in near_miss_cooldowns.keys():
		near_miss_cooldowns[id] = float(near_miss_cooldowns[id]) - delta
		if float(near_miss_cooldowns[id]) <= 0.0:
			near_miss_cooldowns.erase(id)


func _update_momentum(delta: float) -> void:
	if overdrive_remaining > 0.0:
		momentum = clampf(100.0 * overdrive_remaining / maxf(overdrive_duration + overdrive_extension_used, 0.01), 0.0, 100.0)
		return
	if ready:
		momentum = 100.0
		return
	var moving := player.velocity.length() > 24.0
	if moving:
		var generation := _kinetic_value("movement_charge_per_second", 6.0)
		if player.get_upgrade_level(&"voltaic_tendons") > 0:
			generation *= 1.35
		if player.get_upgrade_level(&"nerve_overclock") > 0:
			generation *= 1.25
		momentum = minf(momentum + generation * delta, maximum_momentum)
	else:
		var drain := 12.0
		if player.get_upgrade_level(&"capacitor_marrow") > 0:
			drain *= 0.50
		if player.get_upgrade_level(&"ballistic_nervous_system") > 0:
			drain = 42.0
		momentum = maxf(momentum - drain * delta, 0.0)
	if (
		player.get_upgrade_level(&"ionized_spine") > 0
		and not previous_direction.is_zero_approx()
		and not player.velocity.is_zero_approx()
		and previous_direction.dot(player.velocity.normalized()) < 0.35
	):
		_add_momentum(3.0)
	ready = momentum >= _kinetic_value("ready_threshold", 100.0)
	if ready:
		momentum = 100.0
		_spawn_radial_flash(player.global_position, 72.0, WHITE_CORE)
		host.play_build_sound(&"capacitor_ready", -2.0)
		_show_ready_outline()


func _update_dash_state() -> void:
	if player.is_dashing and not was_dashing:
		dash_start = previous_position
		if ready:
			_activate_overdrive()
		else:
			_add_momentum(_kinetic_value("dash_charge", 20.0))
		_spawn_dash_trace(dash_start, player.global_position, 0.22)
	if player.is_dashing:
		_process_dash_segment(previous_position, player.global_position, false)
	if was_dashing and not player.is_dashing:
		_finish_dash_path(dash_start, player.global_position)
	was_dashing = player.is_dashing


func _process_dash_segment(start: Vector2, finish: Vector2, replay: bool) -> void:
	if overdrive_remaining <= 0.0:
		return
	var high_momentum := momentum >= 75.0
	var lightspeed := player.get_upgrade_level(&"lightspeed") > 0 and momentum >= 100.0
	for enemy in host.living_enemies_for_build():
		if _distance_to_segment(enemy.global_position, start, finish) > _kinetic_value("contact_radius", 48.0):
			continue
		var id := enemy.get_instance_id()
		var key := "%s:%s" % [id, "replay" if replay else "dash"]
		# The route replay is a deliberate second pass: Flash Step promises that
		# it detonates the Static Mark applied by the first pass. The per-route
		# cooldown prevents frame-by-frame multi-hits while still allowing that
		# replay (or a later dash) to resolve the mark during Overdrive.
		if contact_cooldowns.has(key):
			continue
		contact_cooldowns[key] = 0.32
		overdrive_hit_ids[id] = true
		host.damage_enemy_for_build(
			enemy,
			_overdrive_contact_damage(),
			&"lightspeed" if lightspeed else &"static_claws",
			DamageEvent.HitRole.SECONDARY,
			false
		)
		if (
			(high_momentum and player.get_upgrade_level(&"flash_step") > 0)
			or overdrive_remaining > 0.0
		):
			_mark_or_detonate(enemy, lightspeed or replay)
		_spawn_radial_flash(enemy.global_position, 34.0, PINK)


func _finish_dash_path(start: Vector2, finish: Vector2) -> void:
	if overdrive_remaining <= 0.0:
		return
	if player.get_upgrade_level(&"charged_paw_pads") > 0:
		_damage_circle(finish, 84.0, 16.0, &"charged_paw_pads")
	var repeats := 0
	if player.get_upgrade_level(&"phantom_current") > 0:
		repeats = 1
	if player.get_upgrade_level(&"double_exposure") > 0:
		repeats += 1
	if player.get_upgrade_level(&"lightspeed") > 0 and momentum >= 100.0:
		repeats = maxi(repeats, 2)
	if repeats <= 0:
		return
	var trace := _spawn_dash_trace(start, finish, 0.70)
	afterimages.append({
		"start": start,
		"finish": finish,
		"timer": 0.70,
		"repeats": repeats,
		"visual": trace,
	})


func _update_afterimages(delta: float) -> void:
	for index in range(afterimages.size() - 1, -1, -1):
		var image := afterimages[index]
		image["timer"] = float(image["timer"]) - delta
		if float(image["timer"]) > 0.0:
			afterimages[index] = image
			continue
		_process_dash_segment(Vector2(image["start"]), Vector2(image["finish"]), true)
		_spawn_line_burst(Vector2(image["start"]), Vector2(image["finish"]))
		image["repeats"] = int(image["repeats"]) - 1
		if int(image["repeats"]) <= 0:
			_free_afterimage(image)
			afterimages.remove_at(index)
		else:
			image["timer"] = 0.50
			afterimages[index] = image


func _update_static_claws(_delta: float) -> void:
	if overdrive_remaining <= 0.0 or player.velocity.length() < 35.0:
		return
	for enemy in host.enemies_in_radius_for_build(player.global_position, 48.0):
		var id := enemy.get_instance_id()
		if overdrive_hit_ids.has(id):
			continue
		overdrive_hit_ids[id] = true
		host.damage_enemy_for_build(
			enemy, _overdrive_contact_damage(), &"electric_kinetic_overdrive",
			DamageEvent.HitRole.PRIMARY, false
		)
		_spawn_radial_flash(enemy.global_position, 42.0, WHITE_CORE)


func _update_near_misses() -> void:
	if player.get_upgrade_level(&"predators_static") <= 0 or damage_lockout > 0.0:
		return
	var reward := _kinetic_value("near_miss_charge", 8.0)
	var radius := 92.0
	if player.get_upgrade_level(&"predator_coil") > 0:
		reward *= 2.0
		radius = 68.0
	for enemy in host.enemies_in_radius_for_build(player.global_position, radius):
		var id := enemy.get_instance_id()
		if near_miss_cooldowns.has(id):
			continue
		if player.global_position.distance_to(enemy.global_position) < 42.0:
			continue
		near_miss_cooldowns[id] = 1.15
		_add_momentum(reward)
		_spawn_radial_flash(enemy.global_position, 46.0, MAGENTA)


func _update_magnetic_predator(delta: float) -> void:
	if player.get_upgrade_level(&"magnetic_predator") <= 0 or momentum < 75.0:
		return
	for enemy in host.enemies_in_radius_for_build(player.global_position, 190.0):
		var pull := enemy.global_position.direction_to(player.global_position + player.velocity * 0.18)
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).velocity += pull * 70.0 * delta


func _mark_or_detonate(enemy: Node2D, _force_detonate: bool) -> void:
	var id := enemy.get_instance_id()
	if static_marks.has(id):
		static_marks.erase(id)
		var existing_mark := enemy.get_node_or_null("StaticMark")
		if existing_mark != null:
			existing_mark.queue_free()
		_damage_circle(enemy.global_position, 88.0, 26.0, &"static_mark_detonation")
		_spawn_radial_flash(enemy.global_position, 88.0, WHITE_CORE)
		host.play_build_vfx(&"status_shock", enemy.global_position, 1.0)
		return
	static_marks[id] = weakref(enemy)
	_spawn_mark(enemy)


func _damage_circle(center: Vector2, radius: float, damage: float, source: StringName) -> void:
	for enemy in host.enemies_in_radius_for_build(center, radius):
		host.damage_enemy_for_build(enemy, damage, source, DamageEvent.HitRole.SECONDARY, false)


func _add_momentum(amount: float) -> void:
	if overdrive_remaining > 0.0 or ready:
		return
	momentum = clampf(momentum + amount, 0.0, maximum_momentum)
	ready = momentum >= maximum_momentum


func _activate_overdrive() -> void:
	ready = false
	overdrive_duration = _kinetic_value("overdrive_duration", 2.0)
	if player.get_upgrade_level(&"purple_heart") > 0:
		overdrive_duration += 0.5
	if player.get_upgrade_level(&"electric_kinetic_expanded_capacitor") > 0:
		overdrive_duration += _kinetic_value("expanded_capacitor_duration", 0.40)
	if player.get_upgrade_level(&"electric_kinetic_compressed_charge") > 0:
		overdrive_duration *= _kinetic_value("compressed_charge_duration_multiplier", 0.70)
	overdrive_remaining = overdrive_duration
	overdrive_extension_used = 0.0
	overdrive_hit_ids.clear()
	_spawn_radial_flash(player.global_position, 108.0, WHITE_CORE)
	_spawn_kinetic_aura_asset()
	host.play_build_vfx(&"status_haste", player.global_position, 1.35)
	host.play_build_vfx(&"status_shield", player.global_position, 1.3)


func _end_overdrive() -> void:
	overdrive_remaining = 0.0
	momentum = 0.0
	ready = false
	overdrive_hit_ids.clear()
	_spawn_radial_flash(player.global_position, 52.0, VIOLET)


func _show_ready_outline() -> void:
	_spawn_attached_asset(&"status_shield", 0.62, "KineticReadyPulse")


func _overdrive_contact_damage() -> float:
	var damage := _kinetic_value("contact_damage", 45.0) * (1.0 + 0.15 * float(player.get_upgrade_level(&"static_claws") - 1))
	if player.get_upgrade_level(&"electric_kinetic_compressed_charge") > 0:
		damage *= _kinetic_value("compressed_charge_damage_multiplier", 1.60)
	return damage


func _kinetic_value(key: String, fallback: float) -> float:
	if host != null and host.balance_database != null:
		return float(host.balance_database.call(
			"get_kinetic_value", &"electric_kinetic_overdrive", key, fallback
		))
	return fallback


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.01:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _install_aura() -> void:
	aura = Node2D.new()
	aura.name = "VoltHoundAura"
	aura.z_index = 72
	player.add_child.call_deferred(aura)
	aura.hide()


func _update_aura() -> void:
	if not is_instance_valid(aura):
		return
	if overdrive_remaining <= 0.0:
		return
	if not is_instance_valid(kinetic_aura_sprite) or not kinetic_aura_sprite.visible:
		_spawn_kinetic_aura_asset()


func _spawn_kinetic_aura_asset() -> void:
	kinetic_aura_sprite = _spawn_attached_asset(
		&"electric_chain_arc",
		0.68,
		"KineticChargeLightningAura"
	)
	if kinetic_aura_sprite != null:
		kinetic_aura_sprite.position = Vector2(-2.0, -8.0)
		kinetic_aura_sprite.rotation = 0.12
		kinetic_aura_sprite.z_index = 72
		kinetic_aura_sprite.add_to_group("kinetic_charge_vfx")
		# Reuse the authored lightning frames around Koda without requesting
		# additional point lights from the global VFX manager.
		var arc_rotations := [2.38, 4.75]
		var arc_offsets := [Vector2(-4.0, -11.0), Vector2(5.0, -4.0)]
		var arc_scales := [0.82, 1.08]
		for arc_index in range(2):
			var arc := AnimatedSprite2D.new()
			arc.name = "KineticChargeArc%d" % (arc_index + 1)
			arc.sprite_frames = kinetic_aura_sprite.sprite_frames
			arc.animation = &"play"
			arc.material = kinetic_aura_sprite.material
			arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			arc.position = arc_offsets[arc_index]
			arc.rotation = arc_rotations[arc_index]
			arc.scale = kinetic_aura_sprite.scale * arc_scales[arc_index]
			arc.flip_h = arc_index == 1
			arc.flip_v = arc_index == 0
			arc.z_index = 72
			arc.add_to_group("kinetic_charge_vfx")
			aura.add_child(arc)
			arc.animation_finished.connect(arc.queue_free, CONNECT_ONE_SHOT)
			arc.play(&"play")


func _spawn_attached_asset(
	effect_id: StringName,
	effect_scale: float,
	effect_name: String
) -> AnimatedSprite2D:
	if host == null or not host.is_inside_tree():
		return null
	var visual_effects := host.get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return null
	var sprite := visual_effects.call(
		"play",
		effect_id,
		player.global_position,
		effect_scale,
		0.0
	) as AnimatedSprite2D
	if sprite == null:
		return null
	sprite.reparent(aura, true)
	sprite.position = Vector2.ZERO
	sprite.name = effect_name
	return sprite


func _install_momentum_hud() -> void:
	momentum_layer = KineticChargeHudLayerScript.new()
	momentum_layer.name = "VoltHoundMomentumHUD"
	# Gameplay UI is layer 110 and post-process/vignette is layer 100.
	# Keep Kinetic Charge above both without occupying the XP row.
	momentum_layer.layer = 130
	# Keep the HUD owned by Koda so scene transitions release it together with
	# the run, including headless tests that do not assign current_scene.
	player.add_child.call_deferred(momentum_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-170.0, 76.0)
	panel.size = Vector2(340.0, 46.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.01, 0.025, 0.90)
	panel_style.border_color = MAGENTA
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", panel_style)
	momentum_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	momentum_label = Label.new()
	momentum_label.add_theme_font_size_override("font_size", 11)
	momentum_label.add_theme_color_override("font_color", WHITE_CORE)
	stack.add_child(momentum_label)
	momentum_bar = ProgressBar.new()
	momentum_bar.show_percentage = false
	momentum_bar.custom_minimum_size = Vector2(0.0, 12.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("07182b")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("1e579c")
	fill.set_corner_radius_all(3)
	momentum_bar.add_theme_stylebox_override("background", background)
	momentum_bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(momentum_bar)
	momentum_layer.hide()


func _update_momentum_hud() -> void:
	if not is_instance_valid(momentum_bar):
		return
	momentum_bar.max_value = maximum_momentum
	momentum_bar.value = momentum
	momentum_label.modulate = (
		WHITE_CORE
		if overdrive_remaining > 0.0
		else Color(1.0, 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.012), 1.0)
		if ready
		else Color.WHITE
	)
	momentum_label.text = "KINETIC CHARGE  %d / %d%s" % [
		roundi(momentum), roundi(maximum_momentum),
		"  OVERDRIVE" if overdrive_remaining > 0.0 else ("  READY - DASH" if ready else ""),
	]


func _spawn_dash_trace(start: Vector2, finish: Vector2, alpha: float) -> Line2D:
	var line := Line2D.new()
	line.name = "VoltHoundAfterimage"
	line.width = 7.0
	line.default_color = Color(MAGENTA, alpha)
	line.material = unshaded_vfx_material
	line.points = PackedVector2Array([start, (start + finish) * 0.5 + Vector2(0.0, -5.0), finish])
	_add_visual(line)
	return line


func _spawn_line_burst(start: Vector2, finish: Vector2) -> void:
	var line := _spawn_dash_trace(start, finish, 0.95)
	line.width = 12.0
	line.default_color = WHITE_CORE
	_fade_visual(line, 0.18)


func _spawn_radial_flash(position: Vector2, radius: float, _color: Color) -> void:
	# The old polygonal ring read as a flat geometric debug shape after the
	# Ink Crimson pass. Use authored electric animation frames for every burst.
	var effect_id := &"electric_impact"
	if radius >= 80.0:
		effect_id = &"electro_shock"
	elif radius >= 48.0:
		effect_id = &"ball_lightning_burst"
	var scale_multiplier := clampf(radius / 54.0, 0.62, 2.1)
	host.play_build_vfx(effect_id, position, scale_multiplier)


func _spawn_mark(enemy: Node2D) -> void:
	if enemy.get_node_or_null("StaticMark") != null:
		return
	var mark := Line2D.new()
	mark.name = "StaticMark"
	mark.closed = true
	mark.width = 2.0
	mark.default_color = PINK
	mark.material = unshaded_vfx_material
	for index in range(8):
		mark.add_point(Vector2.from_angle(TAU * float(index) / 8.0) * 22.0)
	enemy.add_child(mark)


func _add_visual(visual: CanvasItem) -> void:
	var container := host.get_tree().get_first_node_in_group("effects_container")
	if container == null:
		container = host.get_tree().current_scene
	container.add_child(visual)
	visual.add_to_group("volt_hound_vfx")


func _fade_visual(visual: CanvasItem, duration: float) -> void:
	var tween := visual.create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, duration)
	tween.tween_callback(visual.queue_free)


func _free_afterimage(data: Dictionary) -> void:
	var visual := data.get("visual") as CanvasItem
	if is_instance_valid(visual):
		visual.queue_free()
