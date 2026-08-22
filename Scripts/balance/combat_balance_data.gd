class_name CombatBalanceData
extends Resource


@export var weapon_profiles: Dictionary = {
	&"quill_burst": {"cooldown": 1.65, "step": -0.10, "minimum": 1.20, "damage": 8.0, "damage_step": 3.0},
	&"tail_lash": {"cooldown": 2.80, "step": -0.16, "minimum": 2.10, "damage": 18.0, "damage_step": 6.0, "knockback": 175.0, "knockback_step": 20.0},
	&"arc_spear": {"cooldown": 2.35, "step": -0.13, "minimum": 1.80, "damage": 22.0, "damage_step": 7.0},
	&"bone_shard_volley": {"cooldown": 2.10, "step": -0.12, "minimum": 1.60, "damage": 12.0, "damage_step": 4.0},
	&"conductive_fur": {"cooldown": 1.15, "step": -0.05, "minimum": 0.82, "damage": 9.0, "damage_step": 2.5},
	&"shock_ram": {"cooldown": 2.20, "step": -0.10, "minimum": 1.55, "damage": 16.0, "damage_step": 6.0},
	&"static_claws": {"cooldown": 2.00, "step": -0.08, "minimum": 1.40, "damage": 18.0, "damage_step": 5.0},
	&"ball_lightning": {"cooldown": 1.40, "step": -0.08, "minimum": 0.72, "damage": 8.0, "damage_step": 2.0},
	&"cinder_volley": {"cooldown": 1.80, "step": -0.10, "minimum": 1.32, "damage": 5.0, "damage_step": 2.0},
	&"inferno_ring": {"cooldown": 3.20, "step": -0.16, "minimum": 2.35, "damage": 7.0, "damage_step": 3.0},
	&"magma_spear": {"cooldown": 2.70, "step": -0.13, "minimum": 2.00, "damage": 18.0, "damage_step": 6.0},
	&"ashen_eruption": {"cooldown": 3.80, "step": -0.18, "minimum": 2.80, "damage": 12.0, "damage_step": 5.0},
	&"kinetic_shard": {"cooldown": 1.45, "step": -0.08, "minimum": 1.05, "damage": 9.0, "damage_step": 3.0, "knockback": 125.0},
	&"gravity_well": {"cooldown": 4.10, "step": -0.20, "minimum": 3.15, "damage": 8.0, "damage_step": 3.0, "knockback": 220.0},
	&"repulse_wave": {"cooldown": 3.00, "step": -0.14, "minimum": 2.35, "damage": 10.0, "damage_step": 3.5, "knockback": 540.0},
	&"orbiting_debris": {"cooldown": 999.0, "step": 0.0, "minimum": 999.0},
	&"neural_lance": {"cooldown": 3.35, "step": -0.15, "minimum": 2.55, "damage": 25.0, "damage_step": 7.0, "knockback": 185.0},
}

@export var kinetic_profiles: Dictionary = {
	&"electric_kinetic_overdrive": {
		"charge_max": 100.0,
		"movement_charge_per_second": 6.0,
		"dash_charge": 20.0,
		"near_miss_charge": 8.0,
		"ready_threshold": 100.0,
		"overdrive_duration": 2.0,
		"contact_damage": 45.0,
		"movement_multiplier": 1.15,
		"boss_contact_damage_multiplier": 0.50,
		"contact_radius": 48.0,
		"expanded_capacitor_duration": 0.40,
		"predator_capacitor_kill_extension": 0.08,
		"predator_capacitor_extension_cap": 1.0,
		"compressed_charge_duration_multiplier": 0.70,
		"compressed_charge_damage_multiplier": 1.60,
	},
}

@export var enemy_profiles: Dictionary = {
	&"crawler": {"max_health": 30.0, "move_speed": 65.0, "contact_damage": 10.0, "knockback_resistance": 0.0},
	&"spitter": {"max_health": 54.0, "move_speed": 78.0, "projectile_speed": 150, "knockback_resistance": 0.05},
	&"charger": {"max_health": 180.0, "move_speed": 88.0, "charge_damage": 22.0, "knockback_resistance": 0.28},
	&"visceral_warden": {"max_health": 1500.0, "knockback_resistance": 1.0, "phase_two_threshold": 0.5},
}

@export var spawn_profile: Dictionary = {
	"arena_bounds": Rect2(96.0, 176.0, 2368.0, 1110.0),

	# Faster continuous spawning
	"spawn_interval": 0.55,
	"minimum_spawn_interval": 0.20,

	# Higher population ceiling
	"maximum_enemies": 45,
	"maximum_enemies_end": 100,

	"rush_enemy_budget_bonus": 42,

	# Enemies enter combat sooner
	"minimum_player_distance": 450.0,

	"spawn_clearance_radius": 40.0,
	"occupied_clearance_radius": 52.0,

	"maximum_spitter_ratio": 0.24,
	"maximum_charger_ratio": 0.16,

	"threat_costs": {
		"crawler": 1.00,
		"spitter": 2.00,
		"charger": 3.00,
		"elite": 7.00,
	},
}

@export var encounter_phases: Array[Dictionary] = [
	{
		"id": "awakening",
		"title": "AWAKENING",
		"start": 0.0,
		"end": 75.0,
		"threat_budget": 55.0,
		"spawn_rate": 0.92,
		"profiles": ["swarm", "mixed"],
		"elite_cap": 0.0,
		"spitter_cap": 0.0,
		"charger_cap": 0.0,
	},
	{
		"id": "adaptation",
		"title": "ADAPTATION",
		"start": 75.0,
		"end": 240.0,
		"threat_budget": 80.0,
		"spawn_rate": 0.82,
		"profiles": ["mixed", "crossfire"],
		"elite_cap": 0.10,
		"spitter_cap": 0.22,
		"charger_cap": 0.08,
	},
	{
		"id": "build_check",
		"title": "SYSTEM STRESS",
		"start": 240.0,
		"end": 360.0,
		"threat_budget": 110.0,
		"spawn_rate": 0.72,
		"profiles": ["swarm", "assault", "mixed"],
		"elite_cap": 0.13,
		"spitter_cap": 0.24,
		"charger_cap": 0.15,
	},
	{
		"id": "compound_pressure",
		"title": "COMPOUND PRESSURE",
		"start": 360.0,
		"end": 540.0,
		"threat_budget": 145.0,
		"spawn_rate": 0.64,
		"profiles": ["crossfire", "assault", "mixed"],
		"elite_cap": 0.17,
		"spitter_cap": 0.26,
		"charger_cap": 0.18,
	},
	{
		"id": "containment_failure",
		"title": "CONTAINMENT FAILURE",
		"start": 540.0,
		"end": 660.0,
		"threat_budget": 180.0,
		"spawn_rate": 0.55,
		"profiles": ["assault", "crossfire", "mixed"],
		"elite_cap": 0.20,
		"spitter_cap": 0.26,
		"charger_cap": 0.20,
	},
	{
		"id": "warden_protocol",
		"title": "WARDEN PROTOCOL",
		"start": 660.0,
		"end": 720.0,
		"threat_budget": 0.0,
		"spawn_rate": 2.0,
		"profiles": ["mixed"],
		"elite_cap": 0.0,
		"spitter_cap": 0.0,
		"charger_cap": 0.0,
	},
]

@export var boss_phase_profiles: Dictionary = {
	1: {
		"move_speed": 92.0,
		"attack_cooldown": 1.65,
		"projectile_count": 5,
	},
	2: {
		"move_speed": 122.0,
		"attack_cooldown": 1.05,
		"projectile_count": 7,
	},
}

@export var card_level_profiles: Dictionary = {
	"weapon_damage": {
		"common_step": 0.12,
		"rare_step": 0.20,
		"maximum_level": 5,
	},
	"weapon_cooldown": {
		"common_step": -0.06,
		"rare_step": -0.10,
		"minimum_multiplier": 0.52,
	},
	"knockback": {
		"common_step": 0.15,
		"rare_step": 0.25,
		"maximum_multiplier": 2.5,
	},
}

@export var performance_budgets: Dictionary = {
	"enemies": 110,
	"enemy_projectiles": 84,
	"player_projectiles": 72,
	"vfx": 72,
	"runtime_lights": 20,
	"damage_numbers": 28,
	"pooled_per_scene": 48,
	"target_frame_ms": 16.67,
	"degrade_frame_ms": 25.0,
}

@export var synergy_profiles: Dictionary = {
	&"electric": [&"chain", &"burst", &"mobility"],
	&"fire": [&"burn", &"area", &"death_explosion"],
	&"telekinetic": [&"gravity", &"force", &"piercing"],
}

@export var build_validation_profiles: Dictionary = {
	&"chainstorm": {
		"simulation_effectiveness": 1.30,
		"expected_style": "shock_network_and_branching_chains",
	},
	&"thunder_ram": {
		"simulation_effectiveness": 1.35,
		"expected_style": "kinetic_charge_and_contact_burst",
	},
	&"orange_tempest": {
		"simulation_effectiveness": 1.40,
		"expected_style": "persistent_orbs_and_area_melt",
	},
}
