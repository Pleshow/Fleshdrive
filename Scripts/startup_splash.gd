class_name StartupSplash
extends Control


const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"
const GODOT_ICON := preload("res://icon.svg")
const PLESHOW_LOGO_SHEET := preload(
	"res://Assets/ui/screens/pleshow_soft_logo_animation.png"
)

var sequence_finished: bool = false
var allow_skip: bool = false
var godot_stage: Control
var studio_stage: Control
var studio_logo: AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_play_sequence.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if allow_skip and (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or event is InputEventMouseButton and event.pressed
	):
		_finish()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	godot_stage = CenterContainer.new()
	godot_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(godot_stage)
	var godot_column := VBoxContainer.new()
	godot_column.alignment = BoxContainer.ALIGNMENT_CENTER
	godot_column.add_theme_constant_override("separation", 22)
	godot_stage.add_child(godot_column)
	var godot_logo := TextureRect.new()
	godot_logo.custom_minimum_size = Vector2(132.0, 132.0)
	godot_logo.texture = GODOT_ICON
	godot_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	godot_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	godot_column.add_child(godot_logo)
	var godot_text := Label.new()
	godot_text.text = "MADE WITH GODOT GAME ENGINE"
	godot_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	godot_text.add_theme_font_size_override("font_size", 23)
	godot_text.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	godot_column.add_child(godot_text)

	studio_stage = CenterContainer.new()
	studio_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	studio_stage.hide()
	add_child(studio_stage)
	var studio_column := VBoxContainer.new()
	studio_column.alignment = BoxContainer.ALIGNMENT_CENTER
	studio_column.add_theme_constant_override("separation", 10)
	studio_stage.add_child(studio_column)
	var reveal_clip := Control.new()
	reveal_clip.custom_minimum_size = Vector2(444.0, 300.0)
	reveal_clip.clip_contents = true
	studio_column.add_child(reveal_clip)
	studio_logo = AnimatedSprite2D.new()
	studio_logo.position = Vector2(222.0, 146.0)
	studio_logo.scale = Vector2.ONE * 0.66
	studio_logo.sprite_frames = _make_studio_logo_frames()
	reveal_clip.add_child(studio_logo)
	var studio_name := Label.new()
	studio_name.name = "StudioName"
	studio_name.text = "PLESHOW SOFT"
	studio_name.modulate.a = 0.0
	studio_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_name.add_theme_font_size_override("font_size", 30)
	studio_name.add_theme_color_override("font_color", Color.WHITE)
	studio_column.add_child(studio_name)


func _play_sequence() -> void:
	allow_skip = false
	godot_stage.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(godot_stage, "modulate:a", 1.0, 0.55)
	intro.tween_interval(1.05)
	intro.tween_property(godot_stage, "modulate:a", 0.0, 0.42)
	await intro.finished
	if sequence_finished:
		return
	allow_skip = true
	godot_stage.hide()
	studio_stage.show()
	studio_stage.modulate.a = 1.0
	var studio_name := studio_stage.find_child("StudioName", true, false) as Label
	studio_logo.frame = 0
	studio_logo.play(&"reveal")
	await studio_logo.animation_finished
	var settle := create_tween()
	settle.set_trans(Tween.TRANS_QUAD)
	settle.set_ease(Tween.EASE_OUT)
	settle.tween_property(studio_name, "modulate:a", 1.0, 0.32)
	settle.tween_interval(0.9)
	settle.tween_property(studio_stage, "modulate:a", 0.0, 0.45)
	await settle.finished
	_finish()


func _make_studio_logo_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"reveal")
	frames.set_animation_loop(&"reveal", false)
	frames.set_animation_speed(&"reveal", 7.5)
	for row in range(2):
		for column in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = PLESHOW_LOGO_SHEET
			frame.region = Rect2(column * 444, row * 444, 444, 444)
			frames.add_frame(&"reveal", frame)
	return frames


func _finish() -> void:
	if sequence_finished:
		return
	sequence_finished = true
	var flow := get_tree().root.get_node_or_null("GameFlow")
	if flow != null:
		flow.call("prepare_scene_change")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
