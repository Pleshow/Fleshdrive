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
