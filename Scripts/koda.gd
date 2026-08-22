class_name Koda
extends CharacterBody2D

const MAX_EXTRA_WEAPONS: int = 3
const MIN_WEAPON_UNLOCK_LEVEL_GAP: int = 3
const FIREBALL_PROJECTILE_SCENE := preload(
	"res://Scenes/player/fireball_projectile.tscn"
)
const EXTRA_WEAPON_IDS: Array[StringName] = [
	&"quill_burst",
	&"shock_ram",
	&"tail_lash",
	&"arc_spear",
	&"bone_shard_volley",
	&"cinder_volley",
	&"blazing_stride",
	&"inferno_ring",
	&"magma_spear",
	&"ashen_eruption",
	&"kinetic_shard",
	&"gravity_well",
	&"repulse_wave",
	&"orbiting_debris",
	&"neural_lance",
	&"ball_lightning",
	&"static_claws",
	&"spine_launcher", &"ripper_tail", &"bone_saw", &"parasite_maw",
	&"blood_needle", &"acid_gland", &"jaw_reflex", &"surgical_drone",
	&"implosion_sac",
]
const DIRECTION_ROWS: Array[StringName] = [
	&"down",
	&"right",
	&"up",
	&"left",
]
const WALK_DIRECTION_SOURCE_ROWS := {
	&"down": 0,
	&"right": 0,
	&"up": 0,
	&"left": 0,
}

const ACTION_DIRECTION_SOURCE_ROWS := {
	&"down": 0,
	&"right": 0,
	&"up": 0,
	&"left": 0,
}
const DIRECTION_SWITCH_BIAS: float = 1.18
const LEVEL_PACING_TIERS: Array[Dictionary] = [
	{"through_level": 3, "minimum": 15.0, "target_maximum": 20.0},
	{"through_level": 8, "minimum": 25.0, "target_maximum": 35.0},
	{"through_level": 999, "minimum": 35.0, "target_maximum": 50.0},
]
const VISUAL_ACTION_PRIORITIES := {
	&"attack": 10,
	&"jump": 20,
	&"hurt": 30,
	&"death": 100,
}

enum AttackMode {
	MANUAL,
	SEMI_AUTO,
	AUTO
}

signal health_changed(current_health: float, max_health: float)
signal died
signal biomass_changed(
	current_biomass: float,
	biomass_required: float,
	current_level: int
)

signal level_up_reached(current_level: int)
signal upgrade_levels_changed(upgrade_levels: Dictionary)

@export_category("Movement")
@export var move_speed: float = 210.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var walk_sprite_sheet: Texture2D
@export var idle_sprite_sheet: Texture2D
@export var walk_frame_size: Vector2i = Vector2i(112, 96)
@export var idle_frame_size: Vector2i = Vector2i(96, 96)
@export var walk_animation_speed: float = 13.0
@export var idle_animation_speed: float = 3.5
@export var jump_animation_speed: float = 12.0
@export var attack_animation_speed: float = 10.0
@export var hurt_animation_speed: float = 18.0
@export var death_animation_speed: float = 12.0

@export_category("Dash")
@export var dash_unlocked: bool = false
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.0
@export var dash_input_buffer: float = 0.16
@export_range(0.0, 1.0) var dash_control_return: float = 0.58
@export var dash_exit_speed_multiplier: float = 1.08

@export_category("Attack")
@export var attack_mode: AttackMode = AttackMode.MANUAL
@export var attack_damage: float = 15.0
@export var attack_interval: float = 0.8
@export var attack_range: float = 220.0
@export var manual_target_radius: float = 90.0
@export var chain_range: float = 150.0
@export var chain_damage_multiplier: float = 0.60
@export var chain_unlocked: bool = false
@export var semi_auto_target_radius: float = 165.0
@export var attack_input_buffer: float = 0.20


@export_category("Health")
@export var max_health: float = 100.0

@export_category("Progression")
@export var starting_biomass_required: float = 50.0
@export var biomass_requirement_multiplier: float = 1.35
@export var biomass_gain_multiplier: float = 1.0
@export var biomass_pickup_radius: float = 120.0
@export var biomass_drop_chance_bonus: float = 0.0
@export var weapon_cooldown_multiplier: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_duration_timer: Timer = $DashDurationTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var attack_area: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_cooldown_bar: ProgressBar = $AttackCooldownBar
@onready var lightning_line: Line2D = $LightningLine
@onready var lightning_glow: Line2D = $LightningGlow
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var attack_range_indicator: Line2D = $AttackRangeIndicator
@onready var movement_dust: CPUParticles2D = $MovementDust
@onready var landing_dust: CPUParticles2D = $LandingDust
@onready var ground_shadow: Sprite2D = $GroundShadow
@onready var weapon_system: PlayerWeaponSystem = $WeaponSystem
@onready var player_light: PointLight2D = $PlayerLight

var input_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var idle_side_direction: StringName = &"right"
var current_visual_direction: StringName = &"right"
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.DOWN
var dash_buffer_remaining: float = 0.0
var dash_elapsed: float = 0.0
var normal_scale: Vector2
var ground_shadow_base_scale: Vector2
var ground_shadow_base_alpha: float
var visual_action: StringName = &""
var visual_action_priority: int = 0
var visual_action_elapsed: float = 0.0
var visual_action_timeout: float = 0.0
var current_health: float
var is_dead: bool = false
var current_biomass: float = 0.0
var biomass_required: float
var current_level: int = 1
var total_biomass_collected: float = 0.0
var level_up_pending: bool = false
var attack_buffer_remaining: float = 0.0
var displayed_attack_range: float = -1.0
var upgrade_levels: Dictionary = {}
var selected_upgrade_history: Dictionary = {}
var last_weapon_unlock_level: int = -100
var active_fleshdrive_id: StringName = FleshdriveCatalog.ELECTRIC
var active_fleshdrive_level: int = 1
var burn_damage_multiplier: float = 1.0
var burn_duration_multiplier: float = 1.0
var combustion_unlocked: bool = false
var telekinetic_damage_multiplier: float = 1.0
var telekinetic_force_multiplier: float = 1.0
var fleshdrive_configured: bool = false
var damage_by_source: Dictionary = {}
var free_upgrade_rerolls: int = 0
var stored_healing: float = 0.0
var damage_screen_flash: ColorRect
var damage_screen_flash_tween: Tween
var level_pacing_clock: float = 0.0
var last_level_up_pacing_time: float = 0.0
var pacing_run_manager: RunManager

func _ready() -> void:
	configure_directional_animations()
	var range_material := CanvasItemMaterial.new()
	range_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	attack_range_indicator.material = range_material
	if MinimalistVisualProfile.is_active(get_tree()):
		_apply_minimalist_presentation()
	dash_duration_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown

	dash_duration_timer.timeout.connect(finish_dash)
	animated_sprite.animation_finished.connect(
		_on_visual_animation_finished
	)
	normal_scale = animated_sprite.scale
	ground_shadow_base_scale = ground_shadow.scale
	ground_shadow_base_alpha = ground_shadow.modulate.a
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		meta_progression.apply_to_player(self)
	current_health = max_health
	health_changed.emit(current_health, max_health)
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = true
	attack_timer.stop()
	biomass_required = starting_biomass_required

	biomass_changed.emit(
		current_biomass,
		biomass_required,
		current_level
	)

	update_attack_range_indicator()
	_install_damage_screen_flash()
	var combat_pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if (
		combat_pipeline != null
		and not combat_pipeline.damage_applied.is_connected(
			_on_combat_damage_for_lifesteal
		)
	):
		combat_pipeline.damage_applied.connect(_on_combat_damage_for_lifesteal)


func configure_directional_animations() -> void:
	if MinimalistVisualProfile.is_active(get_tree()):
		MinimalistVisualProfile.configure_player(animated_sprite)
		return
	if walk_sprite_sheet == null:
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	_add_directional_animation_set(
		frames,
		&"",
		walk_sprite_sheet,
		true,
		walk_animation_speed,
		8,
		WALK_DIRECTION_SOURCE_ROWS,
		walk_frame_size
	)
	_add_directional_animation_set(
		frames,
		&"idle",
		idle_sprite_sheet,
		true,
		idle_animation_speed,
		8,
		ACTION_DIRECTION_SOURCE_ROWS,
		idle_frame_size
	)
	_add_directional_animation_set(
		frames,
		&"jump",
		idle_sprite_sheet,
		false,
		jump_animation_speed,
		8,
		ACTION_DIRECTION_SOURCE_ROWS,
		idle_frame_size
	)
	_add_directional_animation_set(
		frames,
		&"attack",
		idle_sprite_sheet,
		false,
		attack_animation_speed,
		8,
		ACTION_DIRECTION_SOURCE_ROWS,
		idle_frame_size
	)
	_add_directional_animation_set(
		frames,
		&"hurt",
		idle_sprite_sheet,
		false,
		hurt_animation_speed,
		8,
		ACTION_DIRECTION_SOURCE_ROWS,
		idle_frame_size
	)
	
	_add_directional_animation_set(
		frames,
		&"death",
		idle_sprite_sheet,
		false,
		death_animation_speed,
		8,
		ACTION_DIRECTION_SOURCE_ROWS,
		idle_frame_size
	)

	animated_sprite.sprite_frames = frames
	animated_sprite.animation = &"idle_right"
	animated_sprite.frame = 0
	animated_sprite.play()


func _add_directional_animation_set(
	frames: SpriteFrames,
	prefix: StringName,
	sprite_sheet: Texture2D,
	loops: bool,
	animation_speed: float,
	frame_count: int,
	source_rows: Dictionary,
	frame_size: Vector2i
) -> void:
	if sprite_sheet == null:
		return

	for direction_name in DIRECTION_ROWS:
		var animation_name := _get_action_animation_name(
			prefix,
			direction_name
		)
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, loops)
		frames.set_animation_speed(
			animation_name,
			animation_speed
		)

		for column in range(frame_count):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = sprite_sheet
			var source_row := int(source_rows[direction_name])
			frame_texture.region = Rect2(
				column * frame_size.x,
				source_row * frame_size.y,
				frame_size.x,
				frame_size.y
			)
			frames.add_frame(animation_name, frame_texture)


func _get_action_animation_name(
	action: StringName,
	direction_name: StringName
) -> StringName:
	if action.is_empty():
		return direction_name
	return StringName("%s_%s" % [action, direction_name])


func _physics_process(delta: float) -> void:
	if not is_instance_valid(pacing_run_manager):
		pacing_run_manager = get_tree().get_first_node_in_group(
			"run_manager"
		) as RunManager
	if (
		pacing_run_manager == null
		or pacing_run_manager.state in [
			RunManager.RunState.PLAYING,
			RunManager.RunState.AIMING,
		]
	):
		level_pacing_clock += delta
	read_movement_input()
	dash_buffer_remaining = maxf(dash_buffer_remaining - delta, 0.0)
	attack_buffer_remaining = maxf(attack_buffer_remaining - delta, 0.0)
	if Input.is_action_just_pressed("attack"):
		attack_buffer_remaining = attack_input_buffer
	if Input.is_action_just_pressed("dash"):
		dash_buffer_remaining = dash_input_buffer

	if is_dashing:
		update_dash_movement(delta)
	else:
		update_normal_movement(delta)
		try_start_dash()

	move_and_slide()
	_update_visual_action_watchdog(delta)
	update_direction_sprite()
	update_ground_shadow()
	update_movement_dust()
	update_attack()
	_update_attack_cooldown_bar()
	if current_biomass >= biomass_required and not level_up_pending:
		_try_trigger_level_up()

func read_movement_input() -> void:
	input_direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_direction != Vector2.ZERO:
		last_direction = input_direction.normalized()
		if input_direction.x > 0.1:
			idle_side_direction = &"right"
		elif input_direction.x < -0.1:
			idle_side_direction = &"left"


func update_normal_movement(delta: float) -> void:
	var volt_movement_multiplier := (
		weapon_system.volt_hound_movement_multiplier()
		if weapon_system != null else 1.0
	)
	var universal_movement_multiplier := (
		weapon_system.universal_movement_multiplier()
		if weapon_system != null else 1.0
	)
	var target_velocity := (
		input_direction
		* move_speed
		* float(get_meta("thunder_move_multiplier", 1.0))
		* volt_movement_multiplier
		* universal_movement_multiplier
	)

	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)


func try_start_dash() -> void:
	if not dash_unlocked:
		return

	if (
		dash_buffer_remaining <= 0.0
		and not Input.is_action_just_pressed("dash")
	):
		return

	if not dash_cooldown_timer.is_stopped():
		return

	is_dashing = true
	dash_buffer_remaining = 0.0
	dash_elapsed = 0.0
	dash_direction = (
		input_direction.normalized()
		if input_direction != Vector2.ZERO
		else last_direction.normalized()
	)
	play_jump_animation(dash_direction)
	play_sound(&"raiju_dash", -7.0, 0.045)
	play_combat_vfx(
		&"dash_smoke",
		global_position - dash_direction * 24.0,
		0.52,
		dash_direction.angle() + PI
	)

	dash_duration_timer.start()
	dash_cooldown_timer.start(
		dash_cooldown
		* float(get_meta("thunder_dash_multiplier", 1.0))
		* (
			weapon_system.volt_hound_dash_cooldown_multiplier()
			if weapon_system != null else 1.0
		)
	)
	animated_sprite.modulate.a = 0.65
	animated_sprite.scale = normal_scale * 1.12

func update_dash_movement(delta: float) -> void:
	dash_elapsed += delta
	var progress := dash_elapsed / maxf(dash_duration, 0.001)
	if progress >= dash_control_return and input_direction != Vector2.ZERO:
		var return_weight := inverse_lerp(dash_control_return, 1.0, progress)
		dash_direction = dash_direction.slerp(
			input_direction.normalized(),
			clampf(return_weight * 0.22, 0.0, 0.22)
		).normalized()
	velocity = dash_direction * dash_speed * (
		weapon_system.volt_hound_dash_speed_multiplier()
		if weapon_system != null else 1.0
	)


func finish_dash() -> void:
	is_dashing = false
	play_combat_vfx(
		&"dash_smoke_end",
		global_position - dash_direction * 8.0,
		0.34,
		dash_direction.angle() + PI
	)
	velocity = dash_direction * move_speed * dash_exit_speed_multiplier
	animated_sprite.modulate.a = 1.0
	animated_sprite.scale = normal_scale
	if visual_action == &"jump":
		visual_action = &""
		visual_action_priority = 0
		update_direction_sprite()
	play_sound(&"raiju_land", -9.0, 0.08)
	play_landing_dust()
	if weapon_system != null:
		weapon_system.notify_dash_finished()


func update_movement_dust() -> void:
	movement_dust.emitting = (
		not is_dead
		and not is_dashing
		and velocity.length_squared() > 625.0
	)


func play_landing_dust() -> void:
	landing_dust.restart()
	landing_dust.emitting = true


func update_ground_shadow() -> void:
	var speed_ratio := clampf(
		velocity.length() / maxf(move_speed, 1.0),
		0.0,
		1.0
	)
	var stride_phase := sin(
		float(animated_sprite.frame) * TAU / maxf(
			float(
				animated_sprite.sprite_frames.get_frame_count(
					animated_sprite.animation
				)
			),
			1.0
		)
	)
	var stride_offset := stride_phase * 0.025 * speed_ratio
	var target_scale := ground_shadow_base_scale * Vector2(
		1.0 + speed_ratio * 0.045 + stride_offset,
		1.0 - speed_ratio * 0.035 - stride_offset * 0.5
	)
	var target_alpha := ground_shadow_base_alpha

	if is_dashing:
		target_scale = ground_shadow_base_scale * Vector2(0.78, 0.72)
		target_alpha = ground_shadow_base_alpha * 0.42
	elif is_dead:
		target_scale = ground_shadow_base_scale * Vector2(1.04, 0.96)
		target_alpha = ground_shadow_base_alpha * 0.62

	ground_shadow.scale = ground_shadow.scale.lerp(
		target_scale,
		0.34
	)
	var shadow_modulate := ground_shadow.modulate
	shadow_modulate.a = lerpf(
		shadow_modulate.a,
		target_alpha,
		0.38
	)
	ground_shadow.modulate = shadow_modulate


func update_direction_sprite() -> void:
	if not visual_action.is_empty():
		return

	var shown_direction := input_direction

	if is_dashing:
		shown_direction = dash_direction
	elif shown_direction == Vector2.ZERO:
		shown_direction = last_direction

	# Movement uses only the side-view run cycle. Vertical input preserves the
	# last horizontal facing, so Koda no longer changes apparent size or snaps
	# into a front/back gait while traversing the arena.
	if shown_direction.x > 0.08:
		idle_side_direction = &"right"
	elif shown_direction.x < -0.08:
		idle_side_direction = &"left"
	var direction_name := idle_side_direction
	var is_moving := (
		is_dashing
		or input_direction != Vector2.ZERO
	)
	animated_sprite.flip_h = direction_name == &"left"
	var animation_name := direction_name
	if not is_moving:
		animated_sprite.flip_h = idle_side_direction == &"left"
		animation_name = _get_action_animation_name(
			&"idle",
			idle_side_direction
		)

	if animated_sprite.animation != animation_name:
		animated_sprite.animation = animation_name
		animated_sprite.frame = 0

	if not animated_sprite.is_playing():
		animated_sprite.play()


func play_jump_animation(direction: Vector2) -> void:
	if direction.x > 0.08:
		idle_side_direction = &"right"
	elif direction.x < -0.08:
		idle_side_direction = &"left"
	_play_visual_action(
		&"jump",
		Vector2.LEFT if idle_side_direction == &"left" else Vector2.RIGHT
	)


func play_attack_animation(direction: Vector2) -> void:
	if direction.x > 0.08:
		idle_side_direction = &"right"
	elif direction.x < -0.08:
		idle_side_direction = &"left"
	animated_sprite.flip_h = idle_side_direction == &"left"
	if input_direction == Vector2.ZERO and not is_dashing:
		var idle_animation := _get_action_animation_name(
			&"idle",
			idle_side_direction
		)
		if animated_sprite.animation != idle_animation:
			animated_sprite.play(idle_animation)
	_flash_fleshdrive_attack_aura()


func _flash_fleshdrive_attack_aura() -> void:
	# Voltaic already draws its complete authored bolt between Koda and the
	# target. A second body-origin effect only obscures Koda's silhouette.
	if active_fleshdrive_id == FleshdriveCatalog.ELECTRIC:
		return
	var effect_id := &"fire_muzzle"
	var effect_scale := 0.58
	if active_fleshdrive_id == FleshdriveCatalog.FIRE:
		effect_id = &"fire_muzzle"
		effect_scale = 0.58
	elif active_fleshdrive_id == FleshdriveCatalog.TELEKINETIC:
		effect_id = &"neural_lance"
		effect_scale = 0.72
	var direction := last_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var local_origin := Vector2(0.0, -10.0) + direction * 9.0
	var effect := play_combat_vfx(
		effect_id, to_global(local_origin), effect_scale, direction.angle()
	)
	if effect != null:
		effect.name = "AttackVFX"
		effect.reparent(self, true)
		effect.position = local_origin
		effect.rotation = direction.angle()
		effect.z_as_relative = true
		effect.z_index = 12


func play_hurt_animation(direction: Vector2 = Vector2.ZERO) -> void:
	_play_visual_action(&"hurt", direction)


func _play_visual_action(
	action: StringName,
	direction: Vector2
) -> void:
	var priority := int(VISUAL_ACTION_PRIORITIES.get(action, 0))
	if (
		not visual_action.is_empty()
		and priority < visual_action_priority
	):
		return

	var shown_direction := direction.normalized()
	if shown_direction == Vector2.ZERO:
		shown_direction = last_direction
	var direction_name := get_direction_name(shown_direction)
	var animation_name := _get_action_animation_name(
		action,
		direction_name
	)
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	visual_action = action
	visual_action_priority = priority
	visual_action_elapsed = 0.0
	animated_sprite.flip_h = direction_name == &"left"
	animated_sprite.animation = animation_name
	animated_sprite.frame = 0
	var frame_count := animated_sprite.sprite_frames.get_frame_count(
		animation_name
	)
	var animation_speed := animated_sprite.sprite_frames.get_animation_speed(
		animation_name
	)
	visual_action_timeout = maxf(
		float(frame_count) / maxf(animation_speed, 1.0) + 0.2,
		0.4
	)
	animated_sprite.play()


func _update_visual_action_watchdog(delta: float) -> void:
	if visual_action.is_empty() or visual_action == &"death":
		return
	visual_action_elapsed += delta
	if (
		animated_sprite.is_playing()
		and visual_action_elapsed < visual_action_timeout
	):
		return
	visual_action = &""
	visual_action_priority = 0
	visual_action_elapsed = 0.0
	visual_action_timeout = 0.0


func _on_visual_animation_finished() -> void:
	if visual_action == &"death":
		animated_sprite.pause()
		animated_sprite.frame = (
			animated_sprite.sprite_frames.get_frame_count(
				animated_sprite.animation
			) - 1
		)
		animated_sprite.modulate = Color(0.62, 0.65, 0.72, 0.82)
		return

	visual_action = &""
	visual_action_priority = 0
	visual_action_elapsed = 0.0
	visual_action_timeout = 0.0
	update_direction_sprite()


func get_direction_name(direction: Vector2) -> StringName:
	if absf(direction.x) >= absf(direction.y):
		return &"right" if direction.x >= 0.0 else &"left"
	return &"down" if direction.y >= 0.0 else &"up"


func get_stable_direction_name(direction: Vector2) -> StringName:
	if direction.is_zero_approx():
		return current_visual_direction

	var candidate := get_direction_name(direction)
	var current_is_horizontal := current_visual_direction in [
		&"left",
		&"right",
	]
	var candidate_is_horizontal := candidate in [&"left", &"right"]

	if current_is_horizontal != candidate_is_horizontal:
		var horizontal_strength := absf(direction.x)
		var vertical_strength := absf(direction.y)
		if (
			candidate_is_horizontal
			and horizontal_strength
			< vertical_strength * DIRECTION_SWITCH_BIAS
		):
			candidate = (
				&"right" if direction.x >= 0.0 else &"left"
			) if current_is_horizontal else (
				&"down" if direction.y >= 0.0 else &"up"
			)
		elif (
			not candidate_is_horizontal
			and vertical_strength
			< horizontal_strength * DIRECTION_SWITCH_BIAS
		):
			candidate = (
				&"right" if direction.x >= 0.0 else &"left"
			) if current_is_horizontal else (
				&"down" if direction.y >= 0.0 else &"up"
			)

	current_visual_direction = candidate
	return current_visual_direction

func take_damage(
	amount: float,
	source: Node = null,
	source_id: StringName = &"enemy_attack",
	damage_type: DamageEvent.DamageType = DamageEvent.DamageType.CONTACT
) -> void:
	var event := DamageEvent.create(
		self,
		amount,
		source,
		source_id,
		&"hostile"
	)
	event.damage_type = damage_type
	event.show_damage_number = true
	event.heavy_feedback = false
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.call("apply_damage", event)


func refund_dash_cooldown_fraction(fraction: float) -> void:
	if dash_cooldown_timer.is_stopped():
		return
	var remaining := dash_cooldown_timer.time_left
	dash_cooldown_timer.stop()
	var refunded_remaining := remaining * (1.0 - clampf(fraction, 0.0, 1.0))
	if refunded_remaining > 0.01:
		dash_cooldown_timer.start(refunded_remaining)


func modify_incoming_damage_event(
	event: DamageEvent,
	amount: float
) -> float:
	if bool(get_meta("balance_debug_god_mode", false)):
		return 0.0
	if is_dead or not invulnerability_timer.is_stopped():
		return 0.0
	amount *= 1.0 - clampf(float(get_meta("armor", 0.0)), 0.0, 0.85)
	var hide_level := get_upgrade_level(&"smoldering_hide")
	if hide_level > 0 and event.source is Node2D:
		var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
		if pipeline != null and not Dictionary(
			pipeline.call("get_status", event.source, &"burn")
		).is_empty():
			amount *= maxf(
				0.1,
				1.0 - BuildItemCatalog.value(
					&"smoldering_hide", "contact_reduction_per_level"
				) * float(hide_level)
			)
	if weapon_system != null and weapon_system.build_runtime != null:
		amount *= weapon_system.build_runtime.incoming_damage_multiplier()
	if weapon_system != null:
		amount = weapon_system.volt_hound_modify_incoming_damage(event, amount)
		amount = weapon_system.universal_modify_incoming_damage(amount)
	return amount


func _on_combat_damage_for_lifesteal(
	event: DamageEvent,
	result: Dictionary
) -> void:
	if event == null or event.source != self or is_dead:
		return
	var lifesteal := clampf(float(get_meta("lifesteal", 0.0)), 0.0, 1.0)
	var applied_damage := float(result.get("damage", 0.0))
	if lifesteal > 0.0 and applied_damage > 0.0:
		heal(applied_damage * lifesteal)


func receive_damage_event(
	event: DamageEvent,
	amount: float
) -> void:
	if is_dead:
		return
	if amount <= 0.0:
		return

	current_health = max(current_health - amount, 0.0)
	set_meta("last_damage_source_id", event.source_id)
	set_meta("last_damage_type", event.damage_type)
	set_meta("last_damage_amount", amount)
	set_meta("last_damage_time_msec", Time.get_ticks_msec())
	if weapon_system != null and weapon_system.build_runtime != null:
		weapon_system.build_runtime.on_player_damaged()
	if weapon_system != null:
		weapon_system.notify_player_damaged(amount)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	var manager := get_tree().get_first_node_in_group(
		"run_manager"
	) as RunManager
	if telemetry != null:
		telemetry.call(
			"record_player_damage",
			amount,
			event.source_id,
			manager.elapsed_seconds if manager != null else 0.0
		)
	invulnerability_timer.start()
	health_changed.emit(current_health, max_health)
	play_sound(&"player_hurt", -5.0, 0.035)

	request_combat_feedback(
		0.36 if current_health <= 0.0 else 0.22,
		0.38 if current_health <= 0.0 else 0.20
	)
	play_hurt_feedback()

	if current_health <= 0.0:
		die()
	else:
		play_hurt_animation()


func play_hurt_feedback() -> void:
	animated_sprite.modulate = Color(1.0, 0.35, 0.35)

	var tween := create_tween()
	tween.tween_property(
		animated_sprite,
		"modulate",
		Color.WHITE,
		0.18
	)
	if not is_instance_valid(damage_screen_flash):
		return
	if damage_screen_flash_tween != null and damage_screen_flash_tween.is_valid():
		damage_screen_flash_tween.kill()
	damage_screen_flash.color = Color(0.92, 0.015, 0.02, 0.30)
	damage_screen_flash_tween = damage_screen_flash.create_tween()
	damage_screen_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	damage_screen_flash_tween.tween_property(
		damage_screen_flash,
		"color",
		Color(0.55, 0.0, 0.01, 0.0),
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _install_damage_screen_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DamageFeedbackLayer"
	layer.layer = 118
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	damage_screen_flash = ColorRect.new()
	damage_screen_flash.name = "DamageScreenFlash"
	damage_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_screen_flash.color = Color(0.55, 0.0, 0.01, 0.0)
	layer.add_child(damage_screen_flash)


func request_combat_feedback(
	shake_amount: float,
	hit_stop_strength: float
) -> void:
	var feedback := get_tree().get_first_node_in_group("combat_feedback")
	if feedback != null and feedback.has_method("play_hit"):
		feedback.play_hit(shake_amount, hit_stop_strength)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	attack_cooldown_bar.hide()
	velocity = Vector2.ZERO
	set_physics_process(false)

	collision_layer = 0
	collision_mask = 0

	animated_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_visual_action(&"death", last_direction)
	play_sound(&"player_death", -2.0)
	died.emit()

func update_attack() -> void:
	update_attack_range_indicator()

	if is_dead:
		return

	match attack_mode:
		AttackMode.MANUAL:
			try_manual_attack()

		AttackMode.SEMI_AUTO:
			try_semi_auto_attack()

		AttackMode.AUTO:
			try_auto_attack()


func try_manual_attack() -> void:
	if attack_buffer_remaining <= 0.0:
		return
	# Right mouse confirms a manually aimed Magma Spear. Do not also emit
	# Koda's normal attack from the same click.
	if weapon_system != null and weapon_system.magma_aim_active:
		attack_buffer_remaining = 0.0
		return

	if not attack_timer.is_stopped():
		return

	var target := find_manual_target()

	if target == null:
		return

	perform_attack(target)
	attack_buffer_remaining = 0.0
	attack_timer.start()


func try_auto_attack() -> void:
	if not attack_timer.is_stopped():
		return

	var target := find_nearest_enemy()

	if target == null:
		return

	perform_attack(target)
	attack_timer.start()

func perform_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	if not target.is_in_group("enemies"):
		return

	if target.get("is_dead") == true:
		return

	var distance_squared := global_position.distance_squared_to(
		target.global_position
	)

	if distance_squared > attack_range * attack_range:
		return

	if not target.has_method("take_damage"):
		return

	if active_fleshdrive_id == FleshdriveCatalog.FIRE:
		_perform_fire_attack(target)
		return
	if active_fleshdrive_id == FleshdriveCatalog.TELEKINETIC:
		_perform_telekinetic_attack(target)
		return
	if weapon_system != null and get_upgrade_level(&"arc_heart") > 0:
		# Set the mirrored attack pose before the runtime samples the chest socket.
		# This keeps moving and freshly-turned attacks on the same anatomical point.
		var thunder_direction := global_position.direction_to(target.global_position)
		play_attack_animation(thunder_direction)
		if weapon_system.perform_thunder_god_attack(target):
			play_sound(&"raiju_attack", -8.0, 0.055)
			play_sound(&"raiju_attack_spark", -2.0, 0.08)
			return

	var chain_target: Node2D = null
	var lightning_targets: Array[Node2D] = [target]

	if chain_unlocked:
		chain_target = find_chain_target(target)

	if chain_target != null:
		lightning_targets.append(chain_target)

	var muzzle_direction := global_position.direction_to(
		target.global_position
	)
	play_attack_animation(muzzle_direction)
	show_lightning_effect(lightning_targets)
	play_sound(&"raiju_attack", -8.0, 0.055)
	play_sound(&"raiju_attack_spark", -2.0, 0.08)
	play_combat_vfx(
		&"arc_muzzle",
		global_position + muzzle_direction * 30.0,
		0.75
	)
	play_combat_vfx(&"electric_impact", target.global_position, 1.0)

	var arc_context := ProcContext.new(1)
	arc_context.visit(target)
	_deal_base_damage(target, attack_damage, &"base_arc", FleshdriveCatalog.ELECTRIC, arc_context)

	if (
		is_instance_valid(chain_target)
		and chain_target.has_method("take_damage")
	):
		var chain_damage := (
			attack_damage * chain_damage_multiplier
		)

		arc_context.visit(chain_target)
		_deal_base_damage(chain_target, chain_damage, &"chain_lightning", FleshdriveCatalog.ELECTRIC, arc_context)
		play_combat_vfx(
			&"electric_impact",
			chain_target.global_position,
			0.72
		)


func _perform_fire_attack(target: Node2D) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_player_projectile")):
		return
	var muzzle_direction := global_position.direction_to(
		target.global_position
	)
	play_attack_animation(muzzle_direction)
	play_sound(&"raiju_attack", -10.0, 0.045)
	play_combat_vfx(
		&"fire_muzzle",
		global_position + muzzle_direction * 30.0,
		0.8,
		muzzle_direction.angle()
	)
	play_combat_vfx(
		&"fireball_creation",
		global_position + muzzle_direction * 26.0,
		1.05
	)
	var direct_damage := attack_damage * 0.72
	var projectile := FIREBALL_PROJECTILE_SCENE.instantiate() as FireballProjectile
	var container := get_tree().get_first_node_in_group("attack_container")
	if container == null:
		container = get_parent()
	if projectile == null or container == null:
		return
	container.add_child(projectile)
	projectile.global_position = global_position + muzzle_direction * 34.0
	projectile.configure(
		self,
		target,
		muzzle_direction,
		direct_damage,
		attack_damage * 0.18,
		3.2,
		maxf(attack_range + 120.0, 480.0)
	)


func _perform_telekinetic_attack(target: Node2D) -> void:
	var direction := global_position.direction_to(target.global_position)
	play_attack_animation(direction)
	play_sound(&"telekinetic_cast", -10.0, 0.055)
	play_combat_vfx(
		&"kinetic_impact",
		target.global_position,
		0.72
	)
	_deal_base_damage(
		target,
		attack_damage * 0.90 * telekinetic_damage_multiplier,
		&"base_kinetic",
		FleshdriveCatalog.TELEKINETIC
	)
	var push_force := (
		direction
		* 277.5
		* telekinetic_force_multiplier
	)
	if target.has_method("apply_external_impulse"):
		target.call("apply_external_impulse", push_force)
	elif target is CharacterBody2D:
		(target as CharacterBody2D).velocity += push_force
	target.set_meta("telekinetically_displaced", true)


func _register_damage_feedback(target: Node2D, amount: float) -> void:
	var feedback := get_tree().get_first_node_in_group("combat_feedback")
	if feedback != null and feedback.has_method("register_damage"):
		feedback.call(
			"register_damage",
			target,
			amount,
			active_fleshdrive_id,
			true,
			true
		)


func _deal_base_damage(
	target: Node2D,
	amount: float,
	source_id: StringName,
	affinity: StringName,
	context: ProcContext = null
) -> void:
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline == null:
		target.take_damage(amount)
		record_damage_source(source_id, amount)
		_register_damage_feedback(target, amount)
		return
	var event := DamageEvent.create(target, amount, self, source_id, affinity)
	event.damage_type = DamageEvent.DamageType.DIRECT
	event.can_crit = true
	event.critical_chance = float(get_meta("critical_chance", 0.05))
	event.critical_multiplier = float(get_meta("critical_multiplier", 1.5))
	event.proc_context = context
	if weapon_system != null and weapon_system.build_runtime != null:
		event.amount = weapon_system.build_runtime.modify_damage(
			source_id, affinity, event.amount, event.damage_type
		)
	pipeline.call("apply_damage", event)

func find_manual_target() -> Node2D:
	return find_target_near_mouse(
		manual_target_radius
	)

func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_squared := INF

	for body in attack_area.get_overlapping_bodies():
		if not body.is_in_group("enemies"):
			continue

		if body.get("is_dead") == true:
			continue

		var enemy := body as Node2D

		if enemy == null:
			continue

		var distance_squared := global_position.distance_squared_to(
			enemy.global_position
		)

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy

func find_chain_target(primary_target: Node2D) -> Node2D:
	if not is_instance_valid(primary_target):
		return null

	var nearest_target: Node2D = null
	var nearest_distance_squared := chain_range * chain_range

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D

		if enemy == null:
			continue

		if enemy == primary_target:
			continue

		if enemy.get("is_dead") == true:
			continue

		var distance_squared := (
			primary_target.global_position.distance_squared_to(
				enemy.global_position
			)
		)

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy

	return nearest_target

func show_lightning_effect(
	targets: Array[Node2D]
) -> void:
	if targets.is_empty():
		return

	# The licensed four-frame chain arc has organic branching and a clean
	# electric silhouette. Stretch it only along its authored horizontal axis,
	# then rotate the complete animation between each pair of chain targets.
	hide_lightning_effect()
	var segment_start := get_electric_muzzle_position(
		targets[0].global_position
	)

	for target in targets:
		if not is_instance_valid(target):
			continue

		var segment_end := target.global_position
		_spawn_autoattack_lightning_asset(segment_start, segment_end)
		segment_start = segment_end


func get_electric_muzzle_position(_target_world_position: Vector2) -> Vector2:
	var facing_sign := -1.0 if animated_sprite.flip_h else 1.0
	# Koda's Dusk Garden sprite is centred on the body. Nine pixels forward and
	# seven pixels upward places the socket under the jaw, at the upper chest,
	# instead of at the paws/body origin.
	return animated_sprite.to_global(Vector2(9.0 * facing_sign, -7.0))


func _spawn_autoattack_lightning_asset(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var distance := delta.length()
	if distance < 2.0:
		return
	var arc := play_combat_vfx(
		&"electric_chain_arc",
		from.lerp(to, 0.5),
		1.0,
		delta.angle()
	)
	if arc == null:
		return
	# The useful painted span is approximately 210 px inside the 256 px asset.
	# Preserve its authored vertical branching while fitting arbitrary ranges.
	arc.scale = Vector2(distance / 210.0, 0.72)
	arc.flip_v = randf() > 0.5
	arc.z_index = 74
	arc.name = "AutoattackLightningVFX"
	arc.set_meta("autoattack_lightning", true)


func hide_lightning_effect() -> void:
	lightning_line.visible = false
	lightning_line.clear_points()
	lightning_glow.visible = false
	lightning_glow.clear_points()


func add_biomass(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	var gained_biomass := (
		amount
		* biomass_gain_multiplier
		* _get_level_pacing_yield_multiplier()
	)
	if weapon_system != null:
		weapon_system.notify_biomass_collected()
	current_biomass += gained_biomass
	total_biomass_collected += gained_biomass

	if not _try_trigger_level_up():
		_emit_biomass_changed()


func _try_trigger_level_up() -> bool:
	if level_up_pending:
		return false

	if current_biomass < biomass_required:
		return false

	# Kinetic Charge is a short, continuous control state. Opening the level-up
	# overlay inside it used to pause/cancel the charge before its payoff. Keep
	# the biomass untouched and retry from _physics_process as soon as the state
	# has naturally ended.
	if (
		weapon_system != null
		and weapon_system.is_kinetic_charge_state_active()
	):
		return false

	current_biomass -= biomass_required
	level_up_pending = true
	level_up()
	return true


func confirm_level_up() -> void:
	if not level_up_pending:
		return

	level_up_pending = false

	_emit_biomass_changed()

	if current_biomass >= biomass_required:
		_queue_followup_level_up()


func _queue_followup_level_up() -> void:
	# Consume overflow promptly so the XP bar always describes exactly one
	# level. A short input guard prevents the accepted click from leaking.
	await get_tree().create_timer(0.22, false).timeout
	if not is_dead and not level_up_pending:
		_try_trigger_level_up()


func level_up() -> void:
	current_level += 1
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_level_reached", current_level)
	last_level_up_pacing_time = level_pacing_clock
	_refresh_level_up_reroll_entitlement()
	if get_upgrade_level(&"malignant_growth") > 0:
		attack_damage *= 1.03
		max_health = maxf(max_health - 2.0, 1.0)
		current_health = minf(current_health, max_health)
		health_changed.emit(current_health, max_health)
	play_sound(&"level_up", -4.0, 0.025)

	biomass_required = round(
		biomass_required * biomass_requirement_multiplier
	)

	# Keep the HUD correct for every progression route, including pacing-gate
	# and overflow level-ups that are not triggered directly by a pickup.
	_emit_biomass_changed()
	level_up_reached.emit(current_level)


func _emit_biomass_changed() -> void:
	biomass_changed.emit(
		current_biomass,
		biomass_required,
		current_level
	)



func get_level_pacing_elapsed() -> float:
	return maxf(level_pacing_clock - last_level_up_pacing_time, 0.0)


func get_level_pacing_contract(level_before_upgrade: int = current_level) -> Dictionary:
	for tier in LEVEL_PACING_TIERS:
		if level_before_upgrade <= int(tier["through_level"]):
			return tier.duplicate()
	return LEVEL_PACING_TIERS.back().duplicate()


func _get_level_pacing_yield_multiplier() -> float:
	var contract := get_level_pacing_contract()
	var minimum := float(contract["minimum"])
	var target_maximum := float(contract["target_maximum"])
	var elapsed := get_level_pacing_elapsed()
	if elapsed <= minimum:
		return 1.0
	# Catch-up affects earned biomass only; the player never levels by waiting.
	# It narrows unlucky drop variance while preserving combat as the source.
	return lerpf(
		1.0,
		1.55,
		clampf(inverse_lerp(minimum, target_maximum, elapsed), 0.0, 1.0)
	)


func _refresh_level_up_reroll_entitlement() -> void:
	free_upgrade_rerolls = (
		1
		if get_upgrade_level(&"experimental_tissue") > 0 and current_level % 2 == 0
		else 0
	)
func apply_upgrade(upgrade_id: StringName) -> void:
	var is_new_weapon := (
		upgrade_id in EXTRA_WEAPON_IDS
		and get_upgrade_level(upgrade_id) == 0
	)
	if is_new_weapon and not can_unlock_weapon(upgrade_id):
		return

	var upgrade_applied := true

	match upgrade_id:
		&"conductive_marrow":
			apply_conductive_marrow()

		&"rapid_synapses":
			apply_rapid_synapses()

		&"predator_tendons":
			apply_predator_tendons()

		&"reinforced_rib_cage":
			max_health += 18.0
			current_health += 18.0
			move_speed *= 0.95
			health_changed.emit(current_health, max_health)

		&"hypertrophic_muscle":
			attack_damage *= 1.20

		&"open_wound":
			attack_damage *= 1.25

		&"biomass_magnet":
			biomass_pickup_radius *= 1.40

		&"overgrown_nerve_cluster":
			pass

		&"adrenal_gland", &"predators_hunger", \
		&"second_heartbeat", &"mutated_synapse", &"echo_nerve", \
		&"elastic_tendons", &"reactive_hide", &"bone_plating", \
		&"pain_converter", &"impact_sac", &"shed_skin", \
		&"predator_reflex", &"experimental_tissue", &"unstable_genome", \
		&"cannibal_enzyme", &"split_nervous_system", &"malignant_growth", \
		&"scavenger_stomach", &"reserve_bladder", &"hungry_magnet", \
		&"porcupine_reflex":
			pass
		
		&"biomass_receptors":
			apply_biomass_receptors()

		&"reinforced_carapace":
			apply_reinforced_carapace()
			
		&"pulse_capacitor":
			apply_pulse_capacitor()
			
		&"impulse_gland":
			unlock_dash()
			
		&"arc_heart":
			unlock_chain_lightning()

		&"ball_lightning", &"ionized_membrane", &"plasma_expansion", \
		&"static_replication", &"residual_charge", &"orbital_charge", \
		&"electric_gravity", &"plasma_shepherd", &"star_collapse", \
		&"chain_reactor", &"polarity_shift":
			pass

		&"static_claws":
			unlock_dash()

		&"voltaic_tendons", &"phantom_current", &"predators_static", \
		&"flash_step", &"magnetic_predator", &"nerve_overclock", \
		&"lightspeed", &"capacitor_marrow", &"predator_coil", \
		&"charged_paw_pads", &"ionized_spine", &"purple_heart", \
		&"double_exposure", &"ballistic_nervous_system", \
		&"electric_kinetic_expanded_capacitor", \
		&"electric_kinetic_predator_capacitor", \
		&"electric_kinetic_compressed_charge":
			pass
			
		&"reflex_cortex":
			unlock_semi_auto()

		&"autonomic_reflex":
			unlock_auto_attack()

		&"biomass_lure":
			apply_biomass_lure()

		&"scavenger_gland":
			biomass_drop_chance_bonus = minf(
				biomass_drop_chance_bonus + 0.06,
				0.30
			)

		&"hemo_recycler":
			pass

		&"overload_vent":
			apply_overload_vent()

		&"kill_switch_nodes":
			pass

		&"conductive_fur", &"arc_relay", &"capacitor_organ", \
		&"storm_core", &"ionized_blood", &"neural_thunder", \
		&"feedback_loop", &"overload_heart", &"eye_of_the_storm", \
		&"singularity_core":
			pass

		&"reflex_spurs":
			apply_reflex_spurs()

		&"thermal_lattice":
			burn_damage_multiplier *= 1.18
			burn_duration_multiplier *= 1.12

		&"combustion_sac":
			combustion_unlocked = true

		&"cauterizing_blood", &"flashpoint_nodes":
			pass

		&"mass_amplifier":
			telekinetic_damage_multiplier *= 1.14
			telekinetic_force_multiplier *= 1.12

		&"vector_cortex":
			weapon_cooldown_multiplier *= 0.91
			telekinetic_damage_multiplier *= 1.08
			telekinetic_force_multiplier *= 1.08

		&"inertial_lattice":
			telekinetic_damage_multiplier *= 1.08

		&"projectile_reversal":
			pass

		&"quill_burst", &"shock_ram", &"tail_lash", &"arc_spear", &"bone_shard_volley", &"cinder_volley", &"blazing_stride", &"inferno_ring", &"magma_spear", &"ashen_eruption", &"kinetic_shard", &"gravity_well", &"repulse_wave", &"orbiting_debris", &"neural_lance", &"spine_launcher", &"ripper_tail", &"bone_saw", &"parasite_maw", &"blood_needle", &"acid_gland", &"jaw_reflex", &"surgical_drone", &"implosion_sac":
			pass
		_:
			if BuildItemCatalog.is_build_item(upgrade_id):
				if upgrade_id == &"galvanic_tendons":
					move_speed *= 1.04
				elif upgrade_id == &"furnace_carapace":
					move_speed *= 0.90
				elif upgrade_id == &"kiln_chamber":
					move_speed *= 0.98
				elif upgrade_id == &"grounding_filaments":
					chain_range += float(BuildItemCatalog.value(
						&"grounding_filaments",
						"range_per_level",
						12.0
					))
			else:
				upgrade_applied = false
				push_warning(
					"Koda: Unknown upgrade: %s" % upgrade_id
				)

	if not upgrade_applied:
		return

	selected_upgrade_history[upgrade_id] = true
	upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	if is_new_weapon:
		last_weapon_unlock_level = current_level
	if weapon_system != null:
		weapon_system.on_upgrade_applied(upgrade_id)
	upgrade_levels_changed.emit(upgrade_levels.duplicate())


func remove_organ_upgrade(upgrade_id: StringName) -> void:
	if get_upgrade_level(upgrade_id) <= 0:
		return

	match upgrade_id:
		&"impulse_gland":
			dash_unlocked = false
		&"arc_heart":
			chain_unlocked = false
		&"reflex_cortex", &"autonomic_reflex":
			attack_mode = AttackMode.MANUAL
			upgrade_levels.erase(&"reflex_cortex")
			upgrade_levels.erase(&"autonomic_reflex")
		&"combustion_sac":
			combustion_unlocked = false

	upgrade_levels.erase(upgrade_id)
	upgrade_levels_changed.emit(upgrade_levels.duplicate())


func has_selected_upgrade(upgrade_id: StringName) -> bool:
	return bool(selected_upgrade_history.get(upgrade_id, false))


func configure_fleshdrive(
	fleshdrive_id: StringName,
	core_level: int = 1
) -> void:
	if not FleshdriveCatalog.DEFINITIONS.has(fleshdrive_id):
		fleshdrive_id = FleshdriveCatalog.ELECTRIC
	active_fleshdrive_id = fleshdrive_id
	active_fleshdrive_level = clampi(
		core_level,
		1,
		FleshdriveCatalog.MAX_CORE_LEVEL
	)
	if not fleshdrive_configured:
		attack_damage *= 1.0 + 0.03 * float(active_fleshdrive_level - 1)
		if fleshdrive_id == FleshdriveCatalog.ELECTRIC:
			chain_damage_multiplier += (
				0.04 * float(active_fleshdrive_level - 1)
			)
		elif fleshdrive_id == FleshdriveCatalog.FIRE:
			burn_damage_multiplier += (
				0.08 * float(active_fleshdrive_level - 1)
			)
		else:
			telekinetic_damage_multiplier += (
				0.07 * float(active_fleshdrive_level - 1)
			)
			telekinetic_force_multiplier += (
				0.05 * float(active_fleshdrive_level - 1)
			)
		fleshdrive_configured = true
	_apply_fleshdrive_visuals()


func _apply_fleshdrive_visuals() -> void:
	if MinimalistVisualProfile.is_active(get_tree()):
		_apply_minimalist_presentation()
		configure_directional_animations()
		return
	if active_fleshdrive_id == FleshdriveCatalog.FIRE:
		player_light.color = Color(1.0, 0.28, 0.08, 1.0)
		player_light.energy = 2.35
	elif active_fleshdrive_id == FleshdriveCatalog.TELEKINETIC:
		player_light.color = Color(0.72, 0.42, 1.0, 1.0)
		player_light.energy = 2.28
	else:
		player_light.color = Color(0.52, 0.82, 1.0, 1.0)
		player_light.energy = 2.2
	configure_directional_animations()


func _apply_minimalist_presentation() -> void:
	player_light.hide()
	MinimalistVisualProfile.configure_shadow(
		ground_shadow,
		Vector2(2.2, 1.25),
		Vector2(-2.0, 7.0)
	)
	lightning_line.antialiased = false
	var electric_material := CanvasItemMaterial.new()
	electric_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lightning_line.material = electric_material
	lightning_line.width = 4.5
	lightning_line.default_color = Color("0ce6f2")
	lightning_glow.antialiased = false
	lightning_glow.material = electric_material
	lightning_glow.width = 11.0
	lightning_glow.default_color = Color("0098db")
	attack_range_indicator.antialiased = false


func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_character_sheet() -> Dictionary:
	return KodaStatSheet.snapshot(self)


func modify_character_stat(
	stat_id: StringName,
	multiplier: float = 1.0,
	flat_bonus: float = 0.0
) -> void:
	# Cards and abilities can use this stable API instead of reaching into UI or
	# duplicating stat names. Existing upgrades that alter the legacy backing
	# fields are reflected by the same character-sheet snapshot.
	match stat_id:
		&"max_health":
			max_health = maxf(max_health * multiplier + flat_bonus, 1.0)
			current_health = minf(current_health, max_health)
			health_changed.emit(current_health, max_health)
		&"damage": attack_damage = maxf(attack_damage * multiplier + flat_bonus, 0.0)
		&"attack_speed":
			var current_rate := 1.0 / maxf(attack_interval, 0.01)
			var next_rate := maxf(current_rate * multiplier + flat_bonus, 0.05)
			attack_interval = 1.0 / next_rate
			attack_timer.wait_time = attack_interval
		&"move_speed": move_speed = maxf(move_speed * multiplier + flat_bonus, 1.0)
		&"armor", &"lifesteal", &"critical_chance":
			var default_value := 0.05 if stat_id == &"critical_chance" else 0.0
			var current := float(get_meta(String(stat_id), default_value))
			set_meta(String(stat_id), maxf(current * multiplier + flat_bonus, 0.0))
		&"critical_damage":
			var current := float(get_meta("critical_multiplier", 1.5))
			set_meta("critical_multiplier", maxf(current * multiplier + flat_bonus, 1.0))
		&"ability_haste":
			var current_haste := maxf(1.0 / maxf(weapon_cooldown_multiplier, 0.01) - 1.0, 0.0)
			var next_haste := maxf(current_haste * multiplier + flat_bonus, 0.0)
			weapon_cooldown_multiplier = 1.0 / (1.0 + next_haste)
		&"pickup_radius":
			biomass_pickup_radius = maxf(biomass_pickup_radius * multiplier + flat_bonus, 0.0)
		_:
			push_warning("Unknown Koda character stat: %s" % stat_id)


func record_damage_source(source_id: StringName, amount: float) -> void:
	if source_id.is_empty() or amount <= 0.0:
		return
	damage_by_source[source_id] = (
		float(damage_by_source.get(source_id, 0.0)) + amount
	)


func get_combat_summary() -> Dictionary:
	var ranked_sources: Array[Dictionary] = []
	for source_id in damage_by_source:
		ranked_sources.append({
			"id": source_id,
			"damage": float(damage_by_source[source_id]),
		})
	ranked_sources.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["damage"]) > float(b["damage"])
	)
	if ranked_sources.size() > 3:
		ranked_sources.resize(3)
	var selected: Array[String] = []
	for upgrade_id in upgrade_levels:
		selected.append(
			"%s LV%d" % [
				String(upgrade_id).replace("_", " ").to_upper(),
				get_upgrade_level(upgrade_id),
			]
		)
	selected.sort()
	return {
		"damage_sources": ranked_sources,
		"selected_upgrades": selected,
	}


func get_unlocked_extra_weapon_count() -> int:
	var count := 0
	for weapon_id in EXTRA_WEAPON_IDS:
		if get_upgrade_level(weapon_id) > 0:
			count += 1
	return count


func can_unlock_weapon(upgrade_id: StringName) -> bool:
	if upgrade_id not in EXTRA_WEAPON_IDS:
		return true
	if get_upgrade_level(upgrade_id) > 0:
		return true
	if get_unlocked_extra_weapon_count() >= MAX_EXTRA_WEAPONS:
		return false
	return (
		current_level - last_weapon_unlock_level
		>= MIN_WEAPON_UNLOCK_LEVEL_GAP
	)


func apply_conductive_marrow() -> void:
	attack_damage *= 1.25


func apply_rapid_synapses() -> void:
	attack_interval = max(
		attack_interval * 0.88,
		0.15
	)

	attack_timer.wait_time = attack_interval
	attack_damage *= 0.92

func apply_predator_tendons() -> void:
	move_speed *= 1.12
	max_health = maxf(max_health * 0.95, 1.0)
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)

func apply_pulse_capacitor() -> void:
	chain_range *= 1.20

func unlock_dash() -> void:
	if dash_unlocked:
		return

	dash_unlocked = true


func refresh_attack_range() -> void:
	var circle_shape := (
		attack_range_shape.shape as CircleShape2D
	)

	if circle_shape != null:
		circle_shape.radius = attack_range

	attack_range_indicator.clear_points()

	var point_count: int = 96

	for point_index in range(point_count + 1):
		var angle := (
			TAU * float(point_index) / float(point_count)
		)

		var point := Vector2(
			cos(angle),
			sin(angle)
		) * attack_range

		attack_range_indicator.add_point(point)

	displayed_attack_range = attack_range
	
func apply_biomass_receptors() -> void:
	biomass_gain_multiplier *= 1.20


func apply_reinforced_carapace() -> void:
	max_health += 15.0
	current_health += 15.0

	health_changed.emit(
		current_health,
		max_health
	)


func apply_biomass_lure() -> void:
	biomass_pickup_radius += 60.0


func apply_overload_vent() -> void:
	weapon_cooldown_multiplier = maxf(
		weapon_cooldown_multiplier * 0.85,
		0.52
	)


func apply_reflex_spurs() -> void:
	dash_cooldown = maxf(dash_cooldown * 0.80, 0.35)
	dash_cooldown_timer.wait_time = dash_cooldown


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var missing := maxf(max_health - current_health, 0.0)
	var applied := minf(amount, missing)
	current_health += applied
	if get_upgrade_level(&"reserve_bladder") > 0 and amount > applied:
		stored_healing = minf(stored_healing + (amount - applied) * 0.50, 20.0)
	if get_upgrade_level(&"reserve_bladder") > 0 and current_health <= max_health * 0.30 and stored_healing > 0.0:
		var released := minf(stored_healing, max_health - current_health)
		current_health += released
		stored_healing -= released
	health_changed.emit(current_health, max_health)
	if applied > 0.0:
		play_attached_combat_vfx(&"holy_heal", 1.05, Vector2(0.0, -12.0))


func release_stored_healing_if_needed() -> void:
	if get_upgrade_level(&"reserve_bladder") <= 0:
		return
	if current_health > max_health * 0.30 or stored_healing <= 0.0:
		return
	var released := minf(stored_healing, max_health - current_health)
	current_health += released
	stored_healing -= released
	health_changed.emit(current_health, max_health)
	if released > 0.0:
		play_attached_combat_vfx(&"holy_heal", 1.05, Vector2(0.0, -12.0))


func register_enemy_kill(total_kills: int) -> void:
	if weapon_system != null:
		weapon_system.on_enemy_killed(total_kills)
	
func unlock_chain_lightning() -> void:
	if chain_unlocked:
		return

	chain_unlocked = true

	
func update_attack_range_indicator() -> void:
	if not is_equal_approx(
		displayed_attack_range,
		attack_range
	):
		refresh_attack_range()

	# The permanent range circle competed with combat telegraphs. Manual skills
	# provide their own short-lived aiming indicators instead.
	attack_range_indicator.visible = false

func try_semi_auto_attack() -> void:
	if not Input.is_action_pressed("attack") and attack_buffer_remaining <= 0.0:
		return

	if not attack_timer.is_stopped():
		return

	var target := find_target_near_mouse(
		semi_auto_target_radius
	)

	if target == null:
		return

	perform_attack(target)
	attack_buffer_remaining = 0.0
	attack_timer.start()


func _update_attack_cooldown_bar() -> void:
	if attack_cooldown_bar == null:
		return
	attack_cooldown_bar.visible = not is_dead and attack_mode != AttackMode.AUTO
	if not attack_cooldown_bar.visible:
		return
	var cooldown := maxf(attack_timer.wait_time, 0.01)
	var progress := (
		1.0
		if attack_timer.is_stopped()
		else clampf(1.0 - attack_timer.time_left / cooldown, 0.0, 1.0)
	)
	attack_cooldown_bar.value = progress
	attack_cooldown_bar.modulate.a = 0.58 if progress >= 0.999 else 0.92

func find_target_near_mouse(
	target_radius: float
) -> Node2D:
	var mouse_position := get_aim_world_position()
	var nearest_target: Node2D = null
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var assist := float(settings.aim_assist_strength) if settings != null else 0.35
	var effective_radius := target_radius * lerpf(0.28, 2.14, assist)
	var nearest_distance_squared := (
		effective_radius * effective_radius
	)

	for body in attack_area.get_overlapping_bodies():
		if not body.is_in_group("enemies"):
			continue

		if body.get("is_dead") == true:
			continue

		var enemy := body as Node2D

		if enemy == null:
			continue

		var distance_squared := (
			mouse_position.distance_squared_to(
				enemy.global_position
			)
		)

		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = enemy

	return nearest_target


func get_controller_aim_direction() -> Vector2:
	if not InputMap.has_action(&"aim_left"):
		return Vector2.ZERO
	var aim := Input.get_vector(
		&"aim_left", &"aim_right", &"aim_up", &"aim_down"
	)
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var sensitivity := float(settings.aim_sensitivity) if settings != null else 1.0
	return (aim * sensitivity).limit_length(1.0)


func get_aim_world_position() -> Vector2:
	var controller_aim := get_controller_aim_direction()
	if controller_aim.length() >= 0.2:
		return global_position + controller_aim.normalized() * attack_range
	return get_global_mouse_position()


func unlock_semi_auto() -> void:
	if attack_mode != AttackMode.MANUAL:
		return

	attack_mode = AttackMode.SEMI_AUTO


func unlock_auto_attack() -> void:
	# Autonomic Reflex is a complete replacement organ. It can be installed
	# after the Reflex Cortex has been moved back to the pending shelf.
	attack_mode = AttackMode.AUTO
	attack_buffer_remaining = 0.0
	attack_cooldown_bar.hide()
	attack_range_indicator.hide()


func play_sound(
	sound_id: StringName,
	volume_db: float = 0.0,
	pitch_variation: float = 0.0
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


func play_combat_vfx(
	effect_id: StringName,
	world_position: Vector2,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> AnimatedSprite2D:
	if not is_inside_tree():
		return null
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		return visual_effects.call(
			"play",
			effect_id,
			world_position,
			effect_scale,
			rotation_radians
		) as AnimatedSprite2D
	return null


func play_attached_combat_vfx(
	effect_id: StringName,
	effect_scale: float = 1.0,
	local_offset: Vector2 = Vector2.ZERO
) -> AnimatedSprite2D:
	var effect := play_combat_vfx(
		effect_id,
		global_position + local_offset,
		effect_scale
	)
	if effect == null:
		return null
	effect.reparent(self, true)
	effect.position = local_offset
	effect.z_as_relative = true
	effect.z_index = 12
	return effect
