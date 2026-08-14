extends Node


const MAXIMUM_POOLED_PER_SCENE: int = 48

var pools: Dictionary = {}


func acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		return null
	var key := scene.resource_path
	var pool: Array = pools.get(key, [])
	var projectile: Node
	while not pool.is_empty():
		projectile = pool.pop_back() as Node
		if is_instance_valid(projectile):
			break
		projectile = null
	pools[key] = pool
	if projectile == null:
		projectile = scene.instantiate()
		projectile.set_meta("projectile_pool_key", key)
		parent.add_child(projectile)
	else:
		projectile.reparent(parent)
		projectile.show()
	if projectile.has_method("prepare_for_reuse"):
		projectile.call("prepare_for_reuse")
	return projectile


func release(projectile: Node) -> void:
	if not is_instance_valid(projectile):
		return
	if bool(projectile.get_meta("projectile_pool_pending", false)):
		return
	projectile.set_meta("projectile_pool_pending", true)
	_release_deferred.call_deferred(projectile)


func _release_deferred(projectile: Node) -> void:
	if not is_instance_valid(projectile):
		return
	var key := String(projectile.get_meta("projectile_pool_key", ""))
	projectile.set_meta("projectile_pool_pending", false)
	if key.is_empty():
		projectile.queue_free()
		return
	var pool: Array = pools.get(key, [])
	var pool_limit := MAXIMUM_POOLED_PER_SCENE
	var database := get_tree().root.get_node_or_null("BalanceDatabase")
	if database != null:
		pool_limit = int(database.call(
			"get_budget",
			"pooled_per_scene",
			float(pool_limit)
		))
	if pool.size() >= pool_limit:
		projectile.queue_free()
		return
	projectile.hide()
	projectile.reparent(self)
	pool.append(projectile)
	pools[key] = pool


func get_pooled_count(scene_path: String) -> int:
	var pool: Array = pools.get(scene_path, [])
	return pool.size()


func flush() -> void:
	for pool_value in pools.values():
		for projectile in Array(pool_value):
			if is_instance_valid(projectile):
				projectile.queue_free()
	pools.clear()
