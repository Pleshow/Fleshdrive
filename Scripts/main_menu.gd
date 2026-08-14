class_name MainMenu
extends Control


const GAME_SCENE_PATH := "res://Scenes/game.tscn"
const InkIcons = preload("res://Scripts/visual/ink_crimson_icon_factory.gd")

@export var minimum_loading_seconds: float = 5.0

@onready var main_panel: VBoxContainer = %MainPanel
@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var menu_shell: PanelContainer = $MenuShell
@onready var prototype_info_panel: PanelContainer = %PrototypeInfoPanel
@onready var prototype_header_label: Label = $PrototypeInfoPanel/Margin/Content/Header
@onready var prototype_profile_label: Label = $PrototypeInfoPanel/Margin/Content/Profile
@onready var prototype_record_header_label: Label = $PrototypeInfoPanel/Margin/Content/BuildHeader
@onready var prototype_record_label: Label = $PrototypeInfoPanel/Margin/Content/Build
@onready var prototype_meta_label: Label = $PrototypeInfoPanel/Margin/Content/Hint
@onready var shell_margin: MarginContainer = $MenuShell/MarginContainer
@onready var version_label: Label = $VersionLabel
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var skill_tree_button: Button = %SkillTreeButton
@onready var quit_button: Button = %QuitButton
@onready var skill_tree_panel: SkillTreePanel = %SkillTreePanel
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var language_option: OptionButton = %LanguageOption
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var crt_slider: HSlider = %CRTSlider
@onready var crt_value_label: Label = %CRTValueLabel
@onready var bloom_slider: HSlider = %BloomSlider
@onready var bloom_value_label: Label = %BloomValueLabel
@onready var chromatic_slider: HSlider = %ChromaticSlider
@onready var chromatic_value_label: Label = %ChromaticValueLabel
@onready var bit_reducer_slider: HSlider = %BitReducerSlider
@onready var bit_reducer_value_label: Label = %BitReducerValueLabel
@onready var back_button: Button = %BackButton
@onready var loading_screen: LoadingScreen = $LoadingScreen
@onready var title_label: Label = $MenuShell/MarginContainer/Content/Title
@onready var subtitle_label: Label = $MenuShell/MarginContainer/Content/Subtitle
@onready var title_separator: HSeparator = $MenuShell/MarginContainer/Content/Separator

var game_loading: bool = false
var arena_selector_panel: PanelContainer
var arena_option: OptionButton
var arena_description_label: Label


func _ready() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("force_state", &"MENU", false)
	_raise_menu_ui_above_post_process()
	_install_ink_crimson_icons()
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_open_settings)
	skill_tree_button.pressed.connect(_open_skill_tree)
	quit_button.pressed.connect(_on_quit_pressed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	language_option.item_selected.connect(_on_language_selected)
	volume_slider.value_changed.connect(_on_volume_changed)
	crt_slider.value_changed.connect(_on_crt_changed)
	bloom_slider.value_changed.connect(_on_bloom_changed)
	chromatic_slider.value_changed.connect(_on_chromatic_changed)
	bit_reducer_slider.value_changed.connect(_on_bit_reducer_changed)
	back_button.pressed.connect(_close_settings)
	skill_tree_panel.back_requested.connect(_close_skill_tree)
	_install_arena_selector()
	_connect_button_sounds()
	resized.connect(_update_responsive_layout)

	_sync_settings_controls()
	_install_gameplay_settings_controls()
	_populate_language_options()
	_refresh_dynamic_localization()
	_update_responsive_layout()
	main_panel.show()
	settings_panel.hide()
	_animate_ui_in(menu_shell, 0.34)
	play_button.grab_focus()
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		meta_progression.statistics_changed.connect(
			_on_meta_statistics_changed
		)
	if (
		meta_progression != null
		and bool(meta_progression.call(
			"consume_flesh_tree_request"
		))
	):
		_open_skill_tree()


func _install_ink_crimson_icons() -> void:
	var icon_bindings := {
		play_button: InkIcons.make_icon(&"play"),
		settings_button: InkIcons.make_icon(&"settings"),
		skill_tree_button: InkIcons.make_icon(&"organ", true),
		quit_button: InkIcons.make_icon(&"exit", true),
	}
	for button_variant in icon_bindings:
		var button := button_variant as Button
		button.icon = icon_bindings[button]
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _raise_menu_ui_above_post_process() -> void:
	# The vignette belongs to the background presentation. Menu controls must
	# remain crisp. Keep the public UI node paths stable and move only the
	# background presentation to lower canvas layers.
	var background_layer := CanvasLayer.new()
	background_layer.name = "MenuBackgroundLayer"
	background_layer.layer = -110
	add_child(background_layer)
	for background_node in [$Background, $LeftShade]:
		var presentation_copy := background_node.duplicate() as Control
		background_layer.add_child(presentation_copy)
		background_node.hide()
	var post_process := get_node_or_null("PostProcess") as CanvasLayer
	if post_process != null:
		post_process.layer = -100


func _update_responsive_layout() -> void:
	if not is_instance_valid(menu_shell):
		return
	var viewport_size := get_viewport_rect().size
	if settings_panel.visible:
		shell_margin.add_theme_constant_override("margin_left", 54)
		shell_margin.add_theme_constant_override("margin_top", 52)
		shell_margin.add_theme_constant_override("margin_right", 54)
		shell_margin.add_theme_constant_override("margin_bottom", 46)
		var settings_size := Vector2(
			minf(viewport_size.x - 80.0, 900.0),
			minf(viewport_size.y - 44.0, 672.0)
		)
		menu_shell.size = settings_size
		menu_shell.position = Vector2(
			(viewport_size.x - settings_size.x) * 0.5,
			clampf(
				(viewport_size.y - settings_size.y) * 0.5,
				22.0,
				64.0
			)
		)
		return
	shell_margin.add_theme_constant_override("margin_left", 42)
	shell_margin.add_theme_constant_override("margin_top", 58)
	shell_margin.add_theme_constant_override("margin_right", 42)
	shell_margin.add_theme_constant_override("margin_bottom", 44)
	menu_shell.size = Vector2(
		clampf(viewport_size.x * 0.31, 390.0, 610.0),
		clampf(viewport_size.y - 104.0, 650.0, 930.0)
	)
	var safe_left := clampf(viewport_size.x * 0.012, 12.0, 24.0)
	var safe_top := clampf(
		(viewport_size.y - menu_shell.size.y) * 0.5,
		30.0,
		52.0
	)
	menu_shell.position = Vector2(safe_left, safe_top)
	title_label.add_theme_font_size_override(
		"font_size", clampi(roundi(menu_shell.size.x * 0.115), 46, 70)
	)
	var button_width := clampf(menu_shell.size.x - 96.0, 300.0, 420.0)
	for button in [play_button, settings_button, skill_tree_button, quit_button]:
		button.custom_minimum_size = Vector2(
			button_width,
			62.0 if viewport_size.y < 800.0 else 70.0
		)
	prototype_info_panel.visible = viewport_size.x >= 1050.0
	# The profile is a fixed-height header card. Set all four offsets explicitly
	# so Control growth/minimum-size resolution cannot stretch it to the bottom.
	prototype_info_panel.anchor_left = 0.0
	prototype_info_panel.anchor_top = 0.0
	prototype_info_panel.anchor_right = 0.0
	prototype_info_panel.anchor_bottom = 0.0
	prototype_info_panel.grow_horizontal = Control.GROW_DIRECTION_END
	prototype_info_panel.grow_vertical = Control.GROW_DIRECTION_END
	var profile_size := Vector2(
		clampf(viewport_size.x * 0.34, 460.0, 660.0),
		230.0
	)
	var profile_position := Vector2(
		clampf(
			viewport_size.x * 0.46,
			menu_shell.position.x + menu_shell.size.x + 34.0,
			viewport_size.x - profile_size.x - 48.0
		),
		clampf(viewport_size.y * 0.045, 28.0, 48.0)
	)
	prototype_info_panel.offset_left = profile_position.x
	prototype_info_panel.offset_top = profile_position.y
	prototype_info_panel.offset_right = profile_position.x + profile_size.x
	prototype_info_panel.offset_bottom = profile_position.y + profile_size.y


func _install_arena_selector() -> void:
	if main_panel.get_node_or_null("ArenaSelectorPanel") != null:
		return
	arena_selector_panel = PanelContainer.new()
	arena_selector_panel.name = "ArenaSelectorPanel"
	arena_selector_panel.custom_minimum_size = Vector2(0.0, 78.0)
	arena_selector_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.055, 0.055, 0.94)
	panel_style.border_color = Color(0.20, 0.62, 0.66, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	arena_selector_panel.add_theme_stylebox_override("panel", panel_style)
	main_panel.add_child(arena_selector_panel)
	main_panel.move_child(arena_selector_panel, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 7)
	arena_selector_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var title := Label.new()
	title.text = "RUN SITE"
	title.custom_minimum_size = Vector2(78.0, 0.0)
	title.add_theme_color_override("font_color", Color(0.48, 0.90, 0.92))
	title.add_theme_font_size_override("font_size", 13)
	row.add_child(title)
	arena_option = OptionButton.new()
	arena_option.name = "ArenaOption"
	arena_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_option.custom_minimum_size = Vector2(0.0, 34.0)
	arena_option.add_item("BIO-LAB")
	arena_option.set_item_metadata(0, &"bio_lab")
	arena_option.add_item("SLUDGEWORKS")
	arena_option.set_item_metadata(1, &"sludgeworks")
	arena_option.add_item("DUSK GARDEN")
	arena_option.set_item_metadata(2, &"dusk_garden")
	arena_option.tooltip_text = "Select the arena used by the next run."
	row.add_child(arena_option)
	arena_description_label = Label.new()
	arena_description_label.name = "ArenaDescription"
	arena_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	arena_description_label.add_theme_font_size_override("font_size", 11)
	content.add_child(arena_description_label)
	var selected_id := &"bio_lab"
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		selected_id = StringName(flow.get("selected_arena_id"))
	var selected_index := 0
	for item_index in range(arena_option.item_count):
		if StringName(arena_option.get_item_metadata(item_index)) == selected_id:
			selected_index = item_index
			break
	arena_option.select(selected_index)
	arena_option.item_selected.connect(_on_arena_selected)
	_refresh_arena_selector(selected_index)


func _on_arena_selected(index: int) -> void:
	if arena_option == null or index < 0 or index >= arena_option.item_count:
		return
	var arena_id := StringName(arena_option.get_item_metadata(index))
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null and flow.has_method("set_selected_arena"):
		flow.call("set_selected_arena", arena_id)
	_refresh_arena_selector(index)
	if arena_selector_panel != null:
		arena_selector_panel.modulate = Color(0.72, 1.0, 0.78, 1.0)
		var tween := create_tween()
		tween.tween_property(
			arena_selector_panel,
			"modulate",
			Color.WHITE,
			0.22
		)


func _refresh_arena_selector(index: int) -> void:
	if arena_description_label == null or arena_selector_panel == null:
		return
	var style := arena_selector_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var arena_id := StringName(arena_option.get_item_metadata(index))
	if arena_id == &"sludgeworks":
		arena_description_label.text = (
			"OPEN ISO DECK  //  GREEN RUNOFF IS IMPASSABLE"
		)
		arena_description_label.add_theme_color_override(
			"font_color",
			Color(0.48, 0.92, 0.50)
		)
		if style != null:
			style.border_color = Color(0.22, 0.92, 0.30, 0.78)
	elif arena_id == &"dusk_garden":
		arena_description_label.text = (
			"OPEN NIGHT FIELD  //  SHARP PIXELS, HIGH-CONTRAST HORDES"
		)
		arena_description_label.add_theme_color_override(
			"font_color",
			Color(0.54, 0.84, 1.0)
		)
		if style != null:
			style.border_color = Color(0.30, 0.66, 1.0, 0.84)
	else:
		arena_description_label.text = (
			"RECTILINEAR LAB  //  COVER LANES AND CONTAINMENT WALLS"
		)
		arena_description_label.add_theme_color_override(
			"font_color",
			Color(0.42, 0.72, 0.76)
		)
		if style != null:
			style.border_color = Color(0.20, 0.62, 0.66, 0.72)


func _install_gameplay_settings_controls() -> void:
	var controls := %FullscreenToggle.get_parent()
	var margin := controls.get_parent()
	if margin.get_node_or_null("SettingsTabs") != null:
		return
	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Leave room for the textured outer frame and localized back action at 720p.
	tabs.custom_minimum_size = Vector2(0.0, 360.0)
	margin.add_child(tabs)
	controls.reparent(tabs)
	controls.name = "DISPLAY & AUDIO"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var gameplay_page := VBoxContainer.new()
	gameplay_page.name = "GAMEPLAY & ACCESSIBILITY"
	gameplay_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(gameplay_page)
	var gameplay_controls := GameplaySettingsControls.new()
	gameplay_controls.name = "GameplaySettings"
	gameplay_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_page.add_child(gameplay_controls)
	fullscreen_toggle.flat = true


func _connect_button_sounds() -> void:
	var confirm_buttons: Array[BaseButton] = [
		play_button,
		settings_button,
		skill_tree_button,
		quit_button,
		fullscreen_toggle,
	]
	if arena_option != null:
		confirm_buttons.append(arena_option)

	for button in confirm_buttons:
		button.mouse_entered.connect(_play_ui_hover)
		button.pressed.connect(_play_ui_confirm)

	back_button.mouse_entered.connect(_play_ui_hover)
	back_button.pressed.connect(_play_ui_cancel)
	skill_tree_panel.back_button.mouse_entered.connect(_play_ui_hover)
	skill_tree_panel.back_button.pressed.connect(_play_ui_cancel)


func _play_ui_hover() -> void:
	_play_sound(&"ui_hover", -7.0, 0.025, &"UI")


func _play_ui_confirm() -> void:
	_play_sound(&"ui_confirm", -5.0, 0.02, &"UI")


func _play_ui_cancel() -> void:
	_play_sound(&"ui_cancel", -5.0, 0.02, &"UI")


func _play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float,
	bus_name: StringName
) -> void:
	if not is_inside_tree():
		return
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			sound_id,
			volume_db,
			pitch_variation,
			bus_name
		)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if skill_tree_panel.visible:
		_close_skill_tree()
		get_viewport().set_input_as_handled()
	elif settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()


func _on_play_pressed() -> void:
	if game_loading:
		return
	game_loading = true
	play_button.disabled = true
	loading_screen.begin()
	var started_at := Time.get_ticks_msec()
	var request_error := ResourceLoader.load_threaded_request(
		GAME_SCENE_PATH,
		"PackedScene",
		true
	)
	if request_error != OK:
		push_error("MainMenu: unable to begin threaded game loading.")
		game_loading = false
		play_button.disabled = false
		loading_screen.hide()
		return
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(
			GAME_SCENE_PATH,
			progress
		)
		if not progress.is_empty():
			loading_screen.set_resource_progress(float(progress[0]))
		var elapsed := (
			float(Time.get_ticks_msec() - started_at) / 1000.0
		)
		if (
			status == ResourceLoader.THREAD_LOAD_LOADED
			and elapsed >= minimum_loading_seconds
		):
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("MainMenu: threaded game loading failed.")
			game_loading = false
			play_button.disabled = false
			loading_screen.hide()
			return
		await get_tree().process_frame
	loading_screen.complete()
	await get_tree().create_timer(0.12, true).timeout
	var game_scene := ResourceLoader.load_threaded_get(
		GAME_SCENE_PATH
	) as PackedScene
	if game_scene == null:
		game_loading = false
		play_button.disabled = false
		loading_screen.hide()
		return
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("prepare_scene_change")
	get_tree().change_scene_to_packed(game_scene)


func _open_settings() -> void:
	main_panel.hide()
	prototype_info_panel.hide()
	title_label.hide()
	subtitle_label.hide()
	title_separator.hide()
	settings_panel.show()
	_update_responsive_layout.call_deferred()
	fullscreen_toggle.release_focus()


func _close_settings() -> void:
	settings_panel.hide()
	title_label.show()
	subtitle_label.show()
	title_separator.show()
	main_panel.show()
	_update_responsive_layout()
	_animate_ui_in(main_panel)
	settings_button.grab_focus()


func _open_skill_tree() -> void:
	menu_shell.hide()
	prototype_info_panel.hide()
	version_label.hide()
	skill_tree_panel.open()


func _close_skill_tree() -> void:
	skill_tree_panel.hide()
	menu_shell.show()
	prototype_info_panel.show()
	_refresh_prototype_profile()
	_update_responsive_layout()
	version_label.show()
	_animate_ui_in(menu_shell)
	skill_tree_button.grab_focus()


func _animate_ui_in(
	control: Control,
	duration: float = 0.22
) -> void:
	var polish := get_tree().root.get_node_or_null("UIPolish")
	if polish != null:
		polish.call("animate_in", control, duration)


func _on_fullscreen_toggled(enabled: bool) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.call("set_fullscreen", enabled)
	_update_responsive_layout.call_deferred()


func _sync_settings_controls() -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	fullscreen_toggle.set_pressed_no_signal(bool(settings.fullscreen_enabled))
	_populate_resolution_options()
	volume_slider.set_value_no_signal(float(settings.master_volume))
	crt_slider.set_value_no_signal(
		float(settings.crt_intensity) * 100.0
	)
	bloom_slider.set_value_no_signal(
		float(settings.bloom_intensity) * 100.0
	)
	chromatic_slider.set_value_no_signal(
		float(settings.chromatic_aberration) * 100.0
	)
	bit_reducer_slider.set_value_no_signal(
		float(settings.bit_reduction) * 100.0
	)
	_update_volume_value_label(volume_slider.value)
	_update_effect_value_label(crt_value_label, crt_slider.value)
	_update_effect_value_label(bloom_value_label, bloom_slider.value)
	_update_effect_value_label(
		chromatic_value_label,
		chromatic_slider.value
	)
	_update_effect_value_label(
		bit_reducer_value_label,
		bit_reducer_slider.value
	)


func _populate_resolution_options() -> void:
	resolution_option.clear()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	var selected_index := 0
	for option in settings.call("get_resolution_options"):
		var index := resolution_option.item_count
		resolution_option.add_item(String(option.get("label", "")))
		var resolution := Vector2i(option.get("size", Vector2i.ZERO))
		resolution_option.set_item_metadata(index, resolution)
		if resolution == Vector2i(settings.selected_resolution):
			selected_index = index
	resolution_option.select(selected_index)


func _on_resolution_selected(index: int) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	settings.call(
		"set_resolution",
		Vector2i(resolution_option.get_item_metadata(index))
	)
	_update_responsive_layout.call_deferred()


func _on_volume_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_master_volume(value)
	_update_volume_value_label(value)


func _populate_language_options() -> void:
	language_option.clear()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	var selected_index := 0
	for option in settings.call("get_language_options"):
		var index := language_option.item_count
		language_option.add_item(tr(String(option.get("label", ""))))
		language_option.set_item_metadata(index, String(option.get("code", "")))
		language_option.set_item_disabled(index, not bool(option.get("enabled", false)))
		if String(option.get("code", "")) == String(settings.language_code):
			selected_index = index
	language_option.select(selected_index)


func _on_language_selected(index: int) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	settings.call(
		"set_language",
		String(language_option.get_item_metadata(index))
	)
	_refresh_dynamic_localization()


func _refresh_dynamic_localization() -> void:
	_populate_language_options()
	var tabs := menu_shell.find_child("SettingsTabs", true, false) as TabContainer
	if tabs != null and tabs.get_tab_count() >= 2:
		tabs.set_tab_title(0, tr("DISPLAY & AUDIO"))
		tabs.set_tab_title(1, tr("GAMEPLAY & ACCESSIBILITY"))
	version_label.text = tr("PRE-ALPHA DEMO")
	_refresh_prototype_profile()


func _refresh_prototype_profile() -> void:
	var statistics := {
		"instance_label": "K0D4-001",
		"runs": 0,
		"deaths": 0,
		"boss_victories": 0,
		"best_time": 0.0,
		"total_kills": 0,
	}
	var progression := get_tree().root.get_node_or_null("MetaProgression")
	if progression != null and progression.has_method("get_statistics"):
		statistics = Dictionary(progression.call("get_statistics"))
	prototype_header_label.text = tr("PROFILE_HEADER")
	prototype_profile_label.text = "%s: K0D4" % tr("PROFILE_SUBJECT")
	prototype_record_header_label.text = tr("PROFILE_INSTANCE_RECORD")
	prototype_record_label.text = "%s: %s\n%s: %d\n%s: %d" % [
		tr("PROFILE_INSTANCE"),
		String(statistics.get("instance_label", "K0D4-001")),
		tr("PROFILE_REPRINTS"),
		int(statistics.get("deaths", 0)),
		tr("PROFILE_RUNS"),
		int(statistics.get("runs", 0)),
	]
	prototype_meta_label.text = "%s: %d  •  %s: %d\n%s: %s" % [
		tr("PROFILE_LIFETIME_KILLS"),
		int(statistics.get("total_kills", 0)),
		tr("PROFILE_BOSS_VICTORIES"),
		int(statistics.get("boss_victories", 0)),
		tr("PROFILE_BEST_SURVIVAL"),
		_format_profile_time(float(statistics.get("best_time", 0.0))),
	]


func _format_profile_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--"
	var total_seconds := maxi(roundi(seconds), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _on_meta_statistics_changed(_statistics: Dictionary) -> void:
	_refresh_prototype_profile()


func _update_volume_value_label(value: float) -> void:
	volume_value_label.text = "%d%%" % roundi(value)


func _on_crt_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_crt_intensity(value / 100.0)
	_update_effect_value_label(crt_value_label, value)


func _on_bloom_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_bloom_intensity(value / 100.0)
	_update_effect_value_label(bloom_value_label, value)


func _on_chromatic_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_chromatic_aberration(value / 100.0)
	_update_effect_value_label(chromatic_value_label, value)


func _on_bit_reducer_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_bit_reduction(value / 100.0)
	_update_effect_value_label(bit_reducer_value_label, value)


func _update_effect_value_label(label: Label, value: float) -> void:
	label.text = "OFF" if value <= 0.0 else "%d%%" % roundi(value)


func _on_quit_pressed() -> void:
	get_tree().quit()
