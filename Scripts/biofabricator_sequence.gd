class_name BiofabricatorSequence
extends Control


signal start_new_run_requested
signal flesh_tree_requested
signal main_menu_requested

enum SequenceState {
	HIDDEN,
	PRINTING,
	DIALOGUE,
}

@export var printing_duration: float = 2.6

@onready var print_sprite: AnimatedSprite2D = %PrintSprite
@onready var print_blend_sprite: AnimatedSprite2D = %PrintBlendSprite
@onready var idle_sprite: AnimatedSprite2D = %IdleSprite
@onready var terminal_text: RichTextLabel = %TerminalText
@onready var run_summary_label: Label = %RunSummaryLabel
@onready var lifetime_summary_label: Label = %LifetimeSummaryLabel
@onready var stage_label: Label = %StageLabel
@onready var skip_button: Button = %SkipButton
@onready var dialogue_panel: DialoguePanel = %DialoguePanel
@onready var terminal_panel: Control = $Terminal
@onready var run_summary_panel: Control = $RunSummaryPanel
@onready var printer_glass: Control = $PrinterGlass
@onready var mimichu_portrait_frame: PanelContainer = (
	%DialoguePanel.get_node("PortraitFrame") as PanelContainer
)

var sequence_state: SequenceState = SequenceState.HIDDEN
var print_elapsed: float = 0.0
var current_instance_number: int = 1
var current_summary: Dictionary = {}
var current_statistics: Dictionary = {}
var statistics_panel: RunStatisticsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	printer_glass.set_meta("preserve_authored_ui_style", true)
	printer_glass.set_meta("ui_polish_skip", true)
	skip_button.pressed.connect(_finish_printing)
	dialogue_panel.choice_selected.connect(_on_choice_selected)
	statistics_panel = RunStatisticsPanel.new()
	statistics_panel.name = "RunStatisticsPanel"
	add_child(statistics_panel)
	statistics_panel.hide()
	# Compact run data sits in the middle column. Mimichu and the dialogue must
	# always render above it; only the deliberately expanded modal may cover it.
	dialogue_panel.z_index = 30
	# On the rebirth/printing screen Mimichu is an overlay, not a framed card.
	mimichu_portrait_frame.add_theme_stylebox_override(
		"panel", StyleBoxEmpty.new()
	)
	hide()


func _process(delta: float) -> void:
	if sequence_state != SequenceState.PRINTING:
		return
	print_elapsed += delta
	var progress := clampf(print_elapsed / printing_duration, 0.0, 1.0)
	_update_print_animation(progress)
	_update_terminal(progress)
	if progress >= 1.0:
		_finish_printing()


func _unhandled_input(event: InputEvent) -> void:
	if sequence_state != SequenceState.PRINTING:
		return
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
	):
		_finish_printing()
		get_viewport().set_input_as_handled()


func start(
	instance_number: int,
	run_summary: Dictionary,
	lifetime_statistics: Dictionary
) -> void:
	current_instance_number = maxi(instance_number, 1)
	current_summary = run_summary.duplicate(true)
	current_statistics = lifetime_statistics.duplicate(true)
	print_elapsed = 0.0
	sequence_state = SequenceState.PRINTING
	print_sprite.frame = 0
	print_sprite.modulate.a = 1.0
	print_sprite.show()
	print_blend_sprite.frame = 1
	print_blend_sprite.modulate.a = 0.0
	print_blend_sprite.show()
	idle_sprite.stop()
	idle_sprite.frame = 0
	idle_sprite.position = Vector2(425.0, 470.0)
	idle_sprite.hide()
	terminal_panel.show()
	run_summary_panel.show()
	printer_glass.show()
	dialogue_panel.hide()
	skip_button.show()
	stage_label.text = tr("BIOFABRICATION IN PROGRESS")
	var summaries := _format_run_summary()
	run_summary_label.text = String(summaries["last_body"])
	lifetime_summary_label.text = String(summaries["lifetime"])
	statistics_panel.present(current_summary)
	_update_terminal(0.0)
	show()
	skip_button.grab_focus()


func _finish_printing() -> void:
	if sequence_state != SequenceState.PRINTING:
		return
	sequence_state = SequenceState.DIALOGUE
	print_elapsed = printing_duration
	print_sprite.frame = 5
	print_sprite.hide()
	print_blend_sprite.hide()
	idle_sprite.show()
	idle_sprite.position = Vector2(425.0, 470.0)
	idle_sprite.play(&"idle")
	skip_button.hide()
	terminal_panel.show()
	run_summary_panel.show()
	printer_glass.show()
	stage_label.text = tr("NEURAL IMPRINT TRANSFER COMPLETE")
	_update_terminal(1.0)
	dialogue_panel.present(
		_get_mimichu_dialogue(
			int(current_statistics.get("deaths", 1))
		),
		[
			{
				"id": &"start_run",
				"label": "START NEW RUN",
			},
			{
				"id": &"flesh_tree",
				"label": "FLESH TREE",
			},
			{
				"id": &"main_menu",
				"label": "MAIN MENU",
			},
		]
	)


func _update_terminal(progress: float) -> void:
	var imprint_status := tr("SCANNING...")
	if progress >= 0.62:
		imprint_status = tr("STABILIZING...")
	if progress >= 1.0:
		imprint_status = tr("SUCCESS")
	terminal_text.text = (
		"[color=#6fe7ed]SUBJECT[/color]\nK0D4\n\n"
		+ "[color=#6fe7ed]INSTANCE[/color]\n#%03d\n\n"
		% current_instance_number
		+ "[color=#6fe7ed]NEURAL IMPRINT:[/color]\n"
		+ imprint_status
	)


func _update_print_animation(progress: float) -> void:
	var frame_position := clampf(progress, 0.0, 1.0) * 5.0
	var current_frame := mini(int(floor(frame_position)), 5)
	var next_frame := mini(current_frame + 1, 5)
	var blend := smoothstep(
		0.0,
		1.0,
		frame_position - float(current_frame)
	)
	print_sprite.frame = current_frame
	print_sprite.modulate.a = 1.0 - blend
	print_blend_sprite.frame = next_frame
	print_blend_sprite.modulate.a = blend


func _format_run_summary() -> Dictionary:
	return {
		"last_body": (
			"LAST BODY\n"
			+ "TIME       %s\n"
			+ "KILLS      %d\n"
			+ "BIOMASS    %.0f\n"
			+ "LEVEL      %d"
		) % [
			_format_duration(
				float(current_summary.get("elapsed_seconds", 0.0))
			),
			int(current_summary.get("kills", 0)),
			float(current_summary.get("biomass", 0.0)),
			int(current_summary.get("level", 1)),
		],
		"lifetime": (
			"LIFETIME\n"
			+ "DEATHS     %d\n"
			+ "RUNS       %d\n"
			+ "BOSSES     %d\n"
			+ "ALL KILLS  %d\n"
			+ "BEST TIME  %s"
		) % [
			int(current_statistics.get("deaths", 0)),
			int(current_statistics.get("runs", 0)),
			int(current_statistics.get("boss_victories", 0)),
			int(current_statistics.get("total_kills", 0)),
			_format_duration(
				float(current_statistics.get("best_time", 0.0))
			),
		],
	}


func _format_duration(duration_seconds: float) -> String:
	var total_seconds := maxi(int(floor(duration_seconds)), 0)
	return "%02d:%02d" % [
		int(total_seconds / 60.0),
		total_seconds % 60,
	]


func _get_mimichu_dialogue(deaths: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(current_statistics.get("runs", 0)) <= 1:
		result.append({
			"speaker": tr("MIMICHU"),
			"text": tr("MIMICHU_STATS_INTRO"),
		})
	var death_cause := String(current_summary.get("death_cause", "unknown")).to_lower()
	var remark_key := &"MIMICHU_REMARK_BALANCED_1"
	if death_cause.contains("crawler"):
		var crawler_lines: Array[StringName] = [
			&"MIMICHU_REMARK_CRAWLER_1", &"MIMICHU_REMARK_CRAWLER_2",
		]
		remark_key = crawler_lines[posmod(deaths, crawler_lines.size())]
	elif death_cause.contains("charger"):
		remark_key = &"MIMICHU_REMARK_CHARGER"
	elif death_cause.contains("spitter") or death_cause.contains("acid"):
		remark_key = &"MIMICHU_REMARK_SPITTER"
	elif death_cause.contains("warden") or death_cause.contains("boss"):
		remark_key = &"MIMICHU_REMARK_WARDEN"
	elif int(current_summary.get("kills", 0)) >= 200:
		remark_key = &"MIMICHU_REMARK_KILLER"
	elif float(current_summary.get("damage_received", 0.0)) <= 40.0:
		remark_key = &"MIMICHU_REMARK_GLASS"
	elif float(current_summary.get("biomass_missed", 0.0)) >= 100.0:
		remark_key = &"MIMICHU_REMARK_BIOMASS"
	else:
		var general_lines: Array[StringName] = [
			&"MIMICHU_REMARK_BALANCED_1",
			&"MIMICHU_REMARK_BALANCED_2",
			&"MIMICHU_REMARK_BALANCED_3",
		]
		remark_key = general_lines[posmod(
			current_instance_number + deaths, general_lines.size()
		)]
	result.append({"speaker": tr("MIMICHU"), "text": tr(remark_key)})
	var recovery_lines: Array[StringName] = [
		&"MIMICHU_RECOVERY_1", &"MIMICHU_RECOVERY_2", &"MIMICHU_RECOVERY_3",
	]
	result.append({
		"speaker": tr("MIMICHU"),
		"text": tr(recovery_lines[posmod(deaths, recovery_lines.size())]),
	})
	return result


func _on_choice_selected(choice_id: StringName) -> void:
	match choice_id:
		&"start_run":
			start_new_run_requested.emit()
		&"flesh_tree":
			flesh_tree_requested.emit()
		&"main_menu":
			main_menu_requested.emit()
