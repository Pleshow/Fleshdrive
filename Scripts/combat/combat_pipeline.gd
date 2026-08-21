extends Node


signal damage_applied(event: DamageEvent, result: Dictionary)
signal target_killed(target: Node2D, event: DamageEvent)
signal status_ended(
	target_position: Vector2,
	status_id: StringName,
	context: Dictionary,
	reason: StringName
)

var status_effects: StatusEffectManager
var random := RandomNumberGenerator.new()
var processed_event_count: int = 0
var rejected_event_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.randomize()
	status_effects = StatusEffectManager.new()
	status_effects.name = "StatusEffectManager"
	add_child(status_effects)
	status_effects.setup(self)
	status_effects.status_ended.connect(status_ended.emit)


func apply_damage(event: DamageEvent) -> Dictionary:
	var result := {
		"accepted": false,
		"damage": 0.0,
		"critical": false,
		"killed": false,
		"knockback": 0.0,
	}
	# Reject delayed collision/status callbacks while gameplay is suspended.
	# This also closes the intermittent "mystery damage" path seen when a
	# projectile callback arrived during a pause transition.
	if get_tree().paused:
		rejected_event_count += 1
		return result
	if (
		event == null
		or not is_instance_valid(event.target)
		or event.amount <= 0.0
		or event.target.get("is_dead") == true
	):
		rejected_event_count += 1
		return result
	var target := event.target
	var amount := event.amount
	amount = _apply_swarm_power_curve(event, target, amount)
	if target.has_method("modify_incoming_damage_event"):
		amount = float(target.call(
			"modify_incoming_damage_event",
			event,
			amount
		))
	amount = EliteModifier.modify_damage_for(target, amount)
	var critical := false
	if event.can_crit and random.randf() < event.critical_chance:
		critical = true
		amount *= maxf(event.critical_multiplier, 1.0)
	amount = maxf(amount, 0.0)
	if amount <= 0.0:
		rejected_event_count += 1
		return result
	var was_dead := bool(target.get("is_dead"))
	target.set_meta("last_damage_affinity", event.affinity)
	if target.has_method("receive_damage_event"):
		target.call("receive_damage_event", event, amount)
	elif target.has_method("take_damage"):
		target.call("take_damage", amount, event.play_hit_sound)
	else:
		rejected_event_count += 1
		return result
	processed_event_count += 1
	var killed := (
		is_instance_valid(target)
		and not was_dead
		and bool(target.get("is_dead"))
	)
	var applied_knockback := _apply_knockback(event)
	if is_instance_valid(target):
		for status_definition in event.status_effects:
			status_effects.apply_status(
				target,
				status_definition,
				event.source,
				event.source_id
			)
		_register_feedback(event, amount, critical)
	_record_damage_source(event, amount)
	result = {
		"accepted": true,
		"damage": amount,
		"critical": critical,
		"killed": killed,
		"knockback": applied_knockback,
	}
	damage_applied.emit(event, result)
	if killed:
		_register_death_feedback(event)
		status_effects.notify_target_killed(target)
		target_killed.emit(target, event)
	return result


func _apply_swarm_power_curve(
	event: DamageEvent,
	target: Node2D,
	amount: float
) -> float:
	# Crawlers are the late-run fodder fantasy: builds increasingly erase them,
	# while Spitters, Chargers and the Warden retain their full durability and
	# damage. This shifts difficulty toward readable projectiles and specials
	# without lowering population density.
	if event.source is Koda and target is Crawler:
		if not bool(target.get_meta("is_elite", false)):
			var player_level := int((event.source as Koda).current_level)
			var execution_multiplier := clampf(
				1.0 + 0.24 * float(maxi(player_level - 7, 0)),
				1.0,
				3.8
			)
			amount *= execution_multiplier
	elif target is Koda and event.source is Crawler:
		var player_level := int((target as Koda).current_level)
		var fodder_threat := lerpf(
			1.0,
			0.55,
			clampf(float(player_level - 7) / 10.0, 0.0, 1.0)
		)
		amount *= fodder_threat
	return amount


func _register_death_feedback(event: DamageEvent) -> void:
	var feedback := get_tree().get_first_node_in_group("combat_feedback")
	if feedback != null and feedback.has_method("register_death"):
		feedback.call(
			"register_death",
			event.target.global_position if is_instance_valid(event.target) else Vector2.ZERO,
			event.affinity,
			event.knockback_direction
		)


func apply_status(
	target: Node2D,
	definition: Dictionary,
	source: Node = null,
	source_id: StringName = &"status"
) -> void:
	status_effects.apply_status(target, definition, source, source_id)


func apply_displacement(
	target: Node2D,
	direction: Vector2,
	strength: float,
	tags: Array[StringName] = []
) -> float:
	if not is_instance_valid(target):
		return 0.0
	var event := DamageEvent.create(target, 0.0)
	event.knockback_direction = direction.normalized()
	event.knockback_strength = strength
	event.tags = tags
	var applied := _apply_knockback(event)
	if applied > 0.0 and &"telekinetic_displacement" in tags:
		status_effects.apply_status(target, {
			"id": &"telekinetic_displacement",
			"duration": 0.35,
			"stack_gain": 1,
			"max_stacks": 1,
			"affinity": &"telekinetic",
			"context": {"force": applied},
		})
	return applied


func register_status_marker(
	target: Node2D,
	status_id: StringName,
	context: Dictionary = {}
) -> void:
	status_effects.register_marker(target, status_id, context)


func get_status(target: Node, status_id: StringName) -> Dictionary:
	return status_effects.get_status(target, status_id)


func consume_status_stacks(
	target: Node,
	status_id: StringName,
	amount: int = -1
) -> int:
	return status_effects.consume_stacks(target, status_id, amount)


func set_status_context_value(
	target: Node,
	status_id: StringName,
	key: StringName,
	value: Variant
) -> void:
	status_effects.set_status_context_value(
		target,
		status_id,
		key,
		value
	)


func clear_transient_state() -> void:
	if status_effects != null:
		status_effects.clear_all()


func _apply_knockback(event: DamageEvent) -> float:
	if (
		event.knockback_strength <= 0.0
		or event.knockback_direction == Vector2.ZERO
		or not is_instance_valid(event.target)
	):
		return 0.0
	var resistance := 0.0
	if event.target.is_in_group("boss") and not event.has_tag(
		&"boss_displace"
	):
		resistance = 1.0
	elif event.target.has_method("get_knockback_resistance"):
		resistance = clampf(float(event.target.call(
			"get_knockback_resistance"
		)), 0.0, 1.0)
	elif event.target.has_meta("knockback_resistance"):
		resistance = clampf(float(event.target.get_meta(
			"knockback_resistance"
		)), 0.0, 1.0)
	var strength := event.knockback_strength * (1.0 - resistance)
	if strength <= 0.0:
		return 0.0
	var impulse := event.knockback_direction.normalized() * strength
	if event.target.has_method("apply_external_impulse"):
		event.target.call("apply_external_impulse", impulse)
	elif event.target is CharacterBody2D:
		(event.target as CharacterBody2D).velocity += impulse
	return strength


func _register_feedback(
	event: DamageEvent,
	amount: float,
	critical: bool
) -> void:
	if not event.show_damage_number and not event.heavy_feedback:
		return
	var feedback := get_tree().get_first_node_in_group("combat_feedback")
	if feedback == null or not feedback.has_method("register_damage"):
		return
	feedback.call(
		"register_damage",
		event.target,
		amount,
		event.affinity,
		event.heavy_feedback or critical,
		event.show_damage_number,
		critical,
		event.screen_shake,
		event.source_id
	)


func _record_damage_source(event: DamageEvent, amount: float) -> void:
	if event.source == null or not is_instance_valid(event.source):
		return
	if event.source.has_method("record_damage_source"):
		event.source.call("record_damage_source", event.source_id, amount)
		return
	var owner := event.source.get_parent()
	if owner != null and owner.has_method("record_damage_source"):
		owner.call("record_damage_source", event.source_id, amount)
