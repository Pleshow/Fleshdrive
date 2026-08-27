extends SceneTree


var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.collision_layer = 4
	player.collision_mask = 0
	var player_shape := CollisionShape2D.new()
	var player_circle := CircleShape2D.new()
	player_circle.radius = 16.0
	player_shape.shape = player_circle
	player.add_child(player_shape)
	world.add_child(player)

	var pickup_scene := load(
		"res://Scenes/pickups/red_gem_pickup.tscn"
	) as PackedScene
	var pickup := pickup_scene.instantiate() as RedGemPickup
	pickup.attraction_radius = 0.0
	# Keep this collision regression isolated from persistent metaprogression.
	pickup.gem_value = 0
	world.add_child(pickup)
	pickup.activate_at(player.global_position + Vector2(64.0, 0.0))
	await process_frame
	var pickup_shape := pickup.get_node(
		"CollisionShape2D"
	) as CollisionShape2D
	_check(
		is_instance_valid(pickup.coin_visual)
		and pickup.coin_visual.scale.x <= RedGemPickup.COIN_VISUAL_SCALE
		and pickup.ground_shadow.visible
		and is_equal_approx(
			(pickup_shape.shape as CircleShape2D).radius,
			7.5
		),
		"Blood Memory coin and collision are half-sized with a spinning shadow"
	)
	var initial_shadow_width := pickup.ground_shadow.scale.x
	await create_timer(0.18).timeout
	_check(
		not is_equal_approx(
			pickup.ground_shadow.scale.x,
			initial_shadow_width
		),
		"Blood Memory shadow changes width with the coin rotation"
	)
	pickup.global_position = player.global_position

	await physics_frame
	await physics_frame
	_check(
		pickup.collected_once,
		"Blood Memory can disable collision from a real body_entered callback"
	)
	_check(
		not pickup.monitoring and not pickup.monitorable,
		"Blood Memory applies deferred Area2D monitoring changes"
	)

	pickup._stop_coin_visual()
	pickup.free()
	world.free()
	await process_frame
	if failures == 0:
		print("RED GEM PHYSICS SAFETY TEST PASSED")
		quit(0)
	else:
		push_error("RED GEM PHYSICS SAFETY TEST FAILED: %d" % failures)
		quit(1)
