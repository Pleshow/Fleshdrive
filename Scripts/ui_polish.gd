extends Node


const CRIMSON_TEXT := Color("9c173b")
const CRIMSON_BODY := Color("e84a6b")
const CRIMSON_HOVER := Color("ff0546")
const CRIMSON_PRESSED := Color("660f31")
const CRIMSON_DISABLED := Color(0.27, 0.012, 0.153, 0.58)
const UI_VOID := Color(0.035, 0.004, 0.035, 0.92)
const HORROR_BUTTON_NORMAL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Buttons/HorrorUI-ButtonA_01.png"
)
const HORROR_BUTTON_HOVER := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Buttons/HorrorUI-ButtonA_02.png"
)
const HORROR_BUTTON_PRESSED := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Buttons/HorrorUI-ButtonA_03.png"
)
const HORROR_PANEL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Panels -slice 9/HorrorUI-Panel_01.png"
)
const HORROR_CURSOR := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Cursors/F_UI_Cursor1.png"
)
const HORROR_CURSOR_ACTIVE := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Cursors/F_UI_Cursor2.png"
)
const HORROR_SWITCH_OFF := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Switches/Big switch/HorrorUI-SwitchA_OFF.png"
)
const HORROR_SWITCH_ON := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Switches/Big switch/HorrorUI-SwitchA_ON.png"
)
const HORROR_SLIDER_HORIZONTAL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Slidebars/HorrorUI-SlidebarA.png"
)
const HORROR_SLIDER_VERTICAL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Slidebars/HorrorUI-SlidebarE.png"
)
const HORROR_HANDLE_HORIZONTAL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Slidebars/HorrorUI-HorizontalHandle_01.png"
)
const HORROR_HANDLE_VERTICAL := preload(
	"res://Assets/ui/Horror UI kit/Horror UI Kit/Horror UI Kit/Slidebars/HorrorUI-VerticalHandle_01.png"
)

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
	Input.set_custom_mouse_cursor(HORROR_CURSOR, Input.CURSOR_ARROW, Vector2(1.0, 1.0))
	Input.set_custom_mouse_cursor(
		HORROR_CURSOR_ACTIVE,
		Input.CURSOR_POINTING_HAND,
		Vector2(2.0, 2.0)
	)
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
	if node is Control:
		_apply_minimal_crimson_style(node as Control)
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
	_remove_button_shadow(button)
	_constrain_menu_button.call_deferred(button)
	_update_pivot(button)


func _remove_button_shadow(button: BaseButton) -> void:
	var old_shadow := button.get_node_or_null("BiomechShadow")
	if old_shadow != null:
		old_shadow.queue_free()


func _apply_minimal_crimson_style(control: Control) -> void:
	if control.has_meta("preserve_authored_ui_style"):
		return
	if control is BaseButton and not control is TextureButton:
		_style_text_button(control as BaseButton)
	elif control is Label:
		_style_label(control as Label)
	elif control is RichTextLabel:
		_style_rich_text(control as RichTextLabel)
	elif control is TextEdit:
		_style_text_edit(control as TextEdit)
	elif control is HSlider or control is VSlider:
		_style_slider(control as Range)
	elif control is Panel or control is PanelContainer:
		_style_panel(control)
	elif control is TabBar:
		_style_tab_bar(control as TabBar)
	elif control is LineEdit:
		_style_line_edit(control as LineEdit)
	elif control is TextureRect:
		_style_ui_texture(control as TextureRect)
	if control is ColorRect and _is_modal_background(control):
		(control as ColorRect).color = UI_VOID
	elif control is ColorRect and "accent" in String(control.name).to_lower():
		var accent := control as ColorRect
		accent.color = Color(
			CRIMSON_TEXT.r,
			CRIMSON_TEXT.g,
			CRIMSON_TEXT.b,
			accent.color.a
		)


func _style_text_button(button: BaseButton) -> void:
	if button is CheckButton:
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		button.add_theme_icon_override("checked", HORROR_SWITCH_ON)
		button.add_theme_icon_override("unchecked", HORROR_SWITCH_OFF)
		button.add_theme_icon_override("checked_disabled", HORROR_SWITCH_ON)
		button.add_theme_icon_override("unchecked_disabled", HORROR_SWITCH_OFF)
	elif button is Button:
		(button as Button).flat = false
		button.add_theme_stylebox_override(
			"normal", _make_horror_style(HORROR_BUTTON_NORMAL, 10.0)
		)
		button.add_theme_stylebox_override(
			"hover", _make_horror_style(HORROR_BUTTON_HOVER, 10.0)
		)
		button.add_theme_stylebox_override(
			"pressed", _make_horror_style(HORROR_BUTTON_PRESSED, 10.0)
		)
		button.add_theme_stylebox_override(
			"disabled", _make_horror_style(HORROR_BUTTON_NORMAL, 10.0)
		)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", CRIMSON_TEXT)
	button.add_theme_color_override("font_focus_color", CRIMSON_TEXT)
	button.add_theme_color_override("font_hover_color", CRIMSON_HOVER)
	button.add_theme_color_override("font_pressed_color", CRIMSON_PRESSED)
	button.add_theme_color_override("font_disabled_color", CRIMSON_DISABLED)
	button.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	button.add_theme_color_override("icon_normal_color", CRIMSON_TEXT)
	button.add_theme_color_override("icon_focus_color", CRIMSON_TEXT)
	button.add_theme_color_override("icon_hover_color", CRIMSON_HOVER)
	button.add_theme_color_override("icon_pressed_color", CRIMSON_PRESSED)
	button.add_theme_color_override("icon_disabled_color", CRIMSON_DISABLED)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)


func _style_label(label: Label) -> void:
	label.add_theme_color_override(
		"font_color",
		CRIMSON_HOVER if _is_heading_label(label) else CRIMSON_BODY
	)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


func _style_rich_text(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", CRIMSON_BODY)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)


func _style_panel(control: Control) -> void:
	# The main menu artwork already supplies the composition behind the text.
	# MenuShell is layout-only; painting it created the large black rectangle
	# visible behind the otherwise frameless menu buttons.
	if control.name in [&"PortraitFrame", &"MenuShell"]:
		control.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	if (
		String(control.name).contains("SelectionBorder")
		or control.name == &"SelectedFrame"
	):
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = CRIMSON_HOVER
		style.set_border_width_all(2)
		style.anti_aliasing = false
		control.add_theme_stylebox_override("panel", style)
	else:
		control.add_theme_stylebox_override(
			"panel", _make_horror_style(HORROR_PANEL, 26.0)
		)


func _make_horror_style(texture: Texture2D, margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style


func _style_tab_bar(tab_bar: TabBar) -> void:
	for style_name in [
		"tab_unselected",
		"tab_hovered",
		"tab_selected",
		"tab_disabled",
		"tab_focus",
	]:
		tab_bar.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	tab_bar.add_theme_color_override("font_unselected_color", CRIMSON_TEXT)
	tab_bar.add_theme_color_override("font_hovered_color", CRIMSON_HOVER)
	tab_bar.add_theme_color_override("font_selected_color", CRIMSON_HOVER)
	tab_bar.add_theme_color_override("font_disabled_color", CRIMSON_DISABLED)
	tab_bar.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	tab_bar.add_theme_constant_override("outline_size", 0)


func _style_line_edit(line_edit: LineEdit) -> void:
	for style_name in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UI_VOID
		style.border_color = CRIMSON_TEXT
		style.border_width_bottom = 1
		style.anti_aliasing = false
		line_edit.add_theme_stylebox_override(style_name, style)
	line_edit.add_theme_color_override("font_color", CRIMSON_TEXT)
	line_edit.add_theme_color_override("font_selected_color", CRIMSON_HOVER)
	line_edit.add_theme_color_override("caret_color", CRIMSON_HOVER)
	line_edit.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	line_edit.add_theme_constant_override("outline_size", 0)


func _style_text_edit(text_edit: TextEdit) -> void:
	text_edit.add_theme_color_override("font_color", CRIMSON_TEXT)
	text_edit.add_theme_color_override("font_selected_color", CRIMSON_HOVER)
	text_edit.add_theme_color_override("caret_color", CRIMSON_HOVER)
	text_edit.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	text_edit.add_theme_constant_override("outline_size", 0)


func _style_slider(slider: Range) -> void:
	var horizontal := slider is HSlider
	var track_texture := (
		HORROR_SLIDER_HORIZONTAL if horizontal else HORROR_SLIDER_VERTICAL
	)
	var track := _make_horror_style(track_texture, 5.0)
	var filled := _make_horror_style(track_texture, 5.0)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var handle := HORROR_HANDLE_HORIZONTAL if horizontal else HORROR_HANDLE_VERTICAL
	slider.add_theme_icon_override("grabber", handle)
	slider.add_theme_icon_override("grabber_highlight", handle)


func _style_ui_texture(texture_rect: TextureRect) -> void:
	var texture_name := String(texture_rect.name).to_lower()
	if "icon" not in texture_name and "portrait" not in texture_name:
		return
	# Heart illustrations are authored full-colour card art. Tinting the generic
	# child name "Icon" crimson crushed the Voltaic Heart into its dark panel.
	var ancestor: Node = texture_rect
	while ancestor != null:
		if ancestor.name == &"FleshdriveOperationScreen":
			texture_rect.self_modulate = Color.WHITE
			return
		ancestor = ancestor.get_parent()
	texture_rect.self_modulate = CRIMSON_BODY


func _is_heading_label(label: Label) -> bool:
	var label_name := String(label.name).to_lower()
	return (
		"title" in label_name
		or "header" in label_name
		or "warning" in label_name
		or "death" in label_name
		or label.get_theme_font_size("font_size") >= 24
	)


func _is_modal_background(control: Control) -> bool:
	var background_name := String(control.name).to_lower()
	if background_name not in ["background", "overlay", "dim", "shade"]:
		return false
	var ancestor: Node = control
	while ancestor != null:
		if ancestor.name in MODAL_NAMES:
			return true
		ancestor = ancestor.get_parent()
	return false


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
