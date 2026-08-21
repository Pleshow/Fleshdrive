class_name Charger
extends CharacterBody2D


const COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/enemy_combat_vfx_atlas.png"
)
const PIXEL_EMISSIVE_SHADER := preload("res://Shaders/pixel_emissive.gdshader")
const HIT_FLASH_DURATION: float = 0.12

enum State {
	CHASE,
	WINDUP,
	CHARGE,
	RECOVERY
}


signal died(enemy: Node2D)

@export_category("Movement")
@export var move_speed: float = 88.0
@export var acceleration: float = 620.0
@export var separation_radius: float = 94.0

@export_category("Charge")
@export var minimum_charge_distance: float = 230.0
@export var maximum_charge_distance: float = 620.0
@export var charge_speed: float = 650.0
@export var charge_windup: float = 1.05
@export var charge_duration: float = 0.72
@export var recovery_duration: float = 0.72
@export var charge_cooldown: float = 3.4
@export var charge_damage: float = 22.0
@export var charge_hit_radius: float = 56.0

@export_category("Health")
@export var max_health: float = 85.0

@export_category("Drops")
@export var biomass_pickup_scene: PackedScene
@export var biomass_value: float = 20.0
@export_range(0.0, 1.0) var biomass_drop_chance: float = 0.86
@export var death_vfx_scene: PackedScene
@export var death_vfx_scale: float = 1.1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trail: Sprite2D = $ChargeTrail
@onready var impact_animation: AnimatedSprite2D = $ImpactAnimation
@onready var charge_indicator: Polygon2D = $ChargeIndicator
@onready var charge_indicator_outline: Line2D = $ChargeIndicatorOutline
@onready var windup_timer: Timer = $WindupTimer
@onready var charge_timer: Timer = $ChargeTimer
@onready var recovery_timer: Timer = $RecoveryTimer
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var health_bar: ProgressBar = $HealthBar

var target: Node2D
var state: State = State.CHASE
var charge_direction: Vector2 = Vector2.RIGHT
var current_health: float
var is_dead: bool = false
var external_impulse: Vector2 = Vector2.ZERO
var readability_rim: Line2D
var hit_flash_remaining: float = 0.0
var health_bar_visual: Node2D
var health_bar_fill: Polygon2D
var unshaded_vfx_material: CanvasItemMaterial


func _ready() -> void:
	unshaded_vfx_material = CanvasItemMaterial.new()
	unshaded_vfx_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_install_consistent_sprite_material()
	_configure_impact_animation()
	var balance := get_tree().root.get_node_or_null("BalanceDatabase")
	if balance != null:
		balance.call("apply_enemy_profile", self, &"charger")
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health
	_install_readable_health_bar()
	_update_readable_health_bar()
	find_player()

	windup_timer.timeout.connect(_begin_charge)
	charge_timer.timeout.connect(_finish_charge)
	recovery_timer.timeout.connect(_finish_recovery)

	trail.hide()
	impact_animation.hide()
	charge_indicator.z_as_relative = false
	charge_indicator.z_index = -2
	charge_indicator.material = unshaded_vfx_material
	charge_indicator_outline.material = unshaded_vfx_material
	sprite.self_modulate = Color(1.16, 1.12, 1.22, 1.0)
	charge_indicator.color = Color("ff0546", 0.52)
	charge_indicator_outline.default_color = Color("ff0546")
	charge_indicator.hide()
	charge_indicator_outline.hide()


func prepare_for_reuse() -> void:
	is_dead = false
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health
	_update_readable_health_bar()
	if is_instance_valid(health_bar_visual):
		health_bar_visual.show()
	state = State.CHASE
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	winding_cleanup()
	find_player()
	sprite.play(&"normal")


func prepare_for_pool() -> void:
	target = null
	external_impulse = Vector2.ZERO
	hit_flash_remaining = 0.0
	sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO
	winding_cleanup()


func winding_cleanup() -> void:
	windup_timer.stop()
	charge_timer.stop()
	recovery_timer.stop()
	cooldown_timer.stop()
	charge_indicator.hide()
	charge_indicator_outline.hide()
	trail.hide()
	impact_animation.hide()
	_set_readability_state(&"normal")


func _physics_process(delta: float) -> void:
	_update_hit_flash(delta)
	if not is_instance_valid(target):
		find_player()

	if target == null:
		velocity = Vector2.ZERO
		return
	if external_impulse.length_squared() > 4.0:
		# A committed charge is telegraphed counter-pressure: ordinary kinetic
		# pushes may move it slightly, but cannot permanently cancel the move.
		if state not in [State.WINDUP, State.CHARGE]:
			_cancel_attack_for_displacement()
		else:
			external_impulse *= 0.18
		velocity = external_impulse
		move_and_slide()
		external_impulse = EnemySteering.register_displacement_wall_impact(
			self,
			external_impulse
		)
		external_impulse = external_impulse.move_toward(
			Vector2.ZERO,
			1050.0 * delta
		)
		return

	match state:
		State.CHASE:
			update_chase(delta)
		State.WINDUP:
			velocity = Vector2.ZERO
			update_telegraph()
		State.CHARGE:
			update_charge()
		State.RECOVERY:
			velocity = Vector2.ZERO


func apply_external_impulse(impulse: Vector2) -> void:
	if state in [State.WINDUP, State.CHARGE]:
		impulse *= 0.18
	external_impulse = (
		external_impulse + impulse
	).limit_length(760.0)
	velocity = external_impulse


func _cancel_attack_for_displacement() -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	windup_timer.stop()
	charge_timer.stop()
	recovery_timer.stop()
	charge_indicator.hide()
	trail.hide()
	impact_animation.hide()
	sprite.play(&"normal")
	collision_mask = 1
	cooldown_timer.start(0.75)


func find_player() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D


func update_chase(delta: float) -> void:
	var direction_to_target := global_position.direction_to(
		target.global_position
	)
	direction_to_target = EnemySteering.resolve_direction(
		self,
		direction_to_target,
		delta,
		separation_radius,
		1.7,
		0.16
	)
	velocity = velocity.move_toward(
		direction_to_target * move_speed,
		acceleration * delta
	)
	move_and_slide()
	update_facing(direction_to_target)
	try_start_charge()


func try_start_charge() -> void:
	if not cooldown_timer.is_stopped():
		return

	var distance := global_position.distance_to(target.global_position)

	if distance < minimum_charge_distance:
		return

	if distance > maximum_charge_distance:
		return

	_start_windup()


func _start_windup() -> void:
	if not is_instance_valid(target):
		return

	state = State.WINDUP
	velocity = Vector2.ZERO
	charge_direction = global_position.direction_to(target.global_position)
	update_facing(charge_direction)
	sprite.play(&"windup")
	_set_readability_state(&"windup")
	charge_indicator.show()
	charge_indicator_outline.show()
	update_telegraph()
	_pulse_charge_indicator()
	windup_timer.start(charge_windup)
	play_sound(&"charger_windup", -7.0, 0.035)
	_play_charge_vfx(
		&"charge_dust", global_position + charge_direction * 10.0,
		0.42, charge_direction.angle()
	)


func update_telegraph() -> void:
	var length := charge_speed * charge_duration
	var half_width := 42.0
	var forward := charge_direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var telegraph_points := PackedVector2Array([
		forward * 20.0 - side * half_width,
		forward * length - side * half_width,
		forward * length + side * half_width,
		forward * 20.0 + side * half_width,
	])
	charge_indicator.polygon = telegraph_points
	charge_indicator_outline.points = PackedVector2Array([
		telegraph_points[0], telegraph_points[1], telegraph_points[2],
		telegraph_points[3], telegraph_points[0],
	])


func _begin_charge() -> void:
	if state != State.WINDUP:
		return

	state = State.CHARGE
	charge_indicator.hide()
	charge_indicator_outline.hide()
	sprite.play(&"charge")
	_set_readability_state(&"charge")
	trail.show()
	collision_mask = 1
	charge_timer.start(charge_duration)
	play_sound(&"charger_charge", -6.0, 0.04)
	_play_charge_vfx(
		&"dash_smoke", global_position - charge_direction * 34.0,
		0.58, charge_direction.angle() + PI
	)


func _pulse_charge_indicator() -> void:
	charge_indicator.modulate.a = 1.0
	charge_indicator_outline.modulate.a = 1.0
	var tween := charge_indicator.create_tween()
	tween.set_loops(3)
	tween.tween_property(charge_indicator, "modulate:a", 0.72, charge_windup / 6.0)
	tween.tween_property(charge_indicator, "modulate:a", 1.0, charge_windup / 6.0)


func update_charge() -> void:
	velocity = charge_direction * charge_speed
	move_and_slide()

	if (
		is_instance_valid(target)
		and global_position.distance_squared_to(target.global_position)
		<= charge_hit_radius * charge_hit_radius
	):
		if target.has_method("take_damage"):
			target.take_damage(charge_damage, self, &"charger")
		_finish_charge(true)
		return

	for collision_index in get_slide_collision_count():
		_finish_charge(true)
		return


func _finish_charge(collided: bool = false) -> void:
	if state != State.CHARGE:
		return

	state = State.RECOVERY
	velocity = Vector2.ZERO
	collision_mask = 1
	trail.hide()
	sprite.play(&"normal")
	_set_readability_state(&"recovery")
	impact_animation.show()
	impact_animation.play(&"impact")
	recovery_timer.start(recovery_duration)
	play_sound(&"charger_impact", -5.0, 0.055)
	play_impact_vfx()
	if collided:
		var camera := get_tree().get_first_node_in_group("camera_feedback")
		if camera != null and camera.has_method("add_trauma_profile"):
			camera.call("add_trauma_profile", &"explosion")


func _finish_recovery() -> void:
	if state != State.RECOVERY:
		return

	state = State.CHASE
	_set_readability_state(&"normal")
	impact_animation.hide()
	cooldown_timer.start(charge_cooldown)


func update_facing(direction_to_face: Vector2) -> void:
	sprite.flip_h = direction_to_face.x < 0.0
	trail.flip_h = sprite.flip_h
	trail.position.x = 72.0 if sprite.flip_h else -72.0


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
	health_bar.value = current_health
	_update_readable_health_bar()
	play_hit_feedback()

	if current_health <= 0.0:
		die()
	elif event.play_hit_sound:
		play_sound(&"enemy_hit", -11.0, 0.07)
		request_combat_feedback(0.18, 0.28, event.screen_shake)


func get_knockback_resistance() -> float:
	if state in [State.WINDUP, State.CHARGE]:
		return 0.88
	return float(get_meta("knockback_resistance", 0.20))


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
	if is_instance_valid(health_bar_visual):
		health_bar_visual.hide()
	play_sound(&"enemy_death", -5.0, 0.07)
	died.emit(self)
	request_combat_feedback(0.62, 0.78)
	EnemyDeathAnimator.play_animation(
		self,
		sprite,
		&"death",
		death_vfx_scale
	)
	_try_drop_biomass()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_return_to_pool_or_free()


func _install_readable_health_bar() -> void:
	health_bar.hide()
	health_bar_visual = Node2D.new()
	health_bar_visual.name = "ReadableHealthBar"
	health_bar_visual.z_as_relative = false
	health_bar_visual.z_index = 82
	add_child(health_bar_visual)
	var background := Polygon2D.new()
	background.name = "Background"
	background.polygon = PackedVector2Array([
		Vector2(-37, -55), Vector2(37, -55),
		Vector2(37, -43), Vector2(-37, -43),
	])
	background.color = Color("1e579c")
	background.material = unshaded_vfx_material
	health_bar_visual.add_child(background)
	health_bar_fill = Polygon2D.new()
	health_bar_fill.name = "Fill"
	health_bar_fill.position = Vector2(-34, -52)
	health_bar_fill.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(68, 0), Vector2(68, 6), Vector2(0, 6),
	])
	health_bar_fill.color = Color("ff0546")
	health_bar_fill.material = unshaded_vfx_material
	health_bar_visual.add_child(health_bar_fill)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color("0ce6f2")
	outline.antialiased = false
	outline.material = unshaded_vfx_material
	outline.points = PackedVector2Array([
		Vector2(-38, -56), Vector2(38, -56), Vector2(38, -42),
		Vector2(-38, -42), Vector2(-38, -56),
	])
	health_bar_visual.add_child(outline)


func _install_consistent_sprite_material() -> void:
	var charger_material := ShaderMaterial.new()
	charger_material.shader = PIXEL_EMISSIVE_SHADER
	charger_material.set_shader_parameter("force_charger_dark", true)
	sprite.material = charger_material


func _update_readable_health_bar() -> void:
	if not is_instance_valid(health_bar_fill):
		return
	health_bar_fill.scale.x = clampf(
		current_health / maxf(max_health, 1.0),
		0.0,
		1.0
	)


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


func play_impact_vfx() -> void:
	if not is_inside_tree():
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call(
			"play",
			&"charger_impact",
			global_position,
			0.82,
			charge_direction.angle()
		)


func _play_charge_vfx(
	effect_id: StringName,
	position: Vector2,
	effect_scale: float,
	rotation_radians: float
) -> void:
	if not is_inside_tree():
		return
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call(
			"play", effect_id, position, effect_scale, rotation_radians
		)


func _configure_impact_animation() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"impact")
	frames.set_animation_loop(&"impact", false)
	frames.set_animation_speed(&"impact", 20.0)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = COMBAT_TEXTURE
		frame.region = Rect2(
			frame_index * 256,
			3 * 256,
			256,
			256
		)
		frames.add_frame(&"impact", frame)
	impact_animation.sprite_frames = frames
	impact_animation.material = sprite.material
	impact_animation.scale = Vector2.ONE * 0.32


func _set_readability_state(readability_state: StringName) -> void:
	# State readability comes from the authored charge telegraph and dust VFX.
	# Avoid persistent procedural outlines around the enemy silhouette.
	match readability_state:
		&"windup":
			sprite.modulate = Color(1.0, 0.88, 0.94, 1.0)
		&"charge":
			sprite.modulate = Color(0.92, 0.94, 1.0, 1.0)
		&"recovery":
			sprite.modulate = Color.WHITE
		_:
			sprite.modulate = Color.WHITE
