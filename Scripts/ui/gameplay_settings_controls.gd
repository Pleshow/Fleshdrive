class_name GameplaySettingsControls
extends VBoxContainer


var settings: Node
var sliders: Dictionary = {}
var active_skill_bind_button: Button
var waiting_for_active_skill_key: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.text = tr("MIX & ACCESSIBILITY")
	title.set_meta("translation_key", "MIX & ACCESSIBILITY")
	title.add_theme_color_override("font_color", Color(0.69, 0.95, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)
	_add_slider(grid, &"music", tr("MUSIC"), float(settings.music_volume), 0.0, 100.0)
	_add_slider(grid, &"sfx", tr("SFX"), float(settings.sfx_volume), 0.0, 100.0)
	_add_slider(grid, &"shake", tr("CAMERA SHAKE"), float(settings.screen_shake_intensity) * 100.0, 0.0, 100.0)
	_add_slider(grid, &"vfx", tr("VFX INTENSITY"), float(settings.vfx_intensity) * 100.0, 0.0, 100.0)
	_add_slider(grid, &"deadzone", tr("STICK DEADZONE"), float(settings.controller_deadzone) * 100.0, 5.0, 55.0)
	_add_slider(grid, &"crosshair", tr("CROSSHAIR SIZE"), float(settings.crosshair_scale) * 100.0, 65.0, 175.0)
	_add_slider(grid, &"flash", tr("HIT FLASH"), float(settings.flash_intensity) * 100.0, 0.0, 100.0)
	_add_slider(grid, &"aim_assist", tr("AIM ASSIST"), float(settings.aim_assist_strength) * 100.0, 0.0, 100.0)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 14)
	add_child(toggles)
	_add_toggle(toggles, tr("DAMAGE NUMBERS"), bool(settings.damage_numbers_enabled), &"damage_numbers")
	_add_toggle(toggles, tr("TUTORIALS"), bool(settings.tutorials_enabled), &"tutorials")
	active_skill_bind_button = Button.new()
	active_skill_bind_button.custom_minimum_size = Vector2(250.0, 42.0)
	active_skill_bind_button.text = "%s: %s" % [
		tr("ACTIVE SKILL"),
		String(settings.call("get_active_skill_key_text")),
	]
	active_skill_bind_button.pressed.connect(_begin_active_skill_rebind)
	add_child(active_skill_bind_button)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.has_meta("translation_key"):
			var key := String(label.get_meta("translation_key"))
			if label.has_meta("setting_value"):
				var value := float(label.get_meta("setting_value"))
				label.text = "%s  %d%%" % [tr(key), roundi(value)]
			else:
				label.text = tr(key)
	for node in find_children("*", "CheckButton", true, false):
		var toggle := node as CheckButton
		if toggle != null and toggle.has_meta("translation_key"):
			toggle.text = tr(String(toggle.get_meta("translation_key")))


func _add_slider(
	parent: Control,
	key: StringName,
	caption: String,
	value: float,
	minimum: float,
	maximum: float
) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(178.0, 45.0)
	parent.add_child(cell)
	var label := Label.new()
	label.text = "%s  %d%%" % [caption, roundi(value)]
	var translation_keys := {
		&"music": "MUSIC",
		&"sfx": "SFX",
		&"shake": "CAMERA SHAKE",
		&"vfx": "VFX INTENSITY",
		&"deadzone": "STICK DEADZONE",
		&"crosshair": "CROSSHAIR SIZE",
		&"flash": "HIT FLASH",
		&"aim_assist": "AIM ASSIST",
	}
	label.set_meta(
		"translation_key",
		String(translation_keys.get(key, String(key).to_upper()))
	)
	label.set_meta("setting_value", value)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.92))
	cell.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0
	slider.value = value
	slider.custom_minimum_size = Vector2(170.0, 18.0)
	slider.value_changed.connect(_on_slider_changed.bind(key, caption, label))
	cell.add_child(slider)
	sliders[key] = slider


func _add_toggle(
	parent: Control,
	caption: String,
	pressed: bool,
	key: StringName
) -> void:
	var toggle := CheckButton.new()
	toggle.set_meta("ui_polish_skip", true)
	toggle.flat = true
	toggle.text = caption
	var translation_keys := {
		&"damage_numbers": "DAMAGE NUMBERS",
		&"tutorials": "TUTORIALS",
	}
	toggle.set_meta(
		"translation_key",
		String(translation_keys.get(key, caption))
	)
	toggle.button_pressed = pressed
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.toggled.connect(_on_toggle_changed.bind(key))
	parent.add_child(toggle)


func _on_slider_changed(
	value: float,
	key: StringName,
	caption: String,
	label: Label
) -> void:
	label.text = "%s  %d%%" % [
		tr(String(label.get_meta("translation_key", caption))),
		roundi(value),
	]
	label.set_meta("setting_value", value)
	match key:
		&"music": settings.call("set_bus_volume", &"Music", value)
		&"sfx": settings.call("set_bus_volume", &"SFX", value)
		&"shake": settings.call("set_gameplay_setting", &"screen_shake", value / 100.0)
		&"vfx": settings.call("set_gameplay_setting", &"vfx_intensity", value / 100.0)
		&"deadzone": settings.call("set_gameplay_setting", &"controller_deadzone", value / 100.0)
		&"crosshair": settings.call("set_gameplay_setting", &"crosshair_scale", value / 100.0)
		&"flash": settings.call("set_gameplay_setting", &"flash_intensity", value / 100.0)
		&"aim_assist": settings.call("set_gameplay_setting", &"aim_assist", value / 100.0)


func _on_toggle_changed(enabled: bool, key: StringName) -> void:
	settings.call("set_gameplay_setting", key, enabled)


func _begin_active_skill_rebind() -> void:
	waiting_for_active_skill_key = true
	active_skill_bind_button.text = tr("PRESS A KEY - ESC TO CANCEL")
	active_skill_bind_button.release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not waiting_for_active_skill_key or not event.pressed or event.echo:
		return
	waiting_for_active_skill_key = false
	if event.keycode != KEY_ESCAPE:
		settings.call("set_active_skill_keycode", event.physical_keycode)
	active_skill_bind_button.text = "%s: %s" % [
		tr("ACTIVE SKILL"),
		String(settings.call("get_active_skill_key_text")),
	]
	get_viewport().set_input_as_handled()
