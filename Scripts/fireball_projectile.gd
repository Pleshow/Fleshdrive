class_name FireballProjectile
extends Area2D


@export var move_speed: float = 205.0
@export var turn_speed: float = 3.2
@export var projectile_texture: Texture2D

@onready var sprite: AnimatedSprite2D = $Sprite

var direction := Vector2.RIGHT
var damage := 8.0
var burn_damage := 2.0
var burn_duration := 3.2
var remaining_distance := 720.0
var source_player: Koda
var tracked_target: WeakRef
var impacted := false


func _ready() -> void:
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = material
	_configure_animation()
	_install_light()
	body_entered.connect(_on_body_entered)


func configure(
	player: Koda,
	target: Node2D,
	shot_direction: Vector2,
	shot_damage: float,
	shot_burn_damage: float,
	shot_burn_duration: float,
	max_distance: float
) -> void:
	source_player = player
	tracked_target = weakref(target)
	direction = shot_direction.normalized()
	damage = shot_damage
	burn_damage = shot_burn_damage
	burn_duration = shot_burn_duration
	remaining_distance = max_distance
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if impacted:
		return
	var target := tracked_target.get_ref() as Node2D if tracked_target != null else null
	if is_instance_valid(target) and target.get("is_dead") != true:
		var desired := global_position.direction_to(target.global_position)
		direction = direction.rotated(
			clampf(direction.angle_to(desired), -turn_speed * delta, turn_speed * delta)
		).normalized()
	rotation = direction.angle()
	var travel := move_speed * delta
	global_position += direction * travel
	remaining_distance -= travel
	if remaining_distance <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if impacted or not body.is_in_group("enemies") or body.get("is_dead") == true:
		return
	impacted = true
	if is_instance_valid(source_player):
		source_player._deal_base_damage(
			body,
			damage,
			&"base_fireball",
			FleshdriveCatalog.FIRE,
			ProcContext.new(2)
		)
		if source_player.weapon_system != null:
			source_player.weapon_system.apply_burn(
				body,
				burn_damage,
				burn_duration,
				1
			)
		source_player.play_combat_vfx(&"fire_impact", global_position, 0.68)
		source_player.play_combat_vfx(
			&"dash_smoke_end", global_position, 0.28, direction.angle()
		)
	queue_free()


func _configure_animation() -> void:
	if projectile_texture == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"flight")
	frames.set_animation_loop(&"flight", true)
	frames.set_animation_speed(&"flight", 16.0)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = projectile_texture
		frame.region = Rect2(frame_index * 128, 0, 128, 96)
		frames.add_frame(&"flight", frame)
	sprite.sprite_frames = frames
	sprite.play(&"flight")


func _install_light() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.42, 0.08, 0.9),
		Color(1.0, 0.12, 0.01, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 96
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.texture = texture
	light.color = Color(1.0, 0.32, 0.06)
	light.energy = 1.45
	light.texture_scale = 0.78
	light.shadow_enabled = false
	light.add_to_group("projectile_light")
	add_child(light)
