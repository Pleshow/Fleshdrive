class_name DuskGardenArena
extends Node2D


const MAP_TEXTURE: Texture2D = preload(
	"res://Assets/environment/dusk_garden_map.png"
)
const MAP_OFFSET := Vector2(16.0, 160.0)
const PLAY_BOUNDS := Rect2(64.0, 208.0, 2432.0, 1024.0)
const CAMERA_BOUNDS := Rect2(0.0, 0.0, 2560.0, 1440.0)
const SAFE_CENTER := Vector2(1280.0, 720.0)
const WALL_THICKNESS := 48.0
const ACTOR_CONSTRAINT_INTERVAL := 0.08
const OCCLUDING_PROP_DATA := [
	{
		"name": "DryGrassSmall01",
		"texture": "72f82453-c2c9-4417-8794-c967b1a01699.png",
		"top_left": Vector2(297.333, 583.667),
		"size": Vector2(20.0, 26.0),
	},
	{
		"name": "DryGrassSmall02",
		"texture": "3054d7e5-4a2d-4097-9bc8-771240148f9b.png",
		"top_left": Vector2(311.333, 577.333),
		"size": Vector2(20.0, 26.0),
	},
	{
		"name": "DryGrassTall01",
		"texture": "e2467ec7-b4a8-49ad-bb6a-18daf5b30568.png",
		"top_left": Vector2(284.0, 540.333),
		"size": Vector2(35.0, 60.0),
	},
	{
		"name": "TwistedTree01",
		"texture": "9b4cf333-eeb7-4008-b1ab-319b0f78b310.png",
		"top_left": Vector2(1081.0, 214.0),
		"size": Vector2(68.0, 79.0),
	},
	{
		"name": "TwistedTree02",
		"texture": "8dcb5dfc-fa57-4192-ab19-bb593c42d7bc.png",
		"top_left": Vector2(293.0, 366.0),
		"size": Vector2(68.0, 79.0),
	},
	{
		"name": "TwistedTree03",
		"texture": "02675ec9-1ec0-422c-b363-8748a6f3c26d.png",
		"top_left": Vector2(1488.0, 509.0),
		"size": Vector2(68.0, 79.0),
	},
	{
		"name": "DryGrassSmall03",
		"texture": "b75164c8-36d6-463b-afcc-2360cd6030f1.png",
		"top_left": Vector2(1115.333, 273.333),
		"size": Vector2(20.0, 26.0),
	},
	{
		"name": "DryGrassTall02",
		"texture": "05f2d971-55f0-4727-9049-9ef31b45dead.png",
		"top_left": Vector2(955.0, 863.333),
		"size": Vector2(35.0, 60.0),
	},
	{
		"name": "BrokenTree01",
		"texture": "a223aeea-29a3-48ed-8b90-8a06e3e9f3f6.png",
		"top_left": Vector2(1795.0, 272.0),
		"size": Vector2(74.0, 81.0),
	},
]
const OCCLUDING_PROP_ROOT := "res://Assets/environment/dusk_garden_props/"

var constraint_time := 0.0


func _ready() -> void:
	add_to_group("walkable_arena")
	y_sort_enabled = true
	_create_backdrop()
	_create_map_visual()
	_create_occluding_props()
	_create_pixel_motes()
	_create_boundary_collision()


func _process(delta: float) -> void:
	constraint_time += delta
	if constraint_time >= ACTOR_CONSTRAINT_INTERVAL:
		constraint_time = 0.0
		_enforce_walkable_actors()


func _create_backdrop() -> void:
	var backdrop := Polygon2D.new()
	backdrop.name = "NightBackdrop"
	backdrop.z_index = -120
	backdrop.polygon = PackedVector2Array([
		Vector2(-600.0, -400.0), Vector2(3160.0, -400.0),
		Vector2(3160.0, 1840.0), Vector2(-600.0, 1840.0),
	])
	backdrop.color = Color(0.008, 0.009, 0.016, 1.0)
	add_child(backdrop)


func _create_map_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "MapComposite"
	sprite.texture = MAP_TEXTURE
	sprite.centered = false
	sprite.position = MAP_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -100
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = unshaded
	add_child(sprite)


func _create_occluding_props() -> void:
	var props := Node2D.new()
	props.name = "YSortedProps"
	props.y_sort_enabled = true
	add_child(props)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for data: Dictionary in OCCLUDING_PROP_DATA:
		var texture_path := OCCLUDING_PROP_ROOT + String(data["texture"])
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_warning("Dusk Garden prop could not load: %s" % texture_path)
			continue
		var prop_size := Vector2(data["size"])
		var sort_base := Node2D.new()
		sort_base.name = String(data["name"])
		# Y-sort at the grass/root base, not at the image center. Actors above
		# this line pass behind the prop; actors below it render in front.
		sort_base.position = (
			MAP_OFFSET
			+ Vector2(data["top_left"])
			+ Vector2(prop_size.x * 0.5, prop_size.y)
		)
		sort_base.add_to_group("arena_occluder")
		props.add_child(sort_base)
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(-prop_size.x * 0.5, -prop_size.y)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = unshaded
		sort_base.add_child(sprite)


func _create_pixel_motes() -> void:
	var motes := Node2D.new()
	motes.name = "PixelMotes"
	motes.z_index = -88
	add_child(motes)
	var positions := [
		Vector2(164, 318), Vector2(294, 1074), Vector2(408, 470),
		Vector2(552, 880), Vector2(702, 300), Vector2(814, 1134),
		Vector2(978, 566), Vector2(1094, 1016), Vector2(1210, 270),
		Vector2(1378, 1110), Vector2(1516, 382), Vector2(1678, 940),
		Vector2(1812, 274), Vector2(1942, 1062), Vector2(2110, 510),
		Vector2(2262, 882), Vector2(2384, 340),
	]
	for index in range(positions.size()):
		var mote := Polygon2D.new()
		mote.name = "Mote%02d" % index
		var size := 2.0 if index % 4 == 0 else 1.0
		mote.polygon = PackedVector2Array([
			Vector2.ZERO, Vector2(size, 0.0),
			Vector2(size, size), Vector2(0.0, size),
		])
		mote.position = positions[index]
		mote.color = Color(0.40, 0.72, 0.82, 0.30 if size > 1.0 else 0.18)
		motes.add_child(mote)


func _create_boundary_collision() -> void:
	var walls := StaticBody2D.new()
	walls.name = "GardenBoundary"
	walls.collision_layer = 1
	walls.collision_mask = 6
	walls.add_to_group("arena_walls")
	add_child(walls)
	_add_wall(
		walls,
		"NorthWall",
		Vector2(PLAY_BOUNDS.get_center().x, PLAY_BOUNDS.position.y - WALL_THICKNESS * 0.5),
		Vector2(PLAY_BOUNDS.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		walls,
		"SouthWall",
		Vector2(PLAY_BOUNDS.get_center().x, PLAY_BOUNDS.end.y + WALL_THICKNESS * 0.5),
		Vector2(PLAY_BOUNDS.size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		walls,
		"WestWall",
		Vector2(PLAY_BOUNDS.position.x - WALL_THICKNESS * 0.5, PLAY_BOUNDS.get_center().y),
		Vector2(WALL_THICKNESS, PLAY_BOUNDS.size.y)
	)
	_add_wall(
		walls,
		"EastWall",
		Vector2(PLAY_BOUNDS.end.x + WALL_THICKNESS * 0.5, PLAY_BOUNDS.get_center().y),
		Vector2(WALL_THICKNESS, PLAY_BOUNDS.size.y)
	)


func _add_wall(
	parent: StaticBody2D,
	wall_name: String,
	wall_position: Vector2,
	wall_size: Vector2
) -> void:
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	var collision := CollisionShape2D.new()
	collision.name = wall_name
	collision.position = wall_position
	collision.shape = shape
	parent.add_child(collision)


func get_play_bounds() -> Rect2:
	return PLAY_BOUNDS


func get_player_spawn_position() -> Vector2:
	return SAFE_CENTER


func get_camera_limits() -> Rect2:
	return CAMERA_BOUNDS


func is_walkable_position(
	world_position: Vector2,
	clearance: float = 0.0
) -> bool:
	return PLAY_BOUNDS.grow(-maxf(clearance, 0.0)).has_point(world_position)


func get_random_walkable_position(clearance: float = 46.0) -> Vector2:
	var safe_bounds := PLAY_BOUNDS.grow(-maxf(clearance, 0.0))
	return Vector2(
		randf_range(safe_bounds.position.x, safe_bounds.end.x),
		randf_range(safe_bounds.position.y, safe_bounds.end.y)
	)


func get_random_edge_spawn_position(clearance: float = 46.0) -> Vector2:
	var inset := maxf(clearance + 5.0, 8.0)
	var safe_bounds := PLAY_BOUNDS.grow(-inset)
	match randi_range(0, 3):
		0:
			return Vector2(randf_range(safe_bounds.position.x, safe_bounds.end.x), safe_bounds.position.y)
		1:
			return Vector2(safe_bounds.end.x, randf_range(safe_bounds.position.y, safe_bounds.end.y))
		2:
			return Vector2(randf_range(safe_bounds.position.x, safe_bounds.end.x), safe_bounds.end.y)
		_:
			return Vector2(safe_bounds.position.x, randf_range(safe_bounds.position.y, safe_bounds.end.y))


func get_closest_walkable_position(
	world_position: Vector2,
	clearance: float = 0.0
) -> Vector2:
	var safe_bounds := PLAY_BOUNDS.grow(-maxf(clearance + 2.0, 2.0))
	return Vector2(
		clampf(world_position.x, safe_bounds.position.x, safe_bounds.end.x - 0.01),
		clampf(world_position.y, safe_bounds.position.y, safe_bounds.end.y - 0.01)
	)


func has_walkable_route(from: Vector2, to: Vector2) -> bool:
	return is_walkable_position(from, 18.0) and is_walkable_position(to, 18.0)


func _enforce_walkable_actors() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		_constrain_actor(player, 22.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Node2D
		if not is_instance_valid(enemy):
			continue
		_constrain_actor(enemy, 58.0 if enemy.is_in_group("boss") else 24.0)


func _constrain_actor(actor: Node2D, clearance: float) -> void:
	if is_walkable_position(actor.global_position, 2.0):
		return
	actor.global_position = get_closest_walkable_position(actor.global_position, clearance)
	actor.reset_physics_interpolation()
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity *= 0.25
