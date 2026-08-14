class_name KineticChargeHudLayer
extends CanvasLayer


var build_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	visible = build_visible and not get_tree().paused


func set_build_visible(value: bool) -> void:
	build_visible = value
	visible = value and not get_tree().paused
