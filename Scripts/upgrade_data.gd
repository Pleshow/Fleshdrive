class_name UpgradeData
extends Resource


enum UpgradeKind {
	ITEM,
	ORGAN,
	WEAPON
}


enum OrganSlot {
	NONE,
	BRAIN,
	MAW,
	HEART,
	LUNG,
	LEGS,
	CLAWS,
	TAIL
}


@export var upgrade_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var card_texture: Texture2D
@export var upgrade_kind: UpgradeKind = UpgradeKind.ITEM
@export var organ_slot: OrganSlot = OrganSlot.NONE
@export_enum("universal", "electric", "fire", "telekinetic")
var fleshdrive_affinity: String = "universal"
@export var synergy_tags: Array[StringName] = []
@export_enum("common", "specialized", "rare")
var rarity: String = "common"
@export_range(1, 10) var max_level: int = 5
@export_range(1, 30) var minimum_player_level: int = 1
@export var build_archetype: StringName = &""
@export var keystone: bool = false
@export var required_weapons: Array[StringName] = []
@export_range(0.01, 10.0, 0.01) var offer_weight: float = 1.0
@export var excluded_upgrades: Array[StringName] = []
@export var effect_values: Dictionary = {}


func get_effective_synergy_tags() -> Array[StringName]:
	var tags := synergy_tags.duplicate()
	var affinity_tag := StringName(fleshdrive_affinity)
	if not affinity_tag.is_empty() and affinity_tag not in tags:
		tags.append(affinity_tag)
	var kind_tag := StringName(
		["item", "organ", "weapon"][int(upgrade_kind)]
	)
	if kind_tag not in tags:
		tags.append(kind_tag)
	return tags


func prerequisites_met(upgrade_levels: Dictionary) -> bool:
	for excluded_id in excluded_upgrades:
		if int(upgrade_levels.get(excluded_id, 0)) > 0:
			return false
	if required_weapons.is_empty():
		return true
	for weapon_id in required_weapons:
		if int(upgrade_levels.get(weapon_id, 0)) > 0:
			return true
	return false
