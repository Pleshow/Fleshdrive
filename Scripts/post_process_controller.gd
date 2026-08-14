class_name PostProcessController
extends ColorRect


@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.68
@export var vignette_follows_player: bool = true

@onready var shader_material: ShaderMaterial = material as ShaderMaterial

var vignette_target: Node2D
var boss_reveal_target: Node2D
var vignette_suppressed: bool = false
var minimalist_pixel_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shader_material = material.duplicate() as ShaderMaterial
	material = shader_material
	_apply_vignette_strength()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	settings.visual_settings_changed.connect(_apply_settings)
	_apply_settings()


func _process(_delta: float) -> void:
	if not vignette_follows_player or shader_material == null:
		return
	if not is_instance_valid(vignette_target):
		vignette_target = get_tree().get_first_node_in_group(
			"player"
		) as Node2D
	if not is_instance_valid(vignette_target):
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_position := (
		get_viewport().get_canvas_transform()
		* vignette_target.global_position
	)
	shader_material.set_shader_parameter(
		"vignette_center",
		Vector2(
			screen_position.x / viewport_size.x,
			screen_position.y / viewport_size.y
		)
	)
	if not is_instance_valid(boss_reveal_target):
		boss_reveal_target = get_tree().get_first_node_in_group("boss") as Node2D
	var reveal_strength := 0.0
	if is_instance_valid(boss_reveal_target) and boss_reveal_target.get("is_dead") != true:
		var boss_screen := get_viewport().get_canvas_transform() * boss_reveal_target.global_position
		shader_material.set_shader_parameter(
			"boss_reveal_center",
			Vector2(boss_screen.x / viewport_size.x, boss_screen.y / viewport_size.y)
		)
		reveal_strength = 1.0
	shader_material.set_shader_parameter("boss_reveal_strength", reveal_strength)


func set_vignette_suppressed(suppressed: bool) -> void:
	vignette_suppressed = suppressed
	_apply_vignette_strength()


func set_minimalist_pixel_mode(enabled: bool) -> void:
	minimalist_pixel_mode = enabled
	_apply_vignette_strength()
	_apply_settings()


func _apply_vignette_strength() -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter(
		"vignette_strength",
		0.0 if vignette_suppressed else (
			minf(vignette_strength, 0.42)
			if minimalist_pixel_mode
			else vignette_strength
		)
	)


func _apply_settings() -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null or shader_material == null:
		return
	shader_material.set_shader_parameter(
		"crt_intensity",
		minf(settings.crt_intensity, 0.08)
	)
	shader_material.set_shader_parameter(
		"bloom_intensity",
		0.0
	)
	shader_material.set_shader_parameter(
		"chromatic_aberration",
		0.0
	)
