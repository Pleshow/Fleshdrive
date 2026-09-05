class_name CharacterSheetPanel
extends PanelContainer


@onready var title_label: Label = %Title
@onready var stats_label: Label = %Stats
@onready var abilities_label: Label = %Abilities
@onready var close_button: Button = %CloseButton


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
	title_label.text = tr("KODA CHARACTER SHEET")
	close_button.text = tr("CLOSE")
	close_button.pressed.connect(hide)


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
