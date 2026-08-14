extends Node


signal transition_started(id: StringName, epoch: int)
signal transition_finished(id: StringName, epoch: int)

var transition_active: bool = false
var transition_id: StringName = &""
var epoch: int = 0


func begin_transition(id: StringName) -> int:
	if transition_active:
		return -1
	transition_active = true
	transition_id = id
	epoch += 1
	transition_started.emit(id, epoch)
	return epoch


func finish_transition(token: int) -> bool:
	if not transition_active or token != epoch:
		return false
	var finished_id := transition_id
	transition_active = false
	transition_id = &""
	transition_finished.emit(finished_id, token)
	return true


func cancel_transients() -> void:
	epoch += 1
	transition_active = false
	transition_id = &""
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.call("clear_transient_state")
	var projectile_pool := get_tree().root.get_node_or_null("ProjectilePool")
	if projectile_pool != null and projectile_pool.has_method("flush"):
		projectile_pool.call("flush")
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and runtime_pool.has_method("flush"):
		runtime_pool.call("flush")
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null and visual_effects.has_method("clear_all"):
		visual_effects.call("clear_all")
	for group_name in [
		&"runtime_transient",
		&"enemy_projectiles",
		&"player_projectiles",
		&"damage_numbers",
	]:
		for transient in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(transient) and not transient.is_queued_for_deletion():
				transient.queue_free()


func is_token_current(token: int) -> bool:
	return token == epoch
