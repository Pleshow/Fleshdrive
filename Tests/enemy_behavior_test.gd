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
	var crawler_frame := crawler_sprite.sprite_frames.get_frame_texture(
		&"walk", 0
	)
	_check(
		is_equal_approx(crawler.move_speed, 65.0),
		"Dusk Garden crawler uses the authored fodder movement speed"
	)
	_check(
		crawler_frame.resource_path.ends_with(
			"Assets/enemies/crawler/Snake crawler/walk/east/frame_000.png"
		)
		and crawler_sprite.sprite_frames.get_frame_count(&"walk") == 9
		and crawler_sprite.sprite_frames.get_frame_count(&"attack") == 9
		and crawler_sprite.sprite_frames.get_frame_count(&"death") == 9,
		"Crawler uses the current Dusk Garden frame animations"
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
	var spitter_frame := spitter_sprite.sprite_frames.get_frame_texture(
		&"normal", 0
	)
	_check(
		spitter_frame != null
		and spitter_frame.resource_path.ends_with("frame_000.png")
		and spitter_sprite.sprite_frames.get_frame_count(&"normal") == 9
		and spitter_sprite.sprite_frames.get_frame_count(&"windup") == 9
		and spitter_sprite.sprite_frames.get_frame_count(&"death") == 9
		and is_equal_approx(spitter.projectile_speed, 150.0),
		"Ranged enemy uses the current Dusk Garden flying-spider frames"
	)
	var spitter_image := spitter_frame.get_image() if spitter_frame != null else null
	var visible_pixels := 0
	var bright_pixels := 0
	if spitter_image != null:
		for pixel_y in range(spitter_image.get_height()):
			for pixel_x in range(spitter_image.get_width()):
				var pixel := spitter_image.get_pixel(pixel_x, pixel_y)
				if pixel.a > 0.1:
					visible_pixels += 1
					if pixel.get_luminance() > 0.35:
						bright_pixels += 1
	_check(
		visible_pixels > 200 and bright_pixels > 20,
		"Flying spider retains a readable silhouette and highlights"
	)
	var spitter_shadow := spitter.get_node("GroundShadow") as Sprite2D
	_check(
		spitter_shadow != null
		and spitter_sprite.position.y < spitter_shadow.position.y
		and spitter_shadow.modulate.a > 0.1,
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
	var charger_frame := charger_sprite.sprite_frames.get_frame_texture(
		&"normal",
		0
	)
	_check(
		charger_frame.resource_path
		== "res://Assets/enemies/charger/charger v2/run/east/frame_000.png"
		and charger_sprite.sprite_frames.get_frame_count(&"normal") == 8
		and charger_sprite.sprite_frames.get_frame_count(&"windup") == 1
		and charger_sprite.sprite_frames.get_frame_count(&"charge") == 8
		and charger_sprite.sprite_frames.get_frame_count(&"death") == 9,
		"Charger uses the complete v2 run, windup, charge and death set"
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
