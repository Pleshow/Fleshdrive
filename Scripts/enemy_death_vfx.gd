class_name EnemyDeathVFX
extends Node2D


const ORGANIC_BURST_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/organic_burst.png"
)

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	animation.material = material
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"death")
	frames.set_animation_loop(&"death", false)
	frames.set_animation_speed(&"death", 18.0)
	# The former atlas row began with a full Charger silhouette. Crawlers using
	# this scene therefore flashed one or two blue "ghost Chargers" when the
	# global palette shader quantized that frame. Use the dedicated organic
	# burst sheet so a death effect never contains another enemy's silhouette.
	for frame_index in range(12):
		var frame := AtlasTexture.new()
		frame.atlas = ORGANIC_BURST_TEXTURE
		frame.region = Rect2(
			(frame_index % 4) * 64,
			int(frame_index / 4.0) * 64,
			64,
			64
		)
		frames.add_frame(&"death", frame)
	animation.sprite_frames = frames
	animation.play(&"death")
	await animation.animation_finished
	queue_free()
