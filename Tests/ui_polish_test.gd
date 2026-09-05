extends SceneTree


const MAIN_MENU := preload("res://Scenes/main_menu.tscn")
const GAME := preload("res://Scenes/game.tscn")
const DIALOGUE_PANEL := preload("res://Scenes/dialogue_panel.tscn")
const STARTUP_SPLASH := preload("res://Scenes/startup_splash.tscn")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var splash := STARTUP_SPLASH.instantiate() as StartupSplash
	root.add_child(splash)
	await process_frame
	await process_frame
	var godot_credit := splash.find_child(
		"GodotCredit", true, false
	) as Label
	var studio_credit := splash.find_child(
		"StudioName", true, false
	) as Label
	_check(
		godot_credit != null
		and studio_credit != null
		and godot_credit.get_theme_color("font_color") == Color.WHITE
		and studio_credit.get_theme_color("font_color") == Color.WHITE,
		"Startup credits remain white after global UI styling"
	)
	splash.queue_free()
	await process_frame

	var theme := load(
		"res://Resources/Themes/fleshdrive_theme.tres"
	) as Theme
	_check(theme != null, "Unified Fleshdrive theme loads")
	var readable_font := theme.default_font as FontVariation
	_check(
		readable_font != null
		and readable_font.spacing_glyph == 1
		and readable_font.spacing_space == 1,
		"Shared horror font uses subtle global letter spacing"
	)
	_check(
		theme.has_stylebox(&"normal", &"Button")
		and theme.has_stylebox(&"hover", &"Button")
		and theme.has_stylebox(&"pressed", &"Button")
		and theme.has_stylebox(&"focus", &"Button"),
		"Buttons expose complete normal, hover, press and focus states"
	)
	_check(
		theme.has_stylebox(&"panel", &"TooltipPanel")
		and theme.has_stylebox(&"slider", &"HSlider")
		and theme.has_stylebox(&"grabber_area_highlight", &"HSlider"),
		"Tooltips and settings sliders use the shared visual language"
	)
	_check(
		theme.get_stylebox(&"normal", &"Button") is StyleBoxTexture
		and theme.get_stylebox(&"panel", &"Panel") is StyleBoxTexture,
		"Shared buttons and panels use Horror UI texture styles"
	)
	var theme_button_normal := theme.get_stylebox(&"normal", &"Button") as StyleBoxTexture
	_check(
		theme_button_normal.texture != null
		and theme.get_color(&"font_color", &"Button") == Color("9c173b")
		and theme.get_color(&"font_hover_color", &"Button") == Color("ff0546"),
		"Shared theme defines textured Horror UI buttons"
	)

	var menu := MAIN_MENU.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	await process_frame
	var play_button := menu.play_button
	var menu_buttons: Array[Button] = [
		menu.play_button,
		menu.settings_button,
		menu.skill_tree_button,
		menu.quit_button,
	]
	for button in menu_buttons:
		_check(
			button.size.is_equal_approx(play_button.size),
			"Main menu button geometry is consistent: %s" % button.name
		)
		_check(
			button.alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"Main menu button copy is centered: %s" % button.name
		)
		_check(
			not button.has_node("BiomechShadow")
			and not button.flat
			and button.get_theme_stylebox("normal") is StyleBoxTexture,
			"Main menu button uses the Horror UI frame: %s" % button.name
		)
		_check(
			button.size.x <= 420.5
			and button.size.x <= menu.menu_shell.size.x - 90.0,
			"Responsive main menu button stays clear of the ornamental sides: %s" % button.name
		)
	_check(
		menu.menu_shell.get_theme_stylebox("panel") is StyleBoxEmpty,
		"Main menu shell remains a transparent layout container"
	)
	_check(
		menu.get_node("Logo").visible
		and menu.menu_shell.get_global_rect().size.x >= 390.0,
		"Main-menu logo and frameless action column retain their safe layout"
	)
	await create_timer(0.18, true).timeout
	_check(
		play_button.has_focus()
		and play_button.scale.is_equal_approx(Vector2.ONE),
		"Keyboard focus highlights without resizing a menu button"
	)
	_check(
		play_button.has_meta("_fleshdrive_ui_polished")
		and play_button.mouse_default_cursor_shape
		== Control.CURSOR_POINTING_HAND,
		"Main menu controls automatically receive interaction polish"
	)
	play_button.mouse_entered.emit()
	await create_timer(0.2, true).timeout
	_check(
		play_button.scale.x > 1.01,
		"Pointer hover smoothly enlarges interactive controls"
	)
	play_button.mouse_exited.emit()
	await create_timer(0.2, true).timeout
	_check(
		is_equal_approx(play_button.scale.x, 1.0),
		"Interactive controls return to their resting state"
	)
	menu._open_settings()
	await create_timer(0.28, true).timeout
	_check(
		menu.settings_panel.visible
		and menu.settings_panel.modulate.a > 0.98
		and menu.volume_slider.has_meta("_fleshdrive_ui_polished"),
		"Settings transition and slider feedback are active"
	)
	_check(
		menu.menu_shell.get_theme_stylebox("panel") is StyleBoxEmpty,
		"Wide settings view keeps the frameless menu composition"
	)
	_check(
		menu.back_button.size.x <= 260.5,
		"Settings back action no longer spans across the outer frame"
	)
	_check(
		menu.menu_shell.position.x >= 28.0
		and menu.menu_shell.position.y >= 24.0
		and menu.version_label.anchor_bottom == 1.0,
		"Main menu uses safe responsive margins and bottom anchoring"
	)
	_check(
		menu.shell_margin.get_theme_constant("margin_left") <= 40
		and menu.shell_margin.get_theme_constant("margin_top") <= 34,
		"Settings content uses compact margins without wasting screen space"
	)
	menu.queue_free()
	await process_frame

	var game := GAME.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var operation := game.get_node(
		"UI/HUD/FleshdriveOperationScreen"
	) as FleshdriveOperationScreen
	_check(
		operation.visible
		and operation.fleshdrive_slots.size() == 5
		and operation.electric_card.has_meta("_fleshdrive_ui_polished")
		and operation.telekinetic_card.has_meta(
			"_fleshdrive_ui_polished"
		),
		"Five Fleshdrive slots share the compact interaction system"
	)
	for slot_index in range(operation.fleshdrive_slots.size() - 1):
		var current_slot := operation.fleshdrive_slots[slot_index]
		var next_slot := operation.fleshdrive_slots[slot_index + 1]
		_check(
			not current_slot.get_global_rect().intersects(
				next_slot.get_global_rect()
			),
			"Adjacent Fleshdrive slots do not overlap"
		)
	_check(
		operation.tank_slot.disabled
		and operation.old_ones_slot.disabled
		and operation.tank_slot.get_node("SlotName").text
		== tr("ADDITIONAL PROTOTYPE")
		and operation.tank_slot.size.y <= 60.0,
		"Unimplemented Fleshdrives remain visible as compact prototype rows"
	)
	_check(
		not operation.get_node("MimichuPanel").get_global_rect().intersects(
			operation.electric_card.get_global_rect()
		),
		"Mimichu panel does not collide with the compact card row"
	)
	operation._select_fleshdrive(FleshdriveCatalog.TELEKINETIC)
	await process_frame
	var details_rect := operation.details_text.get_global_rect()
	var implant_rect := operation.implant_button.get_global_rect()
	_check(
		not details_rect.intersects(implant_rect),
		"Fleshdrive description and implant action no longer overlap"
	)
	_check(
		Rect2(
			Vector2.ZERO,
			(operation.get_node("DetailsPanel") as Control).size
		).encloses(
			Rect2(
				operation.implant_button.position,
				operation.implant_button.size
			)
		),
		"Prototype implant action stays inside the details panel"
	)
	_check(
		operation.fire_card.disabled
		and operation.telekinetic_card.disabled,
		"Only Voltaic is selectable while Pyre and Noetic remain disabled"
	)
	_check(
		operation.electric_card.get_theme_stylebox("focus")
		is StyleBoxEmpty
		and operation.fire_card.get_theme_stylebox("focus")
		is StyleBoxEmpty
		and operation.telekinetic_card.get_theme_stylebox("focus")
		is StyleBoxEmpty,
		"Fleshdrive cards use one consistent selection border"
	)
	operation._select_fleshdrive(FleshdriveCatalog.FIRE)
	_check(
		operation.electric_card.self_modulate.get_luminance()
		> operation.fire_card.self_modulate.get_luminance()
		and operation.details_text.text == "IN DEVELOPMENT",
		"Unavailable Pyre stays gray and explains its prototype status"
	)
	_check(
		operation.electric_card.get_node("SelectedFrame").visible
		and not operation.fire_card.get_node("SelectedFrame").visible,
		"Voltaic Heart keeps its persistent selection frame"
	)
	var electric_icon := operation.electric_card.get_node("Icon") as TextureRect
	var electric_frame_style := (
		operation.electric_card.get_node("SelectedFrame") as Panel
	).get_theme_stylebox("panel") as StyleBoxFlat
	_check(
		electric_icon.visible
		and electric_icon.modulate == Color.WHITE
		and electric_icon.self_modulate == Color.WHITE
		and electric_frame_style.bg_color.a <= 0.001,
		"Voltaic Heart artwork is fully visible behind a transparent selection frame"
	)
	_check(
		operation.mimichu_portrait.sprite_frames.has_animation(&"idle")
		and operation.mimichu_portrait.sprite_frames.has_animation(&"talk"),
		"Operation screen uses the shared Mimichu idle and talk atlas"
	)
	_check(
		operation.get_node("MimichuPanel").get_theme_stylebox("panel")
		is StyleBoxTexture
		and operation.get_node("DetailsPanel").get_theme_stylebox("panel")
		is StyleBoxTexture,
		"Fleshdrive operation panels use the Horror UI frame"
	)
	var hud := game.get_node("UI/HUD")
	var upgrade_card := hud.get_node(
		"LevelUpPanel/CenterContainer/VBoxContainer/Cards/UpgradeCard1"
	) as TextureButton
	var sample_upgrade := load(
		"res://Resources/Upgrades/arc_heart.tres"
	) as UpgradeData
	hud._set_upgrade_card_content(upgrade_card, sample_upgrade)
	await process_frame
	var dynamic_title := upgrade_card.get_node(
		"CardSurface/CardTitle"
	) as Label
	var dynamic_art := upgrade_card.get_node(
		"CardSurface/MainArtwork"
	) as TextureRect
	var card_frame := upgrade_card.get_node(
		"CardSurface/CardFrameOverlay"
	) as TextureRect
	var card_description := upgrade_card.get_node(
		"CardSurface/Description"
	) as Label
	_check(
		upgrade_card.has_method("play_reveal"),
		"Upgrade offers use the animated Horror card controller"
	)
	_check(
		dynamic_title.text == tr(sample_upgrade.display_name),
		"Upgrade card titles remain dynamic and localizable"
	)
	_check(
		dynamic_art.texture != null
		and dynamic_art.texture != sample_upgrade.card_texture,
		"Upgrade cards no longer display legacy baked-text artwork"
	)
	_check(
		dynamic_art.texture != null
		and "/skill_art/cards/arc_heart.png" in dynamic_art.texture.resource_path,
		"Each upgrade card loads its generated ability-specific artwork"
	)
	_check(
		upgrade_card.get_node_or_null("CardSurface/CategoryIcon") == null
		and card_frame.texture.resource_path.ends_with(
			"fleshdrive_upgrade_card_frame_v4.png"
		),
		"Upgrade cards omit the category icon and its top-right socket"
	)
	_check(
		dynamic_title.get_theme_font_size("font_size") >= 17
		and card_description.get_theme_font_size("font_size") >= 11
		and card_description.get_theme_font_size("outline_size") >= 1,
		"Card copy keeps a readable minimum size and contrast outline"
	)
	_check(
		dynamic_title.get_parent() == dynamic_art.get_parent()
		and upgrade_card.get_node_or_null("CardDepthLayer") == null,
		"Artwork and text share one surface so all card content moves together"
	)
	upgrade_card.call("play_reveal", 0.10)
	upgrade_card.call("_on_mouse_entered")
	await create_timer(0.55).timeout
	_check(
		is_equal_approx(upgrade_card.modulate.a, 1.0)
		and upgrade_card.visible,
		"Hover cannot interrupt reveal and strand a card dark or invisible"
	)
	upgrade_card.call("_on_mouse_exited")
	upgrade_card.call("set_selected_visual", true, false)
	_check(
		upgrade_card.scale.x > 1.05
		and upgrade_card.get_node("SelectionBorder").visible,
		"Selected upgrade cards receive highlight and scale emphasis"
	)
	upgrade_card.call("set_selected_visual", false, false)
	var player_status := hud.get_node("PlayerStatusPanel") as Control
	var portrait_frame := player_status.get_node("PortraitFrame") as Control
	var health_bar := player_status.get_node("HealthBar") as Control
	var hud_level := player_status.get_node("LevelLabel") as Label
	hud._set_player_status_visible(true)
	var xp_bar := hud.get_node("BiomassBar") as Control
	var xp_frame := hud.get_node("XPFrame") as TextureRect
	var timer := hud.get_node("RunTimerLabel") as Control
	var boss_panel := hud.get_node("BossPanel") as Control
	_check(
		not player_status.get_global_rect().intersects(
			xp_bar.get_global_rect()
		),
		"Centered XP bar stays clear of Koda portrait, HP and level"
	)
	_check(
		health_bar.get_global_rect().position.x
		>= portrait_frame.get_global_rect().end.x + 12.0,
		"HP bar begins beside Koda's portrait instead of behind it"
	)
	_check(
		hud_level.visible
		and player_status.get_global_rect().encloses(
			hud_level.get_global_rect()
		),
		"Current level is visible inside Koda's status frame"
	)
	_check(
		absf(xp_bar.get_global_rect().get_center().x - 640.0) < 1.0,
		"XP bar is centered at the top of the gameplay viewport"
	)
	_check(
		timer.get_global_rect().get_center().x > 1100.0,
		"Run timer occupies the upper-right lane away from Kinetic Charge"
	)
	_check(
		not xp_frame.visible
		and xp_bar.get_theme_stylebox("background") is StyleBoxFlat,
		"Gameplay XP bar uses the restored compact native HUD style"
	)
	_check(
		not boss_panel.get_global_rect().intersects(timer.get_global_rect())
		and not boss_panel.get_global_rect().intersects(
			xp_bar.get_global_rect()
		),
		"Boss presentation has its own non-overlapping top HUD lane"
	)
	hud.pause_panel.show()
	await create_timer(0.28, true).timeout
	var pause_stack := hud.pause_panel.get_node(
		"CenterContainer/VBoxContainer"
	) as VBoxContainer
	_check(
		hud.pause_panel.has_meta("_fleshdrive_modal_polished")
		and hud.pause_panel.modulate.a > 0.98
		and hud.resume_button.has_meta("_fleshdrive_ui_polished"),
		"Pause and modal screens animate with the shared chrome"
	)
	_check(
		pause_stack.get_theme_constant("separation") <= 10
		and hud.resume_button.custom_minimum_size.y <= 44.0,
		"Pause actions are compact while retaining usable hit targets"
	)
	hud.organ_screen.show()
	await process_frame
	_check(
		hud.organ_screen.has_meta("_fleshdrive_modal_polished")
		and hud.organ_close_button.has_meta("_fleshdrive_ui_polished"),
		"Organ Screen participates in the unified UI system"
	)
	var pending_test_organ := load(
		"res://Resources/Upgrades/reflex_cortex.tres"
	) as UpgradeData
	hud.open_organ_screen(pending_test_organ)
	_check(
		hud.organ_close_button.visible
		and hud.organ_close_button.text.contains("MUTATIONS"),
		"Pending organ placement always exposes a visible back action"
	)
	hud._on_organ_close_pressed()
	_check(
		not hud.organ_screen.visible
		and hud.level_up_panel.visible
		and hud.pending_organ == null,
		"Pending organ placement can return safely to card selection"
	)

	paused = false
	game.queue_free()
	await process_frame

	var dialogue := DIALOGUE_PANEL.instantiate() as DialoguePanel
	root.add_child(dialogue)
	await process_frame
	var portrait := dialogue.get_node("PortraitFrame") as Control
	var text_frame := dialogue.get_node("DialogueFrame") as Control
	_check(
		not portrait.get_global_rect().intersects(
			text_frame.get_global_rect()
		),
		"Dialogue portrait and localized text frame never overlap"
	)
	_check(
		dialogue.body_label.get_theme_color("default_color").r > 0.75
		and dialogue.body_label.get_theme_color("default_color").r
		> dialogue.body_label.get_theme_color("default_color").b * 1.6
		and dialogue.body_label.get_theme_constant("outline_size") == 0,
		"Dialogue copy uses clean high-contrast red without a colored outline"
	)
	dialogue.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("UI POLISH TEST PASSED")
		quit(0)
		return
	push_error("UI POLISH TEST FAILED: %d failure(s)" % failures)
	quit(1)
