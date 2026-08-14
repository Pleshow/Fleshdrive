class_name CardSelectionController
extends RefCounted


var locked: bool = false
var selected_index: int = -1
var reroll_count: int = 0
var paid_reroll_count: int = 0


func begin_offer() -> void:
	locked = false
	selected_index = -1


func select(index: int, offer_count: int) -> bool:
	if locked or index < 0 or index >= offer_count:
		return false
	selected_index = index
	return true


func can_confirm(offer_count: int) -> bool:
	return not locked and selected_index >= 0 and selected_index < offer_count


func clear_selection() -> void:
	selected_index = -1


func register_reroll(paid: bool = false) -> void:
	reroll_count += 1
	if paid:
		paid_reroll_count += 1
	clear_selection()


func finish_offer() -> void:
	locked = true
	selected_index = -1


func reset_run() -> void:
	locked = false
	selected_index = -1
	reroll_count = 0
	paid_reroll_count = 0


func reset_offer() -> void:
	reroll_count = 0
	paid_reroll_count = 0
	clear_selection()
