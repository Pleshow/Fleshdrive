extends Node


const MODAL_NAMES: Array[StringName] = [
	&"SettingsPanel",
	&"SettingsContainer",
	&"SkillTreePanel",
	&"LevelUpPanel",
	&"OrganScreen",
	&"PausePanel",
	&"RunEndPanel",
	&"OnboardingPanel",
	&"BiofabricatorSequence",
	&"FleshdriveOperationScreen",
	&"DialoguePanel",
]

const BUTTON_HOVER_SCALE := Vector2(1.018, 1.018)
const CARD_HOVER_SCALE := Vector2(1.035, 1.035)
const PRESS_SCALE := Vector2(0.982, 0.982)

var active_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_register_existing_tree")


func _register_existing_tree() -> void:
	_register_branch(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_register_branch.call_deferred(node)


func _register_branch(candidate: Variant) -> void:
	# Nodes can disappear between node_added and this deferred registration
	# during scene changes. Keeping the deferred argument untyped lets us
	# reject that freed reference safely instead of triggering a cast error.
	if not is_instance_valid(candidate) or not candidate is Node:
		return
	var node := candidate as Node
	if node is BaseButton:
		_register_button(node as BaseButton)
	elif node is HSlider or node is VSlider:
		_register_slider(node as Range)
	if node is Control and node.name in MODAL_NAMES:
		_register_modal(node as Control)
	for child in node.get_children():
		_register_branch(child)


func _register_button(button: BaseButton) -> void:
	if button.has_meta("ui_polish_skip"):
		return
	if button.has_meta("_fleshdrive_ui_polished"):
		return
	button.set_meta("_fleshdrive_ui_polished", true)
	button.set_meta("_fleshdrive_ui_hovered", false)
	button.set_meta("_fleshdrive_ui_focused", false)
	button.set_meta("_fleshdrive_ui_original_z", button.z_index)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.resized.connect(_update_pivot.bind(button))
	button.mouse_entered.connect(_set_button_hover.bind(button, true))
	button.mouse_exited.connect(_set_button_hover.bind(button, false))
	button.focus_entered.connect(_set_button_focus.bind(button, true))
	button.focus_exited.connect(_set_button_focus.bind(button, false))
	button.button_down.connect(_press_button.bind(button))
	button.button_up.connect(_release_button.bind(button))
	_install_button_shadow(button)
	_constrain_menu_button.call_deferred(button)
	_update_pivot(button)


func _install_button_shadow(button: BaseButton) -> void:
	if not button is Button or bool(button.get("flat")):
		return
	var shadow := Panel.new()
	shadow.name = "BiomechShadow"
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.position += Vector2(3.0, 3.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("09010d")
	style.set_corner_radius_all(0)
	style.shadow_color = Color("09010d")
	style.shadow_size = 0
	style.anti_aliasing = false
	shadow.add_theme_stylebox_override("panel", style)
	button.add_child(shadow)


func _constrain_menu_button(button: BaseButton) -> void:
	if (
		not is_instance_valid(button)
		or not button is Button
		or not button.get_parent() is VBoxContainer
		or button.custom_minimum_size.x > 0.0
	):
		return
	button.custom_minimum_size.x = 360.0
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _register_slider(slider: Range) -> void:
	if slider.has_meta("_fleshdrive_ui_polished"):
		return
	slider.set_meta("_fleshdrive_ui_polished", true)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_entered.connect(_animate_slider.bind(slider, true))
	slider.mouse_exited.connect(_animate_slider.bind(slider, false))
	slider.focus_entered.connect(_animate_slider.bind(slider, true))
	slider.focus_exited.connect(_animate_slider.bind(slider, false))


func _register_modal(control: Control) -> void:
	if control.has_meta("_fleshdrive_modal_polished"):
		return
	control.set_meta("_fleshdrive_modal_polished", true)
	control.visibility_changed.connect(_on_modal_visibility_changed.bind(control))


func _update_pivot(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5


func _set_button_hover(button: BaseButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	button.set_meta("_fleshdrive_ui_hovered", hovered)
	_refresh_button_state(button)


func _set_button_focus(button: BaseButton, focused: bool) -> void:
	if not is_instance_valid(button):
		return
	button.set_meta("_fleshdrive_ui_focused", focused)
	_refresh_button_state(button)


func _refresh_button_state(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.button_pressed:
		return
	var hovered := bool(button.get_meta(
		"_fleshdrive_ui_hovered",
		false
	))
	var focused := bool(button.get_meta(
		"_fleshdrive_ui_focused",
		false
	))
	var active := hovered or focused
	var target_scale := Vector2.ONE
	# Keyboard/controller focus must not change layout geometry. It already has
	# a dedicated focus border; only a real pointer hover lifts the control.
	# This keeps adjacent menu buttons and compact card rows perfectly aligned.
	if hovered and not button.disabled:
		var default_scale := (
			CARD_HOVER_SCALE.x
			if button is TextureButton or button.size.y >= 150.0
			else BUTTON_HOVER_SCALE.x
		)
		var hover_scale := float(button.get_meta(
			"ui_hover_scale",
			default_scale
		))
		target_scale = Vector2(hover_scale, hover_scale)
	button.z_index = (
		int(button.get_meta("_fleshdrive_ui_original_z", 0)) + 20
		if active
		else int(button.get_meta("_fleshdrive_ui_original_z", 0))
	)
	_tween_scale(button, target_scale, 0.14)


func _press_button(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled:
		_tween_scale(button, PRESS_SCALE, 0.06)


func _release_button(button: BaseButton) -> void:
	if is_instance_valid(button):
		_refresh_button_state(button)


func _animate_slider(slider: Range, active: bool) -> void:
	if not is_instance_valid(slider):
		return
	var control := slider as Control
	_update_pivot(control)
	_tween_scale(
		control,
		Vector2(1.012, 1.12) if active else Vector2.ONE,
		0.14
	)


func _on_modal_visibility_changed(control: Control) -> void:
	if is_instance_valid(control) and control.visible:
		animate_in(control)


func animate_in(control: Control, duration: float = 0.22) -> void:
	if not is_instance_valid(control):
		return
	_update_pivot(control)
	_kill_tween(control)
	control.modulate.a = 0.0
	control.scale = Vector2(0.985, 0.985)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)
	tween.tween_property(control, "scale", Vector2.ONE, duration)
	active_tweens[control.get_instance_id()] = tween
	tween.finished.connect(_forget_tween.bind(control.get_instance_id()))


func pulse(control: Control, accent: Color = Color("0ce6f2")) -> void:
	if not is_instance_valid(control):
		return
	_update_pivot(control)
	_kill_tween(control)
	var original_modulate := control.modulate
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2(1.045, 1.045), 0.08)
	tween.parallel().tween_property(control, "modulate", accent, 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.16)
	tween.parallel().tween_property(
		control,
		"modulate",
		original_modulate,
		0.16
	)
	active_tweens[control.get_instance_id()] = tween
	tween.finished.connect(_forget_tween.bind(control.get_instance_id()))


func _tween_scale(
	control: Control,
	target_scale: Vector2,
	duration: float
) -> void:
	_kill_tween(control)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target_scale, duration)
	active_tweens[control.get_instance_id()] = tween
	tween.finished.connect(_forget_tween.bind(control.get_instance_id()))


func _kill_tween(control: Control) -> void:
	var instance_id := control.get_instance_id()
	if not active_tweens.has(instance_id):
		return
	var tween := active_tweens[instance_id] as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	active_tweens.erase(instance_id)


func _forget_tween(instance_id: int) -> void:
	active_tweens.erase(instance_id)
