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

	screen_filter.hide()


func set_enabled(value: bool) -> void:
	enabled = value

	if screen_filter != null:
		screen_filter.visible = value


func _create_screen_filter() -> void:
	screen_filter = ColorRect.new()
	screen_filter.name = "StrictTenColorOutput"
	screen_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_filter.color = Palette.VOID

	var shader_material := ShaderMaterial.new()
	shader_material.shader = QUANTIZE_SHADER
	screen_filter.material = shader_material

	add_child(screen_filter)
