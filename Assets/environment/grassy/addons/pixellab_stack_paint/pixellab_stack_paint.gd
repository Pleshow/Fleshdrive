@tool
extends EditorPlugin

const TILE_LAYER_PARENT := "Tile Layers"
const LAYER_Y_META := "pixellab_layer_y"

func _handles(object: Object) -> bool:
    # Without _handles the editor never routes _forward_canvas_gui_input to
    # this plugin. Claim only PixelLab stack layers (marked with our meta),
    # never the user's own TileMapLayers.
    return object is TileMapLayer and object.has_meta(LAYER_Y_META)

func _edit(_object: Object) -> void:
    pass

func _forward_canvas_gui_input(event: InputEvent) -> bool:
    if not event is InputEventMouseButton:
        return false
    var button_event := event as InputEventMouseButton
    if button_event == null or not button_event.pressed:
        return false
    if button_event.button_index != MOUSE_BUTTON_LEFT:
        return false

    var selected_nodes := get_editor_interface().get_selection().get_selected_nodes()
    if selected_nodes.size() != 1 or not selected_nodes[0] is TileMapLayer:
        return false
    if not selected_nodes[0].has_meta(LAYER_Y_META):
        return false
    var layers := _projection_layers()
    if layers.size() < 2:
        return false

    var surface_layer = _surface_layer_at(button_event.position, layers)
    if surface_layer == null:
        return false
    if button_event.ctrl_pressed:
        surface_layer = _layer_for_y(layers, _layer_y(surface_layer) + 1)
        if surface_layer == null:
            return false
    _select_layer(surface_layer)
    return false

func _projection_layers() -> Array:
    var root := get_editor_interface().get_edited_scene_root()
    if root == null:
        return []
    var parent := root.get_node_or_null(TILE_LAYER_PARENT)
    if parent == null:
        return []
    var layers: Array = []
    for child in parent.get_children():
        if child is TileMapLayer and child.has_meta(LAYER_Y_META):
            layers.append(child)
    return layers

func _surface_layer_at(screen_position: Vector2, layers: Array):
    var best_layer = null
    var best_y := -2147483648
    for layer in layers:
        var local_position: Vector2 = layer.get_global_transform_with_canvas().affine_inverse() * screen_position
        var cell: Vector2i = layer.local_to_map(local_position)
        if layer.get_cell_source_id(cell) == -1:
            continue
        var layer_y := _layer_y(layer)
        if layer_y > best_y:
            best_y = layer_y
            best_layer = layer
    return best_layer

func _layer_for_y(layers: Array, layer_y: int):
    for layer in layers:
        if _layer_y(layer) == layer_y:
            return layer
    return null

func _layer_y(layer: TileMapLayer) -> int:
    return int(layer.get_meta(LAYER_Y_META, 0))

func _select_layer(layer) -> void:
    var selection := get_editor_interface().get_selection()
    var selected_nodes := selection.get_selected_nodes()
    if selected_nodes.size() == 1 and selected_nodes[0] == layer:
        return
    selection.clear()
    selection.add_node(layer)
