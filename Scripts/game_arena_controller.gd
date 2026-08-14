class_name GameArenaController
extends Node2D


const ISOMETRIC_ARENA_SCENE: PackedScene = preload(
	"res://Scenes/isometric_slime_arena.tscn"
)
const ISOMETRIC_ARENA_ID: StringName = &"sludgeworks"
const DUSK_GARDEN_SCENE: PackedScene = preload(
	"res://Scenes/dusk_garden_arena.tscn"
)
const DUSK_GARDEN_ARENA_ID: StringName = &"dusk_garden"


func _ready() -> void:
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var selected_arena := &"bio_lab"
	if flow != null:
		selected_arena = StringName(flow.get("selected_arena_id"))
	match selected_arena:
		ISOMETRIC_ARENA_ID:
			_activate_isometric_arena()
		DUSK_GARDEN_ARENA_ID:
			_activate_dusk_garden_arena()


func _activate_isometric_arena() -> void:
	var arena := ISOMETRIC_ARENA_SCENE.instantiate() as IsometricSlimeArena
	if arena == null:
		push_error("GameArenaController: isometric arena failed to instantiate.")
		return
	_replace_arena(arena)
	_configure_arena_runtime(arena)
	var darkness := get_node_or_null("WorldDarkness") as CanvasModulate
	if darkness != null:
		darkness.color = Color(0.105, 0.155, 0.125, 1.0)
	_show_arena_identification(
		"SLUDGEWORKS // BASIN 07",
		"GRAY DECK: WALKABLE   //   GREEN RUNOFF: RESTRICTED",
		Color(0.20, 1.0, 0.28),
		Color(0.56, 1.0, 0.62)
	)


func _activate_dusk_garden_arena() -> void:
	var arena := DUSK_GARDEN_SCENE.instantiate() as DuskGardenArena
	if arena == null:
		push_error("GameArenaController: dusk garden failed to instantiate.")
		return
	_replace_arena(arena)
	_configure_arena_runtime(arena)
	var darkness := get_node_or_null("WorldDarkness") as CanvasModulate
	if darkness != null:
		darkness.color = Color(0.18, 0.20, 0.27, 1.0)
	for filter in get_tree().get_nodes_in_group("post_process_filter"):
		if filter.has_method("set_minimalist_pixel_mode"):
			filter.call("set_minimalist_pixel_mode", true)
	_show_arena_identification(
		"DUSK GARDEN // NIGHT 01",
		"THE FIELD IS QUIET   //   KEEP MOVING",
		Color(0.30, 0.66, 1.0),
		Color(0.66, 0.90, 1.0)
	)


func _replace_arena(arena: Node2D) -> void:
	var previous_arena := get_node_or_null("Arena")
	if previous_arena != null:
		remove_child(previous_arena)
		previous_arena.queue_free()
	arena.name = "Arena"
	add_child(arena)
	move_child(arena, 0)


func _configure_arena_runtime(arena: Node2D) -> void:
	var player := get_node_or_null("Entities/Koda") as CharacterBody2D
	var spawner := get_node_or_null("EnemySpawner")
	if is_instance_valid(player):
		player.global_position = Vector2(arena.call("get_player_spawn_position"))
		player.reset_physics_interpolation()
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			var camera_limits := Rect2(arena.call("get_camera_limits"))
			camera.limit_left = roundi(camera_limits.position.x)
			camera.limit_top = roundi(camera_limits.position.y)
			camera.limit_right = roundi(camera_limits.end.x)
			camera.limit_bottom = roundi(camera_limits.end.y)
	if spawner != null and spawner.has_method("configure_arena"):
		spawner.call("configure_arena", arena)


func _show_arena_identification(
	title_text: String,
	subtitle_text: String,
	accent: Color,
	title_color: Color
) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArenaIdentification"
	layer.layer = 109
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "ArenaBanner"
	# The main HUD owns the first 132 screen pixels. Keep this transient banner
	# below it so the run timer and site title remain independently readable.
	panel.position = Vector2(390.0, 148.0)
	panel.size = Vector2(500.0, 76.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.045, 0.03, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.76)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	margin.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(
		"font_color",
		Color(accent.r * 0.78 + 0.18, accent.g * 0.78 + 0.18, accent.b * 0.78 + 0.18)
	)
	subtitle.add_theme_font_size_override("font_size", 11)
	content.add_child(subtitle)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.24)
	tween.tween_interval(2.4)
	tween.tween_property(panel, "modulate:a", 0.0, 0.55)
	tween.tween_callback(layer.queue_free)
