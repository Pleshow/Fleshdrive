extends SceneTree


const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const MENU_SCENE := preload("res://Scenes/main_menu.tscn")
const THEME := preload("res://Resources/Themes/fleshdrive_theme.tres")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_test_master_palette()
	_test_strict_output_pass()
	_test_theme_components()
	await _test_menu_identity()
	_test_pixel_vfx_contract()
	_finish()


func _test_master_palette() -> void:
	var expected := PackedStringArray([
		"ff0546", "9c173b", "660f31", "450327", "270022",
		"17001d", "09010d", "0ce6f2", "0098db", "1e579c",
	])
	var actual := PackedStringArray()
	for color_variant in Palette.COLORS:
		var color := color_variant as Color
		actual.append(color.to_html(false))
		_check(is_equal_approx(color.a, 1.0), "Master colors are fully opaque")
	_check(actual == expected, "Master palette matches the ten Ink-Crimson colors")


func _test_strict_output_pass() -> void:
	var visual_system := root.get_node_or_null("InkCrimsonVisualSystem") as CanvasLayer
	var filter := (
		visual_system.get_node_or_null("StrictTenColorOutput") as ColorRect
		if visual_system != null
		else null
	)
	var material := filter.material as ShaderMaterial if filter != null else null
	_check(
		visual_system != null and visual_system.layer >= 1000,
		"Strict output pass renders above gameplay, HUD, menus and post-process"
	)
	_check(
		filter != null
		and filter.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and filter.anchor_right == 1.0
		and filter.anchor_bottom == 1.0,
		"Palette pass covers the viewport without intercepting input"
	)
	_check(
		material != null
		and material.shader.resource_path == "res://Shaders/ink_crimson_quantize.gdshader",
		"Final frame is quantized by the Ink-Crimson nearest-color shader"
	)


func _test_theme_components() -> void:
	var checked_colors := 0
	var checked_styleboxes := 0
	for theme_type in THEME.get_type_list():
		for color_name in THEME.get_color_list(theme_type):
			checked_colors += 1
			_check(
				_is_palette_color(THEME.get_color(color_name, theme_type)),
				"Theme color %s/%s belongs to the master palette" % [
					theme_type, color_name,
				]
			)
		for style_name in THEME.get_stylebox_list(theme_type):
			var style := THEME.get_stylebox(style_name, theme_type) as StyleBoxFlat
			if style == null:
				continue
			checked_styleboxes += 1
			_check(
				_is_palette_color(style.bg_color)
				and _is_palette_color(style.border_color)
				and style.shadow_size == 0
				and not style.anti_aliasing
				and style.corner_radius_top_left == 0
				and style.corner_radius_top_right == 0
				and style.corner_radius_bottom_left == 0
				and style.corner_radius_bottom_right == 0,
				"Theme style %s/%s is crisp, square and palette-safe" % [
					theme_type, style_name,
				]
			)
	_check(checked_colors >= 20, "Theme exposes a complete semantic color system")
	_check(checked_styleboxes >= 20, "Theme covers the reusable UI component states")


func _test_menu_identity() -> void:
	var menu := MENU_SCENE.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var backdrop := menu.get_node_or_null("InkCrimsonBackdrop") as Control
	_check(
		backdrop != null
		and backdrop.get_script().resource_path
		== "res://Scripts/visual/ink_crimson_backdrop.gd",
		"Main menu uses the new procedural biomechanical pixel backdrop"
	)
	_check(
		menu.play_button.icon != null
		and menu.settings_button.icon != null
		and menu.skill_tree_button.icon != null
		and menu.quit_button.icon != null,
		"Main menu actions use the reusable two-tone pixel icon language"
	)
	menu.queue_free()
	await process_frame


func _test_pixel_vfx_contract() -> void:
	var visual_effects := root.get_node_or_null("VisualEffects")
	var electric_material := (
		visual_effects.call("_get_pixel_vfx_material", true) as ShaderMaterial
		if visual_effects != null
		else null
	)
	_check(
		electric_material != null
		and electric_material.shader.resource_path == "res://Shaders/pixel_emissive.gdshader"
		and bool(electric_material.get_shader_parameter("force_electric_blue")),
		"Electric VFX use the hard three-step blue Ink-Crimson ramp"
	)
	var controller_source := FileAccess.get_file_as_string(
		"res://Scripts/post_process_controller.gd"
	)
	_check(
		controller_source.contains("\"bloom_intensity\",\n\t\t0.0")
		and controller_source.contains("\"chromatic_aberration\",\n\t\t0.0"),
		"Soft bloom and chromatic blur are disabled by the visual contract"
	)


func _is_palette_color(color: Color) -> bool:
	if not is_equal_approx(color.a, 1.0):
		return false
	for candidate_variant in Palette.COLORS:
		var candidate := candidate_variant as Color
		if Vector3(color.r, color.g, color.b).distance_to(
			Vector3(candidate.r, candidate.g, candidate.b)
		) < 0.00001:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("INK CRIMSON VISUAL SYSTEM TEST PASSED")
		quit(0)
		return
	push_error("INK CRIMSON VISUAL SYSTEM TEST FAILED: %d failure(s)" % failures)
	quit(1)
