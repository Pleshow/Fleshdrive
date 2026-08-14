class_name BossPresentationController
extends RefCounted


var active: bool = false
var phase: int = 0
var dialogue_epoch: int = 0


func begin() -> void:
	active = true
	phase = 1
	dialogue_epoch += 1


func set_phase(value: int) -> void:
	phase = maxi(value, 1)


func next_dialogue_epoch() -> int:
	dialogue_epoch += 1
	return dialogue_epoch


func is_dialogue_current(epoch: int) -> bool:
	return epoch == dialogue_epoch


func finish() -> void:
	active = false
	dialogue_epoch += 1
