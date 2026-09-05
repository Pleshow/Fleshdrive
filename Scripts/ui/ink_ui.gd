class_name InkUI
extends RefCounted

const VOID := Color("09010d")
const PANEL := Color("17001d")
const BORDER := Color("660f31")
const RED := Color("ff0546")
const BLUE := Color("0098db")
const TEXT := Color("0ce6f2")

static func preserve(node: Control) -> void:
	node.set_meta("preserve_authored_ui_style", true)
	node.set_meta("ui_polish_skip", true)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func box(color: Color = PANEL, edge: Color = BORDER) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = edge
	result.set_border_width_all(2)
	result.set_content_margin_all(12)
	return result

static func label(parent: Node, caption: String, rect: Rect2, font_size: int = 16) -> Label:
	var node := Label.new()
	preserve(node)
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", TEXT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Node, caption: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	preserve(node)
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("normal", box())
	node.add_theme_stylebox_override("hover", box(PANEL, TEXT))
	node.add_theme_stylebox_override("focus", box(PANEL, TEXT))
	node.add_theme_stylebox_override("pressed", box(Color("270022"), RED))
	node.add_theme_stylebox_override("disabled", box(VOID, Color("450327")))
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_disabled_color", Color("1e579c"))
	node.add_theme_font_size_override("font_size", 15)
	node.pressed.connect(action)
	parent.add_child(node)
	return node
