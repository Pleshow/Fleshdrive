class_name EnemySteering
extends RefCounted


const ENVIRONMENT_MASK: int = 1
const DEFAULT_LOOK_AHEAD: float = 82.0
const SPATIAL_CELL_SIZE: float = 128.0
const OBSTACLE_SAMPLE_FRAMES: int = 3
const SEPARATION_SAMPLE_FRAMES: int = 3

static var spatial_grid_frame: int = -1
static var spatial_grid: Dictionary = {}


static func resolve_direction(
	body: CharacterBody2D,
	desired_direction: Vector2,
	delta: float,
	separation_radius: float = 74.0,
	separation_weight: float = 1.35,
	flank_weight: float = 0.0,
	look_ahead: float = DEFAULT_LOOK_AHEAD
) -> Vector2:
	if desired_direction.is_zero_approx():
		return Vector2.ZERO
	var desired := desired_direction.normalized()
	var separation := _separation_direction(body, separation_radius)
	var tangent := Vector2(-desired.y, desired.x)
	var flank_sign := (
		-1.0 if body.get_instance_id() % 2 == 0 else 1.0
	)
	var obstacle_avoidance := _obstacle_avoidance(body, desired, look_ahead)
	var escape := _stuck_escape(body, desired, delta)
	return (
		desired
		+ separation * separation_weight
		+ tangent * flank_weight * flank_sign
		+ obstacle_avoidance * 1.65
		+ escape * 1.8
	).normalized()


static func has_clear_path(
	body: CharacterBody2D,
	target_position: Vector2
) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		body.global_position,
		target_position,
		ENVIRONMENT_MASK,
		[body.get_rid()]
	)
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func register_displacement_wall_impact(
	body: CharacterBody2D,
	impulse: Vector2
) -> Vector2:
	if body.get_slide_collision_count() <= 0 or impulse.length() < 250.0:
		return impulse
	var now := Time.get_ticks_msec()
	if now - int(body.get_meta("last_wall_impact_msec", -10000)) > 180:
		body.set_meta("last_wall_impact_msec", now)
		var visual_effects := body.get_tree().root.get_node_or_null("VisualEffects")
		if visual_effects != null:
			visual_effects.call(
				"play",
				&"kinetic_impact",
				body.global_position,
				0.48
			)
	var collision := body.get_slide_collision(0)
	if collision == null:
		return impulse * 0.35
	return impulse.slide(collision.get_normal()) * 0.42


static func get_death_tint(body: Node) -> Color:
	match StringName(body.get_meta("last_damage_affinity", &"physical")):
		&"electric": return Color(0.48, 0.9, 1.0, 1.0)
		&"fire": return Color(1.0, 0.48, 0.18, 1.0)
		&"telekinetic": return Color(0.82, 0.56, 1.0, 1.0)
	return Color.WHITE


static func _separation_direction(
	body: CharacterBody2D,
	radius: float
) -> Vector2:
	var physics_frame := Engine.get_physics_frames()
	var has_cached_separation := body.has_meta("steering_separation_direction")
	if (
		has_cached_separation
		and physics_frame % SEPARATION_SAMPLE_FRAMES
		!= body.get_instance_id() % SEPARATION_SAMPLE_FRAMES
	):
		return Vector2(body.get_meta(
			"steering_separation_direction",
			Vector2.ZERO
		))
	_rebuild_spatial_grid_if_needed(body.get_tree())
	var force := Vector2.ZERO
	var radius_squared := radius * radius
	var considered := 0
	var center_cell := _cell_for_position(body.global_position)
	var cell_radius := maxi(int(ceil(radius / SPATIAL_CELL_SIZE)), 1)
	for cell_y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for cell_x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			var occupants: Array = spatial_grid.get(Vector2i(cell_x, cell_y), [])
			for other_value in occupants:
				var other := other_value as Node2D
				if other == null or other == body or not is_instance_valid(other):
					continue
				var offset := body.global_position - other.global_position
				var distance_squared := offset.length_squared()
				if distance_squared <= 0.01 or distance_squared >= radius_squared:
					continue
				var distance := sqrt(distance_squared)
				var closeness := 1.0 - distance / radius
				force += offset / distance * closeness * closeness
				considered += 1
				if considered >= 18:
					return _cache_separation(body, force.limit_length(1.0))
	return _cache_separation(body, force.limit_length(1.0))


static func _cache_separation(
	body: CharacterBody2D,
	direction: Vector2
) -> Vector2:
	body.set_meta("steering_separation_direction", direction)
	return direction


static func _rebuild_spatial_grid_if_needed(tree: SceneTree) -> void:
	var physics_frame := Engine.get_physics_frames()
	if spatial_grid_frame == physics_frame:
		return
	spatial_grid_frame = physics_frame
	spatial_grid.clear()
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if (
			enemy == null
			or enemy.get("is_dead") == true
			or bool(enemy.get_meta("telekinetically_captured", false))
		):
			continue
		var cell := _cell_for_position(enemy.global_position)
		var occupants: Array = spatial_grid.get(cell, [])
		occupants.append(enemy)
		spatial_grid[cell] = occupants


static func _cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / SPATIAL_CELL_SIZE),
		floori(position.y / SPATIAL_CELL_SIZE)
	)


static func _obstacle_avoidance(
	body: CharacterBody2D,
	desired: Vector2,
	look_ahead: float = DEFAULT_LOOK_AHEAD
) -> Vector2:
	var physics_frame := Engine.get_physics_frames()
	var next_sample_frame := int(body.get_meta(
		"steering_obstacle_next_frame",
		-1
	))
	if physics_frame < next_sample_frame:
		return Vector2(body.get_meta(
			"steering_obstacle_avoidance",
			Vector2.ZERO
		))
	var sample_interval := 2 if look_ahead > 120.0 else OBSTACLE_SAMPLE_FRAMES
	body.set_meta(
		"steering_obstacle_next_frame",
		physics_frame + sample_interval
	)
	var query := PhysicsRayQueryParameters2D.create(
		body.global_position,
		body.global_position + desired * look_ahead,
		ENVIRONMENT_MASK,
		[body.get_rid()]
	)
	var hit := body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		body.set_meta("steering_obstacle_avoidance", Vector2.ZERO)
		return Vector2.ZERO
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.is_zero_approx():
		var fallback := Vector2(-desired.y, desired.x)
		body.set_meta("steering_obstacle_avoidance", fallback)
		return fallback
	var slide := desired.slide(normal).normalized()
	if slide.is_zero_approx():
		var sign_value := -1.0 if body.get_instance_id() % 2 == 0 else 1.0
		slide = Vector2(-desired.y, desired.x) * sign_value
	var avoidance := (slide + normal * 0.35).normalized()
	body.set_meta("steering_obstacle_avoidance", avoidance)
	return avoidance


static func _stuck_escape(
	body: CharacterBody2D,
	desired: Vector2,
	delta: float
) -> Vector2:
	var last_position: Vector2 = body.get_meta(
		"steering_last_position",
		body.global_position
	)
	var stuck_time := float(body.get_meta("steering_stuck_time", 0.0))
	var escape_time := float(body.get_meta("steering_escape_time", 0.0))
	if body.global_position.distance_squared_to(last_position) < 1.0:
		stuck_time += delta
	else:
		stuck_time = 0.0
	body.set_meta("steering_last_position", body.global_position)
	if stuck_time >= 0.42 and escape_time <= 0.0:
		escape_time = 0.72
		stuck_time = 0.0
		body.set_meta(
			"steering_escape_sign",
			-1.0 if randf() < 0.5 else 1.0
		)
	body.set_meta("steering_stuck_time", stuck_time)
	if escape_time <= 0.0:
		return Vector2.ZERO
	escape_time = maxf(escape_time - delta, 0.0)
	body.set_meta("steering_escape_time", escape_time)
	var sign_value := float(body.get_meta("steering_escape_sign", 1.0))
	return Vector2(-desired.y, desired.x) * sign_value
