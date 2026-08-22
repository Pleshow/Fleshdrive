class_name CombatFeedback
extends Node


const DAMAGE_FONT := preload(
	"res://Assets/fonts/PixeloidSans-Bold.ttf"
)

@export var base_hit_stop_seconds: float = 0.032
@export var minimum_time_scale: float = 0.38
@export var maximum_time_scale: float = 0.68
@export var combine_damage_numbers: bool = true
@export var damage_merge_window: float = 0.24
@export var maximum_damage_labels: int = 28

var hit_stop_active: bool = false
var hit_stop_rearm: float = 0.0
var pending_damage: Dictionary = {}
var pooled_labels: Array[Label] = []
var active_label_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var database := get_tree().root.get_node_or_null("BalanceDatabase")
	if database != null:
		maximum_damage_labels = int(database.call(
			"get_budget",
			"damage_numbers",
			float(maximum_damage_labels)
		))


func _process(delta: float) -> void:
	hit_stop_rearm = maxf(hit_stop_rearm - delta, 0.0)
	for target_id in pending_damage.keys():
		var entry: Dictionary = pending_damage[target_id]
		var label := entry.get("label") as Label
		if not is_instance_valid(label):
			pending_damage.erase(target_id)
			continue
		entry["remaining"] = float(entry["remaining"]) - delta
		entry["position"] = Vector2(entry["position"]) + Vector2(
			0.0,
			-22.0 * delta
		)
		label.global_position = entry["position"]
		if float(entry["remaining"]) <= 0.0:
			pending_damage.erase(target_id)
			_recycle_damage_label(label)
		else:
			pending_damage[target_id] = entry


func shake_camera(amount: float) -> void:
	var camera := get_tree().get_first_node_in_group("camera_feedback")

	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(amount)


func hit_stop(strength: float = 0.5) -> void:
	if hit_stop_active or hit_stop_rearm > 0.0:
		return

	if get_tree().paused:
		return

	hit_stop_active = true
	hit_stop_rearm = 0.085
	var clamped_strength := clampf(strength, 0.0, 1.0)
	var duration := base_hit_stop_seconds * lerpf(
		0.65,
		1.45,
		clamped_strength
	)
	Engine.time_scale = lerpf(
		maximum_time_scale,
		minimum_time_scale,
		clamped_strength
	)

	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0
	hit_stop_active = false


func play_hit(
	shake_amount: float,
	hit_stop_strength: float
) -> void:
	shake_camera(shake_amount)
	hit_stop(hit_stop_strength)


func register_death(
	world_position: Vector2,
	affinity: StringName,
	direction: Vector2 = Vector2.ZERO
) -> void:
	# Enemy scenes already emit one pooled death burst. The pipeline tags that
	# burst by affinity instead of spawning a second noisy effect here.
	if affinity == &"telekinetic":
		shake_camera(0.16)


func register_damage(
	target: Node2D,
	amount: float,
	affinity: StringName = &"physical",
	heavy: bool = false,
	show_number: bool = true,
	critical: bool = false,
	screen_shake: bool = true,
	source_id: StringName = &""
) -> void:
	if not is_instance_valid(target) or amount <= 0.0:
		return
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var numbers_enabled := bool(settings.damage_numbers_enabled) if settings != null else true
	if show_number and numbers_enabled:
		_show_or_merge_damage(target, amount, affinity, critical)
	_flash_target(target, affinity)
	_play_affinity_impact(target.global_position, affinity, heavy, source_id)
	if heavy:
		if screen_shake:
			shake_camera(0.22)
		hit_stop(0.34)
	if critical:
		var audio := get_tree().root.get_node_or_null("AudioEffects")
		if audio != null:
			audio.call("play", &"enemy_hit", 1.5, 0.0, &"SFX", 2)


func _flash_target(target: Node2D, affinity: StringName) -> void:
	if target.get("is_dead") == true:
		return
	# Electric attacks already have an authored bolt and impact. Tinting the
	# complete enemy sprite cyan as well read as an unrelated random flash.
	if affinity == &"electric":
		return
	var sprite := target.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite == null:
		sprite = target.get_node_or_null("Sprite2D") as CanvasItem
	if sprite == null:
		return
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var flash_strength := float(settings.flash_intensity) if settings != null else 1.0
	if flash_strength <= 0.01:
		return
	var flash_colors := {
		&"electric": Color(0.42, 0.95, 1.0, 1.0),
		&"fire": Color(1.0, 0.42, 0.16, 1.0),
		&"telekinetic": Color(0.9, 0.64, 1.0, 1.0),
		&"physical": Color(1.0, 0.96, 0.78, 1.0),
		&"hostile": Color(1.0, 0.16, 0.12, 1.0),
	}
	var flash_color: Color = flash_colors.get(
		affinity,
		flash_colors[&"physical"]
	)
	var old_tween := (
		sprite.get_meta("combat_hit_flash_tween") as Tween
		if sprite.has_meta("combat_hit_flash_tween")
		else null
	)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	sprite.modulate = Color.WHITE.lerp(flash_color, flash_strength)
	var tween := sprite.create_tween()
	sprite.set_meta("combat_hit_flash_tween", tween)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.095)


func _play_affinity_impact(
	world_position: Vector2,
	affinity: StringName,
	heavy: bool,
	source_id: StringName = &""
) -> void:
	var visual_effects := get_tree().root.get_node_or_null(
		"VisualEffects"
	)
	if visual_effects == null or not visual_effects.has_method("play"):
		return
	# Player damage has a dedicated full-screen red flash. Avoid mislabeling
	# hostile hits with one of the elemental impact effects.
	if affinity == &"hostile":
		return
	# Piercing projectiles own their directional terminal impact. Suppressing
	# the generic layer avoids a doubled, muddy burst on the same frame.
	if source_id in [&"arc_spear", &"magma_spear", &"base_fireball"]:
		return
	var effect_id := &"heavy_hit" if heavy else &"generic_hit"
	match affinity:
		&"electric":
			effect_id = &"electric_impact" if heavy else &"electric_micro_hit"
		&"fire":
			effect_id = &"fire_impact"
		&"telekinetic":
			effect_id = &"kinetic_impact"
	visual_effects.call(
		"play",
		effect_id,
		world_position,
		0.62 if heavy else 0.44,
		randf_range(-0.14, 0.14)
	)


func _show_or_merge_damage(
	target: Node2D,
	amount: float,
	affinity: StringName,
	critical: bool = false
) -> void:
	var target_id := target.get_instance_id()
	if combine_damage_numbers and pending_damage.has(target_id):
		var entry: Dictionary = pending_damage[target_id]
		entry["amount"] = float(entry["amount"]) + amount
		entry["remaining"] = damage_merge_window
		var label := entry.get("label") as Label
		if is_instance_valid(label):
			_update_damage_label(label, float(entry["amount"]), affinity, critical)
			label.scale = Vector2(1.28, 1.28) if critical else Vector2(1.16, 1.16)
			var tween := label.create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
			tween.tween_property(label, "scale", Vector2.ONE, 0.1)
		pending_damage[target_id] = entry
		return
	if active_label_count >= maximum_damage_labels:
		return
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_damage_number")):
		return
	var label := _acquire_damage_label()
	if label == null:
		return
	var container := get_tree().get_first_node_in_group("effects_container")
	if container == null:
		return
	if label.get_parent() != container:
		if label.get_parent() != null:
			label.reparent(container)
		else:
			container.add_child(label)
	label.show()
	label.global_position = target.global_position + Vector2(-54.0, -34.0)
	_update_damage_label(label, amount, affinity, critical)
	if critical:
		label.scale = Vector2(1.42, 1.42)
		var critical_tween := label.create_tween()
		critical_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		critical_tween.set_trans(Tween.TRANS_BACK)
		critical_tween.tween_property(label, "scale", Vector2.ONE, 0.16)
	active_label_count += 1
	pending_damage[target_id] = {
		"label": label,
		"amount": amount,
		"remaining": damage_merge_window,
		"position": label.global_position,
	}


func _acquire_damage_label() -> Label:
	while not pooled_labels.is_empty():
		var pooled: Label = pooled_labels.pop_back() as Label
		if is_instance_valid(pooled):
			return pooled
	var label := Label.new()
	label.name = "DamageNumber"
	label.size = Vector2(108.0, 30.0)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DAMAGE_FONT)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = unshaded
	label.add_to_group("damage_numbers")
	label.z_as_relative = false
	label.z_index = 96
	return label


func _update_damage_label(
	label: Label,
	amount: float,
	affinity: StringName,
	critical: bool = false
) -> void:
	label.text = ("! %d !" if critical else "%d") % roundi(amount)
	label.add_theme_font_size_override("font_size", 21 if critical else 17)
	label.add_theme_color_override(
		"font_color",
		Color("0ce6f2") if critical else Color("0098db")
	)


func _recycle_damage_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.hide()
	label.scale = Vector2.ONE
	active_label_count = maxi(active_label_count - 1, 0)
	if pooled_labels.size() < maximum_damage_labels:
		pooled_labels.append(label)
	else:
		label.queue_free()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
