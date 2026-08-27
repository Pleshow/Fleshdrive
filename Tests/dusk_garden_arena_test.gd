extends SceneTree


const GAME_SCENE := preload("res://Scenes/game.tscn")
const MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const CRAWLER_SCENE := preload("res://Scenes/enemies/crawler.tscn")
const SPITTER_SCENE := preload("res://Scenes/enemies/spitter.tscn")
const PROJECTILE_SCENE := preload("res://Scenes/enemies/spitter_projectile.tscn")
const BIOMASS_SCENE := preload("res://Scenes/pickups/biomass_pickup.tscn")

var failure_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flow := root.get_node_or_null("GameFlow")
	_check(flow != null, "GameFlow is available for the Dusk Garden scope lock")
	if flow == null:
		_finish()
		return
	var original_arena := StringName(flow.get("selected_arena_id"))
	flow.call("set_selected_arena", &"dusk_garden")

	var menu := MENU_SCENE.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(
		StringName(flow.get("selected_arena_id")) == &"dusk_garden"
		and menu.get_node_or_null("%ArenaOption") == null,
		"Main menu keeps Dusk Garden scope-locked without an arena selector"
	)
	menu.queue_free()
	await process_frame
	paused = false

	var game := GAME_SCENE.instantiate() as GameArenaController
	root.add_child(game)
	await process_frame
	await process_frame
	var arena := game.get_node_or_null("Arena") as DuskGardenArena
	var player := game.get_node_or_null("Entities/Koda") as Koda
	var spawner := game.get_node_or_null("EnemySpawner")
	var run_manager := game.get_node_or_null("RunManager") as RunManager
	_check(arena != null, "Selected run instantiates Dusk Garden")
	if arena == null or player == null or spawner == null:
		_cleanup(game, flow, original_arena)
		return
	spawner.call("stop_spawning")
	if run_manager != null and run_manager.state == RunManager.RunState.OPERATION:
		run_manager.exit_operation()
	paused = false
	_check(
		bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))
		and int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", 0)) == 1,
		"Physics interpolation and VSync keep physics-driven motion paced at high refresh rates"
	)

	var map_sprite := arena.get_node_or_null("MapComposite") as Sprite2D
	var walls := arena.get_node_or_null("GardenBoundary") as StaticBody2D
	var y_sorted_props := arena.get_node_or_null("YSortedProps") as Node2D
	_check(
		map_sprite != null
		and map_sprite.texture.resource_path
		== "res://Assets/environment/dusk_garden_map.png"
		and map_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"The authored grassy composite renders at nearest-neighbor resolution"
	)
	_check(
		walls != null
		and walls.get_child_count() == 4
		and arena.get_play_bounds().size == Vector2(2432.0, 1024.0),
		"The 2560x1440 field has four solid borders and a roomy combat rectangle"
	)
	_check(
		arena.y_sort_enabled
		and y_sorted_props != null
		and y_sorted_props.y_sort_enabled
		and y_sorted_props.get_child_count() == 9
		and y_sorted_props.get_child(0).is_in_group("arena_occluder"),
		"Grass and trees use root-level Y-sort bases for front/behind traversal"
	)

	var player_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var player_texture := player_sprite.sprite_frames.get_frame_texture(
		&"idle_right",
		0
	)
	var jump_texture := player_sprite.sprite_frames.get_frame_texture(
		&"jump_right",
		0
	)
	var jump_duration := (
		float(player_sprite.sprite_frames.get_frame_count(&"jump_right"))
		/ player_sprite.sprite_frames.get_animation_speed(&"jump_right")
	)
	_check(
		player_texture.resource_path.contains("Assets/player/Koda_32x32")
		and player_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and player_sprite.material is CanvasItemMaterial
		and player_sprite.scale == Vector2.ONE
		and jump_texture.resource_path.contains("Koda_32x32/jumping/east")
		and is_equal_approx(player_sprite.sprite_frames.get_animation_speed(&"jump_right"), 18.0)
		and jump_duration >= 0.27
		and jump_duration <= 0.29,
		"Koda uses native-scale crisp pixel art and a readable 18 FPS jump"
	)
	var grounded_sprite_position := player_sprite.position
	player.is_dashing = true
	player.dash_direction = Vector2.RIGHT
	player.dash_elapsed = player.dash_duration * 0.5
	player.update_dash_movement(0.0)
	_check(
		player_sprite.position.y <= grounded_sprite_position.y - 11.5,
		"Koda's dash animation follows a visible airborne arc"
	)
	player.play_jump_animation(Vector2.RIGHT)
	player.finish_dash()
	_check(
		player_sprite.position == grounded_sprite_position
		and player.visual_action == &"jump",
		"Koda lands at ground height while the authored jump animation finishes"
	)
	player._on_visual_animation_finished()
	var player_light := player.get_node_or_null("PlayerLight") as PointLight2D
	_check(
		player_light != null
		and not player_light.visible
		and not (player.get_node("LightningLine") as Line2D).antialiased
		and (player.get_node("GroundShadow") as Sprite2D).texture.get_width() == 16
		and is_equal_approx(
			(player.get_node("GroundShadow") as Sprite2D).position.y,
			7.0
		),
		"Dusk Garden keeps Koda's crisp shadow directly under the native-scale paws"
	)

	var crawler := CRAWLER_SCENE.instantiate() as Crawler
	game.add_child(crawler)
	var crawler_texture := crawler.sprite.sprite_frames.get_frame_texture(&"walk", 0)
	_check(
		crawler_texture.resource_path.contains("Snake crawler/walk")
		and crawler.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and is_equal_approx(
			(crawler.get_node("GroundShadow") as Sprite2D).position.y,
			9.0
		),
		"Crawler uses the supplied snake animation with its shadow underfoot"
	)
	var spitter := SPITTER_SCENE.instantiate() as Spitter
	game.add_child(spitter)
	var spitter_texture := spitter.sprite.sprite_frames.get_frame_texture(&"normal", 0)
	_check(
		spitter_texture.resource_path.contains("enemies/spitter/Spider/flying")
		and not spitter.aim_line.antialiased
		and is_equal_approx(spitter.ground_shadow.position.y, 34.0)
		and is_equal_approx(spitter.ground_shadow_base_scale.x, 3.0)
		and spitter.ground_shadow.scale.x >= 3.0,
		"Flying spider keeps an intentional gap above a body-sized pixel shadow"
	)

	var universal_pool: Array[UpgradeData] = []
	UpgradeRegistry.append_universal_mutations(universal_pool)
	var shed_skin_upgrade: UpgradeData
	for upgrade in universal_pool:
		if upgrade.upgrade_id == &"shed_skin":
			shed_skin_upgrade = upgrade
			break
	_check(
		shed_skin_upgrade != null and shed_skin_upgrade.max_level == 3,
		"Shed Skin exposes three levels so the electric decoy can grow with the build"
	)
	crawler.set_physics_process(false)
	spitter.set_physics_process(false)
	crawler.global_position = player.global_position + Vector2(48.0, 0.0)
	crawler.target = player
	player.upgrade_levels[&"shed_skin"] = 1
	var universal_runtime := player.weapon_system.universal_mutations
	var timed_decoy := universal_runtime._spawn_decoy()
	var decoy_visual := timed_decoy.get_node_or_null("KodaIdle") as AnimatedSprite2D
	var decoy_texture: Texture2D
	if decoy_visual != null:
		decoy_texture = decoy_visual.sprite_frames.get_frame_texture(
			decoy_visual.animation,
			0
		)
	_check(
		timed_decoy != null
		and decoy_visual != null
		and decoy_visual.is_playing()
		and decoy_texture != null
		and decoy_texture.resource_path.contains("Koda_32x32/Idle state")
		and crawler.target == timed_decoy,
		"Shed Skin leaves a visible animated Koda idle decoy that attracts enemies"
	)
	await create_timer(1.58).timeout
	await process_frame
	_check(
		not is_instance_valid(timed_decoy) and crawler.target == player,
		"Level-one Shed Skin expires cleanly and restores distracted targets"
	)
	player.upgrade_levels[&"shed_skin"] = 2
	var charged_decoy := universal_runtime._spawn_decoy()
	crawler.global_position = charged_decoy.global_position + Vector2(28.0, 0.0)
	var health_before_discharge := crawler.current_health
	universal_runtime._discharge_decoy(charged_decoy, [crawler], 2)
	_check(
		crawler.current_health < health_before_discharge
		and float(charged_decoy.get_meta("blast_damage", 0.0)) > 0.0,
		"Higher-level Shed Skin damages its lured enemies with a scaling electric discharge"
	)
	universal_runtime.active_decoys.erase(charged_decoy)
	charged_decoy.queue_free()
	crawler.target = player
	player.upgrade_levels.erase(&"shed_skin")

	var biomass := BIOMASS_SCENE.instantiate() as BiomassPickup
	game.add_child(biomass)
	var biomass_texture := biomass.sprite.sprite_frames.get_frame_texture(&"pulse", 0)
	var biomass_image := biomass_texture.get_image()
	_check(
		biomass_texture.resource_path.ends_with("small_biomass_transparent.png")
		and biomass_image.get_pixel(0, 0).a == 0.0
		and biomass_image.get_pixel(1, 0).a == 0.0
		and is_equal_approx(biomass.original_scale.x, 0.65)
		and biomass.sprite.material is ShaderMaterial
		and bool((biomass.sprite.material as ShaderMaterial).get_shader_parameter(
			"force_electric_blue"
		)),
		"Biomass is compact, transparent and forced onto the electric-blue ramp"
	)

	var projectile := PROJECTILE_SCENE.instantiate() as SpitterProjectile
	game.add_child(projectile)
	var orb_texture := projectile.projectile_sprite.sprite_frames.get_frame_texture(
		&"flight",
		0
	)
	var orb_image := orb_texture.get_image()
	_check(
		orb_texture.get_width() == 16
		and orb_texture.get_height() == 16
		and orb_image.get_pixel(8, 1).is_equal_approx(Color("ff0546"))
		and is_equal_approx(projectile.projectile_sprite.scale.x, 1.0)
		and is_equal_approx(
			(projectile.collision_shape.shape as CircleShape2D).radius,
			5.5
		)
		and is_equal_approx(projectile.projectile_light.texture_scale, 1.1)
		and projectile.projectile_light.color.is_equal_approx(Color("ff0546"))
		and projectile.projectile_light.energy <= 0.35,
		"Spitter projectile is a larger outlined hostile-crimson pixel orb"
	)

	var post_filter := game.get_node_or_null("PostProcess/ScreenFilter") as PostProcessController
	_check(
		post_filter != null
		and post_filter.minimalist_pixel_mode
		and is_zero_approx(float(post_filter.shader_material.get_shader_parameter("bloom_intensity")))
		and is_zero_approx(float(post_filter.shader_material.get_shader_parameter("chromatic_aberration"))),
		"Minimalist profile disables bloom blur and chromatic color smearing"
	)

	spawner.set("spawning_enabled", false)
	var warning := spawner.call(
		"_create_spawn_warning", player.global_position, &"charger"
	) as Node2D
	_check(
		is_equal_approx(float(spawner.get("spawn_warning_duration")), 1.0)
		and warning != null
		and warning.is_in_group("spawn_warnings")
		and warning.get_child_count() == 4,
		"Every scheduled enemy spawn reserves a one-second red-X warning"
	)
	if is_instance_valid(warning):
		warning.queue_free()
	_check(
		run_manager != null
		and is_equal_approx(run_manager.run_duration_seconds, 720.0)
		and is_equal_approx(run_manager.boss_spawn_time_seconds, 660.0),
		"Dusk Garden preserves the existing run and Warden timing"
	)

	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("clear_all")
	player.current_health = player.max_health - 1.0
	player.heal(1.0)
	var heal_effect: AnimatedSprite2D
	for child in player.get_children():
		var candidate := child as AnimatedSprite2D
		if (
			candidate != null
			and candidate != player_sprite
			and candidate.animation == &"play"
		):
			heal_effect = candidate
			break
	_check(
		heal_effect != null
		and heal_effect.get_parent() == player
		and heal_effect.position == Vector2(0.0, -12.0),
		"Healing VFX stays parented to Koda for its full animation"
	)
	if visual_effects != null:
		visual_effects.call("clear_all")
	await process_frame
	var electric_effect: AnimatedSprite2D
	if visual_effects != null:
		electric_effect = visual_effects.call(
			"play",
			&"electric_impact",
			player.global_position + Vector2(80.0, 0.0),
			1.0
		) as AnimatedSprite2D
	_check(
		electric_effect != null
		and electric_effect.material == null
		and get_nodes_in_group("electric_flash").is_empty(),
		"Lightning VFX keeps authored colors without a soft radial flash"
	)

	player.global_position = Vector2(-100.0, -100.0)
	arena._enforce_walkable_actors()
	_check(
		arena.is_walkable_position(player.global_position, 18.0),
		"Arena recovery returns displaced actors to the walkable field"
	)

	crawler.queue_free()
	spitter.queue_free()
	biomass.queue_free()
	projectile.queue_free()
	_cleanup(game, flow, original_arena)


func _cleanup(game: Node, flow: Node, original_arena: StringName) -> void:
	paused = false
	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("clear_all")
	if is_instance_valid(game):
		game.queue_free()
	flow.call("set_selected_arena", original_arena)
	await process_frame
	_finish()


func _finish() -> void:
	if failure_count == 0:
		print("DUSK GARDEN ARENA TEST PASSED")
		quit(0)
		return
	push_error("DUSK GARDEN ARENA TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)
