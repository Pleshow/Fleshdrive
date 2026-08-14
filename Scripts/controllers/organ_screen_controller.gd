class_name OrganScreenController
extends RefCounted


var opened_from_pause: bool = false
var install_completed: bool = false
var shelf_organ: Resource
var replacement_slot: Node
var replaced_organ: Resource
var replacement_organ: Resource


func begin(from_pause: bool) -> void:
	opened_from_pause = from_pause
	install_completed = false
	shelf_organ = null
	clear_replacement()


func stage_replacement(slot: Node, current: Resource, replacement: Resource) -> bool:
	if not is_instance_valid(slot) or current == null or replacement == null:
		return false
	replacement_slot = slot
	replaced_organ = current
	replacement_organ = replacement
	return true


func clear_replacement() -> void:
	replacement_slot = null
	replaced_organ = null
	replacement_organ = null


func close() -> void:
	opened_from_pause = false
	install_completed = false
	shelf_organ = null
	clear_replacement()
