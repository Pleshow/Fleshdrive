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
