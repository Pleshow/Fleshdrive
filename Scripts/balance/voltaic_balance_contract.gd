class_name VoltaicBalanceContract
extends RefCounted


const POWER_CURVE_TARGETS := {
	&"level_1": 1.0,
	&"early": 1.4,
	&"mid": 2.0,
	&"late": 3.0,
	&"pre_boss": 4.5,
	&"boss_build": 6.0,
}

const THREAT_COSTS := {
	&"crawler": 1,
	&"spitter": 2,
	&"charger": 3,
	&"elite": 7,
	&"visceral_warden": 14,
}

const PATHS := {
	&"thunder_god": {
		"label": "THUNDER GOD",
		"mechanics": [&"arc_relay", &"conductive_fur", &"forked_arc_node", &"feedback_loop", &"pulse_capacitor", &"singularity_core"],
		"keystones": [&"eye_of_the_storm", &"neural_thunder"],
	},
	&"volt_hound": {
		"label": "VOLT HOUND",
		"mechanics": [&"static_claws", &"charged_paw_pads", &"kinetic_capacitor", &"magnetic_predator", &"phantom_current"],
		"keystones": [&"lightspeed"],
	},
	&"orange_tempest": {
		"label": "ORANGE TEMPEST",
		"mechanics": [&"ball_lightning", &"static_replication", &"orbital_charge"],
		"keystones": [&"star_collapse", &"chain_reactor"],
	},
}


static func classify_upgrade(upgrade: UpgradeData) -> StringName:
	if upgrade == null:
		return &"UNKNOWN"
	if upgrade.keystone or &"keystone" in upgrade.get_effective_synergy_tags():
		return &"KEYSTONE"
	if not upgrade.required_weapons.is_empty():
		return &"SYNERGY"
	if upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON:
		return &"MECHANIC"
	if not upgrade.build_archetype.is_empty():
		return &"MAJOR"
	return &"STAT"


static func archetype_for(upgrade: UpgradeData) -> StringName:
	if upgrade == null:
		return &"unclassified"
	if not upgrade.build_archetype.is_empty():
		return upgrade.build_archetype
	for archetype in PATHS:
		var path := Dictionary(PATHS[archetype])
		if (
			upgrade.upgrade_id in Array(path.get("mechanics", []))
			or upgrade.upgrade_id in Array(path.get("keystones", []))
		):
			return archetype
	return &"universal"


static func target_multiplier(checkpoint_id: StringName) -> float:
	return float(POWER_CURVE_TARGETS.get(checkpoint_id, 1.0))


static func threat_cost(enemy_type: StringName, elite: bool = false) -> int:
	if elite:
		return int(THREAT_COSTS[&"elite"])
	return int(THREAT_COSTS.get(enemy_type, 1))
