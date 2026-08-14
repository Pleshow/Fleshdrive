extends Node


const DEFAULT_LIMIT := 64
var pools: Dictionary = {}
var active_by_key: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or not is_instance_valid(parent):
		return null
	var key := scene.resource_path
	var pool: Array = pools.get(key, [])
	var instance: Node
	while not pool.is_empty():
		instance = pool.pop_back() as Node
		if is_instance_valid(instance):
			break
		instance = null
	pools[key] = pool
	if instance == null:
		instance = scene.instantiate()
		instance.set_meta("runtime_pool_key", key)
		parent.add_child(instance)
		_capture_defaults(instance)
	else:
		instance.reparent(parent)
	_restore_defaults(instance)
	_restore_runtime_groups(instance)
	if instance.has_method("prepare_for_reuse"):
		instance.call("prepare_for_reuse")
	active_by_key[key] = int(active_by_key.get(key, 0)) + 1
	return instance


func release(instance: Node) -> void:
	if not is_instance_valid(instance) or bool(instance.get_meta("runtime_pool_pending", false)):
		return
	instance.set_meta("runtime_pool_pending", true)
	_release_deferred.call_deferred(instance)


func _release_deferred(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	var key := String(instance.get_meta("runtime_pool_key", ""))
	instance.set_meta("runtime_pool_pending", false)
	if key.is_empty():
		instance.queue_free()
		return
	if instance.has_method("prepare_for_pool"):
		instance.call("prepare_for_pool")
	_remove_runtime_groups(instance)
	instance.hide()
	instance.set_process(false)
	instance.set_physics_process(false)
	if instance is CollisionObject2D:
		(instance as CollisionObject2D).collision_layer = 0
		(instance as CollisionObject2D).collision_mask = 0
	instance.reparent(self)
	active_by_key[key] = maxi(int(active_by_key.get(key, 1)) - 1, 0)
	var pool: Array = pools.get(key, [])
	var limit := DEFAULT_LIMIT
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null:
		limit = int(budget.call("get_pool_limit", key, DEFAULT_LIMIT))
	if pool.size() >= limit:
		instance.queue_free()
		return
	pool.append(instance)
	pools[key] = pool


func flush() -> void:
	for pool_value in pools.values():
		for instance in Array(pool_value):
			if is_instance_valid(instance):
				instance.queue_free()
	pools.clear()
	active_by_key.clear()


func get_snapshot() -> Dictionary:
	var pooled := 0
	for pool_value in pools.values():
		pooled += Array(pool_value).size()
	return {"pooled": pooled, "active": active_by_key.duplicate(true)}


func _capture_defaults(instance: Node) -> void:
	instance.set_meta("runtime_pool_process_mode", instance.process_mode)
	var runtime_groups: Array[StringName] = []
	for group: StringName in instance.get_groups():
		# Engine/editor-only groups are not part of gameplay identity and should
		# never be restored manually.
		if not String(group).begins_with("_"):
			runtime_groups.append(group)
	instance.set_meta("runtime_pool_groups", runtime_groups)
	if instance is CollisionObject2D:
		instance.set_meta("runtime_pool_collision_layer", (instance as CollisionObject2D).collision_layer)
		instance.set_meta("runtime_pool_collision_mask", (instance as CollisionObject2D).collision_mask)


func _restore_defaults(instance: Node) -> void:
	instance.show()
	instance.process_mode = int(instance.get_meta("runtime_pool_process_mode", Node.PROCESS_MODE_INHERIT))
	instance.set_process(true)
	instance.set_physics_process(true)
	if instance is CollisionObject2D:
		(instance as CollisionObject2D).collision_layer = int(instance.get_meta("runtime_pool_collision_layer", 0))
		(instance as CollisionObject2D).collision_mask = int(instance.get_meta("runtime_pool_collision_mask", 0))


func _remove_runtime_groups(instance: Node) -> void:
	var groups: Array = Array(instance.get_meta("runtime_pool_groups", []))
	# Older pooled instances can reach this path after a hot reload. Capture
	# their current gameplay groups once before removing them.
	if groups.is_empty():
		for group: StringName in instance.get_groups():
			if not String(group).begins_with("_"):
				groups.append(group)
		instance.set_meta("runtime_pool_groups", groups)
	for group in groups:
		var group_name := StringName(group)
		if instance.is_in_group(group_name):
			instance.remove_from_group(group_name)


func _restore_runtime_groups(instance: Node) -> void:
	for group in Array(instance.get_meta("runtime_pool_groups", [])):
		var group_name := StringName(group)
		if not instance.is_in_group(group_name):
			instance.add_to_group(group_name)
