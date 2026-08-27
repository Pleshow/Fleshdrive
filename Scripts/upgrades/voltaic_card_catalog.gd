class_name VoltaicCardCatalog
extends RefCounted


const CARD_IDS: Array[StringName] = [
	&"arc_heart", &"arc_spear", &"bone_shard_volley", &"kill_switch_nodes",
	&"overload_vent", &"pulse_capacitor", &"quill_burst", &"shock_ram", &"tail_lash",
	&"forked_arc_node", &"static_reservoir", &"grounding_filaments", &"thunder_gait",
	&"kinetic_capacitor", &"galvanic_tendons", &"linear_inductor", &"polarized_scar",
	&"rail_synapses", &"corona_follicles", &"ionic_marrow", &"storm_plumage",
	&"ball_lightning", &"chain_reactor", &"electric_gravity", &"ionized_membrane",
	&"orbital_charge", &"plasma_expansion", &"plasma_shepherd", &"polarity_shift",
	&"residual_charge", &"star_collapse", &"static_replication",
	&"arc_relay", &"capacitor_organ", &"conductive_fur", &"eye_of_the_storm",
	&"feedback_loop", &"ionized_blood", &"neural_thunder", &"overload_heart",
	&"singularity_core", &"storm_core",
	&"ballistic_nervous_system", &"capacitor_marrow", &"charged_paw_pads",
	&"double_exposure", &"flash_step", &"ionized_spine", &"lightspeed",
	&"magnetic_predator", &"nerve_overclock", &"phantom_current", &"predators_static",
	&"predator_coil", &"purple_heart", &"static_claws", &"voltaic_tendons",
	&"electric_kinetic_expanded_capacitor", &"electric_kinetic_predator_capacitor",
	&"electric_kinetic_compressed_charge",
]

const INACTIVE_CARD_IDS: Array[StringName] = [
	&"ballistic_nervous_system", &"capacitor_marrow", &"capacitor_organ",
	&"double_exposure", &"electric_kinetic_compressed_charge",
	&"electric_kinetic_expanded_capacitor", &"flash_step",
	&"galvanic_tendons", &"grounding_filaments", &"ionized_spine",
	&"kill_switch_nodes", &"nerve_overclock", &"overload_heart",
	&"predator_coil", &"predators_static", &"shock_ram",
	&"static_reservoir", &"thunder_gait", &"voltaic_tendons",
]

const THUNDER_LEFT_PATH: Array[StringName] = [
	&"arc_relay", &"forked_arc_node", &"pulse_capacitor",
	&"storm_core", &"eye_of_the_storm",
]
const THUNDER_RIGHT_PATH: Array[StringName] = [
	&"conductive_fur", &"feedback_loop", &"singularity_core",
	&"ionized_blood", &"neural_thunder",
]
const VOLT_HOUND_PATH: Array[StringName] = [
	&"static_claws", &"charged_paw_pads", &"kinetic_capacitor",
	&"magnetic_predator", &"phantom_current", &"lightspeed",
]


static func apply_to_pool(pool: Array[UpgradeData]) -> void:
	for index in range(pool.size() - 1, -1, -1):
		var upgrade := pool[index]
		if upgrade == null or upgrade.upgrade_id not in CARD_IDS:
			continue
		if upgrade.upgrade_id in INACTIVE_CARD_IDS:
			pool.remove_at(index)
			continue
		var stem := String(upgrade.upgrade_id).to_upper()
		upgrade.display_name = "VOLT_%s_NAME" % stem
		upgrade.description = "VOLT_%s_DESC" % stem


static func is_voltaic_card(upgrade_id: StringName) -> bool:
	return upgrade_id in CARD_IDS


static func progression_allows(
	upgrade_id: StringName,
	upgrade_levels: Dictionary
) -> bool:
	if upgrade_id in INACTIVE_CARD_IDS:
		return false
	if upgrade_id in THUNDER_LEFT_PATH:
		return _path_allows(
			upgrade_id, THUNDER_LEFT_PATH, upgrade_levels, &"arc_heart",
			THUNDER_RIGHT_PATH[0]
		)
	if upgrade_id in THUNDER_RIGHT_PATH:
		return _path_allows(
			upgrade_id, THUNDER_RIGHT_PATH, upgrade_levels, &"arc_heart",
			THUNDER_LEFT_PATH[0]
		)
	if upgrade_id in VOLT_HOUND_PATH:
		# Volt Hound is an independent parallel path. Only the two Thunder God
		# branches exclude one another.
		return _path_allows(
			upgrade_id, VOLT_HOUND_PATH, upgrade_levels, &"", &""
		)
	return true


static func _path_allows(
	upgrade_id: StringName,
	path: Array[StringName],
	upgrade_levels: Dictionary,
	root_requirement: StringName,
	excluded_first_step: StringName
) -> bool:
	var index := path.find(upgrade_id)
	if index < 0:
		return true
	if index == 0:
		if (
			not root_requirement.is_empty()
			and int(upgrade_levels.get(root_requirement, 0)) <= 0
		):
			return false
		return (
			excluded_first_step.is_empty()
			or int(upgrade_levels.get(excluded_first_step, 0)) <= 0
		)
	return int(upgrade_levels.get(path[index - 1], 0)) > 0
