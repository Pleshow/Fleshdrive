class_name FleshdriveOperationScreen
extends Control


signal fleshdrive_selected(fleshdrive_id: StringName)
signal back_requested

@onready var electric_card: Button = %ElectricCard
@onready var fire_card: Button = %FireCard
@onready var telekinetic_card: Button = %TelekineticCard
@onready var electric_level: Label = %ElectricLevel
@onready var fire_level: Label = %FireLevel
@onready var telekinetic_level: Label = %TelekineticLevel
@onready var telekinetic_icon: TextureRect = $TelekineticCard/Icon
@onready var telekinetic_locked_glyph: Label = (
	$TelekineticCard/LockedGlyph
)
@onready var telekinetic_name: Label = $TelekineticCard/Name
@onready var tank_slot: Button = %TankSlot
@onready var old_ones_slot: Button = %OldOnesSlot
@onready var details_title: Label = %DetailsTitle
@onready var details_text: Label = %DetailsText
@onready var implant_button: Button = %ImplantButton
@onready var back_button: Button = %BackButton
@onready var header: Label = $Header
@onready var mimichu_portrait: AnimatedSprite2D = (
	$MimichuPanel/Portrait
)
@onready var mimichu_dialogue: Label = $MimichuPanel/Dialogue

var selected_fleshdrive_id: StringName = FleshdriveCatalog.ELECTRIC
var meta_progression: Node
var fleshdrive_slots: Array[Button] = []
var mimichu_talk_generation: int = 0
var character_sheet_button: Button
var character_sheet_panel: CharacterSheetPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fleshdrive_slots = [
		electric_card,
		fire_card,
		telekinetic_card,
		tank_slot,
		old_ones_slot,
	]
	for card in [electric_card, fire_card, telekinetic_card]:
		card.set_meta("ui_hover_scale", 1.012)
	for empty_slot in [tank_slot, old_ones_slot]:
		empty_slot.set_meta("ui_polish_skip", true)
		empty_slot.mouse_default_cursor_shape = Control.CURSOR_ARROW
		empty_slot.position.y = 344.0
		empty_slot.size.y = 52.0
		var glyph := empty_slot.get_node_or_null("SlotGlyph") as CanvasItem
		if glyph != null:
			glyph.hide()
		var slot_name := empty_slot.get_node_or_null("SlotName") as Label
		if slot_name != null:
			slot_name.position = Vector2(8.0, 5.0)
			slot_name.size = Vector2(152.0, 20.0)
			slot_name.text = tr("ADDITIONAL PROTOTYPE")
			slot_name.add_theme_font_size_override("font_size", 10)
		var slot_state := empty_slot.get_node_or_null("SlotState") as Label
		if slot_state != null:
			slot_state.position = Vector2(8.0, 26.0)
			slot_state.size = Vector2(152.0, 18.0)
			slot_state.text = tr("IN DEVELOPMENT")
	electric_card.pressed.connect(
		_select_fleshdrive.bind(FleshdriveCatalog.ELECTRIC)
	)
	fire_card.pressed.connect(
		_select_fleshdrive.bind(FleshdriveCatalog.FIRE)
	)
	telekinetic_card.pressed.connect(
		_select_fleshdrive.bind(FleshdriveCatalog.TELEKINETIC)
	)
	implant_button.pressed.connect(_confirm_selection)
	back_button.pressed.connect(back_requested.emit)
	_install_character_sheet()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if is_instance_valid(character_sheet_panel) and character_sheet_panel.visible:
			character_sheet_panel.hide()
			character_sheet_button.grab_focus()
			get_viewport().set_input_as_handled()
			return
		back_requested.emit()
		get_viewport().set_input_as_handled()


func present(progression: Node) -> void:
	meta_progression = progression
	selected_fleshdrive_id = FleshdriveCatalog.ELECTRIC
	var operation_prompts: Array[StringName] = [
		&"MIMICHU_OPERATION_PROMPT",
		&"MIMICHU_OPERATION_PROMPT_2",
		&"MIMICHU_OPERATION_PROMPT_3",
	]
	var completed_runs := 0
	if meta_progression != null and meta_progression.has_method("get_statistics"):
		completed_runs = int(Dictionary(
			meta_progression.call("get_statistics")
		).get("runs", 0))
	mimichu_dialogue.text = tr(operation_prompts[
		posmod(completed_runs, operation_prompts.size())
	])
	mimichu_dialogue.visible_characters = 0
	header.text = tr("SELECT FLESHDRIVE FOR IMPLANTATION")
	if (
		meta_progression != null
		and meta_progression.has_method("consume_blueprint_notice")
	):
		var unlocked_id: StringName = meta_progression.call(
			"consume_blueprint_notice"
		)
		if not unlocked_id.is_empty():
			header.text = (
				tr("BLUEPRINT RESTORED: %s")
				% tr(FleshdriveCatalog.get_display_name(unlocked_id))
			)
	_refresh_unlocks()
	_preview_fleshdrive(selected_fleshdrive_id)
	_refresh_card_selection()
	show()
	_animate_card_reveal()
	_play_mimichu_intro()
	electric_card.grab_focus()


func _install_character_sheet() -> void:
	character_sheet_button = Button.new()
	character_sheet_button.name = "CharacterSheetButton"
	character_sheet_button.text = tr("KODA CHARACTER SHEET")
	character_sheet_button.position = Vector2(892.0, 636.0)
	character_sheet_button.size = Vector2(304.0, 64.0)
	character_sheet_button.process_mode = Node.PROCESS_MODE_ALWAYS
	character_sheet_button.pressed.connect(_show_character_sheet)
	add_child(character_sheet_button)
	character_sheet_panel = CharacterSheetPanel.new()
	character_sheet_panel.name = "CharacterSheetPanel"
	character_sheet_panel.position = Vector2(220.0, 76.0)
	character_sheet_panel.size = Vector2(840.0, 580.0)
	character_sheet_panel.z_index = 40
	add_child(character_sheet_panel)
	character_sheet_panel.hide()


func _show_character_sheet() -> void:
	var player := get_tree().get_first_node_in_group("player") as Koda
	character_sheet_panel.present(KodaStatSheet.snapshot(player))


func _refresh_unlocks() -> void:
	var electric_unlocked := true
	var fire_unlocked := false
	var telekinetic_unlocked := false
	electric_card.disabled = not electric_unlocked
	# Prototype-only hearts remain visible, but cannot receive focus or clicks.
	fire_card.disabled = not fire_unlocked
	# Keep the third prototype archetype visible in the selector. Its blueprint
	# is intentionally unavailable, but the real card communicates the future
	# slot more clearly than an empty placeholder.
	telekinetic_card.show()
	telekinetic_card.disabled = not telekinetic_unlocked
	telekinetic_icon.show()
	telekinetic_locked_glyph.hide()
	telekinetic_name.text = tr("NOETIC HEART")
	telekinetic_name.add_theme_color_override(
		"font_color",
		Color(0.72, 0.42, 1.0, 1.0)
		if telekinetic_unlocked
		else Color(0.42, 0.52, 0.54, 0.82)
	)
	electric_level.text = tr("CORE LV %d / %d") % [
		_get_core_level(FleshdriveCatalog.ELECTRIC),
		FleshdriveCatalog.MAX_CORE_LEVEL,
	]
	fire_level.text = tr("CORE LV %d / %d") % [
		_get_core_level(FleshdriveCatalog.FIRE),
		FleshdriveCatalog.MAX_CORE_LEVEL,
	] if fire_unlocked else tr("IN DEVELOPMENT")
	telekinetic_level.text = (
		tr("CORE LV %d / %d") % [
			_get_core_level(FleshdriveCatalog.TELEKINETIC),
			FleshdriveCatalog.MAX_CORE_LEVEL,
		]
		if telekinetic_unlocked
		else tr("IN DEVELOPMENT")
	)


func _select_fleshdrive(fleshdrive_id: StringName) -> void:
	if not _is_unlocked(fleshdrive_id):
		_preview_unavailable_fleshdrive(fleshdrive_id)
		return
	selected_fleshdrive_id = fleshdrive_id
	_preview_fleshdrive(fleshdrive_id)
	_refresh_card_selection()
	var selected_card := _get_card(fleshdrive_id)
	if selected_card != null:
		var polish := get_tree().root.get_node_or_null("UIPolish")
		if polish != null:
			polish.call(
				"pulse",
				selected_card,
				FleshdriveCatalog.get_definition(
					fleshdrive_id
				).get("accent", Color.WHITE)
			)
	implant_button.grab_focus()


func _preview_unavailable_fleshdrive(fleshdrive_id: StringName) -> void:
	var definition := FleshdriveCatalog.get_definition(fleshdrive_id)
	details_title.text = tr(String(definition.get("name", "FLESHDRIVE")))
	details_title.add_theme_color_override("font_color", Color(0.58, 0.6, 0.62))
	details_text.text = tr("IN DEVELOPMENT")
	implant_button.text = tr("IN DEVELOPMENT")
	implant_button.disabled = true


func _preview_fleshdrive(fleshdrive_id: StringName) -> void:
	implant_button.disabled = false
	var definition := FleshdriveCatalog.get_definition(fleshdrive_id)
	var core_level := _get_core_level(fleshdrive_id)
	details_title.text = tr(String(definition.get("name", "FLESHDRIVE")))
	details_text.text = (
		tr(String(definition.get("operation", "")))
		+ "\n\n"
		+ tr(String(definition.get("build", "")))
		+ "\n\n"
		+ _get_core_bonus_description(fleshdrive_id, core_level)
	)
	var accent: Color = definition.get("accent", Color.WHITE)
	details_title.add_theme_color_override("font_color", accent)
	implant_button.text = (
		tr("IMPLANT %s [ENTER]")
		% tr(String(definition.get("short_name", "CORE")))
	)


func _get_core_bonus_description(
	fleshdrive_id: StringName,
	core_level: int
) -> String:
	var bonus_levels := maxi(core_level - 1, 0)
	var shared := tr("CORE LV %d: +%d%% BASE ATTACK DAMAGE") % [
		core_level,
		bonus_levels * 3,
	]
	match fleshdrive_id:
		FleshdriveCatalog.ELECTRIC:
			return shared + tr(" / +%d%% CHAIN DAMAGE") % (
				bonus_levels * 4
			)
		FleshdriveCatalog.FIRE:
			return shared + tr(" / +%d%% BURN DAMAGE") % (
				bonus_levels * 8
			)
		FleshdriveCatalog.TELEKINETIC:
			return shared + tr(" / +%d%% KINETIC DAMAGE / +%d%% FORCE") % [
				bonus_levels * 7,
				bonus_levels * 5,
			]
	return shared


func _confirm_selection() -> void:
	if not _is_unlocked(selected_fleshdrive_id):
		return
	implant_button.disabled = true
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	var center := implant_button.get_global_rect().get_center()
	if visual_effects != null and visual_effects.has_method("play_ui"):
		visual_effects.call("play_ui", &"organ_flesh_pulse", center, 0.86)
	var pulse_tween := implant_button.create_tween()
	pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse_tween.tween_property(implant_button, "scale", Vector2.ONE * 1.035, 0.055)
	pulse_tween.tween_property(implant_button, "scale", Vector2.ONE, 0.055)
	await get_tree().create_timer(0.07, true, false, true).timeout
	if visual_effects != null and visual_effects.has_method("play_ui"):
		visual_effects.call("play_ui", &"organ_activation", center, 0.78)
	fleshdrive_selected.emit(selected_fleshdrive_id)
	implant_button.disabled = false


func _get_card(fleshdrive_id: StringName) -> Button:
	match fleshdrive_id:
		FleshdriveCatalog.ELECTRIC:
			return electric_card
		FleshdriveCatalog.FIRE:
			return fire_card
		FleshdriveCatalog.TELEKINETIC:
			return telekinetic_card
	return null


func _refresh_card_selection() -> void:
	var cards := {
		FleshdriveCatalog.ELECTRIC: electric_card,
		FleshdriveCatalog.FIRE: fire_card,
		FleshdriveCatalog.TELEKINETIC: telekinetic_card,
	}
	for fleshdrive_id: StringName in cards:
		var card := cards[fleshdrive_id] as Button
		var is_selected := (
			fleshdrive_id == selected_fleshdrive_id
		)
		card.self_modulate = (
			Color.WHITE
			if is_selected
			else Color(0.42, 0.45, 0.47, 0.82)
		)
		if fleshdrive_id == FleshdriveCatalog.FIRE:
			card.self_modulate = Color(0.42, 0.42, 0.44, 0.9)
		var selected_frame := card.get_node_or_null(
			"SelectedFrame"
		) as Control
		if selected_frame != null:
			selected_frame.visible = is_selected
	var electric_icon := electric_card.get_node_or_null("Icon") as TextureRect
	if electric_icon != null:
		electric_icon.self_modulate = Color.WHITE
		electric_icon.modulate = Color.WHITE
		electric_icon.z_index = 3


func _play_mimichu_intro() -> void:
	mimichu_talk_generation += 1
	var generation := mimichu_talk_generation
	mimichu_portrait.play(&"talk")
	mimichu_dialogue.visible_characters = 0
	var character_count := mimichu_dialogue.text.length()
	var shown := 0.0
	while (
		generation == mimichu_talk_generation
		and is_visible_in_tree()
		and shown < float(character_count)
	):
		await get_tree().process_frame
		shown += 34.0 * get_process_delta_time()
		mimichu_dialogue.visible_characters = mini(int(shown), character_count)
	if (
		generation == mimichu_talk_generation
		and is_instance_valid(mimichu_portrait)
	):
		mimichu_dialogue.visible_characters = -1
		mimichu_portrait.play(&"idle")


func _animate_card_reveal() -> void:
	for card_index in range(fleshdrive_slots.size()):
		var card := fleshdrive_slots[card_index]
		var final_position := card.position
		card.position = final_position + Vector2(0.0, 18.0)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.055 * float(card_index))
		tween.tween_property(card, "position", final_position, 0.24)
		tween.tween_property(card, "modulate:a", 1.0, 0.2)


func _is_unlocked(fleshdrive_id: StringName) -> bool:
	if fleshdrive_id != FleshdriveCatalog.ELECTRIC:
		return false
	if meta_progression == null:
		return true
	return bool(meta_progression.call(
		"is_fleshdrive_unlocked",
		fleshdrive_id
	))


func _get_core_level(fleshdrive_id: StringName) -> int:
	if meta_progression == null:
		return 1
	return int(meta_progression.call(
		"get_fleshdrive_level",
		fleshdrive_id
	))
