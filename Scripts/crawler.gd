class_name Crawler
extends CharacterBody2D

const HIT_FLASH_DURATION: float = 0.12

@onready var attack_timer: Timer = $AttackTimer
@export_category("Movement")
@export var move_speed: float = 88.0
@export var acceleration: float = 700.0
@export_category("Drops")
@export var biomass_pickup_scene: PackedScene
@export var biomass_value: float = 10.0
@export_range(0.0, 1.0) var biomass_drop_chance: float = 0.68
@export var death_vfx_scene: PackedScene
@export var death_vfx_scale: float = 0.65
@export_category("Horde Movement")
@export var separation_radius: float = 70.0
@export var separation_weight: float = 1.35
@export var encirclement_weight: float = 0.34

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


var target: Node2D
@export_category("Combat")
@export var contact_damage: float = 10.0
@export var contact_radius: float = 36.0
@export var attack_interval: float = 0.5

signal died(enemy: Node2D)

@export_category("Health")
@export var max_health: float = 30.0


var current_health: float
var is_dead: bool = false
var external_impulse: Vector2 = Vector2.ZERO
var hit_flash_remaining: float = 0.0

func _ready() -> void:
	if MinimalistVisualProfile.is_active(get_tree()):
		MinimalistVisualProfile.configure_crawler(sprite)
		MinimalistVisualProfile.configure_shadow(
			get_node_or_null("GroundShadow") as Sprite2D,
			Vector2(2.3, 1.2),
			Vector2(0.0, 9.0)
		)
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	if balance != null:
		balance.call("apply_enemy_profile", self, &"crawler")
	current_health = max_health
	find_player()
	sprite.play(&"walk")


func prepare_for_reuse() -> void:
	is_dead = false
	current_health = max_health
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	find_player()
	sprite.play(&"walk")


func prepare_for_pool() -> void:
	target = null
	attack_timer.stop()
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)
	if not is_instance_valid(target):
		find_player()

	if target == null:
		velocity = Vector2.ZERO
		return
	if external_impulse.length_squared() > 4.0:
		velocity = external_impulse
		move_and_slide()
		external_impulse = EnemySteering.register_displacement_wall_impact(
			self,
			external_impulse
		)
		external_impulse = external_impulse.move_toward(
			Vector2.ZERO,
			980.0 * delta
		)
		return

	move_toward_player(delta)
	move_and_slide()
	check_contact_damage()
	update_facing()


func apply_external_impulse(impulse: Vector2) -> void:
	external_impulse = (
		external_impulse + impulse
	).limit_length(720.0)
	velocity = external_impulse


func find_player() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D

func move_toward_player(delta: float) -> void:
	var chase_direction := global_position.direction_to(
		target.global_position
	)
	var distance := global_position.distance_to(target.global_position)
	var formation_direction := _get_circle_formation_direction(distance)
	if not formation_direction.is_zero_approx():
		chase_direction = formation_direction
	var active_flank_weight := (
		encirclement_weight
		* clampf(inverse_lerp(260.0, 95.0, distance), 0.0, 1.0)
	)
	active_flank_weight += float(get_meta("elite_route_bias", 0.0))
	var combined_direction := EnemySteering.resolve_direction(
		self,
		chase_direction,
		delta,
		separation_radius,
		separation_weight,
		active_flank_weight
	)

	var target_velocity := combined_direction * move_speed

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)


func _get_circle_formation_direction(distance: float) -> Vector2:
	if distance < 86.0 or distance > 430.0:
		return Vector2.ZERO
	var serial := int(get_meta("formation_serial", 0))
	var seconds := Time.get_ticks_msec() * 0.001
	# Groups share a repeating assault window. Stable per-crawler slots form a
	# real ring instead of every body merely adding the same sideways bias.
	var cycle := fmod(seconds + float(serial % 7) * 1.3, 11.5)
	if cycle > 3.6:
		return Vector2.ZERO
	var slot_count := 10
	var slot := posmod(get_instance_id() + serial * 3, slot_count)
	var orbit_sign := -1.0 if serial % 2 == 0 else 1.0
	var angle := (
		TAU * float(slot) / float(slot_count)
		+ seconds * 0.22 * orbit_sign
	)
	var ring_radius := 142.0 + 12.0 * float(slot % 3)
	var slot_position := target.global_position + Vector2.from_angle(angle) * ring_radius
	return global_position.direction_to(slot_position)


func update_facing() -> void:
	if abs(velocity.x) < 1.0:
		return

	sprite.flip_h = velocity.x < 0.0

func check_contact_damage() -> void:
	if (
		not attack_timer.is_stopped()
		or not is_instance_valid(target)
		or global_position.distance_squared_to(target.global_position)
		> contact_radius * contact_radius
	):
		return

	if target.is_in_group("player") and target.has_method("take_damage"):
		target.take_damage(contact_damage, self, &"crawler")
		attack_timer.start(attack_interval)
		_play_attack_animation()


func _play_attack_animation() -> void:
	sprite.play(&"attack")
	await sprite.animation_finished
	if not is_dead:
		sprite.play(&"walk")

func take_damage(
	amount: float,
	play_hit_sound: bool = true
) -> void:
	var event := DamageEvent.create(self, amount)
	event.play_hit_sound = play_hit_sound
	event.show_damage_number = false
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.call("apply_damage", event)


func receive_damage_event(
	event: DamageEvent,
	amount: float
) -> void:
	if is_dead or amount <= 0.0:
		return

	current_health = max(current_health - amount, 0.0)

	play_hit_feedback()

	if current_health <= 0.0:
		die()
	elif event.play_hit_sound:
		play_sound(&"enemy_hit", -13.0, 0.09)
		request_combat_feedback(0.10, 0.18, event.screen_shake)


func get_knockback_resistance() -> float:
	return float(get_meta("knockback_resistance", 0.0))


func play_hit_feedback() -> void:
	hit_flash_remaining = HIT_FLASH_DURATION
	sprite.modulate = Color(0.3, 0.8, 1.0)


func _update_hit_flash(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining = maxf(hit_flash_remaining - delta, 0.0)
	var progress := 1.0 - hit_flash_remaining / HIT_FLASH_DURATION
	sprite.modulate = Color(0.3, 0.8, 1.0).lerp(Color.WHITE, progress)


func die() -> void:
	if is_dead:
		return

	is_dead = true

	velocity = Vector2.ZERO
	external_impulse = Vector2.ZERO
	attack_timer.stop()

	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	play_sound(&"enemy_death", -8.0, 0.09)
	died.emit(self)
	request_combat_feedback(0.38, 0.55)

	spawn_death_vfx()
	_try_drop_biomass()
	
	sprite.modulate = Color.WHITE
	sprite.play(&"death")

	await sprite.animation_finished

	# Csak az animáció után tűnjön el
	_return_to_pool_or_free()


func _return_to_pool_or_free() -> void:
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and has_meta("runtime_pool_key") and not bool(get_meta("is_elite", false)):
		runtime_pool.call("release", self)
	else:
		queue_free()

func request_combat_feedback(
	shake_amount: float,
	hit_stop_strength: float,
	screen_shake: bool = true
) -> void:
	var feedback := get_tree().get_first_node_in_group("combat_feedback")
	if feedback == null:
		return
	if screen_shake and feedback.has_method("play_hit"):
		feedback.play_hit(shake_amount, hit_stop_strength)
	elif feedback.has_method("hit_stop"):
		feedback.hit_stop(hit_stop_strength)

func spawn_death_vfx() -> void:
	if death_vfx_scene == null:
		return
	var effects_container := get_tree().get_first_node_in_group("effects_container")
	if effects_container == null:
		return
	var effect := death_vfx_scene.instantiate() as Node2D
	if effect == null:
		return
	effects_container.add_child(effect)
	effect.global_position = global_position
	effect.scale *= death_vfx_scale
	effect.modulate = EnemySteering.get_death_tint(self)

func drop_biomass() -> void:
	if biomass_pickup_scene == null:
		push_warning("Crawler: Biomass pickup scene is not assigned.")
		return

	var pickup_container := get_tree().get_first_node_in_group(
		"pickup_container"
	)

	if pickup_container == null:
		push_warning("Crawler: Pickup container not found.")
		return

	_spawn_biomass_deferred.call_deferred(pickup_container, global_position)


func _try_drop_biomass() -> void:
	var chance := biomass_drop_chance
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		chance += float(player.get("biomass_drop_chance_bonus"))
	if randf() <= clampf(chance, 0.0, 1.0):
		drop_biomass()


func _spawn_biomass_deferred(container: Node, world_position: Vector2) -> void:
	if not is_instance_valid(container):
		return
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	var pickup := (
		runtime_pool.call("acquire", biomass_pickup_scene, container) as BiomassPickup
		if runtime_pool != null
		else biomass_pickup_scene.instantiate() as BiomassPickup
	)
	if pickup == null:
		return
	if pickup.get_parent() == null:
		container.add_child(pickup)
	pickup.configure_spawn(biomass_value, world_position)


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
