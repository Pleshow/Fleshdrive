extends CanvasLayer


const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const QUANTIZE_SHADER := preload("res://Shaders/ink_crimson_quantize.gdshader")

var screen_filter: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4095
	_create_screen_filter()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_restyle_branch", get_tree().root)


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


func _on_node_added(node: Node) -> void:
	if node == self or node == screen_filter:
		return
	call_deferred("_restyle_branch", node)


func _restyle_branch(candidate: Variant) -> void:
	if not is_instance_valid(candidate) or not candidate is Node:
		return
	var node := candidate as Node
	if node == self or node == screen_filter or is_ancestor_of(node):
		return
	if node is Control:
		Palette.quantize_control_overrides(node as Control)
	for child in node.get_children():
		_restyle_branch(child)
