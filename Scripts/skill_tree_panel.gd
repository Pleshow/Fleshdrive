class_name SkillTreePanel
extends Control


signal back_requested

const NODE_SIZE := Vector2(116, 116)
const ICON_DRAW_SIZE := Vector2(106, 106)
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.45

@onready var gem_count_label: Label = %GemCountLabel
@onready var detail_title: Label = %DetailTitle
@onready var detail_description: Label = %DetailDescription
@onready var detail_level: Label = %DetailLevel
@onready var detail_cost: Label = %DetailCost
@onready var back_button: Button = %BackButton
@onready var respec_button: Button = %RespecButton
@onready var reset_button: Button = %ResetButton
@onready var tree_viewport: Control = %TreeViewport
@onready var tree_canvas: Control = %TreeCanvas
@onready var respec_dialog: ConfirmationDialog = %RespecDialog
@onready var reset_dialog: ConfirmationDialog = %ResetDialog

var meta_progression: Node
var selected_upgrade: StringName = &"vitality"
var upgrade_buttons: Dictionary = {}
var zoom_level: float = 0.82
var dragging: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	meta_progression = get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	back_button.pressed.connect(back_requested.emit)
	respec_button.pressed.connect(respec_dialog.popup_centered)
	reset_button.pressed.connect(reset_dialog.popup_centered)
	respec_dialog.confirmed.connect(_confirm_respec)
	reset_dialog.confirmed.connect(_confirm_full_reset)
	tree_viewport.gui_input.connect(_on_tree_viewport_input)
	_install_viewport_frame()
	if meta_progression != null:
		meta_progression.gems_changed.connect(_on_progression_changed)
		meta_progression.upgrade_changed.connect(
			func(_id: StringName, _level: int) -> void:
				refresh()
		)
	_build_tree()
	refresh()


func _install_viewport_frame() -> void:
	if tree_viewport.get_node_or_null("VisibleViewportFrame") != null:
		return
	var frame := Panel.new()
	frame.name = "VisibleViewportFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.025, 0.03, 0.04)
	style.border_color = Color(0.18, 0.76, 0.82, 0.62)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", style)
	tree_viewport.add_child(frame)


func open() -> void:
	show()
	refresh()
	_show_upgrade_details(selected_upgrade)
	if upgrade_buttons.has(selected_upgrade):
		(upgrade_buttons[selected_upgrade] as Button).grab_focus()


func _build_tree() -> void:
	for child in tree_canvas.get_children():
		child.queue_free()
	upgrade_buttons.clear()
	if meta_progression == null:
		return

	for upgrade_id in meta_progression.UPGRADE_DEFINITIONS:
		var definition: Dictionary = (
			meta_progression.UPGRADE_DEFINITIONS[upgrade_id]
		)
		var required_id: StringName = definition.get("requires", &"")
		if required_id.is_empty():
			continue
		var required_definition: Dictionary = (
			meta_progression.UPGRADE_DEFINITIONS[required_id]
		)
		var branch := Line2D.new()
		branch.width = 4.0
		branch.default_color = Color(0.72, 0.58, 0.24, 0.72)
		branch.antialiased = true
		branch.points = PackedVector2Array([
			Vector2(required_definition.position) + NODE_SIZE * 0.5,
			Vector2(definition.position) + NODE_SIZE * 0.5,
		])
		tree_canvas.add_child(branch)

	for upgrade_id in meta_progression.UPGRADE_DEFINITIONS:
		_create_upgrade_node(upgrade_id)


func _create_upgrade_node(upgrade_id: StringName) -> void:
	var definition: Dictionary = (
		meta_progression.UPGRADE_DEFINITIONS[upgrade_id]
	)
	var node := Control.new()
	node.position = Vector2(definition.position)
	node.size = Vector2(140, 154)
	tree_canvas.add_child(node)

	var hex_fill := Polygon2D.new()
	hex_fill.name = "HexFill"
	hex_fill.polygon = _hex_points(
		NODE_SIZE * 0.5,
		54.0,
		false
	)
	hex_fill.color = Color(0.055, 0.065, 0.06, 0.98)
	node.add_child(hex_fill)

	var hex_border := Line2D.new()
	hex_border.name = "HexBorder"
	hex_border.points = _hex_points(
		NODE_SIZE * 0.5,
		55.0,
		true
	)
	hex_border.width = 4.0
	hex_border.default_color = Color(0.4, 0.44, 0.34)
	hex_border.antialiased = false
	node.add_child(hex_border)

	var button := Button.new()
	button.size = NODE_SIZE
	button.set_meta("ui_polish_skip", true)
	for style_name in [
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled",
	]:
		button.add_theme_stylebox_override(
			style_name,
			StyleBoxEmpty.new()
		)
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.size = ICON_DRAW_SIZE
	icon_rect.texture = load(String(definition.icon))
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_icon_content(icon_rect)
	button.add_child(icon_rect)
	button.mouse_entered.connect(_show_upgrade_details.bind(upgrade_id))
	button.mouse_entered.connect(_set_hex_hover.bind(button, true))
	button.mouse_exited.connect(_set_hex_hover.bind(button, false))
	button.focus_entered.connect(_show_upgrade_details.bind(upgrade_id))
	button.focus_entered.connect(_set_hex_hover.bind(button, true))
	button.focus_exited.connect(_set_hex_hover.bind(button, false))
	button.pressed.connect(_purchase_upgrade.bind(upgrade_id))
	node.add_child(button)
	upgrade_buttons[upgrade_id] = button

	var name_label := Label.new()
	name_label.position = Vector2(-22, 120)
	name_label.size = Vector2(160, 24)
	name_label.text = tr(String(definition.title))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	node.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "Level"
	level_label.position = Vector2(0, 142)
	level_label.size = Vector2(116, 22)
	level_label.theme_type_variation = &"MonoLabel"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(level_label)


func _center_icon_content(icon_rect: TextureRect) -> void:
	icon_rect.position = (NODE_SIZE - icon_rect.size) * 0.5
	if icon_rect.texture == null:
		return
	var image := icon_rect.texture.get_image()
	if image == null or image.is_empty():
		return
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		return
	var image_size := Vector2(image.get_width(), image.get_height())
	var content_center := (
		Vector2(used_rect.position)
		+ Vector2(used_rect.size) * 0.5
	)
	var normalized_center := content_center / image_size
	icon_rect.position = (
		NODE_SIZE * 0.5
		- icon_rect.size * normalized_center
	)


func _hex_points(
	center: Vector2,
	radius: float,
	close_shape: bool
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := 7 if close_shape else 6
	for point_index in range(point_count):
		var angle := (
			-PI * 0.5
			+ TAU * float(point_index % 6) / 6.0
		)
		points.append(
			center + Vector2(cos(angle), sin(angle)) * radius
		)
	return points


func _set_hex_hover(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var border := button.get_node("../HexBorder") as Line2D
	if border == null:
		return
	border.width = 5.0 if hovered else 4.0
	border.default_color = (
		Color(0.96, 0.77, 0.28)
		if hovered
		else Color(0.4, 0.44, 0.34)
	)
	var node := button.get_parent() as Control
	if node != null:
		node.pivot_offset = NODE_SIZE * 0.5
		var tween := node.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(
			node,
			"scale",
			Vector2(1.07, 1.07) if hovered else Vector2.ONE,
			0.14
		)


func refresh() -> void:
	if meta_progression == null:
		return
	gem_count_label.text = (
		"%d BLOOD MEMORY" % meta_progression.red_gems
	)
	for upgrade_id in upgrade_buttons:
		var definition: Dictionary = (
			meta_progression.UPGRADE_DEFINITIONS[upgrade_id]
		)
		var level: int = meta_progression.get_upgrade_level(upgrade_id)
		var button := upgrade_buttons[upgrade_id] as Button
		var level_label := button.get_node("../Level") as Label
		level_label.text = "%d / %d" % [level, int(definition.max_level)]
		var unlocked: bool = meta_progression.is_upgrade_unlocked(upgrade_id)
		button.disabled = level >= int(definition.max_level)
		button.modulate = (
			Color.WHITE
			if unlocked
			else Color(0.32, 0.34, 0.34, 0.72)
		)
		var fill := button.get_node("../HexFill") as Polygon2D
		var border := button.get_node("../HexBorder") as Line2D
		fill.color = (
			Color(0.055, 0.065, 0.06, 0.98)
			if unlocked
			else Color(0.025, 0.03, 0.03, 0.94)
		)
		border.default_color = (
			Color(0.82, 0.64, 0.25)
			if level >= int(definition.max_level)
			else Color(0.4, 0.44, 0.34)
		)
	_show_upgrade_details(selected_upgrade)


func _show_upgrade_details(upgrade_id: StringName) -> void:
	if meta_progression == null:
		return
	selected_upgrade = upgrade_id
	var definition: Dictionary = (
		meta_progression.UPGRADE_DEFINITIONS[upgrade_id]
	)
	var level: int = meta_progression.get_upgrade_level(upgrade_id)
	var max_level := int(definition.max_level)
	detail_title.text = tr(String(definition.title))
	detail_description.text = tr(String(definition.description))
	detail_level.text = tr("LEVEL  %d / %d") % [level, max_level]
	if not meta_progression.is_upgrade_unlocked(upgrade_id):
		var required_id: StringName = definition.requires
		var required: Dictionary = (
			meta_progression.UPGRADE_DEFINITIONS[required_id]
		)
		detail_cost.text = tr("LOCKED: BUY %s FIRST") % tr(String(required.title))
	elif level >= max_level:
		detail_cost.text = tr("MAXIMUM LEVEL")
	else:
		detail_cost.text = tr("COST  %d IMPRINT FRAGMENTS") % (
			meta_progression.get_upgrade_cost(upgrade_id)
		)


func _purchase_upgrade(upgrade_id: StringName) -> void:
	if meta_progression != null:
		meta_progression.purchase_upgrade(upgrade_id)
	refresh()


func _on_tree_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom_level + 0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom_level - 0.1, event.position)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		tree_canvas.position += event.relative


func _set_zoom(new_zoom: float, pivot: Vector2) -> void:
	new_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	var ratio := new_zoom / zoom_level
	tree_canvas.position = pivot - (pivot - tree_canvas.position) * ratio
	zoom_level = new_zoom
	tree_canvas.scale = Vector2.ONE * zoom_level


func _confirm_respec() -> void:
	meta_progression.respec_upgrades()
	refresh()


func _confirm_full_reset() -> void:
	meta_progression.reset_all_progress()
	refresh()


func _on_progression_changed(_value: int) -> void:
	refresh()
