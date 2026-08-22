class_name Spitter
extends CharacterBody2D

const HIT_FLASH_DURATION: float = 0.12


enum State {
	MOVING,
	WINDUP
}


signal died(enemy: Node2D)

@export_category("Movement")
@export var move_speed: float = 78.0
@export var acceleration: float = 520.0
@export var preferred_distance: float = 390.0
@export var distance_tolerance: float = 65.0
@export var separation_radius: float = 92.0

@export_category("Combat")
@export var attack_range: float = 610.0
@export var attack_windup: float = 0.78
@export var attack_cooldown: float = 2.35
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 9.0
@export var projectile_speed: float = 201.6

@export_category("Health")
@export var max_health: float = 45.0

@export_category("Drops")
@export var biomass_pickup_scene: PackedScene
@export var biomass_value: float = 14.0
@export_range(0.0, 1.0) var biomass_drop_chance: float = 0.76
@export var death_vfx_scene: PackedScene
@export var death_vfx_scale: float = 0.85

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var windup_timer: Timer = $WindupTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var aim_line: Line2D = $AimLine
@onready var ground_shadow: Sprite2D = $GroundShadow

var target: Node2D
var state: State = State.MOVING
var current_health: float
var is_dead: bool = false
var strafe_direction: float = 1.0
var external_impulse: Vector2 = Vector2.ZERO
var flight_time: float = 0.0
var flight_phase: float = 0.0
var ground_shadow_base_scale: Vector2
var ground_shadow_base_alpha: float
var hit_flash_remaining: float = 0.0


func _ready() -> void:
	var telegraph_material := CanvasItemMaterial.new()
	telegraph_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	aim_line.material = telegraph_material
	if MinimalistVisualProfile.is_active(get_tree()):
		MinimalistVisualProfile.configure_spitter(sprite)
		MinimalistVisualProfile.configure_shadow(
			ground_shadow,
			Vector2(3.0, 1.45),
			Vector2(0.0, 34.0)
		)
		aim_line.antialiased = false
		aim_line.width = 3.0
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	if balance != null:
		balance.call("apply_enemy_profile", self, &"spitter")
	ground_shadow_base_scale = ground_shadow.scale
	ground_shadow_base_alpha = ground_shadow.modulate.a
	current_health = max_health
	flight_phase = randf_range(0.0, TAU)
	strafe_direction = -1.0 if randf() < 0.5 else 1.0
	find_player()

	windup_timer.timeout.connect(_fire_projectile)
	attack_cooldown_timer.timeout.connect(_on_attack_ready)
	aim_line.z_as_relative = false
	aim_line.z_index = 70
	aim_line.width = maxf(aim_line.width, 3.0)
	aim_line.hide()


func prepare_for_reuse() -> void:
	is_dead = false
	current_health = max_health
	state = State.MOVING
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	velocity = Vector2.ZERO
	flight_time = 0.0
	flight_phase = randf_range(0.0, TAU)
	strafe_direction = -1.0 if randf() < 0.5 else 1.0
	sprite.modulate = Color.WHITE
	ground_shadow.scale = ground_shadow_base_scale
	var shadow_modulate := ground_shadow.modulate
	shadow_modulate.a = ground_shadow_base_alpha
	ground_shadow.modulate = shadow_modulate
	aim_line.hide()
	windup_timer.stop()
	attack_cooldown_timer.stop()
	find_player()


func prepare_for_pool() -> void:
	target = null
	windup_timer.stop()
	attack_cooldown_timer.stop()
	aim_line.hide()
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)
	_update_flight_motion(delta)
	if not is_instance_valid(target):
		find_player()

	if target == null:
		velocity = Vector2.ZERO
		return
	if external_impulse.length_squared() > 4.0:
		_cancel_windup_for_displacement()
		velocity = external_impulse
		move_and_slide()
		external_impulse = EnemySteering.register_displacement_wall_impact(
			self,
			external_impulse
		)
		external_impulse = external_impulse.move_toward(
			Vector2.ZERO,
			940.0 * delta
		)
		return

	update_facing()

	if state == State.WINDUP:
		velocity = Vector2.ZERO
		return

	update_movement(delta)
	move_and_slide()
	try_start_attack()


func _update_flight_motion(delta: float) -> void:
	flight_time += delta
	var hover_wave := sin(flight_time * 5.2 + flight_phase)
	sprite.position.y = -26.0 + hover_wave * 3.0
	var shadow_modulate := ground_shadow.modulate
	shadow_modulate.a = ground_shadow_base_alpha * (1.0 - hover_wave * 0.14)
	ground_shadow.modulate = shadow_modulate
	ground_shadow.scale = ground_shadow_base_scale * Vector2(
		1.0 - hover_wave * 0.04,
		1.0 - hover_wave * 0.02
	)


func apply_external_impulse(impulse: Vector2) -> void:
	external_impulse = (
		external_impulse + impulse
	).limit_length(680.0)
	velocity = external_impulse


func _cancel_windup_for_displacement() -> void:
	if state != State.WINDUP:
		return
	state = State.MOVING
	windup_timer.stop()
	aim_line.hide()
	sprite.play(&"normal")
	attack_cooldown_timer.start(0.55)


func find_player() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D


func update_movement(delta: float) -> void:
	var offset := target.global_position - global_position
	var distance := offset.length()
	var direction_to_target := offset.normalized()
	var movement_direction := Vector2.ZERO

	if distance > preferred_distance + distance_tolerance:
		movement_direction = direction_to_target
	elif distance < preferred_distance - distance_tolerance:
		movement_direction = -direction_to_target
	else:
		movement_direction = Vector2(
			-direction_to_target.y,
			direction_to_target.x
		) * strafe_direction
	var elite_route_bias := float(get_meta("elite_route_bias", 0.0))
	if elite_route_bias > 0.0:
		var flank := Vector2(-direction_to_target.y, direction_to_target.x)
		movement_direction = (
			movement_direction
			+ flank * strafe_direction * elite_route_bias
		).normalized()
	movement_direction = EnemySteering.resolve_direction(
		self,
		movement_direction,
		delta,
		separation_radius,
		1.55,
		0.12
	)

	velocity = velocity.move_toward(
		movement_direction * move_speed,
		acceleration * delta
	)


func try_start_attack() -> void:
	if not attack_cooldown_timer.is_stopped():
		return

	if global_position.distance_to(target.global_position) > attack_range:
		return
	if not EnemySteering.has_clear_path(self, target.global_position):
		strafe_direction *= -1.0
		return

	state = State.WINDUP
	velocity = Vector2.ZERO
	sprite.play(&"windup")
	# The wind-up animation and sound are the readable tell. A full screen-space
	# aim line made ranged packs look like debug geometry.
	aim_line.hide()
	windup_timer.start(attack_windup)
	play_sound(&"spitter_windup", -8.0, 0.045)


func update_aim_line() -> void:
	aim_line.hide()


func _fire_projectile() -> void:
	state = State.MOVING
	sprite.play(&"normal")
	aim_line.hide()
	attack_cooldown_timer.start(attack_cooldown)

	if not is_instance_valid(target) or projectile_scene == null:
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(
		budget.call("allow_enemy_projectile")
	):
		return

	play_sound(&"spitter_fire", -3.0, 0.06)
	var projectile_pool := get_tree().root.get_node_or_null(
		"ProjectilePool"
	)
	if projectile_pool == null:
		return
	var projectile := projectile_pool.call(
		"acquire",
		projectile_scene,
		get_tree().get_first_node_in_group("attack_container")
	) as SpitterProjectile

	if projectile == null:
		return

	var attack_container := get_tree().get_first_node_in_group(
		"attack_container"
	)

	if attack_container == null:
		push_warning("Spitter: Attack container not found.")
		projectile_pool.call("release", projectile)
		return

	var fire_direction := global_position.direction_to(
		target.global_position
	)
	projectile.global_position = get_projectile_muzzle_position(fire_direction)
	projectile.reset_physics_interpolation()
	projectile.configure(
		fire_direction,
		projectile_damage,
		projectile_speed
	)


func get_projectile_muzzle_position(fire_direction: Vector2) -> Vector2:
	# The supplied spider faces southeast. Its head sits slightly forward and
	# above the sprite centre; mirror that socket when the sprite flips.
	var head_offset := Vector2(-8.0 if sprite.flip_h else 8.0, sprite.position.y - 2.0)
	return global_position + head_offset + fire_direction.normalized() * 5.0


func _on_attack_ready() -> void:
	pass


func update_facing() -> void:
	if target == null:
		return

	sprite.flip_h = target.global_position.x < global_position.x


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

	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		die()
	elif event.play_hit_sound:
		play_sound(&"enemy_hit", -12.0, 0.08)
		request_combat_feedback(0.12, 0.22, event.screen_shake)


func get_knockback_resistance() -> float:
	return float(get_meta("knockback_resistance", 0.05))


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
	play_sound(&"enemy_death", -7.0, 0.08)
	died.emit(self)
	request_combat_feedback(0.48, 0.65)
	EnemyDeathAnimator.play(self, sprite, death_vfx_scale)
	_try_drop_biomass()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
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
		return

	var pickup_container := get_tree().get_first_node_in_group(
		"pickup_container"
	)

	if pickup_container == null:
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
