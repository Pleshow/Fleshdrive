class_name BalanceDebugPanel
extends CanvasLayer


const BuildLoadouts := preload("res://Scripts/debug/build_debug_loadouts.gd")
const ENEMY_SCENES := {
	&"crawler": preload("res://Scenes/enemies/crawler.tscn"),
	&"spitter": preload("res://Scenes/enemies/spitter.tscn"),
	&"charger": preload("res://Scenes/enemies/charger.tscn"),
}

@onready var panel: PanelContainer = %BalanceDebugPanel
@onready var level_spin: SpinBox = %LevelSpin
@onready var upgrade_edit: LineEdit = %UpgradeEdit
@onready var build_options: OptionButton = %BuildOptions
@onready var enemy_options: OptionButton = %EnemyOptions
@onready var damage_spin: SpinBox = %DamageSpin
@onready var god_toggle: CheckButton = %GodToggle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 500
	_style_and_connect_panel()
	panel.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _style_and_connect_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.025, 0.97)
	style.border_color = Color(0.85, 0.08, 0.24, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	for build_id in BuildLoadouts.LOADOUTS:
		build_options.add_item(String(build_id).to_upper())
		build_options.set_item_metadata(build_options.item_count - 1, build_id)
	for enemy_id in ENEMY_SCENES:
		enemy_options.add_item(String(enemy_id).to_upper())
		enemy_options.set_item_metadata(enemy_options.item_count - 1, enemy_id)
	$BalanceDebugPanel/Margin/Column/LevelRow/Action.pressed.connect(_set_level)
	$BalanceDebugPanel/Margin/Column/UpgradeRow/Action.pressed.connect(_add_upgrade)
	$BalanceDebugPanel/Margin/Column/BuildRow/Action.pressed.connect(_force_build)
	$BalanceDebugPanel/Margin/Column/EnemyRow/Action.pressed.connect(_spawn_enemy)
	$BalanceDebugPanel/Margin/Column/DamageRow/Action.pressed.connect(_set_damage_multiplier)
	$BalanceDebugPanel/Margin/Column/Actions/FastForward.pressed.connect(_fast_forward)
	$BalanceDebugPanel/Margin/Column/Actions/Boss.pressed.connect(_start_boss)
	$BalanceDebugPanel/Margin/Column/Actions/Clear.pressed.connect(_clear_enemies)
	god_toggle.toggled.connect(_set_god_mode)


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
