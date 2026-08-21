extends Control

const CardSelectionControllerScript := preload("res://Scripts/controllers/card_selection_controller.gd")
const OrganScreenControllerScript := preload("res://Scripts/controllers/organ_screen_controller.gd")
const BossPresentationControllerScript := preload("res://Scripts/controllers/boss_presentation_controller.gd")
const LabNoteIconScript := preload("res://Scripts/ui/lab_note_icon.gd")

const REFLEX_CORTEX_OFFER_LEVEL: int = 10
const AUTO_ATTACK_OFFER_LEVEL: int = 15
const EARLY_VOLTAIC_CORE_THROUGH_LEVEL: int = 5
const EARLY_SURVIVAL_THROUGH_LEVEL: int = 5
const EARLY_VOLTAIC_CORE_IDS: Array[StringName] = [
	&"arc_heart",
	&"ball_lightning",
	&"static_claws",
]
const SURVIVAL_UPGRADE_IDS: Array[StringName] = [
	&"reinforced_rib_cage",
	&"scavenger_stomach",
	&"reserve_bladder",
	&"reactive_hide",
	&"bone_plating",
	&"porcupine_reflex",
	&"hemo_recycler",
	&"cauterizing_blood",
]
const SURVIVAL_TAGS: Array[StringName] = [
	&"defense",
	&"healing",
	&"sustain",
	&"barrier",
]
const MAIN_MENU_SCENE_PATH := "res://Scenes/main_menu.tscn"
const KODA_PORTRAIT_TEXTURE := "res://Assets/player/idle.png"
const PAID_REROLL_COSTS: Array[int] = [2, 3, 5]

@export var upgrade_pool: Array[UpgradeData] = []
@onready var player_status_panel: Panel = $PlayerStatusPanel
@onready var koda_portrait: TextureRect = $PlayerStatusPanel/KodaPortrait
@onready var health_bar: ProgressBar = $PlayerStatusPanel/HealthBar
@onready var biomass_bar: ProgressBar = $BiomassBar
@onready var health_value_label: Label = (
	$PlayerStatusPanel/HealthValueLabel
)
@onready var biomass_value_label: Label = $BiomassValueLabel
@onready var level_label: Label = $PlayerStatusPanel/LevelLabel
@onready var run_timer_label: Label = $RunTimerLabel
@onready var run_state_label: Label = $RunStateLabel
@onready var rush_label: Label = $RushLabel
@onready var boss_warning_label: Label = $BossWarningLabel
@onready var boss_panel: Panel = $BossPanel
@onready var boss_health_bar: ProgressBar = $BossPanel/HealthBar
@onready var boss_phase_label: Label = $BossPanel/PhaseLabel

@onready var legs_slot: OrganSlotControl = (
	$OrganScreen/LegsSlot
)

@onready var heart_slot: OrganSlotControl = (
	$OrganScreen/HeartSlot
)

@onready var brain_slot: OrganSlotControl = (
	$OrganScreen/BrainSlot
)

@onready var level_up_panel: Control = $LevelUpPanel

@onready var title_label: Label = (
	$LevelUpPanel/CenterContainer/VBoxContainer/TitleLabel
)

@onready var upgrade_card_1: TextureButton = (
	$LevelUpPanel/CenterContainer/VBoxContainer/Cards/UpgradeCard1
)

@onready var upgrade_card_2: TextureButton = (
	$LevelUpPanel/CenterContainer/VBoxContainer/Cards/UpgradeCard2
)

@onready var upgrade_card_3: TextureButton = (
	$LevelUpPanel/CenterContainer/VBoxContainer/Cards/UpgradeCard3
)

@onready var organ_screen: Control = $OrganScreen

@onready var pending_organ_card: OrganDragCard = (
	$OrganScreen/PendingOrganCard
)
@onready var pending_organ_label: Label = $OrganScreen/PendingLabel
@onready var organ_close_button: Button = (
	$OrganScreen/CloseButton
)
@onready var replacement_confirmation: Control = (
	$OrganScreen/ReplacementConfirmation
)
@onready var replacement_message: Label = (
	$OrganScreen/ReplacementConfirmation/Center/Panel/Margin/Content/Message
)
@onready var replacement_yes_button: Button = (
	$OrganScreen/ReplacementConfirmation/Center/Panel/Margin/Content/Buttons/Yes
)
@onready var replacement_no_button: Button = (
	$OrganScreen/ReplacementConfirmation/Center/Panel/Margin/Content/Buttons/No
)
@onready var organ_stats_label: Label = (
	$OrganScreen/StatsLabel
)
@onready var weapon_summary: HBoxContainer = (
	$OrganScreen/WeaponSummary
)
@onready var item_summary: HBoxContainer = (
	$OrganScreen/ItemScroll/ItemSummary
)

@onready var pause_panel: Control = $PausePanel
@onready var pause_main_panel: VBoxContainer = (
	$PausePanel/CenterContainer/VBoxContainer
)
@onready var resume_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/ResumeButton
)
@onready var pause_restart_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/RestartButton
)
@onready var pause_settings_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/SettingsButton
)
@onready var pause_organ_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/OrganScreenButton
)
@onready var pause_main_menu_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/MainMenuButton
)
@onready var pause_quit_button: Button = (
	$PausePanel/CenterContainer/VBoxContainer/QuitButton
)
@onready var pause_settings_panel: VBoxContainer = (
	$PausePanel/CenterContainer/SettingsContainer
)
@onready var pause_fullscreen_toggle: CheckButton = (
	$PausePanel/CenterContainer/SettingsContainer/FullscreenToggle
)
@onready var pause_resolution_option: OptionButton = (
	$PausePanel/CenterContainer/SettingsContainer/ResolutionRow/ResolutionOption
)
@onready var pause_language_option: OptionButton = (
	$PausePanel/CenterContainer/SettingsContainer/LanguageRow/LanguageOption
)
@onready var pause_volume_slider: HSlider = (
	$PausePanel/CenterContainer/SettingsContainer/VolumeRow/VolumeSlider
)
@onready var pause_volume_value_label: Label = (
	$PausePanel/CenterContainer/SettingsContainer/VolumeRow/VolumeValueLabel
)
@onready var pause_crt_slider: HSlider = (
	$PausePanel/CenterContainer/SettingsContainer/CRTRow/CRTSlider
)
@onready var pause_crt_value_label: Label = (
	$PausePanel/CenterContainer/SettingsContainer/CRTRow/CRTValueLabel
)
@onready var pause_bloom_slider: HSlider = (
	$PausePanel/CenterContainer/SettingsContainer/BloomRow/BloomSlider
)
@onready var pause_bloom_value_label: Label = (
	$PausePanel/CenterContainer/SettingsContainer/BloomRow/BloomValueLabel
)
@onready var pause_chromatic_slider: HSlider = (
	$PausePanel/CenterContainer/SettingsContainer/ChromaticRow/ChromaticSlider
)
@onready var pause_chromatic_value_label: Label = (
	$PausePanel/CenterContainer/SettingsContainer/ChromaticRow/ChromaticValueLabel
)
@onready var pause_bit_reducer_slider: HSlider = (
	$PausePanel/CenterContainer/SettingsContainer/BitReducerRow/BitReducerSlider
)
@onready var pause_bit_reducer_value_label: Label = (
	$PausePanel/CenterContainer/SettingsContainer/BitReducerRow/BitReducerValueLabel
)
@onready var pause_settings_back_button: Button = (
	$PausePanel/CenterContainer/SettingsContainer/BackButton
)

@onready var run_end_panel: Control = $RunEndPanel
@onready var death_message: Control = $DeathMessage
@onready var run_end_title: Label = (
	$RunEndPanel/CenterContainer/VBoxContainer/TitleLabel
)
@onready var run_summary_label: Label = (
	$RunEndPanel/CenterContainer/VBoxContainer/SummaryLabel
)
@onready var end_restart_button: Button = (
	$RunEndPanel/CenterContainer/VBoxContainer/RestartButton
)
@onready var end_main_menu_button: Button = (
	$RunEndPanel/CenterContainer/VBoxContainer/MainMenuButton
)
@onready var end_quit_button: Button = (
	$RunEndPanel/CenterContainer/VBoxContainer/QuitButton
)
@onready var onboarding_panel: Control = $OnboardingPanel
@onready var onboarding_start_button: Button = (
	$OnboardingPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StartButton
)
@onready var onboarding_goal_label: Label = (
	$OnboardingPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GoalLabel
)
@onready var onboarding_instructions_label: Label = (
	$OnboardingPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/InstructionsLabel
)
@onready var onboarding_guide_button: Button = (
	$OnboardingPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GuideButton
)
@onready var onboarding_guide_label: Label = (
	$OnboardingPanel/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/GuideLabel
)
@onready var biofabricator_sequence: BiofabricatorSequence = (
	$BiofabricatorSequence
)
@onready var fleshdrive_operation_screen: FleshdriveOperationScreen = (
	$FleshdriveOperationScreen
)
@onready var fleshdrive_icon: TextureRect = (
	$OrganScreen/FleshdrivePanel/Icon
)
@onready var fleshdrive_name_label: Label = (
	$OrganScreen/FleshdrivePanel/Name
)
@onready var fleshdrive_level_label: Label = (
	$OrganScreen/FleshdrivePanel/Level
)
@onready var fleshdrive_build_label: Label = (
	$OrganScreen/FleshdrivePanel/Build
)



var player: Koda
var run_manager: RunManager
var displayed_upgrades: Array[UpgradeData] = []
var recently_offered_upgrade_levels: Dictionary = {}
var upgrade_cards: Array[TextureButton] = []
var bonus_upgrade_card: TextureButton
var pending_organ: UpgradeData
var pending_organs: Array[UpgradeData] = []
var pending_organ_index: int = -1
var offered_pending_organ: UpgradeData
var pending_previous_button: Button
var pending_next_button: Button
var pending_counter_label: Label
var card_selection := CardSelectionControllerScript.new()
var organ_session := OrganScreenControllerScript.new()
var boss_presentation := BossPresentationControllerScript.new()
# Compatibility properties keep existing scenes/tests stable while ownership
# lives in the dedicated controllers above.
var card_selection_locked: bool:
	get:
		return card_selection.locked
	set(value):
		card_selection.locked = value
var selected_upgrade_card_index: int:
	get:
		return card_selection.selected_index
	set(value):
		card_selection.selected_index = value
var upgrade_reroll_count: int:
	get:
		return card_selection.reroll_count
	set(value):
		card_selection.reroll_count = value
var organ_screen_from_pause: bool:
	get:
		return organ_session.opened_from_pause
	set(value):
		organ_session.opened_from_pause = value
var organ_install_completed: bool:
	get:
		return organ_session.install_completed
	set(value):
		organ_session.install_completed = value
var upgrade_confirm_button: Button
var upgrade_reroll_button: Button
var upgrade_skip_button: Button
var upgrade_currency_label: Label
var upgrade_action_row: HBoxContainer
var organ_instruction_label: Label
var organ_description_label: Label
var upgrade_selection_borders: Array[Panel] = []
var death_message_tween: Tween
var recommended_upgrade_id: StringName = &""
var pause_settings_frame: PanelContainer
var victory_message: Control
var magma_skill_panel: PanelContainer
var magma_skill_cooldown: ColorRect
var magma_skill_cooldown_label: Label
var magma_skill_name_label: Label
var active_skill_icon: TextureRect
var active_skill_last_affinity: StringName = &""
var active_skill_key_label: Label
var warden_dialogue_panel: PanelContainer
var warden_dialogue_text: Label
var run_reward_icon: TextureRect


func _ready() -> void:
	UpgradeRegistry.append_build_items(upgrade_pool)
	UpgradeRegistry.append_universal_mutations(upgrade_pool)
	VoltaicCardCatalog.apply_to_pool(upgrade_pool)
	player = get_tree().get_first_node_in_group("player") as Koda
	run_manager = get_tree().get_first_node_in_group(
		"run_manager"
	) as RunManager

	if player == null:
		push_warning("HUD: Player not found.")
		return

	upgrade_cards = [
		upgrade_card_1,
		upgrade_card_2,
		upgrade_card_3
	]
	
	player.health_changed.connect(update_health_bar)
	player.biomass_changed.connect(update_biomass_bar)
	player.died.connect(on_player_died)
	player.level_up_reached.connect(show_level_up_panel)
	player.upgrade_levels_changed.connect(_on_upgrade_levels_changed)
	if run_manager == null:
		push_warning("HUD: Run manager not found.")
	else:
		run_manager.time_changed.connect(update_run_timer)
		run_manager.state_changed.connect(on_run_state_changed)
		run_manager.run_finished.connect(show_run_end)
		run_manager.rush_started.connect(show_rush)
		run_manager.rush_ended.connect(hide_rush)
		run_manager.encounter_phase_changed.connect(
			_on_encounter_phase_changed
		)
		run_manager.boss_warning_started.connect(
			_show_boss_warning
		)
		run_manager.arena_lock_changed.connect(
			_on_arena_lock_changed
		)
		run_manager.boss_started.connect(show_boss)
		run_manager.boss_health_changed.connect(update_boss_health)
		run_manager.boss_phase_changed.connect(show_boss_phase)
		run_manager.boss_defeated.connect(on_boss_defeated)
		run_manager.rebirth_started.connect(show_rebirth_sequence)

		update_run_timer(
			run_manager.elapsed_seconds,
			run_manager.get_remaining_seconds()
		)

	for card_index in range(upgrade_cards.size()):
		upgrade_cards[card_index].pressed.connect(
			on_upgrade_selected.bind(card_index)
		)
	_install_upgrade_confirmation_ui()
	_install_pending_organ_navigation()
	_install_organ_guidance()
	get_viewport().size_changed.connect(_update_upgrade_card_layout)
	_update_upgrade_card_layout()
	_install_magma_skill_hud()
	_install_warden_dialogue()
	_install_run_reward_icon()

	level_up_panel.hide()

	update_health_bar(
		player.current_health,
		player.max_health
	)

	update_biomass_bar(
		player.current_biomass,
		player.biomass_required,
		player.current_level
	)

	legs_slot.organ_installed.connect(
		on_organ_installed
	)

	heart_slot.organ_installed.connect(
		on_organ_installed
	)

	brain_slot.organ_installed.connect(
		on_organ_installed
	)
	for slot in [legs_slot, heart_slot, brain_slot]:
		slot.organ_replacement_requested.connect(
			_on_organ_replacement_requested
		)
	
	organ_screen.hide()
	organ_close_button.hide()
	replacement_confirmation.hide()
	pending_organ_card.clear_organ()
	pause_panel.hide()
	pause_main_panel.show()
	pause_settings_panel.hide()
	run_end_panel.hide()
	run_state_label.hide()
	rush_label.hide()
	boss_warning_label.hide()
	boss_panel.hide()

	resume_button.pressed.connect(on_resume_pressed)
	pause_restart_button.pressed.connect(on_restart_pressed)
	pause_settings_button.pressed.connect(open_pause_settings)
	pause_organ_button.pressed.connect(open_organ_screen_from_pause)
	pause_main_menu_button.pressed.connect(on_return_to_main_menu_pressed)
	pause_quit_button.pressed.connect(on_quit_pressed)
	pause_fullscreen_toggle.toggled.connect(on_pause_fullscreen_toggled)
	pause_resolution_option.item_selected.connect(
		_on_pause_resolution_selected
	)
	pause_language_option.item_selected.connect(_on_pause_language_selected)
	pause_volume_slider.value_changed.connect(on_pause_volume_changed)
	pause_crt_slider.value_changed.connect(on_pause_crt_changed)
	pause_bloom_slider.value_changed.connect(on_pause_bloom_changed)
	pause_chromatic_slider.value_changed.connect(on_pause_chromatic_changed)
	pause_bit_reducer_slider.value_changed.connect(on_pause_bit_reducer_changed)
	_populate_pause_language_options()
	_install_pause_gameplay_settings_controls()
	_refresh_pause_dynamic_localization()
	_install_victory_message()
	pause_settings_back_button.pressed.connect(close_pause_settings)
	end_restart_button.pressed.connect(on_restart_pressed)
	end_main_menu_button.pressed.connect(on_return_to_main_menu_pressed)
	end_quit_button.pressed.connect(on_quit_pressed)
	organ_close_button.pressed.connect(_on_organ_close_pressed)
	replacement_yes_button.pressed.connect(
		_confirm_organ_replacement
	)
	replacement_no_button.pressed.connect(
		_cancel_organ_replacement
	)
	onboarding_start_button.pressed.connect(complete_onboarding)
	onboarding_guide_button.pressed.connect(_toggle_onboarding_guide)
	biofabricator_sequence.start_new_run_requested.connect(
		_on_start_new_run_requested
	)
	biofabricator_sequence.flesh_tree_requested.connect(
		_on_flesh_tree_requested
	)
	biofabricator_sequence.main_menu_requested.connect(
		_on_rebirth_main_menu_requested
	)
	fleshdrive_operation_screen.fleshdrive_selected.connect(
		_on_fleshdrive_selected
	)
	fleshdrive_operation_screen.back_requested.connect(
		on_return_to_main_menu_pressed
	)
	connect_ui_sounds()

	refresh_organ_overview()
	show_fleshdrive_operation()


func _process(_delta: float) -> void:
	_update_magma_skill_hud()


func _install_magma_skill_hud() -> void:
	magma_skill_panel = PanelContainer.new()
	magma_skill_panel.name = "MagmaSpearSkill"
	# Keep the active skill dock clear of the centered Warden health panel.
	magma_skill_panel.position = Vector2(1158.0, 26.0)
	magma_skill_panel.size = Vector2(92.0, 92.0)
	magma_skill_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	magma_skill_panel.tooltip_text = tr("ACTIVE SKILL: Press E / controller X. Aimed skills confirm with Right Mouse / Right Trigger.")
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.02, 0.025, 0.94)
	panel_style.border_color = Color(1.0, 0.18, 0.025, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(7)
	magma_skill_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(magma_skill_panel)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(
		"res://Assets/vfx/projectiles/magma_spear_sheet.png"
	) as Texture2D
	atlas.region = Rect2(0.0, 0.0, 192.0, 96.0)
	icon.texture = atlas
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magma_skill_panel.add_child(icon)
	active_skill_icon = icon
	magma_skill_cooldown = ColorRect.new()
	magma_skill_cooldown.color = Color(0.01, 0.01, 0.015, 0.78)
	magma_skill_cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magma_skill_panel.add_child(magma_skill_cooldown)
	magma_skill_cooldown_label = Label.new()
	magma_skill_cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	magma_skill_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magma_skill_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	magma_skill_cooldown_label.add_theme_font_size_override("font_size", 22)
	magma_skill_cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	magma_skill_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magma_skill_panel.add_child(magma_skill_cooldown_label)
	var key_label := Label.new()
	key_label.text = "E"
	key_label.position = Vector2(7.0, 4.0)
	key_label.size = Vector2(28.0, 28.0)
	key_label.add_theme_font_size_override("font_size", 24)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.16))
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 5)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magma_skill_panel.add_child(key_label)
	active_skill_key_label = key_label
	magma_skill_name_label = Label.new()
	magma_skill_name_label.position = Vector2(-20.0, 94.0)
	magma_skill_name_label.size = Vector2(132.0, 28.0)
	magma_skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magma_skill_name_label.add_theme_font_size_override("font_size", 11)
	magma_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magma_skill_panel.add_child(magma_skill_name_label)
	magma_skill_panel.hide()


func _update_magma_skill_hud() -> void:
	if not is_instance_valid(magma_skill_panel) or player == null:
		return
	var system := player.weapon_system as PlayerWeaponSystem
	if system == null:
		magma_skill_panel.hide()
		return
	var status := system.get_active_skill_status()
	var unlocked := bool(status.get("unlocked", false))
	var gameplay_visible := (
		run_manager == null
		or run_manager.state == RunManager.RunState.PLAYING
	)
	magma_skill_panel.visible = (
		unlocked
		and gameplay_visible
		and not organ_screen.visible
	)
	if not unlocked:
		return
	var affinity := StringName(status.get("affinity", player.active_fleshdrive_id))
	if affinity != active_skill_last_affinity:
		active_skill_last_affinity = affinity
		var definition := FleshdriveCatalog.get_definition(affinity)
		var icon_path := String(definition.get("icon", ""))
		if is_instance_valid(active_skill_icon) and not icon_path.is_empty():
			active_skill_icon.texture = load(icon_path) as Texture2D
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.012, 0.02, 0.025, 0.94)
		style.border_color = Color(definition.get("accent", Color.CYAN))
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		magma_skill_panel.add_theme_stylebox_override("panel", style)
	var cooldown := float(status.get("cooldown", 0.0))
	var maximum := maxf(float(status.get("max_cooldown", 1.0)), 0.01)
	var ratio := clampf(cooldown / maximum, 0.0, 1.0)
	magma_skill_cooldown.position = Vector2(0.0, 92.0 * (1.0 - ratio))
	magma_skill_cooldown.size = Vector2(92.0, 92.0 * ratio)
	magma_skill_cooldown_label.text = (
		"AIM" if bool(status.get("aiming", false))
		else ("%.1f" % cooldown if cooldown > 0.0 else "")
	)
	if is_instance_valid(magma_skill_name_label):
		magma_skill_name_label.text = tr(String(status.get("title", "ACTIVE")))
	if is_instance_valid(active_skill_key_label):
		var settings := get_tree().root.get_node_or_null("GameSettings")
		active_skill_key_label.text = (
			String(settings.call("get_active_skill_key_text"))
			if settings != null
			else "E"
		)


func connect_ui_sounds() -> void:
	var confirm_buttons: Array[BaseButton] = [
		resume_button,
		pause_restart_button,
		pause_settings_button,
		pause_organ_button,
		pause_main_menu_button,
		pause_quit_button,
		pause_fullscreen_toggle,
		end_restart_button,
		end_main_menu_button,
		end_quit_button,
		onboarding_start_button,
		onboarding_guide_button,
		replacement_yes_button,
	]

	for button in confirm_buttons:
		button.mouse_entered.connect(play_ui_hover)
		button.pressed.connect(play_ui_confirm)

	var cancel_buttons: Array[BaseButton] = [
		pause_settings_back_button,
		organ_close_button,
		replacement_no_button,
	]
	for button in cancel_buttons:
		button.mouse_entered.connect(play_ui_hover)
		button.pressed.connect(play_ui_cancel)

	for card in upgrade_cards:
		card.mouse_entered.connect(play_ui_hover)


func _install_pause_gameplay_settings_controls() -> void:
	if pause_settings_panel.get_node_or_null("SettingsTabs") != null:
		return
	pause_settings_panel.custom_minimum_size = Vector2.ZERO
	var center := pause_settings_panel.get_parent()
	pause_settings_frame = PanelContainer.new()
	pause_settings_frame.name = "SettingsFrame"
	pause_settings_frame.custom_minimum_size = Vector2(820.0, 650.0)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.008, 0.018, 0.024, 0.96)
	frame_style.border_color = Color(0.08, 0.68, 0.74, 0.92)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(10)
	frame_style.content_margin_left = 28.0
	frame_style.content_margin_top = 22.0
	frame_style.content_margin_right = 28.0
	frame_style.content_margin_bottom = 22.0
	pause_settings_frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(pause_settings_frame)
	pause_settings_panel.reparent(pause_settings_frame)
	pause_settings_frame.hide()
	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(720.0, 460.0)
	pause_settings_panel.add_child(tabs)
	pause_settings_panel.move_child(tabs, 1)
	var display_page := VBoxContainer.new()
	display_page.name = "DISPLAY & AUDIO"
	display_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(display_page)
	for child_name in [
		"FullscreenToggle",
		"ResolutionRow",
		"LanguageRow",
		"VolumeTitle",
		"VolumeRow",
		"CRTRow",
		"BloomRow",
		"ChromaticRow",
		"BitReducerRow",
	]:
		var child := pause_settings_panel.get_node_or_null(child_name)
		if child != null:
			child.reparent(display_page)
	var gameplay_page := VBoxContainer.new()
	gameplay_page.name = "GAMEPLAY & ACCESSIBILITY"
	gameplay_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(gameplay_page)
	var gameplay_controls := GameplaySettingsControls.new()
	gameplay_controls.name = "GameplaySettings"
	gameplay_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_page.add_child(gameplay_controls)
	pause_fullscreen_toggle.flat = true


func play_ui_hover() -> void:
	play_sound(&"ui_hover", -7.0, 0.025, &"UI")


func play_ui_confirm() -> void:
	play_sound(&"ui_confirm", -5.0, 0.02, &"UI")


func play_ui_cancel() -> void:
	play_sound(&"ui_cancel", -5.0, 0.02, &"UI")


func play_sound(
	sound_id: StringName,
	volume_db: float = 0.0,
	pitch_variation: float = 0.0,
	bus_name: StringName = &"SFX"
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


func update_health_bar(
	current_health: float,
	max_health: float
) -> void:
	health_bar.max_value = maxf(max_health, 1.0)
	health_bar.value = clampf(current_health, 0.0, health_bar.max_value)
	health_value_label.text = "%d / %d" % [
		ceili(maxf(current_health, 0.0)),
		ceili(maxf(max_health, 0.0)),
	]


func update_biomass_bar(
	current_biomass: float,
	biomass_required: float,
	current_level: int
) -> void:
	var displayed_requirement := maxf(biomass_required, 1.0)
	# Level-up pacing deliberately retains overflow. The HUD represents the
	# current level threshold, not the whole hidden bank, so its number and fill
	# can never disagree (for example 1364 / 115 on a full 115-point bar).
	var displayed_biomass := clampf(
		current_biomass,
		0.0,
		displayed_requirement
	)
	biomass_bar.max_value = displayed_requirement
	biomass_bar.value = displayed_biomass
	biomass_value_label.text = "%d / %d" % [
		floori(displayed_biomass),
		ceili(displayed_requirement),
	]
	level_label.text = "LV %d" % current_level


func _set_player_status_visible(should_show: bool) -> void:
	player_status_panel.visible = should_show
	level_label.visible = should_show


func _update_koda_portrait(_fleshdrive_id: StringName) -> void:
	var atlas := load(KODA_PORTRAIT_TEXTURE) as Texture2D
	if atlas == null:
		return
	var portrait_texture := AtlasTexture.new()
	portrait_texture.atlas = atlas
	portrait_texture.region = Rect2(0.0, 0.0, 96.0, 96.0)
	koda_portrait.texture = portrait_texture


func on_player_died() -> void:
	health_bar.value = 0
	health_value_label.text = "0 / %d" % ceili(player.max_health)
	if death_message_tween != null:
		death_message_tween.kill()

	_claim_overlay(&"death", death_message)
	death_message.modulate.a = 0.0
	death_message.show()
	death_message_tween = death_message.create_tween()
	death_message_tween.tween_property(
		death_message,
		"modulate:a",
		1.0,
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	death_message_tween.tween_interval(1.65)
	death_message_tween.tween_property(
		death_message,
		"modulate:a",
		0.0,
		0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_message_tween.tween_callback(death_message.hide)


func update_run_timer(
	_elapsed_seconds: float,
	remaining_seconds: float
) -> void:
	var total_seconds := maxi(int(ceil(remaining_seconds)), 0)
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60

	run_timer_label.text = "%02d:%02d" % [minutes, seconds]


func show_level_up_panel(current_level: int) -> void:
	if run_manager != null:
		if not run_manager.enter_level_up():
			return
	else:
		_set_player_status_visible(false)
	_claim_overlay(&"level_up", level_up_panel)
	_configure_unstable_genome_card()
	_update_upgrade_card_layout()

	_clear_upgrade_selection()
	_refresh_upgrade_offer_actions()
	var available_upgrades: Array[UpgradeData] = []

	for upgrade in upgrade_pool:
		if (
			is_upgrade_available(upgrade)
			and not _was_offered_in_previous_two_levels(
				upgrade.upgrade_id,
				current_level
			)
		):
			available_upgrades.append(upgrade)

	if available_upgrades.size() < upgrade_cards.size():
		push_warning(
			"HUD: Not enough available upgrades."
		)
		return

	displayed_upgrades.clear()

	var forced_reflex_cortex: UpgradeData = null
	var forced_auto_attack: UpgradeData = null
	var affinity_offer: UpgradeData = null
	var synergy_offer: UpgradeData = null
	var survival_offer: UpgradeData = null

	if current_level <= EARLY_SURVIVAL_THROUGH_LEVEL:
		survival_offer = _take_early_survival_upgrade(available_upgrades)
		if survival_offer != null:
			displayed_upgrades.append(survival_offer)

	if (
		current_level <= EARLY_VOLTAIC_CORE_THROUGH_LEVEL
		and player.active_fleshdrive_id == FleshdriveCatalog.ELECTRIC
	):
		_append_early_voltaic_core_offers(available_upgrades)

	if (
		current_level >= REFLEX_CORTEX_OFFER_LEVEL
		and player.attack_mode == Koda.AttackMode.MANUAL
	):
		for upgrade in available_upgrades:
			if upgrade.upgrade_id == &"reflex_cortex":
				forced_reflex_cortex = upgrade
				break

		if forced_reflex_cortex != null:
			displayed_upgrades.append(
				forced_reflex_cortex
			)

			available_upgrades.erase(
				forced_reflex_cortex
			)
		else:
			push_warning(
				"HUD: Reflex Cortex is missing from the pool."
			)
	elif (
		current_level >= AUTO_ATTACK_OFFER_LEVEL
		and player.attack_mode == Koda.AttackMode.SEMI_AUTO
	):
		for upgrade in available_upgrades:
			if upgrade.upgrade_id == &"autonomic_reflex":
				forced_auto_attack = upgrade
				break

		if forced_auto_attack != null:
			displayed_upgrades.append(forced_auto_attack)
			available_upgrades.erase(forced_auto_attack)
		else:
			push_warning(
				"HUD: Autonomic Reflex is missing from the pool."
			)

	if (
		current_level >= 5
		and displayed_upgrades.size() < upgrade_cards.size()
	):
		synergy_offer = _take_synergy_upgrade(available_upgrades)
		if synergy_offer != null:
			displayed_upgrades.append(synergy_offer)
			available_upgrades.erase(synergy_offer)

	if displayed_upgrades.size() < upgrade_cards.size():
		affinity_offer = _take_weighted_upgrade(
			available_upgrades,
			true
		)
		if affinity_offer != null:
			displayed_upgrades.append(affinity_offer)
			available_upgrades.erase(affinity_offer)

	while displayed_upgrades.size() < upgrade_cards.size():
		if available_upgrades.is_empty():
			push_warning(
				"HUD: Not enough upgrades to fill cards."
			)
			return

		var weighted_offer := _take_weighted_upgrade(
			available_upgrades,
			false
		)
		if weighted_offer == null:
			push_warning("HUD: Upgrade weighting returned no offer.")
			return
		displayed_upgrades.append(weighted_offer)

	for offered_upgrade in displayed_upgrades:
		if offered_upgrade != null:
			recently_offered_upgrade_levels[
				offered_upgrade.upgrade_id
			] = current_level

	# A garantált kártya ne mindig ugyanott jelenjen meg.
	displayed_upgrades.shuffle()
	recommended_upgrade_id = &""
	var recommendation_score := -INF
	for offered_upgrade in displayed_upgrades:
		var score := _get_upgrade_offer_weight(offered_upgrade)
		if score > recommendation_score:
			recommendation_score = score
			recommended_upgrade_id = offered_upgrade.upgrade_id
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		var affinity_matches := 0
		for offered_upgrade in displayed_upgrades:
			if offered_upgrade != null:
				if (
					offered_upgrade.fleshdrive_affinity
					== String(player.active_fleshdrive_id)
				):
					affinity_matches += 1
				telemetry.call(
					"record_card_offered",
					offered_upgrade.upgrade_id
				)
		telemetry.call(
			"record_offer_set",
			displayed_upgrades,
			player.active_fleshdrive_id,
			affinity_matches
		)

	for card_index in range(upgrade_cards.size()):
		var upgrade := displayed_upgrades[card_index]

		if upgrade == null:
			push_warning("HUD: Invalid upgrade resource.")
			return

		upgrade_cards[card_index].texture_normal = null
		# Everything needed to decide is printed on the card. Hover must not
		# cover adjacent offers with a duplicate tooltip.
		upgrade_cards[card_index].tooltip_text = ""
		_set_upgrade_offer_badge(
			upgrade_cards[card_index],
			upgrade
		)
		_set_upgrade_card_content(upgrade_cards[card_index], upgrade)

	title_label.text = (
		tr("CHOOSE A MUTATION - LEVEL %d") % current_level
	)

	level_up_panel.show()
	_configure_upgrade_card_focus()
	_animate_upgrade_card_reveal()
	play_sound(&"card_reveal", -5.0, 0.025)
	# Selection is now a two-step interaction (select, then confirm), so an
	# artificial click lock only makes the interface feel unresponsive.
	card_selection.begin_offer()
	for card in upgrade_cards:
		card.disabled = false

	if run_manager == null:
		get_tree().paused = true


func _take_weighted_upgrade(
	candidates: Array[UpgradeData],
	require_active_affinity: bool
) -> UpgradeData:
	var eligible: Array[UpgradeData] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	for upgrade in candidates:
		if (
			require_active_affinity
			and upgrade.fleshdrive_affinity
			!= String(player.active_fleshdrive_id)
		):
			continue
		var weight := _get_upgrade_offer_weight(upgrade)
		eligible.append(upgrade)
		weights.append(weight)
		total_weight += weight
	if eligible.is_empty():
		return null
	var roll := randf() * total_weight
	var running := 0.0
	for index in range(eligible.size()):
		running += weights[index]
		if roll <= running:
			var selected := eligible[index]
			candidates.erase(selected)
			return selected
	var fallback: UpgradeData = eligible.back()
	candidates.erase(fallback)
	return fallback


func _was_offered_in_previous_two_levels(
	upgrade_id: StringName,
	current_level: int
) -> bool:
	if not recently_offered_upgrade_levels.has(upgrade_id):
		return false
	var last_offered_level := int(
		recently_offered_upgrade_levels[upgrade_id]
	)
	return current_level <= last_offered_level + 2


func _take_early_survival_upgrade(
	candidates: Array[UpgradeData]
) -> UpgradeData:
	var survival_candidates: Array[UpgradeData] = []
	for upgrade in candidates:
		if _is_defensive_or_healing_upgrade(upgrade):
			survival_candidates.append(upgrade)
	if survival_candidates.is_empty():
		push_warning("HUD: No defensive or healing early-game offer is available.")
		return null
	var selected := _take_weighted_upgrade(survival_candidates, false)
	if selected != null:
		candidates.erase(selected)
	return selected


func _is_defensive_or_healing_upgrade(upgrade: UpgradeData) -> bool:
	if upgrade == null:
		return false
	if upgrade.upgrade_id in SURVIVAL_UPGRADE_IDS:
		return true
	for tag in upgrade.get_effective_synergy_tags():
		if tag in SURVIVAL_TAGS:
			return true
	return false


func _append_early_voltaic_core_offers(
	candidates: Array[UpgradeData]
) -> void:
	# The opening offers establish the run's identity before generic passives
	# dilute the pool. Unchosen core paths remain visible through level five.
	for core_id in EARLY_VOLTAIC_CORE_IDS:
		if displayed_upgrades.size() >= upgrade_cards.size():
			return
		if (
			player.get_upgrade_level(core_id) > 0
			or player.has_selected_upgrade(core_id)
		):
			continue
		for upgrade in candidates:
			if upgrade.upgrade_id != core_id:
				continue
			displayed_upgrades.append(upgrade)
			candidates.erase(upgrade)
			break


func _take_synergy_upgrade(candidates: Array[UpgradeData]) -> UpgradeData:
	var active_tags := _get_owned_synergy_tags()
	if active_tags.is_empty():
		return null
	var best: UpgradeData = null
	var best_score := -INF
	for upgrade in candidates:
		if (
			upgrade.fleshdrive_affinity != String(player.active_fleshdrive_id)
			and upgrade.fleshdrive_affinity != "universal"
		):
			continue
		var matches := 0
		for tag in upgrade.get_effective_synergy_tags():
			if tag in active_tags:
				matches += 1
		if matches <= 0:
			continue
		var score := float(matches) * 10.0 + _get_upgrade_offer_weight(upgrade)
		if score > best_score:
			best_score = score
			best = upgrade
	return best


func _configure_upgrade_card_focus() -> void:
	if upgrade_cards.is_empty():
		return
	for index in range(upgrade_cards.size()):
		var card := upgrade_cards[index]
		var previous := upgrade_cards[(index - 1 + upgrade_cards.size()) % upgrade_cards.size()]
		var next := upgrade_cards[(index + 1) % upgrade_cards.size()]
		card.focus_neighbor_left = card.get_path_to(previous)
		card.focus_neighbor_right = card.get_path_to(next)


func _get_upgrade_offer_weight(upgrade: UpgradeData) -> float:
	var weight := upgrade.offer_weight
	var current_level := player.get_upgrade_level(upgrade.upgrade_id)
	if upgrade.fleshdrive_affinity == String(player.active_fleshdrive_id):
		weight += 3.2 * (
			run_manager.affinity_offer_pressure
			if run_manager != null
			else 1.0
		)
	elif upgrade.fleshdrive_affinity == "universal":
		weight += 0.5
	if current_level > 0:
		# Once a build has started, completing it is more valuable than filling
		# every slot with level-one options during a twelve-minute run.
		weight += 6.0
	elif upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON:
		# A successful run should deepen two or three weapons instead of
		# continuously scattering the loadout across level-one unlocks.
		var owned_weapons := 0
		for candidate in upgrade_pool:
			if (
				candidate != null
				and candidate.upgrade_kind == UpgradeData.UpgradeKind.WEAPON
				and player.get_upgrade_level(candidate.upgrade_id) > 0
			):
				owned_weapons += 1
		if owned_weapons >= 2:
			weight *= 0.46
	if (
		upgrade.upgrade_kind == UpgradeData.UpgradeKind.ORGAN
		and current_level == 0
	):
		# Surgery is a rare, deliberate interruption rather than every other
		# level-up. Once found, the organ persists on the surgery shelf.
		weight *= 0.22
	var active_tags := _get_owned_synergy_tags()
	var matching_tags := 0
	for tag in upgrade.get_effective_synergy_tags():
		if tag in active_tags:
			matching_tags += 1
	weight += float(matching_tags) * 1.75
	match upgrade.rarity:
		"rare":
			weight *= 0.58
		"specialized":
			weight *= 0.84
	return maxf(weight, 0.05)


func _get_owned_synergy_tags() -> Dictionary:
	var tags: Dictionary = {}
	for owned_upgrade in upgrade_pool:
		if (
			owned_upgrade == null
			or player.get_upgrade_level(owned_upgrade.upgrade_id) <= 0
		):
			continue
		for tag in owned_upgrade.get_effective_synergy_tags():
			if tag in [&"item", &"organ", &"weapon", &"universal"]:
				continue
			tags[tag] = int(tags.get(tag, 0)) + 1
	return tags


func _set_upgrade_offer_badge(
	card: TextureButton,
	upgrade: UpgradeData
) -> void:
	var badge := card.get_node_or_null("OfferBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "OfferBadge"
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-142.0, 10.0)
		badge.size = Vector2(132.0, 26.0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override(
			"font_shadow_color",
			Color(0.0, 0.0, 0.0, 0.95)
		)
		badge.add_theme_constant_override("shadow_offset_x", 2)
		badge.add_theme_constant_override("shadow_offset_y", 2)
		card.add_child(badge)
	var level := player.get_upgrade_level(upgrade.upgrade_id)
	var active_tags := _get_owned_synergy_tags()
	var has_synergy := false
	for tag in upgrade.get_effective_synergy_tags():
		if tag in active_tags:
			has_synergy = true
			break
	if upgrade.upgrade_id == recommended_upgrade_id:
		badge.text = tr("RECOMMENDED")
		badge.modulate = Color(0.42, 1.0, 0.72)
	elif (
		upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON
		and level == 0
	):
		badge.text = tr("NEW WEAPON")
		badge.modulate = Color(0.45, 0.9, 1.0)
	elif upgrade.rarity == "rare":
		badge.text = tr("RARE")
		badge.modulate = Color(0.84, 0.48, 1.0)
	elif has_synergy:
		badge.text = tr("SYNERGY")
		badge.modulate = Color(1.0, 0.76, 0.25)
	else:
		badge.text = tr("UPGRADE")
		badge.modulate = Color(0.82, 0.88, 0.9)
	card.move_child(badge, card.get_child_count() - 1)


func _set_upgrade_card_content(
	card: TextureButton,
	upgrade: UpgradeData
) -> void:
	var previous := card.get_node_or_null("CardSurface")
	if previous != null:
		card.remove_child(previous)
		previous.free()

	# Only the three branch-defining Lightning cards use build colors. This
	# prevents every supporting item from looking like another Ball Lightning.
	# Organs are pink; all remaining/general cards are neutral gray.
	var affinity_color := _get_upgrade_card_color(upgrade)
	if upgrade.rarity == "rare":
		affinity_color = affinity_color.lightened(0.16)

	var surface := PanelContainer.new()
	surface.name = "CardSurface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.clip_contents = true
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = Color(0.025, 0.032, 0.038, 0.98)
	surface_style.border_color = affinity_color.darkened(0.18)
	surface_style.set_border_width_all(2)
	surface_style.corner_radius_top_left = 8
	surface_style.corner_radius_top_right = 8
	surface_style.corner_radius_bottom_left = 8
	surface_style.corner_radius_bottom_right = 8
	surface.add_theme_stylebox_override("panel", surface_style)
	card.add_child(surface)
	card.move_child(surface, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	surface.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "CardTitle"
	title.custom_minimum_size = Vector2(0.0, 42.0)
	title.text = _get_upgrade_display_name(upgrade)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", affinity_color.lightened(0.2))
	stack.add_child(title)
	var kind_names := [tr("ITEM"), tr("ORGAN"), tr("WEAPON")]
	var type_line := Label.new()
	type_line.name = "CardType"
	type_line.text = kind_names[int(upgrade.upgrade_kind)]
	if upgrade.upgrade_kind == UpgradeData.UpgradeKind.ORGAN:
		type_line.name = "OrganType"
		type_line.text += "  /  " + tr(_get_organ_slot_key(upgrade.organ_slot))
	elif upgrade.fleshdrive_affinity != "universal":
		type_line.text += "  /  " + tr(upgrade.fleshdrive_affinity.to_upper())
	type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_line.add_theme_font_size_override("font_size", 13)
	type_line.add_theme_color_override("font_color", affinity_color)
	stack.add_child(type_line)

	var illustration := LabNoteIconScript.new()
	illustration.name = "LabNoteIllustration"
	illustration.custom_minimum_size = Vector2(84.0, 84.0)
	illustration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.call("configure", upgrade, affinity_color)
	stack.add_child(illustration)

	var description := Label.new()
	description.name = "Description"
	description.custom_minimum_size = Vector2(0.0, 76.0)
	description.text = _get_card_effect_rows(upgrade)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(0.82, 0.86, 0.87))
	stack.add_child(description)

	var next_divider := HSeparator.new()
	var next_divider_style := StyleBoxLine.new()
	next_divider_style.color = affinity_color.darkened(0.18)
	next_divider_style.thickness = 1
	next_divider.add_theme_stylebox_override(
		"separator", next_divider_style
	)
	stack.add_child(next_divider)
	var next_change := Label.new()
	next_change.name = "NextLevelChange"
	next_change.custom_minimum_size = Vector2(0.0, 88.0)
	next_change.text = _get_next_level_change(upgrade)
	next_change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_change.add_theme_font_size_override("font_size", 16)
	next_change.add_theme_color_override("font_color", affinity_color)
	stack.add_child(next_change)

	var badge := card.get_node_or_null("OfferBadge")
	if badge != null:
		card.move_child(badge, card.get_child_count() - 1)
	var selection_border := card.get_node_or_null("SelectionBorder")
	if selection_border != null:
		card.move_child(selection_border, card.get_child_count() - 1)


func _get_upgrade_card_color(upgrade: UpgradeData) -> Color:
	if upgrade == null:
		return Color(0.55, 0.58, 0.62)
	if upgrade.upgrade_id == &"arc_heart":
		return Color("329dff")
	if upgrade.upgrade_id == &"ball_lightning":
		return Color("258cff")
	if upgrade.upgrade_id == &"static_claws":
		return Color("a84dff")
	if upgrade.upgrade_kind == UpgradeData.UpgradeKind.ORGAN:
		return Color("ff5b9f")
	return Color(0.55, 0.58, 0.62)


func _get_next_level_change(upgrade: UpgradeData) -> String:
	var current_level := player.get_upgrade_level(upgrade.upgrade_id)
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	var changes := UpgradeProgressionPresenter.describe(
		upgrade, current_level, balance
	)
	if changes.size() > 3:
		changes.resize(3)
	for index in range(changes.size()):
		changes[index] = String(changes[index]).replace(" -> ", " becomes ")
	var heading := (
		tr("NEW EFFECT")
		if current_level == 0 and upgrade.max_level == 1
		else tr("NEXT LEVEL")
	)
	return heading + ":\n" + "\n".join(changes)


func _get_card_effect_rows(upgrade: UpgradeData) -> String:
	var source := tr(upgrade.description.strip_edges())
	source = source.replace("\r", " ").replace("\n", " ")
	while source.contains("  "):
		source = source.replace("  ", " ")
	var sentences := source.split(". ", false)
	var rows: Array[String] = []
	for raw_sentence in sentences:
		if rows.size() >= 3:
			break
		var sentence := String(raw_sentence).strip_edges()
		if sentence.is_empty():
			continue
		if not sentence.ends_with("."):
			sentence += "."
		if sentence.length() > 72:
			sentence = sentence.substr(0, 69).strip_edges() + "..."
		rows.append("- " + sentence)
	if rows.is_empty():
		rows.append("- " + tr("New mutation effect."))
	return "\n".join(rows)


func _get_organ_slot_key(slot: UpgradeData.OrganSlot) -> String:
	return UpgradeProgressionPresenter.organ_slot_key(slot)


func _get_build_level_values(upgrade: UpgradeData, current_level: int, next_level: int) -> String:
	if not BuildItemCatalog.is_build_item(upgrade.upgrade_id):
		return ""
	var values := Dictionary(BuildItemCatalog.VALUES.get(upgrade.upgrade_id, {}))
	var parts: Array[String] = []
	for key in values.keys():
		if parts.size() >= 2:
			break
		var value := float(values[key])
		if absf(value) > 2.0:
			continue
		var current_value := value * float(current_level)
		var next_value := value * float(next_level)
		parts.append("%s %.0f%% > %.0f%%" % [String(key).replace("_per_level", "").replace("_", " ").to_upper(), current_value * 100.0, next_value * 100.0])
	return " / ".join(parts)


func _set_build_card_overlay(card: TextureButton, upgrade: UpgradeData) -> void:
	var previous := card.get_node_or_null("BuildItemName")
	if previous != null:
		card.remove_child(previous)
		previous.free()
	var previous_delta := card.get_node_or_null("BuildLevelDelta")
	if previous_delta != null:
		card.remove_child(previous_delta)
		previous_delta.free()
	if upgrade.build_archetype.is_empty():
		return
	var label := Label.new()
	label.name = "BuildItemName"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 18.0
	label.offset_top = 74.0
	label.offset_right = -18.0
	label.offset_bottom = 144.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = _get_upgrade_display_name(upgrade)
	card.add_child(label)
	var delta_label := Label.new()
	delta_label.name = "BuildLevelDelta"
	delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	delta_label.offset_left = 18.0
	delta_label.offset_top = -105.0
	delta_label.offset_right = -18.0
	delta_label.offset_bottom = -42.0
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delta_label.clip_text = true
	delta_label.add_theme_font_size_override("font_size", 12)
	delta_label.add_theme_color_override("font_color", Color(0.76, 0.92, 0.96))
	var current := player.get_upgrade_level(upgrade.upgrade_id)
	delta_label.text = _get_build_level_values(upgrade, current, mini(current + 1, upgrade.max_level))
	card.add_child(delta_label)


func _animate_upgrade_card_reveal() -> void:
	for card_index in range(upgrade_cards.size()):
		var card := upgrade_cards[card_index]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.9, 0.9)
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(card_index) * 0.065)
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale", Vector2.ONE, 0.26)
		tween.tween_property(card, "modulate:a", 1.0, 0.2)


func on_upgrade_selected(card_index: int) -> void:
	if card_selection.locked:
		return
	if card_selection.selected_index == card_index:
		_accept_selected_upgrade()
		return

	if not card_selection.select(card_index, displayed_upgrades.size()):
		push_warning("HUD: Invalid upgrade card index.")
		return

	var selected_upgrade := displayed_upgrades[card_index]

	if selected_upgrade == null:
		push_warning("HUD: Selected upgrade is missing.")
		return
	_refresh_upgrade_selection_borders()
	upgrade_confirm_button.disabled = false
	upgrade_confirm_button.show()
	upgrade_confirm_button.grab_focus()
	play_sound(&"ui_hover", -9.0, 0.015, &"UI")


func _accept_selected_upgrade() -> void:
	if card_selection.locked:
		return
	if not card_selection.can_confirm(displayed_upgrades.size()):
		return
	var selected_upgrade := displayed_upgrades[card_selection.selected_index]
	if selected_upgrade == null:
		return
	# Freeze the offer before any signal, focus change or queued level-up can
	# mutate the displayed array or submit a second card from the same input.
	card_selection.finish_offer()
	upgrade_confirm_button.disabled = true
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call(
			"record_card_selected",
			selected_upgrade.upgrade_id
		)

	play_sound(&"card_select", -3.0, 0.025, &"UI")

	if (
		selected_upgrade.upgrade_kind
		== UpgradeData.UpgradeKind.ORGAN
	):
		open_organ_screen(selected_upgrade)
		return

	player.apply_upgrade(selected_upgrade.upgrade_id)

	level_up_panel.hide()
	_clear_upgrade_selection()
	complete_level_up()


func _install_upgrade_confirmation_ui() -> void:
	var container := title_label.get_parent() as VBoxContainer
	upgrade_action_row = HBoxContainer.new()
	upgrade_action_row.name = "UpgradeActionRow"
	upgrade_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_action_row.add_theme_constant_override("separation", 16)
	upgrade_action_row.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	container.add_child(upgrade_action_row)
	upgrade_currency_label = Label.new()
	upgrade_currency_label.name = "BloodMemoryLabel"
	upgrade_currency_label.custom_minimum_size = Vector2(190.0, 54.0)
	upgrade_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_currency_label.add_theme_font_size_override("font_size", 15)
	upgrade_currency_label.add_theme_color_override(
		"font_color", Color(0.93, 0.28, 0.38)
	)
	upgrade_currency_label.add_theme_color_override(
		"font_shadow_color", Color(0.0, 0.0, 0.0, 0.95)
	)
	upgrade_currency_label.add_theme_constant_override("shadow_offset_x", 2)
	upgrade_currency_label.add_theme_constant_override("shadow_offset_y", 2)
	upgrade_action_row.add_child(upgrade_currency_label)
	upgrade_reroll_button = Button.new()
	upgrade_reroll_button.name = "RerollButton"
	upgrade_reroll_button.custom_minimum_size = Vector2(220.0, 54.0)
	upgrade_reroll_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	upgrade_action_row.add_child(upgrade_reroll_button)
	upgrade_reroll_button.pressed.connect(_reroll_upgrade_offers)
	upgrade_skip_button = Button.new()
	upgrade_skip_button.name = "SkipButton"
	upgrade_skip_button.text = tr("SKIP")
	upgrade_skip_button.custom_minimum_size = Vector2(180.0, 54.0)
	upgrade_skip_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	upgrade_action_row.add_child(upgrade_skip_button)
	upgrade_skip_button.pressed.connect(_skip_upgrade_offer)
	upgrade_confirm_button = Button.new()
	upgrade_confirm_button.name = "ConfirmSelectionButton"
	upgrade_confirm_button.text = tr("CONFIRM [ENTER]")
	upgrade_confirm_button.custom_minimum_size = Vector2(330.0, 58.0)
	upgrade_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	upgrade_confirm_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	upgrade_confirm_button.disabled = true
	upgrade_confirm_button.hide()
	container.add_child(upgrade_confirm_button)
	upgrade_confirm_button.pressed.connect(_accept_selected_upgrade)
	_refresh_upgrade_offer_actions()
	for card in upgrade_cards:
		var border := Panel.new()
		border.name = "SelectionBorder"
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.hide()
		card.add_child(border)
		upgrade_selection_borders.append(border)


func _clear_upgrade_selection() -> void:
	card_selection.clear_selection()
	if is_instance_valid(upgrade_confirm_button):
		upgrade_confirm_button.disabled = true
		upgrade_confirm_button.hide()
	for border in upgrade_selection_borders:
		border.hide()


func _get_upgrade_reroll_cost() -> int:
	if player == null:
		return 0
	if player.free_upgrade_rerolls > 0:
		return 0
	if card_selection.paid_reroll_count >= PAID_REROLL_COSTS.size():
		return -1
	return PAID_REROLL_COSTS[card_selection.paid_reroll_count]


func _get_blood_memory() -> int:
	var meta := get_tree().root.get_node_or_null("MetaProgression")
	return int(meta.call("get_blood_memory")) if meta != null else 0


func _refresh_upgrade_offer_actions() -> void:
	if not is_instance_valid(upgrade_reroll_button) or player == null:
		return
	var cost := _get_upgrade_reroll_cost()
	var blood_memory := _get_blood_memory()
	upgrade_reroll_button.text = (
		tr("REROLL - FREE")
		if player.free_upgrade_rerolls > 0
		else tr("REROLL LIMIT REACHED")
		if cost < 0
		else tr("REROLL - %d BLOOD MEMORY") % cost
	)
	upgrade_reroll_button.disabled = (
		player.free_upgrade_rerolls <= 0
		and (cost < 0 or blood_memory < cost)
	)
	if is_instance_valid(upgrade_currency_label):
		upgrade_currency_label.text = (
			tr("PERMANENT BLOOD MEMORY: %d") % blood_memory
		)
		upgrade_currency_label.tooltip_text = tr(
			"Permanent meta currency. Paid rerolls cost 2, then 3, then 5 per offer."
		)
	if is_instance_valid(upgrade_skip_button):
		upgrade_skip_button.text = tr("SKIP")


func _reroll_upgrade_offers() -> void:
	if card_selection.locked or player == null:
		return
	var cost := _get_upgrade_reroll_cost()
	if cost < 0 and player.free_upgrade_rerolls <= 0:
		play_sound(&"ui_cancel", -7.0, 0.0, &"UI")
		return
	var paid := false
	if player.free_upgrade_rerolls > 0:
		player.free_upgrade_rerolls -= 1
	else:
		var meta := get_tree().root.get_node_or_null("MetaProgression")
		if meta == null or not bool(meta.call("spend_blood_memory", cost)):
			play_sound(&"ui_cancel", -7.0, 0.0, &"UI")
			_refresh_upgrade_offer_actions()
			return
		paid = true
	card_selection.register_reroll(paid)
	_clear_upgrade_selection()
	# The level-up state is already active, so rebuild only the offers.
	displayed_upgrades.clear()
	if run_manager != null:
		run_manager.exit_level_up()
	show_level_up_panel(player.current_level)
	play_sound(&"card_reveal", -5.0, 0.025, &"UI")


func _skip_upgrade_offer() -> void:
	if card_selection.locked:
		return
	if player != null and player.get_upgrade_level(&"cannibal_enzyme") > 0:
		player.add_biomass(maxf(2.0, ceilf(player.biomass_required * 0.04)))
	level_up_panel.hide()
	_clear_upgrade_selection()
	card_selection.reset_offer()
	complete_level_up()


func _configure_unstable_genome_card() -> void:
	var use_fourth := (
		player != null
		and player.get_upgrade_level(&"unstable_genome") > 0
		and randf() <= 0.05
	)
	if use_fourth:
		if not is_instance_valid(bonus_upgrade_card):
			bonus_upgrade_card = TextureButton.new()
			bonus_upgrade_card.name = "UpgradeCard4"
			bonus_upgrade_card.custom_minimum_size = Vector2(276.0, 396.0)
			bonus_upgrade_card.clip_contents = true
			bonus_upgrade_card.ignore_texture_size = true
			bonus_upgrade_card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			bonus_upgrade_card.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
			upgrade_card_3.get_parent().add_child(bonus_upgrade_card)
			bonus_upgrade_card.pressed.connect(on_upgrade_selected.bind(3))
			var border := Panel.new()
			border.name = "SelectionBorder"
			border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			border.hide()
			bonus_upgrade_card.add_child(border)
			upgrade_selection_borders.append(border)
		if bonus_upgrade_card not in upgrade_cards:
			upgrade_cards.append(bonus_upgrade_card)
		bonus_upgrade_card.show()
	elif is_instance_valid(bonus_upgrade_card):
		upgrade_cards.erase(bonus_upgrade_card)
		bonus_upgrade_card.hide()


func _update_upgrade_card_layout() -> void:
	if upgrade_cards.is_empty() or not is_instance_valid(title_label):
		return
	var viewport_size := get_viewport_rect().size
	var visible_card_count := maxi(upgrade_cards.size(), 1)
	var card_row := upgrade_card_1.get_parent() as HBoxContainer
	var separation := 14 if visible_card_count >= 4 else 18
	if card_row != null:
		card_row.add_theme_constant_override("separation", separation)
	var available_width := maxf(viewport_size.x * 0.92, 660.0)
	var card_width := clampf(
		(
			available_width
			- float(separation * (visible_card_count - 1))
		) / float(visible_card_count),
		218.0,
		276.0
	)
	# Reserve room for the title and both action rows. This keeps even the
	# four-card Unstable Genome offer inside short viewports.
	var card_height := clampf(viewport_size.y - 238.0, 360.0, 396.0)
	for card in upgrade_cards:
		if is_instance_valid(card):
			card.custom_minimum_size = Vector2(card_width, card_height)


func _refresh_upgrade_selection_borders() -> void:
	for index in range(upgrade_selection_borders.size()):
		var border := upgrade_selection_borders[index]
		border.visible = index == card_selection.selected_index
		if not border.visible:
			continue
		var kind := UpgradeData.UpgradeKind.ITEM
		if index < displayed_upgrades.size() and displayed_upgrades[index] != null:
			kind = displayed_upgrades[index].upgrade_kind
		var color := Color(0.3, 0.82, 0.62, 0.98)
		if kind == UpgradeData.UpgradeKind.ORGAN:
			color = Color(0.76, 0.38, 0.96, 0.98)
		elif kind == UpgradeData.UpgradeKind.WEAPON:
			color = Color(1.0, 0.48, 0.18, 0.98)
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = color
		style.set_border_width_all(5)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		border.add_theme_stylebox_override("panel", style)


func _install_pending_organ_navigation() -> void:
	pending_previous_button = Button.new()
	pending_previous_button.name = "PendingPreviousButton"
	pending_previous_button.text = "<"
	pending_previous_button.position = Vector2(916.0, 274.0)
	pending_previous_button.size = Vector2(36.0, 30.0)
	pending_previous_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pending_previous_button.pressed.connect(_show_previous_pending_organ)
	organ_screen.add_child(pending_previous_button)

	pending_counter_label = Label.new()
	pending_counter_label.name = "PendingCounterLabel"
	pending_counter_label.position = Vector2(952.0, 274.0)
	pending_counter_label.size = Vector2(68.0, 30.0)
	pending_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_counter_label.add_theme_font_size_override("font_size", 11)
	pending_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	organ_screen.add_child(pending_counter_label)

	pending_next_button = Button.new()
	pending_next_button.name = "PendingNextButton"
	pending_next_button.text = ">"
	pending_next_button.position = Vector2(1020.0, 274.0)
	pending_next_button.size = Vector2(36.0, 30.0)
	pending_next_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pending_next_button.pressed.connect(_show_next_pending_organ)
	organ_screen.add_child(pending_next_button)
	_refresh_pending_organ_card()


func _install_organ_guidance() -> void:
	organ_instruction_label = Label.new()
	organ_instruction_label.name = "OrganInstruction"
	organ_instruction_label.position = Vector2(270.0, 184.0)
	organ_instruction_label.size = Vector2(610.0, 52.0)
	organ_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	organ_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	organ_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	organ_instruction_label.add_theme_font_size_override("font_size", 18)
	organ_instruction_label.add_theme_color_override("font_color", Color(0.44, 0.96, 0.86))
	organ_screen.add_child(organ_instruction_label)

	organ_description_label = Label.new()
	organ_description_label.name = "PendingOrganDescription"
	organ_description_label.position = Vector2(1070.0, 70.0)
	organ_description_label.size = Vector2(174.0, 500.0)
	organ_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	organ_description_label.add_theme_font_size_override("font_size", 13)
	organ_description_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.94))
	organ_screen.add_child(organ_description_label)

	var slot_labels := {
		brain_slot: "BRAIN SLOT",
		heart_slot: "HEART SLOT",
		legs_slot: "LEGS SLOT",
	}
	for slot_node in slot_labels:
		var slot := slot_node as OrganSlotControl
		if slot == null:
			continue
		var label := Label.new()
		label.name = "SlotTypeLabel"
		label.position = Vector2(0.0, -24.0)
		label.size = Vector2(slot.size.x, 22.0)
		label.text = tr(String(slot_labels[slot_node]))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.56, 0.94, 1.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)


func _add_pending_organ(organ: UpgradeData, select_added: bool = true) -> void:
	if organ == null:
		return
	var existing_index := pending_organs.find(organ)
	if existing_index < 0:
		pending_organs.append(organ)
		existing_index = pending_organs.size() - 1
	if select_added:
		pending_organ_index = existing_index
	_refresh_pending_organ_card()


func _remove_pending_organ(organ: UpgradeData) -> void:
	var removed_index := pending_organs.find(organ)
	if removed_index < 0:
		return
	pending_organs.remove_at(removed_index)
	if pending_organs.is_empty():
		pending_organ_index = -1
	else:
		pending_organ_index = clampi(
			pending_organ_index,
			0,
			pending_organs.size() - 1
		)
	_refresh_pending_organ_card()


func _show_previous_pending_organ() -> void:
	if pending_organs.size() <= 1:
		return
	pending_organ_index = posmod(
		pending_organ_index - 1,
		pending_organs.size()
	)
	_refresh_pending_organ_card()


func _show_next_pending_organ() -> void:
	if pending_organs.size() <= 1:
		return
	pending_organ_index = posmod(
		pending_organ_index + 1,
		pending_organs.size()
	)
	_refresh_pending_organ_card()


func _refresh_pending_organ_card() -> void:
	var has_pending := not pending_organs.is_empty()
	if has_pending:
		pending_organ_index = clampi(
			pending_organ_index,
			0,
			pending_organs.size() - 1
		)
		pending_organ = pending_organs[pending_organ_index]
		pending_organ_card.set_organ(pending_organ)
	else:
		pending_organ_index = -1
		pending_organ = null
		pending_organ_card.clear_organ()
	var has_pages := pending_organs.size() > 1
	if is_instance_valid(pending_previous_button):
		pending_previous_button.visible = has_pages
		pending_next_button.visible = has_pages
		pending_counter_label.visible = has_pages
		pending_counter_label.text = "%d / %d" % [
			pending_organ_index + 1,
			pending_organs.size(),
		]
	if is_instance_valid(pending_organ_label):
		pending_organ_label.text = (
			tr("PENDING ORGAN")
			if pending_organ == null
			else "%s / %s" % [
				tr("ORGAN"),
				tr(_get_organ_slot_key(pending_organ.organ_slot)),
			]
		)
	if is_instance_valid(organ_instruction_label):
		organ_instruction_label.text = (
			tr("NO PENDING ORGAN")
			if pending_organ == null
			else _get_organ_install_instruction(pending_organ.organ_slot)
		)
	if is_instance_valid(organ_description_label):
		organ_description_label.text = (
			tr("Installed organs remain active until replaced.")
			if pending_organ == null
			else "%s\n\n%s / %s\n\n%s" % [
				_get_upgrade_display_name(pending_organ),
				tr("ORGAN"),
				tr(_get_organ_slot_key(pending_organ.organ_slot)),
				tr(pending_organ.description),
			]
		)


func _get_organ_install_instruction(slot: UpgradeData.OrganSlot) -> String:
	match slot:
		UpgradeData.OrganSlot.BRAIN:
			return tr("DRAG THE BRAIN ORGAN TO THE HEAD SLOT")
		UpgradeData.OrganSlot.HEART:
			return tr("DRAG THE HEART ORGAN TO THE CHEST SLOT")
		UpgradeData.OrganSlot.LEGS:
			return tr("DRAG THE LEGS ORGAN TO THE LEG SLOT")
	return tr("DRAG THE %s ORGAN TO ITS MATCHING SLOT") % tr(
		_get_organ_slot_key(slot)
	)


func open_organ_screen(organ: UpgradeData) -> void:
	if organ == null:
		return

	organ_session.begin(false)
	offered_pending_organ = organ
	_add_pending_organ(organ)
	# Selecting an organ card acquires that exact resource. It must not be
	# offered again while it waits on the persistent surgery shelf.
	upgrade_pool.erase(organ)
	_claim_overlay(&"organ", organ_screen)
	_set_player_status_visible(false)

	level_up_panel.hide()
	_refresh_pending_organ_card()
	organ_close_button.text = tr("BACK TO MUTATIONS [ESC]")
	organ_close_button.show()
	refresh_organ_overview()
	_set_vignette_suppressed(true)
	organ_screen.show()
	organ_close_button.grab_focus()

	# Nem oldjuk fel a pause-t.
	# A játék állva marad az organ behelyezéséig.


func on_organ_installed(organ: UpgradeData) -> void:
	if organ == null:
		return

	if organ != pending_organ:
		push_warning("HUD: Unexpected organ was installed.")
		return

	player.apply_upgrade(organ.upgrade_id)
	play_sound(&"organ_install", -2.0, 0.035)
	refresh_organ_overview()

	# Az egyszer telepíthető organ kikerül a poolból.
	upgrade_pool.erase(organ)

	organ_session.install_completed = true
	_remove_pending_organ(organ)
	if organ == offered_pending_organ:
		offered_pending_organ = null
	if organ_session.shelf_organ != null:
		_add_pending_organ(organ_session.shelf_organ as UpgradeData)
		organ_session.shelf_organ = null
	else:
		_refresh_pending_organ_card()
	organ_close_button.text = tr("BACK TO GAME [ESC]")
	organ_close_button.show()
	organ_close_button.grab_focus()


func _on_organ_replacement_requested(
	slot_control: OrganSlotControl,
	current_organ: UpgradeData,
	replacement_organ: UpgradeData
) -> void:
	if replacement_organ != pending_organ:
		return
	if not organ_session.stage_replacement(
		slot_control,
		current_organ,
		replacement_organ
	):
		return
	replacement_message.text = (
		"%s\n%s\n%s\n%s?"
		% [
			tr("DO YOU WANT TO REPLACE"),
			_get_upgrade_display_name(current_organ),
			tr("WITH"),
			_get_upgrade_display_name(replacement_organ),
		]
	)
	replacement_confirmation.show()
	replacement_yes_button.grab_focus()


func _confirm_organ_replacement() -> void:
	if (
		organ_session.replacement_slot == null
		or organ_session.replacement_organ == null
		or organ_session.replaced_organ == null
	):
		_cancel_organ_replacement()
		return

	# Replacing is a swap, never a destructive consume: the removed organ goes
	# back to the pending shelf and remains available for a later installation.
	var replaced := organ_session.replaced_organ as UpgradeData
	var replacement := organ_session.replacement_organ as UpgradeData
	var slot := organ_session.replacement_slot as OrganSlotControl
	player.remove_organ_upgrade(replaced.upgrade_id)
	organ_session.shelf_organ = replaced
	_clear_replacement_request()
	slot.install_organ(replacement)


func _cancel_organ_replacement() -> void:
	_clear_replacement_request()
	if organ_screen.visible:
		organ_close_button.grab_focus()


func _clear_replacement_request() -> void:
	replacement_confirmation.hide()
	organ_session.clear_replacement()


func complete_level_up() -> void:
	_release_overlay(&"organ" if organ_screen.visible else &"level_up")
	if run_manager != null:
		run_manager.exit_level_up()
	else:
		get_tree().paused = false
		_set_player_status_visible(true)

	card_selection.reset_offer()
	player.confirm_level_up()


func on_run_state_changed(new_state: RunManager.RunState) -> void:
	_set_player_status_visible(
		new_state in [RunManager.RunState.PLAYING, RunManager.RunState.AIMING, RunManager.RunState.BOSS_INTRO]
	)

	if new_state == RunManager.RunState.PAUSED:
		_claim_overlay(&"pause", pause_panel)
		pause_panel.show()
		pause_main_panel.show()
		pause_settings_panel.hide()
		if is_instance_valid(pause_settings_frame):
			pause_settings_frame.hide()
		run_state_label.text = tr("PAUSED")
		run_state_label.show()
		resume_button.grab_focus()
		return

	pause_panel.hide()
	if is_instance_valid(pause_settings_frame):
		pause_settings_frame.hide()

	if new_state == RunManager.RunState.LEVEL_UP:
		run_state_label.text = tr("MUTATION")
		run_state_label.show()
	else:
		run_state_label.hide()
	if new_state in [RunManager.RunState.PLAYING, RunManager.RunState.AIMING]:
		_release_active_overlay()


func show_rush(rush_number: int, _duration_seconds: float) -> void:
	rush_label.text = tr("RUSH %d — INCOMING") % rush_number
	rush_label.show()
	play_sound(&"rush_warning", -3.0)


func hide_rush(_rush_number: int) -> void:
	rush_label.hide()


func _on_encounter_phase_changed(
	_phase_id: StringName,
	title: String
) -> void:
	if title.is_empty() or run_manager.elapsed_seconds <= 0.5:
		return
	var localized_title := tr(title)
	run_state_label.text = localized_title
	run_state_label.show()
	await get_tree().create_timer(
		1.6,
		true,
		false,
		true
	).timeout
	if (
		run_manager.state == RunManager.RunState.PLAYING
		and run_state_label.text == localized_title
	):
		run_state_label.hide()


func _on_arena_lock_changed(locked: bool) -> void:
	if locked:
		_show_boss_warning(
			tr("ARENA SEALED // WARDEN PROTOCOL ACTIVE"),
			2.6
		)


func show_boss(_boss: Node2D) -> void:
	boss_presentation.begin()
	boss_phase_label.text = tr("PHASE I")
	boss_panel.show()
	_show_boss_warning(tr("THE VISCERAL WARDEN AWAKENS"))
	_show_warden_dialogue(
		tr("No one escapes my test arena, foolish dog! Lets scrap this experiment!"),
		6.2
	)
	play_sound(&"rush_warning", -1.0, 0.015)


func update_boss_health(
	current_health: float,
	max_health: float
) -> void:
	boss_health_bar.max_value = maxf(max_health, 1.0)
	boss_health_bar.value = clampf(
		current_health,
		0.0,
		boss_health_bar.max_value
	)


func show_boss_phase(phase: int) -> void:
	boss_presentation.set_phase(phase)
	boss_phase_label.text = "%s %s" % [tr("PHASE"), (
		"I" if phase <= 1 else "II"
	)]
	if phase >= 2:
		_show_boss_warning(tr("THE WARDEN IS ENRAGED"))
		_show_warden_dialogue(
			tr("I need backup! The experiment is out of control!"),
			5.2
		)


func _install_warden_dialogue() -> void:
	warden_dialogue_panel = PanelContainer.new()
	warden_dialogue_panel.name = "WardenDialogue"
	warden_dialogue_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	warden_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	warden_dialogue_panel.position = Vector2(-500.0, -214.0)
	warden_dialogue_panel.size = Vector2(1000.0, 132.0)
	warden_dialogue_panel.z_index = 92
	warden_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.012, 0.02, 0.94)
	style.border_color = Color(0.95, 0.14, 0.10, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	warden_dialogue_panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	warden_dialogue_panel.add_child(content)
	var speaker := Label.new()
	speaker.text = tr("VISCERAL WARDEN")
	speaker.add_theme_font_size_override("font_size", 24)
	speaker.add_theme_color_override("font_color", Color(1.0, 0.26, 0.16))
	content.add_child(speaker)
	warden_dialogue_text = Label.new()
	warden_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warden_dialogue_text.add_theme_font_size_override("font_size", 22)
	warden_dialogue_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.91))
	content.add_child(warden_dialogue_text)
	add_child(warden_dialogue_panel)
	warden_dialogue_panel.hide()


func _show_warden_dialogue(message: String, duration: float) -> void:
	if not is_instance_valid(warden_dialogue_panel):
		return
	var generation := boss_presentation.next_dialogue_epoch()
	warden_dialogue_text.text = message
	warden_dialogue_panel.modulate.a = 0.0
	warden_dialogue_panel.show()
	var tween := warden_dialogue_panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(warden_dialogue_panel, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(duration, true, false, true).timeout
	if not boss_presentation.is_dialogue_current(generation):
		return
	var fade := warden_dialogue_panel.create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(warden_dialogue_panel, "modulate:a", 0.0, 0.24)
	fade.tween_callback(warden_dialogue_panel.hide)


func on_boss_defeated() -> void:
	boss_presentation.finish()
	boss_health_bar.value = 0.0
	_show_boss_warning(tr("WARDEN DESTROYED"))
	_show_victory_message()


func _install_victory_message() -> void:
	victory_message = Control.new()
	victory_message.name = "VictoryMessage"
	victory_message.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_message.z_index = 95
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -118.0
	center.offset_bottom = -118.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_message.add_child(center)
	var label := Label.new()
	label.name = "Label"
	label.text = tr("YOU WIN")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 68)
	label.add_theme_color_override("font_color", Color(0.38, 0.98, 1.0))
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.05, 0.08)
	)
	label.add_theme_constant_override("outline_size", 10)
	center.add_child(label)
	add_child(victory_message)
	victory_message.hide()


func _show_victory_message() -> void:
	if not is_instance_valid(victory_message):
		return
	var label := victory_message.find_child("Label", true, false) as Label
	if label != null:
		label.text = tr("YOU WIN")
	victory_message.modulate.a = 0.0
	victory_message.show()
	var tween := victory_message.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(victory_message, "modulate:a", 1.0, 0.45)
	tween.tween_interval(1.65)
	tween.tween_property(victory_message, "modulate:a", 0.0, 0.45)
	tween.tween_callback(victory_message.hide)


func _show_boss_warning(
	message: String,
	duration: float = 2.25
) -> void:
	var localized_message := tr(message)
	boss_warning_label.text = localized_message
	boss_warning_label.show()
	var polish := get_tree().root.get_node_or_null("UIPolish")
	if polish != null:
		polish.call(
			"pulse",
			boss_warning_label,
			Color(0.72, 0.94, 1.0)
		)
	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout
	if boss_warning_label.text == localized_message:
		boss_warning_label.hide()


func show_run_end(
	victory: bool,
	elapsed_seconds: float,
	kill_count: int,
	biomass_collected: float,
	level_reached: int,
	run_details: Dictionary = {}
) -> void:
	_claim_overlay(&"run_end", run_end_panel)
	pause_panel.hide()
	level_up_panel.hide()
	organ_screen.hide()
	run_state_label.hide()
	boss_panel.hide()
	boss_warning_label.hide()
	death_message.hide()
	biofabricator_sequence.hide()
	if is_instance_valid(victory_message):
		victory_message.hide()
	_set_vignette_suppressed(false)
	_set_player_status_visible(false)

	run_end_title.text = tr("RUN COMPLETE") if victory else tr("KODA LOST")
	play_sound(
		&"victory" if victory else &"defeat",
		-2.0
	)
	var summary_text := (
		"%s  %s     %s  %d\n%s  %.0f     %s  %d"
		% [
			tr("TIME"),
			format_duration(elapsed_seconds),
			tr("KILLS"),
			kill_count,
			tr("BIOMASS"),
			biomass_collected,
			tr("LEVEL"),
			level_reached
		]
	)
	var reward_message := String(run_details.get("reward_message", ""))
	var blueprint_id := StringName(run_details.get("blueprint_unlocked", &""))
	run_reward_icon.hide()
	if not reward_message.is_empty():
		run_end_title.text = tr("FLESHDRIVE RECOVERED")
		run_end_title.modulate = Color(0.5, 0.95, 1.0)
		if not blueprint_id.is_empty():
			var icon_path := FleshdriveCatalog.get_icon_path(blueprint_id)
			if not icon_path.is_empty():
				run_reward_icon.texture = load(icon_path) as Texture2D
				run_reward_icon.show()
			summary_text += (
				"\n\n%s: %s" % [
					tr("FLESHDRIVE ACQUIRED"),
					tr(FleshdriveCatalog.get_display_name(blueprint_id)),
				]
			)
		else:
			summary_text += "\n\n" + reward_message
	var leveled_id := StringName(run_details.get("fleshdrive_leveled", &""))
	if not leveled_id.is_empty():
		summary_text += (
			"\n%s: %s  LV %d" % [
				tr("FLESHDRIVE EVOLVED"),
				tr(FleshdriveCatalog.get_display_name(leveled_id)),
				int(run_details.get("fleshdrive_level", 1)),
			]
		)
	var source_lines: Array[String] = []
	for source: Dictionary in run_details.get("damage_sources", []):
		source_lines.append(
			"%s  %.0f" % [
				String(source.get("id", &"damage"))
					.replace("_", " ")
					.to_upper(),
				float(source.get("damage", 0.0)),
			]
		)
	if not source_lines.is_empty():
		summary_text += (
			"\n\n" + tr("TOP DAMAGE") + "\n"
			+ "   ".join(source_lines)
		)
	var selected_upgrades: Array = run_details.get(
		"selected_upgrades",
		[]
	)
	if not selected_upgrades.is_empty():
		var visible_upgrades := selected_upgrades.slice(
			0,
			mini(5, selected_upgrades.size())
		)
		var loadout_lines: Array[String] = []
		for upgrade_name in visible_upgrades:
			loadout_lines.append("- " + String(upgrade_name))
		summary_text += (
			"\n\n" + tr("LOADOUT") + "\n"
			+ "\n".join(loadout_lines)
		)
	run_summary_label.text = summary_text

	run_end_panel.show()
	if not reward_message.is_empty():
		run_end_title.pivot_offset = run_end_title.size * 0.5
		run_end_title.scale = Vector2(0.86, 0.86)
		var reward_tween := run_end_title.create_tween()
		reward_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reward_tween.set_trans(Tween.TRANS_BACK)
		reward_tween.set_ease(Tween.EASE_OUT)
		reward_tween.tween_property(
			run_end_title,
			"scale",
			Vector2.ONE,
			0.42
		)
	else:
		run_end_title.modulate = Color.WHITE
	end_restart_button.grab_focus()


func _install_run_reward_icon() -> void:
	run_reward_icon = TextureRect.new()
	run_reward_icon.name = "FleshdriveRewardIcon"
	run_reward_icon.custom_minimum_size = Vector2(118.0, 118.0)
	run_reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	run_reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	run_reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := run_end_title.get_parent()
	container.add_child(run_reward_icon)
	container.move_child(run_reward_icon, 1)
	run_reward_icon.hide()


func show_rebirth_sequence(
	instance_number: int,
	run_summary: Dictionary,
	lifetime_statistics: Dictionary
) -> void:
	_claim_overlay(&"rebirth", biofabricator_sequence)
	pause_panel.hide()
	level_up_panel.hide()
	organ_screen.hide()
	run_end_panel.hide()
	onboarding_panel.hide()
	run_state_label.hide()
	boss_panel.hide()
	boss_warning_label.hide()
	death_message.hide()
	_set_player_status_visible(false)
	_set_vignette_suppressed(true)
	play_sound(&"defeat", -4.0)
	biofabricator_sequence.start(
		instance_number,
		run_summary,
		lifetime_statistics
	)


func _on_start_new_run_requested() -> void:
	if run_manager != null:
		run_manager.restart_run()


func _on_flesh_tree_requested() -> void:
	if run_manager != null:
		run_manager.open_flesh_tree()


func _on_rebirth_main_menu_requested() -> void:
	if run_manager != null:
		run_manager.return_to_main_menu()


func format_duration(duration_seconds: float) -> String:
	var total_seconds := maxi(int(floor(duration_seconds)), 0)
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func on_resume_pressed() -> void:
	if run_manager != null:
		run_manager.set_manual_pause(false)


func open_pause_settings() -> void:
	pause_main_panel.hide()
	pause_settings_panel.show()
	if is_instance_valid(pause_settings_frame):
		pause_settings_frame.show()
	sync_pause_volume_control()
	pause_fullscreen_toggle.release_focus()


func close_pause_settings() -> void:
	pause_settings_panel.hide()
	if is_instance_valid(pause_settings_frame):
		pause_settings_frame.hide()
	pause_main_panel.show()
	pause_settings_button.grab_focus()


func open_organ_screen_from_pause() -> void:
	if run_manager == null:
		return

	if run_manager.state != RunManager.RunState.PAUSED:
		return

	organ_session.begin(true)
	offered_pending_organ = null
	_refresh_pending_organ_card()
	_claim_overlay(&"organ", organ_screen)
	_set_player_status_visible(false)
	pause_panel.hide()
	organ_close_button.show()
	organ_close_button.text = tr("BACK TO PAUSE [ESC]")
	refresh_organ_overview()
	_set_vignette_suppressed(true)
	organ_screen.show()
	run_manager.set_pause_overlay_locked(true)
	organ_close_button.grab_focus()


func close_organ_screen_to_pause() -> void:
	if not organ_session.opened_from_pause:
		return

	organ_session.opened_from_pause = false
	_claim_overlay(&"pause", pause_panel)
	organ_screen.hide()
	_set_vignette_suppressed(false)
	organ_close_button.hide()
	pause_main_panel.show()
	pause_settings_panel.hide()
	if is_instance_valid(pause_settings_frame):
		pause_settings_frame.hide()
	pause_panel.show()

	if run_manager != null:
		run_manager.set_pause_overlay_locked(false)

	pause_organ_button.grab_focus()


func _on_organ_close_pressed() -> void:
	if replacement_confirmation.visible:
		_cancel_organ_replacement()
		return
	if organ_session.opened_from_pause:
		close_organ_screen_to_pause()
		return
	if organ_session.install_completed:
		organ_session.install_completed = false
		organ_session.shelf_organ = null
		offered_pending_organ = null
		_refresh_pending_organ_card()
		organ_screen.hide()
		organ_close_button.hide()
		_set_vignette_suppressed(false)
		complete_level_up()
		return
	if pending_organ != null:
		_cancel_pending_organ_selection()


func _cancel_pending_organ_selection() -> void:
	_clear_replacement_request()
	if offered_pending_organ != null:
		var cancelled_organ := offered_pending_organ
		offered_pending_organ = null
		_remove_pending_organ(cancelled_organ)
		if not upgrade_pool.has(cancelled_organ):
			upgrade_pool.append(cancelled_organ)
	else:
		_refresh_pending_organ_card()
	organ_screen.hide()
	organ_close_button.hide()
	_set_vignette_suppressed(false)
	level_up_panel.show()
	card_selection.locked = false
	for card in upgrade_cards:
		card.disabled = false
	upgrade_card_1.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if (
		organ_screen.visible
		and event.is_action_pressed("ui_cancel")
	):
		_on_organ_close_pressed()
		get_viewport().set_input_as_handled()


func _set_vignette_suppressed(suppressed: bool) -> void:
	for filter in get_tree().get_nodes_in_group("post_process_filter"):
		if filter.has_method("set_vignette_suppressed"):
			filter.call("set_vignette_suppressed", suppressed)


func on_pause_fullscreen_toggled(enabled: bool) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.call("set_fullscreen", enabled)


func sync_pause_volume_control() -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	pause_fullscreen_toggle.set_pressed_no_signal(
		bool(settings.fullscreen_enabled)
	)
	_populate_pause_resolution_options()
	pause_volume_slider.set_value_no_signal(
		float(settings.master_volume)
	)
	pause_crt_slider.set_value_no_signal(
		float(settings.crt_intensity) * 100.0
	)
	pause_bloom_slider.set_value_no_signal(
		float(settings.bloom_intensity) * 100.0
	)
	pause_chromatic_slider.set_value_no_signal(
		float(settings.chromatic_aberration) * 100.0
	)
	pause_bit_reducer_slider.set_value_no_signal(
		float(settings.bit_reduction) * 100.0
	)
	pause_volume_value_label.text = (
		"%d%%" % roundi(pause_volume_slider.value)
	)
	update_pause_effect_label(
		pause_crt_value_label,
		pause_crt_slider.value
	)
	update_pause_effect_label(
		pause_bloom_value_label,
		pause_bloom_slider.value
	)
	update_pause_effect_label(
		pause_chromatic_value_label,
		pause_chromatic_slider.value
	)
	update_pause_effect_label(
		pause_bit_reducer_value_label,
		pause_bit_reducer_slider.value
	)
	_populate_pause_language_options()


func _populate_pause_resolution_options() -> void:
	pause_resolution_option.clear()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	var selected_index := 0
	for option in settings.call("get_resolution_options"):
		var index := pause_resolution_option.item_count
		pause_resolution_option.add_item(String(option.get("label", "")))
		var resolution := Vector2i(option.get("size", Vector2i.ZERO))
		pause_resolution_option.set_item_metadata(index, resolution)
		if resolution == Vector2i(settings.selected_resolution):
			selected_index = index
	pause_resolution_option.select(selected_index)


func _on_pause_resolution_selected(index: int) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	settings.call(
		"set_resolution",
		Vector2i(pause_resolution_option.get_item_metadata(index))
	)


func _populate_pause_language_options() -> void:
	pause_language_option.clear()
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	var selected_index := 0
	for option in settings.call("get_language_options"):
		var index := pause_language_option.item_count
		pause_language_option.add_item(tr(String(option.get("label", ""))))
		pause_language_option.set_item_metadata(index, String(option.get("code", "")))
		pause_language_option.set_item_disabled(index, not bool(option.get("enabled", false)))
		if String(option.get("code", "")) == String(settings.language_code):
			selected_index = index
	pause_language_option.select(selected_index)


func _on_pause_language_selected(index: int) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings == null:
		return
	settings.call(
		"set_language",
		String(pause_language_option.get_item_metadata(index))
	)
	_refresh_pause_dynamic_localization()


func _refresh_pause_dynamic_localization() -> void:
	_populate_pause_language_options()
	var tabs := pause_settings_panel.get_node_or_null(
		"SettingsTabs"
	) as TabContainer
	if tabs != null and tabs.get_tab_count() >= 2:
		tabs.set_tab_title(0, tr("DISPLAY & AUDIO"))
		tabs.set_tab_title(1, tr("GAMEPLAY & ACCESSIBILITY"))
	if onboarding_panel.visible:
		_configure_onboarding_for_active_drive()


func on_pause_volume_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_master_volume(value)
	pause_volume_value_label.text = "%d%%" % roundi(value)


func on_pause_crt_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_crt_intensity(value / 100.0)
	update_pause_effect_label(pause_crt_value_label, value)


func on_pause_bloom_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_bloom_intensity(value / 100.0)
	update_pause_effect_label(pause_bloom_value_label, value)


func on_pause_chromatic_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_chromatic_aberration(value / 100.0)
	update_pause_effect_label(pause_chromatic_value_label, value)


func on_pause_bit_reducer_changed(value: float) -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null:
		settings.set_bit_reduction(value / 100.0)
	update_pause_effect_label(pause_bit_reducer_value_label, value)


func update_pause_effect_label(label: Label, value: float) -> void:
	label.text = "OFF" if value <= 0.0 else "%d%%" % roundi(value)


func on_restart_pressed() -> void:
	if run_manager != null:
		run_manager.restart_run()


func on_quit_pressed() -> void:
	if run_manager != null:
		run_manager.quit_game()


func on_return_to_main_menu_pressed() -> void:
	if run_manager != null:
		run_manager.set_pause_overlay_locked(false)
	get_tree().paused = false
	Engine.time_scale = 1.0
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("prepare_scene_change")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func show_onboarding() -> void:
	_set_player_status_visible(false)
	_claim_overlay(&"onboarding", onboarding_panel)
	_configure_onboarding_for_active_drive()
	onboarding_panel.show()

	if run_manager != null:
		run_manager.enter_onboarding()

	onboarding_start_button.grab_focus()


func show_fleshdrive_operation() -> void:
	_set_player_status_visible(false)
	_claim_overlay(&"operation", fleshdrive_operation_screen)
	onboarding_panel.hide()
	_set_vignette_suppressed(true)
	if run_manager != null:
		run_manager.enter_operation()
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	fleshdrive_operation_screen.present(meta_progression)


func _claim_overlay(id: StringName, overlay: Control) -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("claim_overlay", id, overlay)
	else:
		overlay.show()


func _release_overlay(id: StringName) -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("release_overlay", id)


func _release_active_overlay() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow == null:
		return
	var active_id := StringName(flow.get("active_overlay_id"))
	if not active_id.is_empty():
		flow.call("release_overlay", active_id)


func _on_fleshdrive_selected(fleshdrive_id: StringName) -> void:
	var core_level := 1
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		core_level = int(meta_progression.call(
			"get_fleshdrive_level",
			fleshdrive_id
		))
	player.configure_fleshdrive(fleshdrive_id, core_level)
	_update_koda_portrait(fleshdrive_id)
	fleshdrive_operation_screen.hide()
	if run_manager != null:
		run_manager.exit_operation()
	_set_vignette_suppressed(false)
	refresh_organ_overview()
	play_sound(&"card_select", -3.0, 0.025, &"UI")
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null and not bool(settings.tutorials_enabled):
		onboarding_panel.hide()
		_set_player_status_visible(true)
	else:
		show_onboarding()


func _configure_onboarding_for_active_drive() -> void:
	var definition := FleshdriveCatalog.get_definition(
		player.active_fleshdrive_id
	)
	var style := String(definition.get("style", ""))
	if style.is_empty():
		style = String(definition.get("build", "ADAPT AND SURVIVE"))
	onboarding_goal_label.text = (
		"%s // %s"
		% [
			String(definition.get("name", "FLESHDRIVE")).to_upper(),
			tr(style.to_upper()),
		]
	)
	onboarding_instructions_label.text = tr("ONBOARDING_RUN_OBJECTIVE")
	onboarding_guide_label.hide()
	var active_key := "ONBOARDING_ACTIVE_ELECTRIC"
	if player.active_fleshdrive_id == FleshdriveCatalog.FIRE:
		active_key = "ONBOARDING_ACTIVE_FIRE"
	elif player.active_fleshdrive_id == FleshdriveCatalog.TELEKINETIC:
		active_key = "ONBOARDING_ACTIVE_TELEKINETIC"
	onboarding_guide_label.text = (
		tr("ONBOARDING_SYSTEM_GUIDE")
		+ "\n\n"
		+ tr(active_key)
	)
	onboarding_guide_button.text = tr("SHOW CONTROLS & SYSTEMS")


func _toggle_onboarding_guide() -> void:
	onboarding_guide_label.visible = not onboarding_guide_label.visible
	onboarding_guide_button.text = (
		tr("HIDE CONTROLS & SYSTEMS")
		if onboarding_guide_label.visible
		else tr("SHOW CONTROLS & SYSTEMS")
	)


func complete_onboarding() -> void:
	# Test harnesses and accessibility flows may invoke BEGIN RUN directly.
	# Resolve that path to the safe default Core before closing onboarding.
	if (
		run_manager != null
		and run_manager.state == RunManager.RunState.OPERATION
	):
		_on_fleshdrive_selected(FleshdriveCatalog.ELECTRIC)
	onboarding_panel.hide()

	if run_manager != null:
		run_manager.exit_onboarding()
	else:
		_set_player_status_visible(true)
	_start_first_run_context_hints()


func _start_first_run_context_hints() -> void:
	var settings := get_tree().root.get_node_or_null("GameSettings")
	if settings != null and not bool(settings.tutorials_enabled):
		return
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if (
		meta_progression != null
		and int(meta_progression.get("total_runs")) > 0
	):
		return
	_show_context_hint_sequence.call_deferred()


func _show_context_hint_sequence() -> void:
	var hint := get_node_or_null("ContextHint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "ContextHint"
		hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
		hint.position = Vector2(-310.0, 92.0)
		hint.size = Vector2(620.0, 42.0)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.z_index = 105
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override(
			"font_color",
			Color(0.75, 0.96, 1.0)
		)
		hint.add_theme_color_override(
			"font_shadow_color",
			Color.BLACK
		)
		hint.add_theme_constant_override("shadow_offset_x", 2)
		hint.add_theme_constant_override("shadow_offset_y", 2)
		add_child(hint)
	var hints := [
		"MOVE TO EVADE // DANGEROUS ATTACKS USE BRIGHT TELEGRAPHS",
		"BIOMASS BUILDS THIS BODY // LEVEL UP TO CHOOSE A MUTATION",
		"ACTIVE SKILL // USE THE HUD KEY // AIMED SKILLS CAN BE CANCELLED",
		"PAUSE TO REVIEW ORGANS, WEAPONS AND ACTIVE SYNERGIES",
	]
	for hint_text in hints:
		if not is_instance_valid(hint):
			return
		hint.text = tr(hint_text)
		hint.modulate.a = 0.0
		hint.show()
		var tween := hint.create_tween()
		tween.tween_property(hint, "modulate:a", 1.0, 0.22)
		tween.tween_interval(2.3)
		tween.tween_property(hint, "modulate:a", 0.0, 0.32)
		await tween.finished
	hint.queue_free()


func _on_upgrade_levels_changed(_levels: Dictionary) -> void:
	refresh_organ_overview()


func refresh_organ_overview() -> void:
	if player == null:
		return

	var attack_mode_name := "MANUAL"
	match player.attack_mode:
		Koda.AttackMode.SEMI_AUTO:
			attack_mode_name = "SEMI AUTO"
		Koda.AttackMode.AUTO:
			attack_mode_name = "AUTO"

	organ_stats_label.text = (
		"LEVEL        %d\n"
		+ "HEALTH       %.0f / %.0f\n"
		+ "DAMAGE       %.1f\n"
		+ "ATTACK RATE  %.2f / sec\n"
		+ "RANGE        %.0f\n"
		+ "MOVE SPEED   %.0f\n"
		+ "BIOMASS      x%.2f\n"
		+ "PICKUP       %.0f\n"
		+ "WEAPON RATE  +%.0f%%\n"
		+ "WEAPONS      %d / %d\n"
		+ "TARGETING    %s\n"
		+ "DASH         %s"
	) % [
		player.current_level,
		player.current_health,
		player.max_health,
		player.attack_damage,
		1.0 / maxf(player.attack_interval, 0.01),
		player.attack_range,
		player.move_speed,
		player.biomass_gain_multiplier,
		player.biomass_pickup_radius,
		(1.0 / player.weapon_cooldown_multiplier - 1.0) * 100.0,
		player.get_unlocked_extra_weapon_count(),
		player.MAX_EXTRA_WEAPONS,
		attack_mode_name,
		"READY" if player.dash_unlocked else "LOCKED"
	]

	for child in item_summary.get_children():
		child.queue_free()
	for child in weapon_summary.get_children():
		child.queue_free()

	var item_count := 0
	var weapon_count := 0
	for upgrade in upgrade_pool:
		if upgrade == null:
			continue
		if upgrade.upgrade_kind == UpgradeData.UpgradeKind.ORGAN:
			continue

		var item_level := player.get_upgrade_level(upgrade.upgrade_id)
		if item_level <= 0:
			continue

		if upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON:
			weapon_summary.add_child(
				_create_loadout_card(upgrade, item_level, true)
			)
			weapon_count += 1
		else:
			item_summary.add_child(
				_create_loadout_card(upgrade, item_level, false)
			)
			item_count += 1

	if item_count == 0:
		item_summary.add_child(_create_empty_loadout_label("NO ITEMS"))
	if weapon_count == 0:
		var base_weapon_text := "BASE ARC ONLY"
		if player.active_fleshdrive_id == FleshdriveCatalog.FIRE:
			base_weapon_text = "BASE FLAME ONLY"
		elif (
			player.active_fleshdrive_id
			== FleshdriveCatalog.TELEKINETIC
		):
			base_weapon_text = "BASE KINETIC SHARD ONLY"
		weapon_summary.add_child(
			_create_empty_loadout_label(base_weapon_text)
		)
	_refresh_fleshdrive_overview()


func _refresh_fleshdrive_overview() -> void:
	var fleshdrive_id := player.active_fleshdrive_id
	var definition := FleshdriveCatalog.get_definition(fleshdrive_id)
	var icon_path := String(definition.get("icon", ""))
	if not icon_path.is_empty():
		fleshdrive_icon.texture = load(icon_path) as Texture2D
	fleshdrive_name_label.text = String(
		definition.get("name", "UNKNOWN CORE")
	)
	fleshdrive_level_label.text = "CORE LEVEL %d / %d" % [
		player.active_fleshdrive_level,
		FleshdriveCatalog.MAX_CORE_LEVEL,
	]
	fleshdrive_build_label.text = (
		String(definition.get("build", ""))
		+ _get_active_synergy_summary()
	)
	var tooltip := (
		String(definition.get("name", "FLESHDRIVE"))
		+ "\nCORE LEVEL %d / %d\n\n" % [
			player.active_fleshdrive_level,
			FleshdriveCatalog.MAX_CORE_LEVEL,
		]
		+ String(definition.get("operation", ""))
		+ "\n\n"
		+ String(definition.get("build", ""))
		+ "\n\nBoss victories recover matching Core fragments. "
		+ "Blueprints persist between runs."
		+ "\n\nSYNERGY TAGS\nMatching tags reinforce the same "
		+ "mechanic. Two or more matching tags form an active synergy."
	)
	$OrganScreen/FleshdrivePanel.tooltip_text = tooltip


func _get_active_synergy_summary() -> String:
	var counts: Dictionary = {}
	var active_keystone := "NONE"
	var build_counts: Dictionary = {}
	for upgrade in upgrade_pool:
		if (
			upgrade == null
			or player.get_upgrade_level(upgrade.upgrade_id) <= 0
		):
			continue
		if upgrade.keystone:
			active_keystone = _get_upgrade_display_name(upgrade)
		if not upgrade.build_archetype.is_empty():
			build_counts[upgrade.build_archetype] = int(build_counts.get(upgrade.build_archetype, 0)) + 1
		for tag in upgrade.get_effective_synergy_tags():
			if tag in [&"item", &"organ", &"weapon", &"universal"]:
				continue
			counts[tag] = int(counts.get(tag, 0)) + 1
	var ranked: Array[Dictionary] = []
	for tag in counts:
		ranked.append({"tag": tag, "count": counts[tag]})
	ranked.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["count"]) > int(b["count"])
	)
	var active_build := "UNFORMED"
	var active_build_id: StringName = &""
	var best_build_count := 0
	for build_id in build_counts:
		if int(build_counts[build_id]) > best_build_count:
			best_build_count = int(build_counts[build_id])
			active_build_id = StringName(build_id)
			active_build = String(build_id).replace("_", " ").to_upper()
	var build_total := 0
	var missing_parts: Array[String] = []
	if not active_build_id.is_empty():
		for upgrade in upgrade_pool:
			if upgrade == null or upgrade.build_archetype != active_build_id:
				continue
			build_total += 1
			if player.get_upgrade_level(upgrade.upgrade_id) <= 0 and missing_parts.size() < 3:
				missing_parts.append(_get_upgrade_display_name(upgrade))
	var completion := (
		"%d / %d" % [best_build_count, build_total]
		if build_total > 0
		else "0 / 0"
	)
	var missing_text := (
		"NONE" if missing_parts.is_empty() else " / ".join(missing_parts)
	)
	if ranked.is_empty():
		return "\n\nBUILD: %s (%s)\nKEYSTONE: %s\nMISSING: %s\nACTIVE SYNERGIES: NONE" % [active_build, completion, active_keystone, missing_text]
	var parts: Array[String] = []
	for index in range(mini(3, ranked.size())):
		parts.append(
			"%s x%d" % [
				String(ranked[index]["tag"])
					.replace("_", " ")
					.to_upper(),
				int(ranked[index]["count"]),
			]
		)
	return "\n\nBUILD: %s (%s)\nKEYSTONE: %s\nMISSING: %s\nACTIVE SYNERGIES: %s" % [active_build, completion, active_keystone, missing_text, " / ".join(parts)]


func _create_loadout_card(
	upgrade: UpgradeData,
	item_level: int,
	is_weapon: bool
) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = (
		Vector2(104.0, 78.0)
		if is_weapon
		else Vector2(62.0, 68.0)
	)
	_update_organ_hover_details()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.tooltip_text = _format_upgrade_tooltip(upgrade, item_level)

	var icon := TextureRect.new()
	icon.custom_minimum_size = (
		Vector2(72.0, 58.0)
		if is_weapon
		else Vector2(48.0, 48.0)
	)
	icon.texture = upgrade.card_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var item_level_label := Label.new()
	item_level_label.theme_type_variation = &"MonoLabel"
	item_level_label.text = "LV %d" % item_level
	item_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_level_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.98, 1.0, 1.0)
	)
	item_level_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.95)
	)
	item_level_label.add_theme_constant_override("shadow_offset_x", 1)
	item_level_label.add_theme_constant_override("shadow_offset_y", 1)
	item_level_label.add_theme_font_size_override("font_size", 10)
	card.add_child(item_level_label)
	card.mouse_entered.connect(
		_animate_loadout_card.bind(card, true)
	)
	card.mouse_exited.connect(
		_animate_loadout_card.bind(card, false)
	)
	return card


func _animate_loadout_card(
	card: Control,
	hovered: bool
) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		card,
		"scale",
		Vector2(1.045, 1.045) if hovered else Vector2.ONE,
		0.14
	)


func _format_upgrade_tooltip(
	upgrade: UpgradeData,
	level: int
) -> String:
	var title := _get_upgrade_display_name(upgrade)
	var kind_names := ["ITEM", "ORGAN", "WEAPON"]
	var effect := tr(upgrade.description)
	if effect.is_empty():
		effect = "Run upgrade selected %d time(s)." % level
	match upgrade.upgrade_id:
		&"conductive_marrow": effect = "+25% attack damage per level."
		&"rapid_synapses": effect = "15% faster base attacks per level."
		&"predator_tendons": effect = "+12% movement speed per level."
		&"biomass_receptors": effect = "+20% biomass gain per level."
		&"reinforced_carapace": effect = "+15 maximum health per level."
		&"pulse_capacitor": effect = "+20% chain-lightning range per level."
		&"impulse_gland": effect = "Unlocks Koda's combat dash."
		&"arc_heart": effect = "Unlocks chain lightning."
		&"reflex_cortex": effect = "Unlocks semi-automatic targeting."
		&"autonomic_reflex": effect = "Evolves targeting into full auto-attack."
		&"biomass_lure": effect = "Greatly expands biomass pickup range."
		&"hemo_recycler": effect = "Periodically heals Koda after kills."
		&"overload_vent": effect = "Secondary weapons recover 15% faster."
		&"kill_switch_nodes": effect = "Emits a scheduled electrical shock pulse."
		&"reflex_spurs": effect = "Improves the unlocked dash."
		&"quill_burst": effect = "Fires damaging quills around Koda."
		&"shock_ram": effect = "Turns dashing into a damaging attack."
		&"tail_lash": effect = "Sweeps nearby enemies around Koda."
		&"arc_spear": effect = "Launches a piercing electrical projectile."
		&"bone_shard_volley": effect = "Fires bone shards in a facing cone."
	var tag_names: Array[String] = []
	for tag in upgrade.get_effective_synergy_tags():
		tag_names.append(
			String(tag).replace("_", " ").to_upper()
		)
	effect += (
		"\n\nAFFINITY: "
		+ upgrade.fleshdrive_affinity.to_upper()
		+ "\nRARITY: "
		+ upgrade.rarity.to_upper()
		+ "\nTAGS: "
		+ ", ".join(tag_names)
	)
	return "%s\n%s - LEVEL %d / %d\n%s" % [
		title,
		kind_names[int(upgrade.upgrade_kind)],
		level,
		upgrade.max_level,
		effect,
	]


func _get_upgrade_display_name(upgrade: UpgradeData) -> String:
	if upgrade == null:
		return tr("UNKNOWN ORGAN")
	var source_name := upgrade.display_name.strip_edges()
	if source_name.is_empty():
		source_name = String(upgrade.upgrade_id).replace("_", " ")
	return tr(source_name.to_upper())


func _update_organ_hover_details() -> void:
	for slot in [legs_slot, heart_slot, brain_slot]:
		if slot.installed_organ_data == null:
			slot.tooltip_text = tr("EMPTY ORGAN SLOT")
			continue
		var data: UpgradeData = slot.installed_organ_data
		slot.tooltip_text = _format_upgrade_tooltip(
			data,
			maxi(player.get_upgrade_level(data.upgrade_id), 1)
		)
	if pending_organ_card.organ_data != null:
		pending_organ_card.tooltip_text = _format_upgrade_tooltip(
			pending_organ_card.organ_data,
			1
		)


func _create_empty_loadout_label(text: String) -> Label:
	var empty_label := Label.new()
	empty_label.text = text
	empty_label.add_theme_color_override(
		"font_color",
		Color(0.78, 0.84, 0.86, 0.88)
	)
	empty_label.add_theme_font_size_override("font_size", 13)
	return empty_label


func is_upgrade_available(upgrade: UpgradeData) -> bool:
	if upgrade == null:
		return false

	if player.current_level < upgrade.minimum_player_level:
		return false

	if (
		upgrade.fleshdrive_affinity != "universal"
		and upgrade.fleshdrive_affinity
		!= String(player.active_fleshdrive_id)
	):
		return false

	if player.get_upgrade_level(upgrade.upgrade_id) >= upgrade.max_level:
		return false

	if not upgrade.prerequisites_met(player.upgrade_levels):
		return false

	if (
		upgrade.build_archetype == &"thunder_god"
		and player.get_upgrade_level(&"arc_heart") <= 0
	):
		return false

	if (
		upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON
		and player.get_upgrade_level(upgrade.upgrade_id) == 0
		and not player.can_unlock_weapon(upgrade.upgrade_id)
	):
		return false

	if (
		upgrade.upgrade_id == &"pulse_capacitor"
		and not player.chain_unlocked
	):
		return false

	if (
		upgrade.upgrade_id == &"reflex_cortex"
		and (
			player.current_level < REFLEX_CORTEX_OFFER_LEVEL
			or player.has_selected_upgrade(&"reflex_cortex")
		)
	):
		return false

	if upgrade.upgrade_id == &"autonomic_reflex":
		if player.current_level < AUTO_ATTACK_OFFER_LEVEL:
			return false

		if player.attack_mode != Koda.AttackMode.SEMI_AUTO:
			return false

	if (
		upgrade.upgrade_id in [
			&"reflex_spurs",
			&"shock_ram",
			&"blazing_stride",
		]
		and not player.dash_unlocked
	):
		return false

	if (
		upgrade.upgrade_id == &"inertial_lattice"
		and player.get_upgrade_level(&"orbiting_debris") <= 0
	):
		return false

	return true
