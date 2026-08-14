class_name IsometricSlimeArena
extends Node2D


const MAP_TEXTURE: Texture2D = preload(
	"res://Assets/environment/isometric/map-composite.png"
)
const DUST_TEXTURE: Texture2D = preload(
	"res://Assets/environment/dust_particle.svg"
)

const SOURCE_SCALE := 0.82
const SOURCE_OFFSET := Vector2(-612.0, -349.0)
const SAFE_CENTER := Vector2(1280.0, 720.0)
const EDGE_WALL_THICKNESS := 42.0
const ACTOR_CONSTRAINT_INTERVAL := 0.08

# Largest connected metal platform from the authored PixelLab map. Small gray
# islands in the runoff remain visual set dressing instead of becoming spawn
# traps. The outline is deliberately simplified at less than one source tile.
const SOURCE_WALKABLE_OUTLINE := [
	Vector2(1528, 640), Vector2(1680, 656), Vector2(1664, 704),
	Vector2(1784, 664), Vector2(1808, 728), Vector2(2120, 688),
	Vector2(2360, 752), Vector2(2472, 864), Vector2(3176, 872),
	Vector2(3312, 936), Vector2(3280, 1016), Vector2(3336, 1048),
	Vector2(3560, 1008), Vector2(3648, 1048), Vector2(3568, 1112),
	Vector2(3664, 1160), Vector2(3848, 1144), Vector2(3984, 1208),
	Vector2(3904, 1272), Vector2(4080, 1368), Vector2(3864, 1520),
	Vector2(3672, 1512), Vector2(3696, 1600), Vector2(3592, 1640),
	Vector2(3512, 1592), Vector2(3040, 1608), Vector2(3024, 1488),
	Vector2(3160, 1432), Vector2(3120, 1408), Vector2(3152, 1376),
	Vector2(3064, 1344), Vector2(2848, 1448), Vector2(2880, 1576),
	Vector2(2760, 1624), Vector2(2776, 1672), Vector2(2296, 1904),
	Vector2(2208, 1896), Vector2(2336, 1776), Vector2(2248, 1736),
	Vector2(2256, 1784), Vector2(2176, 1816), Vector2(2208, 1848),
	Vector2(2128, 1888), Vector2(2160, 1920), Vector2(1976, 2008),
	Vector2(1520, 1936), Vector2(1344, 1848), Vector2(1384, 1824),
	Vector2(1360, 1760), Vector2(1240, 1800), Vector2(1104, 1736),
	Vector2(1144, 1656), Vector2(1056, 1616), Vector2(1088, 1584),
	Vector2(1008, 1552), Vector2(1040, 1512), Vector2(960, 1480),
	Vector2(1000, 1448), Vector2(864, 1344), Vector2(904, 1272),
	Vector2(864, 1192), Vector2(944, 1160), Vector2(912, 1072),
	Vector2(952, 1056), Vector2(1280, 1120), Vector2(1384, 1088),
	Vector2(1296, 1040), Vector2(1296, 984), Vector2(1480, 904),
	Vector2(1392, 848), Vector2(1520, 792), Vector2(1440, 744),
	Vector2(1480, 720), Vector2(1440, 688),
]

const SOURCE_SLIME_LIGHTS := [
	Vector2(1200, 590), Vector2(2300, 570), Vector2(3200, 710),
	Vector2(4320, 1240), Vector2(3980, 1660), Vector2(3180, 1940),
	Vector2(2320, 2160), Vector2(1400, 2070), Vector2(650, 1600),
	Vector2(690, 980), Vector2(2980, 1500),
]

var walkable_polygon := PackedVector2Array()
var play_bounds := Rect2()
var shoreline_lights: Array[PointLight2D] = []
var shoreline_glows: Array[Sprite2D] = []
var atmosphere_time := 0.0
var constraint_time := 0.0


func _ready() -> void:
	add_to_group("walkable_arena")
	_build_walkable_polygon()
	_create_backdrop()
	_create_map_visual()
	_create_boundary_collision()
	_create_shoreline_glow()
	_create_slime_lights()
	_create_atmosphere()


func _process(delta: float) -> void:
	atmosphere_time += delta
	constraint_time += delta
	for index in range(shoreline_lights.size()):
		var light := shoreline_lights[index]
		if not is_instance_valid(light):
			continue
		var pulse := (
			1.0
			+ sin(atmosphere_time * 1.12 + float(index) * 1.71) * 0.055
			+ sin(atmosphere_time * 3.87 + float(index) * 0.63) * 0.018
		)
		light.energy = float(light.get_meta("base_energy", 1.0)) * pulse
		if index < shoreline_glows.size():
			var glow := shoreline_glows[index]
			var glow_color := glow.modulate
			glow_color.a = float(glow.get_meta("base_alpha", 0.12)) * pulse
			glow.modulate = glow_color
	if constraint_time >= ACTOR_CONSTRAINT_INTERVAL:
		constraint_time = 0.0
		_enforce_walkable_actors()


func _build_walkable_polygon() -> void:
	walkable_polygon.clear()
	for source_point: Vector2 in SOURCE_WALKABLE_OUTLINE:
		walkable_polygon.append(_source_to_world(source_point))
	if walkable_polygon.is_empty():
		play_bounds = Rect2(SAFE_CENTER, Vector2.ZERO)
		return
	var minimum := walkable_polygon[0]
	var maximum := walkable_polygon[0]
	for point in walkable_polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	play_bounds = Rect2(minimum, maximum - minimum)


func _source_to_world(source_point: Vector2) -> Vector2:
	return source_point * SOURCE_SCALE + SOURCE_OFFSET


func _create_backdrop() -> void:
	var backdrop := Polygon2D.new()
	backdrop.name = "VoidBackdrop"
	backdrop.z_index = -120
	backdrop.polygon = PackedVector2Array([
		Vector2(-900.0, -700.0),
		Vector2(4700.0, -700.0),
		Vector2(4700.0, 2700.0),
		Vector2(-900.0, 2700.0),
	])
	backdrop.color = Color(0.004, 0.016, 0.012, 1.0)
	add_child(backdrop)


func _create_map_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "MapComposite"
	sprite.texture = MAP_TEXTURE
	sprite.centered = false
	sprite.position = SOURCE_OFFSET
	sprite.scale = Vector2.ONE * SOURCE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(0.76, 0.82, 0.78, 1.0)
	sprite.z_index = -100
	add_child(sprite)


func _create_boundary_collision() -> void:
	var walls := StaticBody2D.new()
	walls.name = "SlimeBoundary"
	walls.collision_layer = 1
	walls.collision_mask = 6
	walls.add_to_group("arena_walls")
	add_child(walls)
	for index in range(walkable_polygon.size()):
		var start := walkable_polygon[index]
		var end := walkable_polygon[(index + 1) % walkable_polygon.size()]
		var edge := end - start
		if edge.length_squared() < 4.0:
			continue
		var shape := RectangleShape2D.new()
		shape.size = Vector2(edge.length() + 8.0, EDGE_WALL_THICKNESS)
		var collision := CollisionShape2D.new()
		collision.name = "Shore%02d" % index
		var edge_point := (start + end) * 0.5
		var inward := _get_inward_normal(start, end, edge_point)
		# Keep the solid strip in the runoff so the actor's own radius, not an
		# invisible inset, determines how close its feet can get to the lip.
		collision.position = (
			edge_point - inward * EDGE_WALL_THICKNESS * 0.5
		)
		collision.rotation = edge.angle()
		collision.shape = shape
		walls.add_child(collision)


func _create_shoreline_glow() -> void:
	var shoreline := Node2D.new()
	shoreline.name = "ShorelineGlow"
	shoreline.z_index = -82
	add_child(shoreline)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var soft_line := Line2D.new()
	soft_line.name = "RunoffAura"
	soft_line.points = walkable_polygon
	soft_line.closed = true
	soft_line.width = 18.0
	soft_line.default_color = Color(0.08, 1.0, 0.18, 0.075)
	soft_line.joint_mode = Line2D.LINE_JOINT_ROUND
	soft_line.material = additive
	shoreline.add_child(soft_line)
	var hard_line := Line2D.new()
	hard_line.name = "ToxicLip"
	hard_line.points = walkable_polygon
	hard_line.closed = true
	hard_line.width = 3.0
	hard_line.default_color = Color(0.28, 1.0, 0.32, 0.34)
	hard_line.joint_mode = Line2D.LINE_JOINT_ROUND
	hard_line.material = additive
	shoreline.add_child(hard_line)


func _create_slime_lights() -> void:
	var lights := Node2D.new()
	lights.name = "SlimeLights"
	lights.z_index = -72
	add_child(lights)
	var light_texture := _create_radial_texture(384)
	var particle_texture := _create_radial_texture(32)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for index in range(SOURCE_SLIME_LIGHTS.size()):
		var light_position := _source_to_world(SOURCE_SLIME_LIGHTS[index])
		# All authored anchors are in runoff. This guard prevents a future map
		# rescale from accidentally illuminating the playable metal as slime.
		if is_walkable_position(light_position, 0.0):
			continue
		var glow := Sprite2D.new()
		glow.name = "SlimeGlow%02d" % (index + 1)
		glow.position = light_position
		glow.texture = light_texture
		glow.scale = Vector2.ONE * (0.58 + float(index % 3) * 0.09)
		glow.material = additive
		glow.modulate = Color(0.08, 1.0, 0.18, 0.10 + float(index % 2) * 0.025)
		glow.set_meta("base_alpha", glow.modulate.a)
		lights.add_child(glow)
		shoreline_glows.append(glow)
		var light := PointLight2D.new()
		light.name = "ToxicLight%02d" % (index + 1)
		light.position = light_position
		light.texture = light_texture
		light.texture_scale = 1.35 + float(index % 3) * 0.18
		light.color = Color(0.12, 1.0, 0.20, 1.0)
		light.energy = 0.92 + float(index % 4) * 0.08
		light.shadow_enabled = false
		light.range_item_cull_mask = 1
		light.set_meta("base_energy", light.energy)
		lights.add_child(light)
		shoreline_lights.append(light)
		var bubbles := CPUParticles2D.new()
		bubbles.name = "RunoffBubbles%02d" % (index + 1)
		bubbles.position = light_position
		bubbles.texture = particle_texture
		bubbles.amount = 7
		bubbles.lifetime = 2.8
		bubbles.preprocess = 2.8
		bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		bubbles.emission_sphere_radius = 62.0
		bubbles.direction = Vector2.UP
		bubbles.spread = 52.0
		bubbles.gravity = Vector2(0.0, -5.0)
		bubbles.initial_velocity_min = 4.0
		bubbles.initial_velocity_max = 13.0
		bubbles.scale_amount_min = 0.08
		bubbles.scale_amount_max = 0.24
		bubbles.color = Color(0.18, 1.0, 0.22, 0.28)
		lights.add_child(bubbles)


func _create_atmosphere() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "BasinAtmosphere"
	particles.position = play_bounds.get_center()
	particles.z_index = -68
	particles.amount = 58
	particles.texture = DUST_TEXTURE
	particles.lifetime = 11.0
	particles.preprocess = 11.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = play_bounds.size * 0.48
	particles.direction = Vector2(0.25, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(-1.2, -2.6)
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 6.0
	particles.scale_amount_min = 0.10
	particles.scale_amount_max = 0.34
	particles.color = Color(0.20, 0.62, 0.38, 0.12)
	add_child(particles)


func _create_radial_texture(size: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.44, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.48),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = size
	texture.height = size
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func get_play_bounds() -> Rect2:
	return play_bounds


func get_player_spawn_position() -> Vector2:
	return SAFE_CENTER


func get_camera_limits() -> Rect2:
	return Rect2(0.0, 0.0, 2830.0, 1440.0)


func is_walkable_position(
	world_position: Vector2,
	clearance: float = 0.0
) -> bool:
	if not Geometry2D.is_point_in_polygon(world_position, walkable_polygon):
		return false
	if clearance <= 0.0:
		return true
	var clearance_squared := clearance * clearance
	for index in range(walkable_polygon.size()):
		var start := walkable_polygon[index]
		var end := walkable_polygon[(index + 1) % walkable_polygon.size()]
		var closest := Geometry2D.get_closest_point_to_segment(
			world_position,
			start,
			end
		)
		if closest.distance_squared_to(world_position) < clearance_squared:
			return false
	return true


func get_random_walkable_position(clearance: float = 46.0) -> Vector2:
	for _attempt in range(128):
		var candidate := Vector2(
			randf_range(play_bounds.position.x, play_bounds.end.x),
			randf_range(play_bounds.position.y, play_bounds.end.y)
		)
		if is_walkable_position(candidate, clearance):
			return candidate
	return get_closest_walkable_position(SAFE_CENTER, clearance)


func get_random_edge_spawn_position(clearance: float = 46.0) -> Vector2:
	for _attempt in range(96):
		var index := randi_range(0, walkable_polygon.size() - 1)
		var start := walkable_polygon[index]
		var end := walkable_polygon[(index + 1) % walkable_polygon.size()]
		var edge_point := start.lerp(end, randf_range(0.10, 0.90))
		var inward := _get_inward_normal(start, end, edge_point)
		var candidate := edge_point + inward * randf_range(
			clearance + 18.0,
			clearance + 118.0
		)
		if is_walkable_position(candidate, clearance):
			return candidate
	return get_random_walkable_position(clearance)


func get_closest_walkable_position(
	world_position: Vector2,
	clearance: float = 0.0
) -> Vector2:
	if is_walkable_position(world_position, clearance):
		return world_position
	var best_point := SAFE_CENTER
	var best_start := walkable_polygon[0]
	var best_end := walkable_polygon[1]
	var best_distance := INF
	for index in range(walkable_polygon.size()):
		var start := walkable_polygon[index]
		var end := walkable_polygon[(index + 1) % walkable_polygon.size()]
		var closest := Geometry2D.get_closest_point_to_segment(
			world_position,
			start,
			end
		)
		var distance := closest.distance_squared_to(world_position)
		if distance < best_distance:
			best_distance = distance
			best_point = closest
			best_start = start
			best_end = end
	var inward := _get_inward_normal(best_start, best_end, best_point)
	var candidate := best_point + inward * (clearance + 5.0)
	for step in range(18):
		if is_walkable_position(candidate, clearance):
			return candidate
		candidate = candidate.lerp(SAFE_CENTER, 0.16 + float(step) * 0.012)
	return SAFE_CENTER


func has_walkable_route(from: Vector2, to: Vector2) -> bool:
	# The selected outline is one connected platform. Steering and solid shore
	# segments handle its concave pockets; route validation should not reject a
	# legal spawn merely because the straight ray crosses one such pocket.
	return is_walkable_position(from, 20.0) and is_walkable_position(to, 18.0)


func _get_inward_normal(
	start: Vector2,
	end: Vector2,
	edge_point: Vector2
) -> Vector2:
	var edge := end - start
	if edge.is_zero_approx():
		return edge_point.direction_to(SAFE_CENTER)
	var normal := edge.orthogonal().normalized()
	if not Geometry2D.is_point_in_polygon(
		edge_point + normal * 7.0,
		walkable_polygon
	):
		normal = -normal
	return normal


func _enforce_walkable_actors() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		_constrain_actor(player, 22.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Node2D
		if not is_instance_valid(enemy):
			continue
		var clearance := 58.0 if enemy.is_in_group("boss") else 24.0
		_constrain_actor(enemy, clearance)


func _constrain_actor(actor: Node2D, clearance: float) -> void:
	if is_walkable_position(actor.global_position, 2.0):
		return
	actor.global_position = get_closest_walkable_position(
		actor.global_position,
		clearance
	)
	actor.reset_physics_interpolation()
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity *= 0.25
