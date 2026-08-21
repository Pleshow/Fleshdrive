class_name ReadablePlayerProjectile
extends Node2D

const PIXEL_EMISSIVE_SHADER := preload("res://Shaders/pixel_emissive.gdshader")

var target_ref: WeakRef
var last_target_position := Vector2.ZERO
var speed: float = 720.0
var lifetime: float = 1.2
var hit_radius: float = 22.0
var hit_callback: Callable
var authored_electric_vfx: AnimatedSprite2D


func configure(
	target: Node2D,
	projectile_speed: float,
	frames: SpriteFrames,
	projectile_scale: float,
	callback: Callable,
	light_color: Color = Color(0.45, 0.82, 1.0, 1.0)
) -> void:
	target_ref = weakref(target)
	last_target_position = target.global_position
	speed = projectile_speed
	lifetime = clampf(
		global_position.distance_to(last_target_position) / maxf(speed, 1.0)
		+ 0.9,
		1.25,
		2.8
	)
	hit_callback = callback
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"flight"
	sprite.scale = Vector2.ONE * projectile_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 18
	var electric_projectile := light_color.b > light_color.r * 1.15
	if electric_projectile:
		var material := ShaderMaterial.new()
		material.shader = PIXEL_EMISSIVE_SHADER
		material.set_shader_parameter("force_electric_blue", true)
		sprite.material = material
	add_child(sprite)
	sprite.play(&"flight")
	if electric_projectile:
		_install_electric_asset(projectile_scale)
	_install_projectile_light(light_color, projectile_scale)


func _install_electric_asset(projectile_scale: float) -> void:
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return
	authored_electric_vfx = visual_effects.call(
		"play_attached", &"projectile_lightning_loop", self,
		Vector2.ZERO, clampf(projectile_scale * 1.15, 0.55, 1.05), 0.0
	) as AnimatedSprite2D
	if authored_electric_vfx != null:
		authored_electric_vfx.name = "ElectricProjectileVFX"
		authored_electric_vfx.z_index = 19


func _exit_tree() -> void:
	if not is_instance_valid(authored_electric_vfx):
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("stop_effect", authored_electric_vfx)


func _install_projectile_light(color: Color, projectile_scale: float) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_light")):
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.95),
		Color(color.r, color.g, color.b, 0.38),
		Color(color.r, color.g, color.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.name = "ProjectileLight"
	light.texture = texture
	light.color = color
	light.energy = clampf(1.1 + projectile_scale * 1.8, 1.2, 2.0)
	light.texture_scale = clampf(0.62 + projectile_scale, 0.70, 1.1)
	light.shadow_enabled = false
	light.add_to_group("projectile_light")
	add_child(light)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	var target := target_ref.get_ref() as Node2D if target_ref != null else null
	if is_instance_valid(target) and target.get("is_dead") != true:
		last_target_position = target.global_position
	var offset := last_target_position - global_position
	if offset.length() <= hit_radius:
		if is_instance_valid(target) and target.get("is_dead") != true:
			hit_callback.call(target)
		queue_free()
		return
	if lifetime <= 0.0:
		queue_free()
		return
	var travel := minf(speed * delta, offset.length())
	var direction := offset.normalized()
	rotation = direction.angle()
	global_position += direction * travel
