class_name OrganPopup
extends Control

var hud
var shell: Panel
var stats: GridContainer
var details: RichTextLabel
var loadout: RichTextLabel
var install_button: Button
var slots: Array[OrganSlotControl] = []
var signature := ""

func _ready() -> void:
	name = "OrganPopup"
	z_index = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	InkUI.preserve(shade)
	shade.color = Color(0.035, 0.004, 0.05, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shell = Panel.new()
	shell.name = "SurgeryWindow"
	InkUI.preserve(shell)
	shell.add_theme_stylebox_override("panel", InkUI.box(InkUI.VOID, InkUI.BORDER))
	add_child(shell)
	var title := InkUI.label(shell, tr("KODA / ORGAN SYSTEM"), Rect2(28, 18, 720, 34), 25)
	title.name = "SurgeryTitle"
	InkUI.button(shell, "×", Rect2(904, 14, 42, 40), hud._on_organ_close_pressed)
	InkUI.label(shell, tr("VITAL SIGNS"), Rect2(26, 77, 234, 26), 18)
	stats = GridContainer.new()
	stats.columns = 2
	stats.position = Vector2(26, 119)
	stats.size = Vector2(245, 310)
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 11)
	shell.add_child(stats)
	var anatomy := TextureRect.new()
	anatomy.name = "ShibaSilhouette"
	InkUI.preserve(anatomy)
	anatomy.position = Vector2(285, 145)
	anatomy.size = Vector2(370, 250)
	anatomy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	anatomy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	anatomy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://Assets/ui/ink_crimson_v2/shiba_silhouette.png"):
		anatomy.texture = load("res://Assets/ui/ink_crimson_v2/shiba_silhouette.png")
	shell.add_child(anatomy)
	slots.assign([hud.brain_slot, hud.heart_slot, hud.legs_slot])
	var positions := [Vector2(300, 96), Vector2(503, 212), Vector2(373, 366)]
	for index in range(slots.size()):
		var slot := slots[index]
		slot.reparent(shell)
		slot.show()
		slot.position = positions[index]
		slot.size = Vector2(74, 86)
		slot.scale = Vector2.ONE
		slot.focus_mode = Control.FOCUS_ALL
		for child in slot.get_children():
			if child is CanvasItem:
				child.hide()
		var panel := Panel.new()
		InkUI.preserve(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", InkUI.box())
		slot.add_child(panel)
		slot.move_child(panel, 0)
		if is_instance_valid(slot.installed_organ):
			# Normalize anchors before sizing so authored slot layouts cannot emit
			# opposite-anchor warnings when reparented into the popup.
			slot.installed_organ.anchor_left = 0.0
			slot.installed_organ.anchor_top = 0.0
			slot.installed_organ.anchor_right = 0.0
			slot.installed_organ.anchor_bottom = 0.0
			slot.installed_organ.offset_left = 7.0
			slot.installed_organ.offset_top = 7.0
			slot.installed_organ.offset_right = 67.0
			slot.installed_organ.offset_bottom = 67.0
			slot.installed_organ.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.installed_organ.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.installed_organ.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := InkUI.label(slot, tr(["BRAIN SLOT", "HEART SLOT", "LEGS SLOT"][index]), Rect2(-18, -26, 112, 24), 12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.gui_input.connect(_slot_input.bind(slot))
		slot.mouse_entered.connect(_show_slot.bind(slot))
		slot.focus_entered.connect(_show_slot.bind(slot))
	InkUI.label(shell, tr("ORGAN DETAILS"), Rect2(682, 77, 260, 27), 18)
	details = RichTextLabel.new()
	InkUI.preserve(details)
	details.position = Vector2(682, 114)
	details.size = Vector2(254, 292)
	details.add_theme_font_size_override("normal_font_size", 16)
	details.add_theme_color_override("default_color", InkUI.TEXT)
	shell.add_child(details)
	install_button = InkUI.button(shell, tr("INSTALL ORGAN"), Rect2(682, 418, 254, 42), _install_pending)
	InkUI.button(shell, "◀", Rect2(682, 469, 48, 34), hud._show_previous_pending_organ)
	InkUI.button(shell, "▶", Rect2(888, 469, 48, 34), hud._show_next_pending_organ)
	loadout = RichTextLabel.new()
	InkUI.preserve(loadout)
	loadout.position = Vector2(28, 475)
	loadout.size = Vector2(622, 79)
	loadout.add_theme_font_size_override("normal_font_size", 14)
	loadout.add_theme_color_override("default_color", InkUI.TEXT)
	shell.add_child(loadout)
	hud.organ_close_button.reparent(shell)
	InkUI.preserve(hud.organ_close_button)
	hud.organ_close_button.position = Vector2(682, 522)
	hud.organ_close_button.size = Vector2(254, 40)
	hud.organ_close_button.add_theme_font_size_override("font_size", 12)
	hud.replacement_confirmation.z_index = 40
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var view := get_viewport_rect().size
	var factor := minf(1.0, minf((view.x - 32.0) / 960.0, (view.y - 32.0) / 584.0))
	shell.size = Vector2(960, 584)
	shell.scale = Vector2.ONE * factor
	shell.position = (view - shell.size * factor) * 0.5

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or hud.player == null:
		return
	# Legacy widgets remain alive for the existing inventory controller only.
	for child in hud.organ_screen.get_children():
		if child != self and child != hud.replacement_confirmation and child is CanvasItem:
			child.hide()
	var current := str(hud.player.get_character_sheet()) + str(hud.pending_organ_index) + str(hud.pending_organs) + TranslationServer.get_locale()
	if current == signature:
		return
	signature = current
	for child in stats.get_children():
		stats.remove_child(child)
		child.queue_free()
	for row: Dictionary in hud.player.get_character_sheet().get("stats", []):
		var name_label := InkUI.label(stats, tr(String(row.get("name", ""))), Rect2(), 13)
		name_label.custom_minimum_size = Vector2(155, 22)
		InkUI.label(stats, KodaStatSheet.format_value(row), Rect2(), 15)
	for slot in slots:
		if not is_instance_valid(slot.installed_organ):
			continue
		slot.installed_organ.visible = slot.installed_organ_data != null
		if slot.installed_organ_data != null:
			slot.installed_organ.texture = hud._get_generated_card_art(slot.installed_organ_data)
		var valid: bool = hud.pending_organ != null and hud.pending_organ.organ_slot == slot.accepted_slot
		(slot.get_child(0) as Panel).add_theme_stylebox_override("panel", InkUI.box(InkUI.PANEL, InkUI.TEXT if valid else InkUI.BORDER))
	install_button.disabled = hud.pending_organ == null
	if hud.pending_organ != null:
		var pending: UpgradeData = hud.pending_organ
		var old: UpgradeData
		for slot in slots:
			if slot.accepted_slot == pending.organ_slot:
				old = slot.installed_organ_data
		details.text = "%s (%d/%d)\n\n%s\n%s\n\n%s\n%s" % [tr("PENDING ORGAN"), hud.pending_organ_index + 1, hud.pending_organs.size(), tr("NEW ORGAN"), hud._get_upgrade_display_name(pending) + "\n" + tr(pending.description), tr("CURRENT ORGAN"), tr("EMPTY SLOT") if old == null else hud._get_upgrade_display_name(old) + "\n" + tr(old.description)]
	else:
		details.text = tr("SELECT AN ORGAN SLOT TO INSPECT IT") + "\n\n" + tr("NO PENDING ORGAN")
	var owned: Array[String] = []
	for upgrade in hud.upgrade_pool:
		if upgrade != null and hud.player.get_upgrade_level(upgrade.upgrade_id) > 0 and upgrade.upgrade_kind != UpgradeData.UpgradeKind.ORGAN:
			owned.append("%s %d" % [hud._get_upgrade_display_name(upgrade), hud.player.get_upgrade_level(upgrade.upgrade_id)])
	loadout.text = tr("VOLTAIC HEART") + " · " + tr("LEVEL") + " %d\n" % hud.player.active_fleshdrive_level + (" · ".join(owned) if not owned.is_empty() else tr("BASE ARC ONLY"))

func _show_slot(slot: OrganSlotControl) -> void:
	if hud.pending_organ != null:
		return
	var organ := slot.installed_organ_data
	details.text = tr("EMPTY SLOT") if organ == null else hud._get_upgrade_display_name(organ) + "\n\n" + tr(organ.description)

func _slot_input(event: InputEvent, slot: OrganSlotControl) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		if hud.pending_organ != null:
			slot._drop_data(Vector2.ZERO, hud.pending_organ)
		else:
			_show_slot(slot)
		slot.accept_event()

func _install_pending() -> void:
	if hud.pending_organ == null:
		return
	for slot in slots:
		if slot.accepted_slot == hud.pending_organ.organ_slot:
			slot._drop_data(Vector2.ZERO, hud.pending_organ)
			return
