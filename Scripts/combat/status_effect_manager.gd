class_name StatusEffectManager
extends Node


signal status_ended(
	target_position: Vector2,
	status_id: StringName,
	context: Dictionary,
	reason: StringName
)

var active_statuses: Dictionary = {}
var combat_pipeline: Node


func setup(pipeline: Node) -> void:
	combat_pipeline = pipeline
	process_mode = Node.PROCESS_MODE_ALWAYS


func apply_status(
	target: Node2D,
	definition: Dictionary,
	source: Node = null,
	source_id: StringName = &"status"
) -> void:
	if not is_instance_valid(target):
		return
	var status_id := StringName(definition.get("id", &""))
	if status_id.is_empty():
		return
	var target_id := target.get_instance_id()
	var target_statuses: Dictionary = active_statuses.get(target_id, {})
	var key := String(status_id)
	var is_new_status := not target_statuses.has(key)
	var entry: Dictionary = target_statuses.get(key, {
		"target_ref": weakref(target),
		"id": status_id,
		"remaining": 0.0,
		"tick_remaining": 0.5,
		"tick_interval": 0.5,
		"stacks": 0,
		"max_stacks": 1,
		"damage_per_second": 0.0,
		"source_ref": weakref(source) if source != null else null,
		"source_id": source_id,
		"affinity": &"physical",
		"persistent": false,
		"context": {},
	})
	entry["target_ref"] = weakref(target)
	entry["remaining"] = maxf(
		float(entry.get("remaining", 0.0)),
		float(definition.get("duration", 0.0))
	)
	entry["tick_interval"] = maxf(
		float(definition.get("tick_interval", 0.5)),
		0.05
	)
	entry["tick_remaining"] = minf(
		float(entry.get("tick_remaining", entry["tick_interval"])),
		float(entry["tick_interval"])
	)
	entry["max_stacks"] = maxi(int(definition.get("max_stacks", 1)), 1)
	entry["stacks"] = mini(
		int(entry.get("stacks", 0))
		+ maxi(int(definition.get("stack_gain", 1)), 0),
		int(entry["max_stacks"])
	)
	entry["damage_per_second"] = maxf(
		float(entry.get("damage_per_second", 0.0)),
		float(definition.get("damage_per_second", 0.0))
	)
	entry["source_ref"] = weakref(source) if source != null else null
	entry["source_id"] = source_id
	entry["affinity"] = StringName(
		definition.get("affinity", &"physical")
	)
	entry["persistent"] = bool(definition.get("persistent", false))
	var merged_context := Dictionary(entry.get("context", {})).duplicate(true)
	merged_context.merge(
		Dictionary(definition.get("context", {})),
		true
	)
	entry["context"] = merged_context
	target_statuses[key] = entry
	active_statuses[target_id] = target_statuses
	target.set_meta("status_" + key, true)
	if is_new_status:
		_play_status_visual(target, status_id)


func _play_status_visual(target: Node2D, status_id: StringName) -> void:
	var effect_id := &""
	match status_id:
		&"burn": effect_id = &"status_burn"
		&"shock", &"grounded", &"polarized_scar": effect_id = &"status_shock"
	if effect_id.is_empty():
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null and visual_effects.has_method("play"):
		visual_effects.call("play", effect_id, target.global_position, 0.9)


func register_marker(
	target: Node2D,
	status_id: StringName,
	context: Dictionary = {}
) -> void:
	apply_status(target, {
		"id": status_id,
		"duration": INF,
		"persistent": true,
		"stack_gain": 1,
		"max_stacks": 1,
		"context": context,
	})


func has_status(target: Node, status_id: StringName) -> bool:
	if not is_instance_valid(target):
		return false
	var statuses: Dictionary = active_statuses.get(
		target.get_instance_id(),
		{}
	)
	return statuses.has(String(status_id))


func get_status(target: Node, status_id: StringName) -> Dictionary:
	if not is_instance_valid(target):
		return {}
	var statuses: Dictionary = active_statuses.get(
		target.get_instance_id(),
		{}
	)
	return Dictionary(statuses.get(String(status_id), {}))


func consume_stacks(
	target: Node,
	status_id: StringName,
	amount: int = -1
) -> int:
	if not is_instance_valid(target):
		return 0
	var target_id := target.get_instance_id()
	var statuses: Dictionary = active_statuses.get(target_id, {})
	var key := String(status_id)
	if not statuses.has(key):
		return 0
	var entry: Dictionary = statuses[key]
	var available := int(entry.get("stacks", 0))
	var consumed := available if amount < 0 else mini(available, amount)
	var remaining := available - consumed
	if remaining <= 0:
		_end_status(target_id, key, entry, &"consumed")
		statuses.erase(key)
	else:
		entry["stacks"] = remaining
		statuses[key] = entry
	if statuses.is_empty():
		active_statuses.erase(target_id)
	else:
		active_statuses[target_id] = statuses
	return consumed


func set_status_context_value(
	target: Node,
	status_id: StringName,
	key: StringName,
	value: Variant
) -> void:
	if not is_instance_valid(target):
		return
	var target_id := target.get_instance_id()
	var statuses: Dictionary = active_statuses.get(target_id, {})
	var status_key := String(status_id)
	if not statuses.has(status_key):
		return
	var entry: Dictionary = statuses[status_key]
	var context := Dictionary(entry.get("context", {}))
	context[key] = value
	entry["context"] = context
	statuses[status_key] = entry
	active_statuses[target_id] = statuses


func notify_target_killed(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	_end_target_statuses(target.get_instance_id(), &"killed")


func clear_all() -> void:
	for target_id in active_statuses.keys():
		_end_target_statuses(int(target_id), &"cleared")
	active_statuses.clear()


func _process(delta: float) -> void:
	# Combat simulation must be completely frozen by pause, level-up and organ
	# screens. This node lives on the root and therefore cannot rely on inherited
	# process mode alone.
	if get_tree().paused:
		return
	# Status end signals can synchronously remove a target while this loop is
	# running (notably chained fire deaths). Work on key snapshots and validate
	# every lookup again before touching the live dictionary.
	for target_id_variant in active_statuses.keys():
		var target_id := int(target_id_variant)
		if not active_statuses.has(target_id):
			continue
		var statuses: Dictionary = Dictionary(
			active_statuses.get(target_id, {})
		).duplicate()
		for key in statuses.keys():
			if not statuses.has(key):
				continue
			var entry: Dictionary = statuses[key]
			var target := _weak_node(entry.get("target_ref")) as Node2D
			if target == null or not is_instance_valid(target):
				statuses.erase(key)
				continue
			if target.get("is_dead") == true:
				_end_status(target_id, key, entry, &"killed")
				statuses.erase(key)
				continue
			if bool(entry.get("persistent", false)):
				continue
			entry["remaining"] = float(entry["remaining"]) - delta
			entry["tick_remaining"] = float(entry["tick_remaining"]) - delta
			if (
				float(entry.get("damage_per_second", 0.0)) > 0.0
				and float(entry["tick_remaining"]) <= 0.0
			):
				var interval := float(entry["tick_interval"])
				entry["tick_remaining"] += interval
				_apply_damage_tick(target, entry, interval)
			if float(entry["remaining"]) <= 0.0:
				_end_status(target_id, key, entry, &"expired")
				statuses.erase(key)
			else:
				statuses[key] = entry
		# A status_ended listener may already have cleared this target. Never
		# resurrect that removed entry with our local snapshot.
		if not active_statuses.has(target_id):
			continue
		if statuses.is_empty():
			active_statuses.erase(target_id)
		else:
			active_statuses[target_id] = statuses


func _apply_damage_tick(
	target: Node2D,
	entry: Dictionary,
	interval: float
) -> void:
	if combat_pipeline == null or not is_instance_valid(target):
		return
	var source := _weak_node(entry.get("source_ref"))
	var event := DamageEvent.create(
		target,
		float(entry["damage_per_second"])
		* interval
		* float(entry["stacks"]),
		source,
		StringName(entry["source_id"]),
		StringName(entry["affinity"])
	)
	event.damage_type = DamageEvent.DamageType.DAMAGE_OVER_TIME
	event.hit_role = DamageEvent.HitRole.STATUS_TICK
	event.can_trigger_procs = false
	event.play_hit_sound = false
	event.heavy_feedback = false
	event.tags = [&"status_tick", StringName(entry["id"])]
	combat_pipeline.call("apply_damage", event)


func _end_target_statuses(target_id: int, reason: StringName) -> void:
	var statuses: Dictionary = active_statuses.get(target_id, {})
	for key in statuses.keys():
		_end_status(target_id, key, statuses[key], reason)
	active_statuses.erase(target_id)


func _end_status(
	_target_id: int,
	key: String,
	entry: Dictionary,
	reason: StringName
) -> void:
	var target := _weak_node(entry.get("target_ref")) as Node2D
	var last_position := (
		target.global_position
		if is_instance_valid(target)
		else Vector2(entry.get("last_position", Vector2.ZERO))
	)
	if is_instance_valid(target):
		target.remove_meta("status_" + key)
	entry["last_position"] = last_position
	status_ended.emit(
		last_position,
		StringName(entry["id"]),
		Dictionary(entry.get("context", {})),
		reason
	)


func _weak_node(value: Variant) -> Node:
	var reference := value as WeakRef
	if reference == null:
		return null
	return reference.get_ref() as Node
