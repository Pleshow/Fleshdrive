class_name UniversalMutationRuntime
extends RefCounted


const WEAPON_IDS: Array[StringName] = [
	&"spine_launcher", &"ripper_tail", &"bone_saw", &"parasite_maw",
	&"blood_needle", &"acid_gland", &"jaw_reflex", &"surgical_drone",
	&"implosion_sac",
]

var system: PlayerWeaponSystem
var player: Koda
var acid_zones: Array[Dictionary] = []
var saw_angle := 0.0
var saw_tick := 0.0
var weapon_activations := 0
var biomass_pickups := 0
var damage_buff_remaining := 0.0
var reactive_speed_remaining := 0.0
var bone_plating_remaining := 0.0
var predator_kills := 0
var blood_target_id := 0
var blood_streak := 0
var repeat_guard := false
var active_decoys: Array[Node2D] = []
var unshaded_vfx_material: CanvasItemMaterial


func setup(owner: PlayerWeaponSystem) -> void:
	system = owner
	player = owner.player
	unshaded_vfx_material = CanvasItemMaterial.new()
	unshaded_vfx_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var manager := system.get_tree().get_first_node_in_group("run_manager")
	if manager != null and manager.has_signal("rush_ended"):
		manager.rush_ended.connect(_on_rush_ended)


func shutdown() -> void:
	acid_zones.clear()
	for decoy in active_decoys:
		if is_instance_valid(decoy):
			decoy.queue_free()
	active_decoys.clear()


func update(delta: float) -> void:
	damage_buff_remaining = maxf(damage_buff_remaining - delta, 0.0)
	reactive_speed_remaining = maxf(reactive_speed_remaining - delta, 0.0)
	bone_plating_remaining = maxf(bone_plating_remaining - delta, 0.0)
	_update_acid_zones(delta)
	_update_bone_saw(delta)


func handles(weapon_id: StringName) -> bool:
	return weapon_id in WEAPON_IDS


func base_cooldown(weapon_id: StringName, level: int) -> float:
	var values := {
		&"spine_launcher": 1.5, &"ripper_tail": 2.7, &"bone_saw": 0.5,
		&"parasite_maw": 3.2, &"blood_needle": 0.72, &"acid_gland": 4.2,
		&"jaw_reflex": 2.4, &"surgical_drone": 1.15, &"implosion_sac": 4.8,
	}
	return maxf(float(values.get(weapon_id, 1.5)) * (1.0 - 0.035 * float(level - 1)), 0.18)


func fire(weapon_id: StringName, level: int) -> bool:
	var fired := false
	match weapon_id:
		&"spine_launcher": fired = _fire_spine_launcher(level)
		&"ripper_tail": fired = _fire_ripper_tail(level)
		&"bone_saw": fired = true # Continuous contact weapon.
		&"parasite_maw": fired = _fire_parasite_maw(level)
		&"blood_needle": fired = _fire_blood_needle(level)
		&"acid_gland": fired = _fire_acid_gland(level)
		&"jaw_reflex": fired = _fire_jaw_reflex(level)
		&"surgical_drone": fired = _fire_surgical_drone(level)
		&"implosion_sac": fired = _fire_implosion_sac(level)
	return fired


func cooldown_multiplier() -> float:
	var multiplier := 1.0
	if player.get_upgrade_level(&"rapid_synapses") > 0:
		multiplier *= 0.88
	if player.get_upgrade_level(&"hypertrophic_muscle") > 0:
		multiplier *= 1.10
	if player.get_upgrade_level(&"elastic_tendons") > 0:
		multiplier *= 1.10
	if player.get_upgrade_level(&"adrenal_gland") > 0 and player.current_health <= player.max_health * 0.30:
		multiplier *= 0.75
	if damage_buff_remaining > 0.0:
		multiplier *= 0.85
	return multiplier


func movement_multiplier() -> float:
	var multiplier := 1.0
	if player.get_upgrade_level(&"adrenal_gland") > 0 and player.current_health <= player.max_health * 0.30:
		multiplier *= 1.15
	if reactive_speed_remaining > 0.0:
		multiplier *= 1.40
	return multiplier


func modify_incoming_damage(amount: float) -> float:
	if player.get_upgrade_level(&"bone_plating") > 0 and bone_plating_remaining <= 0.0:
		bone_plating_remaining = 8.0
		_spawn_ring(player.global_position, 46.0, Color(0.76, 0.82, 0.88, 0.9))
		return 0.0
	if player.get_upgrade_level(&"open_wound") > 0:
		amount += 1.0
	return amount


func on_player_damaged(amount: float) -> void:
	player.release_stored_healing_if_needed()
	if player.get_upgrade_level(&"reactive_hide") > 0:
		reactive_speed_remaining = 1.0
	if player.get_upgrade_level(&"pain_converter") > 0:
		damage_buff_remaining = maxf(damage_buff_remaining, 3.0)
	if player.get_upgrade_level(&"porcupine_reflex") > 0:
		_fire_quill_retaliation()


func on_enemy_killed(total_kills: int) -> void:
	if player.get_upgrade_level(&"predators_hunger") > 0 and total_kills % 25 == 0:
		predator_kills += 1
		player.set_meta("universal_kill_damage_multiplier", 1.0 + 0.01 * predator_kills)
	if player.get_upgrade_level(&"mutated_synapse") > 0 and randf() <= 0.02:
		var candidates: Array[StringName] = []
		for weapon_id in system.cooldowns:
			if player.get_upgrade_level(weapon_id) > 0 and float(system.cooldowns[weapon_id]) > 0.0:
				candidates.append(weapon_id)
		if not candidates.is_empty():
			system.cooldowns[candidates.pick_random()] = 0.0


func _on_rush_ended(_rush_number: int) -> void:
	predator_kills = 0
	player.set_meta("universal_kill_damage_multiplier", 1.0)


func on_biomass_collected() -> void:
	biomass_pickups += 1
	if player.get_upgrade_level(&"scavenger_stomach") > 0 and biomass_pickups % 15 == 0:
		player.heal(5.0)


func on_dash_finished() -> void:
	if player.get_upgrade_level(&"impact_sac") > 0:
		for enemy in system._enemies_in_radius(player.global_position, 120.0):
			system._apply_knockback(enemy, player.global_position.direction_to(enemy.global_position), 520.0)
		_spawn_ring(player.global_position, 120.0, Color(0.84, 0.42, 0.26, 0.85))
	if player.get_upgrade_level(&"shed_skin") > 0:
		_spawn_decoy()
	if player.get_upgrade_level(&"predator_reflex") > 0:
		var nearby := system._enemies_in_radius(player.global_position, 96.0)
		if not nearby.is_empty():
			player.refund_dash_cooldown_fraction(0.50)


func _damage_multiplier() -> float:
	var value := (player.attack_damage / 15.0) * float(player.get_meta("universal_kill_damage_multiplier", 1.0))
	if player.get_upgrade_level(&"split_nervous_system") > 0:
		value *= 0.75
	return value


func _projectile_multiplier() -> float:
	return 0.85 if player.get_upgrade_level(&"overgrown_nerve_cluster") > 0 else 1.0


func _area_multiplier() -> float:
	return 1.20 if player.get_upgrade_level(&"elastic_tendons") > 0 else 1.0


func _fire_spine_launcher(level: int) -> bool:
	var projectile_count := 2 if player.get_upgrade_level(&"overgrown_nerve_cluster") > 0 else 1
	var targets := system._nearest_enemies(720.0, projectile_count)
	if targets.is_empty(): return false
	player.play_attack_animation(player.global_position.direction_to(targets[0].global_position))
	for target in targets:
		system._launch_readable_projectile(target, 620.0 + 40.0 * level, 1, 0.17, false,
			_on_spine_hit.bind(32.0 * (1.0 + 0.18 * (level - 1)) * _damage_multiplier() * _projectile_multiplier(), level))
	return true


func _on_spine_hit(target: Node2D, damage: float, level: int) -> void:
	system._damage_enemy(target, damage, true, &"spine_launcher")
	system.play_build_vfx(&"slash_horizontal", target.global_position, 0.85)
	if level >= 3:
		var extras := system.targeting_service.nearest(target.global_position, 150.0, mini(level - 1, 2))
		for enemy in extras:
			if enemy != target: system._damage_enemy(enemy, damage * 0.65, false, &"spine_launcher")


func _fire_ripper_tail(level: int) -> bool:
	var center := player.global_position - player.last_direction.normalized() * 32.0
	var targets := system._enemies_in_radius(center, (145.0 + 12.0 * level) * _area_multiplier())
	if targets.is_empty(): return false
	for enemy in targets:
		var behind := player.last_direction.normalized().dot(player.global_position.direction_to(enemy.global_position)) < 0.35
		if behind:
			system._damage_enemy(enemy, (24.0 + 7.0 * level) * _damage_multiplier(), true, &"ripper_tail")
			system._apply_knockback(enemy, player.global_position.direction_to(enemy.global_position), 460.0)
	system.play_build_vfx(
		&"ripper_tail_sweep",
		center,
		1.35,
		player.last_direction.angle() + PI
	)
	return true


func _update_bone_saw(delta: float) -> void:
	var level := player.get_upgrade_level(&"bone_saw")
	if level <= 0: return
	saw_angle += delta * (2.4 + 0.18 * level)
	saw_tick -= delta
	if saw_tick > 0.0: return
	saw_tick = 0.24
	var count := 2 if level >= 4 else 1
	for index in count:
		var angle := saw_angle + TAU * float(index) / count
		var center := player.global_position + Vector2.from_angle(angle) * (55.0 + 6.0 * level)
		for enemy in system._enemies_in_radius(center, 34.0):
			system._damage_enemy(enemy, (7.0 + 2.0 * level) * _damage_multiplier(), false, &"bone_saw", DamageEvent.HitRole.STATUS_TICK, false)
		_spawn_ring(center, 22.0, Color(0.78, 0.80, 0.76, 0.65))
		system.play_build_vfx(&"slash_small", center, 0.8, angle)


func _fire_parasite_maw(level: int) -> bool:
	var targets := system._nearest_enemies(470.0, 1)
	if targets.is_empty(): return false
	var target := targets[0]
	var target_position := target.global_position
	player.play_attack_animation(player.global_position.direction_to(target_position))
	system._damage_enemy(target, (48.0 + 12.0 * level) * _damage_multiplier(), true, &"parasite_maw")
	var killed: bool = bool(target.get("is_dead"))
	_spawn_maw_feedback(target_position, killed)
	system.play_build_vfx(&"bite_impact", target_position, 1.65)
	system.play_build_sound(&"enemy_hit", -4.0)
	if killed and randf() < 0.18 + 0.03 * level:
		player.add_biomass(1.0)
		_spawn_ring(target_position, 58.0, Color("0ce6f2"))
		system.play_build_sound(&"biomass_pickup", -10.0)
	return true


func _spawn_maw_feedback(target_position: Vector2, killed: bool) -> void:
	system.play_build_vfx(
		&"bite_impact", target_position, 1.25 if killed else 1.0
	)
	if killed:
		system.play_build_vfx(&"enemy_death_burst", target_position, 0.72)


func _fire_blood_needle(level: int) -> bool:
	var targets := system._nearest_enemies(760.0, 1)
	if targets.is_empty(): return false
	var target := targets[0]
	var id := target.get_instance_id()
	blood_streak = blood_streak + 1 if id == blood_target_id else 1
	blood_target_id = id
	var damage := (15.0 + 3.0 * level) * (1.0 + minf(blood_streak - 1, 8) * 0.08) * _damage_multiplier() * _projectile_multiplier()
	system._launch_readable_projectile(target, 980.0, 2, 0.10, false, _on_blood_needle_hit.bind(damage))
	return true


func _on_blood_needle_hit(target: Node2D, damage: float) -> void:
	system._damage_enemy(target, damage, true, &"blood_needle")


func _fire_acid_gland(level: int) -> bool:
	var targets := system._nearest_enemies(620.0, 1)
	if targets.is_empty(): return false
	var center := targets[0].global_position
	acid_zones.append({"center": center, "remaining": 3.0 + 0.25 * level, "tick": 0.0, "level": level})
	_spawn_ring(center, (82.0 + 8.0 * level) * _area_multiplier(), Color(0.40, 0.88, 0.22, 0.75))
	system.play_build_vfx(&"status_poison", center, 1.35)
	return true


func _update_acid_zones(delta: float) -> void:
	for index in range(acid_zones.size() - 1, -1, -1):
		var zone := acid_zones[index]
		zone.remaining = float(zone.remaining) - delta
		zone.tick = float(zone.tick) - delta
		if float(zone.tick) <= 0.0:
			zone.tick = 0.45
			var radius := (82.0 + 8.0 * int(zone.level)) * _area_multiplier()
			for enemy in system._enemies_in_radius(zone.center, radius):
				system._damage_enemy(enemy, (5.0 + 2.0 * int(zone.level)) * _damage_multiplier(), false, &"acid_gland", DamageEvent.HitRole.STATUS_TICK, false)
				enemy.set_meta("corroded", true)
		if float(zone.remaining) <= 0.0: acid_zones.remove_at(index)
		else: acid_zones[index] = zone


func _fire_jaw_reflex(level: int) -> bool:
	var targets := system._nearest_enemies(105.0 * _area_multiplier(), 1)
	if targets.is_empty(): return false
	var multiplier := 2.0 if player.current_health <= player.max_health * 0.20 else 1.0
	system._damage_enemy(targets[0], (38.0 + 10.0 * level) * multiplier * _damage_multiplier(), true, &"jaw_reflex")
	system.play_build_vfx(&"bite_impact", targets[0].global_position, 1.45)
	return true


func _fire_surgical_drone(level: int) -> bool:
	var targets := system._nearest_enemies(820.0, 1)
	if targets.is_empty(): return false
	system._launch_readable_projectile(targets[0], 780.0, 0, 0.12, false,
		_on_drone_hit.bind((12.0 + 4.0 * level) * _damage_multiplier() * _projectile_multiplier()))
	return true


func _on_drone_hit(target: Node2D, damage: float) -> void:
	system._damage_enemy(target, damage, true, &"surgical_drone")


func _fire_implosion_sac(level: int) -> bool:
	var targets := system._nearest_enemies(650.0, 1)
	if targets.is_empty(): return false
	_implode_after_delay(targets[0].global_position, level)
	return true


func _implode_after_delay(center: Vector2, level: int) -> void:
	_spawn_ring(center, 105.0 * _area_multiplier(), Color(0.54, 0.22, 0.72, 0.82))
	await system.get_tree().create_timer(1.2).timeout
	if not is_instance_valid(system): return
	for enemy in system._enemies_in_radius(center, 120.0 * _area_multiplier()):
		system._apply_knockback(enemy, enemy.global_position.direction_to(center), 340.0)
		system._damage_enemy(enemy, (28.0 + 8.0 * level) * _damage_multiplier(), true, &"implosion_sac")
	_spawn_ring(center, 120.0 * _area_multiplier(), Color(0.78, 0.38, 0.94, 0.95))


func on_weapon_activated(weapon_id: StringName, level: int) -> void:
	if repeat_guard: return
	weapon_activations += 1
	var repeat_delay := -1.0
	var repeat_scale := 1.0
	if player.get_upgrade_level(&"second_heartbeat") > 0 and weapon_activations % 8 == 0:
		repeat_delay = 0.10
	if player.get_upgrade_level(&"echo_nerve") > 0 and weapon_activations % 10 == 0:
		repeat_delay = 0.40
		repeat_scale = 0.50
	if player.get_upgrade_level(&"split_nervous_system") > 0 and randf() <= 0.25:
		repeat_delay = 0.12
	if repeat_delay >= 0.0:
		_repeat_weapon(weapon_id, level, repeat_delay, repeat_scale)


func _repeat_weapon(weapon_id: StringName, level: int, delay: float, scale_value: float) -> void:
	await system.get_tree().create_timer(delay).timeout
	if not is_instance_valid(system): return
	repeat_guard = true
	var old: float = float(player.get_meta("universal_kill_damage_multiplier", 1.0))
	player.set_meta("universal_kill_damage_multiplier", old * scale_value)
	system._fire_weapon(weapon_id, level)
	player.set_meta("universal_kill_damage_multiplier", old)
	repeat_guard = false


func _fire_quill_retaliation() -> void:
	for target in system._nearest_enemies(420.0, 8):
		system._damage_enemy(target, 9.0 * _damage_multiplier(), false, &"porcupine_reflex", DamageEvent.HitRole.SECONDARY, false)
	_spawn_ring(player.global_position, 86.0, Color(0.82, 0.34, 0.46, 0.85))


func _spawn_decoy() -> Node2D:
	if not is_instance_valid(player):
		return null
	var level := player.get_upgrade_level(&"shed_skin")
	if level <= 0:
		return null
	var lifetime := 1.5 + 0.25 * float(level - 1)
	var lure_radius := 260.0 + 30.0 * float(level - 1)
	var blast_radius := (108.0 + 18.0 * float(level - 2)) * _area_multiplier()
	var blast_damage := (10.0 + 6.0 * float(level)) * _damage_multiplier()
	var decoy := Node2D.new()
	decoy.name = "ShedSkinDecoy"
	decoy.add_to_group("shed_skin_decoy")
	decoy.set_meta("shed_skin_level", level)
	decoy.set_meta("lifetime", lifetime)
	decoy.set_meta("lure_radius", lure_radius)
	decoy.set_meta("blast_radius", blast_radius if level >= 2 else 0.0)
	decoy.set_meta("blast_damage", blast_damage if level >= 2 else 0.0)
	var player_shadow := player.get_node_or_null("GroundShadow") as Sprite2D
	if player_shadow != null:
		var shadow := Sprite2D.new()
		shadow.name = "GroundShadow"
		shadow.texture = player_shadow.texture
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.position = player_shadow.position
		shadow.scale = player.ground_shadow_base_scale
		MinimalistVisualProfile.configure_ground_shadow(shadow)
		shadow.z_index = -1
		decoy.add_child(shadow)
	var visual := AnimatedSprite2D.new()
	visual.name = "KodaIdle"
	visual.sprite_frames = player.animated_sprite.sprite_frames
	var idle_animation := StringName("idle_%s" % player.idle_side_direction)
	if not visual.sprite_frames.has_animation(idle_animation):
		idle_animation = &"idle_right"
	visual.animation = idle_animation
	visual.flip_h = player.idle_side_direction == &"left"
	visual.position = player.animated_sprite.position
	visual.scale = player.normal_scale
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.material = player.animated_sprite.material
	visual.modulate = Color(0.62, 0.88, 1.0, 0.78)
	visual.play(idle_animation)
	decoy.add_child(visual)
	var container := player.get_parent()
	if container == null:
		container = system.get_tree().current_scene
	if container == null:
		decoy.queue_free()
		return null
	container.add_child(decoy)
	decoy.global_position = player.global_position
	decoy.reset_physics_interpolation()
	active_decoys.append(decoy)
	var distracted: Array[Node2D] = []
	for enemy in system._enemies_in_radius(decoy.global_position, lure_radius):
		if enemy.get("target") is Node2D:
			enemy.set("target", decoy)
			distracted.append(enemy)
	_run_decoy_lifetime(decoy, distracted, level, lifetime)
	return decoy


func _run_decoy_lifetime(
	decoy: Node2D,
	distracted: Array[Node2D],
	level: int,
	lifetime: float
) -> void:
	await system.get_tree().create_timer(maxf(lifetime - 0.30, 0.0)).timeout
	if not is_instance_valid(decoy):
		return
	var fade := decoy.create_tween()
	fade.tween_property(decoy, "modulate:a", 0.24, 0.30)
	await fade.finished
	if not is_instance_valid(decoy):
		return
	system.play_build_vfx(&"decoy_smoke", decoy.global_position, 0.92)
	if level >= 2:
		_discharge_decoy(decoy, distracted, level)
	for enemy in distracted:
		if is_instance_valid(enemy) and enemy.get("target") == decoy:
			enemy.set("target", player)
	active_decoys.erase(decoy)
	decoy.queue_free()


func _discharge_decoy(
	decoy: Node2D,
	distracted: Array[Node2D],
	level: int
) -> void:
	if not is_instance_valid(decoy) or level < 2:
		return
	var blast_radius := float(decoy.get_meta(
		"blast_radius",
		(108.0 + 18.0 * float(level - 2)) * _area_multiplier()
	))
	var blast_damage := float(decoy.get_meta(
		"blast_damage",
		(10.0 + 6.0 * float(level)) * _damage_multiplier()
	))
	for enemy in distracted:
		if (
			is_instance_valid(enemy)
			and enemy.global_position.distance_to(decoy.global_position) <= blast_radius
		):
			system._damage_enemy(
				enemy,
				blast_damage,
				false,
				&"shed_skin_discharge",
				DamageEvent.HitRole.SECONDARY,
				false
			)
	system.play_build_vfx(
		&"electric_impact",
		decoy.global_position,
		1.25 + 0.15 * float(level - 2)
	)
	system.play_build_sound(&"raiju_attack_spark", -7.0)
	_spawn_ring(decoy.global_position, blast_radius, Color(0.18, 0.72, 1.0, 0.90))


func _spawn_ring(center: Vector2, radius: float, color: Color) -> void:
	system._spawn_world_ring(center, radius, color, 0.28)
