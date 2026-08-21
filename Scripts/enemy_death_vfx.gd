class_name EnemyDeathVFX
extends Node2D


const COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/enemy_combat_vfx_atlas.png"
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
	for frame_index in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = COMBAT_TEXTURE
		frame.region = Rect2(
			frame_index * 256,
			2 * 256,
			256,
			256
		)
		frames.add_frame(&"death", frame)
	animation.sprite_frames = frames
	animation.play(&"death")
	await animation.animation_finished
	queue_free()
