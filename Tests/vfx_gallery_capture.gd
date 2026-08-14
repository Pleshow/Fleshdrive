extends SceneTree


const EFFECT_IDS: Array[StringName] = [
	&"electric_chain_arc", &"electric_heavy_chain", &"electric_lance",
	&"storm_strike_01", &"storm_strike_03", &"storm_strike_06",
	&"static_strike", &"ball_lightning_burst",
	&"fire_impact", &"fireball_creation", &"fireball_explode",
	&"fire_explosion_ring", &"fire_explosion_spiked", &"fire_explosion_embers",
	&"slash_heavy", &"slash_horizontal", &"bite_impact", &"slash_small",
	&"status_burn", &"status_shock", &"status_heal", &"status_shield",
	&"status_haste", &"status_poison",
]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	await _capture_page(0, "res://.godot/vfx_gallery_1.png")
	var visual_effects := root.get_node_or_null("VisualEffects")
	if visual_effects != null:
		visual_effects.call("clear_all")
	await process_frame
	await _capture_page(12, "res://.godot/vfx_gallery_2.png")
	print("VFX GALLERY CAPTURED")
	quit(0)


func _capture_page(start_index: int, output_path: String) -> void:
	var gallery := Node2D.new()
	gallery.name = "VfxGallery"
	root.add_child(gallery)
	current_scene = gallery

	var background := ColorRect.new()
	background.color = Color("071017")
	background.position = Vector2.ZERO
	background.size = Vector2(1152.0, 648.0)
	background.z_index = -100
	gallery.add_child(background)
	var effects := Node2D.new()
	effects.name = "Effects"
	effects.add_to_group("effects_container")
	gallery.add_child(effects)

	var visual_effects := root.get_node_or_null("VisualEffects")
	for page_index in range(12):
		var index := start_index + page_index
		if index >= EFFECT_IDS.size():
			break
		var column := page_index % 4
		var row := page_index / 4
		var position := Vector2(
			140.0 + float(column) * 290.0,
			100.0 + float(row) * 205.0
		)
		var label := Label.new()
		label.text = String(EFFECT_IDS[index])
		label.position = position + Vector2(-120.0, 66.0)
		label.size = Vector2(240.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("c9f5ff"))
		label.z_index = 100
		gallery.add_child(label)
		var sprite = visual_effects.call(
			"play", EFFECT_IDS[index], position, 0.82
		) if visual_effects != null else null
		if sprite is AnimatedSprite2D:
			var count: int = sprite.sprite_frames.get_frame_count(&"play")
			sprite.pause()
			sprite.frame = mini(maxi(count / 2, 0), count - 1)

	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(output_path)
	gallery.queue_free()
	await process_frame
