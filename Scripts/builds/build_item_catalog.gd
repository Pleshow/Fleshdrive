class_name BuildItemCatalog
extends RefCounted


const BUILD_IDS: Array[StringName] = [
	&"chainstorm", &"thunder_ram", &"orange_tempest",
]

const ITEM_IDS: Array[StringName] = [
	&"forked_arc_node", &"static_reservoir", &"grounding_filaments",
	&"thunder_gait", &"kinetic_capacitor", &"galvanic_tendons",
	&"spore_ember_sac", &"oxygen_thief", &"smoldering_hide",
	&"rupture_vesicle", &"ash_pressure_chamber", &"chain_igniter",
	&"event_horizon_membrane", &"compression_cortex", &"tidal_ligaments",
	&"vector_mantle", &"reactive_cranium", &"mirror_prism",
	&"linear_inductor", &"polarized_scar", &"rail_synapses",
	&"corona_follicles", &"ionic_marrow", &"storm_plumage",
	&"furnace_carapace", &"cautery_valves", &"thermal_pulse_gland",
	&"obsidian_throat", &"kiln_chamber", &"pressure_crucible",
	&"orbit_brood_sac", &"collision_nucleus", &"execution_fold",
	&"synaptic_rail", &"psychic_parallax", &"thought_echo",
]

const VALUES := {
	&"forked_arc_node": {"fork_chance": 0.45, "fork_damage": 0.45, "targets": 2.0, "generations": 1.0},
	&"static_reservoir": {"chain_hits": 10.0, "radius": 180.0, "base_damage": 0.70, "damage_per_level": 0.15},
	&"grounding_filaments": {"duration": 2.0, "damage_per_level": 0.07, "range_per_level": 12.0},
	&"thunder_gait": {"minimum_targets": 2.0, "cooldown_refund": 0.45, "aftershock_damage": 0.70},
	&"kinetic_capacitor": {"distance": 280.0, "max_charges": 3.0, "damage_per_level_charge": 0.07},
	&"galvanic_tendons": {"move_speed_per_level": 0.04, "radius_per_level": 0.07, "secondary_penalty_per_level": 0.03},
	&"spore_ember_sac": {"required_stacks": 5.0, "interval": 0.75, "range": 150.0, "max_per_second": 2.0},
	&"oxygen_thief": {"range": 280.0, "tick_rate_per_level_enemy": 0.006, "cap_per_level": 0.06},
	&"smoldering_hide": {"duration_per_level": 0.12, "direct_penalty_per_level": 0.03, "contact_reduction_per_level": 0.02},
	&"rupture_vesicle": {"damage_per_stack": 0.35},
	&"ash_pressure_chamber": {"radius_per_level": 0.08, "damage_per_level": 0.06},
	&"chain_igniter": {"base_chance": 0.12, "chance_per_level": 0.04, "secondary_damage": 0.60, "generations": 3.0},
	&"event_horizon_membrane": {"radius": 0.45, "duration": 1.5, "cooldown": 0.30, "initial_damage_penalty": 0.25},
	&"compression_cortex": {"damage_per_level_second": 0.03, "cap_per_level": 0.12},
	&"tidal_ligaments": {"refund_per_level_kill": 0.06, "base_cap": 0.60, "cap_per_level": 0.12},
	&"vector_mantle": {"duration": 1.2, "radius": 160.0, "cooldown": 0.25},
	&"reactive_cranium": {"base_chance": 0.15, "chance_per_level": 0.05, "damage": 0.45, "internal_cooldown": 3.0},
	&"mirror_prism": {"copies": 2.0, "base_damage": 0.45, "damage_per_level": 0.06, "max_per_second": 6.0},
	&"linear_inductor": {"damage": 0.65, "range": 0.35, "cooldown": 0.25, "width": -0.35},
	&"polarized_scar": {"duration": 2.5, "damage_per_level": 0.08},
	&"rail_synapses": {"speed_range_per_level": 0.12, "width_per_level": -0.06, "minimum_hits": 3.0, "refund_per_level": 0.05},
	&"corona_follicles": {"splits": 2.0, "damage": 0.35, "max_splits": 8.0},
	&"ionic_marrow": {"projectiles_at_levels": 3.0, "damage_penalty_per_level": 0.04},
	&"storm_plumage": {"required_impacts": 6.0, "radius": 110.0, "base_damage": 0.35, "damage_per_level": 0.08},
	&"furnace_carapace": {"minimum_burning": 3.0, "range": 190.0, "damage_reduction": 0.22, "tick_rate": 0.20, "move_penalty": 0.10},
	&"cautery_valves": {"heal_per_hit_level": 0.08, "base_cap": 0.8, "cap_per_level": 0.2},
	&"thermal_pulse_gland": {"required_ticks": 4.0, "base_pull": 35.0, "pull_per_level": 8.0, "burn_stacks": 1.0},
	&"obsidian_throat": {"cooldown": 0.35, "damage": 0.90, "lane_duration": 3.0, "lane_damage": 0.22},
	&"kiln_chamber": {"range_per_level": 0.10, "damage_per_level": 0.07, "move_penalty_per_level": 0.02},
	&"pressure_crucible": {"interval": 1.5, "max_stacks": 3.0, "damage_per_level_stack": 0.08},
	&"orbit_brood_sac": {"capacity": 2.0, "radius": 0.25, "cooldown": 2.0},
	&"collision_nucleus": {"damage_per_level": 0.16, "duration_penalty_per_level": 0.04},
	&"execution_fold": {"threshold": 0.20, "radius": 130.0, "base_damage": 0.70, "damage_per_level": 0.20},
	&"synaptic_rail": {"width": -0.30, "cooldown": 0.35, "damage": 1.0, "force": 0.50},
	&"psychic_parallax": {"distance_step": 220.0, "damage_per_level_step": 0.05, "cap_per_level": 0.15},
	&"thought_echo": {"minimum_hits": 3.0, "delay": 0.45, "base_damage": 0.25, "damage_per_level": 0.08},
}


static func is_build_item(upgrade_id: StringName) -> bool:
	return upgrade_id in ITEM_IDS


static func value(upgrade_id: StringName, key: String, fallback: float = 0.0) -> float:
	return float(Dictionary(VALUES.get(upgrade_id, {})).get(key, fallback))
