class_name MagmaSpearProjectile
extends Area2D


@export var move_speed: float = 345.0
@export var projectile_texture: Texture2D

@onready var sprite: AnimatedSprite2D = $Sprite

var direction := Vector2.RIGHT
var damage := 24.0
var burn_damage := 5.0
var burn_duration := 5.0
var remaining_distance := 760.0
var source_system: PlayerWeaponSystem
var hit_enemy_ids: Dictionary = {}
var finished := false


func _ready() -> void:
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = material
	var light := get_node_or_null("Glow") as PointLight2D
	if light != null:
		light.add_to_group("projectile_light")
	_configure_animation()
	_install_light_texture()
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


func configure(
	shot_direction: Vector2,
	shot_damage: float,
	shot_burn_damage: float,
	shot_burn_duration: float,
	max_distance: float,
	owner_system: PlayerWeaponSystem
) -> void:
	direction = shot_direction.normalized()
	damage = shot_damage
	burn_damage = shot_burn_damage
	burn_duration = shot_burn_duration
	remaining_distance = max_distance
	source_system = owner_system
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if finished:
		return
	var travel := move_speed * delta
	var start := global_position
	var destination := start + direction * travel
	_sweep_segment(start, destination)
	if finished:
		return
	global_position = destination
	remaining_distance -= travel
	if remaining_distance <= 0.0:
		_finish()


func _sweep_segment(start: Vector2, destination: Vector2) -> void:
	# Area overlap events can tunnel at projectile speed. Sweep the complete
	# travelled segment and resolve every enemy before the first wall.
	var segment := destination - start
	if segment.length_squared() <= 0.01:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(segment.length() + 28.0, 28.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(
		segment.angle(),
		start + segment * 0.5
	)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 64)
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_node := a.get("collider") as Node2D
		var b_node := b.get("collider") as Node2D
		if a_node == null:
			return false
		if b_node == null:
			return true
		return direction.dot(a_node.global_position - start) < direction.dot(b_node.global_position - start)
	)
	for hit in hits:
		var collider := hit.get("collider") as Node2D
		if not is_instance_valid(collider) or collider == self:
			continue
		if collider.is_in_group("enemies"):
			_hit_enemy(collider)
			continue
		_finish()
		return


func _on_body_entered(body: Node2D) -> void:
	if finished:
		return
	if body.is_in_group("enemies"):
		_hit_enemy(body)
		return
	# World geometry is collision layer 1. The spear pierces creatures but is
	# consumed by the first real obstacle it reaches.
	_finish()


func _hit_enemy(body: Node2D) -> void:
	if body.get("is_dead") == true:
		return
	var enemy_id := body.get_instance_id()
	if hit_enemy_ids.has(enemy_id):
		return
	hit_enemy_ids[enemy_id] = true
	if not is_instance_valid(source_system):
		return
	source_system.damage_enemy_for_build(
		body,
		damage,
		&"magma_spear",
		DamageEvent.HitRole.PRIMARY,
		true,
		ProcContext.new(1)
	)
	source_system.apply_burn(body, burn_damage, burn_duration, 2)
	source_system.play_projectile_impact(
		&"magma_spear_impact",
		body.global_position,
		0.74,
		direction.angle()
	)


func _finish() -> void:
	if finished:
		return
	finished = true
	queue_free()


func _configure_animation() -> void:
	if projectile_texture == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"flight")
	frames.set_animation_loop(&"flight", true)
	frames.set_animation_speed(&"flight", 14.0)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = projectile_texture
		frame.region = Rect2(frame_index * 192, 0, 192, 96)
		frames.add_frame(&"flight", frame)
	sprite.sprite_frames = frames
	sprite.play(&"flight")


func _install_light_texture() -> void:
	var light := get_node_or_null("Glow") as PointLight2D
	if light == null:
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.22, 0.025, 0.95),
		Color(1.0, 0.03, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	light.texture = texture
