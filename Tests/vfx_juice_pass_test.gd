extends SceneTree


const WORLD_EFFECTS: Array[StringName] = [
	&"generic_hit", &"heavy_hit", &"electric_impact", &"electric_micro_hit",
	&"shock_proc", &"dash_smoke", &"dash_smoke_end", &"charge_dust",
	&"enemy_death_burst", &"tissue_droplets", &"biomass_collect",
	&"fire_impact", &"magma_spear_impact", &"charger_impact",
	&"enemy_spawn", &"boss_slam", &"boss_death",
	&"ball_lightning_idle", &"ball_lightning_explosion",
	&"projectile_lightning", &"projectile_lightning_loop",
	&"kinetic_charge_lightning", &"shock_status",
	&"enemy_death_lightning", &"decoy_smoke", &"holy_heal",
]
const UI_EFFECTS: Array[StringName] = [
	&"ui_energy_confirm", &"organ_flesh_pulse", &"organ_activation",
]
const ELECTRIC_EFFECTS: Array[StringName] = [
	&"electric_impact", &"electric_micro_hit", &"shock_proc",
	&"biomass_collect", &"ui_energy_confirm", &"organ_activation",
	&"ball_lightning_idle", &"ball_lightning_explosion",
	&"projectile_lightning", &"projectile_lightning_loop",
	&"kinetic_charge_lightning", &"shock_status",
	&"enemy_death_lightning", &"holy_heal",
]
const CRIMSON_EFFECTS: Array[StringName] = [
	&"generic_hit", &"heavy_hit", &"enemy_death_burst",
	&"tissue_droplets", &"fire_impact", &"magma_spear_impact",
	&"boss_slam", &"boss_death", &"organ_flesh_pulse",
]
const NEUTRAL_EFFECTS: Array[StringName] = [
	&"dash_smoke", &"dash_smoke_end", &"charge_dust",
	&"charger_impact", &"enemy_spawn",
	&"decoy_smoke",
]
const LOOP_EFFECTS: Array[StringName] = [
	&"ball_lightning_idle", &"projectile_lightning_loop",
	&"kinetic_charge_lightning", &"shock_status",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	root.get_node("GameFlow").call("set_selected_arena", &"dusk_garden")
	var game := (load("res://Scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	paused = false
	game.get_node("EnemySpawner").call("stop_spawning")
	var settings := root.get_node("GameSettings")
	var original_intensity := float(settings.get("vfx_intensity"))
	settings.set("vfx_intensity", 1.0)
	var visual_effects := root.get_node("VisualEffects")
	var all_registered := true
	for effect_id in WORLD_EFFECTS + UI_EFFECTS:
		all_registered = all_registered and bool(visual_effects.call("has_effect", effect_id))
	_check(all_registered, "Every focused juice-pass effect is data-driven in VisualEffects")
	var ripper_sweep := visual_effects.call(
		"play",
		&"ripper_tail_sweep",
		Vector2(320.0, 260.0),
		1.35,
		PI
	) as AnimatedSprite2D
	var ripper_frame := (
		ripper_sweep.sprite_frames.get_frame_texture(&"play", 0)
		as AtlasTexture
		if ripper_sweep != null
		else null
	)
	_check(
		ripper_sweep != null
		and ripper_frame != null
		and ripper_frame.atlas.resource_path.ends_with(
			"Assets/vfx/licensed/slashes/big_slash.png"
		)
		and is_equal_approx(
			ripper_sweep.sprite_frames.get_animation_speed(&"play"),
			14.0
		),
		"Ripper Tail uses a readable crescent sweep instead of an explosion"
	)
	if ripper_sweep != null:
		visual_effects.call("stop_effect", ripper_sweep)

	var nearest_only := true
	var source_colors_safe := true
	var short_frequent_effects := true
	var index := 0
	for effect_id in WORLD_EFFECTS:
		var sprite := visual_effects.call(
			"play", effect_id,
			Vector2(180.0 + float(index % 6) * 90.0, 220.0 + float(index / 6) * 80.0),
			0.5
		) as AnimatedSprite2D
		index += 1
		if sprite == null:
			nearest_only = false
			source_colors_safe = false
			continue
		nearest_only = nearest_only and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		var material := sprite.material as ShaderMaterial
		var parent_layer := sprite.get_parent() as CanvasLayer
		source_colors_safe = (
			source_colors_safe
			and bool(visual_effects.call("uses_original_colors", effect_id))
			and material == null
			and parent_layer != null
			and parent_layer.layer == 106
		)
		if effect_id in [&"generic_hit", &"electric_micro_hit", &"biomass_collect"]:
			var duration := (
				float(sprite.sprite_frames.get_frame_count(&"play"))
				/ sprite.sprite_frames.get_animation_speed(&"play")
			)
			short_frequent_effects = short_frequent_effects and duration <= 0.12
		if effect_id in LOOP_EFFECTS:
			visual_effects.call("stop_effect", sprite)
	_check(nearest_only, "Purchased VFX keep crisp nearest-neighbor filtering")
	_check(source_colors_safe, "Purchased VFX bypass recoloring and retain their source palette")
	_check(short_frequent_effects, "Frequent hit and pickup effects finish within 120 ms")
	_check(
		Array(visual_effects.get("active_sprites")).size() <= 72,
		"Juice pass shares the existing pooled simultaneous-effect ceiling"
	)
	await create_timer(0.90).timeout
	_check(
		Array(visual_effects.get("active_sprites")).is_empty()
		and Array(visual_effects.get("pooled_sprites")).size() <= 40,
		"Short animations recycle through the existing bounded VFX pool"
	)

	var ui_sprite := visual_effects.call(
		"play_ui", &"ui_energy_confirm", Vector2(320.0, 180.0), 0.55
	) as AnimatedSprite2D
	_check(
		ui_sprite != null
		and ui_sprite.process_mode == Node.PROCESS_MODE_ALWAYS
		and ui_sprite.get_parent() is CanvasLayer,
		"Confirmation VFX remains visible while modal gameplay is paused"
	)
	settings.set("vfx_intensity", original_intensity)
	visual_effects.call("clear_all")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("VFX JUICE PASS TEST PASSED")
	quit(1 if failures > 0 else 0)
