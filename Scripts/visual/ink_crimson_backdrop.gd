extends Control


const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const GRID_SIZE := 96


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.VOID)
	for column in range(0, ceili(size.x / GRID_SIZE) + 1):
		var x := float(column * GRID_SIZE)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Palette.INK, 1.0, false)
	for row in range(0, ceili(size.y / GRID_SIZE) + 1):
		var y := float(row * GRID_SIZE)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Palette.INK, 1.0, false)

	var right_mass := Rect2(size.x * 0.58, 0.0, size.x * 0.42, size.y)
	draw_rect(right_mass, Palette.INK)
	for band in range(7):
		var band_y := snappedf(size.y * (0.08 + float(band) * 0.14), 2.0)
		var band_x := snappedf(size.x * (0.62 + float(band % 3) * 0.07), 2.0)
		draw_rect(
			Rect2(band_x, band_y, size.x - band_x, 4.0),
			Palette.FLESH_SHADOW
		)
		draw_rect(
			Rect2(band_x - 10.0, band_y - 6.0, 10.0, 16.0),
			Palette.FLESH_DEEP
		)

	var circuit_x := snappedf(size.x * 0.76, 2.0)
	draw_line(
		Vector2(circuit_x, 0.0),
		Vector2(circuit_x, size.y * 0.32),
		Palette.TECH_DEEP,
		2.0,
		false
	)
	draw_line(
		Vector2(circuit_x, size.y * 0.32),
		Vector2(size.x, size.y * 0.32),
		Palette.TECH,
		2.0,
		false
	)
	for marker in range(5):
		var marker_position := Vector2(
			circuit_x - 3.0,
			snappedf(size.y * (0.08 + marker * 0.055), 2.0)
		)
		draw_rect(Rect2(marker_position, Vector2(8.0, 4.0)), Palette.TECH_BRIGHT)

	draw_rect(Rect2(24.0, 24.0, 84.0, 3.0), Palette.ALERT)
	draw_rect(Rect2(24.0, 32.0, 42.0, 3.0), Palette.FLESH)
	draw_rect(
		Rect2(size.x - 132.0, size.y - 28.0, 108.0, 4.0),
		Palette.TECH_BRIGHT
	)
