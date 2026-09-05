class_name GameplaySettingsControls
extends VBoxContainer


var settings: Node
var sliders: Dictionary = {}
@onready var active_skill_bind_button: Button = %ActiveSkillBind
var waiting_for_active_skill_key: bool = false
@onready var secondary_active_skill_bind_button: Button = %SecondaryActiveSkillBind
var waiting_for_secondary_active_skill_key: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	_bind_slider(&"music", $Grid/Music, float(settings.music_volume))
	_bind_slider(&"sfx", $Grid/Sfx, float(settings.sfx_volume))
	_bind_slider(&"shake", $Grid/Shake, float(settings.screen_shake_intensity) * 100.0)
	_bind_slider(&"vfx", $Grid/Vfx, float(settings.vfx_intensity) * 100.0)
	_bind_slider(&"deadzone", $Grid/Deadzone, float(settings.controller_deadzone) * 100.0)
	_bind_slider(&"crosshair", $Grid/Crosshair, float(settings.crosshair_scale) * 100.0)
	_bind_slider(&"flash", $Grid/Flash, float(settings.flash_intensity) * 100.0)
	_bind_slider(&"aim_assist", $Grid/AimAssist, float(settings.aim_assist_strength) * 100.0)
	_bind_toggle($Toggles/DamageNumbers, bool(settings.damage_numbers_enabled), &"damage_numbers")
	_bind_toggle($Toggles/Tutorials, bool(settings.tutorials_enabled), &"tutorials")
	_bind_toggle($Toggles/Shaders, bool(settings.shaders_enabled), &"shaders")
	active_skill_bind_button.text = "%s: %s" % [
		tr("ACTIVE SKILL"),
		String(settings.call("get_active_skill_key_text")),
	]
	active_skill_bind_button.pressed.connect(_begin_active_skill_rebind)
	secondary_active_skill_bind_button.text = "%s: %s" % [
		tr("SECONDARY ACTIVE SKILL"),
		String(settings.call("get_secondary_active_skill_key_text")),
	]
	secondary_active_skill_bind_button.pressed.connect(
		_begin_secondary_active_skill_rebind
	)


func _bind_slider(key: StringName, cell: VBoxContainer, value: float) -> void:
	var label := cell.get_node("Label") as Label
	var slider := cell.get_node("Slider") as HSlider
	label.text = "%s  %d%%" % [tr(String(label.get_meta("translation_key"))), roundi(value)]
	label.set_meta("setting_value", value)
	slider.value = value
	slider.value_changed.connect(_on_slider_changed.bind(key, label.text, label))
	sliders[key] = slider


func _bind_toggle(toggle: CheckButton, pressed: bool, key: StringName) -> void:
	toggle.button_pressed = pressed
	toggle.toggled.connect(_on_toggle_changed.bind(key))


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
	waiting_for_secondary_active_skill_key = false
	active_skill_bind_button.text = tr("PRESS A KEY - ESC TO CANCEL")
	active_skill_bind_button.release_focus()


func _begin_secondary_active_skill_rebind() -> void:
	waiting_for_active_skill_key = false
	waiting_for_secondary_active_skill_key = true
	secondary_active_skill_bind_button.text = tr("PRESS A KEY - ESC TO CANCEL")
	secondary_active_skill_bind_button.release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		not waiting_for_active_skill_key
		and not waiting_for_secondary_active_skill_key
	) or not event.pressed or event.echo:
		return
	if waiting_for_active_skill_key:
		waiting_for_active_skill_key = false
		if event.keycode != KEY_ESCAPE:
			settings.call("set_active_skill_keycode", event.physical_keycode)
	else:
		waiting_for_secondary_active_skill_key = false
		if event.keycode != KEY_ESCAPE:
			settings.call(
				"set_secondary_active_skill_keycode", event.physical_keycode
			)
	active_skill_bind_button.text = "%s: %s" % [
		tr("ACTIVE SKILL"),
		String(settings.call("get_active_skill_key_text")),
	]
	secondary_active_skill_bind_button.text = "%s: %s" % [
		tr("SECONDARY ACTIVE SKILL"),
		String(settings.call("get_secondary_active_skill_key_text")),
	]
	get_viewport().set_input_as_handled()
