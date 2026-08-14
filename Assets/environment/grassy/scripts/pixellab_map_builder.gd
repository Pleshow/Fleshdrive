@tool
extends Node2D

const MANIFEST_PATH := "res://pixellab/engine-map.json"
const RENDERER_SCRIPT := preload("res://scripts/pixellab_tile_layer_renderer.gd")
const BUILDINGS_CONTROLLER_SCRIPT_PATH := "res://scripts/pixellab_buildings_controller.gd"

func _ready() -> void:
    if get_node_or_null("Tile Layers") != null:
        return
    _build_tile_layers()

func _build_tile_layers() -> void:
    var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if file == null:
        push_error("PixelLab engine manifest could not be opened")
        return
    var manifest = JSON.parse_string(file.get_as_text())
    if not manifest is Dictionary:
        push_error("PixelLab engine manifest is invalid")
        return

    var parent := Node2D.new()
    parent.name = "Tile Layers"
    # Objects carry z_index = drawOrder (>= 0); keep runtime-built tile
    # renderers below them so a layer-0 object is never painted over.
    parent.z_index = -1
    add_child(parent)
    _set_owner(parent)

    var legacy: Dictionary = manifest.get("legacyTerrain", {})
    for layer in legacy.get("layers", []):
        _build_legacy_layer(parent, layer, legacy.get("tileSize", {}))

    var projection_layers: Array = manifest.get("projectionLayers", [])
    for layer_index in range(projection_layers.size()):
        _build_projection_layer(parent, projection_layers[layer_index], layer_index)

    for kit in manifest.get("buildingKits", []):
        _build_building_kit(parent, kit)

func _build_building_kit(parent: Node2D, kit: Dictionary) -> void:
    var controller_script = load(BUILDINGS_CONTROLLER_SCRIPT_PATH)
    if controller_script == null:
        push_error("PixelLab Buildings controller script is missing")
        return
    var controller = controller_script.new()
    controller.name = "Buildings - %s" % str(kit.get("name", kit.get("id", "Kit")))
    controller.kit_id = str(kit.get("id", ""))
    controller.editor_description = "PixelLab native Buildings kit. Select this node to open semantic floor, roof, wall, door, stair, pillar, stamp, and storey tools. Generated visual lanes are managed internally."
    parent.add_child(controller)
    _set_owner(controller)

func _build_projection_layer(parent: Node2D, layer: Dictionary, layer_index: int) -> void:
    var tile_set_data := _projection_tile_set(layer)
    var cells_by_y: Dictionary = {}
    for cell in layer.get("cells", []):
        var layer_y := int(cell.get("layerY", 0))
        if not cells_by_y.has(layer_y):
            cells_by_y[layer_y] = []
        cells_by_y[layer_y].append(cell)
    if cells_by_y.is_empty():
        cells_by_y[0] = []

    var terrains_configured := false
    for layer_y in cells_by_y.keys():
        var tile_layer := TileMapLayer.new()
        var layer_name: String = str(
            layer.get("tileGroupName", layer.get("gridKind", "Tiles"))
        )
        var height_label: String
        if layer_y == 0:
            height_label = "GROUND"
        elif layer_y > 0:
            height_label = "ELEVATED +%d" % layer_y
        else:
            height_label = "LOWER %d" % abs(layer_y)
        tile_layer.name = "Y%d - %s - %s" % [
            layer_y,
            height_label,
            layer_name,
        ]
        tile_layer.editor_description = "PixelLab projected paint layer Y%d (%s). Godot paints only the selected TileMapLayer. Select the Y level matching the surface you want; Y0 is ground, and each positive level is one stack stride higher." % [
            layer_y,
            height_label,
        ]
        tile_layer.set_meta("pixellab_layer_y", layer_y)
        tile_layer.tile_set = tile_set_data["tile_set"]
        _align_projection_tile_layer(tile_layer, layer, layer_y)
        if not terrains_configured:
            _configure_projection_terrains(tile_layer, layer, tile_set_data["source_to_tile"])
            terrains_configured = true
        tile_layer.modulate = Color(1, 1, 1, 0)
        parent.add_child(tile_layer)
        _set_owner(tile_layer)
        for cell in cells_by_y[layer_y]:
            var tile_index := int(cell.get("tileIndex", 0))
            if tile_set_data["source_to_tile"].has(tile_index):
                tile_layer.set_cell(
                    Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0))),
                    int(tile_set_data["source_to_tile"][tile_index]),
                    Vector2i.ZERO
                )
        _add_renderer(parent, tile_layer, layer, tile_set_data["source_to_tile"], layer_index, layer_y, false)

func _build_legacy_layer(parent: Node2D, layer: Dictionary, tile_size: Dictionary) -> void:
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(
        int(tile_size.get("width", 16)),
        int(tile_size.get("height", 16))
    )
    var atlas := TileSetAtlasSource.new()
    var texture := load(str(layer.get("image", ""))) as Texture2D
    if texture == null:
        return
    atlas.texture = texture
    atlas.texture_region_size = tile_set.tile_size
    var atlas_columns := int(layer.get("atlasColumns", 4))
    var atlas_tiles: Array = layer.get("atlasTiles", [])
    if atlas_tiles.is_empty():
        for atlas_index in range(atlas_columns * int(layer.get("atlasRows", 4))):
            atlas.create_tile(Vector2i(atlas_index % atlas_columns, atlas_index / atlas_columns))
    else:
        for atlas_index in atlas_tiles:
            var tile_index := int(atlas_index)
            atlas.create_tile(Vector2i(tile_index % atlas_columns, tile_index / atlas_columns))
    tile_set.add_source(atlas, 0)
    _configure_legacy_terrains(tile_set, atlas, layer)

    var tile_layer := TileMapLayer.new()
    tile_layer.name = "Y0 - GROUND - %s" % str(layer.get("name", "Topdown"))
    tile_layer.editor_description = "PixelLab ground paint layer Y0. Godot paints only the selected TileMapLayer."
    tile_layer.tile_set = tile_set
    tile_layer.modulate = Color(1, 1, 1, 0)
    parent.add_child(tile_layer)
    _set_owner(tile_layer)
    for placement in layer.get("placements", []):
        var atlas_index := int(placement.get("tileIndex", 0))
        tile_layer.set_cell(
            Vector2i(int(placement.get("q", 0)), int(placement.get("r", 0))),
            0,
            Vector2i(atlas_index % atlas_columns, atlas_index / atlas_columns)
        )
    var renderer_layer := layer.duplicate(true)
    renderer_layer["tileSize"] = tile_size
    _add_renderer(parent, tile_layer, renderer_layer, {0: 0}, -1, 0, true)

func _projection_tile_set(layer: Dictionary) -> Dictionary:
    var tile_set := TileSet.new()
    var projection: Dictionary = layer.get("projection", {})
    var cell_size: Dictionary = projection.get("cellSize", {})
    tile_set.tile_size = Vector2i(
        int(cell_size.get("width", layer.get("tileW", 16))),
        int(cell_size.get("height", layer.get("tileH", 16)))
    )
    var grid_kind := str(layer.get("gridKind", ""))
    if grid_kind == "iso":
        tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
        tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
    elif grid_kind == "hex-flat-top" or grid_kind == "hex-pointy-top":
        tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
        tile_set.tile_layout = (
            TileSet.TILE_LAYOUT_STAIRS_DOWN
            if grid_kind == "hex-flat-top"
            else TileSet.TILE_LAYOUT_STAIRS_RIGHT
        )
        tile_set.tile_offset_axis = (
            TileSet.TILE_OFFSET_AXIS_VERTICAL
            if grid_kind == "hex-flat-top"
            else TileSet.TILE_OFFSET_AXIS_HORIZONTAL
        )

    var source_to_tile: Dictionary = {}
    for asset in layer.get("tileAssets", []):
        var texture := load(str(asset.get("assetPath", ""))) as Texture2D
        if texture == null:
            continue
        var source := TileSetAtlasSource.new()
        source.texture = texture
        source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
        source.create_tile(Vector2i.ZERO)
        var source_id := tile_set.get_next_source_id()
        tile_set.add_source(source, source_id)
        source_to_tile[int(asset.get("tileIndex", 0))] = source_id
    return {"tile_set": tile_set, "source_to_tile": source_to_tile}

func _align_projection_tile_layer(
    tile_layer: TileMapLayer,
    layer: Dictionary,
    layer_y: int = 0
) -> void:
    var projection: Dictionary = layer.get("projection", {})
    var origin_data: Dictionary = projection.get(
        "editorOrigin",
        projection.get("origin", {})
    )
    var q_data: Dictionary = projection.get("qBasis", {})
    var r_data: Dictionary = projection.get("rBasis", {})
    var stack_data: Dictionary = projection.get("stackBasis", {})
    var desired_origin := Vector2(
        float(origin_data.get("x", 0)),
        float(origin_data.get("y", 0))
    )
    desired_origin += layer_y * Vector2(
        float(stack_data.get("x", 0)),
        float(stack_data.get("y", 0))
    )
    var desired_q := Vector2(
        float(q_data.get("x", 0)),
        float(q_data.get("y", 0))
    )
    var desired_r := Vector2(
        float(r_data.get("x", 0)),
        float(r_data.get("y", 0))
    )
    var native_origin := tile_layer.map_to_local(Vector2i.ZERO)
    var native_q := tile_layer.map_to_local(Vector2i(1, 0)) - native_origin
    var native_r := tile_layer.map_to_local(Vector2i(0, 1)) - native_origin
    var determinant := native_q.x * native_r.y - native_r.x * native_q.y
    var m00 := (desired_q.x * native_r.y - desired_r.x * native_q.y) / determinant
    var m01 := (-desired_q.x * native_r.x + desired_r.x * native_q.x) / determinant
    var m10 := (desired_q.y * native_r.y - desired_r.y * native_q.y) / determinant
    var m11 := (-desired_q.y * native_r.x + desired_r.y * native_q.x) / determinant
    var x_basis := Vector2(m00, m10)
    var y_basis := Vector2(m01, m11)
    var translation := desired_origin - Vector2(
        x_basis.x * native_origin.x + y_basis.x * native_origin.y,
        x_basis.y * native_origin.x + y_basis.y * native_origin.y
    )
    tile_layer.transform = Transform2D(x_basis, y_basis, translation)

func _configure_projection_terrains(
    tile_layer: TileMapLayer,
    layer: Dictionary,
    source_to_tile: Dictionary
) -> void:
    var rules = layer.get("tileRules", {})
    if rules == null or not rules is Dictionary or rules.is_empty():
        return
    var rule_type := str(rules.get("rule_type", ""))
    var arity := int(rules.get("arity", 0))
    var grid_kind := str(layer.get("gridKind", ""))
    if rule_type == "corner":
        if arity != 4 or grid_kind == "hex-flat-top" or grid_kind == "hex-pointy-top":
            return
    elif rule_type == "edge":
        if arity == 4 and (grid_kind == "hex-flat-top" or grid_kind == "hex-pointy-top"):
            return
        if arity == 6 and grid_kind != "hex-flat-top" and grid_kind != "hex-pointy-top":
            return
        if arity != 4 and arity != 6:
            return
    else:
        return

    var tile_set: TileSet = tile_layer.tile_set
    var terrain_set := tile_set.get_terrain_sets_count()
    tile_set.add_terrain_set()
    var terrain_names = rules.get("terrains", [])
    for terrain_index in range(2):
        tile_set.add_terrain(terrain_set, terrain_index)
        if terrain_names is Array and terrain_index < terrain_names.size():
            tile_set.set_terrain_name(terrain_set, terrain_index, str(terrain_names[terrain_index]))
    tile_set.set_terrain_set_mode(
        terrain_set,
        TileSet.TERRAIN_MODE_MATCH_CORNERS
        if rule_type == "corner"
        else TileSet.TERRAIN_MODE_MATCH_SIDES
    )

    var peering_bits: Array = []
    if rule_type == "corner":
        peering_bits = _corner_peering_bits(grid_kind)
    elif arity == 4:
        peering_bits = _four_edge_peering_bits(grid_kind)
    else:
        peering_bits = _hex_edge_peering_bits(grid_kind)

    var rule_tiles: Dictionary = rules.get("tiles", {})
    for asset_tile_index in source_to_tile.keys():
        var tile_index := int(asset_tile_index)
        var source_id := int(source_to_tile[asset_tile_index])
        var source := tile_set.get_source(source_id) as TileSetAtlasSource
        if source == null:
            continue
        var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
        tile_data.set_terrain_set(terrain_set)
        var rule_entry = rule_tiles.get("tile_%d" % tile_index, {})
        var is_filler: bool = rule_entry.is_empty() and str(rules.get("connectivity", "same")) == "other"
        var mask := int(rule_entry.get("mask", 0))
        var tile_terrain := 1 if is_filler else 0
        if rule_type == "corner" and mask == 0:
            tile_terrain = 1
        tile_data.set_terrain(tile_terrain)
        for bit_index in range(peering_bits.size()):
            var peering_bit := int(peering_bits[bit_index])
            if peering_bit < 0:
                continue
            var terrain := 0
            if is_filler:
                terrain = 1
            elif rule_type == "corner":
                terrain = 1 - ((mask >> bit_index) & 1)
            elif str(rules.get("connectivity", "same")) == "other":
                terrain = (mask >> bit_index) & 1
            else:
                terrain = 0 if ((mask >> bit_index) & 1) != 0 else 1
            tile_data.set_terrain_peering_bit(peering_bit, terrain)

    _add_projection_terrain_aliases(
        tile_set,
        rules,
        source_to_tile,
        terrain_set,
        rule_type,
        arity,
        peering_bits
    )

func _add_projection_terrain_aliases(
    tile_set: TileSet,
    rules: Dictionary,
    source_to_tile: Dictionary,
    terrain_set: int,
    rule_type: String,
    arity: int,
    peering_bits: Array
) -> void:
    var rule_tiles: Dictionary = rules.get("tiles", {})
    var filler_tile := _projection_filler_tile(rule_tiles, source_to_tile)
    for mask in range(1 << arity):
        var visual_tile := _closest_projection_tile_for_mask(rule_tiles, mask, arity)
        for center_terrain in range(2):
            var alias_tile := visual_tile
            if (
                rule_type == "edge"
                and str(rules.get("connectivity", "same")) == "other"
                and center_terrain == 1
            ):
                alias_tile = filler_tile
            if alias_tile < 0 or not source_to_tile.has(alias_tile):
                continue
            var source := tile_set.get_source(int(source_to_tile[alias_tile])) as TileSetAtlasSource
            if source == null:
                continue
            var alternative := source.create_alternative_tile(Vector2i.ZERO)
            var tile_data := source.get_tile_data(Vector2i.ZERO, alternative)
            tile_data.set_terrain_set(terrain_set)
            tile_data.set_terrain(center_terrain)
            for bit_index in range(peering_bits.size()):
                var peering_bit := int(peering_bits[bit_index])
                if peering_bit < 0:
                    continue
                var terrain := 0
                if rule_type == "corner":
                    terrain = 1 - ((mask >> bit_index) & 1)
                elif str(rules.get("connectivity", "same")) == "other":
                    terrain = (mask >> bit_index) & 1
                else:
                    terrain = 0 if ((mask >> bit_index) & 1) != 0 else 1
                tile_data.set_terrain_peering_bit(peering_bit, terrain)

func _projection_filler_tile(
    rule_tiles: Dictionary,
    source_to_tile: Dictionary
) -> int:
    for tile_index in source_to_tile.keys():
        if not rule_tiles.has("tile_%d" % int(tile_index)):
            return int(tile_index)
    return -1

func _closest_projection_tile_for_mask(
    rule_tiles: Dictionary,
    mask: int,
    arity: int
) -> int:
    var best_tile := -1
    var best_score := -1
    for key in rule_tiles.keys():
        var text_key := str(key)
        if not text_key.begins_with("tile_") or not text_key.substr(5).is_valid_int():
            continue
        var tile_index := int(text_key.substr(5))
        var entry = rule_tiles[key]
        if not entry is Dictionary:
            continue
        var masks: Array = []
        var configured_masks = entry.get("masks")
        if configured_masks is Array:
            masks = configured_masks
        else:
            masks = [int(entry.get("mask", -1))]
        for candidate in masks:
            var candidate_mask := int(candidate)
            if candidate_mask == mask:
                return tile_index
            var score := arity - _projection_popcount(candidate_mask ^ mask)
            if score > best_score or (score == best_score and tile_index < best_tile):
                best_tile = tile_index
                best_score = score
    return best_tile

func _projection_popcount(value: int) -> int:
    var count := 0
    var remaining := value
    while remaining != 0:
        count += remaining & 1
        remaining >>= 1
    return count

func _configure_legacy_terrains(
    tile_set: TileSet,
    atlas: TileSetAtlasSource,
    layer: Dictionary
) -> void:
    var rules = layer.get("tileRules", {})
    if not rules is Dictionary or str(rules.get("rule_type", "")) != "pattern_4x4":
        return
    var terrain_names: Array = rules.get("terrains", [])
    if terrain_names.is_empty():
        return
    var terrain_set := tile_set.get_terrain_sets_count()
    tile_set.add_terrain_set()
    tile_set.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_CORNERS)
    var paint_terrain_count: int = min(2, terrain_names.size())
    for terrain_index in range(paint_terrain_count):
        tile_set.add_terrain(terrain_set, terrain_index)
        tile_set.set_terrain_name(
            terrain_set,
            terrain_index,
            str(terrain_names[terrain_index])
        )

    var columns := int(layer.get("atlasColumns", 4))
    var rule_tiles: Dictionary = rules.get("tiles", {})
    for key in rule_tiles.keys():
        var tile_index := int(str(key).trim_prefix("tile_"))
        var coords := Vector2i(tile_index % columns, tile_index / columns)
        if not atlas.has_tile(coords):
            continue
        var entry: Dictionary = rule_tiles[key]
        var pattern: Array = entry.get("pattern", [])
        if pattern.size() != 4:
            continue
        var corners := [
            int(pattern[1][1]),
            int(pattern[1][2]),
            int(pattern[2][1]),
            int(pattern[2][2]),
        ]
        var tile_data := atlas.get_tile_data(coords, 0)
        var paint_terrain := int(corners[0])
        var canonical := paint_terrain == 0 or paint_terrain == 1
        for corner in corners:
            if int(corner) != paint_terrain:
                canonical = false
                break
        if canonical:
            tile_data.set_terrain_set(terrain_set)
            tile_data.set_terrain(paint_terrain)

func _four_edge_peering_bits(grid_kind: String) -> Array:
    if grid_kind == "iso":
        return [14, 2, 6, 10]
    return [12, 0, 4, 8]

func _hex_edge_peering_bits(grid_kind: String) -> Array:
    if grid_kind == "hex-pointy-top":
        return [2, 6, 8, 10, 14, 0]
    return [2, 4, 6, 10, 12, 14]

func _corner_peering_bits(grid_kind: String) -> Array:
    if grid_kind == "iso":
        return [5, 9, 1, 13]
    return [3, 7, 15, 11]

func _add_renderer(
    parent: Node2D,
    tile_layer: TileMapLayer,
    layer: Dictionary,
    source_to_tile: Dictionary,
    layer_index: int,
    layer_y: int,
    legacy: bool
) -> void:
    var renderer := Node2D.new()
    renderer.name = "Renderer Y%s" % str(layer_y)
    renderer.set_script(RENDERER_SCRIPT)
    renderer.set("tile_map", tile_layer)
    renderer.set("layer_data", layer)
    renderer.set("source_to_tile", _invert_source_map(source_to_tile))
    renderer.set("layer_y", layer_y)
    renderer.set("legacy", legacy)
    parent.add_child(renderer)
    _set_owner(renderer)

func _invert_source_map(source_to_tile: Dictionary) -> Dictionary:
    var inverted: Dictionary = {}
    for tile_index in source_to_tile.keys():
        inverted[source_to_tile[tile_index]] = tile_index
    return inverted

func _set_owner(node: Node) -> void:
    if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
        node.owner = get_tree().edited_scene_root
