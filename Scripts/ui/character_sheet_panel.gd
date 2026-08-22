class_name CharacterSheetPanel
extends PanelContainer


var title_label: Label
var stats_label: Label
var abilities_label: Label
var close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.016, 0.022, 0.97)
	style.border_color = Color(0.18, 0.78, 0.84, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	title_label = Label.new()
	title_label.text = tr("KODA CHARACTER SHEET")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.32, 0.92, 0.96))
	stack.add_child(title_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	stack.add_child(columns)
	stats_label = Label.new()
	stats_label.custom_minimum_size = Vector2(350.0, 360.0)
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.95))
	columns.add_child(stats_label)
	abilities_label = Label.new()
	abilities_label.custom_minimum_size = Vector2(350.0, 360.0)
	abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abilities_label.add_theme_font_size_override("font_size", 16)
	abilities_label.add_theme_color_override("font_color", Color(0.62, 0.88, 0.92))
	columns.add_child(abilities_label)
	close_button = Button.new()
	close_button.text = tr("CLOSE")
	close_button.custom_minimum_size = Vector2(220.0, 48.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(hide)
	stack.add_child(close_button)


func present(sheet: Dictionary) -> void:
	var stat_lines: Array[String] = [tr("BASE STATISTICS")]
	for row: Dictionary in sheet.get("stats", []):
		stat_lines.append("%-20s %s" % [
			tr(String(row.get("name", "STAT"))),
			KodaStatSheet.format_value(row),
		])
	stats_label.text = "\n".join(stat_lines)
	var ability_lines: Array[String] = [tr("ABILITIES")]
	for ability: Dictionary in sheet.get("abilities", []):
		ability_lines.append("%s  LV %d" % [
			tr(String(ability.get("name", "ABILITY"))),
			int(ability.get("level", 1)),
		])
	abilities_label.text = "\n".join(ability_lines)
	show()
	close_button.grab_focus()
