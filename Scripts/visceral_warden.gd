class_name VisceralWarden
extends CharacterBody2D


const BOSS_TEXTURE := preload(
	"res://Assets/enemies/boss/visceral_warden_sheet.png"
)

enum State {
	INTRO,
	HUNT,
	WINDUP_VOLLEY,
	WINDUP_SLAM,
	WINDUP_CHARGE,
	CHARGE,
	RECOVERY,
	DEAD,
}


signal died(enemy: Node2D)
signal health_changed(current_health: float, max_health: float)
signal phase_changed(phase: int)
signal attack_started(attack_id: StringName)

@export_category("Health")
@export var max_health: float = 1500.0
@export_range(0.1, 0.9) var phase_two_threshold: float = 0.5

@export_category("Movement")
@export var move_speed: float = 92.0
@export var phase_two_move_speed: float = 122.0
@export var acceleration: float = 520.0

@export_category("Attack Rhythm")
@export var intro_duration: float = 1.15
@export var attack_cooldown: float = 1.65
@export var phase_two_attack_cooldown: float = 1.05
@export var recovery_duration: float = 0.55

@export_category("Projectile Fan")
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 14.0
@export var projectile_speed: float = 390.0
@export var volley_windup: float = 0.8
@export var volley_spread_degrees: float = 58.0
@export var volley_projectile_count: int = 5
@export var phase_two_projectile_count: int = 7

@export_category("Ground Slam")
@export var slam_windup: float = 1.05
@export var slam_radius: float = 245.0
@export var slam_damage: float = 28.0

@export_category("Charge")
@export var charge_windup: float = 0.82
@export var charge_speed: float = 720.0
@export var phase_two_charge_speed: float = 860.0
@export var charge_duration: float = 0.72
@export var charge_damage: float = 32.0
@export var charge_hit_radius: float = 88.0
@export var minimum_charge_distance: float = 170.0
@export var contact_damage: float = 18.0
@export var contact_radius: float = 78.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var state_timer: Timer = $StateTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var contact_damage_timer: Timer = $ContactDamageTimer
@onready var aim_line: Line2D = $AimLine
@onready var charge_line: Line2D = $ChargeLine
@onready var volley_area: Polygon2D = $VolleyArea
@onready var charge_area: Polygon2D = $ChargeArea
@onready var slam_telegraph: Line2D = $SlamTelegraph
@onready var slam_fill: Polygon2D = $SlamFill
var target: Node2D
var state: State = State.INTRO
var phase: int = 1
var current_health: float
var is_dead: bool = false
var charge_direction: Vector2 = Vector2.RIGHT
var attack_sequence_index: int = 0
var base_sprite_scale: Vector2
var _breathing_time: float = 0.0
var pending_combo_attack: StringName = &""
var electric_burst_window: float = 0.0
var electric_burst_stacks: int = 0
var hunt_stuck_time: float = 0.0
var last_hunt_position: Vector2


func _ready() -> void:
	var telegraph_material := CanvasItemMaterial.new()
	telegraph_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for telegraph_visual in [
		aim_line, charge_line, volley_area, charge_area,
		slam_telegraph, slam_fill,
	]:
		telegraph_visual.material = telegraph_material
	_configure_sprite_animations()
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	if balance != null:
		balance.call(
			"apply_enemy_profile",
			self,
			&"visceral_warden"
		)
	current_health = max_health
	last_hunt_position = global_position
	base_sprite_scale = sprite.scale
	find_player()
	_build_slam_telegraph()

	state_timer.timeout.connect(_on_state_timer_timeout)
	for telegraph in [aim_line, charge_line, slam_telegraph]:
		telegraph.z_as_relative = false
		telegraph.z_index = 76
		telegraph.width = maxf(telegraph.width, 4.0)
	slam_fill.z_as_relative = false
	slam_fill.z_index = 74
	aim_line.hide()
	charge_line.hide()
	volley_area.hide()
	charge_area.hide()
	slam_telegraph.hide()
	slam_fill.hide()

	sprite.scale = base_sprite_scale * 0.45
	sprite.modulate.a = 0.0
	var intro_tween := create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		sprite,
		"scale",
		base_sprite_scale,
		intro_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(
		sprite,
		"modulate:a",
		1.0,
		intro_duration * 0.65
	)
	state_timer.start(intro_duration)
	health_changed.emit(current_health, max_health)
	play_sound(&"rush_warning", -2.0, 0.02)


func _process(delta: float) -> void:
	electric_burst_window = maxf(electric_burst_window - delta, 0.0)
	if is_zero_approx(electric_burst_window):
		electric_burst_stacks = 0
	if state != State.HUNT:
		return

	_breathing_time += delta
	var breathing_scale := 1.0 + sin(_breathing_time * 3.2) * 0.018
	sprite.scale = base_sprite_scale * breathing_scale


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(target):
		find_player()

	if target == null:
		velocity = Vector2.ZERO
		return

	match state:
		State.INTRO:
			velocity = Vector2.ZERO
		State.HUNT:
			_update_hunt(delta)
		State.WINDUP_VOLLEY:
			velocity = Vector2.ZERO
			_update_volley_area()
		State.WINDUP_SLAM:
			velocity = Vector2.ZERO
		State.WINDUP_CHARGE:
			velocity = Vector2.ZERO
			_update_charge_area()
		State.CHARGE:
			_update_charge()
		State.RECOVERY:
			velocity = Vector2.ZERO
		State.DEAD:
			velocity = Vector2.ZERO


func find_player() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D


func _update_hunt(delta: float) -> void:
	var direction_to_target := global_position.direction_to(
		target.global_position
	)
	direction_to_target = EnemySteering.resolve_direction(
		self,
		direction_to_target,
		delta,
		118.0,
		1.1,
		0.16,
		190.0
	)
	var active_move_speed := (
		phase_two_move_speed if phase == 2 else move_speed
	)
	velocity = velocity.move_toward(
		direction_to_target * active_move_speed,
		acceleration * delta
	)
	move_and_slide()
	var moved_distance := global_position.distance_to(last_hunt_position)
	if moved_distance < 1.2 and velocity.length_squared() > 900.0:
		hunt_stuck_time += delta
	else:
		hunt_stuck_time = maxf(hunt_stuck_time - delta * 2.0, 0.0)
	if hunt_stuck_time >= 0.42:
		# Break repeated corner contacts with a deterministic side-step instead
		# of allowing the large boss body to grind against the same prop.
		var side := direction_to_target.orthogonal()
		if sin(Time.get_ticks_msec() * 0.003) < 0.0:
			side = -side
		velocity = side * active_move_speed * 1.25
		move_and_slide()
		hunt_stuck_time = 0.0
	last_hunt_position = global_position
	_update_facing(direction_to_target)
	_check_contact_damage()

	if attack_cooldown_timer.is_stopped():
		_choose_attack()


func _choose_attack() -> void:
	if not is_instance_valid(target):
		return

	var distance := global_position.distance_to(target.global_position)
	var attack_slot := attack_sequence_index % 3
	attack_sequence_index += 1
	pending_combo_attack = &""
	if phase == 2 and attack_sequence_index % 3 == 1:
		match attack_slot:
			0:
				pending_combo_attack = (
					&"slam"
					if distance <= slam_radius * 1.5
					else &"charge"
				)
			1:
				pending_combo_attack = &"volley"
			2:
				pending_combo_attack = &"slam"

	match attack_slot:
		0:
			_start_projectile_volley()
		1:
			if distance <= slam_radius * 1.35:
				_start_ground_slam()
			else:
				_start_charge_windup()
		2:
			if distance >= minimum_charge_distance:
				_start_charge_windup()
			else:
				_start_projectile_volley()


func force_attack(attack_id: StringName) -> void:
	if is_dead:
		return

	state_timer.stop()
	attack_cooldown_timer.stop()

	match attack_id:
		&"volley":
			_start_projectile_volley()
		&"slam":
			_start_ground_slam()
		&"charge":
			_start_charge_windup()


func _start_projectile_volley() -> void:
	if not is_instance_valid(target):
		return

	state = State.WINDUP_VOLLEY
	velocity = Vector2.ZERO
	sprite.scale = base_sprite_scale * 1.04
	sprite.play(&"cast")
	# Kept logically visible for state/debug tooling, but rendered transparent;
	# the readable ground wedge is the actual player-facing telegraph.
	aim_line.show()
	volley_area.show()
	_update_volley_area()
	state_timer.start(volley_windup * (0.82 if phase == 2 else 1.0))
	attack_started.emit(&"volley")
	play_sound(&"spitter_windup", -2.0, 0.03)


func _update_volley_area() -> void:
	if not is_instance_valid(target):
		volley_area.hide()
		return
	var local_direction := to_local(target.global_position).normalized()
	var length := minf(
		global_position.distance_to(target.global_position) + 110.0,
		720.0
	)
	var half_angle := deg_to_rad(volley_spread_degrees * 0.5)
	volley_area.polygon = PackedVector2Array([
		local_direction * 42.0,
		local_direction.rotated(-half_angle) * length,
		local_direction.rotated(half_angle) * length,
	])


func _fire_projectile_volley() -> void:
	aim_line.hide()
	volley_area.hide()
	if projectile_scene == null or not is_instance_valid(target):
		_start_recovery()
		return

	var attack_container := get_tree().get_first_node_in_group(
		"attack_container"
	)
	if attack_container == null:
		_start_recovery()
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(
		budget.call("allow_enemy_projectile")
	):
		_start_recovery()
		return

	var projectile_count := (
		phase_two_projectile_count
		if phase == 2
		else volley_projectile_count
	)
	var center_direction := global_position.direction_to(
		target.global_position
	)
	var spread_radians := deg_to_rad(volley_spread_degrees)
	var projectile_pool := get_tree().root.get_node_or_null(
		"ProjectilePool"
	)
	if projectile_pool == null:
		_start_recovery()
		return

	for projectile_index in range(projectile_count):
		var interpolation := (
			0.5
			if projectile_count <= 1
			else float(projectile_index) / float(projectile_count - 1)
		)
		var angle_offset := lerpf(
			-spread_radians * 0.5,
			spread_radians * 0.5,
			interpolation
		)
		var projectile_direction := center_direction.rotated(angle_offset)
		var projectile := projectile_pool.call(
			"acquire",
			projectile_scene,
			attack_container
		) as BossProjectile
		if projectile == null:
			continue

		projectile.global_position = (
			global_position + projectile_direction * 72.0
		)
		var is_center_projectile := (
			phase == 2
			and projectile_index == int(projectile_count / 2.0)
		)
		projectile.configure(
			projectile_direction,
			projectile_damage * (1.35 if is_center_projectile else 1.0),
			projectile_speed * (1.12 if phase == 2 else 1.0),
			is_center_projectile
		)

	play_sound(&"spitter_fire", 1.0, 0.035)
	play_world_vfx(&"boss_phase", global_position, 0.42)
	_start_recovery()


func _start_ground_slam() -> void:
	state = State.WINDUP_SLAM
	velocity = Vector2.ZERO
	sprite.scale = base_sprite_scale * 1.08
	sprite.play(&"cast")
	slam_telegraph.show()
	slam_fill.show()
	slam_fill.scale = Vector2.ONE * 0.08
	slam_fill.modulate.a = 0.12

	var telegraph_tween := create_tween()
	telegraph_tween.set_parallel(true)
	telegraph_tween.tween_property(
		slam_fill,
		"scale",
		Vector2.ONE,
		slam_windup * (0.78 if phase == 2 else 1.0)
	)
	telegraph_tween.tween_property(
		slam_fill,
		"modulate:a",
		0.34,
		slam_windup * (0.78 if phase == 2 else 1.0)
	)

	state_timer.start(slam_windup * (0.78 if phase == 2 else 1.0))
	attack_started.emit(&"slam")
	play_sound(&"charger_windup", -1.0, 0.025)


func _perform_ground_slam() -> void:
	slam_telegraph.hide()
	slam_fill.hide()

	if (
		is_instance_valid(target)
		and global_position.distance_to(target.global_position)
		<= slam_radius
		and target.has_method("take_damage")
	):
		target.take_damage(
			slam_damage,
			self,
			&"visceral_warden_slam"
		)

	_play_slam_burst()
	play_sound(&"charger_impact", 0.0, 0.035)
	request_combat_feedback(0.9, 0.75)

	if phase == 2:
		_fire_radial_projectiles(8)

	_start_recovery()


func _fire_radial_projectiles(projectile_count: int) -> void:
	if projectile_scene == null:
		return

	var attack_container := get_tree().get_first_node_in_group(
		"attack_container"
	)
	if attack_container == null:
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(
		budget.call("allow_enemy_projectile")
	):
		return
	var projectile_pool := get_tree().root.get_node_or_null(
		"ProjectilePool"
	)
	if projectile_pool == null:
		return

	for projectile_index in range(projectile_count):
		var direction := Vector2.RIGHT.rotated(
			TAU * float(projectile_index) / float(projectile_count)
		)
		var projectile := projectile_pool.call(
			"acquire",
			projectile_scene,
			attack_container
		) as BossProjectile
		if projectile == null:
			continue

		projectile.global_position = global_position + direction * 68.0
		projectile.configure(
			direction,
			projectile_damage * 0.8,
			projectile_speed * 0.86
		)


func _start_charge_windup() -> void:
	if not is_instance_valid(target):
		return

	state = State.WINDUP_CHARGE
	velocity = Vector2.ZERO
	charge_direction = global_position.direction_to(target.global_position)
	_update_facing(charge_direction)
	sprite.scale = base_sprite_scale * 1.03
	sprite.play(&"charge")
	charge_line.show()
	charge_area.show()
	_update_charge_area()
	state_timer.start(charge_windup * (0.78 if phase == 2 else 1.0))
	attack_started.emit(&"charge")
	play_sound(&"charger_windup", 0.0, 0.025)


func _update_charge_area() -> void:
	var active_charge_speed := (
		phase_two_charge_speed if phase == 2 else charge_speed
	)
	var length := active_charge_speed * charge_duration
	var tangent := Vector2(-charge_direction.y, charge_direction.x)
	var half_width := 62.0
	charge_area.polygon = PackedVector2Array([
		charge_direction * 34.0 - tangent * half_width,
		charge_direction * length - tangent * half_width,
		charge_direction * length + tangent * half_width,
		charge_direction * 34.0 + tangent * half_width,
	])


func _begin_charge() -> void:
	state = State.CHARGE
	charge_line.hide()
	charge_area.hide()
	collision_mask = 1
	state_timer.start(charge_duration)
	play_sound(&"charger_charge", -1.0, 0.03)


func _update_charge() -> void:
	var active_charge_speed := (
		phase_two_charge_speed if phase == 2 else charge_speed
	)
	velocity = charge_direction * active_charge_speed
	move_and_slide()

	if (
		is_instance_valid(target)
		and global_position.distance_squared_to(target.global_position)
		<= charge_hit_radius * charge_hit_radius
	):
		if target.has_method("take_damage"):
			target.take_damage(
				charge_damage,
				self,
				&"visceral_warden"
			)
		_finish_charge()
		return

	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision != null:
			# Leave a small gap after impact so the following hunt state does not
			# begin while the Warden is still embedded in the obstacle margin.
			global_position += collision.get_normal() * 18.0
		_finish_charge()
		return


func _finish_charge() -> void:
	if state != State.CHARGE:
		return

	collision_mask = 1
	play_sound(&"charger_impact", -1.0, 0.035)
	play_world_vfx(&"boss_charge_impact", global_position, 1.0)
	request_combat_feedback(0.72, 0.65)
	_start_recovery()


func _start_recovery() -> void:
	state = State.RECOVERY
	velocity = Vector2.ZERO
	aim_line.hide()
	charge_line.hide()
	volley_area.hide()
	charge_area.hide()
	slam_telegraph.hide()
	slam_fill.hide()
	sprite.scale = base_sprite_scale
	sprite.play(&"enraged" if phase == 2 else &"idle")
	state_timer.start(
		0.24
		if not pending_combo_attack.is_empty()
		else recovery_duration * (0.75 if phase == 2 else 1.0)
	)


func interrupt_active_attack(affinity: StringName, force: float = 1.0) -> bool:
	if is_dead or state not in [
		State.WINDUP_VOLLEY,
		State.WINDUP_SLAM,
		State.WINDUP_CHARGE,
	]:
		return false
	# Each Fleshdrive can create an opening, but telekinetic force is the most
	# reliable while fire needs a stronger committed hit.
	var threshold := 0.65
	if affinity == FleshdriveCatalog.FIRE:
		threshold = 0.9
	elif affinity == FleshdriveCatalog.TELEKINETIC:
		threshold = 0.45
	if force < threshold:
		return false
	state_timer.stop()
	pending_combo_attack = &""
	play_world_vfx(&"boss_charge_impact", global_position, 0.75)
	request_combat_feedback(0.48, 0.52)
	_start_recovery()
	return true


func _finish_recovery() -> void:
	if not pending_combo_attack.is_empty():
		var combo_attack := pending_combo_attack
		pending_combo_attack = &""
		force_attack(combo_attack)
		return
	state = State.HUNT
	sprite.play(&"enraged" if phase == 2 else &"idle")
	var next_cooldown := (
		phase_two_attack_cooldown if phase == 2 else attack_cooldown
	)
	attack_cooldown_timer.start(next_cooldown)


func _on_state_timer_timeout() -> void:
	match state:
		State.INTRO:
			state = State.HUNT
			sprite.play(&"idle")
			attack_cooldown_timer.start(0.75)
		State.WINDUP_VOLLEY:
			_fire_projectile_volley()
		State.WINDUP_SLAM:
			_perform_ground_slam()
		State.WINDUP_CHARGE:
			_begin_charge()
		State.CHARGE:
			_finish_charge()
		State.RECOVERY:
			_finish_recovery()


func _check_contact_damage() -> void:
	if (
		not contact_damage_timer.is_stopped()
		or not is_instance_valid(target)
		or global_position.distance_squared_to(target.global_position)
		> contact_radius * contact_radius
	):
		return

	if target.is_in_group("player") and target.has_method("take_damage"):
		target.take_damage(
			contact_damage,
			self,
			&"visceral_warden"
		)
		contact_damage_timer.start()


func _update_facing(direction_to_face: Vector2) -> void:
	if absf(direction_to_face.x) < 0.01:
		return
	sprite.flip_h = direction_to_face.x < 0.0


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


func modify_incoming_damage_event(
	event: DamageEvent,
	amount: float
) -> float:
	if event.affinity == FleshdriveCatalog.FIRE and (
		event.damage_type == DamageEvent.DamageType.DAMAGE_OVER_TIME
	):
		return amount * 1.12
	if (
		event.affinity == FleshdriveCatalog.ELECTRIC
		and event.damage_type != DamageEvent.DamageType.DAMAGE_OVER_TIME
	):
		electric_burst_stacks = mini(electric_burst_stacks + 1, 3)
		electric_burst_window = 0.72
		return amount * (
			1.0 + float(electric_burst_stacks - 1) * 0.04
		)
	return amount


func receive_damage_event(
	event: DamageEvent,
	amount: float
) -> void:
	if is_dead or state == State.INTRO or amount <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	_play_hit_feedback()

	if (
		phase == 1
		and current_health <= max_health * phase_two_threshold
		and current_health > 0.0
	):
		_enter_phase_two()

	if current_health <= 0.0:
		die()
	elif event.play_hit_sound:
		play_sound(&"enemy_hit", -8.0, 0.055)
		request_combat_feedback(0.22, 0.28, event.screen_shake)


func get_knockback_resistance() -> float:
	return 1.0


func _enter_phase_two() -> void:
	phase = 2
	# Enrage is a real second health phase, not only a speed modifier. Preserve
	# damage already dealt while adding a substantial fresh health reserve.
	var old_max_health := max_health
	max_health *= 1.65
	current_health += max_health - old_max_health
	health_changed.emit(current_health, max_health)
	var database := get_tree().root.get_node_or_null("BalanceDatabase")
	if database != null:
		var phase_profile := Dictionary(database.call(
			"get_boss_phase_profile",
			phase
		))
		phase_two_move_speed = float(phase_profile.get(
			"move_speed",
			phase_two_move_speed
		))
		phase_two_attack_cooldown = float(phase_profile.get(
			"attack_cooldown",
			phase_two_attack_cooldown
		))
		phase_two_projectile_count = int(phase_profile.get(
			"projectile_count",
			phase_two_projectile_count
		))
	phase_changed.emit(phase)
	sprite.play(&"enraged")
	sprite.modulate = Color(0.72, 1.0, 1.0)
	var phase_tween := create_tween()
	phase_tween.tween_property(sprite, "modulate", Color.WHITE, 0.35)
	play_sound(&"rush_warning", 1.0, 0.015)
	play_world_vfx(&"boss_phase", global_position, 1.0)
	request_combat_feedback(1.0, 0.8)
	attack_cooldown_timer.stop()
	if state == State.HUNT:
		attack_cooldown_timer.start(0.35)


func _play_hit_feedback() -> void:
	sprite.modulate = Color(0.25, 0.85, 1.0)
	var hit_tween := create_tween()
	hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	state_timer.stop()
	attack_cooldown_timer.stop()
	aim_line.hide()
	charge_line.hide()
	volley_area.hide()
	charge_area.hide()
	slam_telegraph.hide()
	slam_fill.hide()
	EnemyDeathAnimator.play(self, sprite, 1.8)
	_play_death_burst()
	play_sound(&"enemy_death", 1.0, 0.025)
	request_combat_feedback(1.4, 1.0)
	died.emit(self)

	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(
		sprite,
		"scale",
		base_sprite_scale * 1.28,
		0.55
	)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.65)
	await death_tween.finished
	queue_free()


func _build_slam_telegraph() -> void:
	var circle_points := PackedVector2Array()
	for point_index in range(65):
		var angle := TAU * float(point_index) / 64.0
		circle_points.append(
			Vector2.RIGHT.rotated(angle) * slam_radius
		)
	slam_telegraph.points = circle_points
	slam_fill.polygon = circle_points


func _play_slam_burst() -> void:
	play_world_vfx(&"boss_slam", global_position, 1.0)


func _play_death_burst() -> void:
	play_world_vfx(&"boss_death", global_position, 1.0)


func _configure_sprite_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var animation_rows := {
		&"idle": {"row": 0, "fps": 4.5},
		&"cast": {"row": 1, "fps": 7.0},
		&"charge": {"row": 2, "fps": 10.0},
		&"enraged": {"row": 3, "fps": 7.0},
	}
	for animation_name: StringName in animation_rows:
		var data: Dictionary = animation_rows[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(
			animation_name,
			float(data["fps"])
		)
		for frame_index in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = BOSS_TEXTURE
			frame.region = Rect2(
				frame_index * 256,
				int(data["row"]) * 256,
				256,
				256
			)
			frames.add_frame(animation_name, frame)
	sprite.sprite_frames = frames
	sprite.play(&"idle")


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


func play_world_vfx(
	effect_id: StringName,
	effect_position: Vector2,
	effect_scale: float
) -> void:
	var visual_effects := get_tree().root.get_node_or_null(
		"VisualEffects"
	)
	if visual_effects != null:
		visual_effects.call(
			"play",
			effect_id,
			effect_position,
			effect_scale
		)


func play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float
) -> void:
	if not is_inside_tree():
		return

	var audio_effects := get_tree().root.get_node_or_null(
		"AudioEffects"
	)
	if audio_effects != null:
		audio_effects.call(
			"play",
			sound_id,
			volume_db,
			pitch_variation,
			&"SFX"
		)
