class_name TargetingService
extends RefCounted


var tree: SceneTree


func setup(scene_tree: SceneTree) -> void:
	tree = scene_tree


func living_enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if tree == null:
		return result
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if (
			enemy == null
			or not is_instance_valid(enemy)
			or enemy.get("is_dead") == true
		):
			continue
		result.append(enemy)
	return result


func in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_squared := radius * radius
	for enemy in living_enemies():
		if center.distance_squared_to(enemy.global_position) <= radius_squared:
			result.append(enemy)
	return result


func nearest(
	origin: Vector2,
	radius: float,
	limit: int
) -> Array[Node2D]:
	var candidates := in_radius(origin, radius)
	candidates.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return origin.distance_squared_to(a.global_position) < (
				origin.distance_squared_to(b.global_position)
			)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates
