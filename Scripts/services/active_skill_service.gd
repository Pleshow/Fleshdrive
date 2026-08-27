class_name ActiveSkillService
extends RefCounted


var host


func setup(owner) -> void:
	host = owner


func handle_input(event: InputEvent) -> bool:
	if host == null or host.player == null or host.player.is_dead:
		return false
	if event.is_action_pressed("active_cancel") and host.magma_aim_active:
		host._cancel_active_skill_internal()
		return true
	if event.is_action_pressed("active_skill"):
		return bool(host._activate_or_aim_active_skill())
	if event.is_action_pressed("secondary_active_skill"):
		return bool(host._activate_secondary_active_skill())
	if event.is_action_pressed("active_confirm") and host.magma_aim_active:
		host._fire_aimed_magma_spear()
		return true
	return false


func cancel() -> void:
	if host != null:
		host._cancel_active_skill_internal()


func get_status() -> Dictionary:
	if host == null or host.player == null:
		return {}
	return host._build_active_skill_status()
