class_name OrangeTempestRuntime
extends RefCounted


const DEEP_BLUE := Color("1e579c")
const ELECTRIC_BLUE := Color("0098db")
const CYAN := Color("0ce6f2")
const CORE := Color("f2fbff")
const MAX_ORBS := 12
const POLARITY_COOLDOWN := 8.0

static var orb_sprite_frames: SpriteFrames

var host: PlayerWeaponSystem
var player: Koda
var orbs: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var spawn_cooldown: float = 0.0
var proximity_cooldown: float = 0.0
var created_count: int = 0
var reactor_bonus: float = 0.0
var reactor_decay: float = 0.0
var polarity_remaining: float = 0.0
var polarity_cooldown: float = 0.0
var polarity_burst_done: bool = false


func setup(owner: PlayerWeaponSystem) -> void:
	host = owner
	player = owner.player


func shutdown() -> void:
	for orb in orbs:
		_free_visual(orb)
	for field in fields:
		_free_visual(field)
	orbs.clear()
	fields.clear()


func update(delta: float) -> void:
	_update_fields(delta)
	if player == null or player.is_dead:
		return
	if player.get_upgrade_level(&"ball_lightning") <= 0:
		return
	polarity_cooldown = maxf(polarity_cooldown - delta, 0.0)
	reactor_decay -= delta
	if reactor_decay <= 0.0:
		reactor_bonus = 0.0
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_spawn_ball(false)
		var level := player.get_upgrade_level(&"ball_lightning")
		var base_cooldown := maxf(1.4 - 0.08 * float(level - 1), 0.72)
		spawn_cooldown = base_cooldown / (1.0 + reactor_bonus)
	_update_polarity(delta)
	for index in range(orbs.size() - 1, -1, -1):
		_update_orb(index, delta)
	proximity_cooldown -= delta
	if proximity_cooldown <= 0.0:
		proximity_cooldown = 0.16
		_resolve_orb_proximity()


func activate_polarity_shift() -> bool:
	if (
		player.get_upgrade_level(&"polarity_shift") <= 0
		or orbs.is_empty()
		or polarity_remaining > 0.0
		or polarity_cooldown > 0.0
	):
		return false
	polarity_remaining = 0.8
	polarity_cooldown = POLARITY_COOLDOWN
	polarity_burst_done = false
	host.play_build_vfx(&"ball_lightning_burst", player.global_position, 1.0)
	return true


func _spawn_ball(offspring: bool, at_position: Vector2 = Vector2.INF) -> void:
	if orbs.size() >= MAX_ORBS:
		return
	created_count += 1
	var direction := player.last_direction.normalized()
	var target_candidates := host.nearest_enemies_for_build(
		player.global_position, 720.0, 1
	)
	if not target_candidates.is_empty():
		direction = player.global_position.direction_to(
			target_candidates[0].global_position
		)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var orbital := (
		player.get_upgrade_level(&"orbital_charge") > 0
		and created_count % 3 == 0
		and not offspring
	)
	var lifetime := 4.2 * (
		1.0 + 0.35 * float(player.get_upgrade_level(&"ionized_membrane"))
	)
	var radius := 32.0 * (
		1.0 + 0.25 * float(player.get_upgrade_level(&"plasma_expansion"))
	)
	var speed := 220.0 / (
		1.0 + 0.10 * float(player.get_upgrade_level(&"plasma_expansion"))
	)
	var start := (
		player.global_position + direction * 34.0
		if at_position == Vector2.INF
		else at_position
	)
	var visual := _create_orb_visual(start, radius, false)
	var target_node := _find_target_for(start)
	orbs.append({
		"visual": visual,
		"position": start,
		"velocity": direction * speed,
		"speed": speed,
		"target": target_node,
		"lifetime": lifetime,
		"radius": radius,
		"charge": 0,
		"tick": 0.0,
		"contacts": {},
		"replication_available": true,
		"replication_cooldown": 0.0,
		"orbital": orbital,
		"orbit_angle": randf() * TAU,
		"orbit_remaining": 6.0,
		"sun": false,
		"sun_spawn_tick": 0.6,
	})
	var reactor := player.get_upgrade_level(&"chain_reactor")
	if reactor > 0:
		reactor_bonus = minf(reactor_bonus + 0.02 * float(reactor), 0.50)
		reactor_decay = 5.0


func _update_orb(index: int, delta: float) -> void:
	if index >= orbs.size():
		return
	var orb := orbs[index]
	var visual := _get_valid_node_2d(orb.get("visual"))
	if not is_instance_valid(visual):
		orbs.remove_at(index)
		return
	orb["lifetime"] = float(orb["lifetime"]) - delta
	orb["tick"] = float(orb["tick"]) - delta
	orb["replication_cooldown"] = maxf(
		float(orb["replication_cooldown"]) - delta, 0.0
	)
	if bool(orb["orbital"]):
		orb["orbit_remaining"] = float(orb["orbit_remaining"]) - delta
		orb["orbit_angle"] = float(orb["orbit_angle"]) + delta * 2.2
		orb["position"] = player.global_position + Vector2.from_angle(
			float(orb["orbit_angle"])
		) * 78.0
		if float(orb["orbit_remaining"]) <= 0.0:
			orb["orbital"] = false
			orb["velocity"] = player.global_position.direction_to(
				_find_aim_point()
			) * 190.0
	else:
		_apply_orb_steering(orb, delta)
		orb["position"] = Vector2(orb["position"]) + Vector2(orb["velocity"]) * delta
	visual.global_position = Vector2(orb["position"])
	visual.rotation += delta * (0.65 if bool(orb["sun"]) else 1.8)
	if float(orb["tick"]) <= 0.0:
		orb["tick"] = 0.26
		_damage_near_orb(orb)
	if bool(orb["sun"]):
		orb["sun_spawn_tick"] = float(orb["sun_spawn_tick"]) - delta
		if float(orb["sun_spawn_tick"]) <= 0.0:
			orb["sun_spawn_tick"] = 0.6
			_spawn_ball(true, Vector2(orb["position"]))
	if float(orb["lifetime"]) <= 0.0:
		_expire_orb(index)
	else:
		orbs[index] = orb


func _apply_orb_steering(orb: Dictionary, delta: float) -> void:
	var velocity := Vector2(orb["velocity"])
	# Dictionary-held Object references become freed-object Variants when an
	# enemy dies. Casting that Variant before validating it raises a runtime
	# error and pauses the game. Resolve it through the guarded helper first.
	var target := _get_valid_node_2d(orb.get("target"))
	if not is_instance_valid(target) or target.global_position.distance_to(Vector2(orb["position"])) > 960.0:
		target = _find_target_for(Vector2(orb["position"]))
		orb["target"] = target
	if is_instance_valid(target):
		var desired := Vector2(orb["position"]).direction_to(target.global_position) * float(orb["speed"])
		var steering := 620.0
		if player.get_upgrade_level(&"plasma_shepherd") > 0:
			steering *= 1.45
		velocity = velocity.move_toward(desired, steering * delta)
	if player.get_upgrade_level(&"electric_gravity") > 0:
		var attraction := Vector2.ZERO
		for other in orbs:
			if other == orb:
				continue
			var offset := Vector2(other["position"]) - Vector2(orb["position"])
			if offset.length_squared() < 90000.0 and offset.length_squared() > 64.0:
				attraction += offset.normalized()
		velocity += attraction.limit_length(2.0) * 42.0 * delta
	orb["velocity"] = velocity.limit_length(float(orb["speed"]) * 1.15)


func _damage_near_orb(orb: Dictionary) -> void:
	var damage := 8.0 + 2.0 * float(player.get_upgrade_level(&"ball_lightning") - 1)
	var radius := float(orb["radius"]) * (1.0 + 0.18 * float(orb["charge"]))
	if bool(orb["sun"]):
		damage = 18.0
		radius = 90.0
	for enemy in host.enemies_in_radius_for_build(Vector2(orb["position"]), radius):
		host.damage_enemy_for_build(
			enemy, damage, &"orange_sun" if bool(orb["sun"]) else &"ball_lightning",
			DamageEvent.HitRole.SECONDARY, false
		)
		var contacts := orb["contacts"] as Dictionary
		var enemy_id := enemy.get_instance_id()
		if not contacts.has(enemy_id):
			contacts[enemy_id] = true
			_set_charge(orb, mini(int(orb["charge"]) + 1, 3))


func _resolve_orb_proximity() -> void:
	for first_index in range(orbs.size()):
		for second_index in range(first_index + 1, orbs.size()):
			if first_index >= orbs.size() or second_index >= orbs.size():
				return
			var first := orbs[first_index]
			var second := orbs[second_index]
			if bool(first["sun"]) or bool(second["sun"]):
				continue
			var distance := Vector2(first["position"]).distance_to(Vector2(second["position"]))
			if distance > 42.0:
				continue
			_set_charge(first, mini(int(first["charge"]) + 1, 3))
			_set_charge(second, mini(int(second["charge"]) + 1, 3))
			if (
				player.get_upgrade_level(&"star_collapse") > 0
				and int(first["charge"]) >= 3
				and int(second["charge"]) >= 3
			):
				_create_orange_sun(first_index, second_index)
				return
			if player.get_upgrade_level(&"static_replication") <= 0:
				continue
			if (
				bool(first["replication_available"])
				and bool(second["replication_available"])
				and float(first["replication_cooldown"]) <= 0.0
				and float(second["replication_cooldown"]) <= 0.0
			):
				first["replication_available"] = false
				second["replication_available"] = false
				first["replication_cooldown"] = 0.5
				second["replication_cooldown"] = 0.5
				_spawn_ball(true, (Vector2(first["position"]) + Vector2(second["position"])) * 0.5)


func _set_charge(orb: Dictionary, charge: int) -> void:
	var previous_charge := int(orb.get("charge", 0))
	orb["charge"] = charge
	var visual := _get_valid_node_2d(orb.get("visual"))
	if is_instance_valid(visual):
		visual.scale = Vector2.ONE * (1.0 + 0.18 * float(charge))
		visual.modulate = Color.WHITE.lerp(CYAN, 0.08 * float(charge))
	if (
		previous_charge < 3
		and charge >= 3
		and player.get_upgrade_level(&"static_replication") > 0
		and bool(orb.get("replication_available", false))
		and orbs.size() < MAX_ORBS
	):
		orb["replication_available"] = false
		_spawn_ball(true, Vector2(orb["position"]))


func _create_orange_sun(first_index: int, second_index: int) -> void:
	var first := orbs[first_index]
	var second := orbs[second_index]
	var center := (Vector2(first["position"]) + Vector2(second["position"])) * 0.5
	_remove_orb(maxi(first_index, second_index), false)
	_remove_orb(mini(first_index, second_index), false)
	var visual := _create_orb_visual(center, 90.0, true)
	orbs.append({
		"visual": visual, "position": center, "velocity": Vector2.from_angle(randf() * TAU) * 54.0,
		"speed": 96.0, "target": _find_target_for(center),
		"lifetime": 5.0, "radius": 90.0, "charge": 3, "tick": 0.0, "contacts": {},
		"replication_available": false, "replication_cooldown": 0.0, "orbital": false,
		"orbit_angle": 0.0, "orbit_remaining": 0.0, "sun": true, "sun_spawn_tick": 0.35,
	})
	host.play_build_vfx(&"ball_lightning_burst", center, 1.5)
	host.play_build_vfx(&"electric_heavy_chain", center, 1.15)


func _expire_orb(index: int) -> void:
	if index >= orbs.size():
		return
	var orb := orbs[index]
	if player.get_upgrade_level(&"residual_charge") > 0 and not bool(orb["sun"]):
		_spawn_static_field(Vector2(orb["position"]))
	if int(orb["charge"]) >= 3 and not bool(orb["sun"]):
		for enemy in host.enemies_in_radius_for_build(Vector2(orb["position"]), 72.0):
			host.damage_enemy_for_build(enemy, 16.0, &"supercharged_burst")
		host.play_build_vfx(&"ball_lightning_burst", Vector2(orb["position"]), 0.9)
	_remove_orb(index, true)


func _remove_orb(index: int, _expired: bool) -> void:
	if index < 0 or index >= orbs.size():
		return
	_free_visual(orbs[index])
	orbs.remove_at(index)


func _spawn_static_field(position: Vector2) -> void:
	var visual := _create_field_visual(position)
	fields.append({"visual": visual, "position": position, "lifetime": 2.0, "tick": 0.0})


func _update_fields(delta: float) -> void:
	for index in range(fields.size() - 1, -1, -1):
		var field := fields[index]
		field["lifetime"] = float(field["lifetime"]) - delta
		field["tick"] = float(field["tick"]) - delta
		if float(field["tick"]) <= 0.0:
			field["tick"] = 0.35
			for enemy in host.enemies_in_radius_for_build(Vector2(field["position"]), 68.0):
				host.damage_enemy_for_build(enemy, 5.0, &"residual_charge")
				if enemy.has_method("apply_external_impulse"):
					enemy.call("apply_external_impulse", Vector2.ZERO)
		if float(field["lifetime"]) <= 0.0:
			_free_visual(field)
			fields.remove_at(index)
		else:
			fields[index] = field


func _update_polarity(delta: float) -> void:
	if polarity_remaining <= 0.0:
		return
	polarity_remaining -= delta
	if polarity_remaining > 0.32:
		for orb in orbs:
			orb["velocity"] = Vector2(orb["position"]).direction_to(player.global_position) * 330.0
	elif not polarity_burst_done:
		polarity_burst_done = true
		for orb in orbs:
			var target := _find_target_for(Vector2(orb["position"]))
			orb["target"] = target
			var launch_direction := (
				Vector2(orb["position"]).direction_to(target.global_position)
				if is_instance_valid(target)
				else player.global_position.direction_to(Vector2(orb["position"]))
			)
			orb["velocity"] = launch_direction * 520.0
			_set_charge(orb, mini(int(orb["charge"]) + 1, 3))
		host.play_build_vfx(&"ball_lightning_burst", player.global_position, 1.15)


func _find_aim_point() -> Vector2:
	var candidates := host.nearest_enemies_for_build(player.global_position, 900.0, 1)
	return candidates[0].global_position if not candidates.is_empty() else player.global_position + player.last_direction * 300.0


func _find_target_for(position: Vector2) -> Node2D:
	var candidates := host.nearest_enemies_for_build(position, 960.0, 1)
	if candidates.is_empty():
		return null
	return _get_valid_node_2d(candidates[0])


func _get_valid_node_2d(candidate: Variant) -> Node2D:
	if not is_instance_valid(candidate):
		return null
	if candidate is Node2D:
		return candidate as Node2D
	return null


func _create_orb_visual(position: Vector2, radius: float, sun: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "StormCore" if sun else "BallLightning"
	root.global_position = position
	root.z_index = 6
	var sprite := AnimatedSprite2D.new()
	sprite.name = "PixelOrb"
	sprite.sprite_frames = _get_orb_sprite_frames()
	sprite.animation = &"pulse"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = material
	root.add_child(sprite)
	sprite.play()
	var glow := Line2D.new()
	glow.name = "ElectricGlow"
	glow.closed = true
	glow.antialiased = false
	glow.width = 8.0
	glow.default_color = Color(0.0, 0.596, 0.859, 0.30)
	glow.material = material
	for point in _circle_points(8, 15.0):
		glow.add_point(point)
	root.add_child(glow)
	var ring := Line2D.new()
	ring.name = "ElectricOutline"
	ring.closed = true
	ring.antialiased = false
	ring.width = 3.0
	ring.default_color = CYAN if not sun else CORE
	ring.material = material
	for point in _circle_points(8, 15.0):
		ring.add_point(point)
	root.add_child(ring)
	root.scale = Vector2.ONE * radius / 32.0 * (1.45 if sun else 1.0)
	_add_visual(root)
	return root


func _create_field_visual(position: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = "ResidualStaticField"
	root.global_position = position
	root.z_index = 2
	var ring := Line2D.new()
	ring.closed = true
	ring.antialiased = false
	ring.width = 2.0
	ring.default_color = Color(0.047, 0.902, 0.949, 0.82)
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ring.material = material
	for point in _circle_points(12, 68.0):
		ring.add_point(point)
	root.add_child(ring)
	_add_visual(root)
	return root


func _circle_points(count: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		points.append(Vector2.from_angle(TAU * float(index) / float(count)) * radius)
	return points


func _get_orb_sprite_frames() -> SpriteFrames:
	if orb_sprite_frames != null:
		return orb_sprite_frames
	orb_sprite_frames = SpriteFrames.new()
	orb_sprite_frames.remove_animation(&"default")
	orb_sprite_frames.add_animation(&"pulse")
	orb_sprite_frames.set_animation_loop(&"pulse", true)
	orb_sprite_frames.set_animation_speed(&"pulse", 10.0)
	var spark_sets := [
		[Vector2i(4, 6), Vector2i(19, 5), Vector2i(3, 16), Vector2i(20, 18)],
		[Vector2i(6, 3), Vector2i(21, 10), Vector2i(5, 20), Vector2i(18, 21)],
		[Vector2i(3, 10), Vector2i(17, 3), Vector2i(20, 15), Vector2i(9, 21)],
		[Vector2i(5, 4), Vector2i(20, 7), Vector2i(3, 18), Vector2i(17, 20)],
	]
	for frame_index in range(4):
		var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(7, 18):
			for x in range(7, 18):
				var distance := Vector2(x - 12, y - 12).length()
				if distance <= 5.4:
					image.set_pixel(x, y, DEEP_BLUE)
				if distance <= 4.0:
					image.set_pixel(x, y, ELECTRIC_BLUE)
				if distance <= 2.1:
					image.set_pixel(x, y, CORE)
		var phase := frame_index % 2
		_draw_pixel_line(image, Vector2i(1, 12 - phase), Vector2i(8, 10 + phase), CYAN)
		_draw_pixel_line(image, Vector2i(16, 13 - phase), Vector2i(22, 10 + phase), CYAN)
		_draw_pixel_line(image, Vector2i(10 + phase, 1), Vector2i(12 - phase, 8), ELECTRIC_BLUE)
		_draw_pixel_line(image, Vector2i(13 - phase, 16), Vector2i(10 + phase, 22), ELECTRIC_BLUE)
		for spark in spark_sets[frame_index]:
			image.set_pixelv(spark, CORE)
		var texture := ImageTexture.create_from_image(image)
		orb_sprite_frames.add_frame(&"pulse", texture)
	return orb_sprite_frames


func _draw_pixel_line(image: Image, start: Vector2i, finish: Vector2i, color: Color) -> void:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	for step in range(steps + 1):
		var ratio := float(step) / float(maxi(steps, 1))
		var point := Vector2(start).lerp(Vector2(finish), ratio).round()
		image.set_pixelv(Vector2i(point), color)


func _add_visual(visual: Node2D) -> void:
	var container := host.get_tree().get_first_node_in_group("effects_container")
	if container == null:
		container = host.get_tree().current_scene
	container.add_child(visual)
	visual.add_to_group("orange_tempest_vfx")


func _free_visual(data: Dictionary) -> void:
	var visual := _get_valid_node_2d(data.get("visual"))
	if is_instance_valid(visual):
		visual.queue_free()
