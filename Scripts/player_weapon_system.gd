class_name PlayerWeaponSystem
extends Node2D


const ActiveSkillServiceScript := preload(
	"res://Scripts/services/active_skill_service.gd"
)

const ARC_SPEAR_PROJECTILE_SCENE := preload(
	"res://Scenes/player/arc_spear_projectile.tscn"
)
const MAGMA_SPEAR_PROJECTILE_SCENE := preload(
	"res://Scenes/player/magma_spear_projectile.tscn"
)
const PLAYER_PROJECTILES_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/player_projectiles_atlas.png"
)
const FIRE_PROJECTILES_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/fire_projectiles_atlas.png"
)
const TELEKINETIC_PROJECTILES_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/telekinetic_combat_vfx_atlas.png"
)
const WEAPON_IDS: Array[StringName] = [
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
	&"spine_launcher", &"ripper_tail", &"bone_saw", &"parasite_maw",
	&"blood_needle", &"acid_gland", &"jaw_reflex", &"surgical_drone",
	&"implosion_sac",
]

var player: Koda
var cooldowns: Dictionary = {}
var dash_was_active: bool = false
var dash_hit_ids: Dictionary = {}
var dash_build_damage_multiplier: float = 1.0
var active_burns: Dictionary = {}
var fire_trail_cooldown: float = 0.0
var reversal_check_cooldown: float = 0.0
var orbit_damage_cooldown: float = 0.0
var orbit_angle: float = 0.0
var captured_enemies: Array[Dictionary] = []
var active_gravity_wells: Array[Dictionary] = []
var capture_cycle_active: bool = false
var capture_cooldown: float = 0.0
var reversal_roll_override: float = -1.0
var active_damage_source: StringName = &""
var weapon_controllers: Array[FleshdriveWeaponController] = []
var targeting_service: TargetingService
var projectile_vfx_service: ProjectileVfxService
var combat_pipeline: Node
var balance_database: Node
var build_runtime: BuildRuntime
var magma_aim_active: bool = false
var magma_aim_indicator: Polygon2D
var magma_aim_outline: Line2D
var intrinsic_active_cooldown: float = 0.0
var active_skill_service: RefCounted
var thunder_god: ThunderGodRuntime
var orange_tempest: OrangeTempestRuntime
var volt_hound: VoltHoundRuntime
var universal_mutations: UniversalMutationRuntime


func _ready() -> void:
	player = get_parent() as Koda
	combat_pipeline = get_tree().root.get_node_or_null("CombatPipeline")
	balance_database = get_tree().root.get_node_or_null("BalanceDatabase")
	targeting_service = TargetingService.new()
	targeting_service.setup(get_tree())
	projectile_vfx_service = ProjectileVfxService.new()
	projectile_vfx_service.setup(get_tree())
	var electric := ElectricWeaponController.new()
	electric.initialize(self)
	var fire := FireWeaponController.new()
	fire.initialize(self)
	var telekinetic := TelekineticWeaponController.new()
	telekinetic.initialize(self)
	weapon_controllers.assign([electric, fire, telekinetic])
	build_runtime = BuildRuntime.new()
	build_runtime.setup(self, combat_pipeline)
	thunder_god = ThunderGodRuntime.new()
	thunder_god.setup(self, combat_pipeline)
	orange_tempest = OrangeTempestRuntime.new()
	orange_tempest.setup(self)
	volt_hound = VoltHoundRuntime.new()
	volt_hound.setup(self)
	universal_mutations = UniversalMutationRuntime.new()
	universal_mutations.setup(self)
	active_skill_service = ActiveSkillServiceScript.new()
	active_skill_service.setup(self)
	if (
		combat_pipeline != null
		and not combat_pipeline.status_ended.is_connected(
		_on_pipeline_status_ended
		)
	):
		combat_pipeline.status_ended.connect(_on_pipeline_status_ended)
	for weapon_id in WEAPON_IDS:
		cooldowns[weapon_id] = 0.0
	_install_magma_aim_indicator()


func _exit_tree() -> void:
	if build_runtime != null:
		build_runtime.shutdown()
	if thunder_god != null:
		thunder_god.shutdown()
	if orange_tempest != null:
		orange_tempest.shutdown()
	if volt_hound != null:
		volt_hound.shutdown()
	if universal_mutations != null:
		universal_mutations.shutdown()
	_release_all_captured_enemies()


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	intrinsic_active_cooldown = maxf(intrinsic_active_cooldown - delta, 0.0)

	_update_projectile_reversal(delta)
	_update_orbiting_debris(delta)
	_update_gravity_wells(delta)
	if build_runtime != null:
		build_runtime.update(delta)
	if orange_tempest != null:
		orange_tempest.update(delta)
	if volt_hound != null:
		volt_hound.update(delta)
	if thunder_god != null:
		thunder_god.update(delta)
	if universal_mutations != null:
		universal_mutations.update(delta)
	fire_trail_cooldown = maxf(fire_trail_cooldown - delta, 0.0)
	_update_dash_ram()

	for weapon_id in WEAPON_IDS:
		if weapon_id in [&"shock_ram", &"blazing_stride"]:
			continue

		var level := player.get_upgrade_level(weapon_id)
		if level <= 0:
			continue

		var remaining := maxf(float(cooldowns[weapon_id]) - delta, 0.0)
		cooldowns[weapon_id] = remaining
		if weapon_id == &"magma_spear":
			continue
		if remaining > 0.0:
			continue

		if _fire_weapon(weapon_id, level):
			cooldowns[weapon_id] = _get_cooldown(weapon_id, level)
		else:
			cooldowns[weapon_id] = 0.15
	_update_magma_aim_indicator()


func _input(event: InputEvent) -> void:
	if player == null or player.is_dead or get_tree().paused:
		return
	if active_skill_service != null and active_skill_service.handle_input(event):
		get_viewport().set_input_as_handled()


func _activate_or_aim_active_skill() -> bool:
	if (
		player.active_fleshdrive_id == FleshdriveCatalog.ELECTRIC
		and orange_tempest != null
		and orange_tempest.activate_polarity_shift()
	):
		return true
	if intrinsic_active_cooldown > 0.0:
		return false
	match player.active_fleshdrive_id:
		FleshdriveCatalog.FIRE:
			if player.get_upgrade_level(&"magma_spear") > 0:
				_toggle_magma_aim()
				return magma_aim_active
	# Repulse Wave, Inferno Ring and Voltaic Overdrive are automatic weapons.
	# Only explicitly manual weapons may consume the active-skill input.
	return false


func _fire_voltaic_overdrive() -> bool:
	var targets := _enemies_in_radius(global_position, 205.0)
	if targets.is_empty():
		return false
	for enemy in targets:
		_try_interrupt_boss(enemy, FleshdriveCatalog.ELECTRIC, 1.0)
		_damage_enemy(
			enemy,
			player.attack_damage * 1.35,
			true,
			&"voltaic_overdrive",
			DamageEvent.HitRole.SECONDARY,
			false
		)
	_play_vfx(&"electro_shock", global_position, 4.1)
	_play_sound(&"raiju_attack_spark", -3.0, 0.025)
	return true


func _toggle_magma_aim() -> void:
	if player.get_upgrade_level(&"magma_spear") <= 0:
		return
	if float(cooldowns.get(&"magma_spear", 0.0)) > 0.0:
		return
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	var next_active := not magma_aim_active
	if run_manager != null:
		if next_active and not bool(run_manager.call("enter_targeting")):
			return
		if not next_active:
			run_manager.call("exit_targeting")
	magma_aim_active = next_active
	magma_aim_indicator.visible = magma_aim_active
	magma_aim_outline.visible = magma_aim_active


func cancel_active_skill() -> void:
	if active_skill_service != null:
		active_skill_service.cancel()
	else:
		_cancel_active_skill_internal()


func _cancel_active_skill_internal() -> void:
	magma_aim_active = false
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager != null and run_manager.state == RunManager.RunState.AIMING:
		run_manager.call("exit_targeting")
	_update_magma_aim_indicator()


func _fire_aimed_magma_spear() -> void:
	var level := player.get_upgrade_level(&"magma_spear")
	if level <= 0 or float(cooldowns.get(&"magma_spear", 0.0)) > 0.0:
		magma_aim_active = false
		_update_magma_aim_indicator()
		return
	var direction := global_position.direction_to(get_global_mouse_position())
	if direction.length_squared() < 0.01:
		direction = player.last_direction
	if _fire_magma_spear_direction(direction.normalized(), level):
		cooldowns[&"magma_spear"] = _get_cooldown(&"magma_spear", level)
	magma_aim_active = false
	var run_manager := get_tree().get_first_node_in_group("run_manager")
	if run_manager != null and run_manager.state == RunManager.RunState.AIMING:
		run_manager.call("exit_targeting")
	_update_magma_aim_indicator()


func _install_magma_aim_indicator() -> void:
	magma_aim_indicator = Polygon2D.new()
	magma_aim_indicator.name = "MagmaAimShadow"
	magma_aim_indicator.color = Color(0.92, 0.055, 0.01, 0.19)
	magma_aim_indicator.z_index = -2
	magma_aim_indicator.polygon = PackedVector2Array([
		Vector2(28.0, -30.0), Vector2(720.0, -44.0),
		Vector2(720.0, 44.0), Vector2(28.0, 30.0),
	])
	add_child(magma_aim_indicator)
	magma_aim_outline = Line2D.new()
	magma_aim_outline.name = "MagmaAimOutline"
	magma_aim_outline.width = 3.0
	magma_aim_outline.default_color = Color(1.0, 0.18, 0.025, 0.65)
	magma_aim_outline.points = PackedVector2Array([
		Vector2(28.0, 0.0), Vector2(720.0, 0.0),
	])
	add_child(magma_aim_outline)
	magma_aim_indicator.hide()
	magma_aim_outline.hide()


func _update_magma_aim_indicator() -> void:
	if not is_instance_valid(magma_aim_indicator):
		return
	var visible_now := (
		magma_aim_active
		and player.get_upgrade_level(&"magma_spear") > 0
		and float(cooldowns.get(&"magma_spear", 0.0)) <= 0.0
	)
	magma_aim_indicator.visible = visible_now
	magma_aim_outline.visible = visible_now
	if visible_now:
		var direction := global_position.direction_to(get_global_mouse_position())
		if direction.length_squared() > 0.01:
			magma_aim_indicator.rotation = direction.angle()
			magma_aim_outline.rotation = direction.angle()


func get_magma_spear_status() -> Dictionary:
	var cooldown := float(cooldowns.get(&"magma_spear", 0.0))
	var level := player.get_upgrade_level(&"magma_spear") if player != null else 0
	return {
		"unlocked": level > 0,
		"aiming": magma_aim_active,
		"ready": level > 0 and cooldown <= 0.0,
		"cooldown": cooldown,
		"max_cooldown": _get_cooldown(&"magma_spear", maxi(level, 1)),
	}


func get_active_skill_status() -> Dictionary:
	return active_skill_service.get_status() if active_skill_service != null else _build_active_skill_status()


func _build_active_skill_status() -> Dictionary:
	var affinity := player.active_fleshdrive_id if player != null else FleshdriveCatalog.ELECTRIC
	if (
		affinity == FleshdriveCatalog.ELECTRIC
		and player.get_upgrade_level(&"polarity_shift") > 0
		and orange_tempest != null
	):
		var remaining := maxf(orange_tempest.polarity_remaining, 0.0)
		var cooldown := maxf(orange_tempest.polarity_cooldown, 0.0)
		return {
			"id": &"polarity_shift",
			"title": "POLARITY SHIFT",
			"affinity": &"electric",
			"unlocked": true,
			"aiming": false,
			"ready": not orange_tempest.orbs.is_empty() and remaining <= 0.0 and cooldown <= 0.0,
			"cooldown": maxf(remaining, cooldown),
			"max_cooldown": OrangeTempestRuntime.POLARITY_COOLDOWN,
		}
	if affinity == FleshdriveCatalog.FIRE and player.get_upgrade_level(&"magma_spear") > 0:
		var magma := get_magma_spear_status()
		magma["id"] = &"magma_spear"
		magma["title"] = "MAGMA SPEAR"
		magma["affinity"] = &"fire"
		return magma
	return {
		"id": &"",
		"title": "",
		"affinity": affinity,
		"unlocked": false,
		"aiming": false,
		"ready": false,
		"cooldown": 0.0,
		"max_cooldown": 1.0,
	}


func on_upgrade_applied(upgrade_id: StringName) -> void:
	if upgrade_id in WEAPON_IDS:
		cooldowns[upgrade_id] = 0.05


func perform_thunder_god_attack(target: Node2D) -> bool:
	return thunder_god != null and thunder_god.perform_attack(target)


func on_enemy_killed(total_kills: int) -> void:
	if universal_mutations != null:
		universal_mutations.on_enemy_killed(total_kills)
	if volt_hound != null:
		volt_hound.on_enemy_killed()
	var recycler_level := player.get_upgrade_level(&"hemo_recycler")
	if recycler_level > 0:
		var kills_per_heal := maxi(12 - (recycler_level - 1), 8)
		if total_kills % kills_per_heal == 0:
			var heal_amount := 6.0 + 2.0 * float(recycler_level - 1)
			player.heal(heal_amount)

	var switch_level := player.get_upgrade_level(&"kill_switch_nodes")
	if switch_level > 0:
		var kills_per_pulse := maxi(15 - (switch_level - 1), 11)
		if total_kills % kills_per_pulse == 0:
			_fire_kill_switch(switch_level)

	var cauterize_level := player.get_upgrade_level(&"cauterizing_blood")
	if (
		player.active_fleshdrive_id == FleshdriveCatalog.FIRE
		and cauterize_level > 0
	):
		var fire_kills_per_heal := maxi(14 - cauterize_level, 9)
		if total_kills % fire_kills_per_heal == 0:
			player.heal(4.0 + 2.0 * float(cauterize_level))


func _fire_weapon(weapon_id: StringName, level: int) -> bool:
	active_damage_source = weapon_id
	var fired := false
	if universal_mutations != null and universal_mutations.handles(weapon_id):
		fired = universal_mutations.fire(weapon_id, level)
	for controller in weapon_controllers:
		if fired:
			break
		if controller.handles(weapon_id):
			fired = controller.fire(weapon_id, level)
			break
	active_damage_source = &""
	if fired and universal_mutations != null:
		universal_mutations.on_weapon_activated(weapon_id, level)
	return fired


func _get_cooldown(weapon_id: StringName, level: int) -> float:
	var base_cooldown := 1.0
	if balance_database != null:
		base_cooldown = float(balance_database.call(
			"get_weapon_cooldown",
			weapon_id,
			level,
			1.0
		))
	var multiplier := player.weapon_cooldown_multiplier
	if universal_mutations != null:
		multiplier *= universal_mutations.cooldown_multiplier()
		if universal_mutations.handles(weapon_id):
			base_cooldown = universal_mutations.base_cooldown(weapon_id, level)
	if weapon_id == &"gravity_well" and player.get_upgrade_level(&"event_horizon_membrane") > 0:
		multiplier *= 1.30
	if weapon_id == &"repulse_wave" and player.get_upgrade_level(&"vector_mantle") > 0:
		multiplier *= 1.25
	if weapon_id == &"arc_spear" and player.get_upgrade_level(&"linear_inductor") > 0:
		multiplier *= 1.25
	if weapon_id == &"magma_spear" and player.get_upgrade_level(&"obsidian_throat") > 0:
		multiplier *= 1.35
	if weapon_id == &"orbiting_debris" and player.get_upgrade_level(&"orbit_brood_sac") > 0:
		multiplier *= 1.0
	if weapon_id == &"neural_lance" and player.get_upgrade_level(&"synaptic_rail") > 0:
		multiplier *= 1.35
	return base_cooldown * multiplier


func refund_weapon_cooldown(weapon_id: StringName, fraction: float) -> void:
	if not cooldowns.has(weapon_id):
		return
	var before := float(cooldowns[weapon_id])
	cooldowns[weapon_id] = maxf(
		before * (1.0 - clampf(fraction, 0.0, 0.95)),
		0.0
	)
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_cooldown_refund", weapon_id, before - float(cooldowns[weapon_id]))


func on_arc_projectile_finished(hit_count: int) -> void:
	if build_runtime != null:
		build_runtime.on_arc_projectile_finished(hit_count)


func play_build_vfx(
	effect_id: StringName,
	world_position: Vector2,
	scale_value: float,
	rotation_radians: float = 0.0
) -> void:
	_play_vfx(effect_id, world_position, scale_value, rotation_radians)


func play_build_sound(sound_id: StringName, volume_db: float = -9.0) -> void:
	_play_sound(sound_id, volume_db, 0.04)


func displace_enemy_for_build(enemy: Node2D, direction: Vector2, strength: float) -> void:
	_apply_knockback(enemy, direction, strength)


func _fire_orbiting_debris_proxy(_level: int) -> bool:
	return true


func _weapon_value(
	weapon_id: StringName,
	key: String,
	level: int,
	fallback: float
) -> float:
	if balance_database == null:
		return fallback
	return float(balance_database.call(
		"get_weapon_value",
		weapon_id,
		key,
		level,
		fallback
	))


func _fire_kinetic_shard(level: int) -> bool:
	var targets := _nearest_enemies(590.0, mini(1 + level, 4))
	if targets.is_empty():
		return false
	var damage_multiplier := player.telekinetic_damage_multiplier
	player.play_attack_animation(
		global_position.direction_to(targets[0].global_position)
	)
	for target in targets:
		_launch_readable_projectile(
			target, 760.0, 0, 0.18, false,
			_on_kinetic_shard_hit.bind(
				_weapon_value(&"kinetic_shard", "damage", level, 9.0) * damage_multiplier,
				_weapon_value(&"kinetic_shard", "knockback", level, 125.0) * player.telekinetic_force_multiplier
			)
		)
	_play_sound(&"telekinetic_cast", -9.0, 0.06)
	return true


func _on_kinetic_shard_hit(target: Node2D, damage: float, force: float) -> void:
	_damage_enemy(target, damage, true, &"kinetic_shard")
	_apply_knockback(target, global_position.direction_to(target.global_position), force)
	target.set_meta("telekinetically_displaced", true)
	_play_vfx(&"kinetic_impact", target.global_position, 0.72)


func _fire_gravity_well(level: int) -> bool:
	var targets := _nearest_enemies(620.0, 1)
	if targets.is_empty():
		return false
	var center := targets[0].global_position
	var radius := 135.0 + 18.0 * float(level - 1)
	var horizon := player.get_upgrade_level(&"event_horizon_membrane")
	if horizon > 0:
		radius *= 1.45
	var affected := _enemies_in_radius(center, radius)
	if affected.is_empty():
		return false
	player.play_attack_animation(global_position.direction_to(center))
	for target in affected:
		var pull_direction := target.global_position.direction_to(center)
		_damage_enemy(
			target,
			_weapon_value(
				&"gravity_well", "damage", level, 8.0
			)
			* player.telekinetic_damage_multiplier
			* (0.75 if horizon > 0 else 1.0)
		)
		_apply_knockback(
			target,
			pull_direction,
			_weapon_value(
				&"gravity_well", "knockback", level, 220.0
			) * player.telekinetic_force_multiplier
		)
		target.set_meta("telekinetically_displaced", true)
	_spawn_world_ring(
		center,
		radius,
		Color(0.72, 0.38, 1.0, 0.88),
		0.42
	)
	_play_vfx(&"gravity_well", center, radius / 48.0)
	var persistent_visual := _create_gravity_well_visual(center, radius)
	_play_sound(&"telekinetic_pulse", -8.0, 0.035)
	active_gravity_wells.append({
		"center": center,
		"radius": radius,
		"remaining": 2.0 + (1.5 if horizon > 0 else 0.0),
		"elapsed": 0.0,
		"tick": 0.25,
		"level": level,
		"refund": 0.0,
		"visual": persistent_visual,
	})
	return true


func _update_gravity_wells(delta: float) -> void:
	for index in range(active_gravity_wells.size() - 1, -1, -1):
		var well: Dictionary = active_gravity_wells[index]
		well["remaining"] = float(well["remaining"]) - delta
		well["elapsed"] = float(well["elapsed"]) + delta
		well["tick"] = float(well["tick"]) - delta
		if float(well["tick"]) <= 0.0:
			well["tick"] = 0.25
			var compression := player.get_upgrade_level(&"compression_cortex")
			var ramp := minf(float(well["elapsed"]), 4.0)
			var damage_multiplier := 1.0 + 0.03 * float(compression) * ramp
			for enemy in _enemies_in_radius(well["center"], float(well["radius"])):
				var was_alive: bool = enemy.get("is_dead") != true
				_damage_enemy(
					enemy,
					_weapon_value(&"gravity_well", "damage", int(well["level"]), 8.0)
					* 0.25 * damage_multiplier * player.telekinetic_damage_multiplier,
					false, &"gravity_well", DamageEvent.HitRole.STATUS_TICK, false
				)
				_apply_knockback(enemy, enemy.global_position.direction_to(well["center"]), 150.0)
				if was_alive and enemy.get("is_dead") == true:
					_refund_gravity_well_from_kill(well)
		if float(well["remaining"]) <= 0.0:
			var visual := well.get("visual") as Node
			if is_instance_valid(visual):
				visual.queue_free()
			active_gravity_wells.remove_at(index)
		else:
			active_gravity_wells[index] = well


func _refund_gravity_well_from_kill(well: Dictionary) -> void:
	var tidal := player.get_upgrade_level(&"tidal_ligaments")
	if tidal <= 0:
		return
	var maximum := 0.6 + 0.12 * float(tidal)
	var available := maximum - float(well.get("refund", 0.0))
	var refund := minf(0.06 * float(tidal), available)
	if refund <= 0.0:
		return
	well["refund"] = float(well.get("refund", 0.0)) + refund
	cooldowns[&"gravity_well"] = maxf(float(cooldowns.get(&"gravity_well", 0.0)) - refund, 0.0)


func _fire_repulse_wave(level: int) -> bool:
	var radius := 145.0 + 16.0 * float(level - 1)
	var targets := _enemies_in_radius(global_position, radius)
	if targets.is_empty():
		return false
	player.play_attack_animation(player.last_direction)
	for target in targets:
		_try_interrupt_boss(
			target,
			FleshdriveCatalog.TELEKINETIC,
			1.0 + 0.08 * float(level - 1)
		)
		var push_direction := global_position.direction_to(
			target.global_position
		)
		_damage_enemy(
			target,
			_weapon_value(
				&"repulse_wave", "damage", level, 10.0
			)
			* player.telekinetic_damage_multiplier
		)
		_apply_knockback(
			target,
			push_direction,
			_weapon_value(
				&"repulse_wave", "knockback", level, 540.0
			) * player.telekinetic_force_multiplier
		)
		target.set_meta("telekinetically_displaced", true)
	_play_vfx(&"repulse_wave", global_position, radius / 50.0)
	_play_sound(&"telekinetic_pulse", -7.0, 0.04)
	if build_runtime != null:
		build_runtime.activate_repulse_barrier()
	return true


func _create_gravity_well_visual(center: Vector2, radius: float) -> Node2D:
	var effects := get_tree().get_first_node_in_group("effects_container")
	if effects == null:
		effects = get_tree().current_scene
	var visual := Node2D.new()
	visual.name = "PersistentGravityWell"
	effects.add_child(visual)
	visual.global_position = center
	var ring := Line2D.new()
	ring.closed = true
	ring.width = 5.0
	ring.antialiased = true
	ring.default_color = Color(0.74, 0.30, 1.0, 0.86)
	ring.z_index = 12
	for point_index in range(49):
		var angle := TAU * float(point_index) / 48.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	visual.add_child(ring)
	var core := Polygon2D.new()
	core.color = Color(0.30, 0.04, 0.48, 0.20)
	core.polygon = ring.points
	core.z_index = 11
	visual.add_child(core)
	var tween := visual.create_tween().set_loops()
	tween.tween_property(visual, "scale", Vector2.ONE * 0.92, 0.32)
	tween.tween_property(visual, "scale", Vector2.ONE * 1.04, 0.32)
	return visual


func _fire_neural_lance(level: int) -> bool:
	var targets := _nearest_enemies(720.0, 1)
	if targets.is_empty():
		return false
	var direction := global_position.direction_to(targets[0].global_position)
	var length := 760.0 + 30.0 * float(level - 1)
	var width := 38.0
	if build_runtime != null:
		width *= build_runtime.neural_width_multiplier()
	var hit_limit := 3 + level
	var hit_targets: Array[Node2D] = []
	for enemy in _living_enemies():
		var offset := enemy.global_position - global_position
		var forward := offset.dot(direction)
		var lateral := absf(offset.cross(direction))
		if forward >= 0.0 and forward <= length and lateral <= width:
			hit_targets.append(enemy)
	hit_targets.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return global_position.distance_squared_to(a.global_position) < (
				global_position.distance_squared_to(b.global_position)
			)
	)
	if hit_targets.size() > hit_limit:
		hit_targets.resize(hit_limit)
	var base_damage := _weapon_value(&"neural_lance", "damage", level, 25.0)
	var base_force := _weapon_value(&"neural_lance", "knockback", level, 185.0)
	for target in hit_targets:
		var distance := global_position.distance_to(target.global_position)
		var build_damage: float = build_runtime.neural_damage_multiplier(distance) if build_runtime != null else 1.0
		_damage_enemy(
			target,
			base_damage * build_damage * player.telekinetic_damage_multiplier
		)
		_apply_knockback(
			target,
			direction,
			base_force * player.telekinetic_force_multiplier * (build_runtime.neural_force_multiplier() if build_runtime != null else 1.0)
		)
		target.set_meta("telekinetically_displaced", true)
		_play_vfx(&"neural_lance", target.global_position, 0.9)
	player.play_attack_animation(direction)
	_spawn_telekinetic_tracer(Vector2.ZERO, direction * length, 0.32)
	_play_sound(&"telekinetic_cast", -5.0, 0.035)
	if build_runtime != null and hit_targets.size() >= 3:
		var echo_multiplier: float = build_runtime.neural_echo_multiplier()
		if echo_multiplier > 0.0:
			var echo_timer := get_tree().create_timer(0.45)
			echo_timer.timeout.connect(
				_echo_neural_line.bind(direction, length, width, base_damage * echo_multiplier, base_force * 0.35),
				CONNECT_ONE_SHOT
			)
	return true


func _echo_neural_line(direction: Vector2, length: float, width: float, damage: float, force: float) -> void:
	if not is_inside_tree() or player == null or player.is_dead:
		return
	for enemy in _living_enemies():
		var offset := enemy.global_position - global_position
		if offset.dot(direction) < 0.0 or offset.dot(direction) > length or absf(offset.cross(direction)) > width:
			continue
		_damage_enemy(enemy, damage * player.telekinetic_damage_multiplier, true, &"thought_echo", DamageEvent.HitRole.SECONDARY, false)
		_apply_knockback(enemy, direction, force * player.telekinetic_force_multiplier)
	_spawn_telekinetic_tracer(Vector2.ZERO, direction * length, 0.22)


func _update_projectile_reversal(delta: float) -> void:
	reversal_check_cooldown = maxf(reversal_check_cooldown - delta, 0.0)
	if reversal_check_cooldown > 0.0:
		return
	reversal_check_cooldown = 0.12
	var level := player.get_upgrade_level(&"projectile_reversal")
	var barrier: bool = build_runtime != null and build_runtime.barrier_active()
	if level <= 0 and not barrier:
		return
	var reversal_chance := minf(
		0.35 + 0.08 * float(level - 1),
		0.67
	)
	var reversal_radius := 0.0
	if level > 0:
		reversal_radius = 190.0 + 30.0 * float(level)
	var barrier_radius := 0.0
	if barrier:
		barrier_radius = BuildItemCatalog.value(
			&"vector_mantle", "radius", 160.0
		)
	var radius_squared := pow(maxf(reversal_radius, barrier_radius), 2.0)
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		var projectile_2d := projectile as Node2D
		if (
			projectile_2d == null
			or global_position.distance_squared_to(
				projectile_2d.global_position
			) > radius_squared
		):
			continue
		if barrier:
			_play_vfx(&"repulse_wave", projectile_2d.global_position, 0.30)
			projectile_2d.queue_free()
			continue
		if projectile_2d.has_meta("telekinetic_reversal_checked"):
			continue
		projectile_2d.set_meta("telekinetic_reversal_checked", true)
		if _reversal_roll() > reversal_chance:
			continue
		if projectile_2d.has_method("reverse_to_nearest_enemy"):
			var reflected_damage := float(projectile_2d.get("damage"))
			if bool(projectile_2d.call(
				"reverse_to_nearest_enemy",
				1.1 + 0.2 * float(level)
			)):
				_play_vfx(
					&"repulse_wave",
					projectile_2d.global_position,
					0.42
				)
				_play_sound(&"telekinetic_impact", -10.0, 0.04)
				if build_runtime != null:
					build_runtime.on_projectile_reversed(
						projectile_2d.global_position,
						maxf(reflected_damage, 1.0)
					)


func _update_orbiting_debris(delta: float) -> void:
	var level := player.get_upgrade_level(&"orbiting_debris")
	capture_cooldown = maxf(capture_cooldown - delta, 0.0)
	if level <= 0:
		_release_all_captured_enemies()
		return
	if not captured_enemies.is_empty():
		var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
		if telemetry != null:
			telemetry.call("record_crowd_control", delta, captured_enemies.size())

	if captured_enemies.is_empty() and capture_cooldown <= 0.0:
		_capture_orbit_targets(level)

	orbit_angle = fmod(orbit_angle + delta * (2.05 + 0.10 * level), TAU)
	for capture_index in range(captured_enemies.size() - 1, -1, -1):
		var capture := captured_enemies[capture_index]
		var enemy := _get_valid_capture_enemy(capture)
		if enemy == null or enemy.get("is_dead") == true:
			_remove_capture(capture_index, false)
			continue

		var count := maxi(captured_enemies.size(), 1)
		var angle := (
			orbit_angle
			+ TAU * float(capture_index) / float(count)
		)
		var orbit_radius := (
			92.0
			+ 7.0 * float(level - 1)
			+ 10.0 * float(capture_index % 2)
		)
		if build_runtime != null:
			orbit_radius *= build_runtime.orbit_radius_multiplier()
		var orbit_target := (
			global_position
			+ Vector2.from_angle(angle) * orbit_radius
		)
		if StringName(capture.get("phase", &"pulling")) == &"pulling":
			_pull_capture_toward_orbit(
				enemy,
				orbit_target,
				delta
			)
			var tether_pull := capture.get("tether") as Line2D
			if is_instance_valid(tether_pull):
				tether_pull.points = PackedVector2Array([
					Vector2.ZERO,
					to_local(enemy.global_position),
				])
				tether_pull.modulate.a = 0.42
			var radial_distance := enemy.global_position.distance_to(
				global_position
			)
			if (
				enemy.global_position.distance_to(orbit_target) <= 30.0
				or absf(radial_distance - orbit_radius) <= 34.0
			):
				_activate_capture(enemy, capture)
				capture["phase"] = &"orbiting"
			captured_enemies[capture_index] = capture
			if StringName(capture["phase"]) == &"pulling":
				continue

		# Captivity is health-driven rather than duration-driven: the held
		# creature loses exactly 2 HP per second until it dies.
		var drain_accumulator: float = (
			float(capture.get("drain_accumulator", 0.0))
			+ delta * 2.0 / (build_runtime.orbit_duration_multiplier() if build_runtime != null else 1.0)
		)
		var drain_damage := floori(drain_accumulator)
		if drain_damage > 0:
			drain_accumulator -= float(drain_damage)
			_damage_enemy(
				enemy,
				float(drain_damage),
				false,
				&"orbiting_debris"
			)
		capture["drain_accumulator"] = drain_accumulator
		captured_enemies[capture_index] = capture
		if enemy.get("is_dead") == true:
			_remove_capture(capture_index, false)
			continue
		var fold_level := player.get_upgrade_level(&"execution_fold")
		var current_hp := float(enemy.get("current_health"))
		var maximum_hp := float(enemy.get("max_health"))
		if fold_level > 0 and maximum_hp > 0.0 and current_hp / maximum_hp <= 0.20:
			var fold_center := enemy.global_position
			_remove_capture(capture_index, false)
			for fold_target in _enemies_in_radius(fold_center, 130.0):
				_damage_enemy(fold_target, player.attack_damage * (0.70 + 0.20 * float(fold_level)), true, &"execution_fold", DamageEvent.HitRole.SECONDARY, false)
			_play_vfx(&"gravity_well", fold_center, 1.25)
			continue

		enemy.global_position = (
			enemy.global_position.lerp(
				orbit_target,
				clampf(delta * 14.0, 0.0, 1.0)
			)
		)
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).velocity = Vector2.ZERO
		var tether := capture.get("tether") as Line2D
		if is_instance_valid(tether):
			tether.points = PackedVector2Array([
				Vector2.ZERO,
				to_local(enemy.global_position),
			])
			tether.modulate.a = (
				0.72 + sin(orbit_angle * 3.0 + capture_index) * 0.24
			)

	orbit_damage_cooldown = maxf(orbit_damage_cooldown - delta, 0.0)
	if orbit_damage_cooldown > 0.0:
		_finish_capture_cycle_if_empty(level)
		return
	orbit_damage_cooldown = maxf(0.38 - 0.025 * float(level - 1), 0.26)
	var captured_snapshot := captured_enemies.duplicate()
	for capture in captured_snapshot:
		var captive := _get_valid_capture_enemy(capture)
		if captive == null:
			continue
		for target in _enemies_in_radius(captive.global_position, 58.0):
			if target == captive or _is_enemy_captured(target):
				continue
			_damage_enemy(
				target,
				(6.0 + 2.2 * float(level - 1))
				* player.telekinetic_damage_multiplier
				* (build_runtime.orbit_collision_multiplier() if build_runtime != null else 1.0),
				false,
				&"orbiting_debris"
			)
			_apply_knockback(
				target,
				captive.global_position.direction_to(target.global_position),
				95.0 * player.telekinetic_force_multiplier
			)
			target.set_meta("telekinetically_displaced", true)
			_play_vfx(&"kinetic_impact", target.global_position, 0.48)
		_play_vfx(&"kinetic_impact", captive.global_position, 0.34)
	_finish_capture_cycle_if_empty(level)


func _capture_orbit_targets(level: int) -> void:
	var capacity := 1 + int((level - 1) / 2.0)
	if build_runtime != null:
		capacity += build_runtime.orbit_capacity_bonus()
	var capture_range := (
		330.0 + 35.0 * float(level - 1)
	)
	var candidates := _nearest_enemies(capture_range, capacity * 3)
	for enemy in candidates:
		if captured_enemies.size() >= capacity:
			break
		if enemy.is_in_group("boss") or _is_enemy_captured(enemy):
			continue
		_capture_enemy(enemy, level)
	if captured_enemies.is_empty():
		capture_cooldown = 0.45
		return
	capture_cycle_active = true
	var first_enemy := _get_valid_capture_enemy(captured_enemies[0])
	if first_enemy != null:
		player.play_attack_animation(
			global_position.direction_to(first_enemy.global_position)
		)
	_play_vfx(&"gravity_well", global_position, 1.7)
	_play_sound(&"telekinetic_pulse", -6.0, 0.035)


func _capture_enemy(enemy: Node2D, level: int) -> void:
	var tether := Line2D.new()
	tether.name = "KineticTether"
	tether.width = 4.5
	tether.default_color = Color(0.84, 0.62, 1.0, 0.94)
	tether.antialiased = true
	tether.z_as_relative = false
	tether.z_index = 62
	tether.show_behind_parent = false
	add_child(tether)

	var collision_layer_value := 0
	var collision_mask_value := 0
	if enemy is CollisionObject2D:
		var collision_object := enemy as CollisionObject2D
		collision_layer_value = collision_object.collision_layer
		collision_mask_value = collision_object.collision_mask
	var capture := {
		"enemy": enemy,
		"phase": &"pulling",
		"drain_accumulator": 0.0,
		"physics_processing": enemy.is_physics_processing(),
		"collision_layer": collision_layer_value,
		"collision_mask": collision_mask_value,
		"original_modulate": enemy.modulate,
		"tether": tether,
	}
	enemy.set_meta("telekinetically_captured", true)
	enemy.modulate = Color(0.88, 0.72, 1.0, 1.0)
	captured_enemies.append(capture)


func _pull_capture_toward_orbit(
	enemy: Node2D,
	orbit_target: Vector2,
	delta: float
) -> void:
	var offset := orbit_target - enemy.global_position
	var distance := offset.length()
	if distance <= 1.0:
		return
	var pull_speed := clampf(300.0 + distance * 2.25, 360.0, 980.0)
	var desired_velocity := offset.normalized() * pull_speed
	if enemy.has_method("apply_external_impulse"):
		enemy.call(
			"apply_external_impulse",
			desired_velocity * clampf(delta * 5.5, 0.18, 0.72)
		)
	elif enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = desired_velocity
	else:
		enemy.global_position = enemy.global_position.move_toward(
			orbit_target,
			pull_speed * delta
		)


func _activate_capture(enemy: Node2D, capture: Dictionary) -> void:
	enemy.set_physics_process(false)
	if enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = Vector2.ZERO
	if enemy is CollisionObject2D:
		var collision_object := enemy as CollisionObject2D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0


func _remove_capture(capture_index: int, execute_enemy: bool) -> void:
	if capture_index < 0 or capture_index >= captured_enemies.size():
		return
	var capture := captured_enemies[capture_index]
	captured_enemies.remove_at(capture_index)
	var tether := capture.get("tether") as Line2D
	if is_instance_valid(tether):
		tether.queue_free()
	var enemy := _get_valid_capture_enemy(capture)
	if enemy == null:
		return
	enemy.remove_meta("telekinetically_captured")
	if enemy.get("is_dead") == true:
		return
	if execute_enemy:
		_damage_enemy(
			enemy,
			1000000.0,
			true,
			&"orbiting_debris"
		)
		_play_vfx(&"repulse_wave", enemy.global_position, 0.65)
		return
	_restore_captured_enemy(enemy, capture)


func _get_valid_capture_enemy(capture: Dictionary) -> Node2D:
	# Casting a previously freed Object raises an error before a subsequent
	# is_instance_valid() check can run. Validate the untyped Variant first.
	var enemy_value: Variant = capture.get("enemy")
	if not is_instance_valid(enemy_value):
		return null
	if not enemy_value is Node2D:
		return null
	return enemy_value as Node2D


func _restore_captured_enemy(enemy: Node2D, capture: Dictionary) -> void:
	enemy.modulate = capture.get("original_modulate", Color.WHITE)
	enemy.set_physics_process(bool(capture.get("physics_processing", true)))
	if enemy is CollisionObject2D:
		var collision_object := enemy as CollisionObject2D
		collision_object.collision_layer = int(capture.get("collision_layer", 0))
		collision_object.collision_mask = int(capture.get("collision_mask", 0))


func _release_all_captured_enemies() -> void:
	for capture_index in range(captured_enemies.size() - 1, -1, -1):
		_remove_capture(capture_index, false)
	capture_cycle_active = false


func _finish_capture_cycle_if_empty(_level: int) -> void:
	if not capture_cycle_active or not captured_enemies.is_empty():
		return
	capture_cycle_active = false
	capture_cooldown = 5.0 + (2.0 if player.get_upgrade_level(&"orbit_brood_sac") > 0 else 0.0)


func _is_enemy_captured(enemy: Node2D) -> bool:
	return bool(enemy.get_meta("telekinetically_captured", false))


func _reversal_roll() -> float:
	if reversal_roll_override >= 0.0:
		return clampf(reversal_roll_override, 0.0, 1.0)
	return randf()


func _spawn_telekinetic_tracer(
	from: Vector2,
	to: Vector2,
	duration: float
) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_effect")):
		return
	var tracer := AnimatedSprite2D.new()
	tracer.sprite_frames = _make_telekinetic_projectile_frames()
	tracer.animation = &"flight"
	tracer.position = from
	tracer.rotation = from.direction_to(to).angle()
	tracer.scale = Vector2.ONE * 0.34
	tracer.z_index = 18
	tracer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(tracer)
	tracer.play(&"flight")
	var tween := tracer.create_tween()
	tween.tween_property(tracer, "position", to, duration)
	tween.tween_callback(tracer.queue_free)


func _make_telekinetic_projectile_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"flight")
	frames.set_animation_loop(&"flight", true)
	frames.set_animation_speed(&"flight", 18.0)
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = TELEKINETIC_PROJECTILES_TEXTURE
		frame.region = Rect2(frame_index * 256, 0, 256, 256)
		frames.add_frame(&"flight", frame)
	return frames


func _fire_cinder_volley(level: int) -> bool:
	var targets := _nearest_enemies(
		470.0 + 18.0 * float(level - 1),
		2 + level
	)
	if targets.is_empty():
		return false
	player.play_attack_animation(
		global_position.direction_to(targets[0].global_position)
	)
	for target in targets:
		var damage := _weapon_value(
			&"cinder_volley", "damage", level, 5.0
		)
		_launch_readable_projectile(
			target, 610.0, 0, 0.42, true,
			_on_cinder_projectile_hit.bind(
				damage, 2.4 + 1.0 * float(level - 1)
			)
		)
	return true


func _on_cinder_projectile_hit(target: Node2D, damage: float, burn: float) -> void:
	_damage_enemy(target, damage, true, &"cinder_volley")
	apply_burn(target, burn, 4.0, 1)
	_play_vfx(&"fire_impact", target.global_position, 0.62)


func _fire_inferno_ring(level: int) -> bool:
	var radius := 145.0 + 16.0 * float(level - 1)
	var targets := _enemies_in_radius(global_position, radius)
	if targets.is_empty():
		return false
	player.play_attack_animation(player.last_direction)
	for target in targets:
		_try_interrupt_boss(
			target,
			FleshdriveCatalog.FIRE,
			0.9 + 0.06 * float(level - 1)
		)
		_damage_enemy(target, _weapon_value(
			&"inferno_ring", "damage", level, 7.0
		))
		apply_burn(
			target,
			3.0 + 1.1 * float(level - 1),
			4.5,
			2
		)
		if build_runtime != null:
			build_runtime.on_inferno_ring_hit(target)
	if build_runtime != null:
		build_runtime.on_inferno_ring_cast(targets)
	_play_vfx(&"inferno_ring", global_position, radius / 52.0)
	return true


func _try_interrupt_boss(
	target: Node2D,
	affinity: StringName,
	force: float
) -> bool:
	if (
		not is_instance_valid(target)
		or not target.has_method("interrupt_active_attack")
	):
		return false
	return bool(target.call("interrupt_active_attack", affinity, force))


func _fire_magma_spear(level: int) -> bool:
	# Magma Spear is intentionally manual. E enters aim mode and right mouse
	# confirms the shot; the weapon loop must never auto-cast it.
	return false


func _fire_magma_spear_direction(direction: Vector2, level: int) -> bool:
	var range_value := 660.0 + 25.0 * float(level - 1)
	var damage_multiplier := 1.0
	if build_runtime != null:
		range_value *= build_runtime.magma_range_multiplier()
		damage_multiplier = build_runtime.magma_damage_multiplier()
	var container := get_tree().get_first_node_in_group("attack_container")
	if container == null:
		return false
	var spear := MAGMA_SPEAR_PROJECTILE_SCENE.instantiate() as MagmaSpearProjectile
	if spear == null:
		return false
	container.add_child(spear)
	spear.global_position = global_position + direction * 46.0
	spear.configure(
		direction,
		_weapon_value(&"magma_spear", "damage", level, 18.0) * damage_multiplier,
		4.0 + 1.4 * float(level - 1),
		5.0,
		range_value,
		self
	)
	player.play_attack_animation(direction)
	_play_vfx(
		&"fire_muzzle",
		global_position + direction * 30.0,
		0.85,
		direction.angle()
	)
	if player.get_upgrade_level(&"obsidian_throat") > 0:
		_spawn_magma_lane(direction, range_value, level)
	return true


func play_projectile_impact(
	effect_id: StringName,
	world_position: Vector2,
	scale_multiplier: float = 1.0
) -> void:
	_play_vfx(effect_id, world_position, scale_multiplier)


func _spawn_magma_lane(direction: Vector2, range_value: float, level: int) -> void:
	var lane := Line2D.new()
	lane.width = 42.0
	lane.default_color = Color(1.0, 0.20, 0.02, 0.42)
	lane.points = PackedVector2Array([Vector2.ZERO, direction * range_value])
	lane.z_index = 7
	add_child(lane)
	var elapsed := 0.0
	var tick := 0.0
	while elapsed < 3.0 and is_instance_valid(lane) and is_inside_tree():
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		tick -= delta
		if tick > 0.0:
			continue
		tick = 0.5
		for enemy in _living_enemies():
			var offset := enemy.global_position - global_position
			if offset.dot(direction) >= 0.0 and offset.dot(direction) <= range_value and absf(offset.cross(direction)) <= 32.0:
				_damage_enemy(enemy, player.attack_damage * 0.11, false, &"obsidian_throat", DamageEvent.HitRole.SECONDARY, false)
				apply_burn(enemy, 2.0 + 0.4 * float(level), 2.0, 1)
	if is_instance_valid(lane):
		lane.queue_free()


func _fire_ashen_eruption(level: int) -> bool:
	var targets := _nearest_enemies(560.0, 1)
	if targets.is_empty():
		return false
	var center := targets[0].global_position
	var radius := 96.0 + 14.0 * float(level - 1)
	player.play_attack_animation(global_position.direction_to(center))
	for target in _enemies_in_radius(center, radius):
		_damage_enemy(target, _weapon_value(
			&"ashen_eruption", "damage", level, 12.0
		))
		apply_burn(
			target,
			3.2 + 1.2 * float(level - 1),
			4.2,
			2
		)
	_play_vfx(&"ashen_eruption", center, radius / 44.0)
	return true


func _fire_quill_burst(level: int) -> bool:
	var targets := _nearest_enemies(
		430.0 + 18.0 * float(level - 1),
		2 + level + (build_runtime.quill_projectile_count_bonus() if build_runtime != null else 0)
	)
	if targets.is_empty():
		return false

	player.play_attack_animation(
		global_position.direction_to(targets[0].global_position)
	)
	var damage := _weapon_value(
		&"quill_burst", "damage", level, 8.0
	)
	if build_runtime != null:
		damage *= build_runtime.quill_damage_multiplier()
	for target in targets:
		_launch_readable_projectile(
			target, 860.0, 1, 0.16, false,
			_on_quill_projectile_hit.bind(damage)
		)
	return true


func _on_quill_projectile_hit(target: Node2D, damage: float) -> void:
	_damage_enemy(target, damage, true, &"quill_burst")
	if build_runtime != null:
		build_runtime.on_quill_impact(target, damage)
	_play_vfx(&"electric_impact", target.global_position, 0.85)


func _fire_tail_lash(level: int) -> bool:
	var radius := 125.0 + 14.0 * float(level - 1)
	var targets := _enemies_in_radius(global_position, radius)
	if targets.is_empty():
		return false

	player.play_attack_animation(player.last_direction)
	var damage := _weapon_value(
		&"tail_lash", "damage", level, 18.0
	)
	for target in targets:
		_damage_enemy(target, damage)
		var push_direction := global_position.direction_to(target.global_position)
		_apply_knockback(
			target,
			push_direction,
			_weapon_value(&"tail_lash", "knockback", level, 175.0)
		)
	_play_vfx(
		&"slash_heavy",
		global_position,
		radius / 82.0,
		randf_range(-0.3, 0.3)
	)
	return true


func _fire_arc_spear(level: int) -> bool:
	var targets := _nearest_enemies(620.0, 1)
	if targets.is_empty():
		return false
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(
		budget.call("allow_player_projectile")
	):
		return false

	var direction := global_position.direction_to(targets[0].global_position)
	var length := 650.0 + 25.0 * float(level - 1)
	var damage := _weapon_value(
		&"arc_spear", "damage", level, 22.0
	)
	var speed_multiplier := 1.0
	var width_multiplier := 1.0
	if build_runtime != null:
		length *= build_runtime.arc_range_multiplier()
		damage *= build_runtime.arc_damage_multiplier()
		speed_multiplier = build_runtime.arc_speed_multiplier()
		width_multiplier = build_runtime.arc_width_multiplier()
	var projectile := (
		ARC_SPEAR_PROJECTILE_SCENE.instantiate()
		as ArcSpearProjectile
	)
	var container := get_tree().get_first_node_in_group("attack_container")
	if projectile == null or container == null:
		return false

	player.play_attack_animation(direction)
	container.add_child(projectile)
	projectile.global_position = global_position + direction * 34.0
	projectile.configure(
		direction,
		damage,
		length,
		1 + level,
		self,
		speed_multiplier,
		width_multiplier
	)
	_play_vfx(
		&"arc_muzzle",
		global_position + direction * 30.0,
		0.85,
		direction.angle()
	)
	return true


func _fire_bone_shard_volley(level: int) -> bool:
	var direction := player.last_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var range_value := 360.0 + 18.0 * float(level - 1)
	var half_angle := deg_to_rad(36.0 + 3.0 * float(level - 1))
	var damage := _weapon_value(
		&"bone_shard_volley", "damage", level, 12.0
	)
	var targets: Array[Node2D] = []

	for enemy in _living_enemies():
		var offset := enemy.global_position - global_position
		if offset.length_squared() > range_value * range_value:
			continue
		if absf(direction.angle_to(offset.normalized())) > half_angle:
			continue
		targets.append(enemy)

	if targets.is_empty():
		return false

	player.play_attack_animation(direction)
	# Each selected target receives a visible travelling shard.  Damage is
	# applied only on impact, so the fan remains readable instead of resolving
	# as an unexplained instant cone hit.
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	var projectile_count := mini(targets.size(), 5 + level)
	for target_index in range(projectile_count):
		_launch_readable_projectile(
			targets[target_index], 720.0, 2, 0.14, false,
			_on_bone_shard_hit.bind(damage)
		)
	return true


func _on_bone_shard_hit(target: Node2D, damage: float) -> void:
	_damage_enemy(target, damage, false, &"bone_shard_volley")
	_play_vfx(&"kinetic_impact", target.global_position, 0.72)


func _update_dash_ram() -> void:
	if player.active_fleshdrive_id == FleshdriveCatalog.FIRE:
		_update_blazing_stride()
		return
	var level := player.get_upgrade_level(&"shock_ram")
	if level <= 0:
		dash_was_active = player.is_dashing
		return

	if player.is_dashing and not dash_was_active:
		dash_hit_ids.clear()
		dash_build_damage_multiplier = (
			build_runtime.shock_ram_damage_multiplier()
			if build_runtime != null else 1.0
		)

	if player.is_dashing:
		var damage := 16.0 + 6.0 * float(level - 1)
		var radius := 68.0 + 6.0 * float(level - 1)
		if build_runtime != null:
			damage *= dash_build_damage_multiplier
			radius *= build_runtime.shock_ram_radius_multiplier()
		for enemy in _enemies_in_radius(global_position, radius):
			var enemy_id := enemy.get_instance_id()
			if dash_hit_ids.has(enemy_id):
				continue
			dash_hit_ids[enemy_id] = true
			_damage_enemy(enemy, damage, true, &"shock_ram")
			_apply_knockback(enemy, player.dash_direction, 320.0 + 35.0 * level)
			_play_vfx(&"electric_impact", enemy.global_position, 2.0)

	if dash_was_active and not player.is_dashing and build_runtime != null:
		build_runtime.on_dash_finished(dash_hit_ids.size())
	dash_was_active = player.is_dashing


func _update_blazing_stride() -> void:
	var level := player.get_upgrade_level(&"blazing_stride")
	if level <= 0:
		dash_was_active = player.is_dashing
		return
	if player.is_dashing and not dash_was_active:
		dash_hit_ids.clear()
	if player.is_dashing:
		if fire_trail_cooldown <= 0.0:
			_spawn_blazing_stride_zone(
				global_position,
				68.0 + 5.0 * level,
				level
			)
			fire_trail_cooldown = 0.20
		for enemy in _enemies_in_radius(global_position, 74.0 + 5.0 * level):
			var enemy_id := enemy.get_instance_id()
			if dash_hit_ids.has(enemy_id):
				continue
			dash_hit_ids[enemy_id] = true
			_damage_enemy(
				enemy,
				8.0 + 4.0 * float(level - 1),
				true,
				&"blazing_stride"
			)
			apply_burn(
				enemy,
				3.0 + float(level),
				4.0,
				2
			)
	dash_was_active = player.is_dashing


func _spawn_blazing_stride_zone(
	world_position: Vector2,
	radius: float,
	level: int
) -> void:
	var container := get_tree().get_first_node_in_group("attack_container")
	if container == null:
		return
	var zone := Polygon2D.new()
	zone.name = "BlazingStrideZone"
	zone.z_index = 4
	zone.color = Color(1.0, 0.12, 0.015, 0.30)
	var points := PackedVector2Array()
	for point_index in range(25):
		var angle := TAU * float(point_index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	zone.polygon = points
	container.add_child(zone)
	zone.global_position = world_position
	_play_vfx(&"burning_ground", world_position, radius / 62.0)
	_play_vfx(&"fire_explosion_embers", world_position, radius / 74.0)
	var pulse := zone.create_tween().set_loops()
	pulse.tween_property(zone, "modulate:a", 0.55, 0.32)
	pulse.tween_property(zone, "modulate:a", 0.92, 0.32)
	var elapsed := 0.0
	var tick := 0.0
	var duration := 2.4 + 0.15 * float(level - 1)
	while elapsed < duration and is_instance_valid(zone) and is_inside_tree():
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		tick -= delta
		if tick > 0.0:
			continue
		tick = 0.40
		for enemy in _enemies_in_radius(world_position, radius):
			_damage_enemy(
				enemy,
				2.0 + 0.8 * float(level),
				false,
				&"blazing_stride",
				DamageEvent.HitRole.SECONDARY,
				false
			)
			apply_burn(enemy, 2.0 + 0.5 * float(level), 1.4, 1)
	if is_instance_valid(zone):
		pulse.kill()
		var fade := zone.create_tween()
		fade.tween_property(zone, "modulate:a", 0.0, 0.24)
		fade.tween_callback(zone.queue_free)


func apply_burn(
	enemy: Node2D,
	damage_per_second: float,
	duration: float,
	stack_gain: int = 1
) -> void:
	if not is_instance_valid(enemy):
		return
	var flashpoint_level := player.get_upgrade_level(&"flashpoint_nodes")
	if combat_pipeline == null:
		return
	combat_pipeline.call(
		"apply_status",
		enemy,
		{
			"id": &"burn",
			"duration": duration * player.burn_duration_multiplier * (build_runtime.burn_duration_multiplier() if build_runtime != null else 1.0),
			"tick_interval": 0.5 / (build_runtime.burn_tick_multiplier(enemy.global_position) if build_runtime != null else 1.0),
			"damage_per_second": (
				damage_per_second * player.burn_damage_multiplier
			),
			"stack_gain": stack_gain,
			"max_stacks": 5,
			"affinity": FleshdriveCatalog.FIRE,
			"context": {
				"flashpoint_level": flashpoint_level,
				"combusted": false,
			},
		},
		player,
		&"burn"
	)
	var burn := Dictionary(combat_pipeline.call(
		"get_status",
		enemy,
		&"burn"
	))
	if (
		player.combustion_unlocked
		and int(burn.get("stacks", 0)) >= 3
		and not bool(
			Dictionary(burn.get("context", {})).get("combusted", false)
		)
	):
		var consumed_stacks := int(burn.get("stacks", 0))
		var rupture_level := player.get_upgrade_level(&"rupture_vesicle")
		if rupture_level > 0:
			consumed_stacks = int(combat_pipeline.call(
				"consume_status_stacks", enemy, &"burn", -1
			))
		combat_pipeline.call(
			"set_status_context_value",
			enemy,
			&"burn",
			&"combusted",
			true
		)
		_fire_burn_explosion(
			enemy.global_position,
			maxi(player.get_upgrade_level(&"combustion_sac"), 1),
			rupture_level <= 0,
			1.0 + 0.35 * float(consumed_stacks) if rupture_level > 0 else 1.0
		)


func _on_pipeline_status_ended(
	target_position: Vector2,
	status_id: StringName,
	context: Dictionary,
	reason: StringName
) -> void:
	if status_id != &"burn" or reason != &"killed":
		return
	var flashpoint_level := int(context.get("flashpoint_level", 0))
	if flashpoint_level > 0:
		_fire_burn_explosion(
			target_position,
			flashpoint_level,
			false
		)


func _update_burns(delta: float) -> void:
	for enemy_id in active_burns.keys():
		var burn: Dictionary = active_burns[enemy_id]
		var enemy_ref := burn.get("enemy_ref") as WeakRef
		var enemy: Node2D = null
		if enemy_ref != null:
			enemy = enemy_ref.get_ref() as Node2D
		if enemy == null or not is_instance_valid(enemy):
			active_burns.erase(enemy_id)
			continue
		burn["last_position"] = enemy.global_position
		if enemy.get("is_dead") == true:
			var flashpoint_level := player.get_upgrade_level(
				&"flashpoint_nodes"
			)
			if flashpoint_level > 0:
				_fire_burn_explosion(
					enemy.global_position,
					flashpoint_level,
					false
				)
			active_burns.erase(enemy_id)
			continue
		burn["remaining"] = float(burn["remaining"]) - delta
		burn["tick"] = float(burn["tick"]) - delta
		if float(burn["tick"]) <= 0.0:
			burn["tick"] = 0.5
			_damage_enemy(
				enemy,
				float(burn["dps"]) * 0.5 * float(burn["stacks"]),
				false,
				&"burn"
			)
			_play_vfx(&"fire_impact", enemy.global_position, 0.36)
		if (
			player.combustion_unlocked
			and int(burn["stacks"]) >= 3
			and not bool(burn["combusted"])
		):
			burn["combusted"] = true
			_fire_burn_explosion(
				enemy.global_position,
				maxi(player.get_upgrade_level(&"combustion_sac"), 1),
				true
			)
		if float(burn["remaining"]) <= 0.0:
			active_burns.erase(enemy_id)
		else:
			active_burns[enemy_id] = burn


func _fire_burn_explosion(
	center: Vector2,
	level: int,
	apply_secondary_burn: bool,
	damage_multiplier: float = 1.0,
	proc_context: ProcContext = null
) -> void:
	var radius := 86.0 + 10.0 * float(level - 1)
	if build_runtime != null:
		radius = build_runtime.fire_explosion_radius(radius)
	var source_id: StringName = (
		&"combustion_sac"
		if apply_secondary_burn
		else &"flashpoint_nodes"
	)
	for target in _enemies_in_radius(center, radius):
		_damage_enemy(
			target,
			(8.0 + 4.0 * float(level)) * damage_multiplier,
			true,
			source_id,
			DamageEvent.HitRole.SECONDARY,
			true,
			proc_context
		)
		if apply_secondary_burn:
			apply_burn(
				target,
				1.8 + 0.7 * float(level),
				3.0,
				1
			)
	_play_vfx(&"ashen_eruption", center, radius / 48.0)
	_play_vfx(
		&"fire_explosion_spiked" if apply_secondary_burn else &"fire_explosion_ring",
		center,
		radius / 76.0
	)


func _fire_kill_switch(level: int) -> void:
	var radius := 260.0 + 25.0 * float(level - 1)
	var damage := player.attack_damage * (
		1.65 + 0.25 * float(level - 1)
	)
	for enemy in _enemies_in_radius(global_position, radius):
		_damage_enemy(enemy, damage, true, &"kill_switch_nodes")
	_play_vfx(&"electro_shock", global_position, radius / 52.0)


func _living_enemies() -> Array[Node2D]:
	return targeting_service.living_enemies()


func living_enemies_for_build() -> Array[Node2D]:
	return _living_enemies()


func nearest_enemies_for_build(
	center: Vector2,
	radius: float,
	limit: int
) -> Array[Node2D]:
	return targeting_service.nearest(center, radius, limit)


func enemies_in_radius_for_build(
	center: Vector2,
	radius: float
) -> Array[Node2D]:
	return _enemies_in_radius(center, radius)


func damage_enemy_for_build(
	enemy: Node2D,
	amount: float,
	source_id: StringName,
	hit_role: DamageEvent.HitRole = DamageEvent.HitRole.SECONDARY,
	can_trigger_procs: bool = false,
	proc_context: ProcContext = null
) -> void:
	_damage_enemy(
		enemy, amount, true, source_id, hit_role,
		can_trigger_procs, proc_context
	)


func notify_player_damaged(amount: float = 0.0) -> void:
	if volt_hound != null:
		volt_hound.on_player_damaged()
	if universal_mutations != null:
		universal_mutations.on_player_damaged(amount)


func universal_movement_multiplier() -> float:
	return universal_mutations.movement_multiplier() if universal_mutations != null else 1.0


func universal_modify_incoming_damage(amount: float) -> float:
	return universal_mutations.modify_incoming_damage(amount) if universal_mutations != null else amount


func notify_biomass_collected() -> void:
	if universal_mutations != null:
		universal_mutations.on_biomass_collected()


func notify_dash_finished() -> void:
	if universal_mutations != null:
		universal_mutations.on_dash_finished()


func volt_hound_movement_multiplier() -> float:
	return volt_hound.movement_multiplier() if volt_hound != null else 1.0


func volt_hound_dash_speed_multiplier() -> float:
	return volt_hound.dash_speed_multiplier() if volt_hound != null else 1.0


func volt_hound_dash_cooldown_multiplier() -> float:
	return volt_hound.dash_cooldown_multiplier() if volt_hound != null else 1.0


func volt_hound_modify_incoming_damage(event: DamageEvent, amount: float) -> float:
	return volt_hound.modify_incoming_damage(event, amount) if volt_hound != null else amount


func emit_static_reservoir(center: Vector2, damage: float) -> void:
	for enemy in _enemies_in_radius(center, 180.0):
		_damage_enemy(enemy, damage, true, &"static_reservoir", DamageEvent.HitRole.SECONDARY, false)
	_play_vfx(&"static_strike", center, 1.45)
	_play_vfx(&"electro_shock", center, 2.2)


func emit_dash_aftershock(damage: float) -> void:
	for enemy in _enemies_in_radius(global_position, 120.0):
		_damage_enemy(enemy, damage, true, &"thunder_gait", DamageEvent.HitRole.SECONDARY, false)
	_play_vfx(&"electro_shock", global_position, 2.2)


func emit_reactive_repulse(damage_multiplier: float) -> void:
	var radius := 145.0
	for enemy in _enemies_in_radius(global_position, radius):
		_damage_enemy(enemy, player.attack_damage * damage_multiplier, true, &"reactive_cranium", DamageEvent.HitRole.SECONDARY, false)
		_apply_knockback(enemy, global_position.direction_to(enemy.global_position), 420.0)
	_play_vfx(&"repulse_wave", global_position, radius / 50.0)


func emit_chain_igniter(center: Vector2, context: ProcContext) -> void:
	_fire_burn_explosion(center, maxi(player.get_upgrade_level(&"chain_igniter"), 1), false, 0.60, context)


func _nearest_enemies(radius: float, limit: int) -> Array[Node2D]:
	return targeting_service.nearest(global_position, radius, limit)


func _enemies_in_radius(
	center: Vector2,
	radius: float
) -> Array[Node2D]:
	return targeting_service.in_radius(center, radius)


func _damage_enemy(
	enemy: Node2D,
	amount: float,
	play_hit_sound: bool = true,
	source_id: StringName = &"",
	hit_role: DamageEvent.HitRole = DamageEvent.HitRole.PRIMARY,
	can_trigger_procs: bool = true,
	proc_context: ProcContext = null
) -> void:
	if not is_instance_valid(enemy):
		return
	var resolved_source := (
		source_id if not source_id.is_empty() else active_damage_source
	)
	if resolved_source.is_empty():
		resolved_source = &"unclassified"
	var event := DamageEvent.create(
		enemy,
		amount,
		player,
		resolved_source,
		player.active_fleshdrive_id
	)
	if bool(enemy.get_meta("corroded", false)):
		event.amount *= 1.10
	event.play_hit_sound = play_hit_sound
	event.damage_type = (
		DamageEvent.DamageType.DIRECT
		if play_hit_sound
		else DamageEvent.DamageType.DAMAGE_OVER_TIME
	)
	event.can_crit = play_hit_sound
	event.critical_chance = float(player.get_meta(
		"critical_chance",
		0.05
	))
	event.critical_multiplier = float(player.get_meta(
		"critical_multiplier",
		1.5
	))
	event.hit_role = hit_role
	event.can_trigger_procs = can_trigger_procs
	event.proc_context = proc_context
	# Ball Lightning deals frequent overlapping ticks. Preserve its hit-stop and
	# critical feedback without stacking camera trauma every quarter-second.
	event.screen_shake = resolved_source not in [
		&"ball_lightning",
		&"orange_sun",
	]
	if build_runtime != null:
		event.amount = build_runtime.modify_damage(
			resolved_source,
			player.active_fleshdrive_id,
			event.amount,
			event.damage_type
		)
	event.heavy_feedback = play_hit_sound
	if combat_pipeline != null:
		combat_pipeline.call("apply_damage", event)


func _apply_knockback(
	enemy: Node2D,
	direction: Vector2,
	strength: float
) -> void:
	if combat_pipeline != null:
		var displacement_tags: Array[StringName] = [
			&"telekinetic_displacement"
		]
		combat_pipeline.call(
			"apply_displacement",
			enemy,
			direction,
			strength,
			displacement_tags
		)


func _spawn_projectile_tracer(
	from: Vector2,
	to: Vector2,
	atlas_row: int,
	projectile_scale: float,
	duration: float,
	use_fire_atlas: bool = false
) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_effect")):
		return
	var tracer := AnimatedSprite2D.new()
	tracer.sprite_frames = _make_projectile_frames(
		atlas_row,
		use_fire_atlas
	)
	tracer.animation = &"flight"
	tracer.position = from
	tracer.rotation = from.direction_to(to).angle()
	tracer.scale = Vector2.ONE * projectile_scale
	tracer.z_index = 18
	tracer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(tracer)
	tracer.play(&"flight")
	var tween := tracer.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tracer, "position", to, duration)
	tween.tween_callback(tracer.queue_free)


func _launch_readable_projectile(
	target: Node2D,
	speed: float,
	atlas_row: int,
	projectile_scale: float,
	use_fire_atlas: bool,
	hit_callback: Callable
) -> void:
	if not is_instance_valid(target):
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_player_projectile")):
		# Preserve combat reliability when only presentation is budget-limited.
		hit_callback.call(target)
		return
	var container := get_tree().get_first_node_in_group("attack_container")
	if container == null:
		hit_callback.call(target)
		return
	var projectile := ReadablePlayerProjectile.new()
	container.add_child(projectile)
	projectile.global_position = global_position
	projectile.configure(
		target,
		speed,
		_make_projectile_frames(atlas_row, use_fire_atlas),
		projectile_scale,
		hit_callback,
		(
			Color(1.0, 0.28, 0.055, 1.0)
			if use_fire_atlas
			else (
				Color(0.28, 0.84, 1.0, 1.0)
				if atlas_row == 1
				else Color(0.72, 0.42, 1.0, 1.0)
			)
		)
	)


func _make_projectile_frames(
	atlas_row: int,
	use_fire_atlas: bool = false
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"flight")
	frames.set_animation_loop(&"flight", true)
	frames.set_animation_speed(&"flight", 14.0)
	var texture := (
		FIRE_PROJECTILES_TEXTURE
		if use_fire_atlas
		else PLAYER_PROJECTILES_TEXTURE
	)
	var frame_size := 128 if use_fire_atlas else 256
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			frame_index * frame_size,
			atlas_row * frame_size,
			frame_size,
			frame_size
		)
		frames.add_frame(&"flight", frame)
	return frames


func _spawn_ring(radius: float, color: Color, width: float) -> void:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.antialiased = true
	for point_index in range(49):
		var angle := TAU * float(point_index) / 48.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	add_child(ring)
	_fade_and_free(ring, 0.24)


func _spawn_world_ring(
	center: Vector2,
	radius: float,
	color: Color,
	duration: float
) -> void:
	var ring := Line2D.new()
	ring.global_position = center
	ring.width = 4.0
	ring.default_color = color
	ring.antialiased = true
	ring.z_as_relative = false
	ring.z_index = 58
	for point_index in range(65):
		var angle := TAU * float(point_index) / 64.0
		ring.add_point(Vector2.from_angle(angle) * radius)
	var container := get_tree().get_first_node_in_group("effects_container")
	if container != null:
		container.add_child(ring)
	else:
		get_tree().current_scene.add_child(ring)
	ring.global_position = center
	ring.scale = Vector2.ONE * 0.72
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


func _fade_and_free(effect: CanvasItem, duration: float) -> void:
	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)


func _play_vfx(
	effect_id: StringName,
	world_position: Vector2,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> void:
	projectile_vfx_service.play_vfx(
		effect_id,
		world_position,
		effect_scale,
		rotation_radians
	)


func _play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float
) -> void:
	projectile_vfx_service.play_sound(
		sound_id,
		volume_db,
		pitch_variation
	)
