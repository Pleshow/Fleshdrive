class_name MinimalistVisualProfile
extends RefCounted


const ARENA_ID: StringName = &"dusk_garden"
const PLAYER_ROOT := "res://Assets/player/Koda_32x32"
const CRAWLER_ROOT := "res://Assets/enemies/crawler/Snake crawler"
const SPITTER_ROOT := "res://Assets/enemies/spitter/Spider"
const BIOMASS_TEXTURE := preload(
	"res://Assets/environment/small_biomass_transparent.png"
)
const PIXEL_EMISSIVE_SHADER := preload(
	"res://Shaders/pixel_emissive.gdshader"
)
const DIRECTIONS: Array[StringName] = [&"down", &"right", &"up", &"left"]
const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
static var pixel_shadow_texture: ImageTexture


static func is_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var flow := tree.root.get_node_or_null("GameFlow")
	return (
		flow != null
		and StringName(flow.get("selected_arena_id")) == ARENA_ID
	)


static func configure_player(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for direction in DIRECTIONS:
		_add_file_animation(
			frames,
			direction,
			PLAYER_ROOT + "/running state/east",
			8,
			12.0,
			true
		)
		_add_file_animation(
			frames,
			StringName("idle_%s" % direction),
			PLAYER_ROOT + "/Idle state",
			8,
			7.0,
			true
		)
		_add_selected_file_animation(
			frames,
			StringName("jump_%s" % direction),
			PLAYER_ROOT + "/jumping/east",
			[0, 2, 4, 6, 8],
			18.0,
			false
		)
		_add_file_animation(
			frames,
			StringName("attack_%s" % direction),
			PLAYER_ROOT + "/running state/east",
			8,
			15.0,
			false
		)
		_add_file_animation(
			frames,
			StringName("hurt_%s" % direction),
			PLAYER_ROOT + "/jumping/east",
			4,
			14.0,
			false
		)
		_add_file_animation(
			frames,
			StringName("death_%s" % direction),
			PLAYER_ROOT + "/death/east",
			9,
			12.0,
			false
		)
	sprite.sprite_frames = frames
	sprite.animation = &"idle_right"
	sprite.frame = 0
	# Fractional nearest-neighbour scaling makes pixel widths alternate while a
	# sprite moves. Keep gameplay sprites at native integer scale so high-contrast
	# edges remain temporally stable as well as sharp in a still frame.
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, -8.0)
	_apply_crisp_canvas_style(sprite)
	sprite.play()


static func configure_crawler(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_file_animation(frames, &"walk", CRAWLER_ROOT + "/walk/east", 9, 11.0, true)
	_add_file_animation(frames, &"attack", CRAWLER_ROOT + "/attack/east", 9, 15.0, false)
	_add_file_animation(frames, &"death", CRAWLER_ROOT + "/death/east", 9, 13.0, false)
	sprite.sprite_frames = frames
	sprite.animation = &"walk"
	sprite.frame = 0
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, -3.0)
	_apply_crisp_canvas_style(sprite)
	sprite.play()


static func configure_spitter(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_file_animation(
		frames,
		&"normal",
		SPITTER_ROOT + "/flying/south-east",
		9,
		10.0,
		true
	)
	_add_file_animation(
		frames,
		&"windup",
		SPITTER_ROOT + "/flying/south-east",
		9,
		16.0,
		true
	)
	_add_file_animation(
		frames,
		&"death",
		SPITTER_ROOT + "/death/south-east",
		9,
		8.0,
		false
	)
	sprite.sprite_frames = frames
	sprite.animation = &"normal"
	sprite.frame = 0
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, -18.0)
	_apply_crisp_canvas_style(sprite)
	sprite.play()


static func configure_biomass(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"pulse")
	frames.set_animation_loop(&"pulse", true)
	frames.set_animation_speed(&"pulse", 2.0)
	frames.add_frame(&"pulse", BIOMASS_TEXTURE, 1.0)
	frames.add_frame(&"pulse", BIOMASS_TEXTURE, 1.0)
	sprite.sprite_frames = frames
	sprite.animation = &"pulse"
	sprite.frame = 0
	# The source is already a complete 17x17 pickup. Keep it deliberately tiny
	# beside the 48px character frames, like a compact survivor-game XP drop.
	sprite.scale = Vector2.ONE * 0.65
	_apply_crisp_canvas_style(sprite)
	var biomass_material := ShaderMaterial.new()
	biomass_material.shader = PIXEL_EMISSIVE_SHADER
	biomass_material.set_shader_parameter("force_electric_blue", true)
	sprite.material = biomass_material
	sprite.play()


static func configure_shadow(
	shadow: Sprite2D,
	display_scale: Vector2,
	ground_position: Vector2
) -> void:
	if shadow == null:
		return
	if pixel_shadow_texture == null:
		var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var rows := [
			"................",
			"....########....",
			"..############..",
			".##############.",
			".##############.",
			"..############..",
			"....########....",
			"................",
		]
		for y in range(rows.size()):
			for x in range(String(rows[y]).length()):
				if String(rows[y]).substr(x, 1) == "#":
					image.set_pixel(x, y, Palette.VOID)
		pixel_shadow_texture = ImageTexture.create_from_image(image)
	shadow.texture = pixel_shadow_texture
	shadow.scale = display_scale
	shadow.position = ground_position
	shadow.modulate = Palette.TECH_BRIGHT
	_apply_crisp_canvas_style(shadow)


static func _add_file_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	folder: String,
	frame_count: int,
	fps: float,
	loops: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loops)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in range(frame_count):
		var path := "%s/frame_%03d.png" % [folder, frame_index]
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("Minimalist visual profile could not load: %s" % path)
			continue
		frames.add_frame(animation_name, texture)


static func _add_selected_file_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	folder: String,
	frame_indices: Array,
	fps: float,
	loops: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loops)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in frame_indices:
		var path := "%s/frame_%03d.png" % [folder, int(frame_index)]
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("Minimalist visual profile could not load: %s" % path)
			continue
		frames.add_frame(animation_name, texture)


static func _apply_crisp_canvas_style(item: CanvasItem) -> void:
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	item.material = unshaded
