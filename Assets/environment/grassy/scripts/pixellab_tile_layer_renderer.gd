@tool
extends Node2D

@export var tile_map: TileMapLayer
@export var layer_data: Dictionary = {}
@export var source_to_tile: Dictionary = {}
@export var layer_y: int = 0
@export var legacy: bool = false
@export_storage var pattern_values: Dictionary = {}

var _textures: Dictionary = {}
var _placements: Dictionary = {}
var _tile_to_source: Dictionary = {}
var _auto_rules: Dictionary = {}
var _last_cells: Dictionary = {}
var _vertex_values: Dictionary = {}
var _auto_syncing := false

const LAYER_ORDER_STRIDE := 1000000000000.0
const POSITION_ORDER_STRIDE := 1000000.0
const PATTERN_CENTER_MATCH_SCORE := 10
const PATTERN_CENTER_MISMATCH_SCORE := -30
const PATTERN_RING_MATCH_SCORE := 1
const PATTERN_RING_MISMATCH_SCORE := -1

func _ready() -> void:
    _load_layer_data()
    set_process(true)
    _last_cells = _collect_cells()
    queue_redraw()

func _process(_delta: float) -> void:
    if tile_map != null:
        _sync_auto_tiling()
        queue_redraw()

func _load_layer_data() -> void:
    _textures.clear()
    _placements.clear()
    _tile_to_source.clear()
    _auto_rules = {}
    for placement in layer_data.get("placements", []):
        _placements[_cell_key(placement)] = placement

    if legacy:
        var legacy_path := str(layer_data.get("image", ""))
        if not legacy_path.is_empty():
            _textures[0] = load(legacy_path)
    else:
        var asset_paths: Dictionary = layer_data.get("assetPaths", {})
        for tile_index in asset_paths.keys():
            var texture_path := str(asset_paths[tile_index])
            if not texture_path.is_empty():
                _textures[int(tile_index)] = load(texture_path)

    var rules = layer_data.get("tileRules", {})
    if rules is Dictionary:
        _auto_rules = rules
    if not legacy:
        for source_id in source_to_tile.keys():
            _tile_to_source[int(source_to_tile[source_id])] = int(source_id)
    var current := _collect_tile_indices()
    if _uses_pattern_rules():
        if not pattern_values.is_empty():
            _vertex_values = pattern_values.duplicate(true)
        elif not _load_exported_paint_values():
            if _pattern_cells_are_paint_tiles():
                _load_pattern_paint_values()
            else:
                _rebuild_pattern_vertices(current, [])
        _replace_pattern_tiles_with_paint_tiles()
        pattern_values = _vertex_values.duplicate(true)
    else:
        _rebuild_vertex_values(current, [])

func _draw() -> void:
    if tile_map == null:
        return
    var draw_items: Array[Dictionary] = []
    var sidescroller := bool(layer_data.get("sidescroller", false))
    for cell in _draw_cells():
        var tile_index: int
        if _uses_pattern_rules():
            var request := _pattern_for_cell(cell)
            if sidescroller and _pattern_center_is_empty(request):
                continue
            if (
                not sidescroller
                and not _uses_transition_patterns()
                and tile_map.get_cell_source_id(cell) < 0
                and not _pattern_center_is_mixed(request)
            ):
                continue
            tile_index = _tile_for_pattern(request)
        else:
            tile_index = _tile_index_for(cell)
        if tile_index < 0:
            continue
        var texture := _texture_for(tile_index)
        if texture == null:
            continue
        var item := _draw_item(cell, tile_index, texture)
        draw_items.append(item)
    draw_items.sort_custom(Callable(self, "_sort_draw_items"))
    for item in draw_items:
        draw_texture_rect_region(
            item["texture"],
            item["destination"],
            item["source"]
        )

func _draw_cells() -> Array:
    var cells: Dictionary = {}
    var sidescroller := bool(layer_data.get("sidescroller", false))
    for used_cell in tile_map.get_used_cells():
        var cell := Vector2i(used_cell)
        cells[cell] = true
        if _uses_pattern_rules() and (sidescroller or not _uses_transition_patterns()):
            cells[cell + Vector2i(-1, 0)] = true
            cells[cell + Vector2i(0, -1)] = true
            cells[cell + Vector2i(-1, -1)] = true
    return cells.keys()

func _pattern_center_is_empty(pattern: Array) -> bool:
    return (
        int(pattern[1][1]) == 1
        and int(pattern[1][2]) == 1
        and int(pattern[2][1]) == 1
        and int(pattern[2][2]) == 1
    )

func _pattern_center_is_mixed(pattern: Array) -> bool:
    var has_lower := false
    var has_upper := false
    for row in [1, 2]:
        for column in [1, 2]:
            var value := int(pattern[row][column])
            has_lower = has_lower or value == 0
            has_upper = has_upper or value == 1
    return has_lower and has_upper

func _tile_index_for(cell: Vector2i) -> int:
    if legacy:
        var atlas := tile_map.get_cell_atlas_coords(cell)
        return atlas.x + atlas.y * int(layer_data.get("atlasColumns", 4))
    var source_id := tile_map.get_cell_source_id(cell)
    return int(source_to_tile.get(source_id, -1))

func _visual_tile_index_for(cell: Vector2i) -> int:
    if _uses_pattern_rules():
        return _tile_for_pattern(_pattern_for_cell(cell))
    return _tile_index_for(cell)

func _texture_for(tile_index: int) -> Texture2D:
    if legacy:
        return _textures.get(0) as Texture2D
    return _textures.get(tile_index) as Texture2D

func _draw_item(cell: Vector2i, tile_index: int, texture: Texture2D) -> Dictionary:
    var authored = _placements.get(_cell_key_values(cell.x, cell.y, layer_y))
    if authored != null and int(authored.get("tileIndex", -1)) == tile_index:
        var source := _source_rect(authored, texture)
        return {
            "texture": texture,
            "source": source,
            "destination": Rect2(
                float(authored.get("xPx", 0)),
                float(authored.get("yPx", 0)),
                float(authored.get("width", source.size.x)),
                float(authored.get("height", source.size.y))
            ),
            "order": float(authored.get("drawOrder", authored.get("renderOrder", 0)))
        }

    var width := float(texture.get_width())
    var height := float(texture.get_height())
    var x := 0.0
    var y := 0.0
    if legacy:
        var tile_size: Dictionary = layer_data.get("tileSize", {})
        width = float(tile_size.get("width", width))
        height = float(tile_size.get("height", height))
        x = cell.x * width
        y = cell.y * height
        var columns := int(layer_data.get("atlasColumns", 4))
        var source := Rect2(
            (tile_index % columns) * width,
            (tile_index / columns) * height,
            width,
            height
        )
        return {
            "texture": texture,
            "source": source,
            "destination": Rect2(x, y, width, height),
            "order": cell.y * POSITION_ORDER_STRIDE + cell.x
        }

    var tile_type := str(layer_data.get("tileType", ""))
    var logical_width := float(layer_data.get("tileW", width))
    if tile_type != "oblique":
        width = logical_width
    var projection: Dictionary = layer_data.get("projection", {})
    var sprite_origin: Dictionary = projection.get("spriteOrigin", projection.get("origin", {}))
    var q_basis: Dictionary = projection.get("qBasis", {})
    var r_basis: Dictionary = projection.get("rBasis", {})
    var stack_basis: Dictionary = projection.get("stackBasis", {})
    x = float(sprite_origin.get("x", 0))
    x += cell.x * float(q_basis.get("x", logical_width))
    x += cell.y * float(r_basis.get("x", 0))
    x += layer_y * float(stack_basis.get("x", 0))
    y = float(sprite_origin.get("y", 0))
    y += cell.x * float(q_basis.get("y", 0))
    y += cell.y * float(r_basis.get("y", logical_width))
    y += layer_y * float(stack_basis.get("y", 0))
    y -= height
    return {
        "texture": texture,
        "source": Rect2(0, 0, texture.get_width(), texture.get_height()),
        "destination": Rect2(x, y, width, height),
        "order": _projection_draw_order(x, y, height)
    }

func _projection_draw_order(x: float, y: float, height: float) -> float:
    return (
        float(layer_data.get("drawOrderOffset", 0))
        + layer_y * LAYER_ORDER_STRIDE
        + (y + height) * POSITION_ORDER_STRIDE
        + x
    )

func _source_rect(placement: Dictionary, texture: Texture2D) -> Rect2:
    var source: Dictionary = placement.get("sourceRect", {})
    return Rect2(
        float(source.get("x", 0)),
        float(source.get("y", 0)),
        float(source.get("width", texture.get_width())),
        float(source.get("height", texture.get_height()))
    )

func _cell_key(placement: Dictionary) -> String:
    return _cell_key_values(
        int(placement.get("q", 0)),
        int(placement.get("r", 0)),
        int(placement.get("layerY", 0))
    )

func _cell_key_values(q: int, r: int, y: int) -> String:
    return "%d,%d,%d" % [q, r, y]

func _sort_draw_items(first: Dictionary, second: Dictionary) -> bool:
    return float(first["order"]) < float(second["order"])

func _collect_cells() -> Dictionary:
    var cells: Dictionary = {}
    if tile_map == null:
        return cells
    for cell in tile_map.get_used_cells():
        if _uses_pattern_rules():
            var tile_data := tile_map.get_cell_tile_data(cell)
            if tile_data != null and tile_data.get_terrain() >= 0:
                cells[cell] = tile_data.get_terrain()
        else:
            cells[cell] = _tile_index_for(cell)
    return cells

func _collect_tile_indices() -> Dictionary:
    var cells: Dictionary = {}
    if tile_map == null:
        return cells
    for cell in tile_map.get_used_cells():
        cells[cell] = _tile_index_for(cell)
    return cells

func _sync_auto_tiling() -> void:
    if _auto_syncing or tile_map == null or _auto_rules.is_empty():
        return
    var current := _collect_cells()
    var changed: Array = []
    for cell in current.keys():
        if not _last_cells.has(cell) or int(_last_cells[cell]) != int(current[cell]):
            changed.append(cell)
    for cell in _last_cells.keys():
        if not current.has(cell):
            changed.append(cell)
    if changed.is_empty():
        return

    _auto_syncing = true
    var rule_type := str(_auto_rules.get("rule_type", ""))
    var arity := int(_auto_rules.get("arity", 0))
    if rule_type == "corner" and arity == 4:
        _sync_corner_cells(current, changed)
    elif rule_type == "edge" and (arity == 4 or arity == 6):
        _sync_edge_cells(current, changed)
    elif rule_type == "pattern_4x4":
        _sync_pattern_cells(current, changed)
    _auto_syncing = false
    _last_cells = _collect_cells()

func _sync_corner_cells(current: Dictionary, changed: Array) -> void:
    _rebuild_vertex_values(current, changed)
    var affected: Dictionary = {}
    for cell in changed:
        for offset in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
            var candidate: Vector2i = Vector2i(cell) + Vector2i(offset)
            if current.has(candidate):
                affected[candidate] = true
    for cell in affected.keys():
        var desired_mask := _corner_mask_for_cell(Vector2i(cell))
        var desired_tile := _tile_for_mask(desired_mask, 4)
        if desired_tile >= 0 and int(current[cell]) != desired_tile:
            _set_tile_index(Vector2i(cell), desired_tile)
            current[cell] = desired_tile

func _sync_edge_cells(current: Dictionary, changed: Array) -> void:
    var grid_kind := str(layer_data.get("gridKind", ""))
    var arity := int(_auto_rules.get("arity", 0))
    var offsets := _edge_offsets(grid_kind, arity)
    var affected: Dictionary = {}
    for cell in changed:
        affected[Vector2i(cell)] = true
        for offset in offsets:
            var candidate: Vector2i = Vector2i(cell) + Vector2i(offset)
            if current.has(candidate):
                affected[candidate] = true
    for cell in affected.keys():
        var coords := Vector2i(cell)
        if _terrain_for_tile(int(current[coords])) != "feature":
            continue
        var mask := 0
        for index in range(offsets.size()):
            var neighbour: Vector2i = coords + Vector2i(offsets[index])
            var neighbour_terrain := "empty"
            if current.has(neighbour):
                neighbour_terrain = _terrain_for_tile(int(current[neighbour]))
            var bit_set := false
            if str(_auto_rules.get("connectivity", "same")) == "same":
                bit_set = neighbour_terrain == "feature" or neighbour_terrain == "filler"
            else:
                bit_set = neighbour_terrain != "feature"
            if bit_set:
                mask |= 1 << index
        var desired_tile := _tile_for_mask(mask, arity)
        if desired_tile >= 0 and int(current[coords]) != desired_tile:
            _set_tile_index(coords, desired_tile)
            current[coords] = desired_tile

func _sync_pattern_cells(current: Dictionary, changed: Array) -> void:
    if current.is_empty():
        _vertex_values.clear()
        pattern_values = {}
        return
    for cell in changed:
        var coords := Vector2i(cell)
        if current.has(coords):
            _vertex_values[coords] = int(current[coords])
        else:
            _vertex_values.erase(coords)
    pattern_values = _vertex_values.duplicate(true)

func _rebuild_pattern_vertices(current: Dictionary, priority_cells: Array) -> void:
    var previous: Dictionary = _vertex_values.duplicate(true)
    _vertex_values.clear()
    var prioritized: Dictionary = {}
    for cell in priority_cells:
        prioritized[Vector2i(cell)] = true
    for cell in current.keys():
        var coords := Vector2i(cell)
        if not prioritized.has(coords):
            if _has_pattern_vertices(previous, coords):
                _restore_pattern_vertices(previous, coords)
            else:
                _write_pattern_vertices(coords, int(current[coords]))
    for cell in priority_cells:
        var coords := Vector2i(cell)
        if current.has(coords):
            _write_pattern_vertices(coords, int(current[coords]))

func _has_pattern_vertices(vertices: Dictionary, cell: Vector2i) -> bool:
    return (
        vertices.has(cell)
        and vertices.has(cell + Vector2i(1, 0))
        and vertices.has(cell + Vector2i(0, 1))
        and vertices.has(cell + Vector2i(1, 1))
    )

func _restore_pattern_vertices(vertices: Dictionary, cell: Vector2i) -> void:
    _vertex_values[cell] = int(vertices[cell])
    _vertex_values[cell + Vector2i(1, 0)] = int(vertices[cell + Vector2i(1, 0)])
    _vertex_values[cell + Vector2i(0, 1)] = int(vertices[cell + Vector2i(0, 1)])
    _vertex_values[cell + Vector2i(1, 1)] = int(vertices[cell + Vector2i(1, 1)])

func _write_pattern_vertices(cell: Vector2i, tile_index: int) -> void:
    var entry := _rule_entry(tile_index)
    var pattern = entry.get("pattern")
    if not pattern is Array or pattern.size() != 4:
        return
    _vertex_values[cell] = _base_pattern_value(int(pattern[1][1]))
    _vertex_values[cell + Vector2i(1, 0)] = _base_pattern_value(int(pattern[1][2]))
    _vertex_values[cell + Vector2i(0, 1)] = _base_pattern_value(int(pattern[2][1]))
    _vertex_values[cell + Vector2i(1, 1)] = _base_pattern_value(int(pattern[2][2]))

func _replace_pattern_tiles_with_paint_tiles() -> void:
    var paint_tiles := {
        0: _canonical_pattern_tile(0),
        1: _canonical_pattern_tile(1),
    }
    for cell in tile_map.get_used_cells():
        var terrain := int(_vertex_values.get(cell, 0))
        var tile_index := int(paint_tiles.get(terrain, -1))
        if tile_index >= 0:
            _set_tile_index(cell, tile_index)

func _pattern_cells_are_paint_tiles() -> bool:
    for cell in tile_map.get_used_cells():
        var tile_data := tile_map.get_cell_tile_data(cell)
        if tile_data == null or tile_data.get_terrain() < 0:
            return false
    return true

func _load_pattern_paint_values() -> void:
    _vertex_values.clear()
    for cell in tile_map.get_used_cells():
        var tile_data := tile_map.get_cell_tile_data(cell)
        if tile_data != null and tile_data.get_terrain() >= 0:
            _vertex_values[cell] = tile_data.get_terrain()

func _load_exported_paint_values() -> bool:
    var values = layer_data.get("paintValues", [])
    if not values is Array or values.is_empty():
        return false
    _vertex_values.clear()
    for entry in values:
        _vertex_values[Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))] = int(entry.get("value", 0))
    return true

func _canonical_pattern_tile(terrain: int) -> int:
    for tile_index in _rule_indices():
        var candidate = _rule_entry(tile_index).get("pattern")
        if not candidate is Array or candidate.size() != 4:
            continue
        if (
            int(candidate[1][1]) == terrain
            and int(candidate[1][2]) == terrain
            and int(candidate[2][1]) == terrain
            and int(candidate[2][2]) == terrain
        ):
            return tile_index
    return -1

func _pattern_for_cell(cell: Vector2i) -> Array:
    var wildcard := int(_auto_rules.get("wildcard", 255))
    var derive_transition := _uses_transition_patterns()
    var sidescroller := bool(layer_data.get("sidescroller", false))
    var center_fallback := wildcard
    if sidescroller:
        center_fallback = 1
    elif not derive_transition and _vertex_values.has(cell):
        center_fallback = int(_vertex_values[cell])
    var pattern: Array = []
    for row in range(4):
        var values: Array = []
        for column in range(4):
            var position := cell + Vector2i(column - 1, row - 1)
            var fallback := center_fallback if row in [1, 2] and column in [1, 2] else wildcard
            var value := int(_vertex_values.get(position, fallback))
            if (
                derive_transition
                and value == 0
                and int(_vertex_values.get(position + Vector2i(0, -1), wildcard)) == 1
            ):
                value = 2
            values.append(value)
        pattern.append(values)
    return pattern

func _tile_for_pattern(request: Array) -> int:
    if not _uses_transition_patterns():
        return _exact_tile_for_pattern(request)
    var exact_tile := _exact_tile_for_pattern(request)
    if exact_tile >= 0:
        return exact_tile
    var best_tile := -1
    var best_score := -2147483648
    var best_wildcards := 2147483647
    for tile_index in _rule_indices():
        var candidate = _rule_entry(tile_index).get("pattern")
        if not candidate is Array:
            continue
        var score := _pattern_score(candidate, request)
        var wildcards := _pattern_wildcards(candidate)
        if score > best_score or (score == best_score and wildcards < best_wildcards):
            best_tile = tile_index
            best_score = score
            best_wildcards = wildcards
    return best_tile

func _exact_tile_for_pattern(request: Array) -> int:
    var best_tile := -1
    var best_wildcards := 2147483647
    for tile_index in _rule_indices():
        var candidate = _rule_entry(tile_index).get("pattern")
        if not candidate is Array or not _patterns_match(candidate, request):
            continue
        var wildcards := _pattern_wildcards(candidate)
        if wildcards < best_wildcards:
            best_tile = tile_index
            best_wildcards = wildcards
    return best_tile

func _pattern_score(candidate: Array, request: Array) -> int:
    var wildcard := int(_auto_rules.get("wildcard", 255))
    var score := 0
    for row in range(4):
        for column in range(4):
            var expected := int(candidate[row][column])
            var actual := int(request[row][column])
            if expected == wildcard or actual == wildcard:
                continue
            var center := row in [1, 2] and column in [1, 2]
            if expected == actual:
                score += PATTERN_CENTER_MATCH_SCORE if center else PATTERN_RING_MATCH_SCORE
            else:
                score += PATTERN_CENTER_MISMATCH_SCORE if center else PATTERN_RING_MISMATCH_SCORE
    return score

func _uses_transition_patterns() -> bool:
    var terrain_names: Array = _auto_rules.get("terrains", [])
    return terrain_names.size() > 2

func _uses_pattern_rules() -> bool:
    return str(_auto_rules.get("rule_type", "")) == "pattern_4x4"

func _base_pattern_value(value: int) -> int:
    if _uses_transition_patterns() and value == 2:
        return 0
    return value

func _patterns_match(first: Array, second: Array) -> bool:
    var wildcard := int(_auto_rules.get("wildcard", 255))
    for row in range(4):
        for column in range(4):
            var left := int(first[row][column])
            var right := int(second[row][column])
            if left != wildcard and right != wildcard and left != right:
                return false
    return true

func _pattern_wildcards(pattern: Array) -> int:
    var wildcard := int(_auto_rules.get("wildcard", 255))
    var count := 0
    for row in pattern:
        for value in row:
            if int(value) == wildcard:
                count += 1
    return count

func _rebuild_vertex_values(current: Dictionary, priority_cells: Array) -> void:
    _vertex_values.clear()
    var prioritized: Dictionary = {}
    for cell in priority_cells:
        var coords := Vector2i(cell)
        prioritized[coords] = true
        if current.has(coords):
            var mask := _mask_for_tile(int(current[coords]))
            if mask >= 0:
                _write_cell_vertices(coords, mask)
    for cell in current.keys():
        var coords := Vector2i(cell)
        if prioritized.has(coords):
            continue
        var mask := _mask_for_tile(int(current[coords]))
        if mask >= 0:
            _write_cell_vertices(coords, mask)

func _write_cell_vertices(cell: Vector2i, mask: int) -> void:
    _vertex_values[cell] = (mask >> 3) & 1
    _vertex_values[cell + Vector2i(1, 0)] = (mask >> 2) & 1
    _vertex_values[cell + Vector2i(0, 1)] = (mask >> 1) & 1
    _vertex_values[cell + Vector2i(1, 1)] = mask & 1

func _corner_mask_for_cell(cell: Vector2i) -> int:
    var mask := 0
    if int(_vertex_values.get(cell, 0)) != 0:
        mask |= 8
    if int(_vertex_values.get(cell + Vector2i(1, 0), 0)) != 0:
        mask |= 4
    if int(_vertex_values.get(cell + Vector2i(0, 1), 0)) != 0:
        mask |= 2
    if int(_vertex_values.get(cell + Vector2i(1, 1), 0)) != 0:
        mask |= 1
    return mask

func _edge_offsets(grid_kind: String, arity: int) -> Array:
    if arity == 4:
        return [
            Vector2i(0, -1),
            Vector2i(1, 0),
            Vector2i(0, 1),
            Vector2i(-1, 0)
        ]
    if grid_kind == "hex-pointy-top":
        return [
            Vector2i(0, 1),
            Vector2i(-1, 1),
            Vector2i(-1, 0),
            Vector2i(0, -1),
            Vector2i(1, -1),
            Vector2i(1, 0)
        ]
    return [
        Vector2i(1, 0),
        Vector2i(0, 1),
        Vector2i(-1, 1),
        Vector2i(-1, 0),
        Vector2i(0, -1),
        Vector2i(1, -1)
    ]

func _rule_indices() -> Array:
    var indices: Array = []
    var tiles: Dictionary = _auto_rules.get("tiles", {})
    for key in tiles.keys():
        var text_key := str(key)
        if text_key.begins_with("tile_") and text_key.substr(5).is_valid_int():
            indices.append(int(text_key.substr(5)))
    indices.sort()
    return indices

func _rule_entry(tile_index: int) -> Dictionary:
    var tiles: Dictionary = _auto_rules.get("tiles", {})
    var entry = tiles.get("tile_%d" % tile_index)
    return entry if entry is Dictionary else {}

func _mask_for_tile(tile_index: int) -> int:
    var entry := _rule_entry(tile_index)
    return int(entry.get("mask", -1)) if not entry.is_empty() else -1

func _tile_for_mask(mask: int, arity: int) -> int:
    var indices := _rule_indices()
    var best_tile := -1
    var best_score := -1
    for tile_index in indices:
        var entry := _rule_entry(tile_index)
        var configured_masks = entry.get("masks")
        var masks: Array = []
        if configured_masks is Array:
            masks = configured_masks
        else:
            masks = [int(entry.get("mask", -1))]
        for candidate in masks:
            var candidate_mask := int(candidate)
            if candidate_mask == mask:
                return tile_index
            var score := arity - _popcount(candidate_mask ^ mask)
            if score > best_score:
                best_score = score
                best_tile = tile_index
    return best_tile

func _popcount(value: int) -> int:
    var count := 0
    var remaining := value
    while remaining != 0:
        count += remaining & 1
        remaining >>= 1
    return count

func _terrain_for_tile(tile_index: int) -> String:
    if tile_index < 0:
        return "empty"
    var entry := _rule_entry(tile_index)
    if entry.is_empty():
        return "filler" if tile_index == _filler_tile_index() else "empty"
    if str(_auto_rules.get("connectivity", "same")) == "same" and int(entry.get("mask", -1)) == 0:
        return "ground"
    return "feature"

func _filler_tile_index() -> int:
    if str(_auto_rules.get("connectivity", "same")) != "other":
        return -1
    var assets: Dictionary = layer_data.get("assetPaths", {})
    var asset_indices: Array = []
    for key in assets.keys():
        asset_indices.append(int(key))
    asset_indices.sort()
    for tile_index in asset_indices:
        if _rule_entry(tile_index).is_empty():
            return tile_index
    return -1

func _set_tile_index(cell: Vector2i, tile_index: int) -> void:
    if legacy:
        var columns := int(layer_data.get("atlasColumns", 4))
        tile_map.set_cell(
            cell,
            0,
            Vector2i(tile_index % columns, tile_index / columns)
        )
        return
    if not _tile_to_source.has(tile_index):
        return
    tile_map.set_cell(cell, int(_tile_to_source[tile_index]), Vector2i.ZERO)
