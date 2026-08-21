class_name BiomassPickup
extends Area2D


@export var biomass_value: float = 10.0
@export var pickup_delay: float = 0.15

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_be_collected: bool = false
var collected: bool = false
var original_scale: Vector2
var player: Node2D
var reuse_epoch: int = 0
var spawn_tween: Tween


func _ready() -> void:
	add_to_group("biomass_pickups")
	if MinimalistVisualProfile.is_active(get_tree()):
		MinimalistVisualProfile.configure_biomass(sprite)
	if not body_entered.is_connected(on_body_entered):
		body_entered.connect(on_body_entered)
	original_scale = sprite.scale
	prepare_for_reuse()


func prepare_for_reuse() -> void:
	reuse_epoch += 1
	var current_epoch := reuse_epoch
	if spawn_tween != null and spawn_tween.is_valid():
		spawn_tween.kill()
	collected = false
	can_be_collected = false
	monitoring = true
	monitorable = true
	player = get_tree().get_first_node_in_group("player") as Node2D
	if original_scale == Vector2.ZERO:
		original_scale = sprite.scale
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ZERO

	spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(
	sprite,
	"scale",
	original_scale,
	0.18
	).set_trans(Tween.TRANS_BACK)

	spawn_tween.tween_property(
		sprite,
		"rotation",
		randf_range(-0.25, 0.25),
		0.18
	)

	await get_tree().create_timer(pickup_delay).timeout
	if is_inside_tree() and current_epoch == reuse_epoch and not collected:
		can_be_collected = true


func configure_spawn(value: float, world_position: Vector2) -> void:
	biomass_value = value
	global_position = world_position
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_biomass_spawned", biomass_value)


func prepare_for_pool() -> void:
	reuse_epoch += 1
	if spawn_tween != null and spawn_tween.is_valid():
		spawn_tween.kill()
	can_be_collected = false
	collected = true
	player = null
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	if collected or not can_be_collected:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var pickup_radius := float(player.get("biomass_pickup_radius"))
	var distance := global_position.distance_to(player.global_position)
	if distance > pickup_radius:
		return
	# With a large simultaneous drop several pickups can reach Koda in the same
	# physics frame without producing a fresh body_entered edge. Previously the
	# distance <= 1 early return then left those pickups pinned to Koda forever.
	if distance <= 30.0:
		on_body_entered(player)
		return

	var attraction_speed := lerpf(260.0, 720.0, 1.0 - distance / pickup_radius)
	if player.has_method("get_upgrade_level") and int(player.call("get_upgrade_level", &"hungry_magnet")) > 0:
		attraction_speed *= lerpf(1.25, 2.15, 1.0 - distance / pickup_radius)
	global_position = global_position.move_toward(
		player.global_position,
		attraction_speed * delta
	)


func on_body_entered(body: Node2D) -> void:
	if collected or not can_be_collected:
		return

	if not body.is_in_group("player"):
		return

	if not body.has_method("add_biomass"):
		return

	collected = true
	body.add_biomass(biomass_value)
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call(
			"play", &"biomass_collect",
			body.global_position + Vector2(0.0, -5.0), 0.30
		)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_biomass_collected", biomass_value)
	play_sound(&"biomass_pickup", -19.0, 0.08)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		sprite,
		"scale",
		Vector2.ZERO,
		0.12
	)

	tween.tween_property(
		sprite,
		"modulate:a",
		0.0,
		0.12
	)

	await tween.finished
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and has_meta("runtime_pool_key"):
		runtime_pool.call("release", self)
	else:
		queue_free()


func play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float
) -> void:
	if not is_inside_tree():
		return
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			sound_id,
			volume_db,
			pitch_variation,
			&"SFX"
		)
