class_name ProjectileVfxService
extends RefCounted


var tree: SceneTree


func setup(scene_tree: SceneTree) -> void:
	tree = scene_tree


func play_vfx(
	effect_id: StringName,
	world_position: Vector2,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> void:
	if tree == null:
		return
	var budget := tree.root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_effect")):
		return
	var visual_effects := tree.root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call(
			"play",
			effect_id,
			world_position,
			effect_scale,
			rotation_radians
		)


func play_sound(
	sound_id: StringName,
	volume_db: float,
	pitch_variation: float
) -> void:
	if tree == null:
		return
	var audio_effects := tree.root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			sound_id,
			volume_db,
			pitch_variation,
			&"SFX"
		)
