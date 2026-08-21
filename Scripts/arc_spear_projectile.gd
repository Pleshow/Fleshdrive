class_name ArcSpearProjectile
extends Area2D


const PIXEL_EMISSIVE_SHADER := preload("res://Shaders/pixel_emissive.gdshader")

@export var move_speed: float = 720.0
@export var projectile_texture: Texture2D

@onready var sprite: AnimatedSprite2D = $Sprite

var direction: Vector2 = Vector2.RIGHT
var damage: float = 22.0
var remaining_distance: float = 650.0
var remaining_pierces: int = 2
var hit_enemy_ids: Dictionary = {}
var source_system: PlayerWeaponSystem
var finished := false


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = PIXEL_EMISSIVE_SHADER
	material.set_shader_parameter("force_electric_blue", true)
	sprite.material = material
	_configure_animation()
	_install_light()
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


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
		frame.region = Rect2(frame_index * 256, 0, 256, 256)
		frames.add_frame(&"flight", frame)
	sprite.sprite_frames = frames
	sprite.play(&"flight")


func _install_light() -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_light")):
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.58, 0.94, 1.0, 0.95),
		Color(0.08, 0.38, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 160
	texture.height = 160
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.name = "ArcSpearLight"
	light.texture = texture
	light.color = Color(0.32, 0.82, 1.0, 1.0)
	light.energy = 1.85
	light.texture_scale = 0.92
	light.shadow_enabled = false
	light.add_to_group("projectile_light")
	add_child(light)


func configure(
	shot_direction: Vector2,
	shot_damage: float,
	max_distance: float,
	pierce_count: int,
	owner_system: PlayerWeaponSystem = null,
	speed_multiplier: float = 1.0,
	width_multiplier: float = 1.0
) -> void:
	direction = shot_direction.normalized()
	damage = shot_damage
	remaining_distance = max_distance
	remaining_pierces = pierce_count
	source_system = owner_system
	move_speed *= speed_multiplier
	sprite.scale.y *= width_multiplier
	$CollisionShape2D.scale.y *= width_multiplier
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var travel := move_speed * delta
	global_position += direction * travel
	remaining_distance -= travel
	if remaining_distance <= 0.0:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if body.get("is_dead") == true:
		return

	var enemy_id := body.get_instance_id()
	if hit_enemy_ids.has(enemy_id):
		return
	hit_enemy_ids[enemy_id] = true

	if source_system != null and is_instance_valid(source_system):
		source_system.damage_enemy_for_build(
			body, damage, &"arc_spear",
			DamageEvent.HitRole.PRIMARY, true,
			ProcContext.new(1)
		)
		_play_impact(body.global_position)

	remaining_pierces -= 1
	if remaining_pierces <= 0:
		_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	if source_system != null and is_instance_valid(source_system):
		source_system.on_arc_projectile_finished(hit_enemy_ids.size())
	queue_free()


func _play_impact(position: Vector2) -> void:
	if not is_inside_tree():
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("play", &"electric_impact", position, 1.15)
