class_name SpitterProjectile
extends Area2D


const COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/enemy_combat_vfx_atlas.png"
)

@export var move_speed: float = 320.0
@export var damage: float = 9.0
@export var maximum_lifetime: float = 5.0

@onready var projectile_sprite: AnimatedSprite2D = $ProjectileSprite
@onready var impact_animation: AnimatedSprite2D = $ImpactAnimation
@onready var acid_decal: AnimatedSprite2D = $AcidDecal
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

var direction: Vector2 = Vector2.RIGHT
var exploded: bool = false
var reflected: bool = false
var projectile_light: PointLight2D


func _ready() -> void:
	_install_projectile_light()
	projectile_sprite.sprite_frames = _make_poison_orb_animation()
	projectile_sprite.scale = Vector2.ONE
	projectile_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var projectile_material := CanvasItemMaterial.new()
	projectile_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	projectile_sprite.material = projectile_material
	impact_animation.sprite_frames = _make_animation(
		COMBAT_TEXTURE,
		0,
		&"impact",
		false,
		18.0
	)
	acid_decal.sprite_frames = _make_animation(
		COMBAT_TEXTURE,
		1,
		&"puddle",
		true,
		7.0
	)
	if MinimalistVisualProfile.is_active(get_tree()):
		var pixel_shader := load("res://Shaders/pixel_emissive.gdshader") as Shader
		for effect_sprite in [impact_animation, acid_decal]:
			var pixel_material := ShaderMaterial.new()
			pixel_material.shader = pixel_shader
			effect_sprite.material = pixel_material
			effect_sprite.scale = Vector2.ONE * 0.20
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(explode)
	lifetime_timer.start(maximum_lifetime)
	impact_animation.hide()
	acid_decal.hide()
	projectile_sprite.play(&"flight")


func _physics_process(delta: float) -> void:
	if exploded:
		return

	global_position += direction * move_speed * delta
	rotation = direction.angle()


func configure(
	travel_direction: Vector2,
	projectile_damage: float,
	projectile_speed: float
) -> void:
	direction = travel_direction.normalized()
	damage = projectile_damage
	move_speed = projectile_speed


func prepare_for_reuse() -> void:
	exploded = false
	reflected = false
	rotation = 0.0
	collision_mask = 5
	set_physics_process(true)
	set_deferred("monitoring", true)
	collision_shape.set_deferred("disabled", false)
	projectile_sprite.modulate = Color.WHITE
	projectile_sprite.show()
	if is_instance_valid(projectile_light):
		projectile_light.show()
	projectile_sprite.play(&"flight")
	impact_animation.hide()
	acid_decal.hide()
	acid_decal.modulate = Color.WHITE
	lifetime_timer.start(maximum_lifetime)


func _on_body_entered(body: Node2D) -> void:
	if exploded:
		return

	if reflected and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		explode()
		return
	if body.is_in_group("enemies"):
		return

	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, self, &"spitter_projectile", DamageEvent.DamageType.PROJECTILE)

	explode()


func reverse_to_nearest_enemy(damage_multiplier: float = 1.0) -> bool:
	if exploded or reflected:
		return false
	var target := _nearest_enemy()
	if target == null:
		return false
	reflected = true
	direction = global_position.direction_to(target.global_position)
	damage *= damage_multiplier
	move_speed *= 1.15
	collision_mask = 3
	projectile_sprite.modulate = Color("0ce6f2")
	if is_instance_valid(projectile_light):
		projectile_light.color = Color("0098db")
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


func explode() -> void:
	if exploded:
		return

	exploded = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	projectile_sprite.hide()
	if is_instance_valid(projectile_light):
		projectile_light.hide()
	acid_decal.show()
	acid_decal.play(&"puddle")
	impact_animation.show()
	impact_animation.play(&"impact")
	play_sound(&"spitter_impact", -6.0, 0.07)

	await impact_animation.animation_finished
	impact_animation.hide()

	var fade_tween := create_tween()
	fade_tween.tween_property(acid_decal, "modulate:a", 0.0, 1.15)
	await fade_tween.finished
	var projectile_pool := get_tree().root.get_node_or_null(
		"ProjectilePool"
	)
	if projectile_pool != null:
		projectile_pool.call("release", self)
	else:
		queue_free()


func _install_projectile_light() -> void:
	projectile_light = get_node_or_null("ProjectileLight") as PointLight2D
	if projectile_light != null:
		projectile_light.add_to_group("projectile_light")
		return
	projectile_light = PointLight2D.new()
	projectile_light.name = "ProjectileLight"
	projectile_light.add_to_group("projectile_light")
	projectile_light.texture = _make_pixel_light_texture()
	projectile_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile_light.color = Color("ff0546")
	projectile_light.energy = 0.62
	projectile_light.texture_scale = 1.1
	projectile_light.shadow_enabled = false
	add_child(projectile_light)
	if MinimalistVisualProfile.is_active(get_tree()):
		projectile_light.energy = 0.34


func _make_poison_orb_animation() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"flight")
	frames.set_animation_loop(&"flight", true)
	frames.set_animation_speed(&"flight", 10.0)
	var pattern := [
		"............",
		"....dddd....",
		"..ddggggdd..",
		".dggLLLLggd.",
		"dggLLLLLLggd",
		"dggLLWWLgggd",
		"dggLLLLLLggd",
		".dggLLLLggd.",
		"..ddggggdd..",
		"....dddd....",
		"............",
		"............",
	]
	for animation_frame in range(4):
		var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(pattern.size()):
			for x in range(pattern[y].length()):
				var symbol: String = String(pattern[y]).substr(x, 1)
				var color := Color.TRANSPARENT
				match symbol:
					"d":
						color = Color("450327")
					"g":
						color = Color("660f31")
					"L":
						color = Color("9c173b")
					"W":
						color = (
							Color("ff0546")
							if (x + animation_frame) % 3 != 0
							else Color("9c173b")
						)
				if color.a > 0.0:
					image.set_pixel(x, y, color)
		frames.add_frame(&"flight", ImageTexture.create_from_image(image))
	return frames


func _make_pixel_light_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(16):
		for x in range(16):
			var ring := maxi(absi(x - 7), absi(y - 7))
			var alpha := 0.0
			if ring <= 2:
				alpha = 0.88
			elif ring <= 4:
				alpha = 0.42
			elif ring <= 6:
				alpha = 0.14
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _make_animation(
	texture: Texture2D,
	row: int,
	animation_name: StringName,
	should_loop: bool,
	fps: float,
	frame_size: int = 256
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, should_loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			frame_index * frame_size,
			row * frame_size,
			frame_size,
			frame_size
		)
		frames.add_frame(animation_name, frame)
	return frames


func play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float
) -> void:
	if not is_inside_tree():
		return
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			sound_id,
			volume_db,
			pitch_variation,
			&"SFX"
		)
