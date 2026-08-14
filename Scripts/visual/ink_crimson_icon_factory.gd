class_name InkCrimsonIconFactory
extends RefCounted


const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const ICON_PATTERNS := {
	&"play": [
		"............", "..11........", "..111.......", "..1111......",
		"..11222.....", "..112222....", "..112222....", "..11222.....",
		"..1111......", "..111.......", "..11........", "............",
	],
	&"settings": [
		"....11......", "...1221.....", "1111221111..", "1222222221..",
		".12211221...", "..211112....", "..211112....", ".12211221...",
		"1222222221..", "1111221111..", "...1221.....", "....11......",
	],
	&"organ": [
		"............", "..111..111...", ".1222112221..", "122222222221.",
		"122222222221.", ".12222222221..", "..12222221...", "...122221....",
		"....1221....", ".....11.....", "............", "............",
	],
	&"exit": [
		"111111111...", "122222221...", "12.....21...", "12....1111..",
		"12.....2221.", "12......2221", "12.....2221.", "12....1111..",
		"12.....21...", "122222221...", "111111111...", "............",
	],
}
static var cache: Dictionary = {}


static func make_icon(icon_id: StringName, hostile: bool = false) -> ImageTexture:
	var cache_key := "%s:%s" % [icon_id, hostile]
	if cache.has(cache_key):
		return cache[cache_key] as ImageTexture
	var pattern: Array = ICON_PATTERNS.get(icon_id, ICON_PATTERNS[&"organ"])
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var dark := Palette.FLESH if hostile else Palette.TECH
	var bright := Palette.ALERT if hostile else Palette.TECH_BRIGHT
	for y in range(pattern.size()):
		var row := String(pattern[y])
		for x in range(row.length()):
			var symbol := row.substr(x, 1)
			if symbol == "1":
				image.set_pixel(x, y, dark)
			elif symbol == "2":
				image.set_pixel(x, y, bright)
	var texture := ImageTexture.create_from_image(image)
	cache[cache_key] = texture
	return texture
