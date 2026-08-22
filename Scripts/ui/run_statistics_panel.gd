class_name RunStatisticsPanel
extends PanelContainer


const COMPACT_POSITION := Vector2(575.0, 92.0)
const COMPACT_SIZE := Vector2(230.0, 198.0)
const EXPANDED_POSITION := Vector2(36.0, 36.0)
const EXPANDED_SIZE := Vector2(1208.0, 648.0)

var summary: Dictionary = {}
var expanded := false
var title_label: Label
var content: VBoxContainer
var toggle_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.014, 0.02, 0.96)
	style.border_color = Color(0.16, 0.72, 0.78, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	add_theme_stylebox_override("panel", style)
	gui_input.connect(_on_panel_input)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root_stack := VBoxContainer.new()
	root_stack.add_theme_constant_override("separation", 7)
	margin.add_child(root_stack)
	var header := HBoxContainer.new()
	root_stack.add_child(header)
	title_label = Label.new()
	title_label.text = tr("PREVIOUS RUN STATISTICS")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color(0.34, 0.92, 0.96))
	header.add_child(title_label)
	toggle_button = Button.new()
	toggle_button.text = tr("EXPAND")
	toggle_button.custom_minimum_size = Vector2(76.0, 30.0)
	toggle_button.pressed.connect(_toggle_expanded)
	header.add_child(toggle_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_stack.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	position = COMPACT_POSITION
	size = COMPACT_SIZE


func present(run_summary: Dictionary) -> void:
	summary = run_summary.duplicate(true)
	expanded = false
	position = COMPACT_POSITION
	size = COMPACT_SIZE
	z_index = 20
	_apply_layout_mode()
	_rebuild()
	show()


func _toggle_expanded() -> void:
	expanded = not expanded
	position = EXPANDED_POSITION if expanded else COMPACT_POSITION
	size = EXPANDED_SIZE if expanded else COMPACT_SIZE
	_apply_layout_mode()
	_rebuild()


func _apply_layout_mode() -> void:
	z_index = 100 if expanded else 20
	title_label.text = (
		tr("PREVIOUS RUN STATISTICS") if expanded else tr("RUN STATISTICS")
	)
	title_label.add_theme_font_size_override("font_size", 19 if expanded else 14)
	toggle_button.text = tr("COLLAPSE") if expanded else tr("EXPAND")
	toggle_button.custom_minimum_size = (
		Vector2(110.0, 34.0) if expanded else Vector2(76.0, 30.0)
	)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_expanded()
		accept_event()


func _rebuild() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_add_metric_strip()
	if expanded:
		_add_chart(tr("KODA DAMAGE BY SOURCE"), Dictionary(summary.get("damage_sources", {})))
		_add_chart(tr("ENEMY DAMAGE TO KODA"), _enemy_damage_values())
		_add_chart(tr("KILLS BY ENEMY"), Dictionary(summary.get("kills_by_enemy", {})))
		_add_details()


func _add_metric_strip() -> void:
	var metrics := [
		[tr("TOTAL DAMAGE"), "%.0f" % float(summary.get("total_damage_dealt", 0.0))],
		[tr("DPS"), "%.1f" % float(summary.get("average_dps", 0.0))],
		[tr("DAMAGE TAKEN"), "%.0f" % float(summary.get("damage_received", 0.0))],
		[tr("KILLS"), "%d" % int(summary.get("kills", 0))],
	]
	if expanded:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color(0.74, 0.84, 0.85))
		var parts: Array[String] = []
		for metric: Array in metrics:
			parts.append("%s %s" % [metric[0], metric[1]])
		row.text = "    ".join(parts)
		content.add_child(row)
		return
	for metric: Array in metrics:
		var metric_row := HBoxContainer.new()
		metric_row.add_theme_constant_override("separation", 5)
		content.add_child(metric_row)
		var name_label := Label.new()
		name_label.text = String(metric[0])
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.58, 0.78, 0.80))
		metric_row.add_child(name_label)
		var value_label := Label.new()
		value_label.text = String(metric[1])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 15)
		value_label.add_theme_color_override("font_color", Color(0.95, 0.31, 0.48))
		metric_row.add_child(value_label)


func _add_chart(heading: String, values: Dictionary) -> void:
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_size_override("font_size", 14 if not expanded else 18)
	heading_label.add_theme_color_override("font_color", Color(0.92, 0.34, 0.48))
	content.add_child(heading_label)
	var entries: Array[Dictionary] = []
	for key in values:
		entries.append({"name": String(key), "value": float(values[key])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["value"]) > float(b["value"])
	)
	var limit := entries.size() if expanded else mini(entries.size(), 3)
	var maximum := float(entries[0]["value"]) if not entries.is_empty() else 1.0
	if limit == 0:
		var empty := Label.new()
		empty.text = tr("NO DATA")
		content.add_child(empty)
		return
	for index in range(limit):
		_add_bar(entries[index], maximum)


func _add_bar(entry: Dictionary, maximum: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(150.0 if expanded else 112.0, 22.0)
	name_label.text = String(entry["name"]).replace("_", " ").to_upper()
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 12 if not expanded else 14)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 20.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.max_value = maxf(maximum, 1.0)
	bar.value = float(entry["value"])
	row.add_child(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(70.0, 22.0)
	value_label.text = "%.0f" % float(entry["value"])
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)


func _enemy_damage_values() -> Dictionary:
	var detailed := Dictionary(summary.get("enemy_damage", {}))
	if not detailed.is_empty():
		return detailed
	return Dictionary(summary.get("damage_received_sources", {}))


func _add_details() -> void:
	var details := Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 15)
	details.add_theme_color_override("font_color", Color(0.72, 0.86, 0.88))
	details.text = (
		"%s: %s    %s: %.0f    %s: %.0f    %s: %.1fs"
		% [
			tr("DEATH CAUSE"), tr(String(summary.get("death_cause", "UNKNOWN")).replace("_", " ").to_upper()),
			tr("BIOMASS COLLECTED"), float(summary.get("biomass_collected", summary.get("biomass", 0.0))),
			tr("BIOMASS MISSED"), float(summary.get("biomass_missed", 0.0)),
			tr("CROWD CONTROL"), float(summary.get("crowd_control_seconds", 0.0)),
		]
	)
	content.add_child(details)
