class_name EnemyDeathAnimator
extends RefCounted

static func play(
	enemy: Node2D,
	sprite: AnimatedSprite2D,
	scale_factor: float = 1.0
) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(sprite):
		return
	var container := enemy.get_tree().get_first_node_in_group(
		"effects_container"
	)
	if container == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.texture = sprite.sprite_frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.global_position = sprite.global_position
	ghost.rotation = sprite.global_rotation
	ghost.z_index = 24
	if enemy is Charger:
		ghost.material = sprite.material
		ghost.self_modulate = sprite.self_modulate
	else:
		var ghost_material := CanvasItemMaterial.new()
		ghost_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ghost.material = ghost_material
	container.add_child(ghost)

	var affinity := StringName(
		enemy.get_meta("last_damage_affinity", &"physical")
	)
	var effect_id := &"enemy_death"
	var tint := Color(0.78, 0.82, 0.86, 1.0)
	var end_position := ghost.global_position + Vector2(0.0, 8.0)
	var end_scale := ghost.scale * Vector2(1.05, 0.68)
	var end_rotation := ghost.rotation
	match affinity:
		&"electric":
			effect_id = &"electric_impact"
			tint = Color(0.34, 0.88, 1.0, 1.0)
			end_scale = ghost.scale * 1.18
		&"fire":
			effect_id = &"fire_explosion_embers"
			tint = Color(1.0, 0.32, 0.08, 1.0)
			end_position += Vector2(0.0, -28.0)
			end_scale = ghost.scale * Vector2(0.72, 1.16)
		&"telekinetic":
			effect_id = &"kinetic_impact"
			tint = Color(0.78, 0.42, 1.0, 1.0)
			end_scale = ghost.scale * 0.18
			end_rotation += (
				-0.5 if sprite.flip_h else 0.5
			)

	ghost.modulate = tint
	_play_world_effect(enemy, &"enemy_death_lightning", scale_factor * 0.82)
	if not enemy is VisceralWarden:
		_play_death_layers(enemy, scale_factor, effect_id)
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "global_position", end_position, 0.28)
	tween.tween_property(ghost, "scale", end_scale, 0.28)
	tween.tween_property(ghost, "rotation", end_rotation, 0.28)
	tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		0.32
	).set_delay(0.06)
	tween.chain().tween_callback(ghost.queue_free)


static func play_animation(
	enemy: Node2D,
	sprite: AnimatedSprite2D,
	animation: StringName,
	scale_factor: float = 1.0
) -> void:
	if (
		not is_instance_valid(enemy)
		or not is_instance_valid(sprite)
		or not sprite.sprite_frames.has_animation(animation)
	):
		play(enemy, sprite, scale_factor)
		return
	var container := enemy.get_tree().get_first_node_in_group(
		"effects_container"
	)
	if container == null:
		return
	var ghost := AnimatedSprite2D.new()
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.sprite_frames = sprite.sprite_frames
	ghost.animation = animation
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.z_index = 24
	if enemy is Charger:
		ghost.material = sprite.material
		ghost.self_modulate = sprite.self_modulate
	else:
		var ghost_material := CanvasItemMaterial.new()
		ghost_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ghost.material = ghost_material
	container.add_child(ghost)
	ghost.play(animation)
	var effect_id := _get_affinity_effect_id(enemy)
	_play_world_effect(enemy, &"enemy_death_lightning", scale_factor * 0.82)
	if not enemy is VisceralWarden:
		_play_death_layers(enemy, scale_factor, effect_id)
	_free_after_animation(ghost)


static func _free_after_animation(ghost: AnimatedSprite2D) -> void:
	await ghost.animation_finished
	if is_instance_valid(ghost):
		ghost.queue_free()


static func _get_affinity_effect_id(enemy: Node) -> StringName:
	match StringName(enemy.get_meta("last_damage_affinity", &"physical")):
		&"electric": return &"electric_impact"
		&"fire": return &"fire_explosion_embers"
		&"telekinetic": return &"kinetic_impact"
	return &"enemy_death"


static func _play_world_effect(
	enemy: Node2D,
	effect_id: StringName,
	scale_factor: float
) -> void:
	var visual_effects := enemy.get_tree().root.get_node_or_null(
		"VisualEffects"
	)
	if visual_effects != null:
		visual_effects.call(
			"play",
			effect_id,
			enemy.global_position,
			0.85 * scale_factor
		)


static func _play_death_layers(
	enemy: Node2D,
	scale_factor: float,
	affinity_effect_id: StringName
) -> void:
	_play_world_effect(enemy, &"enemy_death_burst", scale_factor * 0.78)
	_play_delayed_world_effect(
		enemy, &"tissue_droplets", scale_factor * 0.66, 0.045
	)
	# Only elemental finishing blows receive a small second accent. The flesh
	# burst remains the dominant silhouette, including on authored Chargers.
	if affinity_effect_id != &"enemy_death":
		_play_delayed_world_effect(
			enemy, affinity_effect_id, scale_factor * 0.44, 0.025
		)


static func _play_delayed_world_effect(
	enemy: Node2D,
	effect_id: StringName,
	scale_factor: float,
	delay: float
) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var tree := enemy.get_tree()
	var position := enemy.global_position
	await tree.create_timer(delay, false).timeout
	var visual_effects := tree.root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("play", effect_id, position, 0.85 * scale_factor)
