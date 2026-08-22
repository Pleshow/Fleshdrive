extends Node


signal visual_settings_changed
signal audio_settings_changed
signal language_changed(language_code: String)
signal display_settings_changed

const SETTINGS_PATH := "user://fleshdrive_settings.cfg"
const MASTER_SECTION := "settings"
const SYSTEM_SECTION := "system"
const SAVE_VERSION := 3
const BIT_REDUCER_EFFECT_NAME := "FleshdriveBitReducer"
const DEFAULT_MASTER_VOLUME: float = 100.0
const DEFAULT_CRT_INTENSITY: float = 0.14
const DEFAULT_BLOOM_INTENSITY: float = 0.055
const DEFAULT_CHROMATIC_ABERRATION: float = 0.04
const DEFAULT_BIT_REDUCTION: float = 0.42
const DEFAULT_MUSIC_VOLUME: float = 82.0
const DEFAULT_SFX_VOLUME: float = 88.0
const DEFAULT_UI_VOLUME: float = 86.0
const DEFAULT_SCREEN_SHAKE: float = 0.72
const DEFAULT_VFX_INTENSITY: float = 0.82
const DEFAULT_FLASH_INTENSITY: float = 0.80
const DEFAULT_CONTROLLER_DEADZONE: float = 0.20
const DEFAULT_AIM_SENSITIVITY: float = 1.0
const DEFAULT_CROSSHAIR_SCALE: float = 1.0
const DEFAULT_AIM_ASSIST: float = 0.35
const DEFAULT_LANGUAGE := "en"
const DEFAULT_ACTIVE_SKILL_KEY: Key = KEY_E
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1280, 720)
const RESOLUTION_PRESETS := [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const LANGUAGE_OPTIONS := [
	{"code": "en", "label": "ENGLISH", "enabled": true},
	{"code": "hu", "label": "MAGYAR", "enabled": true},
]

var master_volume: float = DEFAULT_MASTER_VOLUME
var crt_intensity: float = DEFAULT_CRT_INTENSITY
var bloom_intensity: float = DEFAULT_BLOOM_INTENSITY
var chromatic_aberration: float = DEFAULT_CHROMATIC_ABERRATION
var bit_reduction: float = DEFAULT_BIT_REDUCTION
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var ui_volume: float = DEFAULT_UI_VOLUME
var screen_shake_intensity: float = DEFAULT_SCREEN_SHAKE
var vfx_intensity: float = DEFAULT_VFX_INTENSITY
var flash_intensity: float = DEFAULT_FLASH_INTENSITY
var controller_deadzone: float = DEFAULT_CONTROLLER_DEADZONE
var aim_sensitivity: float = DEFAULT_AIM_SENSITIVITY
var crosshair_scale: float = DEFAULT_CROSSHAIR_SCALE
var aim_assist_strength: float = DEFAULT_AIM_ASSIST
var damage_numbers_enabled: bool = true
var tutorials_enabled: bool = true
var shaders_enabled: bool = true
var language_code: String = DEFAULT_LANGUAGE
var active_skill_keycode: Key = DEFAULT_ACTIVE_SKILL_KEY
var fullscreen_enabled: bool = true
# Vector2i.ZERO means native desktop resolution in fullscreen mode.
var selected_resolution: Vector2i = Vector2i.ZERO

var _bit_reducer_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	if not get_tree().node_added.is_connected(_on_runtime_node_added):
		get_tree().node_added.connect(_on_runtime_node_added)
	_apply_display_settings()
	TranslationServer.set_locale(language_code)
	_ensure_bit_reducer()
	_apply_audio_settings()
	_apply_input_settings()
	_apply_active_skill_binding()
	_apply_shader_setting.call_deferred()


func set_master_volume(value: float, save: bool = true) -> void:
	master_volume = clampf(value, 0.0, 100.0)
	_apply_audio_settings()
	audio_settings_changed.emit()
	if save:
		_save_settings()


func set_crt_intensity(value: float, save: bool = true) -> void:
	crt_intensity = clampf(value, 0.0, 1.0)
	visual_settings_changed.emit()
	if save:
		_save_settings()


func set_bloom_intensity(value: float, save: bool = true) -> void:
	bloom_intensity = clampf(value, 0.0, 1.0)
	visual_settings_changed.emit()
	if save:
		_save_settings()


func set_chromatic_aberration(
	value: float,
	save: bool = true
) -> void:
	chromatic_aberration = clampf(value, 0.0, 1.0)
	visual_settings_changed.emit()
	if save:
		_save_settings()


func set_bit_reduction(value: float, save: bool = true) -> void:
	bit_reduction = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	audio_settings_changed.emit()
	if save:
		_save_settings()


func set_bus_volume(bus_name: StringName, value: float, save: bool = true) -> void:
	var clamped := clampf(value, 0.0, 100.0)
	match bus_name:
		&"Music": music_volume = clamped
		&"SFX": sfx_volume = clamped
		&"UI": ui_volume = clamped
		_: return
	_apply_audio_settings()
	audio_settings_changed.emit()
	if save:
		_save_settings()


func set_gameplay_setting(key: StringName, value: Variant, save: bool = true) -> void:
	match key:
		&"screen_shake": screen_shake_intensity = clampf(float(value), 0.0, 1.0)
		&"vfx_intensity": vfx_intensity = clampf(float(value), 0.0, 1.0)
		&"flash_intensity": flash_intensity = clampf(float(value), 0.0, 1.0)
		&"controller_deadzone":
			controller_deadzone = clampf(float(value), 0.05, 0.55)
			_apply_input_settings()
		&"aim_sensitivity": aim_sensitivity = clampf(float(value), 0.25, 2.0)
		&"crosshair_scale": crosshair_scale = clampf(float(value), 0.65, 1.75)
		&"aim_assist": aim_assist_strength = clampf(float(value), 0.0, 1.0)
		&"damage_numbers": damage_numbers_enabled = bool(value)
		&"tutorials": tutorials_enabled = bool(value)
		&"shaders":
			shaders_enabled = bool(value)
			_apply_shader_setting()
		_: return
	visual_settings_changed.emit()
	if save:
		_save_settings()


func set_language(code: String, save: bool = true) -> bool:
	for option in LANGUAGE_OPTIONS:
		if String(option.get("code", "")) != code:
			continue
		if not bool(option.get("enabled", false)):
			return false
		language_code = code
		TranslationServer.set_locale(language_code)
		language_changed.emit(language_code)
		if save:
			_save_settings()
		return true
	return false


func get_language_options() -> Array:
	return LANGUAGE_OPTIONS.duplicate(true)


func get_resolution_options() -> Array[Dictionary]:
	var screen_size := _get_current_screen_size()
	var options: Array[Dictionary] = [{
		"size": Vector2i.ZERO,
		"label": "%s (%d x %d)" % [
			tr("NATIVE"),
			screen_size.x,
			screen_size.y,
		],
	}]
	for resolution in RESOLUTION_PRESETS:
		if resolution.x > screen_size.x or resolution.y > screen_size.y:
			continue
		options.append({
			"size": resolution,
			"label": "%d x %d" % [resolution.x, resolution.y],
		})
	if (
		selected_resolution != Vector2i.ZERO
		and selected_resolution.x > 0
		and not _resolution_options_contain(options, selected_resolution)
	):
		options.append({
			"size": selected_resolution,
			"label": "%d x %d" % [
				selected_resolution.x,
				selected_resolution.y,
			],
		})
	return options


func set_fullscreen(enabled: bool, save: bool = true) -> void:
	fullscreen_enabled = enabled
	_apply_display_settings()
	display_settings_changed.emit()
	if save:
		_save_settings()


func set_resolution(resolution: Vector2i, save: bool = true) -> void:
	if resolution != Vector2i.ZERO and (
		resolution.x < 960 or resolution.y < 540
	):
		return
	selected_resolution = resolution
	_apply_display_settings()
	display_settings_changed.emit()
	if save:
		_save_settings()


func set_active_skill_keycode(keycode: Key, save: bool = true) -> void:
	if keycode == KEY_NONE:
		return
	active_skill_keycode = keycode
	_apply_active_skill_binding()
	if save:
		_save_settings()


func get_active_skill_key_text() -> String:
	return OS.get_keycode_string(active_skill_keycode)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var repository := get_tree().root.get_node_or_null("SaveRepository")
	if repository != null:
		var result := Dictionary(repository.call(
			"load_versioned", SETTINGS_PATH, SAVE_VERSION
		))
		if not bool(result.get("ok", false)):
			return
		config = result.get("config") as ConfigFile
		if bool(result.get("recovered_from_backup", false)):
			push_warning("GameSettings: recovered settings from backup.")
	else:
		if config.load(SETTINGS_PATH) != OK:
			return

	master_volume = clampf(
		float(config.get_value(MASTER_SECTION, "master_volume", master_volume)),
		0.0,
		100.0
	)
	crt_intensity = clampf(
		float(config.get_value(MASTER_SECTION, "crt", crt_intensity)),
		0.0,
		1.0
	)
	bloom_intensity = clampf(
		float(config.get_value(MASTER_SECTION, "bloom", bloom_intensity)),
		0.0,
		1.0
	)
	chromatic_aberration = clampf(
		float(
			config.get_value(
				MASTER_SECTION,
				"chromatic_aberration",
				chromatic_aberration
			)
		),
		0.0,
		1.0
	)
	bit_reduction = clampf(
		float(config.get_value(MASTER_SECTION, "bit_reduction", bit_reduction)),
		0.0,
		1.0
	)
	music_volume = clampf(float(config.get_value(MASTER_SECTION, "music_volume", music_volume)), 0.0, 100.0)
	sfx_volume = clampf(float(config.get_value(MASTER_SECTION, "sfx_volume", sfx_volume)), 0.0, 100.0)
	ui_volume = clampf(float(config.get_value(MASTER_SECTION, "ui_volume", ui_volume)), 0.0, 100.0)
	screen_shake_intensity = clampf(float(config.get_value(MASTER_SECTION, "screen_shake", screen_shake_intensity)), 0.0, 1.0)
	vfx_intensity = clampf(float(config.get_value(MASTER_SECTION, "vfx_intensity", vfx_intensity)), 0.0, 1.0)
	flash_intensity = clampf(float(config.get_value(MASTER_SECTION, "flash_intensity", flash_intensity)), 0.0, 1.0)
	controller_deadzone = clampf(float(config.get_value(MASTER_SECTION, "controller_deadzone", controller_deadzone)), 0.05, 0.55)
	aim_sensitivity = clampf(float(config.get_value(MASTER_SECTION, "aim_sensitivity", aim_sensitivity)), 0.25, 2.0)
	crosshair_scale = clampf(float(config.get_value(MASTER_SECTION, "crosshair_scale", crosshair_scale)), 0.65, 1.75)
	aim_assist_strength = clampf(float(config.get_value(MASTER_SECTION, "aim_assist", aim_assist_strength)), 0.0, 1.0)
	damage_numbers_enabled = bool(config.get_value(MASTER_SECTION, "damage_numbers", damage_numbers_enabled))
	tutorials_enabled = bool(config.get_value(MASTER_SECTION, "tutorials", tutorials_enabled))
	shaders_enabled = bool(config.get_value(MASTER_SECTION, "shaders", shaders_enabled))
	language_code = String(config.get_value(
		MASTER_SECTION,
		"language",
		DEFAULT_LANGUAGE
	))
	if language_code not in ["en", "hu"]:
		language_code = DEFAULT_LANGUAGE
	active_skill_keycode = int(config.get_value(
		MASTER_SECTION,
		"active_skill_keycode",
		DEFAULT_ACTIVE_SKILL_KEY
	))
	fullscreen_enabled = bool(config.get_value(
		MASTER_SECTION,
		"fullscreen",
		fullscreen_enabled
	))
	var resolution_x := int(config.get_value(
		MASTER_SECTION,
		"resolution_x",
		0
	))
	var resolution_y := int(config.get_value(
		MASTER_SECTION,
		"resolution_y",
		0
	))
	selected_resolution = (
		Vector2i(resolution_x, resolution_y)
		if resolution_x >= 960 and resolution_y >= 540
		else Vector2i.ZERO
	)


func _save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SYSTEM_SECTION, "save_version", SAVE_VERSION)
	config.set_value(MASTER_SECTION, "master_volume", master_volume)
	config.set_value(MASTER_SECTION, "crt", crt_intensity)
	config.set_value(MASTER_SECTION, "bloom", bloom_intensity)
	config.set_value(
		MASTER_SECTION,
		"chromatic_aberration",
		chromatic_aberration
	)
	config.set_value(MASTER_SECTION, "bit_reduction", bit_reduction)
	config.set_value(MASTER_SECTION, "music_volume", music_volume)
	config.set_value(MASTER_SECTION, "sfx_volume", sfx_volume)
	config.set_value(MASTER_SECTION, "ui_volume", ui_volume)
	config.set_value(MASTER_SECTION, "screen_shake", screen_shake_intensity)
	config.set_value(MASTER_SECTION, "vfx_intensity", vfx_intensity)
	config.set_value(MASTER_SECTION, "flash_intensity", flash_intensity)
	config.set_value(MASTER_SECTION, "controller_deadzone", controller_deadzone)
	config.set_value(MASTER_SECTION, "aim_sensitivity", aim_sensitivity)
	config.set_value(MASTER_SECTION, "crosshair_scale", crosshair_scale)
	config.set_value(MASTER_SECTION, "aim_assist", aim_assist_strength)
	config.set_value(MASTER_SECTION, "damage_numbers", damage_numbers_enabled)
	config.set_value(MASTER_SECTION, "tutorials", tutorials_enabled)
	config.set_value(MASTER_SECTION, "shaders", shaders_enabled)
	config.set_value(MASTER_SECTION, "language", language_code)
	config.set_value(MASTER_SECTION, "active_skill_keycode", int(active_skill_keycode))
	config.set_value(MASTER_SECTION, "fullscreen", fullscreen_enabled)
	config.set_value(MASTER_SECTION, "resolution_x", selected_resolution.x)
	config.set_value(MASTER_SECTION, "resolution_y", selected_resolution.y)
	var repository := get_tree().root.get_node_or_null("SaveRepository")
	var save_error := (
		int(repository.call("commit", config, SETTINGS_PATH, SAVE_VERSION))
		if repository != null
		else config.save(SETTINGS_PATH)
	)
	if save_error != OK:
		push_error("GameSettings: unable to save settings (%s)." % error_string(save_error))
		return false
	return true


func _apply_audio_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return

	var normalized_volume := master_volume / 100.0
	AudioServer.set_bus_mute(master_bus, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(
		master_bus,
		linear_to_db(maxf(normalized_volume, 0.0001))
	)
	_apply_bus_volume(&"Music", music_volume)
	_apply_bus_volume(&"SFX", sfx_volume)
	_apply_bus_volume(&"UI", ui_volume)

	_ensure_bit_reducer()
	if _bit_reducer_index < 0:
		return

	var effect := AudioServer.get_bus_effect(
		master_bus,
		_bit_reducer_index
	) as AudioEffectDistortion
	if effect != null:
		effect.mode = AudioEffectDistortion.MODE_LOFI
		effect.drive = lerpf(0.0, 0.82, bit_reduction)
		effect.pre_gain = lerpf(0.0, -5.0, bit_reduction)
		effect.keep_hf_hz = lerpf(16000.0, 2200.0, bit_reduction)

	AudioServer.set_bus_effect_enabled(
		master_bus,
		_bit_reducer_index,
		bit_reduction > 0.001
	)


func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.0001)))


func _apply_input_settings() -> void:
	for action in [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"aim_left", &"aim_right", &"aim_up", &"aim_down",
	]:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, controller_deadzone)


func _apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var resolution := selected_resolution
	if fullscreen_enabled:
		if resolution == Vector2i.ZERO:
			# Borderless native fullscreen always covers the complete display.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			# An explicit fullscreen resolution uses the platform's exclusive
			# mode so the selected output mode is actually applied.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if resolution == Vector2i.ZERO:
		resolution = DEFAULT_WINDOW_RESOLUTION
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(
		screen_position + (screen_size - resolution) / 2
	)


func _get_current_screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i(3840, 2160)
	return DisplayServer.screen_get_size(
		DisplayServer.window_get_current_screen()
	)


func _resolution_options_contain(
	options: Array[Dictionary],
	resolution: Vector2i
) -> bool:
	for option in options:
		if Vector2i(option.get("size", Vector2i.ZERO)) == resolution:
			return true
	return false


func _apply_active_skill_binding() -> void:
	if not InputMap.has_action(&"active_skill"):
		InputMap.add_action(&"active_skill")
	for event in InputMap.action_get_events(&"active_skill"):
		if event is InputEventKey:
			InputMap.action_erase_event(&"active_skill", event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = active_skill_keycode
	InputMap.action_add_event(&"active_skill", key_event)


func _ensure_bit_reducer() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return

	for effect_index in range(
		AudioServer.get_bus_effect_count(master_bus)
	):
		var effect := AudioServer.get_bus_effect(master_bus, effect_index)
		if effect.resource_name == BIT_REDUCER_EFFECT_NAME:
			_bit_reducer_index = effect_index
			return

	var bit_reducer := AudioEffectDistortion.new()
	bit_reducer.resource_name = BIT_REDUCER_EFFECT_NAME
	bit_reducer.mode = AudioEffectDistortion.MODE_LOFI
	AudioServer.add_bus_effect(master_bus, bit_reducer)
	_bit_reducer_index = (
		AudioServer.get_bus_effect_count(master_bus) - 1
	)


func _on_runtime_node_added(node: Node) -> void:
	if shaders_enabled:
		return
	_disable_shader_subtree.call_deferred(node)


func _apply_shader_setting() -> void:
	if shaders_enabled:
		for node in get_tree().get_nodes_in_group("shader_toggle_disabled"):
			if not is_instance_valid(node) or not node is CanvasItem:
				continue
			var item := node as CanvasItem
			if item.has_meta("shader_toggle_saved_material"):
				item.material = item.get_meta(
					"shader_toggle_saved_material"
				) as Material
				item.remove_meta("shader_toggle_saved_material")
			item.remove_from_group("shader_toggle_disabled")
		return
	_disable_shader_subtree(get_tree().root)


func _disable_shader_subtree(node_value: Variant) -> void:
	if not is_instance_valid(node_value):
		return
	var node := node_value as Node
	if node == null:
		return
	if node is CanvasItem and not node.is_in_group("shader_toggle_hide"):
		var item := node as CanvasItem
		if item.material is ShaderMaterial:
			if not item.has_meta("shader_toggle_saved_material"):
				item.set_meta("shader_toggle_saved_material", item.material)
			item.material = null
			if not item.is_in_group("shader_toggle_disabled"):
				item.add_to_group("shader_toggle_disabled")
	for child in node.get_children():
		_disable_shader_subtree(child)
