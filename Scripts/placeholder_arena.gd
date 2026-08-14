class_name PlaceholderArena
extends Node2D


const ARENA_SIZE := Vector2(2560.0, 1440.0)
const WALL_THICKNESS: float = 56.0
const TOP_PLAYFIELD_INSET: float = 144.0
const BOTTOM_CAMERA_INSET: float = 64.0
const ASSET_ROOT := "res://Assets/environment/lab/"

const WALL_TEXTURES: Array[Texture2D] = [
	preload(ASSET_ROOT + "lab_wall_standard.png"),
	preload(ASSET_ROOT + "lab_wall_reinforced.png"),
	preload(ASSET_ROOT + "lab_pressure_door.png"),
]
const CORNER_TEXTURE: Texture2D = preload(
	ASSET_ROOT + "lab_corner_pylon.png"
)
const DETAIL_TEXTURES: Array[Texture2D] = [
	preload(ASSET_ROOT + "lab_floor_vent.png"),
	preload(ASSET_ROOT + "lab_broken_conduit.png"),
	preload(ASSET_ROOT + "lab_contamination_growth.png"),
	preload(ASSET_ROOT + "lab_pipe_barrier.png"),
]
const PROP_TEXTURES: Array[Texture2D] = [
	preload(ASSET_ROOT + "lab_stasis_pod.png"),
	preload(ASSET_ROOT + "lab_specimen_tank.png"),
	preload(ASSET_ROOT + "lab_surgical_station.png"),
	preload(ASSET_ROOT + "lab_reactor_pylon.png"),
	preload(ASSET_ROOT + "lab_biomass_vat.png"),
	preload(ASSET_ROOT + "lab_cable_nest.png"),
	preload(ASSET_ROOT + "lab_decon_unit.png"),
	preload(ASSET_ROOT + "lab_cargo_cluster.png"),
]
const DUST_TEXTURE: Texture2D = preload(
	"res://Assets/environment/dust_particle.svg"
)

const OBSTACLE_DATA := [
	[
		"NorthWestStasisPod",
		Vector2(420.0, 390.0),
		0,
		Vector2(92.0, 44.0),
		Vector2(0.0, -60.0),
		0.62,
		112.0,
		190.0,
	],
	[
		"NorthSpecimenTank",
		Vector2(650.0, 420.0),
		1,
		Vector2(94.0, 44.0),
		Vector2(0.0, -60.0),
		0.61,
		110.0,
		190.0,
	],
	[
		"NorthEastReactor",
		Vector2(2140.0, 420.0),
		3,
		Vector2(96.0, 48.0),
		Vector2(0.0, -60.0),
		0.62,
		105.0,
		190.0,
	],
	[
		"NorthEastSurgicalStation",
		Vector2(1830.0, 390.0),
		2,
		Vector2(166.0, 54.0),
		Vector2(-8.0, -40.0),
		0.64,
		145.0,
		130.0,
	],
	[
		"NorthEastBiomassVat",
		Vector2(1980.0, 610.0),
		4,
		Vector2(134.0, 48.0),
		Vector2(0.0, -60.0),
		0.64,
		140.0,
		165.0,
	],
	[
		"SouthWestDecon",
		Vector2(470.0, 1080.0),
		6,
		Vector2(110.0, 48.0),
		Vector2(0.0, -60.0),
		0.62,
		112.0,
		190.0,
	],
	[
		"SouthWestCableJunction",
		Vector2(700.0, 1120.0),
		5,
		Vector2(166.0, 54.0),
		Vector2(0.0, -35.0),
		0.62,
		150.0,
		110.0,
	],
	[
		"SouthEastCargo",
		Vector2(2070.0, 1080.0),
		7,
		Vector2(158.0, 56.0),
		Vector2(0.0, -55.0),
		0.64,
		145.0,
		150.0,
	],
]

const DECORATION_DATA := [
	[Vector2(535.0, 525.0), 0, 0.36, 0.0],
	[Vector2(1890.0, 530.0), 0, 0.36, 0.0],
	[Vector2(2090.0, 655.0), 0, 0.34, PI * 0.5],
	[Vector2(560.0, 1215.0), 0, 0.36, 0.0],
	[Vector2(790.0, 1070.0), 1, 0.40, 0.10],
	[Vector2(1715.0, 415.0), 1, 0.40, -0.12],
	[Vector2(2000.0, 705.0), 2, 0.38, 0.06],
	[Vector2(2150.0, 1145.0), 1, 0.40, -0.08],
	[Vector2(735.0, 1015.0), 3, 0.36, 0.04],
	[Vector2(2215.0, 990.0), 3, 0.36, -0.04],
]

const LAB_STATION_DATA := [
	[Vector2(535.0, 420.0), Vector2(430.0, 250.0)],
	[Vector2(1990.0, 485.0), Vector2(560.0, 340.0)],
	[Vector2(585.0, 1090.0), Vector2(450.0, 250.0)],
	[Vector2(2070.0, 1080.0), Vector2(390.0, 250.0)],
]

const MICROZONE_DATA := [
	[
		"ABANDONED SURGERY",
		Vector2(535.0, 420.0),
		Vector2(350.0, 178.0),
		Color(0.32, 0.74, 0.82, 0.12),
		0,
	],
	[
		"BIOMASS QUARANTINE",
		Vector2(1980.0, 620.0),
		Vector2(330.0, 210.0),
		Color(0.30, 0.88, 0.58, 0.11),
		2,
	],
	[
		"ELECTRIC RELAY",
		Vector2(1530.0, 445.0),
		Vector2(300.0, 142.0),
		Color(0.22, 0.68, 1.0, 0.13),
		1,
	],
	[
		"CONTAINMENT BREACH",
		Vector2(2070.0, 1080.0),
		Vector2(320.0, 184.0),
		Color(0.82, 0.24, 0.24, 0.10),
		3,
	],
	[
		"OVERGROWN SAMPLE",
		Vector2(480.0, 1060.0),
		Vector2(330.0, 182.0),
		Color(0.35, 0.76, 0.42, 0.11),
		2,
	],
	[
		"BLOOD / CABLE LANE",
		Vector2(1280.0, 1030.0),
		Vector2(580.0, 116.0),
		Color(0.82, 0.18, 0.24, 0.09),
		1,
	],
]

const LIGHT_DATA := [
	[Vector2(420.0, 330.0), Color(0.32, 0.82, 1.0), 1.10, 1.38, 0.13],
	[Vector2(650.0, 360.0), Color(0.28, 0.72, 0.92), 1.35, 1.32, 0.18],
	[Vector2(2140.0, 360.0), Color(0.24, 0.76, 1.0), 1.55, 1.42, 0.20],
	[Vector2(1980.0, 550.0), Color(0.18, 0.92, 0.82), 1.25, 1.34, 0.18],
	[Vector2(470.0, 1020.0), Color(0.22, 0.72, 0.92), 0.90, 1.28, 0.13],
	[Vector2(2070.0, 1025.0), Color(0.26, 0.72, 0.92), 0.78, 1.24, 0.11],
	[Vector2(195.0, 720.0), Color(1.0, 0.18, 0.10), 0.82, 1.16, 0.10],
	[Vector2(2365.0, 720.0), Color(1.0, 0.18, 0.10), 0.82, 1.16, 0.10],
]


var laboratory_lights: Array[PointLight2D] = []
var occluding_obstacles: Array[Dictionary] = []
var player_reference: Node2D
var atmosphere_time: float = 0.0


func _ready() -> void:
	_create_boundary_collisions()
	_create_floor_markings()
	_create_microzones()
	_create_boundary_visuals()
	_create_lab_stations()
	_create_decorations()
	_create_obstacles()
	_create_laboratory_lights()
	_create_atmosphere()


func _process(delta: float) -> void:
	atmosphere_time += delta
	for index in range(laboratory_lights.size()):
		var light := laboratory_lights[index]
		var base_energy := float(light.get_meta("base_energy"))
		var phase := float(index) * 1.73
		var primary_flicker := sin(atmosphere_time * 1.37 + phase) * 0.025
		var secondary_flicker := sin(atmosphere_time * 4.91 + phase) * 0.012
		var flicker_multiplier := (
			1.0 + primary_flicker + secondary_flicker
		)
		light.energy = base_energy * flicker_multiplier
		var glow := light.get_meta("glow_sprite") as Sprite2D
		if is_instance_valid(glow):
			var glow_color := glow.modulate
			glow_color.a = (
				float(light.get_meta("base_glow_alpha"))
				* flicker_multiplier
			)
			glow.modulate = glow_color
	_update_obstacle_occlusion(delta)


func _create_boundary_collisions() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 6
	walls.add_to_group("arena_walls")
	add_child(walls)

	_add_wall_shape(
		walls,
		"Left",
		Vector2(WALL_THICKNESS * 0.5, ARENA_SIZE.y * 0.5),
		Vector2(WALL_THICKNESS, ARENA_SIZE.y)
	)
	_add_wall_shape(
		walls,
		"Right",
		Vector2(ARENA_SIZE.x - WALL_THICKNESS * 0.5, ARENA_SIZE.y * 0.5),
		Vector2(WALL_THICKNESS, ARENA_SIZE.y)
	)
	_add_wall_shape(
		walls,
		"Top",
		Vector2(ARENA_SIZE.x * 0.5, TOP_PLAYFIELD_INSET * 0.5),
		Vector2(ARENA_SIZE.x, TOP_PLAYFIELD_INSET)
	)
	_add_wall_shape(
		walls,
		"Bottom",
		Vector2(
			ARENA_SIZE.x * 0.5,
			ARENA_SIZE.y - BOTTOM_CAMERA_INSET - WALL_THICKNESS * 0.5
		),
		Vector2(ARENA_SIZE.x, WALL_THICKNESS)
	)


func _add_wall_shape(
	body: StaticBody2D,
	shape_name: String,
	shape_position: Vector2,
	shape_size: Vector2
) -> void:
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	var collision := CollisionShape2D.new()
	collision.name = shape_name
	collision.position = shape_position
	collision.shape = rectangle
	body.add_child(collision)


func _create_floor_markings() -> void:
	var markings := Node2D.new()
	markings.name = "FloorMarkings"
	markings.z_index = -90
	add_child(markings)

	_add_floor_line(
		markings,
		PackedVector2Array([
			Vector2(1280.0, 500.0),
			Vector2(1510.0, 565.0),
			Vector2(1640.0, 720.0),
			Vector2(1510.0, 875.0),
			Vector2(1280.0, 940.0),
			Vector2(1050.0, 875.0),
			Vector2(920.0, 720.0),
			Vector2(1050.0, 565.0),
			Vector2(1280.0, 500.0),
		]),
		Color(0.16, 0.64, 0.76, 0.07),
		2.0
	)


func _add_floor_line(
	parent: Node,
	points: PackedVector2Array,
	line_color: Color,
	line_width: float
) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = line_width
	line.default_color = line_color
	line.antialiased = false
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	parent.add_child(line)


func _create_microzones() -> void:
	var zones := Node2D.new()
	zones.name = "ReadableMicrozones"
	zones.z_index = -87
	add_child(zones)
	for zone_data in MICROZONE_DATA:
		var title := String(zone_data[0])
		var zone := Node2D.new()
		zone.name = title.to_pascal_case().replace("/", "")
		zone.position = zone_data[1]
		zone.set_meta("microzone_id", title)
		zones.add_child(zone)
		var zone_size: Vector2 = zone_data[2]
		var half := zone_size * 0.5
		var cut := minf(half.x, half.y) * 0.22
		var points := PackedVector2Array([
			Vector2(-half.x + cut, -half.y),
			Vector2(half.x - cut, -half.y),
			Vector2(half.x, -half.y + cut),
			Vector2(half.x, half.y - cut),
			Vector2(half.x - cut, half.y),
			Vector2(-half.x + cut, half.y),
			Vector2(-half.x, half.y - cut),
			Vector2(-half.x, -half.y + cut),
		])
		var fill := Polygon2D.new()
		fill.polygon = points
		fill.color = zone_data[3]
		zone.add_child(fill)
		var outline := Line2D.new()
		outline.points = points
		outline.closed = true
		outline.width = 2.0
		outline.default_color = Color(zone_data[3]) * Color(1.8, 1.8, 1.8, 1.5)
		outline.antialiased = false
		outline.joint_mode = Line2D.LINE_JOINT_BEVEL
		zone.add_child(outline)
		var detail_index := int(zone_data[4])
		for detail_offset in [Vector2(-half.x * 0.55, 0.0), Vector2(half.x * 0.55, 0.0)]:
			var detail := Sprite2D.new()
			detail.texture = DETAIL_TEXTURES[detail_index]
			detail.position = detail_offset
			detail.scale = Vector2.ONE * 0.28
			detail.modulate = Color(0.68, 0.80, 0.78, 0.54)
			detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			zone.add_child(detail)
		var label := Label.new()
		label.position = Vector2(-half.x + 12.0, -half.y + 8.0)
		label.size = Vector2(zone_size.x - 24.0, 20.0)
		label.text = title
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.52, 0.78, 0.78, 0.68))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(label)

	var cable_lane := zones.get_node_or_null("BloodCableLane") as Node2D
	if cable_lane != null:
		_add_floor_line(
			cable_lane,
			PackedVector2Array([
				Vector2(-258.0, 18.0),
				Vector2(-145.0, -13.0),
				Vector2(-22.0, 12.0),
				Vector2(112.0, -15.0),
				Vector2(258.0, 8.0),
			]),
			Color(0.78, 0.13, 0.18, 0.42),
			5.0
		)


func _create_boundary_visuals() -> void:
	var visuals := Node2D.new()
	visuals.name = "BoundaryVisuals"
	visuals.y_sort_enabled = true
	add_child(visuals)

	var spacing := 112.0
	var horizontal_count := ceili(ARENA_SIZE.x / spacing)
	for index in range(horizontal_count):
		var x := spacing * 0.5 + index * spacing
		var texture_index := index % 2
		if absf(x - ARENA_SIZE.x * 0.5) < spacing * 0.55:
			texture_index = 2
		_add_sprite(
			visuals,
			WALL_TEXTURES[texture_index],
			Vector2(
				x,
				TOP_PLAYFIELD_INSET - WALL_THICKNESS * 0.5
			),
			0.34
		)
		_add_sprite(
			visuals,
			WALL_TEXTURES[texture_index],
			Vector2(
				x,
				ARENA_SIZE.y
				- BOTTOM_CAMERA_INSET
				- WALL_THICKNESS * 0.5
			),
			0.34,
			PI
		)

	var vertical_count := ceili(ARENA_SIZE.y / spacing)
	for index in range(vertical_count):
		var y := spacing * 0.5 + index * spacing
		_add_sprite(
			visuals,
			WALL_TEXTURES[index % 2],
			Vector2(WALL_THICKNESS * 0.5, y),
			0.34,
			PI * 0.5
		)
		_add_sprite(
			visuals,
			WALL_TEXTURES[index % 2],
			Vector2(ARENA_SIZE.x - WALL_THICKNESS * 0.5, y),
			0.34,
			-PI * 0.5
		)

	for corner_position in [
		Vector2(
			WALL_THICKNESS * 0.5,
			TOP_PLAYFIELD_INSET - WALL_THICKNESS * 0.5
		),
		Vector2(
			ARENA_SIZE.x - WALL_THICKNESS * 0.5,
			TOP_PLAYFIELD_INSET - WALL_THICKNESS * 0.5
		),
		Vector2(
			WALL_THICKNESS * 0.5,
			ARENA_SIZE.y
			- BOTTOM_CAMERA_INSET
			- WALL_THICKNESS * 0.5
		),
		Vector2(
			ARENA_SIZE.x - WALL_THICKNESS * 0.5,
			ARENA_SIZE.y
			- BOTTOM_CAMERA_INSET
			- WALL_THICKNESS * 0.5
		),
	]:
		_add_sprite(
			visuals,
			CORNER_TEXTURE,
			corner_position,
			0.35
		)


func _create_lab_stations() -> void:
	var stations := Node2D.new()
	stations.name = "LabStations"
	stations.z_index = -85
	add_child(stations)

	for index in range(LAB_STATION_DATA.size()):
		var data: Array = LAB_STATION_DATA[index]
		var station := Node2D.new()
		station.name = "Station%02d" % (index + 1)
		station.position = data[0]
		stations.add_child(station)

		var size: Vector2 = data[1]
		var half_size := size * 0.5
		var corner_cut := minf(half_size.x, half_size.y) * 0.18
		var panel_points := PackedVector2Array([
			Vector2(-half_size.x + corner_cut, -half_size.y),
			Vector2(half_size.x - corner_cut, -half_size.y),
			Vector2(half_size.x, -half_size.y + corner_cut),
			Vector2(half_size.x, half_size.y - corner_cut),
			Vector2(half_size.x - corner_cut, half_size.y),
			Vector2(-half_size.x + corner_cut, half_size.y),
			Vector2(-half_size.x, half_size.y - corner_cut),
			Vector2(-half_size.x, -half_size.y + corner_cut),
		])

		var base := Polygon2D.new()
		base.name = "ServicePad"
		base.polygon = panel_points
		base.color = Color(0.025, 0.065, 0.10, 0.34)
		station.add_child(base)

		var outline := Line2D.new()
		outline.name = "ServiceOutline"
		outline.points = panel_points
		outline.closed = true
		outline.width = 3.0
		outline.default_color = Color(0.18, 0.55, 0.66, 0.14)
		outline.antialiased = false
		outline.joint_mode = Line2D.LINE_JOINT_BEVEL
		station.add_child(outline)


func _create_obstacles() -> void:
	var obstacles := Node2D.new()
	obstacles.name = "Obstacles"
	obstacles.y_sort_enabled = true
	obstacles.add_to_group("arena_obstacles")
	add_child(obstacles)

	for data in OBSTACLE_DATA:
		var body := StaticBody2D.new()
		body.name = data[0]
		body.position = data[1]
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("arena_obstacle")
		body.add_to_group("arena_occluder")
		obstacles.add_child(body)

		_add_obstacle_shadow(body, data[3], Vector2.ZERO)
		var visual := _add_sprite(
			body,
			PROP_TEXTURES[data[2]],
			data[4],
			data[5]
		)
		visual.name = "Visual"
		visual.modulate = Color(0.74, 0.82, 0.88, 0.94)

		var shape := RectangleShape2D.new()
		shape.size = data[3]
		var collision := CollisionShape2D.new()
		collision.name = "FootprintCollision"
		collision.position = Vector2.ZERO
		collision.shape = shape
		body.add_child(collision)

		occluding_obstacles.append({
			"body": body,
			"visual": visual,
			"half_width": data[6],
			"height": data[7],
		})


func _add_obstacle_shadow(
	parent: Node,
	footprint_size: Vector2,
	shadow_position: Vector2
) -> void:
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	var radius := Vector2(
		footprint_size.x * 0.72,
		footprint_size.y * 0.31
	)
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(
			cos(angle) * radius.x,
			sin(angle) * radius.y
		))
	shadow.polygon = points
	shadow.position = shadow_position + Vector2(0.0, 8.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.48)
	shadow.z_index = -1
	shadow.name = "GroundShadow"
	parent.add_child(shadow)


func _create_decorations() -> void:
	var decorations := Node2D.new()
	decorations.name = "GroundDecorations"
	decorations.z_index = -80
	add_child(decorations)

	for data in DECORATION_DATA:
		var sprite := _add_sprite(
			decorations,
			DETAIL_TEXTURES[data[1]],
			data[0],
			data[2],
			data[3]
		)
		sprite.modulate = Color(0.72, 0.82, 0.86, 0.88)


func _create_laboratory_lights() -> void:
	var lights := Node2D.new()
	lights.name = "LaboratoryLights"
	lights.z_index = 5
	add_child(lights)

	var light_texture := _create_radial_light_texture()
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for index in range(LIGHT_DATA.size()):
		var data: Array = LIGHT_DATA[index]
		var glow := Sprite2D.new()
		glow.name = "ElectricalGlow%02d" % (index + 1)
		glow.position = data[0]
		glow.texture = light_texture
		glow.scale = Vector2.ONE * float(data[3]) * 0.42
		glow.material = glow_material
		var glow_color: Color = data[1]
		glow_color.a = float(data[4])
		glow.modulate = glow_color
		glow.z_index = -1
		lights.add_child(glow)

		var light := PointLight2D.new()
		light.name = "LabLight%02d" % (index + 1)
		light.position = data[0]
		light.color = data[1]
		light.energy = data[2]
		light.texture = light_texture
		light.texture_scale = data[3]
		light.range_item_cull_mask = 1
		light.set_meta("base_energy", data[2])
		light.set_meta("base_glow_alpha", data[4])
		light.set_meta("glow_sprite", glow)
		lights.add_child(light)
		laboratory_lights.append(light)


func _create_radial_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.58),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 384
	texture.height = 384
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _create_atmosphere() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "Atmosphere"
	particles.position = ARENA_SIZE * 0.5
	particles.z_index = -70
	particles.amount = 84
	particles.texture = DUST_TEXTURE
	particles.lifetime = 12.0
	particles.preprocess = 12.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = ARENA_SIZE * 0.48
	particles.direction = Vector2(0.35, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(-1.5, -3.0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 7.0
	particles.scale_amount_min = 0.16
	particles.scale_amount_max = 0.42
	particles.color = Color(0.34, 0.56, 0.64, 0.16)
	add_child(particles)


func _update_obstacle_occlusion(delta: float) -> void:
	if not is_instance_valid(player_reference):
		player_reference = get_tree().get_first_node_in_group(
			"player"
		) as Node2D
	var enemies := get_tree().get_nodes_in_group("enemies")

	for entry in occluding_obstacles:
		var body := entry["body"] as Node2D
		var visual := entry["visual"] as Sprite2D
		if not is_instance_valid(body) or not is_instance_valid(visual):
			continue

		var player_is_covered := (
			is_instance_valid(player_reference)
			and _is_target_covered_by_obstacle(
				player_reference,
				body,
				entry
			)
		)
		var enemy_is_covered := false
		for enemy_node in enemies:
			var enemy := enemy_node as Node2D
			if (
				is_instance_valid(enemy)
				and _is_target_covered_by_obstacle(enemy, body, entry)
			):
				enemy_is_covered = true
				break
		var target_alpha := 1.0
		if player_is_covered:
			target_alpha = 0.42
		elif enemy_is_covered:
			target_alpha = 0.56
		var visual_color := visual.self_modulate
		visual_color.a = move_toward(
			visual_color.a,
			target_alpha,
			delta * 3.6
		)
		visual.self_modulate = visual_color


func _is_target_covered_by_obstacle(
	target: Node2D,
	body: Node2D,
	entry: Dictionary
) -> bool:
	var target_position := target.global_position
	if target.is_in_group("boss"):
		# The boss origin sits above its visual feet; normalize it to the same
		# depth sample used by Koda and the regular enemies.
		target_position += Vector2(0.0, 54.0)
	var target_offset := target_position - body.global_position
	return (
		target_offset.y < 4.0
		and target_offset.y > -float(entry["height"])
		and absf(target_offset.x) < float(entry["half_width"])
	)


func _add_sprite(
	parent: Node,
	texture: Texture2D,
	sprite_position: Vector2,
	sprite_scale: float,
	sprite_rotation: float = 0.0
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = texture
	sprite.position = sprite_position
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.rotation = sprite_rotation
	parent.add_child(sprite)
	return sprite
