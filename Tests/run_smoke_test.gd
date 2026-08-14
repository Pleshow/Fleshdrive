extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var meta_progression := root.get_node_or_null("MetaProgression")
	var original_meta_save_path := String(meta_progression.save_path)
	var smoke_meta_save_path := (
		"res://.godot/fleshdrive_run_smoke_progression.cfg"
	)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(smoke_meta_save_path)
	)
	meta_progression.save_path = smoke_meta_save_path
	meta_progression.reset_all_progress()

	var packed_game := load("res://Scenes/game.tscn") as PackedScene
	_check(packed_game != null, "Game scene can be loaded")

	if packed_game == null:
		_finish()
		return

	var game := packed_game.instantiate()
	root.add_child(game)
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var run_manager := get_first_node_in_group(
		"run_manager"
	) as RunManager
	var spawner := game.get_node("EnemySpawner")
	var hud := game.get_node("UI/HUD")
	var enemies_container := game.get_node("Entities/Enemies")
	var attack_container := game.get_node("Entities/Attacks")
	var music := game.get_node("Music") as AudioStreamPlayer
	var audio_effects := root.get_node_or_null("AudioEffects")
	var world_darkness := game.get_node("WorldDarkness") as CanvasModulate
	var post_process := game.get_node_or_null("PostProcess/ScreenFilter")
	var settings := root.get_node_or_null("GameSettings")
	var original_master_volume := float(settings.master_volume)
	var original_crt := float(settings.crt_intensity)
	var original_bloom := float(settings.bloom_intensity)
	var original_chromatic := float(settings.chromatic_aberration)
	var original_bit_reduction := float(settings.bit_reduction)

	_check(player != null, "Player exists")
	_check(run_manager != null, "Run manager exists")
	_check(
		player != null
		and player.collision_layer == 4
		and player.collision_mask == 1,
		"Koda collides with the laboratory but cannot be body-blocked by enemies"
	)
	var gameplay_camera := player.get_node("Camera2D") as CameraFeedback
	gameplay_camera._physics_process(0.0)
	_check(
		gameplay_camera.base_offset.y <= -64.0
		and gameplay_camera.zoom.is_equal_approx(Vector2(1.3, 1.3))
		and spawner.viewport_half_extent.y <= 296.0
		and spawner.arena_bounds.position.y >= 160.0,
		"Camera keeps its HUD offset and uses the 15% closer gameplay framing"
	)
	_check(
		run_manager.boss_scene != null
		and hud.get_node_or_null("BossPanel") != null
		and hud.get_node_or_null("BossWarningLabel") != null,
		"Run finale includes the Visceral Warden and boss HUD"
	)
	_check(
		world_darkness != null and world_darkness.color.v < 0.26,
		"Arena has a deep blue-black ambient canvas modulation"
	)
	_check(
		post_process != null,
		"Gameplay has a full-screen CRT post process"
	)
	var ui_layer := game.get_node("UI") as CanvasLayer
	var post_process_layer := game.get_node("PostProcess") as CanvasLayer
	var top_safe_area := hud.get_node("TopHudSafeArea") as ColorRect
	_check(
		ui_layer.layer > post_process_layer.layer
		and top_safe_area.size.y >= 128.0
		and top_safe_area.color.a >= 0.9,
		"Status, boss and mutation UI render above the vignette in a top safe area"
	)
	if post_process != null:
		var post_material := post_process.material as ShaderMaterial
		_check(
			post_material != null
			and post_process.vignette_strength >= 0.65
			and post_process.vignette_follows_player,
			"Gameplay uses the near-black player-following vignette"
		)
	_check(audio_effects != null, "Gameplay audio effects player is available")
	if audio_effects != null:
		audio_effects.call("clear_play_counts")
	_check(
		music != null
		and music.stream.resource_path
		== "res://Assets/audio/music/gameplay_loop.ogg"
		and music.autoplay
		and music.stream.get("loop") == true,
		"Gameplay uses the selected looping music"
	)
	_check(music.bus == &"Music", "Gameplay music uses the Music bus")
	_check(
		music.process_mode == Node.PROCESS_MODE_ALWAYS
		and music.playing,
		"Gameplay music runs independently of paused UI states"
	)

	if player == null or run_manager == null:
		paused = false
		game.queue_free()
		await process_frame
		_finish()
		return

	_check(
		run_manager.state == RunManager.RunState.OPERATION,
		"Run starts in Fleshdrive operation state"
	)
	_check(
		hud.fleshdrive_operation_screen.visible,
		"Fleshdrive selection operation is visible before onboarding"
	)
	hud._on_fleshdrive_selected(FleshdriveCatalog.ELECTRIC)
	_check(
		run_manager.state == RunManager.RunState.ONBOARDING,
		"Implanting a Fleshdrive opens onboarding"
	)
	_check(hud.onboarding_panel.visible, "Onboarding panel is visible")
	_check(paused, "Onboarding pauses gameplay")
	_check(music.playing, "Music continues during onboarding")
	hud.complete_onboarding()
	_check(
		run_manager.state == RunManager.RunState.PLAYING and not paused,
		"Begin Run starts normal gameplay"
	)
	_check(
		is_equal_approx(
			player.move_speed,
			210.0 + 4.0 * meta_progression.get_upgrade_level(&"mobility")
		),
		"Player uses base movement plus permanent mobility"
	)
	_check(
		hud.health_bar is ProgressBar
		and hud.biomass_bar is ProgressBar
		and hud.koda_portrait.texture is AtlasTexture
		and hud.get_node_or_null("HeartPulse") == null,
		"HUD uses a square Koda portrait and native Godot status bars"
	)
	hud.update_health_bar(50.0, 100.0)
	hud.update_biomass_bar(25.0, 100.0, 2)
	_check(
		is_equal_approx(hud.health_bar.value, 50.0)
		and is_equal_approx(hud.health_bar.max_value, 100.0)
		and is_equal_approx(hud.biomass_bar.value, 25.0)
		and is_equal_approx(hud.biomass_bar.max_value, 100.0)
		and hud.health_value_label.text == "50 / 100"
		and hud.biomass_value_label.text == "25 / 100",
		"Red HP and blue XP bars display independent exact values"
	)
	var health_fill := (
		hud.health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	)
	var xp_fill := (
		hud.biomass_bar.get_theme_stylebox("fill") as StyleBoxFlat
	)
	_check(
		health_fill != null
		and xp_fill != null
		and health_fill.bg_color.r > 0.7
		and xp_fill.bg_color.b > 0.8,
		"Native status bars use the red and blue Fleshdrive UI palette"
	)
	_check(
		hud.get_node_or_null("GemCountLabel") == null,
		"Gameplay HUD does not display permanent gem currency"
	)
	var player_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var down_frame := (
		player_sprite.sprite_frames.get_frame_texture(&"down", 0)
		as AtlasTexture
	)
	_check(
		down_frame != null
		and down_frame.atlas.resource_path
		== "res://Assets/player/Koda run.png"
		and down_frame.region.size == Vector2(112, 96),
		"Player uses the replacement Koda run sprite sheet"
	)
	_check(
		player_sprite.scale == Vector2.ONE
		and player_sprite.texture_filter
		== CanvasItem.TEXTURE_FILTER_NEAREST,
		"Koda's replacement gameplay sprite uses crisp whole-pixel rendering"
	)
	_check(
		player_sprite.sprite_frames.get_animation_names().size() == 24,
		"Koda uses four visual directions instead of eight"
	)
	_check(
		player.walk_animation_speed >= 13.0
		and player.walk_animation_speed < 14.0,
		"Koda's grounded gait plays at a controlled running cadence"
	)
	var left_frame := (
		player_sprite.sprite_frames.get_frame_texture(&"left", 0)
		as AtlasTexture
	)
	var right_frame := (
		player_sprite.sprite_frames.get_frame_texture(&"right", 0)
		as AtlasTexture
	)
	_check(
		left_frame.region == right_frame.region,
		"Left reuses the mirrored side-view atlas row"
	)
	var action_names := [&"idle", &"jump", &"attack", &"hurt", &"death"]
	for direction_name in player.DIRECTION_ROWS:
		_check(
			player_sprite.sprite_frames.get_frame_count(direction_name) == 8,
			"%s run animation uses all eight replacement frames" % direction_name
		)
		for run_frame_index in range(8):
			var run_frame := player_sprite.sprite_frames.get_frame_texture(
				direction_name, run_frame_index
			) as AtlasTexture
			_check(
				run_frame != null
				and run_frame.atlas.resource_path == "res://Assets/player/Koda run.png"
				and run_frame.region.size == Vector2(112, 96),
				"%s frame %d stays on the replacement run sheet"
				% [direction_name, run_frame_index]
			)
		for action_name in action_names:
			var animation_name := StringName(
				"%s_%s" % [action_name, direction_name]
			)
			var action_frame := (
				player_sprite.sprite_frames.get_frame_texture(
					animation_name,
					0
				) as AtlasTexture
			)
			_check(
				player_sprite.sprite_frames.get_frame_count(
					animation_name
				) == 8
				and action_frame != null
				and action_frame.atlas.resource_path
				== "res://Assets/player/idle.png"
				and action_frame.region.size == Vector2(96, 96),
				"%s uses the replacement idle sheet"
				% animation_name
			)
	_check(
		not player_sprite.flip_h,
		"Directional sheet starts without horizontal mirroring"
	)
	var ground_shadow := (
		player.get_node_or_null("GroundShadow") as Sprite2D
	)
	_check(
		ground_shadow != null
		and ground_shadow.texture != null
		and ground_shadow.z_index < player_sprite.z_index
		and ground_shadow.position.y >= 40.0,
		"Koda has a grounded elliptical shadow at paw level"
	)
	if ground_shadow != null:
		var shadow_scale_before_dash := ground_shadow.scale
		var shadow_alpha_before_dash := ground_shadow.modulate.a
		player.is_dashing = true
		player.update_ground_shadow()
		_check(
			ground_shadow.scale.x < shadow_scale_before_dash.x
			and ground_shadow.modulate.a < shadow_alpha_before_dash,
			"Koda's shadow contracts and fades while dashing"
		)
		player.is_dashing = false
		ground_shadow.scale = player.ground_shadow_base_scale
		ground_shadow.modulate.a = player.ground_shadow_base_alpha
	_check(
		player.get_node_or_null("MovementDust") != null
		and player.get_node_or_null("LandingDust") != null,
		"Koda has movement and landing dust emitters"
	)
	var player_light := player.get_node_or_null("PlayerLight") as PointLight2D
	_check(
		player_light != null
		and player_light.texture != null
		and player_light.energy >= 2.2
		and player_light.texture_scale >= 1.85,
		"Koda carries the stronger cool-blue radial light"
	)
	_check(
		player.movement_dust.texture != null
		and player.landing_dust.texture != null
		and player.movement_dust.color_ramp != null
		and player.landing_dust.color_ramp != null
		and player.movement_dust.initial_velocity_max <= 20.0,
		"Dust emitters use subtle gray motes instead of brown debris"
	)
	player.input_direction = Vector2.ZERO
	player.last_direction = Vector2.DOWN
	player.idle_side_direction = &"right"
	player.update_direction_sprite()
	_check(
		player.animated_sprite.animation == &"idle_right"
		and player.animated_sprite.is_playing(),
		"Standing still plays Koda's side-view idle animation"
	)
	player.play_jump_animation(Vector2.UP)
	_check(
		player.animated_sprite.animation == &"jump_right",
		"Every dash direction reuses Koda's clean side-view jump animation"
	)
	player._on_visual_animation_finished()
	player.play_hurt_animation(Vector2(-1, 1))
	_check(
		player.animated_sprite.animation == &"hurt_left"
		and player.animated_sprite.flip_h,
		"Diagonal damage feedback resolves to the mirrored side view"
	)
	player.animated_sprite.stop()
	player._update_visual_action_watchdog(1.0)
	player.update_direction_sprite()
	_check(
		player.visual_action.is_empty()
		and player.animated_sprite.is_playing(),
		"Koda recovers if a one-shot animation stops without its finish signal"
	)
	player.play_attack_animation(Vector2(1, -1))
	_check(
		player.animated_sprite.animation == &"idle_right"
		and not player.animated_sprite.flip_h
		and player.get_node_or_null("AttackAura") != null,
		"Attacks keep the side-view stance and flash a Fleshdrive aura"
	)
	player._on_visual_animation_finished()
	player.velocity = Vector2(100.0, 0.0)
	player.update_movement_dust()
	_check(player.movement_dust.emitting, "Movement starts the foot dust")
	player.input_direction = Vector2.RIGHT
	player.update_direction_sprite()
	_check(
		player.animated_sprite.animation == &"right"
		and not player.animated_sprite.flip_h,
		"Right movement uses the right animation row"
	)
	player.input_direction = Vector2.LEFT
	player.update_direction_sprite()
	_check(
		player.animated_sprite.animation == &"left"
		and player.animated_sprite.flip_h,
		"Left movement mirrors the side-view animation"
	)
	player.idle_side_direction = &"right"
	player.input_direction = Vector2(1.0, -1.0).normalized()
	player.update_direction_sprite()
	var first_diagonal_view := player.animated_sprite.animation
	player.input_direction = Vector2(0.35, -1.0).normalized()
	player.update_direction_sprite()
	var clear_upward_view := player.animated_sprite.animation
	player.input_direction = Vector2(1.0, -1.0).normalized()
	player.update_direction_sprite()
	_check(
		first_diagonal_view == &"right"
		and clear_upward_view == &"right"
		and player.animated_sprite.animation == &"right",
		"All movement directions retain the side-view run cycle"
	)
	player.is_dashing = true
	player.finish_dash()
	_check(player.landing_dust.emitting, "Dash landing starts the dust burst")

	var auto_upgrade := load(
		"res://Resources/Upgrades/autonomic_reflex.tres"
	) as UpgradeData
	_check(
		auto_upgrade.card_texture.resource_path
		== "res://Assets/ui/organs/04_autonomic_reflex.png",
		"Autonomic Reflex uses the user-created card"
	)

	spawner.set_run_progress(0.0)
	var opening_weights: Dictionary = spawner.get_spawn_weights()
	_check(opening_weights.has(&"crawler"), "Crawler is available at run start")
	_check(not opening_weights.has(&"spitter"), "Spitter is locked at run start")
	_check(not opening_weights.has(&"charger"), "Charger is locked at run start")

	spawner.set_run_progress(1.0)
	var end_weights: Dictionary = spawner.get_spawn_weights()
	_check(end_weights.has(&"spitter"), "Spitter joins the late-run mix")
	_check(end_weights.has(&"charger"), "Charger joins the late-run mix")

	var crawler_scene := load(
		"res://Scenes/enemies/crawler.tscn"
	) as PackedScene
	var crawler := crawler_scene.instantiate() as Crawler
	enemies_container.add_child(crawler)
	await process_frame
	crawler.set_physics_process(false)
	crawler.target = player
	crawler.global_position = player.global_position
	player.invulnerability_timer.stop()
	var health_before_contact := player.current_health
	crawler.check_contact_damage()
	_check(
		player.current_health < health_before_contact,
		"Crawler contact damage works without relying on a blocking collision"
	)
	_check(
		crawler.collision_mask == 1
		and (crawler.collision_mask & player.collision_layer) == 0,
		"Enemy bodies pass through Koda instead of forming an inescapable ring"
	)
	player.current_health = player.max_health
	player.invulnerability_timer.stop()
	player.health_changed.emit(player.current_health, player.max_health)
	crawler.queue_free()

	var spitter_scene := load(
		"res://Scenes/enemies/spitter.tscn"
	) as PackedScene
	var spitter := spitter_scene.instantiate() as Spitter
	enemies_container.add_child(spitter)
	spitter.global_position = player.global_position + Vector2(400.0, 0.0)
	await process_frame
	var spitter_frames_fit := true
	var spitter_frame_heights: Array[int] = []
	var spitter_frame_widths: Array[int] = []
	for spitter_frame_index in range(8):
		var spitter_frame_image := (
			spitter.sprite.sprite_frames.get_frame_texture(
				&"normal",
				spitter_frame_index
			).get_image()
		)
		var spitter_bounds := spitter_frame_image.get_used_rect()
		spitter_frame_heights.append(spitter_bounds.size.y)
		spitter_frame_widths.append(spitter_bounds.size.x)
		if (
			spitter_bounds.position.x < 8
			or spitter_bounds.position.y < 8
			or spitter_bounds.end.x > 248
			or spitter_bounds.end.y > 248
		):
			spitter_frames_fit = false
			break
	_check(
		spitter_frames_fit,
		"Flying-spider flight frames do not bleed into neighboring cells"
	)
	_check(
		float(spitter_frame_heights.max())
		/ float(spitter_frame_heights.min()) < 1.32,
		"Flying spider keeps a stable silhouette throughout flight"
	)
	_check(
		spitter_frame_widths.max() <= 240
		and spitter.sprite.position.y < -20.0,
		"Flying spider remains contained and visibly airborne"
	)

	var attack_count_before := attack_container.get_child_count()
	var expected_muzzle := spitter.get_projectile_muzzle_position(
		spitter.global_position.direction_to(player.global_position)
	)
	spitter.attack_cooldown_timer.stop()
	spitter.try_start_attack()
	_check(
		spitter.state == Spitter.State.WINDUP,
		"Spitter enters its readable audio-visual wind-up"
	)
	spitter._fire_projectile()
	_check(
		attack_container.get_child_count() == attack_count_before + 1,
		"Spitter fires a projectile into the attack container"
	)
	var fired_projectile := attack_container.get_child(
		attack_container.get_child_count() - 1
	) as Area2D
	_check(
		fired_projectile != null and fired_projectile.collision_mask == 5,
		"Enemy projectiles target Koda and still impact laboratory geometry"
	)
	_check(
		fired_projectile != null
		and fired_projectile.global_position.distance_to(expected_muzzle) < 1.0,
		"Spitter projectile originates at the flying spider's mirrored head socket"
	)
	spitter.queue_free()

	var boss_projectile_scene := load(
		"res://Scenes/enemies/boss_projectile.tscn"
	) as PackedScene
	var boss_projectile := (
		boss_projectile_scene.instantiate() as Area2D
	)
	_check(
		boss_projectile.collision_mask == 5,
		"Boss projectiles use the same player and environment layers"
	)
	boss_projectile.free()

	for pickup_path in [
		"res://Scenes/pickups/biomass_pickup.tscn",
		"res://Scenes/pickups/red_gem_pickup.tscn",
	]:
		var pickup_scene := load(pickup_path) as PackedScene
		var pickup := pickup_scene.instantiate() as Area2D
		_check(
			pickup.collision_layer == 0 and pickup.collision_mask == 4,
			"Pickup detects Koda on the dedicated player layer"
		)
		pickup.free()

	var charger_scene := load(
		"res://Scenes/enemies/charger.tscn"
	) as PackedScene
	var charger := charger_scene.instantiate() as Charger
	enemies_container.add_child(charger)
	charger.global_position = player.global_position + Vector2(400.0, 80.0)
	await process_frame

	charger._start_windup()
	_check(
		charger.state == Charger.State.WINDUP,
		"Charger enters a telegraphed wind-up"
	)
	_check(
		charger.charge_indicator.visible,
		"Charger ground danger indicator is visible"
	)
	charger._begin_charge()
	_check(charger.state == Charger.State.CHARGE, "Charger enters charge state")
	_check(charger.trail.visible, "Charger trail is visible during charge")
	_check(charger.collision_mask == 1, "Charge ignores other enemies")
	charger._finish_charge()
	_check(
		charger.state == Charger.State.RECOVERY,
		"Charger enters recovery after charge"
	)
	_check(
		charger.collision_mask == 1,
		"Charger remains non-blocking after its charge"
	)
	charger.queue_free()

	for _spawn_index in range(20):
		var spawn_position: Vector2 = spawner._find_spawn_position()
		var camera_center: Vector2 = spawner._get_camera_center()
		_check(
			spawner._is_offscreen(spawn_position, camera_center),
			"Generated enemy spawn is offscreen"
		)

	run_manager.set_manual_pause(true)
	_check(paused, "Manual pause pauses the scene tree")
	_check(
		run_manager.state == RunManager.RunState.PAUSED,
		"Manual pause enters PAUSED state"
	)
	_check(music.playing, "Music continues in the pause menu")
	_check(hud.get_node("PausePanel").visible, "Pause panel is visible")
	_check(
		not hud.player_status_panel.visible,
		"Player status HUD is hidden behind the pause menu"
	)
	_check(
		hud.get_node(
			"PausePanel/CenterContainer/VBoxContainer/SettingsButton"
		) != null,
		"Pause menu includes settings"
	)
	_check(
		hud.get_node(
			"PausePanel/CenterContainer/VBoxContainer/MainMenuButton"
		) != null,
		"Pause menu includes returning to the main menu"
	)
	hud.open_pause_settings()
	_check(
		hud.pause_settings_panel.visible and not hud.pause_main_panel.visible,
		"Pause settings panel opens"
	)
	hud.pause_volume_slider.value = 35.0
	_check(
		hud.pause_volume_value_label.text == "35%",
		"Pause menu includes a working volume control"
	)
	hud.pause_crt_slider.value = 26.0
	hud.pause_bloom_slider.value = 24.0
	hud.pause_chromatic_slider.value = 18.0
	hud.pause_bit_reducer_slider.value = 12.0
	_check(
		hud.pause_crt_value_label.text == "26%"
		and hud.pause_bloom_value_label.text == "24%"
		and hud.pause_chromatic_value_label.text == "18%"
		and hud.pause_bit_reducer_value_label.text == "12%",
		"Pause settings expose all four adjustable effects"
	)
	hud.close_pause_settings()
	_check(
		not hud.pause_settings_panel.visible and hud.pause_main_panel.visible,
		"Pause settings panel closes"
	)
	hud.open_organ_screen_from_pause()
	_check(
		hud.organ_screen.visible
		and hud.organ_screen_from_pause
		and run_manager.pause_overlay_locked,
		"Pause menu opens the organ overview"
	)
	_check(
		not hud.player_status_panel.visible,
		"Player status HUD is hidden on the organ screen"
	)
	_check(music.playing, "Music continues on the organ screen")
	if post_process != null:
		var organ_post_material := post_process.material as ShaderMaterial
		_check(
			is_zero_approx(float(
				organ_post_material.get_shader_parameter(
					&"vignette_strength"
				)
			)),
			"Organ screen suppresses the gameplay vignette"
		)
	_check(
		hud.organ_stats_label.text.contains("DAMAGE"),
		"Organ overview displays player stats"
	)
	hud.close_organ_screen_to_pause()
	_check(
		hud.get_node("PausePanel").visible
		and not run_manager.pause_overlay_locked,
		"Organ overview returns to pause"
	)
	if post_process != null:
		var restored_post_material := post_process.material as ShaderMaterial
		_check(
			float(restored_post_material.get_shader_parameter(
				&"vignette_strength"
			)) >= 0.65,
			"Closing the organ screen restores the vignette"
		)

	run_manager.set_manual_pause(false)
	_check(not paused, "Resume unpauses the scene tree")
	_check(
		hud.player_status_panel.visible,
		"Player status HUD returns after resuming"
	)

	spawner.set_run_progress(1.0)
	var expected_end_interval: float = spawner.minimum_spawn_interval
	if spawner.director_pressure_reason != &"imprint_assist":
		expected_end_interval /= maxf(spawner.director_pressure, 0.45)
	expected_end_interval = maxf(expected_end_interval, 0.12)
	var expected_end_enemy_budget: int = maxi(
		int(float(spawner.maximum_enemies_end) * spawner.director_pressure),
		spawner.starting_maximum_enemies
	)
	_check(
		is_equal_approx(
			spawner.spawn_timer.wait_time,
			expected_end_interval
		),
		"Difficulty curve reaches the director-adjusted end interval"
	)
	_check(
		spawner.maximum_enemies == expected_end_enemy_budget,
		"Difficulty curve reaches the director-adjusted enemy budget"
	)

	run_manager.trigger_rush()
	_check(run_manager.rush_active, "Rush becomes active")
	_check(spawner.rush_active, "Spawner receives rush state")
	var expected_rush_enemy_budget: int = maxi(
		int(float(
			spawner.maximum_enemies_end + spawner.rush_enemy_budget_bonus
		) * spawner.director_pressure),
		spawner.starting_maximum_enemies
	)
	_check(
		spawner.maximum_enemies == expected_rush_enemy_budget,
		"Rush temporarily raises the director-adjusted enemy budget"
	)
	run_manager._end_rush()
	_check(not spawner.rush_active, "Rush restores normal spawn state")

	var first_level_contract := player.get_level_pacing_contract()
	player.level_pacing_clock = (
		player.last_level_up_pacing_time
		+ float(first_level_contract["minimum"])
	)
	player.add_biomass(1000.0)
	_check(
		run_manager.state == RunManager.RunState.LEVEL_UP,
		"Level-up enters LEVEL_UP state"
	)
	_check(music.playing, "Music continues during mutation card selection")
	_check(player.current_level == 2, "First queued level is applied")
	var generated_offer_card := hud.upgrade_cards[0] as TextureButton
	_check(
		generated_offer_card.texture_normal == null
		and generated_offer_card.get_node_or_null("CardSurface") != null,
		"Mutation offers use generated Godot card surfaces instead of stretched card art"
	)
	var generated_surface := generated_offer_card.get_node(
		"CardSurface"
	) as PanelContainer
	var generated_preview := generated_surface.find_child(
		"Preview", true, false
	)
	var generated_description := generated_surface.find_child(
		"Description", true, false
	) as Label
	var generated_next := generated_surface.find_child(
		"NextLevelChange", true, false
	) as Label
	_check(
		generated_preview == null
		and generated_description != null
		and not generated_description.text.is_empty()
		and generated_next != null
		and (
			generated_next.text.contains("NEXT LEVEL")
			or generated_next.text.contains("NEW EFFECT")
		),
		"Mutation cards expose readable text and stats without legacy art previews"
	)

	run_manager.exit_level_up()
	var retained_overflow_biomass := player.current_biomass
	player.confirm_level_up()
	await process_frame
	_check(
		player.current_level == 2
		and player.current_biomass == retained_overflow_biomass,
		"Overflow biomass is retained without bypassing level pacing"
	)
	_check(
		run_manager.state == RunManager.RunState.PLAYING,
		"Overflow biomass returns control between paced level-ups"
	)
	var second_level_contract := player.get_level_pacing_contract()
	player.level_pacing_clock = (
		player.last_level_up_pacing_time
		+ float(second_level_contract["minimum"])
	)
	player._try_trigger_level_up()
	_check(
		player.current_level == 3
		and run_manager.state == RunManager.RunState.LEVEL_UP,
		"Retained biomass triggers the next offer after the pacing gate"
	)

	paused = false
	run_manager.finish_run(true)
	_check(
		run_manager.state == RunManager.RunState.VICTORY,
		"Victory enters VICTORY state"
	)
	_check(hud.get_node("RunEndPanel").visible, "Victory panel is visible")

	paused = false
	game.queue_free()
	await process_frame

	game = packed_game.instantiate()
	root.add_child(game)
	await process_frame
	game.get_node("UI/HUD").complete_onboarding()
	await process_frame

	player = get_first_node_in_group("player") as Koda
	run_manager = get_first_node_in_group("run_manager") as RunManager
	hud = game.get_node("UI/HUD")

	player.current_level = 15
	player.attack_mode = Koda.AttackMode.SEMI_AUTO
	hud.show_level_up_panel(15)

	var auto_attack_index := -1

	for upgrade_index in range(hud.displayed_upgrades.size()):
		var upgrade: UpgradeData = hud.displayed_upgrades[upgrade_index]
		if upgrade.upgrade_id == &"autonomic_reflex":
			auto_attack_index = upgrade_index
			break

	_check(
		auto_attack_index >= 0,
		"Auto-attack evolution is guaranteed at level 15"
	)

	var reflex_cortex := load(
		"res://Resources/Upgrades/reflex_cortex.tres"
	) as UpgradeData
	hud.brain_slot.installed_organ_data = reflex_cortex
	hud.brain_slot.installed_organ.texture = reflex_cortex.card_texture
	hud.brain_slot.installed_organ.show()
	if player.get_upgrade_level(&"reflex_cortex") == 0:
		player.apply_upgrade(&"reflex_cortex")

	await process_frame
	hud.on_upgrade_selected(auto_attack_index)
	_check(
		hud.selected_upgrade_card_index == auto_attack_index
		and hud.upgrade_confirm_button.visible
		and not hud.organ_screen.visible,
		"First card click only selects and exposes the confirmation button"
	)
	hud._accept_selected_upgrade()
	_check(
		hud.organ_screen.visible
		and hud.pending_organ.upgrade_id == &"autonomic_reflex",
		"Auto-attack waits for organ installation"
	)
	_check(
		player.attack_mode == Koda.AttackMode.SEMI_AUTO,
		"Auto-attack is not applied when its card is selected"
	)
	var auto_attack_upgrade: UpgradeData = hud.pending_organ
	_check(
		hud.brain_slot._can_drop_data(Vector2.ZERO, auto_attack_upgrade),
		"Autonomic Reflex can evolve the installed Reflex Cortex"
	)
	hud.brain_slot._drop_data(Vector2.ZERO, auto_attack_upgrade)
	_check(
		hud.replacement_confirmation.visible
		and hud.replacement_yes_button.visible
		and hud.replacement_no_button.visible,
		"Occupied organ slots request a clickable replacement confirmation"
	)
	_check(
		hud.replacement_message.text.contains("REFLEX CORTEX")
		and hud.replacement_message.text.contains("AUTONOMIC REFLEX"),
		"Replacement confirmation names both the old and new organ"
	)
	_check(
		player.attack_mode == Koda.AttackMode.SEMI_AUTO,
		"Organ replacement does not apply before confirmation"
	)
	hud._confirm_organ_replacement()
	_check(
		player.attack_mode == Koda.AttackMode.AUTO,
		"Confirming organ replacement unlocks automatic targeting"
	)
	_check(
		hud.organ_screen.visible
		and hud.pending_organ == reflex_cortex,
		"Replaced organ returns to the pending shelf without closing the screen"
	)
	var second_pending_organ := load(
		"res://Resources/Upgrades/impulse_gland.tres"
	) as UpgradeData
	hud._add_pending_organ(second_pending_organ)
	_check(
		hud.pending_organs.size() == 2
		and hud.pending_previous_button.visible
		and hud.pending_next_button.visible
		and hud.pending_counter_label.text == "2 / 2",
		"Multiple pending organs expose paging controls and a position counter"
	)
	hud._show_previous_pending_organ()
	_check(
		hud.pending_organ == reflex_cortex
		and hud.pending_counter_label.text == "1 / 2",
		"Pending organ paging returns to the previously replaced organ"
	)
	_check(
		player.get_upgrade_level(&"autonomic_reflex") == 1,
		"Installed organs are tracked in the loadout"
	)

	player.apply_upgrade(&"conductive_marrow")
	player.apply_upgrade(&"conductive_marrow")
	hud.refresh_organ_overview()
	await process_frame
	_check(
		player.get_upgrade_level(&"conductive_marrow") == 2,
		"Repeated item choices increase their item level"
	)
	_check(
		hud.item_summary.get_child_count() > 0,
		"Selected items appear in the organ overview"
	)
	# Organ installation intentionally keeps the surgery screen open. Close it
	# before exercising lethal combat damage, just as the player must do.
	hud._on_organ_close_pressed()
	await process_frame
	_check(
		hud.pending_organs.size() == 2
		and hud.pending_organ != null,
		"Pending organ shelf survives closing the surgery screen"
	)

	player.take_damage(player.max_health)
	_check(
		player.visual_action == &"death"
		and String(player.animated_sprite.animation).begins_with("death_")
		and player.animated_sprite.process_mode
		== Node.PROCESS_MODE_ALWAYS,
		"Lethal damage plays Koda's generated death animation"
	)
	_check(
		run_manager.state == RunManager.RunState.DYING,
		"Player death enters the staged death presentation"
	)
	_check(
		hud.get_node("DeathMessage").visible
		and not hud.get_node("RunEndPanel").visible,
		"Red death message appears before the game-over menu"
	)
	_check(
		(
			hud.get_node("DeathMessage/CenterContainer") as Control
		).offset_top <= -140.0,
		"Death message is positioned twenty percent above screen center"
	)
	await create_timer(
		run_manager.death_menu_delay_seconds + 0.1,
		true,
		false,
		true
	).timeout
	_check(
		run_manager.state == RunManager.RunState.REBIRTH,
		"Death presentation transitions to the rebirth sequence"
	)
	var bio_sequence := (
		hud.get_node("BiofabricatorSequence")
		as BiofabricatorSequence
	)
	_check(
		bio_sequence.visible
		and bio_sequence.sequence_state
		== BiofabricatorSequence.SequenceState.PRINTING
		and bio_sequence.terminal_text.text.contains("SUBJECT")
		and bio_sequence.terminal_text.text.contains("#002"),
		"Biofabricator prints the next numbered K0D4 body"
	)
	bio_sequence._process(bio_sequence.printing_duration * 0.1)
	_check(
		bio_sequence.printing_duration <= 2.6
		and bio_sequence.print_blend_sprite.visible
		and bio_sequence.print_blend_sprite.modulate.a > 0.0
		and bio_sequence.print_blend_sprite.modulate.a < 1.0,
		"Biofabricator crossfades print stages at render-frame speed"
	)
	var rebirth_stats_panel := (
		bio_sequence.get_node("RunSummaryPanel") as Control
	)
	var mimichu_portrait_panel := (
		bio_sequence.dialogue_panel.get_node("PortraitFrame") as Control
	)
	var mimichu_dialogue_frame := (
		bio_sequence.dialogue_panel.get_node("DialogueFrame") as Control
	)
	_check(
		rebirth_stats_panel.position.x < 40.0
		and rebirth_stats_panel.position.y >= 340.0
		and rebirth_stats_panel.size.x <= 230.0
		and not bio_sequence.dialogue_panel.visible
		and bio_sequence.terminal_panel.visible
		and rebirth_stats_panel.visible
		and bio_sequence.printer_glass.visible,
		"Fabricator data panels stay readable while the body is printing"
	)
	_check(
		bio_sequence.run_summary_label.text.contains("LAST BODY")
		and bio_sequence.lifetime_summary_label.text.contains("LIFETIME")
		and (
			bio_sequence.run_summary_label.get_parent()
			is VBoxContainer
		),
		"Biofabricator statistics use a compact middle column"
	)
	bio_sequence._finish_printing()
	var idle_first_frame := (
		bio_sequence.idle_sprite.sprite_frames.get_frame_texture(&"idle", 0)
		as AtlasTexture
	)
	var print_first_frame := (
		bio_sequence.print_sprite.sprite_frames.get_frame_texture(&"print", 0)
		as AtlasTexture
	)
	_check(
		bio_sequence.dialogue_panel.visible
		and not bio_sequence.print_sprite.visible
		and bio_sequence.idle_sprite.visible
		and bio_sequence.idle_sprite.is_playing()
		and bio_sequence.idle_sprite.sprite_frames.get_frame_count(
			&"idle"
		) == 14
		and bio_sequence.terminal_panel.visible
		and rebirth_stats_panel.visible
		and bio_sequence.printer_glass.visible
		and idle_first_frame != null
		and idle_first_frame.atlas.resource_path
		== "res://Assets/ui/screens/koda_printer_idle_8f.png"
		and print_first_frame != null
		and print_first_frame.atlas.resource_path
		== "res://Assets/ui/screens/koda_body_print_6f.png"
		and bio_sequence.idle_sprite.position == Vector2(425.0, 470.0),
		"Fabricator restores Koda's dedicated print animation and position"
	)
	_check(
		mimichu_portrait_panel.position.x >= 1000.0
		and mimichu_dialogue_frame.position.x >= 790.0
		and mimichu_portrait_panel.get_global_rect().end.y
		<= mimichu_dialogue_frame.get_global_rect().position.y
		and mimichu_portrait_panel.get_global_rect().end.x
		<= bio_sequence.get_viewport_rect().size.x
		and mimichu_dialogue_frame.get_global_rect().end.x
		<= bio_sequence.get_viewport_rect().size.x
		and mimichu_dialogue_frame.get_global_rect().end.y
		<= bio_sequence.get_viewport_rect().size.y,
		"Mimichu and wrapped dialogue use the clear right-side column"
	)
	bio_sequence.dialogue_panel.continue_button.emit_signal("pressed")
	_check(
		not bio_sequence.dialogue_panel.is_typing,
		"Clickable continue button completes the current typewriter line"
	)
	bio_sequence.dialogue_panel.continue_button.emit_signal("pressed")
	_check(
		bio_sequence.dialogue_panel.current_entry_index == 1
		and bio_sequence.dialogue_panel.is_typing,
		"Clickable continue button advances to the next dialogue line"
	)
	bio_sequence.dialogue_panel.continue_button.emit_signal("pressed")
	bio_sequence.dialogue_panel.continue_button.emit_signal("pressed")
	await process_frame
	var first_rebirth_choice := (
		bio_sequence.dialogue_panel.choices_container.get_child(0)
		as Button
	)
	var second_rebirth_choice := (
		bio_sequence.dialogue_panel.choices_container.get_child(1)
		as Button
	)
	var third_rebirth_choice := (
		bio_sequence.dialogue_panel.choices_container.get_child(2)
		as Button
	)
	_check(
		bio_sequence.dialogue_panel.choices_container.get_child_count()
		== 3
		and first_rebirth_choice.text.contains("START NEW RUN")
		and second_rebirth_choice.text.contains("FLESH TREE")
		and third_rebirth_choice.text.contains("MAIN MENU")
		and not first_rebirth_choice.get_global_rect().intersects(
			second_rebirth_choice.get_global_rect()
		)
		and not second_rebirth_choice.get_global_rect().intersects(
			third_rebirth_choice.get_global_rect()
		),
		"Rebirth dialogue exposes all three requested actions"
	)
	_check(
		bio_sequence.dialogue_panel.animated_portrait.sprite_frames
		.has_animation(&"idle")
		and bio_sequence.dialogue_panel.animated_portrait.sprite_frames
		.has_animation(&"talk"),
		"Biofabricator dialogue uses Mimichu idle and talk animation"
	)
	if audio_effects != null:
		_check(
			audio_effects.call("get_play_count", &"spitter_windup") > 0
			and audio_effects.call("get_play_count", &"spitter_fire") > 0
			and audio_effects.call("get_play_count", &"charger_windup") > 0
			and audio_effects.call("get_play_count", &"charger_charge") > 0
			and audio_effects.call("get_play_count", &"charger_impact") > 0,
			"Enemy telegraph, attack and impact sounds are triggered"
		)
		_check(
			audio_effects.call("get_play_count", &"rush_warning") > 0
			and audio_effects.call("get_play_count", &"level_up") > 0
			and audio_effects.call("get_play_count", &"card_reveal") > 0
			and audio_effects.call("get_play_count", &"card_select") > 0
			and audio_effects.call("get_play_count", &"organ_install") > 0,
			"Rush, level-up, card and organ sounds are triggered"
		)
		_check(
			audio_effects.call("get_play_count", &"player_hurt") > 0
			and audio_effects.call("get_play_count", &"player_death") > 0
			and audio_effects.call("get_play_count", &"defeat") > 0,
			"Player damage, death and run-end sounds are triggered"
		)

	hud.on_return_to_main_menu_pressed()
	await process_frame
	await process_frame
	_check(
		current_scene != null and current_scene.name == "MainMenu",
		"Run-end action returns to the main menu"
	)

	paused = false
	settings.set_master_volume(original_master_volume)
	settings.set_crt_intensity(original_crt)
	settings.set_bloom_intensity(original_bloom)
	settings.set_chromatic_aberration(original_chromatic)
	settings.set_bit_reduction(original_bit_reduction)
	meta_progression.save_path = original_meta_save_path
	meta_progression._load_progression()
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(smoke_meta_save_path)
	)
	if is_instance_valid(game):
		game.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	failure_count += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failure_count == 0:
		print("SMOKE TEST PASSED")
		quit(0)
		return

	push_error("SMOKE TEST FAILED: %d failure(s)" % failure_count)
	quit(1)
