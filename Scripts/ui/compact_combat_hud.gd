class_name CompactCombatHUD
extends Control

@export_group("Screen Placement")
@export var screen_offset: Vector2 = Vector2.ZERO

var hud: Control
var hp: Label
var hp_orb: TextureProgressBar
var energy_orb: TextureProgressBar
var energy: Label
var level: Label
var currency: Label
var clock_label: Label
var dash_button: Button
var primary_button: Button
var secondary_button: Button
var organ_button: Button
var xp: ProgressBar
var frame: Texture2D
var health_ratio := 1.0
var charge_ratio := 0.0

func _ready() -> void:
	name = "CompactCombatHUD"
	InkUI.preserve(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	if ResourceLoader.exists("res://Assets/ui/ink_crimson_v2/hud_ornament.png"):
		frame = load("res://Assets/ui/ink_crimson_v2/hud_ornament.png")
	if has_node("AuthoredFrame"):
		_bind_authored_nodes()
		get_viewport().size_changed.connect(_layout)
		_layout()
		return
	hp = InkUI.label(self, "", Rect2(72, 176, 116, 24), 16)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy = InkUI.label(self, "", Rect2(716, 176, 116, 24), 16)
	energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level = InkUI.label(self, "", Rect2(500, 180, 138, 22), 16)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency = InkUI.label(self, "", Rect2(320, 180, 186, 22), 13)
	clock_label = InkUI.label(self, "", Rect2(646, 180, 170, 22), 13)
	dash_button = InkUI.button(self, "", Rect2(235, 112, 112, 34), _dash)
	primary_button = InkUI.button(self, "", Rect2(355, 112, 128, 34), _primary)
	secondary_button = InkUI.button(self, "", Rect2(491, 112, 122, 34), _secondary)
	organ_button = InkUI.button(self, tr("ORGANS"), Rect2(621, 112, 72, 34), _organs)
	organ_button.add_theme_font_size_override("font_size", 12)
	xp = ProgressBar.new()
	InkUI.preserve(xp)
	xp.position = Vector2(180, 238)
	xp.size = Vector2(540, 9)
	xp.show_percentage = false
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The generated ornament is the bezel; keep the live fill recessed behind it.
	xp.z_index = -1
	xp.add_theme_stylebox_override("background", InkUI.box(InkUI.VOID, Color("1e579c")))
	xp.add_theme_stylebox_override("fill", InkUI.box(InkUI.BLUE, InkUI.TEXT))
	add_child(xp)
	InkUI.label(self, "XP", Rect2(154, 230, 25, 20), 11)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _bind_authored_nodes() -> void:
	# Ornament is the top bezel: live fills and captions render underneath it
	# and remain visible through its transparent sockets.
	$AuthoredFrame.z_index = 2
	hp = get_node_or_null("HP")
	hp_orb = get_node_or_null("HPOrb")
	energy_orb = get_node_or_null("EnergyOrb")
	energy = get_node_or_null("Energy")
	level = get_node_or_null("Level")
	currency = get_node_or_null("Currency")
	clock_label = get_node_or_null("Clock")
	dash_button = get_node_or_null("Dash")
	primary_button = get_node_or_null("Primary")
	secondary_button = get_node_or_null("Secondary")
	organ_button = get_node_or_null("Organs")
	xp = get_node_or_null("XP")
	xp.z_index = 0
	for overlay in [hp, energy, level, currency, clock_label, dash_button, primary_button, secondary_button, organ_button]:
		if overlay != null: overlay.z_index = 3
	if dash_button != null: dash_button.pressed.connect(_dash)
	if primary_button != null: primary_button.pressed.connect(_primary)
	if secondary_button != null: secondary_button.pressed.connect(_secondary)
	if organ_button != null: organ_button.pressed.connect(_organs)
	frame = null

func _layout() -> void:
	var viewport := get_viewport_rect().size
	# Keep the authored ornament compact on wide screens; its native artwork is
	# intentionally a three-to-one strip and should never dominate the arena.
	var factor := minf(0.72, (viewport.x - 24.0) / 900.0)
	size = Vector2(900, 300)
	scale = Vector2.ONE * factor
	# Bottom edge is flush with the viewport; the scene itself owns the
	# ornament padding, so no extra runtime margin is added here.
	position = Vector2(
		(viewport.x - 900.0 * factor) * 0.5,
		viewport.y - size.y * factor
	) + screen_offset

func _process(_delta: float) -> void:
	if hud == null or hud.player == null:
		return
	for id in ["TopHudSafeArea", "PlayerStatusPanel", "BiomassTitle", "BiomassBar", "BiomassValueLabel", "RunTimerLabel", "MagmaSpearSkill"]:
		var old := hud.get_node_or_null(NodePath(id)) as CanvasItem
		if old != null:
			old.hide()
	# Explicitly hide authored bar nodes as well; some scene variants expose
	# them outside the named parent and would otherwise draw over the socket.
	for legacy in ["HealthBar", "HealthValueLabel", "HealthTitle", "LevelLabel"]:
		var legacy_node := hud.get_node_or_null(NodePath("PlayerStatusPanel/" + legacy)) as CanvasItem
		if legacy_node != null:
			legacy_node.hide()
	visible = hud.run_manager != null and hud.run_manager.state in [RunManager.RunState.PLAYING, RunManager.RunState.AIMING, RunManager.RunState.BOSS_INTRO]
	if not visible:
		return
	var player: Koda = hud.player
	health_ratio = clampf(player.current_health / maxf(player.max_health, 1.0), 0.0, 1.0)
	if is_instance_valid(hp_orb):
		hp_orb.value = health_ratio * 100.0
	var volt = player.weapon_system.get("volt_hound")
	var kinetic_active := volt != null and player.get_upgrade_level(&"static_claws") > 0
	if is_instance_valid(energy_orb):
		energy_orb.value = (float(volt.momentum) / maxf(float(volt.maximum_momentum), 1.0)) * 100.0 if kinetic_active else 100.0
		energy_orb.modulate = Color.WHITE if kinetic_active else Color("1e579c")
		if kinetic_active and energy_orb.value >= 99.9:
			energy_orb.modulate = Color(0.65, 0.92, 1.0, 1.0).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
	if volt != null and is_instance_valid(volt.momentum_layer):
		volt.momentum_layer.hide()
	var thunder_runtime = player.weapon_system.thunder_god
	if thunder_runtime != null and is_instance_valid(thunder_runtime.status_layer):
		thunder_runtime.status_layer.hide()
	if hp != null: hp.text = "%d / %d" % [ceili(player.current_health), ceili(player.max_health)]
	if level != null: level.text = "%s %d" % [tr("LEVEL"), player.current_level]
	var meta := get_tree().root.get_node_or_null("MetaProgression")
	if currency != null:
		currency.text = tr("Blood: %d") % (
			int(meta.get("red_gems")) if meta != null else 0
		)
	if clock_label != null: clock_label.text = tr("DEFEAT THE WARDEN") if hud.run_manager.boss_spawned else hud.format_duration(hud.run_manager.get_remaining_seconds())
	if xp != null:
		xp.max_value = maxf(player.biomass_required, 1.0)
		xp.value = player.current_biomass
	tooltip_text = "XP %d / %d" % [player.current_biomass, player.biomass_required]
	var status: Dictionary = player.weapon_system.get_active_skill_status()
	charge_ratio = 1.0 - clampf(float(status.get("cooldown", 0.0)) / maxf(float(status.get("max_cooldown", 1.0)), 1.0), 0.0, 1.0)
	var unlocked := bool(status.get("unlocked", false))
	var ready := unlocked and bool(status.get("ready", float(status.get("cooldown", 0.0)) <= 0.0))
	if energy != null: energy.text = tr("READY") if ready else ("%d%%" % roundi(charge_ratio * 100.0) if unlocked else tr("LOCKED"))
	var settings := get_tree().root.get_node("GameSettings")
	if primary_button != null:
		primary_button.text = "%s  %s" % [settings.get_active_skill_key_text(), tr("DISCHARGE")]
		primary_button.disabled = not ready
	if dash_button != null: dash_button.text = "%s · %s" % [tr("DASH"), tr("SPACE")]
	if secondary_button != null: secondary_button.text = "%s · %s" % [settings.get_secondary_active_skill_key_text(), tr("THUNDER")]
	var thunder = player.weapon_system.thunder_god
	if secondary_button != null: secondary_button.disabled = thunder == null or (thunder.has_method("has_capstone_active_skill") and not thunder.has_capstone_active_skill())
	if organ_button != null: organ_button.text = tr("ORGANS")
	queue_redraw()

func _draw() -> void:
	if frame != null:
		draw_texture_rect(frame, Rect2(0, 0, 900, 300), false)
	# Authored scenes provide their own transparent ornament; do not add a
	# fallback panel behind it, since that opaque box masks the gameplay UI.

func _dash() -> void:
	Input.action_press("dash")
	await get_tree().physics_frame
	Input.action_release("dash")

func _primary() -> void:
	Input.action_press("active_skill")
	await get_tree().process_frame
	Input.action_release("active_skill")

func _secondary() -> void:
	Input.action_press("secondary_active_skill")
	await get_tree().process_frame
	Input.action_release("secondary_active_skill")

func _organs() -> void:
	hud.run_manager.set_manual_pause(true)
	hud.open_organ_screen_from_pause()
