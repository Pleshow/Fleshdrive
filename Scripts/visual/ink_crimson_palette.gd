class_name InkCrimsonPalette
extends RefCounted


const ALERT := Color("ff0546")
const FLESH := Color("9c173b")
const FLESH_DEEP := Color("660f31")
const FLESH_SHADOW := Color("450327")
const PANEL := Color("270022")
const INK := Color("17001d")
const VOID := Color("09010d")
const TECH_BRIGHT := Color("0ce6f2")
const TECH := Color("0098db")
const TECH_DEEP := Color("1e579c")

const COLORS := [
	ALERT,
	FLESH,
	FLESH_DEEP,
	FLESH_SHADOW,
	PANEL,
	INK,
	VOID,
	TECH_BRIGHT,
	TECH,
	TECH_DEEP,
]


static func nearest_opaque(source: Color) -> Color:
	var target := COLORS[0] as Color
	var best_distance := INF
	var source_rgb := Vector3(source.r, source.g, source.b)
	for candidate_variant in COLORS:
		var candidate := candidate_variant as Color
		var candidate_rgb := Vector3(candidate.r, candidate.g, candidate.b)
		var difference := source_rgb - candidate_rgb
		var distance := difference.dot(difference)
		if distance < best_distance:
			best_distance = distance
			target = candidate
	target.a = 1.0
	return target


static func make_panel(
	fill: Color = PANEL,
	border: Color = TECH_DEEP,
	border_width: int = 2,
	content_margin: float = 12.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = nearest_opaque(fill)
	style.border_color = nearest_opaque(border)
	style.set_border_width_all(border_width)
	style.set_content_margin_all(content_margin)
	style.set_corner_radius_all(0)
	style.shadow_size = 0
	style.shadow_color = VOID
	style.anti_aliasing = false
	return style


static func quantize_control_overrides(control: Control) -> void:
	if control == null:
		return
	for property_data in control.get_property_list():
		var property_name := String(property_data.get("name", ""))
		if property_name.begins_with("theme_override_colors/"):
			var color_value: Variant = control.get(property_name)
			if color_value is Color:
				control.set(property_name, nearest_opaque(color_value as Color))
		elif property_name.begins_with("theme_override_styles/"):
			var style_value: Variant = control.get(property_name)
			if style_value is StyleBoxFlat:
				var style := (style_value as StyleBoxFlat).duplicate(true) as StyleBoxFlat
				quantize_stylebox(style)
				control.set(property_name, style)


static func quantize_stylebox(style: StyleBoxFlat) -> void:
	if style == null:
		return
	style.bg_color = nearest_opaque(style.bg_color)
	style.border_color = nearest_opaque(style.border_color)
	style.shadow_color = VOID
	style.shadow_size = 0
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
