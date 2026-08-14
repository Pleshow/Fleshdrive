class_name FleshdriveCatalog
extends RefCounted


const ELECTRIC: StringName = &"electric"
const FIRE: StringName = &"fire"
const TELEKINETIC: StringName = &"telekinetic"
const MAX_CORE_LEVEL: int = 5

const DEFINITIONS := {
	ELECTRIC: {
		"name": "VOLTAIC HEART",
		"short_name": "ELECTRIC",
		"style": "BURST / MOBILITY / CHAIN LIGHTNING",
		"icon": "res://Assets/ui/fleshdrives/electric_core.png",
		"accent": Color(0.16, 0.82, 1.0, 1.0),
		"operation": (
			"Build a self-sustaining electrical network through Shock, "
			+ "branching chains, Capacitor discharges and THUNDERSTATE."
		),
		"build": (
			"THUNDER GOD / SHOCK NETWORK / RECURSIVE DISCHARGE\n"
			+ "Synergies: CONDUCTIVE FUR, CAPACITOR ORGAN, "
			+ "SINGULARITY CORE"
		),
	},
	FIRE: {
		"name": "PYRE HEART",
		"short_name": "FIRE",
		"style": "BURN / AREA DENIAL / ATTRITION",
		"icon": "res://Assets/ui/fleshdrives/fire_core.png",
		"accent": Color(1.0, 0.28, 0.08, 1.0),
		"operation": (
			"Damage over time, area denial and cascading explosions. "
			+ "Excels at controlling dense hordes."
		),
		"build": (
			"BURN STACKS / FIRE ZONES / DEATH EXPLOSIONS\n"
			+ "Synergies: COMBUSTION SAC, THERMAL LATTICE, "
			+ "FLASHPOINT NODES"
		),
	},
	TELEKINETIC: {
		"name": "NOETIC HEART",
		"short_name": "NOETIC",
		"style": "CONTROL / POSITIONING / REVERSAL",
		"icon": "res://Assets/ui/fleshdrives/telekinetic_core.png",
		"accent": Color(0.72, 0.42, 1.0, 1.0),
		"operation": (
			"Battlefield control, forced positioning and projectile "
			+ "manipulation. Excels at shaping dense hordes."
		),
		"build": (
			"GRAVITY CONTROL / KNOCKBACK / PIERCING\n"
			+ "Synergies: GRAVITY WELL, KINETIC CAPTIVITY, "
			+ "PROJECTILE REVERSAL"
		),
	},
}


static func get_definition(fleshdrive_id: StringName) -> Dictionary:
	return DEFINITIONS.get(fleshdrive_id, DEFINITIONS[ELECTRIC])


static func get_display_name(fleshdrive_id: StringName) -> String:
	return String(get_definition(fleshdrive_id).get("name", "UNKNOWN CORE"))


static func get_icon_path(fleshdrive_id: StringName) -> String:
	return String(get_definition(fleshdrive_id).get("icon", ""))


static func get_affinity(fleshdrive_id: StringName) -> String:
	return String(fleshdrive_id)
