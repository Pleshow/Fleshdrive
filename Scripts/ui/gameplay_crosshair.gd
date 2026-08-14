class_name GameplayCrosshair
extends Control


@export var accent_color := Color(0.96, 0.69, 0.22, 0.72)
@export var shadow_color := Color(0.02, 0.025, 0.03, 0.72)
@export var radius: float = 10.0
@export var gap: float = 4.0
@export var player_dead_radius: float = 44.0

var run_manager: RunManager
var cursor_owned: bool = false
var displayed_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(34.0, 34.0)
	pivot_offset = size * 0.5
	z_index = 400
	run_manager = get_tree().get_first_node_in_group(
		"run_manager"
	) as RunManager
	queue_redraw()
	displayed_position = get_viewport().get_mouse_position()


func _process(_delta: float) -> void:
	if not is_instance_valid(run_manager):
		run_manager = get_tree().get_first_node_in_group(
			"run_manager"
		) as RunManager
	var gameplay_active := (
		run_manager != null
		and run_manager.state == RunManager.RunState.PLAYING
		and not get_tree().paused
	)
	visible = gameplay_active
	if gameplay_active:
		var target_position := get_viewport().get_mouse_position()
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(player):
			var camera := player.get_node_or_null("Camera2D") as Camera2D
			if camera != null:
				var player_screen := player.global_position - camera.get_screen_center_position() + get_viewport_rect().size * 0.5
				var controller_aim := Vector2.ZERO
				if player.has_method("get_controller_aim_direction"):
					controller_aim = player.call("get_controller_aim_direction")
				if controller_aim.length() >= 0.2:
					target_position = player_screen + controller_aim.normalized() * 170.0
				elif target_position.distance_to(player_screen) < player_dead_radius:
					var direction := (displayed_position - player_screen).normalized()
					if direction == Vector2.ZERO:
						direction = Vector2.RIGHT
					target_position = player_screen + direction * player_dead_radius
		displayed_position = displayed_position.lerp(target_position, 0.72)
		global_position = displayed_position - size * 0.5
		var settings := get_tree().root.get_node_or_null("GameSettings")
		scale = Vector2.ONE * (float(settings.crosshair_scale) if settings != null else 1.0)
		if not cursor_owned:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			cursor_owned = true
	elif cursor_owned:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cursor_owned = false


func _exit_tree() -> void:
	if cursor_owned:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _draw() -> void:
	var center := size * 0.5
	_draw_brackets(center + Vector2.ONE, shadow_color, 4.0)
	_draw_brackets(center, accent_color, 2.0)
	draw_rect(Rect2(center - Vector2.ONE, Vector2(3.0, 3.0)), accent_color, true)


func _draw_brackets(
	center: Vector2,
	color: Color,
	width: float
) -> void:
	var arm := maxf(radius - gap, 3.0)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var joint: Vector2 = center + Vector2(corner) * radius
		draw_line(joint, joint - Vector2(corner.x * arm, 0.0), color, width, false)
		draw_line(joint, joint - Vector2(0.0, corner.y * arm), color, width, false)
