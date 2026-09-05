class_name DialoguePanel
extends Control


signal choice_selected(choice_id: StringName)

@export var characters_per_second: float = 42.0
@export var use_right_column_layout: bool = false
@export var right_column_width: float = 390.0

@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var choices_container: VBoxContainer = %Choices
@onready var continue_button: Button = %ContinueButton
@onready var portrait_frame: Control = $PortraitFrame
@onready var portrait_texture: Control = $PortraitFrame/Portrait
@onready var animated_portrait: AnimatedSprite2D = (
	$PortraitFrame/Portrait/AnimatedPortrait
)
@onready var dialogue_frame: Control = $DialogueFrame

var dialogue_entries: Array[Dictionary] = []
var dialogue_choices: Array[Dictionary] = []
var current_entry_index: int = 0
var visible_character_progress: float = 0.0
var is_typing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_screen_layout()
	resized.connect(_apply_screen_layout)
	portrait_texture.resized.connect(_layout_animated_portrait)
	continue_button.pressed.connect(advance)
	hide()


func _apply_screen_layout() -> void:
	portrait_texture.custom_minimum_size = Vector2.ZERO
	var safe_margin := clampf(size.x * 0.025, 18.0, 36.0)
	if use_right_column_layout:
		var column_width := clampf(right_column_width, 320.0, 520.0)
		var column_x := size.x - safe_margin - column_width
		var portrait_size := clampf(size.y * 0.27, 174.0, 202.0)
		portrait_frame.position = Vector2(
			size.x - safe_margin - portrait_size,
			92.0
		)
		portrait_frame.size = Vector2(portrait_size, portrait_size)
		call_deferred("_layout_animated_portrait")
		var dialogue_top := portrait_frame.position.y + portrait_size + 10.0
		dialogue_frame.position = Vector2(column_x, dialogue_top)
		dialogue_frame.size = Vector2(
			column_width,
			maxf(size.y - dialogue_top - safe_margin, 330.0)
		)
		return
	var dialogue_height := clampf(size.y * 0.30, 204.0, 244.0)
	var portrait_size := dialogue_height
	var bottom := size.y - safe_margin
	portrait_frame.position = Vector2(safe_margin, bottom - portrait_size)
	portrait_frame.size = Vector2(portrait_size, portrait_size)
	call_deferred("_layout_animated_portrait")
	var dialogue_x := safe_margin + portrait_size + 12.0
	dialogue_frame.position = Vector2(dialogue_x, bottom - dialogue_height)
	dialogue_frame.size = Vector2(
		maxf(size.x - dialogue_x - safe_margin, 360.0),
		dialogue_height
	)


func _layout_animated_portrait() -> void:
	if not is_instance_valid(animated_portrait):
		return
	animated_portrait.position = portrait_texture.size * 0.5
	var available := maxf(minf(
		portrait_texture.size.x,
		portrait_texture.size.y
	) - 8.0, 1.0)
	var portrait_scale := available / 320.0
	animated_portrait.scale = Vector2.ONE * portrait_scale


func _process(delta: float) -> void:
	if not visible or not is_typing:
		return
	visible_character_progress += characters_per_second * delta
	body_label.visible_characters = mini(
		int(visible_character_progress),
		body_label.get_total_character_count()
	)
	if (
		body_label.visible_characters
		>= body_label.get_total_character_count()
	):
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_accept"):
		return
	if choices_container.visible:
		return
	advance()
	get_viewport().set_input_as_handled()


func present(
	entries: Array[Dictionary],
	choices: Array[Dictionary]
) -> void:
	dialogue_entries = entries.duplicate(true)
	dialogue_choices = choices.duplicate(true)
	current_entry_index = 0
	show()
	animated_portrait.show()
	_clear_choices()
	_show_current_entry()
	call_deferred("_layout_animated_portrait")
	continue_button.grab_focus()


func advance() -> void:
	if is_typing:
		_finish_typing()
		return
	current_entry_index += 1
	if current_entry_index >= dialogue_entries.size():
		_show_choices()
		return
	_show_current_entry()


func _show_current_entry() -> void:
	if dialogue_entries.is_empty():
		_show_choices()
		return
	var entry: Dictionary = dialogue_entries[current_entry_index]
	speaker_label.text = tr(String(entry.get("speaker", "MIMICHU")))
	body_label.text = tr(String(entry.get("text", "")))
	body_label.visible_characters = 0
	visible_character_progress = 0.0
	is_typing = true
	animated_portrait.play(&"talk")
	continue_button.text = tr("CONTINUE  >    [SPACE]")
	continue_button.show()


func _finish_typing() -> void:
	is_typing = false
	animated_portrait.play(&"idle")
	body_label.visible_characters = -1
	continue_button.text = tr("NEXT  >    [SPACE]")


func _show_choices() -> void:
	is_typing = false
	animated_portrait.play(&"idle")
	continue_button.hide()
	choices_container.show()
	for index in range(dialogue_choices.size()):
		var choice: Dictionary = dialogue_choices[index]
		var button := Button.new()
		button.name = "Choice%02d" % (index + 1)
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.set_meta("ui_polish_skip", true)
		button.text = "[%d]  %s" % [
			index + 1,
			tr(String(choice.get("label", "CONTINUE"))),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.68, 0.96, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.68, 0.96, 1.0))
		button.pressed.connect(
			_on_choice_pressed.bind(
				StringName(choice.get("id", "continue"))
			)
		)
		choices_container.add_child(button)
		button.modulate.a = 0.0
		button.scale = Vector2(0.985, 0.985)
		var tween := button.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(index) * 0.045)
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.16)
		tween.tween_property(button, "scale", Vector2.ONE, 0.18)
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Button).grab_focus()


func _on_choice_pressed(choice_id: StringName) -> void:
	choice_selected.emit(choice_id)


func _clear_choices() -> void:
	choices_container.hide()
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
