class_name BuildDebugLoadouts
extends RefCounted


const LOADOUTS := {
	&"chainstorm": {"affinity": &"electric", "upgrades": [&"arc_heart", &"arc_relay", &"forked_arc_node", &"pulse_capacitor", &"storm_core", &"eye_of_the_storm"]},
	&"thunder_ram": {"affinity": &"electric", "upgrades": [&"static_claws", &"charged_paw_pads", &"kinetic_capacitor", &"magnetic_predator", &"phantom_current", &"lightspeed"]},
	&"orange_tempest": {"affinity": &"electric", "upgrades": [&"ball_lightning", &"ionized_membrane", &"plasma_expansion", &"static_replication", &"orbital_charge", &"chain_reactor", &"star_collapse"]},
}

const KEYSTONES: Array[StringName] = [
	&"overload_heart", &"lightspeed", &"star_collapse",
]


static func apply_to(player: Koda, build_id: StringName, item_level: int = 5) -> bool:
	if player == null or not LOADOUTS.has(build_id):
		return false
	var definition := Dictionary(LOADOUTS[build_id])
	for item_id in BuildItemCatalog.ITEM_IDS:
		player.upgrade_levels.erase(item_id)
	for loadout_definition in LOADOUTS.values():
		for previous_upgrade in Array(Dictionary(loadout_definition)["upgrades"]):
			player.upgrade_levels.erase(StringName(previous_upgrade))
	player.configure_fleshdrive(StringName(definition["affinity"]), 5)
	for upgrade_id in Array(definition["upgrades"]):
		player.upgrade_levels[StringName(upgrade_id)] = 1 if StringName(upgrade_id) in KEYSTONES else item_level
	player.upgrade_levels_changed.emit(player.upgrade_levels.duplicate())
	return true
