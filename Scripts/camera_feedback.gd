class_name CameraFeedback
extends Camera2D


@export var trauma_decay: float = 1.9
@export var maximum_offset: Vector2 = Vector2(13.0, 9.0)
@export var maximum_rotation: float = 0.012
@export var base_offset: Vector2 = Vector2.ZERO
@export var spring_speed: float = 4.2
@export var movement_look_ahead: float = 38.0
@export var aim_look_ahead: float = 32.0
@export var maximum_look_ahead: float = 54.0

var trauma: float = 0.0
var look_offset: Vector2 = Vector2.ZERO
var cinematic_offset: Vector2 = Vector2.ZERO
var cinematic_active: bool = false


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_look_ahead(delta)
	trauma = maxf(trauma - trauma_decay * delta, 0.0)

	if trauma <= 0.0:
		offset = base_offset + look_offset + cinematic_offset
		rotation = 0.0
		return

	var shake_power := trauma * trauma
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var shake_scale := float(settings.screen_shake_intensity) if settings != null else 1.0
	offset = base_offset + look_offset + cinematic_offset + Vector2(
		randf_range(-maximum_offset.x, maximum_offset.x),
		randf_range(-maximum_offset.y, maximum_offset.y)
	) * shake_power * shake_scale
	rotation = randf_range(
		-maximum_rotation,
		maximum_rotation
	) * shake_power * shake_scale


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func add_trauma_profile(profile: StringName) -> void:
	var profiles := {
		&"hit": 0.16,
		&"dash": 0.11,
		&"explosion": 0.34,
		&"boss_attack": 0.48,
		&"boss_death": 0.82,
	}
	add_trauma(float(profiles.get(profile, 0.16)))


func play_boss_intro(target: Node2D, hold_seconds: float = 0.55) -> void:
	if cinematic_active or not is_instance_valid(target):
		return
	cinematic_active = true
	var parent_body := get_parent() as Node2D
	if parent_body == null:
		cinematic_active = false
		return
	var target_offset := (
		target.global_position - parent_body.global_position
	).limit_length(360.0)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "cinematic_offset", target_offset, 0.38)
	tween.tween_interval(hold_seconds)
	tween.tween_property(self, "cinematic_offset", Vector2.ZERO, 0.48)
	await tween.finished
	cinematic_active = false


func _update_look_ahead(delta: float) -> void:
	if cinematic_active:
		look_offset = look_offset.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
		return
	var parent_body := get_parent() as CharacterBody2D
	if parent_body == null:
		return
	var movement_vector := parent_body.velocity.normalized() * movement_look_ahead
	var viewport_center := get_viewport_rect().size * 0.5
	var mouse_vector := get_viewport().get_mouse_position() - viewport_center
	var aim_vector := Vector2.ZERO
	if mouse_vector.length() > 90.0:
		aim_vector = mouse_vector.normalized() * aim_look_ahead
	var target := (movement_vector + aim_vector).limit_length(maximum_look_ahead)
	look_offset = look_offset.lerp(target, 1.0 - exp(-spring_speed * delta))
