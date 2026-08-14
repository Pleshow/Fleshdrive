class_name OrganSlotControl
extends Control


signal organ_installed(organ_data: UpgradeData)
signal organ_replacement_requested(
	slot_control: OrganSlotControl,
	current_organ: UpgradeData,
	replacement_organ: UpgradeData
)


@export var accepted_slot: UpgradeData.OrganSlot = (
	UpgradeData.OrganSlot.LEGS
)

@onready var installed_organ: TextureRect = $InstalledOrgan

var installed_organ_data: UpgradeData
var drop_feedback: int = 0
var pulse_time: float = 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	mouse_entered.connect(_animate_slot.bind(true))
	mouse_exited.connect(_animate_slot.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()
	set_process(true)


func _process(delta: float) -> void:
	pulse_time += delta
	if OrganDragCard.active_drag_organ == null and drop_feedback != 0:
		drop_feedback = 0
		queue_redraw()
	elif drop_feedback != 0:
		queue_redraw()


func _draw() -> void:
	if drop_feedback == 0:
		return
	var color := (
		Color(0.30, 0.96, 0.82, 0.72 + sin(pulse_time * 9.0) * 0.18)
		if drop_feedback > 0
		else Color(1.0, 0.18, 0.20, 0.90)
	)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), color, false, 4.0)


func _can_drop_data(
	_at_position: Vector2,
	data: Variant
) -> bool:
	var organ := data as UpgradeData

	if organ == null:
		return false

	if organ.upgrade_kind != UpgradeData.UpgradeKind.ORGAN:
		return false
	drop_feedback = 1 if organ.organ_slot == accepted_slot else -1
	queue_redraw()
	# Accept the drag event so invalid anatomy drops receive explicit red
	# kickback instead of failing silently under the cursor.
	return true


func _drop_data(
	_at_position: Vector2,
	data: Variant
) -> void:
	var organ := data as UpgradeData

	if organ == null:
		return
	if organ.organ_slot != accepted_slot:
		_play_invalid_feedback()
		return

	if installed_organ_data != null:
		organ_replacement_requested.emit(
			self,
			installed_organ_data,
			organ
		)
		return

	install_organ(organ)


func install_organ(organ: UpgradeData) -> void:
	if organ == null:
		return

	installed_organ_data = organ

	installed_organ.texture = organ.card_texture
	installed_organ.show()
	tooltip_text = (
		String(organ.upgrade_id).replace("_", " ").to_upper()
		+ "\nINSTALLED ORGAN"
	)

	organ_installed.emit(organ)
	_play_valid_feedback()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _animate_slot(hovered: bool) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"scale",
		Vector2(1.06, 1.06) if hovered else Vector2.ONE,
		0.14
	)


func _play_valid_feedback() -> void:
	drop_feedback = 1
	queue_redraw()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.10)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	tween.tween_callback(func() -> void:
		drop_feedback = 0
		queue_redraw()
	)


func _play_invalid_feedback() -> void:
	drop_feedback = -1
	queue_redraw()
	var origin := position
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "position", origin + Vector2(9.0, 0.0), 0.045)
	tween.tween_property(self, "position", origin - Vector2(7.0, 0.0), 0.055)
	tween.tween_property(self, "position", origin, 0.065)
	tween.tween_callback(func() -> void:
		drop_feedback = 0
		queue_redraw()
	)
