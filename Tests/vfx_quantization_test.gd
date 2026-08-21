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


func _is_unshaded(item: CanvasItem) -> bool:
	return (
		item != null
		and item.material is CanvasItemMaterial
		and (item.material as CanvasItemMaterial).light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED
	)


func _run() -> void:
	root.get_node("GameFlow").call("set_selected_arena", &"dusk_garden")
	var game_scene := load("res://Scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	paused = false
	game.get_node("EnemySpawner").stop_spawning()
	var player := game.get_node("Entities/Koda") as Koda
	var weapons := player.get_node("WeaponSystem") as PlayerWeaponSystem
	_check(
		_is_unshaded(player.attack_range_indicator),
		"Koda procedural range VFX ignores Dusk Garden world darkness"
	)
	_check(
		weapons.procedural_vfx_material.light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED,
		"Weapon telegraphs and procedural combat VFX share an unshaded material"
	)
	_check(
		weapons.thunder_god.unshaded_vfx_material.light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED
		and weapons.volt_hound.unshaded_vfx_material.light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED
		and weapons.universal_mutations.unshaded_vfx_material.light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED,
		"All build runtimes protect generated VFX from black quantization"
	)

	var charger := (load("res://Scenes/enemies/charger.tscn") as PackedScene).instantiate() as Charger
	root.add_child(charger)
	_check(
		_is_unshaded(charger.charge_indicator)
		and _is_unshaded(charger.charge_indicator_outline)
		and _is_unshaded(charger.health_bar_fill)
		and _is_unshaded(charger.readability_rim)
		and charger.impact_animation.material is ShaderMaterial,
		"Charger indicator, rim and generated HP bar remain readable"
	)

	var spitter := (load("res://Scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Spitter
	root.add_child(spitter)
	_check(_is_unshaded(spitter.aim_line), "Spitter aim telegraph cannot quantize to black")

	var warden := (load("res://Scenes/enemies/visceral_warden.tscn") as PackedScene).instantiate() as VisceralWarden
	root.add_child(warden)
	_check(
		_is_unshaded(warden.aim_line)
		and _is_unshaded(warden.charge_line)
		and _is_unshaded(warden.volley_area)
		and _is_unshaded(warden.charge_area)
		and _is_unshaded(warden.slam_telegraph)
		and _is_unshaded(warden.slam_fill),
		"Boss telegraphs bypass world lighting consistently"
	)

	var memory := (load("res://Scenes/pickups/red_gem_pickup.tscn") as PackedScene).instantiate() as RedGemPickup
	root.add_child(memory)
	var memory_safe := true
	for child in memory.blood_drop_visual.get_children():
		if child is CanvasItem and not _is_unshaded(child):
			memory_safe = false
	_check(memory_safe, "Blood Memory drop and blue outline remain palette-readable")

	var projectile_paths := [
		"res://Scenes/player/magma_spear_projectile.tscn",
		"res://Scenes/player/fireball_projectile.tscn",
		"res://Scenes/enemies/boss_projectile.tscn",
	]
	var projectile_safe := true
	for projectile_path in projectile_paths:
		var projectile := (load(projectile_path) as PackedScene).instantiate() as Node2D
		root.add_child(projectile)
		var sprite := projectile.get_node_or_null("Sprite") as CanvasItem
		if sprite == null:
			sprite = projectile.get_node_or_null("ProjectileSprite") as CanvasItem
		projectile_safe = projectile_safe and _is_unshaded(sprite)
		projectile.queue_free()
	var arc_spear := (load("res://Scenes/player/arc_spear_projectile.tscn") as PackedScene).instantiate() as ArcSpearProjectile
	root.add_child(arc_spear)
	var arc_material := arc_spear.sprite.material as ShaderMaterial
	projectile_safe = (
		projectile_safe
		and arc_material != null
		and bool(arc_material.get_shader_parameter("force_electric_blue"))
	)
	arc_spear.queue_free()
	_check(projectile_safe, "Player and boss projectiles cannot be darkened into black silhouettes")

	var static_strike := root.get_node("VisualEffects").call(
		"play", &"static_strike", Vector2.ZERO, 0.56
	) as AnimatedSprite2D
	_check(
		static_strike is AnimatedSprite2D
		and static_strike.material is ShaderMaterial
		and bool((static_strike.material as ShaderMaterial).get_shader_parameter("force_electric_blue")),
		"Real Kinetic Charge lightning asset uses forced electric-blue emission"
	)

	game.queue_free()
	charger.queue_free()
	spitter.queue_free()
	warden.queue_free()
	memory.queue_free()
	await process_frame
	if failures == 0:
		print("VFX QUANTIZATION TEST PASSED")
	quit(1 if failures > 0 else 0)
