extends SceneTree


const WALK_PREFIX := (
	"res://Assets/enemies/crawler/Snake crawler/walk/east/snake walk"
)
const DEATH_PREFIX := (
	"res://Assets/enemies/crawler/Snake crawler/death/east/snake death"
)

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_scene_frames()
	_test_runtime_profile_frames()
	if failures == 0:
		print("CRAWLER SPRITE TEST PASSED")
		quit(0)
	else:
		push_error("CRAWLER SPRITE TEST FAILED: %d" % failures)
		quit(1)


func _test_scene_frames() -> void:
	var scene := load("res://Scenes/enemies/crawler.tscn") as PackedScene
	_check(scene != null, "Crawler scene loads")
	if scene == null:
		return
	var crawler := scene.instantiate() as CharacterBody2D
	var sprite := crawler.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check_animation_contract(sprite.sprite_frames)
	_check_numbered_frames(sprite.sprite_frames, &"walk", WALK_PREFIX, 9, "Crawler scene")
	_check_numbered_frames(sprite.sprite_frames, &"attack", WALK_PREFIX, 9, "Crawler scene")
	_check_numbered_frames(sprite.sprite_frames, &"death", DEATH_PREFIX, 10, "Crawler scene")
	crawler.free()


func _test_runtime_profile_frames() -> void:
	var sprite := AnimatedSprite2D.new()
	MinimalistVisualProfile.configure_crawler(sprite)
	_check_animation_contract(sprite.sprite_frames)
	_check_numbered_frames(
		sprite.sprite_frames,
		&"walk",
		WALK_PREFIX,
		9,
		"Dusk Garden runtime profile"
	)
	_check_numbered_frames(
		sprite.sprite_frames,
		&"attack",
		WALK_PREFIX,
		9,
		"Dusk Garden runtime profile"
	)
	_check_numbered_frames(
		sprite.sprite_frames,
		&"death",
		DEATH_PREFIX,
		10,
		"Dusk Garden runtime profile"
	)
	sprite.free()


func _check_animation_contract(frames: SpriteFrames) -> void:
	_check(frames.has_animation(&"walk"), "Crawler retains the walk animation")
	_check(frames.has_animation(&"attack"), "Crawler retains the attack animation")
	_check(frames.has_animation(&"death"), "Crawler retains the death animation")
	_check(frames.get_frame_count(&"walk") == 9, "Crawler has nine walk frames")
	_check(frames.get_frame_count(&"attack") == 9, "Crawler has nine attack frames")
	_check(frames.get_frame_count(&"death") == 10, "Crawler has ten death frames")


func _check_numbered_frames(
	frames: SpriteFrames,
	animation: StringName,
	prefix: String,
	frame_count: int,
	source: String
) -> void:
	for frame_index in range(frame_count):
		var texture := frames.get_frame_texture(animation, frame_index)
		_check(
			texture != null
			and texture.resource_path == "%s%d.png" % [
				prefix,
				frame_index + 1,
			],
			"%s uses crimson %s frame %d" % [
				source,
				animation,
				frame_index + 1,
			]
		)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
