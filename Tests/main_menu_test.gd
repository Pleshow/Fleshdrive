extends SceneTree


var failure_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu_scene := load("res://Scenes/main_menu.tscn") as PackedScene
	_check(menu_scene != null, "Main menu scene loads")
	if menu_scene == null:
		_finish()
		return

	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame

	var background := menu.get_node("Background") as TextureRect
	var menu_shell := menu.get_node("MenuShell") as PanelContainer
	var main_panel := menu.get_node("%MainPanel") as VBoxContainer
	var settings_panel := menu.get_node("%SettingsPanel") as VBoxContainer
	var play_button := menu.get_node("%PlayButton") as Button
	var settings_button := menu.get_node("%SettingsButton") as Button
	var skill_tree_button := menu.get_node("%SkillTreeButton") as Button
	var quit_button := menu.get_node("%QuitButton") as Button
	var skill_tree_panel := menu.get_node("%SkillTreePanel") as SkillTreePanel
	var music := menu.get_node("Music") as AudioStreamPlayer
	var volume_slider := menu.get_node("%VolumeSlider") as HSlider
	var volume_value_label := menu.get_node("%VolumeValueLabel") as Label
	var crt_slider := menu.get_node("%CRTSlider") as HSlider
	var bloom_slider := menu.get_node("%BloomSlider") as HSlider
	var chromatic_slider := menu.get_node("%ChromaticSlider") as HSlider
	var bit_reducer_slider := menu.get_node("%BitReducerSlider") as HSlider
	var post_process := menu.get_node(
		"PostProcess/ScreenFilter"
	) as ColorRect
	var audio_effects := root.get_node_or_null("AudioEffects")
	var settings := root.get_node_or_null("GameSettings")
	var original_master_volume := float(settings.master_volume)
	var original_crt := float(settings.crt_intensity)
	var original_bloom := float(settings.bloom_intensity)
	var original_chromatic := float(settings.chromatic_aberration)
	var original_bit_reduction := float(settings.bit_reduction)

	_check(audio_effects != null, "Central audio effects player is available")
	_check(settings != null, "Persistent game settings are available")
	_check(
		is_equal_approx(settings.DEFAULT_MASTER_VOLUME, 100.0)
		and is_equal_approx(settings.DEFAULT_CRT_INTENSITY, 0.14)
		and is_equal_approx(settings.DEFAULT_BLOOM_INTENSITY, 0.055)
		and is_equal_approx(
			settings.DEFAULT_CHROMATIC_ABERRATION,
			0.04
		)
		and is_equal_approx(settings.DEFAULT_BIT_REDUCTION, 0.42),
		"Requested visual and audio values are the defaults"
	)
	_check(
		play_button.get_theme_font("font").resource_path
		== "res://Assets/fonts/PixeloidSans-Bold.ttf"
		and menu.get_theme_default_font().resource_path
		== "res://Assets/fonts/PixeloidSans.ttf",
		"Global UI theme uses Pixeloid Sans and Pixeloid Sans Bold"
	)
	_check(
		AudioServer.get_bus_index("Music") >= 0
		and AudioServer.get_bus_index("SFX") >= 0
		and AudioServer.get_bus_index("UI") >= 0,
		"Music, SFX and UI audio buses are configured"
	)
	_check(
		background.texture.resource_path
		== "res://Assets/ui/screens/mainmenu.png",
		"Requested image is used as the menu background"
	)
	_check(
		music != null
		and music.stream.resource_path
		== "res://Assets/audio/music/main_menu.mp3"
		and music.autoplay
		and music.stream.get("loop") == true,
		"Main menu uses the first requested track on loop"
	)
	_check(music.bus == &"Music", "Main menu music uses the Music bus")
	if audio_effects != null:
		audio_effects.call("clear_play_counts")
		menu._play_ui_hover()
		menu._play_ui_confirm()
		menu._play_ui_cancel()
		_check(
			audio_effects.call("get_play_count", &"ui_hover") == 1
			and audio_effects.call("get_play_count", &"ui_confirm") == 1
			and audio_effects.call("get_play_count", &"ui_cancel") == 1,
			"Menu hover, confirm and cancel sounds are connected"
		)
	_check(
		play_button != null
		and settings_button != null
		and skill_tree_button != null
		and quit_button != null,
		"Play, settings, Flesh Tree and quit buttons exist"
	)
	_check(
		play_button.text == "START RUN"
		and settings_button.text == "SETTINGS"
		and skill_tree_button.text == "FLESH TREE"
		and quit_button.text == "QUIT GAME",
		"Main menu buttons use English labels"
	)
	_check(play_button.global_position.x < 520.0, "Menu buttons are placed on the left")
	var prototype_panel := menu.get_node("%PrototypeInfoPanel") as PanelContainer
	_check(
		menu_shell.size.x <= 610.0
		and menu_shell.position.x <= 24.0
		and prototype_panel.position.x > menu_shell.get_global_rect().end.x
		and prototype_panel.size.y <= 230.0
		and prototype_panel.get_global_rect().end.y
		< menu.get_viewport_rect().size.y * 0.40,
		"Main controls stay on the far left and the profile uses the empty upper area"
	)

	menu._open_settings()
	await process_frame
	_check(not main_panel.visible and settings_panel.visible, "Settings panel opens")
	_check(
		menu_shell.position.y <= 64.0
		and menu_shell.get_global_rect().end.y
		<= menu.get_viewport_rect().size.y,
		"Raised settings shell stays fully inside the viewport"
	)
	volume_slider.value = 42.0
	var master_bus := AudioServer.get_bus_index("Master")
	_check(
		is_equal_approx(
			db_to_linear(AudioServer.get_bus_volume_db(master_bus)),
			0.42
		)
		and not AudioServer.is_bus_mute(master_bus)
		and volume_value_label.text == "42%",
		"Main menu volume control updates the Master bus"
	)
	crt_slider.value = 45.0
	bloom_slider.value = 37.0
	chromatic_slider.value = 29.0
	bit_reducer_slider.value = 31.0
	await process_frame
	var post_material := post_process.material as ShaderMaterial
	_check(
		is_equal_approx(float(settings.crt_intensity), 0.45)
		and is_equal_approx(float(settings.bloom_intensity), 0.37)
		and is_equal_approx(float(settings.chromatic_aberration), 0.29)
		and is_equal_approx(float(settings.bit_reduction), 0.31),
		"Visual and lo-fi settings update from the main menu"
	)
	_check(
		is_equal_approx(
			float(post_material.get_shader_parameter("crt_intensity")),
			0.45
		),
		"CRT setting updates the full-screen post process"
	)
	var master_effect_count := AudioServer.get_bus_effect_count(master_bus)
	_check(
		master_effect_count > 0
		and AudioServer.get_bus_effect(
			master_bus,
			master_effect_count - 1
		) is AudioEffectDistortion
		and AudioServer.is_bus_effect_enabled(
			master_bus,
			master_effect_count - 1
		),
		"Bit reducer is active on the Master bus"
	)
	menu._close_settings()
	_check(main_panel.visible and not settings_panel.visible, "Settings panel closes")
	menu._open_skill_tree()
	_check(
		skill_tree_panel.visible and not menu.menu_shell.visible,
		"Main menu opens the permanent Flesh Tree"
	)
	_check(
		skill_tree_panel.upgrade_buttons.size() == 13,
		"Flesh Tree builds thirteen permanent skill nodes"
	)
	var hex_nodes_valid := true
	for upgrade_button in skill_tree_panel.upgrade_buttons.values():
		var button := upgrade_button as Button
		var icon_rect: TextureRect = null
		if button != null:
			icon_rect = button.get_node_or_null("Icon") as TextureRect
		var visible_center := Vector2.ZERO
		if icon_rect != null and icon_rect.texture != null:
			var icon_image := icon_rect.texture.get_image()
			if icon_image != null and not icon_image.is_empty():
				var used_rect := icon_image.get_used_rect()
				var normalized_center := (
					Vector2(used_rect.position)
					+ Vector2(used_rect.size) * 0.5
				) / Vector2(
					icon_image.get_width(),
					icon_image.get_height()
				)
				visible_center = (
					icon_rect.position
					+ icon_rect.size * normalized_center
				)
		if (
			button == null
			or button.get_node_or_null("../HexFill") == null
			or button.get_node_or_null("../HexBorder") == null
			or icon_rect == null
			or icon_rect.size != Vector2(106, 106)
			or visible_center.distance_to(Vector2(58, 58)) > 0.75
		):
			hex_nodes_valid = false
			break
	_check(
		hex_nodes_valid,
		"Flesh Tree icon content is centered inside every hexagon"
	)
	var tree_position_before := skill_tree_panel.tree_canvas.position
	skill_tree_panel.dragging = true
	var drag_event := InputEventMouseMotion.new()
	drag_event.relative = Vector2(30, 18)
	skill_tree_panel._on_tree_viewport_input(drag_event)
	skill_tree_panel.dragging = false
	_check(
		skill_tree_panel.tree_canvas.position != tree_position_before,
		"Flesh Tree can be dragged"
	)
	var zoom_before := skill_tree_panel.zoom_level
	skill_tree_panel._set_zoom(
		zoom_before + 0.1,
		Vector2(300, 200)
	)
	_check(
		skill_tree_panel.zoom_level > zoom_before,
		"Flesh Tree can be zoomed"
	)
	skill_tree_panel._show_upgrade_details(&"power")
	_check(
		skill_tree_panel.detail_title.text == "PREDATOR CORE"
		and skill_tree_panel.detail_description.text.contains(
			"attack damage"
		),
		"Hovering a skill exposes its details"
	)
	_check(
		skill_tree_panel.respec_dialog.dialog_text.contains("Refund")
		and skill_tree_panel.reset_dialog.dialog_text.contains(
			"cannot be undone"
		),
		"Respec and full reset require explicit confirmation"
	)
	menu._close_skill_tree()
	_check(
		not skill_tree_panel.visible and menu.menu_shell.visible,
		"Flesh Tree returns to the main menu"
	)

	menu.minimum_loading_seconds = 0.05
	menu._on_play_pressed()
	for _frame in range(600):
		if current_scene != null and current_scene.name == "Game":
			break
		await process_frame
	_check(current_scene != null and current_scene.name == "Game", "Play starts the game scene")
	if current_scene != null:
		_check(
			current_scene.get_node(
				"UI/HUD/FleshdriveOperationScreen"
			).visible,
			"Starting a run displays the Fleshdrive operation before onboarding"
		)

	paused = false
	settings.set_master_volume(original_master_volume)
	settings.set_crt_intensity(original_crt)
	settings.set_bloom_intensity(original_bloom)
	settings.set_chromatic_aberration(original_chromatic)
	settings.set_bit_reduction(original_bit_reduction)
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failure_count == 0:
		print("MAIN MENU TEST PASSED")
		quit(0)
		return
	push_error("MAIN MENU TEST FAILED: %d failure(s)" % failure_count)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failure_count += 1
	push_error("FAIL: " + message)
