class_name LoadingScreen
extends Control


@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar

var elapsed_seconds: float = 0.0
var resource_progress: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func begin() -> void:
	elapsed_seconds = 0.0
	resource_progress = 0.0
	progress_bar.value = 0.0
	status_label.text = tr("LOADING")
	show()
	set_process(true)
	queue_redraw()


func set_resource_progress(value: float) -> void:
	resource_progress = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	elapsed_seconds += delta
	var presentation_progress := minf(elapsed_seconds / 5.0, 0.96)
	progress_bar.value = minf(
		maxf(resource_progress, presentation_progress) * 100.0,
		100.0
	)
	var dots := ".".repeat(int(elapsed_seconds * 2.4) % 4)
	status_label.text = "%s%s" % [tr("LOADING"), dots]
	queue_redraw()


func complete() -> void:
	resource_progress = 1.0
	progress_bar.value = 100.0
	status_label.text = tr("NEURAL LINK READY")
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5 + Vector2(0.0, -42.0)
	var angle := elapsed_seconds * 3.2
	draw_arc(
		center,
		38.0,
		angle,
		angle + PI * 1.35,
		48,
		Color(0.18, 0.86, 1.0, 0.95),
		5.0,
		true
	)
	draw_arc(
		center,
		28.0,
		-angle * 0.72,
		-angle * 0.72 + PI * 0.92,
		40,
		Color(0.95, 0.34, 0.26, 0.82),
		3.0,
		true
	)
	for index in range(3):
		var dot_angle := angle * 0.55 + TAU * float(index) / 3.0
		draw_circle(
			center + Vector2.from_angle(dot_angle) * 48.0,
			3.5,
			Color(0.72, 0.96, 1.0, 0.92)
		)
