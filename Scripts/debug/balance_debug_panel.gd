class_name BalanceDebugPanel
extends CanvasLayer


const BuildLoadouts := preload("res://Scripts/debug/build_debug_loadouts.gd")
const ENEMY_SCENES := {
	&"crawler": preload("res://Scenes/enemies/crawler.tscn"),
	&"spitter": preload("res://Scenes/enemies/spitter.tscn"),
	&"charger": preload("res://Scenes/enemies/charger.tscn"),
}

var panel: PanelContainer
var level_spin: SpinBox
var upgrade_edit: LineEdit
var build_options: OptionButton
var enemy_options: OptionButton
var damage_spin: SpinBox
var god_toggle: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500
	_build_panel()
	panel.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "BalanceDebugPanel"
	panel.position = Vector2(20.0, 150.0)
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.025, 0.97)
	style.border_color = Color(0.85, 0.08, 0.24, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "BALANCE LAB // F10"
	title.add_theme_color_override("font_color", Color(1.0, 0.12, 0.30))
	column.add_child(title)

	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 40
	level_spin.value = 10
	_add_control_row(column, "LEVEL", level_spin, "SET", _set_level)

	upgrade_edit = LineEdit.new()
	upgrade_edit.placeholder_text = "upgrade_id"
	_add_control_row(column, "UPGRADE", upgrade_edit, "ADD", _add_upgrade)

	build_options = OptionButton.new()
	for build_id in BuildLoadouts.LOADOUTS:
		build_options.add_item(String(build_id).to_upper())
		build_options.set_item_metadata(build_options.item_count - 1, build_id)
	_add_control_row(column, "BUILD", build_options, "FORCE", _force_build)

	enemy_options = OptionButton.new()
	for enemy_id in ENEMY_SCENES:
		enemy_options.add_item(String(enemy_id).to_upper())
		enemy_options.set_item_metadata(enemy_options.item_count - 1, enemy_id)
	_add_control_row(column, "SPAWN", enemy_options, "SPAWN", _spawn_enemy)

	damage_spin = SpinBox.new()
	damage_spin.min_value = 0.1
	damage_spin.max_value = 20.0
	damage_spin.step = 0.1
	damage_spin.value = 1.0
	_add_control_row(column, "DAMAGE X", damage_spin, "APPLY", _set_damage_multiplier)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	_add_button(action_row, "+60 SEC", _fast_forward)
	_add_button(action_row, "BOSS", _start_boss)
	_add_button(action_row, "CLEAR", _clear_enemies)

	god_toggle = CheckButton.new()
	god_toggle.text = "GOD MODE"
	god_toggle.toggled.connect(_set_god_mode)
	column.add_child(god_toggle)


func _add_control_row(
	parent: VBoxContainer,
	label_text: String,
	control: Control,
	button_text: String,
	callback: Callable
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 86.0
	row.add_child(label)
	control.custom_minimum_size.x = 190.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_add_button(row, button_text, callback)


func _add_button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	parent.add_child(button)


func _player() -> Koda:
	return get_tree().get_first_node_in_group("player") as Koda


func _set_level() -> void:
	var player := _player()
	if player == null:
		return
	player.current_level = int(level_spin.value)
	player.level_up_reached.emit(player.current_level)
	player.call("_emit_biomass_changed")
	var telemetry := get_tree().root.get_node_or_null("RunTelemetry")
	if telemetry != null:
		telemetry.call("record_level_reached", player.current_level)


func _add_upgrade() -> void:
	var player := _player()
	var upgrade_id := StringName(upgrade_edit.text.strip_edges())
	if player != null and not upgrade_id.is_empty():
		player.apply_upgrade(upgrade_id)


func _force_build() -> void:
	var player := _player()
	if player == null or build_options.item_count == 0:
		return
	BuildLoadouts.apply_to(
		player,
		StringName(build_options.get_selected_metadata()),
		5
	)


func _spawn_enemy() -> void:
	var player := _player()
	var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
	if player == null or spawner == null or enemy_options.item_count == 0:
		return
	var enemy_id := StringName(enemy_options.get_selected_metadata())
	var scene := ENEMY_SCENES.get(enemy_id) as PackedScene
	var position := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 260.0
	spawner.call("_schedule_enemy_spawn", scene, enemy_id, position, false)


func _set_damage_multiplier() -> void:
	var player := _player()
	if player == null:
		return
	if not player.has_meta("balance_debug_base_damage"):
		player.set_meta("balance_debug_base_damage", player.attack_damage)
	player.attack_damage = (
		float(player.get_meta("balance_debug_base_damage"))
		* float(damage_spin.value)
	)


func _fast_forward() -> void:
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager == null:
		return
	manager.elapsed_seconds = minf(manager.elapsed_seconds + 60.0, 659.0)
	if manager.encounter_director != null:
		manager.encounter_director.call("_process", 0.51)


func _start_boss() -> void:
	var manager := get_tree().get_first_node_in_group("run_manager")
	if manager != null:
		manager.call("start_boss_encounter")


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss"):
			enemy.queue_free()
	var pipeline := get_tree().root.get_node_or_null("CombatPipeline")
	if pipeline != null:
		pipeline.call("clear_transient_state")


func _set_god_mode(enabled: bool) -> void:
	var player := _player()
	if player != null:
		player.set_meta("balance_debug_god_mode", enabled)
