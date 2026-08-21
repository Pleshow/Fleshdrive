class_name BossProjectile
extends Area2D


const PROJECTILE_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/enemy_projectiles_atlas.png"
)

@export var move_speed: float = 420.0
@export var damage: float = 14.0
@export var maximum_lifetime: float = 5.0

@onready var projectile_sprite: AnimatedSprite2D = $ProjectileSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var direction: Vector2 = Vector2.RIGHT
var charged: bool = false
var expired: bool = false
var reflected: bool = false


func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	projectile_sprite.material = material
	var light := get_node_or_null("ProjectileLight") as PointLight2D
	if light != null:
		light.add_to_group("projectile_light")
	projectile_sprite.sprite_frames = _make_animations()
	projectile_sprite.play(&"charged" if charged else &"normal")
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(expire)
	lifetime_timer.start(maximum_lifetime)


func _physics_process(delta: float) -> void:
	if expired:
		return

	global_position += direction * move_speed * delta
	rotation = direction.angle()


func configure(
	travel_direction: Vector2,
	projectile_damage: float,
	projectile_speed: float,
	is_charged: bool = false
) -> void:
	direction = travel_direction.normalized()
	damage = projectile_damage
	move_speed = projectile_speed
	charged = is_charged
	if is_node_ready():
		projectile_sprite.play(&"charged" if charged else &"normal")

	if charged:
		projectile_sprite.scale = Vector2.ONE * 0.20
		var circle_shape := collision_shape.shape as CircleShape2D
		if circle_shape != null:
			circle_shape.radius = 18.0
	else:
		projectile_sprite.scale = Vector2.ONE * 0.14
		var circle_shape := collision_shape.shape as CircleShape2D
		if circle_shape != null:
			circle_shape.radius = 12.0


func prepare_for_reuse() -> void:
	expired = false
	reflected = false
	charged = false
	rotation = 0.0
	collision_mask = 5
	set_physics_process(true)
	set_deferred("monitoring", true)
	collision_shape.set_deferred("disabled", false)
	projectile_sprite.modulate = Color.WHITE
	projectile_sprite.scale = Vector2.ONE * 0.14
	projectile_sprite.show()
	projectile_sprite.play(&"normal")
	lifetime_timer.start(maximum_lifetime)


func _on_body_entered(body: Node2D) -> void:
	if expired:
		return

	if reflected and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		expire()
		return
	if body.is_in_group("enemies"):
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, self, &"visceral_warden_projectile", DamageEvent.DamageType.PROJECTILE)

	expire()


func reverse_to_nearest_enemy(damage_multiplier: float = 1.0) -> bool:
	# Charged core shots are deliberately non-reversible. Their brighter
	# silhouette tells telekinetic players to dodge instead of countering.
	if expired or reflected or charged:
		return false
	var target := _nearest_enemy()
	if target == null:
		return false
	reflected = true
	direction = global_position.direction_to(target.global_position)
	damage *= damage_multiplier
	move_speed *= 1.12
	collision_mask = 3
	projectile_sprite.modulate = Color(0.82, 0.5, 1.0, 1.0)
	return true


func _nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or enemy.get("is_dead") == true:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func expire() -> void:
	if expired:
		return

	expired = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	projectile_sprite.hide()

	var visual_effects := get_tree().root.get_node_or_null(
		"VisualEffects"
	)
	if visual_effects != null:
		visual_effects.call(
			"play",
			&"boss_charge_impact",
			global_position,
			1.0 if charged else 0.65
		)

	var projectile_pool := get_tree().root.get_node_or_null(
		"ProjectilePool"
	)
	if projectile_pool != null:
		projectile_pool.call("release", self)
	else:
		queue_free()


func _make_animations() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name in [&"normal", &"charged"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, 12.0)
	var animation_rows := {
		&"normal": 1,
		&"charged": 2,
	}
	for animation_name: StringName in animation_rows:
		var row := int(animation_rows[animation_name])
		for frame_index in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = PROJECTILE_TEXTURE
			frame.region = Rect2(
				frame_index * 256,
				row * 256,
				256,
				256
			)
			frames.add_frame(animation_name, frame)
	return frames
