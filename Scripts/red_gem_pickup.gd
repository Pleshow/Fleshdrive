class_name RedGemPickup
extends Area2D


signal collected

@export var attraction_radius: float = 150.0
@export var attraction_speed: float = 360.0
@export var gem_value: int = 1

var player: Node2D
var collected_once: bool = false
var blood_drop_visual: Node2D
var unshaded_vfx_material: CanvasItemMaterial


func _ready() -> void:
	unshaded_vfx_material = CanvasItemMaterial.new()
	unshaded_vfx_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_install_blood_drop_visual()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	prepare_for_reuse()


func prepare_for_reuse() -> void:
	collected_once = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	monitoring = true
	monitorable = true
	show()
	if is_instance_valid(blood_drop_visual):
		blood_drop_visual.show()


func prepare_for_pool() -> void:
	collected_once = true
	player = null
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	if collected_once:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if distance <= attraction_radius:
		if distance <= 28.0:
			_on_body_entered(player)
			return
		global_position = global_position.move_toward(
			player.global_position,
			attraction_speed * delta
		)


func _on_body_entered(body: Node) -> void:
	if collected_once or not body.is_in_group("player"):
		return
	collected_once = true
	var meta_progression := get_tree().root.get_node_or_null(
		"MetaProgression"
	)
	if meta_progression != null:
		meta_progression.add_gems(gem_value)
	var audio_effects := get_tree().root.get_node_or_null("AudioEffects")
	if audio_effects != null:
		audio_effects.call(
			"play",
			&"card_select",
			-9.0,
			0.08,
			&"SFX"
		)
	collected.emit()
	var runtime_pool := get_tree().root.get_node_or_null("RuntimePool")
	if runtime_pool != null and has_meta("runtime_pool_key"):
		runtime_pool.call("release", self)
	else:
		queue_free()


func _install_blood_drop_visual() -> void:
	var old_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if old_sprite != null:
		old_sprite.hide()
	blood_drop_visual = Node2D.new()
	blood_drop_visual.name = "BloodMemoryDrop"
	blood_drop_visual.z_index = 32
	blood_drop_visual.scale = Vector2.ONE * 1.45
	add_child(blood_drop_visual)
	var points := PackedVector2Array([
		Vector2(0, -18), Vector2(7, -7), Vector2(12, 1),
		Vector2(12, 9), Vector2(7, 16), Vector2(0, 19),
		Vector2(-7, 16), Vector2(-12, 9), Vector2(-12, 1),
		Vector2(-7, -7), Vector2(0, -18),
	])
	var glow := Line2D.new()
	glow.name = "BlueGlowOutline"
	glow.closed = true
	glow.width = 7.0
	glow.default_color = Color("1e579c", 0.78)
	glow.antialiased = false
	glow.material = unshaded_vfx_material
	glow.points = points
	blood_drop_visual.add_child(glow)
	var drop := Polygon2D.new()
	drop.name = "BurgundyDrop"
	drop.polygon = points
	drop.color = Color("9c173b")
	drop.material = unshaded_vfx_material
	blood_drop_visual.add_child(drop)
	var outline := Line2D.new()
	outline.name = "ElectricOutline"
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color("0ce6f2")
	outline.antialiased = false
	outline.material = unshaded_vfx_material
	outline.points = points
	blood_drop_visual.add_child(outline)
	var highlight := Polygon2D.new()
	highlight.name = "DropHighlight"
	highlight.polygon = PackedVector2Array([
		Vector2(-4, -6), Vector2(0, -12), Vector2(3, -6),
		Vector2(1, 0), Vector2(-3, 1),
	])
	highlight.color = Color("ff0546")
	highlight.material = unshaded_vfx_material
	blood_drop_visual.add_child(highlight)
	var pulse := blood_drop_visual.create_tween().set_loops()
	pulse.tween_property(blood_drop_visual, "scale", Vector2.ONE * 1.58, 0.42)
	pulse.tween_property(blood_drop_visual, "scale", Vector2.ONE * 1.45, 0.42)
