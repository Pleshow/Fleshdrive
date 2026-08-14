class_name TrialLabAutotile
extends TileMapLayer


const GRID_SIZE := Vector2i(160, 90)
const TILE_SIZE := Vector2i(16, 16)
const DISPLAY_SCALE := 1.0
const ARENA_OFFSET := Vector2.ZERO
const SOURCE_ID := 0
const TERRAIN_SET := 0
const FLOOR_TERRAIN := 0
const TILESET_TEXTURE := preload(
	"res://Assets/environment/top_down_lab_trial/Tileset.png"
)

const FLOOR_VARIANTS: Array[Vector2i] = [
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(3, 6),
	Vector2i(4, 6),
]

const HAZARD_TILES: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(7, 4),
	Vector2i(2, 5), Vector2i(7, 5),
	Vector2i(2, 6), Vector2i(7, 6),
	Vector2i(2, 7), Vector2i(7, 7),
	Vector2i(2, 8), Vector2i(3, 8),
	Vector2i(4, 8), Vector2i(7, 8),
]

const HORIZONTAL_WALL_TOP: Array[Vector2i] = [
	Vector2i(3, 1), Vector2i(4, 1),
]
const HORIZONTAL_WALL_BOTTOM: Array[Vector2i] = [
	Vector2i(3, 2), Vector2i(4, 2),
]
const DOOR_TOP: Array[Vector2i] = [
	Vector2i(7, 1), Vector2i(8, 1),
]
const DOOR_BOTTOM: Array[Vector2i] = [
	Vector2i(7, 2), Vector2i(8, 2),
]
const LOWER_WALL_TOP: Array[Vector2i] = [
	Vector2i(10, 7), Vector2i(11, 7),
	Vector2i(12, 7), Vector2i(13, 7),
]
const LOWER_WALL_BOTTOM: Array[Vector2i] = [
	Vector2i(10, 8), Vector2i(11, 8),
	Vector2i(12, 8), Vector2i(13, 8),
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -100
	position = ARENA_OFFSET
	scale = Vector2.ONE * DISPLAY_SCALE
	tile_set = _build_tile_set()
	_paint_floor_with_terrain()
	_create_detail_layer()


func _build_tile_set() -> TileSet:
	var result := TileSet.new()
	result.tile_size = TILE_SIZE
	result.add_terrain_set(TERRAIN_SET)
	result.set_terrain_set_mode(
		TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_SIDES
	)
	result.add_terrain(TERRAIN_SET, FLOOR_TERRAIN)
	result.set_terrain_name(TERRAIN_SET, FLOOR_TERRAIN, "LabFloor")
	result.set_terrain_color(
		TERRAIN_SET,
		FLOOR_TERRAIN,
		Color(0.05, 0.42, 0.43)
	)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILESET_TEXTURE
	atlas.texture_region_size = TILE_SIZE
	atlas.use_texture_padding = false
	result.add_source(atlas, SOURCE_ID)

	var atlas_tiles := FLOOR_VARIANTS.duplicate()
	for tile in HAZARD_TILES:
		if not atlas_tiles.has(tile):
			atlas_tiles.append(tile)
	for tile in (
		HORIZONTAL_WALL_TOP
		+ HORIZONTAL_WALL_BOTTOM
		+ DOOR_TOP
		+ DOOR_BOTTOM
		+ LOWER_WALL_TOP
		+ LOWER_WALL_BOTTOM
	):
		if not atlas_tiles.has(tile):
			atlas_tiles.append(tile)
	for x in range(10, 14):
		for y in range(3, 7):
			var vertical_wall_tile := Vector2i(x, y)
			if not atlas_tiles.has(vertical_wall_tile):
				atlas_tiles.append(vertical_wall_tile)
	for atlas_coordinate in atlas_tiles:
		atlas.create_tile(atlas_coordinate)

	for atlas_coordinate in FLOOR_VARIANTS:
		var tile_data := atlas.get_tile_data(atlas_coordinate, 0)
		tile_data.terrain_set = TERRAIN_SET
		tile_data.terrain = FLOOR_TERRAIN
		for neighbor in [
			TileSet.CELL_NEIGHBOR_TOP_SIDE,
			TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		]:
			tile_data.set_terrain_peering_bit(neighbor, FLOOR_TERRAIN)
	return result


func _paint_floor_with_terrain() -> void:
	var floor_cells: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			floor_cells.append(Vector2i(x, y))
	set_cells_terrain_connect(
		floor_cells,
		TERRAIN_SET,
		FLOOR_TERRAIN,
		true
	)
	# This third-party atlas does not include a complete Godot terrain peering
	# matrix. Keep terrain-connect as the primary paint operation, then fill
	# only unmatched edge cells so the trial always covers exactly 2560x1440.
	for cell in floor_cells:
		if get_cell_source_id(cell) == -1:
			set_cell(cell, SOURCE_ID, FLOOR_VARIANTS[2], 0)

	# The requested clean floor is a repeating 2x2 panel made from atlas cells
	# (3,5), (4,5), (3,6), (4,6). No random hazard fragments are used here.
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var panel_tile := FLOOR_VARIANTS[(y % 2) * 2 + x % 2]
			set_cell(Vector2i(x, y), SOURCE_ID, panel_tile, 0)

	# Wall atlas cells intentionally contain transparent cutouts. Remove the
	# floor underneath every wall cell so green floor pixels cannot show through
	# the vertical walls, door recesses or outer corners.
	for x in range(GRID_SIZE.x):
		erase_cell(Vector2i(x, 0))
		erase_cell(Vector2i(x, 1))
		erase_cell(Vector2i(x, GRID_SIZE.y - 2))
		erase_cell(Vector2i(x, GRID_SIZE.y - 1))
	for y in range(2, GRID_SIZE.y - 2):
		erase_cell(Vector2i(0, y))
		erase_cell(Vector2i(GRID_SIZE.x - 1, y))


func _create_detail_layer() -> void:
	var details := TileMapLayer.new()
	details.name = "ArenaDetailTiles"
	details.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	details.z_index = -99
	details.position = ARENA_OFFSET
	details.scale = Vector2.ONE * DISPLAY_SCALE
	details.tile_set = tile_set
	get_parent().add_child.call_deferred(details)
	_populate_details.call_deferred(details)


func _populate_details(details: TileMapLayer) -> void:
	# Two-tile-high top wall uses wall panels with a centered laboratory door.
	# The lower wall uses the atlas's dedicated thin lower-wall pair supplied
	# in the visual reference, rather than a vertically flipped upper wall.
	for x in range(GRID_SIZE.x):
		var wall_index := x % 2
		details.set_cell(
			Vector2i(x, 0), SOURCE_ID,
			HORIZONTAL_WALL_TOP[wall_index], 0
		)
		details.set_cell(
			Vector2i(x, 1), SOURCE_ID,
			HORIZONTAL_WALL_BOTTOM[wall_index], 0
		)
		details.set_cell(
			Vector2i(x, GRID_SIZE.y - 2), SOURCE_ID,
			LOWER_WALL_TOP[x % LOWER_WALL_TOP.size()], 0
		)
		details.set_cell(
			Vector2i(x, GRID_SIZE.y - 1), SOURCE_ID,
			LOWER_WALL_BOTTOM[x % LOWER_WALL_BOTTOM.size()], 0
		)

	var door_left := GRID_SIZE.x / 2 - 1
	for offset in range(2):
		details.set_cell(
			Vector2i(door_left + offset, 0),
			SOURCE_ID, DOOR_TOP[offset], 0
		)
		details.set_cell(
			Vector2i(door_left + offset, 1),
			SOURCE_ID, DOOR_BOTTOM[offset], 0
		)

	# Native one-tile-wide sidewalls use the atlas's dedicated thin vertical
	# wall style requested in the visual reference. The floor layer is erased
	# below these cells, so their cutouts reveal only the dark arena underlay.
	for y in range(2, GRID_SIZE.y - 2):
		details.set_cell(
			Vector2i(0, y), SOURCE_ID,
			Vector2i(10, 3 + y % 4), 0
		)
		details.set_cell(
			Vector2i(GRID_SIZE.x - 1, y), SOURCE_ID,
			Vector2i(13, 3 + y % 4), 0
		)

	# One continuous black/yellow safety line follows the inner wall edge.
	var top_hazard_y := 2
	var bottom_hazard_y := GRID_SIZE.y - 3
	for x in range(2, GRID_SIZE.x - 2):
		var horizontal_tile := Vector2i(3 + x % 2, 8)
		details.set_cell(
			Vector2i(x, top_hazard_y), SOURCE_ID,
			horizontal_tile, 0
		)
		details.set_cell(
			Vector2i(x, bottom_hazard_y), SOURCE_ID,
			horizontal_tile,
			TileSetAtlasSource.TRANSFORM_FLIP_V
		)
	for y in range(3, GRID_SIZE.y - 3):
		details.set_cell(
			Vector2i(1, y), SOURCE_ID,
			Vector2i(2, 5 + y % 3), 0
		)
		details.set_cell(
			Vector2i(GRID_SIZE.x - 2, y), SOURCE_ID,
			Vector2i(7, 5 + y % 3), 0
		)
	# Corner tiles join the horizontal and vertical hazard segments.
	details.set_cell(Vector2i(1, top_hazard_y), SOURCE_ID, Vector2i(2, 8), 0)
	details.set_cell(Vector2i(GRID_SIZE.x - 2, top_hazard_y), SOURCE_ID, Vector2i(7, 8), 0)
	details.set_cell(
		Vector2i(1, bottom_hazard_y), SOURCE_ID,
		Vector2i(2, 8), TileSetAtlasSource.TRANSFORM_FLIP_V
	)
	details.set_cell(
		Vector2i(GRID_SIZE.x - 2, bottom_hazard_y), SOURCE_ID,
		Vector2i(7, 8), TileSetAtlasSource.TRANSFORM_FLIP_V
	)
