class_name RedGemPickup
extends Area2D


signal collected

@export var attraction_radius: float = 150.0
@export var attraction_speed: float = 360.0
@export var gem_value: int = 1

var player: Node2D
var collected_once: bool = false
var coin_visual: AnimatedSprite2D


func _ready() -> void:
	var legacy_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if legacy_sprite != null:
		legacy_sprite.hide()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	prepare_for_reuse()


func prepare_for_reuse() -> void:
	_stop_coin_visual()
	collected_once = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	monitoring = true
	monitorable = true
	show()


func activate_at(world_position: Vector2) -> void:
	global_position = world_position
	_start_spin_visual()


func prepare_for_pool() -> void:
	collected_once = true
	player = null
	monitoring = false
	monitorable = false
	_stop_coin_visual()


func _exit_tree() -> void:
	_stop_coin_visual()


func _physics_process(delta: float) -> void:
	if collected_once:
		return
	# A transient VFX spike can briefly exhaust the shared pool on the exact
	# drop frame. Keep retrying so a permanent collectible never stays hidden.
	if not is_instance_valid(coin_visual):
		_start_spin_visual()
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= attraction_radius:
		if distance <= 28.0:
			_on_body_entered(player)
			return
		global_position = global_position.move_toward(
			player.global_position,
			attraction_speed * delta
		)


func _on_body_entered(body: Node) -> void:
	if collected_once or not body.is_in_group("player"):
		return
	collected_once = true
	# body_entered is emitted while PhysicsServer2D is flushing its contact
	# query. Area2D rejects immediate monitoring changes in that window, so
	# defer both properties to the safe side of the physics frame.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var meta_progression := get_tree().root.get_node_or_null("MetaProgression")
	if meta_progression != null:
		meta_progression.add_gems(gem_value)
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call("play", &"card_select", -9.0, 0.08, &"SFX")
	collected.emit()
	_play_collect_visual()


func _start_spin_visual() -> void:
	_stop_coin_visual()
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return
	coin_visual = visual_effects.call(
		"play_attached",
		&"blood_memory_coin_spin",
		self,
		Vector2.ZERO,
		1.35,
		0.0
	) as AnimatedSprite2D
	if coin_visual != null:
		coin_visual.name = "BloodMemoryGoldCoin"
		coin_visual.z_index = 32


func _play_collect_visual() -> void:
	_stop_coin_visual()
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		coin_visual = visual_effects.call(
			"play",
			&"blood_memory_coin_collect",
			global_position,
			1.35,
			0.0
		) as AnimatedSprite2D
		if coin_visual != null:
			coin_visual.name = "BloodMemoryGoldCoinPickup"
			coin_visual.z_index = 32
			coin_visual.animation_finished.connect(
				_release_after_collection,
				CONNECT_ONE_SHOT
			)
			return
	_release_after_collection()


func _stop_coin_visual() -> void:
	if not is_instance_valid(coin_visual):
		coin_visual = null
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("stop_effect", coin_visual)
	else:
		coin_visual.queue_free()
	coin_visual = null


func _release_after_collection() -> void:
	coin_visual = null
	if not is_instance_valid(self):
		return
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and has_meta("runtime_pool_key"):
		runtime_pool.call("release", self)
	else:
		queue_free()
