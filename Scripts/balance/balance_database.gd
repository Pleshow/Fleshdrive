extends Node


const BALANCE_RESOURCE := preload(
	"res://Resources/Balance/combat_balance.tres"
)

var data: CombatBalanceData


func _ready() -> void:
	data = BALANCE_RESOURCE


func get_weapon_profile(weapon_id: StringName) -> Dictionary:
	return Dictionary(data.weapon_profiles.get(weapon_id, {}))


func get_kinetic_value(
	profile_id: StringName,
	key: String,
	fallback: float
) -> float:
	var profile := Dictionary(data.kinetic_profiles.get(profile_id, {}))
	return float(profile.get(key, fallback))


func get_weapon_value(
	weapon_id: StringName,
	key: String,
	level: int,
	fallback: float
) -> float:
	var profile := get_weapon_profile(weapon_id)
	if not profile.has(key):
		return fallback
	var base := float(profile[key])
	var step := float(profile.get(key + "_step", 0.0))
	return base + step * float(maxi(level - 1, 0))


func get_weapon_cooldown(
	weapon_id: StringName,
	level: int,
	fallback: float = 1.0
) -> float:
	var profile := get_weapon_profile(weapon_id)
	if profile.is_empty():
		return fallback
	var cooldown := (
		float(profile.get("cooldown", fallback))
		+ float(profile.get("step", 0.0))
		* float(maxi(level - 1, 0))
	)
	return maxf(cooldown, float(profile.get("minimum", 0.05)))


func get_enemy_profile(enemy_id: StringName) -> Dictionary:
	return Dictionary(data.enemy_profiles.get(enemy_id, {}))


func apply_enemy_profile(enemy: Node, enemy_id: StringName) -> void:
	var profile := get_enemy_profile(enemy_id)
	for key in profile.keys():
		var property_name := StringName(key)
		if _has_property(enemy, property_name):
			enemy.set(property_name, profile[key])
		elif key == "knockback_resistance":
			enemy.set_meta("knockback_resistance", profile[key])


func get_spawn_profile() -> Dictionary:
	return data.spawn_profile.duplicate(true)


func get_encounter_phases() -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	for phase in data.encounter_phases:
		phases.append(Dictionary(phase).duplicate(true))
	return phases


func get_boss_phase_profile(phase: int) -> Dictionary:
	return Dictionary(data.boss_phase_profiles.get(phase, {}))


func get_card_level_profile(profile_id: String) -> Dictionary:
	return Dictionary(data.card_level_profiles.get(profile_id, {}))


func get_budget(key: String, fallback: float) -> float:
	return float(data.performance_budgets.get(key, fallback))


func get_synergies(affinity: StringName) -> Array:
	return Array(data.synergy_profiles.get(affinity, []))


func get_build_validation_profile(
	affinity: StringName
) -> Dictionary:
	return Dictionary(data.build_validation_profiles.get(affinity, {}))


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property["name"]) == property_name:
			return true
	return false
