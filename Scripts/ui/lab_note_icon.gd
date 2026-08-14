class_name LabNoteIcon
extends Control


var accent_color := Color(0.32, 0.82, 1.0)
var upgrade_kind: int = UpgradeData.UpgradeKind.ITEM
var organ_slot: int = UpgradeData.OrganSlot.NONE
var symbol_seed: int = 0


func configure(upgrade: UpgradeData, accent: Color) -> void:
	accent_color = accent
	if upgrade != null:
		upgrade_kind = int(upgrade.upgrade_kind)
		organ_slot = int(upgrade.organ_slot)
		symbol_seed = abs(hash(upgrade.upgrade_id))
	queue_redraw()


func _draw() -> void:
	var paper := Rect2(6.0, 4.0, size.x - 12.0, size.y - 8.0)
	draw_rect(paper, Color(0.86, 0.83, 0.70, 0.94), true)
	draw_rect(paper, Color(0.12, 0.14, 0.14, 0.86), false, 2.0)
	for row in range(3):
		var y := 15.0 + float(row) * 12.0
		draw_line(
			Vector2(12.0, y),
			Vector2(size.x - 12.0 - float((symbol_seed + row) % 9), y),
			Color(0.18, 0.22, 0.22, 0.18),
			1.0,
			false
		)
	match upgrade_kind:
		UpgradeData.UpgradeKind.ORGAN:
			_draw_organ_doodle()
		UpgradeData.UpgradeKind.WEAPON:
			_draw_weapon_doodle()
		_:
			_draw_item_doodle()
	_draw_lab_marks()


func _draw_organ_doodle() -> void:
	var center := size * 0.5 + Vector2(0.0, 4.0)
	match organ_slot:
		UpgradeData.OrganSlot.BRAIN:
			for offset in [Vector2(-11, -5), Vector2(0, -10), Vector2(11, -4), Vector2(-5, 7), Vector2(7, 8)]:
				draw_circle(center + offset, 10.0, Color(accent_color, 0.34), false, 3.0, false)
			draw_line(center + Vector2(0, 14), center + Vector2(0, 23), accent_color, 3.0, false)
		UpgradeData.OrganSlot.LEGS:
			draw_polyline(PackedVector2Array([
				center + Vector2(-10, -20), center + Vector2(-5, 0),
				center + Vector2(-14, 20), center + Vector2(-2, 20),
			]), accent_color, 4.0, false)
			draw_polyline(PackedVector2Array([
				center + Vector2(10, -20), center + Vector2(5, 0),
				center + Vector2(14, 20), center + Vector2(2, 20),
			]), accent_color, 4.0, false)
		_:
			var heart := PackedVector2Array([
				center + Vector2(0, 21), center + Vector2(-19, 1),
				center + Vector2(-16, -13), center + Vector2(-5, -18),
				center, center + Vector2(5, -18),
				center + Vector2(16, -13), center + Vector2(19, 1),
				center + Vector2(0, 21),
			])
			draw_colored_polygon(heart, Color(accent_color, 0.32))
			draw_polyline(heart, accent_color, 3.0, false)


func _draw_weapon_doodle() -> void:
	var center := size * 0.5 + Vector2(0.0, 4.0)
	var bolt := PackedVector2Array([
		center + Vector2(7, -28), center + Vector2(-13, -3),
		center + Vector2(-2, -3), center + Vector2(-9, 27),
		center + Vector2(16, -9), center + Vector2(4, -9),
		center + Vector2(7, -28),
	])
	draw_colored_polygon(bolt, Color(accent_color, 0.38))
	draw_polyline(bolt, accent_color, 3.0, false)


func _draw_item_doodle() -> void:
	var center := size * 0.5 + Vector2(0.0, 7.0)
	draw_line(center + Vector2(-7, -26), center + Vector2(7, -26), accent_color, 3.0, false)
	draw_line(center + Vector2(-5, -24), center + Vector2(-5, -9), accent_color, 3.0, false)
	draw_line(center + Vector2(5, -24), center + Vector2(5, -9), accent_color, 3.0, false)
	var flask := PackedVector2Array([
		center + Vector2(-5, -9), center + Vector2(-19, 20),
		center + Vector2(19, 20), center + Vector2(5, -9),
	])
	draw_colored_polygon(flask, Color(accent_color, 0.28))
	draw_polyline(PackedVector2Array([
		center + Vector2(-5, -9), center + Vector2(-19, 20),
		center + Vector2(19, 20), center + Vector2(5, -9),
	]), accent_color, 3.0, false)


func _draw_lab_marks() -> void:
	var ink := Color(0.12, 0.15, 0.15, 0.64)
	draw_line(Vector2(12, size.y - 13), Vector2(29, size.y - 16), ink, 2.0, false)
	draw_line(Vector2(14, size.y - 9), Vector2(34, size.y - 11), ink, 2.0, false)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x - 33.0, size.y - 9.0),
		"M?",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		10,
		ink
	)
