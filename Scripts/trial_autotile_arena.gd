class_name TrialAutotileArena
extends PlaceholderArena


# Keep the gameplay boundary contract from PlaceholderArena, but do not build
# its legacy runtime visuals. The manually painted TileMapLayer children are
# the complete visual arena in this scene.
func _ready() -> void:
	_create_boundary_collisions()
	_refresh_manual_tile_layers.call_deferred()


func _refresh_manual_tile_layers() -> void:
	var unshaded_material := CanvasItemMaterial.new()
	unshaded_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var layer_z := {
		&"FloorTiles": -2,
		&"WallTiles": -1,
		&"HazardTiles": 0,
	}
	for node_name in layer_z:
		var layer := get_node_or_null(NodePath(node_name)) as TileMapLayer
		if layer == null:
			push_error("TrialAutotileArena: missing %s" % node_name)
			continue
		layer.material = unshaded_material
		layer.z_index = int(layer_z[node_name])
		layer.z_as_relative = false
		layer.modulate = Color.WHITE
		layer.self_modulate = Color.WHITE
		layer.visibility_layer = 1
		layer.enabled = true
		layer.show()
		layer.notify_runtime_tile_data_update()
		layer.update_internals()
		layer.queue_redraw()
