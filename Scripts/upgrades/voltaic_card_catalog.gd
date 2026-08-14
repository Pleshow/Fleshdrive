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


static func apply_to_pool(pool: Array[UpgradeData]) -> void:
	for upgrade in pool:
		if upgrade == null or upgrade.upgrade_id not in CARD_IDS:
			continue
		var stem := String(upgrade.upgrade_id).to_upper()
		upgrade.display_name = "VOLT_%s_NAME" % stem
		upgrade.description = "VOLT_%s_DESC" % stem


static func is_voltaic_card(upgrade_id: StringName) -> bool:
	return upgrade_id in CARD_IDS
