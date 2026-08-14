class_name EliteModifier
extends Node


enum Type {
	ARMORED,
	VOLATILE,
	ACCELERATED,
	REGENERATIVE,
}

const TYPE_NAMES := {
	Type.ARMORED: "ARMORED",
	Type.VOLATILE: "VOLATILE",
	Type.ACCELERATED: "ACCELERATED",
	Type.REGENERATIVE: "REGENERATIVE",
}
const TYPE_COLORS := {
	Type.ARMORED: Color(0.58, 0.72, 0.88, 0.92),
	Type.VOLATILE: Color(1.0, 0.28, 0.12, 0.94),
	Type.ACCELERATED: Color(0.95, 0.82, 0.18, 0.94),
	Type.REGENERATIVE: Color(0.25, 1.0, 0.48, 0.92),
}

var elite_type: Type = Type.ARMORED
var enemy: Node2D
var damage_reduction: float = 0.0
var regeneration_delay: float = 0.0
var maximum_health: float = 1.0


func initialize(target: Node2D, modifier_type: Type) -> void:
	enemy = target
	elite_type = modifier_type
	name = "EliteModifier"
	enemy.set_meta("is_elite", true)
	enemy.set_meta("elite_type", TYPE_NAMES[elite_type])
	_apply_stats()
	_create_telegraph()
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.call(
			"register_status_marker",
			enemy,
			&"elite_modifier",
			{
				"type": TYPE_NAMES[elite_type],
				"damage_reduction": damage_reduction,
			}
		)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if (
		elite_type != Type.REGENERATIVE
		or not is_instance_valid(enemy)
		or enemy.get("is_dead") == true
	):
		return
	regeneration_delay = maxf(regeneration_delay - delta, 0.0)
	if regeneration_delay > 0.0:
		return
	var current := float(enemy.get("current_health"))
	enemy.set(
		"current_health",
		minf(current + maximum_health * 0.035 * delta, maximum_health)
	)


func modify_damage(amount: float) -> float:
	regeneration_delay = 2.25
	return amount * (1.0 - damage_reduction)


static func modify_damage_for(target: Node, amount: float) -> float:
	var modifier := target.get_node_or_null("EliteModifier") as EliteModifier
	if modifier == null:
		return amount
	return modifier.modify_damage(amount)


func _apply_stats() -> void:
	maximum_health = float(enemy.get("max_health"))
	match elite_type:
		Type.ARMORED:
			maximum_health *= 1.75
			damage_reduction = 0.28
			enemy.set_meta("elite_route_bias", 0.05)
		Type.VOLATILE:
			maximum_health *= 1.22
			enemy.set_meta("elite_route_bias", 0.92)
		Type.ACCELERATED:
			maximum_health *= 0.92
			enemy.set_meta("elite_route_bias", 1.28)
			_multiply_numeric_property(&"move_speed", 1.42)
			_multiply_numeric_property(&"charge_speed", 1.24)
			_multiply_numeric_property(&"attack_cooldown", 0.78)
		Type.REGENERATIVE:
			maximum_health *= 1.32
			enemy.set_meta("elite_route_bias", 0.56)
	enemy.set("max_health", maximum_health)
	enemy.set("current_health", maximum_health)


func _multiply_numeric_property(property_name: StringName, factor: float) -> void:
	var property_exists := false
	for property in enemy.get_property_list():
		if StringName(property["name"]) == property_name:
			property_exists = true
			break
	if not property_exists:
		return
	var value = enemy.get(property_name)
	if value != null:
		enemy.set(property_name, float(value) * factor)


func _create_telegraph() -> void:
	var ring := Line2D.new()
	ring.name = "EliteTelegraph"
	ring.width = 4.0
	ring.default_color = TYPE_COLORS[elite_type]
	ring.z_as_relative = false
	ring.z_index = 42
	for point_index in range(33):
		var angle := TAU * float(point_index) / 32.0
		ring.add_point(Vector2.from_angle(angle) * 47.0)
	enemy.add_child(ring)

	var label := Label.new()
	label.name = "EliteLabel"
	label.position = Vector2(-48.0, -68.0)
	label.size = Vector2(96.0, 20.0)
	label.text = TYPE_NAMES[elite_type]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", TYPE_COLORS[elite_type])
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_as_relative = false
	label.z_index = 43
	enemy.add_child(label)


func _on_enemy_died(_dead_enemy: Node2D) -> void:
	var audio := enemy.get_tree().root.get_node_or_null("AudioEffects")
	if audio != null:
		audio.call("play", &"elite_kill", -2.0, 0.025, &"SFX", 2)
	if elite_type != Type.VOLATILE or not is_instance_valid(enemy):
		return
	var player := enemy.get_tree().get_first_node_in_group("player") as Node2D
	if (
		player != null
		and enemy.global_position.distance_squared_to(player.global_position)
		<= 135.0 * 135.0
		and player.has_method("take_damage")
	):
		player.call(
			"take_damage",
			18.0,
			enemy,
			&"volatile_elite"
		)
	var visual_effects := enemy.get_tree().root.get_node_or_null(
		"VisualEffects"
	)
	if visual_effects != null:
		visual_effects.call(
			"play",
			&"repulse_wave",
			enemy.global_position,
			2.3
		)
