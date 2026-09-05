class_name UpgradeRegistry
extends RefCounted


const BUILD_ITEM_DIRECTORY := "res://Resources/Upgrades/BuildItems"
const UNIVERSAL_WEAPON_ICON := preload("res://Assets/ui/weapons/05_bone_shard_volley.png")
const UNIVERSAL_ITEM_ICON := preload("res://Assets/ui/items/01_conductive_marrow.png")

const UNIVERSAL_DEFINITIONS: Array[Dictionary] = [
	{"id": &"spine_launcher", "name": "SPINE LAUNCHER", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 2, "desc": "Launches a 32 damage spine every 1.5 seconds. Upgrades improve piercing, speed and burst patterns."},
	{"id": &"ripper_tail", "name": "RIPPER TAIL", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 2, "desc": "Sweeps a wide arc behind Koda with strong knockback."},
	{"id": &"bone_saw", "name": "BONE SAW", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 3, "desc": "A serrated saw orbits Koda and repeatedly damages enemies on contact."},
	{"id": &"parasite_maw", "name": "PARASITE MAW", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 4, "desc": "Bites the nearest target for heavy damage. Kills can recover biomass."},
	{"id": &"blood_needle", "name": "BLOOD NEEDLE", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 3, "desc": "Rapid needle fire gains damage on consecutive hits against the same target."},
	{"id": &"acid_gland", "name": "ACID GLAND", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 4, "desc": "Spits a persistent corrosive pool that damages and marks enemies."},
	{"id": &"jaw_reflex", "name": "JAW REFLEX", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 3, "desc": "Automatically bites nearby enemies. Deals double damage below 20% health."},
	{"id": &"surgical_drone", "name": "SURGICAL DRONE", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 5, "desc": "An independent drone fires precise shots at distant enemies."},
	{"id": &"implosion_sac", "name": "IMPLOSION SAC", "kind": UpgradeData.UpgradeKind.WEAPON, "min": 5, "desc": "Plants a sac that pulls enemies inward and detonates after 1.2 seconds."},
	{"id": &"porcupine_reflex", "name": "PORCUPINE REFLEX", "desc": "Taking damage triggers an extra defensive Quill Burst."},
	{"id": &"predator_tendons", "name": "PREDATOR TENDONS", "desc": "+12% movement speed, -5% maximum health."},
	{"id": &"reinforced_rib_cage", "name": "REINFORCED RIB CAGE", "desc": "+18 maximum health, -5% movement speed."},
	{"id": &"rapid_synapses", "name": "RAPID SYNAPSES", "desc": "+12% attack speed, -8% attack damage."},
	{"id": &"hypertrophic_muscle", "name": "HYPERTROPHIC MUSCLE", "desc": "+20% damage, -10% attack speed."},
	{"id": &"biomass_magnet", "name": "BIOMASS MAGNET", "desc": "+40% biomass pickup radius."},
	{"id": &"hungry_magnet", "name": "HUNGRY MAGNET", "desc": "Biomass accelerates as it is pulled toward Koda."},
	{"id": &"scavenger_stomach", "name": "SCAVENGER STOMACH", "desc": "Every 15th biomass pickup restores 5 health."},
	{"id": &"reserve_bladder", "name": "RESERVE BLADDER", "desc": "Stores 50% of excess healing, up to 20, and releases it below 30% health."},
	{"id": &"adrenal_gland", "name": "ADRENAL GLAND", "desc": "Below 30% health gain +25% attack speed and +15% movement speed."},
	{"id": &"open_wound", "name": "OPEN WOUND", "desc": "+25% damage, but every incoming hit deals +1 damage."},
	{"id": &"predators_hunger", "name": "PREDATOR'S HUNGER", "desc": "Every 25 kills grants +1% damage for the current run."},
	{"id": &"second_heartbeat", "name": "SECOND HEARTBEAT", "desc": "Every 8th universal weapon activation repeats."},
	{"id": &"mutated_synapse", "name": "MUTATED SYNAPSE", "desc": "Weapon kills have a 2% chance to reset another weapon cooldown."},
	{"id": &"echo_nerve", "name": "ECHO NERVE", "desc": "Every 10th universal weapon activation repeats after 0.4 seconds at 50% power."},
	{"id": &"overgrown_nerve_cluster", "name": "OVERGROWN NERVE CLUSTER", "desc": "+1 projectile where supported, -15% projectile damage."},
	{"id": &"elastic_tendons", "name": "ELASTIC TENDONS", "desc": "+20% area size, -10% attack speed."},
	{"id": &"reactive_hide", "name": "REACTIVE HIDE", "desc": "After taking damage gain +40% movement speed for 1 second."},
	{"id": &"bone_plating", "name": "BONE PLATING", "desc": "Blocks one incoming hit every 8 seconds."},
	{"id": &"pain_converter", "name": "PAIN CONVERTER", "desc": "Taking damage grants temporary attack speed for 3 seconds."},
	{"id": &"impact_sac", "name": "IMPACT SAC", "desc": "Dash ending releases a strong knockback pulse."},
	{"id": &"shed_skin", "name": "SHED SKIN", "max": 3, "desc": "Dash ending leaves an animated Koda decoy. Levels 2-3 add a delayed electric discharge with improved lure duration, radius and damage."},
	{"id": &"predator_reflex", "name": "PREDATOR REFLEX", "desc": "Ending a dash near enemies refunds 50% dash cooldown."},
	{"id": &"experimental_tissue", "name": "EXPERIMENTAL TISSUE", "desc": "Every second level-up grants one free reroll for that offer only. Unused free rerolls never stack."},
	{"id": &"unstable_genome", "name": "UNSTABLE GENOME", "rarity": "rare", "desc": "5% chance for mutation offers to contain a fourth choice."},
	{"id": &"cannibal_enzyme", "name": "CANNIBAL ENZYME", "desc": "Skipping a mutation offer refunds a small amount of biomass."},
	{"id": &"split_nervous_system", "name": "SPLIT NERVOUS SYSTEM", "rarity": "rare", "desc": "-25% damage; weapon activations have a 25% chance to repeat."},
	{"id": &"malignant_growth", "name": "MALIGNANT GROWTH", "rarity": "rare", "desc": "Each future level grants +3% damage but removes 2 maximum health."},
]

const KINETIC_EXTENSION_DEFINITIONS: Array[Dictionary] = [
	{"id": &"electric_kinetic_expanded_capacitor", "name": "EXPANDED CAPACITOR", "rarity": "specialized", "min": 7, "desc": "Kinetic Overdrive lasts 0.4 seconds longer."},
	{"id": &"electric_kinetic_predator_capacitor", "name": "PREDATOR CAPACITOR", "rarity": "rare", "min": 10, "desc": "Kills during Overdrive restore 0.08 seconds, up to 1 second per activation."},
	{"id": &"electric_kinetic_compressed_charge", "name": "COMPRESSED CHARGE", "rarity": "rare", "min": 10, "desc": "Overdrive duration is 30% shorter, but contact damage is 60% higher."},
]


static func append_build_items(pool: Array[UpgradeData]) -> void:
	var known: Dictionary = {}
	for upgrade in pool:
		if upgrade != null:
			known[upgrade.upgrade_id] = true
	var directory := DirAccess.open(BUILD_ITEM_DIRECTORY)
	if directory == null:
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(BUILD_ITEM_DIRECTORY + "/" + file_name) as UpgradeData
		if resource == null or known.has(resource.upgrade_id):
			continue
		pool.append(resource)
		known[resource.upgrade_id] = true


static func append_universal_mutations(pool: Array[UpgradeData]) -> void:
	var known: Dictionary = {}
	for upgrade in pool:
		if upgrade != null:
			known[upgrade.upgrade_id] = true
	_append_universal_mutations(pool, known)
	_append_kinetic_extensions(pool, known)


static func _append_universal_mutations(pool: Array[UpgradeData], known: Dictionary) -> void:
	for definition in UNIVERSAL_DEFINITIONS:
		var upgrade_id: StringName = definition["id"]
		if known.has(upgrade_id):
			continue
		var upgrade := UpgradeData.new()
		upgrade.upgrade_id = upgrade_id
		upgrade.display_name = String(definition.get("name", String(upgrade_id).to_upper()))
		upgrade.description = String(definition.get("desc", ""))
		upgrade.upgrade_kind = int(definition.get("kind", UpgradeData.UpgradeKind.ITEM))
		# Universal entries have no authored card art; leave the illustration empty
		# instead of reusing the obsolete generic icon.
		upgrade.card_texture = null
		upgrade.fleshdrive_affinity = "universal"
		upgrade.rarity = String(definition.get("rarity", "common"))
		upgrade.minimum_player_level = int(definition.get("min", 1))
		upgrade.max_level = int(definition.get(
			"max",
			5 if upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON else 1
		))
		var tags: Array[StringName] = [&"universal"]
		tags.append(&"weapon" if upgrade.upgrade_kind == UpgradeData.UpgradeKind.WEAPON else &"item")
		upgrade.synergy_tags = tags
		pool.append(upgrade)
		known[upgrade_id] = true


static func _append_kinetic_extensions(pool: Array[UpgradeData], known: Dictionary) -> void:
	for definition in KINETIC_EXTENSION_DEFINITIONS:
		var upgrade_id: StringName = definition["id"]
		if known.has(upgrade_id):
			continue
		var upgrade := UpgradeData.new()
		upgrade.upgrade_id = upgrade_id
		upgrade.display_name = String(definition["name"])
		upgrade.description = String(definition["desc"])
		upgrade.card_texture = null
		upgrade.upgrade_kind = UpgradeData.UpgradeKind.ITEM
		upgrade.fleshdrive_affinity = "electric"
		upgrade.rarity = String(definition["rarity"])
		upgrade.minimum_player_level = int(definition["min"])
		upgrade.max_level = 1
		upgrade.build_archetype = &"volt_hound"
		var requirements: Array[StringName] = [&"static_claws"]
		var tags: Array[StringName] = [&"electric", &"volt_hound", &"kinetic_charge", &"overdrive"]
		upgrade.required_weapons = requirements
		upgrade.synergy_tags = tags
		pool.append(upgrade)
		known[upgrade_id] = true
