extends CanvasLayer

const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const QUANTIZE_SHADER := preload("res://Shaders/ink_crimson_quantize.gdshader")

var screen_filter: ColorRect
var enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Quantize the rendered world, never the interface. Gameplay post-process is
	# on layer 100, transient arena banners start at 109 and the HUD starts at
	# 110. Keeping this filter between them preserves the Ink Crimson world
	# without recoloring or fringing any text or controls.
	layer = 105
	_create_screen_filter()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if (
		settings != null
		and not settings.visual_settings_changed.is_connected(
			_refresh_visibility
		)
	):
		settings.visual_settings_changed.connect(_refresh_visibility)
	_refresh_visibility()


func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_visibility()


func _create_screen_filter() -> void:
	screen_filter = ColorRect.new()
	screen_filter.name = "StrictTenColorOutput"
	screen_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_filter.color = Palette.VOID
	screen_filter.add_to_group("shader_toggle_hide")

	var shader_material := ShaderMaterial.new()
	shader_material.shader = QUANTIZE_SHADER
	screen_filter.material = shader_material

	add_child(screen_filter)


func _refresh_visibility() -> void:
	if screen_filter == null:
		return
	var settings := get_tree().root.get_node_or_null("GameSettings")
	screen_filter.visible = (
		enabled
		and (settings == null or bool(settings.get("shaders_enabled")))
	)
