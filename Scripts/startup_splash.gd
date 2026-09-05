class_name StartupSplash
extends Control


const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"
const PLESHOW_LOGO_SHEET := preload(
	"res://Assets/ui/screens/pleshow_soft_logo_animation.png"
)

var sequence_finished: bool = false
var allow_skip: bool = false
@onready var godot_stage: Control = %GodotStage
@onready var studio_stage: Control = %StudioStage
@onready var studio_logo: AnimatedSprite2D = %StudioLogo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	studio_logo.sprite_frames = _make_studio_logo_frames()
	_play_sequence.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if allow_skip and (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("ui_cancel")
		or event is InputEventMouseButton and event.pressed
	):
		_finish()


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
