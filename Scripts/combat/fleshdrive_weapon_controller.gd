class_name FleshdriveWeaponController
extends RefCounted


var host: PlayerWeaponSystem
var affinity: StringName
var handlers: Dictionary = {}


func setup(
	system: PlayerWeaponSystem,
	controller_affinity: StringName,
	weapon_handlers: Dictionary
) -> void:
	host = system
	affinity = controller_affinity
	handlers = weapon_handlers.duplicate()


func handles(weapon_id: StringName) -> bool:
	return handlers.has(weapon_id)


func fire(weapon_id: StringName, level: int) -> bool:
	if host == null or not handlers.has(weapon_id):
		return false
	return bool(host.call(StringName(handlers[weapon_id]), level))


func cooldown(weapon_id: StringName, level: int) -> float:
	var database := host.get_tree().root.get_node_or_null("BalanceDatabase")
	if database == null:
		return 1.0
	return float(database.call(
		"get_weapon_cooldown",
		weapon_id,
		level,
		1.0
	))
