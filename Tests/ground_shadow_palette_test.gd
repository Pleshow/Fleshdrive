extends SceneTree


const Palette = preload("res://Scripts/visual/ink_crimson_palette.gd")
const SHADOW_SCENES := [
	"res://Scenes/player/koda.tscn",
	"res://Scenes/enemies/crawler.tscn",
	"res://Scenes/enemies/spitter.tscn",
	"res://Scenes/enemies/charger.tscn",
	"res://Scenes/enemies/visceral_warden.tscn",
	"res://Scenes/pickups/red_gem_pickup.tscn",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(
		Palette.GROUND_SHADOW.is_equal_approx(
			Color(0.117647, 0.341176, 0.611765, 0.42)
		),
		"Ground-shadow contract uses translucent Ink-Crimson TECH_DEEP"
	)
	for scene_path in SHADOW_SCENES:
		var packed := load(scene_path) as PackedScene
		var instance := packed.instantiate()
		var shadow := instance.get_node("GroundShadow") as Sprite2D
		_check(
			shadow.modulate.is_equal_approx(Palette.GROUND_SHADOW),
			"%s authors the shared ground-shadow color" % scene_path
		)
		instance.free()

	var runtime_shadow := Sprite2D.new()
	MinimalistVisualProfile.configure_ground_shadow(runtime_shadow)
	_check(
		runtime_shadow.modulate.is_equal_approx(Palette.GROUND_SHADOW)
		and runtime_shadow.material is CanvasItemMaterial
		and (runtime_shadow.material as CanvasItemMaterial).light_mode
		== CanvasItemMaterial.LIGHT_MODE_UNSHADED,
		"Runtime ground shadows keep the shared color independent of world lighting"
	)
	runtime_shadow.free()

	if failures == 0:
		print("GROUND SHADOW PALETTE TEST PASSED")
		quit(0)
	else:
		push_error("GROUND SHADOW PALETTE TEST FAILED: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)
