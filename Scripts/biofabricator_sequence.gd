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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skip_button.pressed.connect(_finish_printing)
	dialogue_panel.choice_selected.connect(_on_choice_selected)
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
	var death_line := (
		"Easy now. The imprint held. Most of you came back "
		+ "in the correct places."
	)
	if deaths >= 20:
		death_line = (
			"Was that the twenty-third? Never mind. "
			+ "I made another you."
		)
	elif deaths >= 10:
		death_line = (
			"Again? Hold still. You always twitch before "
			+ "the eyes are finished."
		)
	elif deaths >= 5:
		death_line = (
			"The fabricator remembered your scars. "
			+ "I told it not to."
		)
	elif deaths >= 2:
		death_line = (
			"You are getting easier to print. "
			+ "I am not sure that is good."
		)
	return [
		{
			"speaker": tr("MIMICHU"),
			"text": tr(death_line),
		},
		{
			"speaker": tr("MIMICHU"),
			"text": tr(
				"The body is new. The memory is not. "
				+ "Your Blood Memory fragments are safe."
			),
		},
	]


func _on_choice_selected(choice_id: StringName) -> void:
	match choice_id:
		&"start_run":
			start_new_run_requested.emit()
		&"flesh_tree":
			flesh_tree_requested.emit()
		&"main_menu":
			main_menu_requested.emit()
