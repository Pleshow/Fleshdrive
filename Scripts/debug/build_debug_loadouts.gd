class_name BuildDebugLoadouts
extends RefCounted


const LOADOUTS := {
	&"chainstorm": {"affinity": &"electric", "upgrades": [&"arc_spear", &"arc_heart", &"forked_arc_node", &"static_reservoir", &"grounding_filaments"]},
	&"thunder_ram": {"affinity": &"electric", "upgrades": [&"shock_ram", &"thunder_gait", &"kinetic_capacitor", &"galvanic_tendons"]},
	&"wildfire_shepherd": {"affinity": &"fire", "upgrades": [&"inferno_ring", &"spore_ember_sac", &"oxygen_thief", &"smoldering_hide"]},
	&"flashpoint_bomber": {"affinity": &"fire", "upgrades": [&"ashen_eruption", &"combustion_sac", &"rupture_vesicle", &"ash_pressure_chamber", &"chain_igniter"]},
	&"gravity_architect": {"affinity": &"telekinetic", "upgrades": [&"gravity_well", &"event_horizon_membrane", &"compression_cortex", &"tidal_ligaments"]},
	&"repulse_bastion": {"affinity": &"telekinetic", "upgrades": [&"repulse_wave", &"projectile_reversal", &"vector_mantle", &"reactive_cranium", &"mirror_prism"]},
	&"rail_predator": {"affinity": &"electric", "upgrades": [&"arc_spear", &"linear_inductor", &"polarized_scar", &"rail_synapses"]},
	&"quill_tempest": {"affinity": &"electric", "upgrades": [&"quill_burst", &"corona_follicles", &"ionic_marrow", &"storm_plumage"]},
	&"furnace_halo": {"affinity": &"fire", "upgrades": [&"inferno_ring", &"furnace_carapace", &"cautery_valves", &"thermal_pulse_gland"]},
	&"magma_artillery": {"affinity": &"fire", "upgrades": [&"magma_spear", &"obsidian_throat", &"kiln_chamber", &"pressure_crucible"]},
	&"captive_moon": {"affinity": &"telekinetic", "upgrades": [&"orbiting_debris", &"orbit_brood_sac", &"collision_nucleus", &"execution_fold"]},
	&"neural_executioner": {"affinity": &"telekinetic", "upgrades": [&"neural_lance", &"synaptic_rail", &"psychic_parallax", &"thought_echo"]},
}

const KEYSTONES: Array[StringName] = [
	&"forked_arc_node", &"thunder_gait", &"spore_ember_sac",
	&"rupture_vesicle", &"event_horizon_membrane", &"vector_mantle",
	&"linear_inductor", &"corona_follicles", &"furnace_carapace",
	&"obsidian_throat", &"orbit_brood_sac", &"synaptic_rail",
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
