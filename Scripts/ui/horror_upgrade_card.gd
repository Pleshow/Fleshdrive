class_name HorrorUpgradeCard
extends TextureButton


const HOVER_SCALE := Vector2(1.035, 1.035)
const SELECTED_SCALE := Vector2(1.065, 1.065)
const REST_SCALE := Vector2.ONE
const MAX_TILT_DEGREES := 1.35

var _hovered := false
var _selected := false
var _motion_tween: Tween
var _reveal_tween: Tween
var _revealing := false


func _init() -> void:
	set_meta("ui_polish_skip", true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resized.connect(_refresh_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_refresh_pivot()


func set_selected_visual(selected: bool, animate := true) -> void:
	_selected = selected
	var border := get_node_or_null("SelectionBorder") as CanvasItem
	if border != null:
		border.visible = selected
	if animate:
		_animate_pose()
	else:
		scale = SELECTED_SCALE if selected else REST_SCALE


func play_reveal(delay: float) -> void:
	_refresh_pivot()
	_kill_motion_tween()
	_kill_reveal_tween()
	_revealing = true
	var surface := get_node_or_null("CardSurface") as Control
	if surface != null:
		surface.position = Vector2(0.0, 34.0)
	scale = Vector2(0.72, 0.72)
	rotation_degrees = -3.0
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_reveal_tween = create_tween()
	_reveal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reveal_tween.tween_interval(delay)
	_reveal_tween.set_trans(Tween.TRANS_BACK)
	_reveal_tween.set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "scale", REST_SCALE, 0.34)
	_reveal_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.30)
	_reveal_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	if surface != null:
		_reveal_tween.parallel().tween_property(surface, "position", Vector2.ZERO, 0.30)
	_reveal_tween.finished.connect(_finish_reveal)


func play_confirm() -> void:
	_refresh_pivot()
	_kill_motion_tween()
	_motion_tween = create_tween()
	_motion_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion_tween.set_trans(Tween.TRANS_BACK)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", Vector2(1.105, 1.105), 0.08)
	_motion_tween.tween_property(self, "scale", SELECTED_SCALE, 0.13)


func reset_pose() -> void:
	_hovered = false
	_selected = false
	_revealing = false
	_kill_motion_tween()
	_kill_reveal_tween()
	rotation_degrees = 0.0
	scale = REST_SCALE
	modulate = Color.WHITE
	var surface := get_node_or_null("CardSurface") as Control
	if surface != null:
		surface.position = Vector2.ZERO


func _on_mouse_entered() -> void:
	_hovered = true
	if _revealing:
		return
	_animate_pose()


func _on_mouse_exited() -> void:
	_hovered = false
	if _revealing:
		return
	_animate_pose()


func _on_gui_input(event: InputEvent) -> void:
	if not _hovered or not event is InputEventMouseMotion:
		return
	var safe_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var normalized := (get_local_mouse_position() / safe_size) * 2.0 - Vector2.ONE
	rotation_degrees = clampf(normalized.x, -1.0, 1.0) * MAX_TILT_DEGREES


func _animate_pose() -> void:
	if _revealing:
		return
	_refresh_pivot()
	_kill_motion_tween()
	var target_scale := REST_SCALE
	if _selected:
		target_scale = SELECTED_SCALE
	elif _hovered:
		target_scale = HOVER_SCALE
	_motion_tween = create_tween()
	_motion_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion_tween.set_trans(Tween.TRANS_QUAD)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(self, "scale", target_scale, 0.16)
	if not _hovered:
		_motion_tween.tween_property(self, "rotation_degrees", 0.0, 0.16)


func _finish_reveal() -> void:
	_revealing = false
	modulate = Color.WHITE
	var surface := get_node_or_null("CardSurface") as Control
	if surface != null:
		surface.position = Vector2.ZERO
	_animate_pose()


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5


func _kill_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()


func _kill_reveal_tween() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
