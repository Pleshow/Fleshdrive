class_name RedGemPickup
extends Area2D


signal collected

@export var attraction_radius: float = 150.0
@export var attraction_speed: float = 360.0
@export var gem_value: int = 1

var player: Node2D
var collected_once: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	prepare_for_reuse()


func prepare_for_reuse() -> void:
	collected_once = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	monitoring = true
	monitorable = true
	show()


func prepare_for_pool() -> void:
	collected_once = true
	player = null
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	if collected_once:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= attraction_radius:
		global_position = global_position.move_toward(
			player.global_position,
			attraction_speed * delta
		)


func _on_body_entered(body: Node) -> void:
	if collected_once or not body.is_in_group("player"):
		return
	collected_once = true
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		meta_progression.add_gems(gem_value)
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			&"card_select",
			-9.0,
			0.08,
			&"SFX"
		)
	collected.emit()
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and has_meta("runtime_pool_key"):
		runtime_pool.call("release", self)
	else:
		queue_free()
