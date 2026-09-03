class_name GameArenaController
extends Node2D


const DUSK_GARDEN_SCENE: PackedScene = preload(
	"res://Scenes/dusk_garden_arena.tscn"
)
const BalanceDebugPanelScript := preload(
	"res://Scripts/debug/balance_debug_panel.gd"
)


func _ready() -> void:
	var ink_system := get_tree().root.get_node_or_null("InkCrimsonVisualSystem")
	if ink_system != null:
		ink_system.set_enabled(true)

	_activate_dusk_garden_arena()
	if OS.is_debug_build():
		add_child(BalanceDebugPanelScript.new())


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


func _exit_tree() -> void:
	var ink_system := get_tree().root.get_node_or_null("InkCrimsonVisualSystem")
	if ink_system != null:
		ink_system.set_enabled(false)
