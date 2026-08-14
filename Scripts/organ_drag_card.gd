class_name OrganDragCard
extends TextureRect


static var active_drag_organ: UpgradeData
var organ_data: UpgradeData


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	mouse_entered.connect(_animate_hover.bind(true))
	mouse_exited.connect(_animate_hover.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()


func set_organ(data: UpgradeData) -> void:
	organ_data = data

	if organ_data == null:
		clear_organ()
		return

	texture = organ_data.card_texture
	tooltip_text = (
		String(organ_data.upgrade_id).replace("_", " ").to_upper()
		+ "\nPENDING ORGAN\nDrag onto its matching anatomy slot."
	)
	show()


func clear_organ() -> void:
	organ_data = null
	texture = null
	tooltip_text = ""
	hide()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if organ_data == null:
		return null

	var preview := TextureRect.new()

	preview.texture = organ_data.card_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	preview.size = Vector2(100.0, 150.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_drag_preview(preview)
	active_drag_organ = organ_data

	return organ_data


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		active_drag_organ = null


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _animate_hover(hovered: bool) -> void:
	if organ_data == null:
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"scale",
		Vector2(1.055, 1.055) if hovered else Vector2.ONE,
		0.14
	)
