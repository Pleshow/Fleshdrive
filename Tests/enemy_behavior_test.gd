extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_scene := load("res://Scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.get_node("UI/HUD").complete_onboarding()
	await process_frame

	var player := get_first_node_in_group("player") as Koda
	var spawner := game.get_node("EnemySpawner")
	var enemies := game.get_node("Entities/Enemies")
	var attacks := game.get_node("Entities/Attacks")
	spawner.stop_spawning()

	var crawler_scene := load(
		"res://Scenes/enemies/crawler.tscn"
	) as PackedScene
	var crawler := crawler_scene.instantiate() as Crawler
	enemies.add_child(crawler)
	var crawler_sprite := crawler.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var crawler_frame := (
		crawler_sprite.sprite_frames.get_frame_texture(&"walk", 0)
		as AtlasTexture
	)
	_check(
		is_equal_approx(crawler.move_speed, 88.0),
		"Crawler movement speed is reduced by twenty percent"
	)
	_check(
		crawler_frame.atlas.resource_path
		== "res://Assets/enemies/crawler/walk.png"
		and crawler_sprite.sprite_frames.get_frame_count(&"walk") == 8
		and crawler_sprite.sprite_frames.get_frame_count(&"attack") == 8,
		"Crawler uses the current eight-frame mutant-animal animation strip"
	)
	_check(
		crawler.get_node_or_null("GroundShadow") != null,
		"Crawler has a grounded elliptical shadow"
	)
	var pickups := game.get_node("Entities/Pickups")
	var pickup_count_before := pickups.get_child_count()
	crawler.drop_biomass()
	_check(
		pickups.get_child_count() == pickup_count_before,
		"Biomass Area2D insertion is deferred outside physics queries"
	)
	await process_frame
	_check(
		pickups.get_child_count() == pickup_count_before + 1,
		"Deferred biomass pickup is inserted on the next frame"
	)
	crawler.queue_free()
	await process_frame

	var spitter_scene := load(
		"res://Scenes/enemies/spitter.tscn"
	) as PackedScene
	var spitter := spitter_scene.instantiate() as Spitter
	enemies.add_child(spitter)
	spitter.global_position = player.global_position + Vector2(400.0, 0.0)
	var spitter_sprite := spitter.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var spitter_frame := (
		spitter_sprite.sprite_frames.get_frame_texture(&"normal", 0)
		as AtlasTexture
	)
	_check(
		spitter_frame.atlas.resource_path
		== "res://Assets/enemies/spitter/flying_spider_atlas.png"
		and spitter_sprite.sprite_frames.get_frame_count(&"normal") == 8
		and spitter_sprite.sprite_frames.get_frame_count(&"windup") == 4
		and is_equal_approx(spitter.projectile_speed, 201.6),
		"Ranged enemy uses the generated flying-spider animation atlas"
	)
	var spitter_image := spitter_frame.get_image()
	var luminous_cyan_pixels := 0
	for pixel_y in range(spitter_image.get_height()):
		for pixel_x in range(spitter_image.get_width()):
			var pixel := spitter_image.get_pixel(pixel_x, pixel_y)
			if (
				pixel.a > 0.95
				and pixel.g > pixel.r * 1.22
				and pixel.b > pixel.r * 1.14
			):
				luminous_cyan_pixels += 1
	_check(
		luminous_cyan_pixels > 70,
		"Flying spider retains readable cyan eyes and weapon highlights"
	)
	_check(
		spitter.get_node_or_null("GroundShadow") != null
		and spitter_sprite.position.y < -20.0
		and spitter.get_node("GroundShadow").modulate.a < 0.5,
		"Flying spider hovers above a soft aerial shadow"
	)

	for _frame in range(65):
		await physics_frame

	_check(
		attacks.get_child_count() > 0,
		"Spitter completes wind-up and fires during live physics"
	)
	spitter.queue_free()

	for child in attacks.get_children():
		child.queue_free()

	await process_frame

	var charger_scene := load(
		"res://Scenes/enemies/charger.tscn"
	) as PackedScene
	var charger := charger_scene.instantiate() as Charger
	enemies.add_child(charger)
	charger.global_position = player.global_position + Vector2(400.0, 80.0)
	var charger_sprite := charger.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var charger_frame := (
		charger_sprite.sprite_frames.get_frame_texture(&"normal", 0)
		as AtlasTexture
	)
	_check(
		charger_frame.atlas.resource_path
		== "res://Assets/enemies/charger/charger_pixel_atlas.png"
		and charger_sprite.sprite_frames.get_frame_count(&"normal") == 4
		and charger_sprite.sprite_frames.get_frame_count(&"windup") == 4
		and charger_sprite.sprite_frames.get_frame_count(&"charge") == 4,
		"Charger uses the new animated mutant-animal pixel atlas"
	)
	_check(
		charger.get_node_or_null("GroundShadow") != null,
		"Charger has a grounded elliptical shadow"
	)

	for _frame in range(68):
		await physics_frame

	_check(
		charger.state == Charger.State.CHARGE,
		"Charger completes telegraph and begins a live charge"
	)
	_check(charger.trail.visible, "Live charge displays its trail")
	_check(
		charger.charge_indicator.visible == false,
		"Charge hides the telegraph after wind-up"
	)

	paused = false
	game.queue_free()
	await process_frame

	if failure_count == 0:
		print("ENEMY BEHAVIOR TEST PASSED")
		quit(0)
		return

	push_error("ENEMY BEHAVIOR TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	failure_count += 1
	push_error("FAIL: " + message)
