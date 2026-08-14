class_name BuildRuntime
extends RefCounted


var host: PlayerWeaponSystem
var player: Koda
var pipeline: Node
var random := RandomNumberGenerator.new()
var chain_hit_counter: int = 0
var movement_charge_distance: float = 0.0
var movement_charges: int = 0
var previous_position := Vector2.ZERO
var reactive_cooldown: float = 0.0
var barrier_remaining: float = 0.0
var split_window: float = 0.0
var split_count: int = 0
var wildfire_tick: float = 0.75
var secondary_projectile_impacts: int = 0
var inferno_tick_counter: int = 0
var cautery_window: float = 0.0
var cautery_healed: float = 0.0
var fire_idle_time: float = 0.0
var pressure_stacks: int = 0


func setup(owner: PlayerWeaponSystem, combat_pipeline: Node) -> void:
	host = owner
	player = owner.player
	pipeline = combat_pipeline
	previous_position = player.global_position
	random.randomize()
	if pipeline != null:
		if not pipeline.damage_applied.is_connected(_on_damage_applied):
			pipeline.damage_applied.connect(_on_damage_applied)
		if not pipeline.target_killed.is_connected(_on_target_killed):
			pipeline.target_killed.connect(_on_target_killed)


func shutdown() -> void:
	if pipeline == null:
		return
	if pipeline.damage_applied.is_connected(_on_damage_applied):
		pipeline.damage_applied.disconnect(_on_damage_applied)
	if pipeline.target_killed.is_connected(_on_target_killed):
		pipeline.target_killed.disconnect(_on_target_killed)


func update(delta: float) -> void:
	cautery_window -= delta
	if cautery_window <= 0.0:
		cautery_window = 1.0
		cautery_healed = 0.0
	fire_idle_time += delta
	var pressure_level := level(&"pressure_crucible")
	if pressure_level > 0:
		while fire_idle_time >= BuildItemCatalog.value(&"pressure_crucible", "interval", 1.5):
			fire_idle_time -= BuildItemCatalog.value(&"pressure_crucible", "interval", 1.5)
			pressure_stacks = mini(pressure_stacks + 1, 3)
	reactive_cooldown = maxf(reactive_cooldown - delta, 0.0)
	barrier_remaining = maxf(barrier_remaining - delta, 0.0)
	split_window -= delta
	if split_window <= 0.0:
		split_window = 1.0
		split_count = 0
	var travelled := previous_position.distance_to(player.global_position)
	previous_position = player.global_position
	if travelled < 80.0:
		movement_charge_distance += travelled
		while movement_charge_distance >= 280.0 and movement_charges < 3:
			movement_charge_distance -= 280.0
			movement_charges += 1
	wildfire_tick -= delta
	if wildfire_tick <= 0.0:
		wildfire_tick += 0.75
		_spread_wildfire_stacks()


func level(upgrade_id: StringName) -> int:
	return player.get_upgrade_level(upgrade_id)


func modify_damage(
	source_id: StringName,
	affinity: StringName,
	amount: float,
	damage_type: DamageEvent.DamageType
) -> float:
	var result := amount
	var galvanic := level(&"galvanic_tendons")
	if galvanic > 0 and affinity == FleshdriveCatalog.ELECTRIC and source_id != &"shock_ram":
		result *= maxf(0.1, 1.0 - BuildItemCatalog.value(&"galvanic_tendons", "secondary_penalty_per_level") * float(galvanic))
	var smolder := level(&"smoldering_hide")
	if smolder > 0 and affinity == FleshdriveCatalog.FIRE and damage_type != DamageEvent.DamageType.DAMAGE_OVER_TIME:
		result *= maxf(0.1, 1.0 - BuildItemCatalog.value(&"smoldering_hide", "direct_penalty_per_level") * float(smolder))
	if source_id in [&"combustion_sac", &"flashpoint_nodes", &"ashen_eruption"]:
		var pressure := level(&"ash_pressure_chamber")
		result *= 1.0 + BuildItemCatalog.value(&"ash_pressure_chamber", "damage_per_level") * float(pressure)
	return result


func shock_ram_damage_multiplier() -> float:
	var capacitor := level(&"kinetic_capacitor")
	if capacitor <= 0:
		return 1.0
	var charges := consume_movement_charges()
	return 1.0 + BuildItemCatalog.value(&"kinetic_capacitor", "damage_per_level_charge") * float(capacitor * charges)


func shock_ram_radius_multiplier() -> float:
	return 1.0 + BuildItemCatalog.value(&"galvanic_tendons", "radius_per_level") * float(level(&"galvanic_tendons"))


func arc_damage_multiplier() -> float:
	return 1.65 if level(&"linear_inductor") > 0 else 1.0


func arc_range_multiplier() -> float:
	return (1.35 if level(&"linear_inductor") > 0 else 1.0) * (
		1.0 + 0.12 * float(level(&"rail_synapses"))
	)


func arc_speed_multiplier() -> float:
	return 1.0 + 0.12 * float(level(&"rail_synapses"))


func arc_width_multiplier() -> float:
	var result := 0.65 if level(&"linear_inductor") > 0 else 1.0
	return maxf(result * (1.0 - 0.06 * float(level(&"rail_synapses"))), 0.35)


func on_arc_projectile_finished(hit_count: int) -> void:
	var rail := level(&"rail_synapses")
	if rail > 0 and hit_count >= 3:
		host.refund_weapon_cooldown(&"arc_spear", 0.05 * float(rail))
		_record_trigger(&"rail_synapses")


func quill_projectile_count_bonus() -> int:
	var marrow := level(&"ionic_marrow")
	return int(marrow >= 1) + int(marrow >= 3) + int(marrow >= 5)


func quill_damage_multiplier() -> float:
	return maxf(1.0 - 0.04 * float(level(&"ionic_marrow")), 0.65)


func on_quill_impact(target: Node2D, damage: float) -> void:
	if not is_instance_valid(target):
		return
	if level(&"corona_follicles") > 0:
		var context := ProcContext.new(1)
		context.visit(target)
		var split_targets := host.nearest_enemies_for_build(target.global_position, 210.0, 3)
		var splits := 0
		for split_target in split_targets:
			if split_target == target or not context.visit(split_target):
				continue
			host.damage_enemy_for_build(split_target, damage * 0.35, &"corona_follicles", DamageEvent.HitRole.SECONDARY, false, context)
			splits += 1
			if splits >= 2:
				break
	secondary_projectile_impacts += 1
	var plumage := level(&"storm_plumage")
	if plumage > 0 and secondary_projectile_impacts >= 6:
		secondary_projectile_impacts = 0
		var burst_damage := player.attack_damage * (0.35 + 0.08 * float(plumage))
		for enemy in host.enemies_in_radius_for_build(target.global_position, 110.0):
			host.damage_enemy_for_build(enemy, burst_damage, &"storm_plumage", DamageEvent.HitRole.SECONDARY, false)
		host.play_build_vfx(&"electro_shock", target.global_position, 1.8)
		_record_trigger(&"storm_plumage")


func inferno_tick_rate_multiplier() -> float:
	return 1.20 if furnace_active() else 1.0


func furnace_active() -> bool:
	if level(&"furnace_carapace") <= 0 or pipeline == null:
		return false
	var burning := 0
	for enemy in host.enemies_in_radius_for_build(player.global_position, 190.0):
		if not Dictionary(pipeline.call("get_status", enemy, &"burn")).is_empty():
			burning += 1
	return burning >= 3


func incoming_damage_multiplier() -> float:
	return 0.78 if furnace_active() else 1.0


func on_inferno_ring_hit(target: Node2D) -> void:
	var valves := level(&"cautery_valves")
	if valves > 0:
		var cap := 0.8 + 0.2 * float(valves)
		var heal := minf(0.08 * float(valves), maxf(cap - cautery_healed, 0.0))
		if heal > 0.0:
			player.heal(heal)
			cautery_healed += heal


func on_inferno_ring_cast(targets: Array[Node2D]) -> void:
	inferno_tick_counter += 1
	var gland := level(&"thermal_pulse_gland")
	if gland <= 0 or inferno_tick_counter % 4 != 0:
		return
	var pull := 35.0 + 8.0 * float(gland)
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		host.displace_enemy_for_build(enemy, enemy.global_position.direction_to(player.global_position), pull)
		host.apply_burn(enemy, 2.0, 3.0, 1)
	_record_trigger(&"thermal_pulse_gland")


func magma_damage_multiplier() -> float:
	var result := 1.0 + 0.07 * float(level(&"kiln_chamber"))
	if level(&"obsidian_throat") > 0:
		result *= 1.90
	var pressure := level(&"pressure_crucible")
	if pressure > 0 and pressure_stacks > 0:
		result *= 1.0 + 0.08 * float(pressure * pressure_stacks)
		pressure_stacks = 0
		_record_trigger(&"pressure_crucible")
	return result


func magma_range_multiplier() -> float:
	return 1.0 + 0.10 * float(level(&"kiln_chamber"))


func register_fire_hit() -> void:
	fire_idle_time = 0.0


func orbit_capacity_bonus() -> int:
	return 2 if level(&"orbit_brood_sac") > 0 else 0


func orbit_radius_multiplier() -> float:
	return 1.25 if level(&"orbit_brood_sac") > 0 else 1.0


func orbit_collision_multiplier() -> float:
	return 1.0 + 0.16 * float(level(&"collision_nucleus"))


func orbit_duration_multiplier() -> float:
	return maxf(1.0 - 0.04 * float(level(&"collision_nucleus")), 0.65)


func neural_damage_multiplier(distance: float) -> float:
	var result := 2.0 if level(&"synaptic_rail") > 0 else 1.0
	var parallax := level(&"psychic_parallax")
	if parallax > 0:
		var steps := floori(distance / 220.0)
		result *= 1.0 + minf(0.05 * float(parallax * steps), 0.15 * float(parallax))
	return result


func neural_force_multiplier() -> float:
	return 1.5 if level(&"synaptic_rail") > 0 else 1.0


func neural_width_multiplier() -> float:
	return 0.70 if level(&"synaptic_rail") > 0 else 1.0


func neural_echo_multiplier() -> float:
	var echo := level(&"thought_echo")
	return 0.25 + 0.08 * float(echo) if echo > 0 else 0.0


func _record_trigger(build_item: StringName) -> void:
	var telemetry := player.get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null and telemetry.has_method("record_build_trigger"):
		telemetry.call("record_build_trigger", build_item)


func fire_explosion_radius(base_radius: float) -> float:
	return base_radius * (1.0 + BuildItemCatalog.value(&"ash_pressure_chamber", "radius_per_level") * float(level(&"ash_pressure_chamber")))


func burn_duration_multiplier() -> float:
	return 1.0 + BuildItemCatalog.value(&"smoldering_hide", "duration_per_level") * float(level(&"smoldering_hide"))


func burn_tick_multiplier(center: Vector2) -> float:
	var oxygen := level(&"oxygen_thief")
	if oxygen <= 0 or pipeline == null:
		return 1.0
	var burning := 0
	for enemy in host.enemies_in_radius_for_build(center, 280.0):
		if not Dictionary(pipeline.call("get_status", enemy, &"burn")).is_empty():
			burning += 1
	var bonus := minf(0.006 * float(oxygen) * float(burning), 0.06 * float(oxygen))
	return 1.0 + bonus


func consume_movement_charges() -> int:
	var charges := movement_charges
	movement_charges = 0
	return charges


func on_dash_finished(hit_count: int) -> void:
	if hit_count >= 2 and level(&"thunder_gait") > 0:
		player.refund_dash_cooldown_fraction(0.45)
		host.emit_dash_aftershock(player.attack_damage * 0.70)


func activate_repulse_barrier() -> void:
	if level(&"vector_mantle") > 0:
		barrier_remaining = 1.2


func barrier_active() -> bool:
	return barrier_remaining > 0.0


func on_player_damaged() -> void:
	var reactive := level(&"reactive_cranium")
	if reactive <= 0 or reactive_cooldown > 0.0:
		return
	if random.randf() <= 0.15 + 0.05 * float(reactive):
		reactive_cooldown = 3.0
		host.emit_reactive_repulse(0.45)


func on_projectile_reversed(projectile_position: Vector2, projectile_damage: float) -> void:
	var prism := level(&"mirror_prism")
	if prism <= 0 or split_count >= 6:
		return
	var copies := mini(2, 6 - split_count)
	split_count += copies
	var targets := host.nearest_enemies_for_build(projectile_position, 420.0, copies)
	for target in targets:
		host.damage_enemy_for_build(
			target,
			projectile_damage * (0.45 + 0.06 * float(prism)),
			&"mirror_prism",
			DamageEvent.HitRole.REFLECTED,
			false
		)


func _on_damage_applied(event: DamageEvent, result: Dictionary) -> void:
	if event == null or event.source != player or not bool(result.get("accepted", false)):
		return
	if event.affinity == FleshdriveCatalog.ELECTRIC:
		_handle_electric_hit(event)
	elif event.affinity == FleshdriveCatalog.FIRE:
		register_fire_hit()


func _handle_electric_hit(event: DamageEvent) -> void:
	if not is_instance_valid(event.target) or pipeline == null:
		return
	var grounded := Dictionary(pipeline.call("get_status", event.target, &"grounded"))
	if event.source_id == &"arc_spear":
		var scar := level(&"polarized_scar")
		if scar > 0:
			var mark := Dictionary(pipeline.call("get_status", event.target, &"polarized_scar"))
			if mark.is_empty():
				pipeline.call("apply_status", event.target, {"id": &"polarized_scar", "duration": 2.5, "stack_gain": 1, "max_stacks": 1, "affinity": FleshdriveCatalog.ELECTRIC}, player, &"polarized_scar")
			else:
				pipeline.call("consume_status_stacks", event.target, &"polarized_scar", 1)
				host.damage_enemy_for_build(event.target, event.amount * 0.08 * float(scar), &"polarized_scar", DamageEvent.HitRole.SECONDARY, false)
				host.play_build_vfx(&"electric_impact", event.target.global_position, 1.25)
				host.play_build_sound(&"electric_impact", -11.0)
				_record_trigger(&"polarized_scar")
	var filaments := level(&"grounding_filaments")
	if event.source_id == &"chain_lightning":
		chain_hit_counter += 1
		var reservoir := level(&"static_reservoir")
		if reservoir > 0 and chain_hit_counter >= 10:
			chain_hit_counter = 0
			host.emit_static_reservoir(
				event.target.global_position,
				player.attack_damage * (0.70 + 0.15 * float(reservoir))
			)
		if filaments > 0 and not grounded.is_empty():
			pipeline.call("consume_status_stacks", event.target, &"grounded", 1)
			host.damage_enemy_for_build(
				event.target,
				float(event.amount) * 0.07 * float(filaments),
				&"grounding_filaments",
				DamageEvent.HitRole.SECONDARY,
				false
			)
	if filaments > 0 and grounded.is_empty():
		pipeline.call("apply_status", event.target, {
			"id": &"grounded", "duration": 2.0, "stack_gain": 1,
			"max_stacks": 1, "affinity": FleshdriveCatalog.ELECTRIC,
		}, player, &"grounding_filaments")
	var forked := level(&"forked_arc_node")
	if forked > 0 and event.source_id == &"chain_lightning" and event.can_trigger_procs:
		var context := event.proc_context
		if context == null:
			context = ProcContext.new(1)
			context.visit(event.target)
		if context.can_fork() and random.randf() <= 0.45:
			var child := context.fork()
			for target in host.nearest_enemies_for_build(event.target.global_position, player.chain_range, 4):
				if child.visit(target):
					host.damage_enemy_for_build(target, event.amount * 0.45, &"chain_lightning", DamageEvent.HitRole.SECONDARY, false, child)
					if child.visited_targets.size() >= 3:
						break


func _on_target_killed(target: Node2D, event: DamageEvent) -> void:
	if event == null or event.source != player:
		return
	var igniter := level(&"chain_igniter")
	if igniter <= 0 or event.affinity != FleshdriveCatalog.FIRE:
		return
	var context := event.proc_context
	if context == null:
		context = ProcContext.new(3)
	if not context.can_fork() or random.randf() > 0.12 + 0.04 * float(igniter):
		return
	var child := context.fork()
	host.emit_chain_igniter(target.global_position, child)


func _spread_wildfire_stacks() -> void:
	if level(&"spore_ember_sac") <= 0 or pipeline == null:
		return
	var transfers := 0
	for source in host.living_enemies_for_build():
		var burn := Dictionary(pipeline.call("get_status", source, &"burn"))
		if int(burn.get("stacks", 0)) < 5:
			continue
		for target in host.nearest_enemies_for_build(source.global_position, 150.0, 4):
			if target == source or not Dictionary(pipeline.call("get_status", target, &"burn")).is_empty():
				continue
			host.apply_burn(target, maxf(float(burn.get("damage_per_second", 1.0)) / 5.0, 1.0), 3.0, 1)
			transfers += 1
			break
		if transfers >= 2:
			break
