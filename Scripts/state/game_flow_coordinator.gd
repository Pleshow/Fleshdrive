extends Node


signal flow_state_changed(previous: StringName, current: StringName, epoch: int)
signal overlay_changed(previous: StringName, current: StringName)
signal input_device_changed(device: StringName)


const PUBLIC_ARENA_ID: StringName = &"dusk_garden"

const PAUSING_STATES: Array[StringName] = [
	&"OPERATION", &"ONBOARDING", &"PAUSED", &"LEVEL_UP", &"BOSS_INTRO",
	&"DYING", &"REBIRTH", &"GAME_OVER", &"VICTORY",
]
const ALLOWED_TRANSITIONS := {
	&"MENU": [&"PLAYING"],
	&"PLAYING": [&"AIMING", &"OPERATION", &"ONBOARDING", &"PAUSED", &"LEVEL_UP", &"BOSS_INTRO", &"DYING", &"REBIRTH", &"GAME_OVER", &"VICTORY"],
	&"AIMING": [&"PLAYING", &"PAUSED", &"DYING", &"VICTORY"],
	&"OPERATION": [&"PLAYING", &"ONBOARDING", &"DYING", &"VICTORY"],
	&"ONBOARDING": [&"PLAYING", &"DYING", &"VICTORY"],
	&"PAUSED": [&"PLAYING", &"DYING"],
	&"LEVEL_UP": [&"PLAYING", &"DYING", &"VICTORY"],
	&"BOSS_INTRO": [&"PLAYING", &"DYING", &"VICTORY"],
	&"DYING": [&"REBIRTH", &"GAME_OVER"],
	&"REBIRTH": [&"GAME_OVER", &"PLAYING"],
	&"GAME_OVER": [&"PLAYING"],
	&"VICTORY": [&"REBIRTH", &"GAME_OVER"],
}

var flow_state: StringName = &"PLAYING"
var flow_epoch: int = 0
var active_overlay_id: StringName = &""
var active_overlay: Control
var last_input_device: StringName = &"keyboard_mouse"
var _input_guard_until_msec: int = 0
var _scene_instance_id: int = 0
var _transition_in_progress: bool = false
var selected_arena_id: StringName = PUBLIC_ARENA_ID


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene_instance_id = _current_scene_id()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(_delta: float) -> void:
	var current_id := _current_scene_id()
	if current_id == _scene_instance_id:
		return
	# Scene roots run their _ready() methods before this autoload receives its
	# next process tick.  The new scene therefore already owns the authoritative
	# initial state (MENU/PLAYING/OPERATION).  Never overwrite it here.
	_scene_instance_id = current_id


func _input(event: InputEvent) -> void:
	var next_device := last_input_device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_device = &"controller"
	elif event is InputEventKey or event is InputEventMouse:
		next_device = &"keyboard_mouse"
	if next_device != last_input_device:
		last_input_device = next_device
		input_device_changed.emit(last_input_device)


func request_state(current: StringName, target: StringName) -> bool:
	if _transition_in_progress or current != flow_state:
		return false
	if target == current:
		return true
	var allowed: Array = ALLOWED_TRANSITIONS.get(current, [])
	if target not in allowed:
		push_warning("GameFlow rejected transition %s -> %s" % [current, target])
		return false
	_transition_in_progress = true
	var previous := flow_state
	flow_state = target
	flow_epoch += 1
	_input_guard_until_msec = Time.get_ticks_msec() + 90
	get_tree().paused = target in PAUSING_STATES
	flow_state_changed.emit(previous, flow_state, flow_epoch)
	_transition_in_progress = false
	return true


func force_state(target: StringName, should_pause: bool = false) -> void:
	var previous := flow_state
	flow_state = target
	flow_epoch += 1
	get_tree().paused = should_pause
	flow_state_changed.emit(previous, flow_state, flow_epoch)


func claim_overlay(id: StringName, overlay: Control) -> bool:
	if id.is_empty() or not is_instance_valid(overlay):
		return false
	if is_instance_valid(active_overlay) and active_overlay != overlay:
		active_overlay.hide()
	var previous := active_overlay_id
	active_overlay_id = id
	active_overlay = overlay
	overlay.show()
	_input_guard_until_msec = Time.get_ticks_msec() + 70
	overlay_changed.emit(previous, active_overlay_id)
	return true


func release_overlay(id: StringName) -> bool:
	if id != active_overlay_id:
		return false
	if is_instance_valid(active_overlay):
		active_overlay.hide()
	var previous := active_overlay_id
	active_overlay_id = &""
	active_overlay = null
	overlay_changed.emit(previous, &"")
	return true


func can_accept_input() -> bool:
	return not _transition_in_progress and Time.get_ticks_msec() >= _input_guard_until_msec


func prepare_scene_change() -> void:
	flow_epoch += 1
	_transition_in_progress = false
	if is_instance_valid(active_overlay):
		active_overlay.hide()
	active_overlay_id = &""
	active_overlay = null
	_input_guard_until_msec = Time.get_ticks_msec() + 100
	get_tree().paused = false
	var lifecycle := get_tree().root.get_node_or_null("SceneLifecycle")
	if lifecycle != null:
		lifecycle.call("cancel_transients")


func set_selected_arena(arena_id: StringName) -> bool:
	if arena_id != PUBLIC_ARENA_ID:
		push_warning(
			"GameFlow rejected non-public arena: %s; Dusk Garden is scope-locked."
			% arena_id
		)
		return false
	selected_arena_id = PUBLIC_ARENA_ID
	return true


func reset_for_scene_change() -> void:
	# Backward-compatible explicit cleanup entry point.  State initialization is
	# deliberately left to the destination scene.
	prepare_scene_change()


func _current_scene_id() -> int:
	var scene := get_tree().current_scene
	return scene.get_instance_id() if is_instance_valid(scene) else 0


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		return
	if Input.get_connected_joypads().is_empty() and last_input_device == &"controller":
		last_input_device = &"keyboard_mouse"
		input_device_changed.emit(last_input_device)
