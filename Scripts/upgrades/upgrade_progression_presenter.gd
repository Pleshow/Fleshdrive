class_name UpgradeProgressionPresenter
extends RefCounted


static func describe(
	upgrade: UpgradeData,
	current_level: int,
	balance: Node
) -> Array[String]:
	var next_level := mini(current_level + 1, upgrade.max_level)
	var result := _weapon_changes(upgrade, current_level, next_level, balance)
	result.append_array(_specific_changes(upgrade, current_level, next_level))
	result.append_array(_universal_weapon_changes(
		upgrade, current_level, next_level
	))
	if result.is_empty() and BuildItemCatalog.is_build_item(upgrade.upgrade_id):
		result.append_array(_build_item_changes(upgrade, current_level, next_level))
	if result.is_empty():
		result.append("%s: %s" % [
			_t("UNLOCK") if current_level == 0 else _t("EFFECT"),
			_t(upgrade.description.strip_edges()),
		])
	var limited: Array[String] = []
	for index in range(mini(result.size(), 4)):
		limited.append(result[index])
	return limited


static func organ_slot_key(slot: UpgradeData.OrganSlot) -> String:
	var keys := [
		"NONE", "BRAIN", "MAW", "HEART", "LUNG", "LEGS", "CLAWS", "TAIL",
	]
	return keys[clampi(int(slot), 0, keys.size() - 1)]


static func _weapon_changes(
	upgrade: UpgradeData,
	current_level: int,
	next_level: int,
	balance: Node
) -> Array[String]:
	var result: Array[String] = []
	if balance == null:
		return result
	var profile := Dictionary(balance.call("get_weapon_profile", upgrade.upgrade_id))
	if profile.is_empty():
		return result
	if profile.has("damage"):
		result.append(_stat(
			"DAMAGE",
			float(balance.call(
				"get_weapon_value", upgrade.upgrade_id, "damage",
				maxi(current_level, 1), 0.0
			)),
			float(balance.call(
				"get_weapon_value", upgrade.upgrade_id, "damage",
				next_level, 0.0
			)),
			current_level == 0,
			1
		))
	if float(profile.get("cooldown", 999.0)) < 100.0:
		result.append(_stat(
			"COOLDOWN",
			float(balance.call(
				"get_weapon_cooldown", upgrade.upgrade_id,
				maxi(current_level, 1), 1.0
			)),
			float(balance.call(
				"get_weapon_cooldown", upgrade.upgrade_id, next_level, 1.0
			)),
			current_level == 0,
			2,
			" s"
		))
	return result


static func _specific_changes(
	upgrade: UpgradeData,
	current_level: int,
	next_level: int
) -> Array[String]:
	var result: Array[String] = []
	var unlocking := current_level == 0
	var old_level := maxi(current_level, 1)
	match upgrade.upgrade_id:
		&"arc_heart":
			if unlocking:
				result.append("%s: %s" % [
					_t("UNLOCK"), _t("2-TARGET CHAIN LIGHTNING")
				])
			else:
				result.append(_compound_bonus(
					"CHAIN DAMAGE", 1.12, current_level - 1, next_level - 1
				))
		&"arc_spear":
			result.append(_stat(
				"PIERCE", 1.0 + old_level, 1.0 + next_level,
				unlocking, 0
			))
		&"bone_shard_volley":
			result.append(_stat(
				"MAX PROJECTILES", 5.0 + old_level, 5.0 + next_level,
				unlocking, 0
			))
		&"quill_burst":
			result.append(_stat(
				"TARGETS", 2.0 + old_level, 2.0 + next_level,
				unlocking, 0
			))
		&"tail_lash":
			result.append(_stat(
				"KNOCKBACK",
				175.0 + 20.0 * float(old_level - 1),
				175.0 + 20.0 * float(next_level - 1),
				unlocking, 0
			))
		&"shock_ram":
			result.append(_stat(
				"DAMAGE", 16.0 + 6.0 * float(old_level - 1),
				16.0 + 6.0 * float(next_level - 1), unlocking, 0
			))
			result.append(_stat(
				"RADIUS", 68.0 + 6.0 * float(old_level - 1),
				68.0 + 6.0 * float(next_level - 1), unlocking, 0, " px"
			))
		&"kill_switch_nodes":
			result.append(_stat(
				"KILLS REQUIRED", float(maxi(15 - (old_level - 1), 11)),
				float(maxi(15 - (next_level - 1), 11)), unlocking, 0
			))
			result.append(_stat(
				"DAMAGE", 165.0 + 25.0 * float(old_level - 1),
				165.0 + 25.0 * float(next_level - 1), unlocking, 0, "% ATK"
			))
			result.append(_stat(
				"RADIUS", 260.0 + 25.0 * float(old_level - 1),
				260.0 + 25.0 * float(next_level - 1), unlocking, 0, " px"
			))
		&"pulse_capacitor":
			result.append(_stat(
				"CHAIN RANGE",
				(pow(1.20, float(current_level)) - 1.0) * 100.0,
				(pow(1.20, float(next_level)) - 1.0) * 100.0,
				false, 0, "%"
			))
		&"overload_vent":
			result.append(_stat(
				"COOLDOWN REDUCTION",
				(1.0 - maxf(pow(0.85, float(current_level)), 0.52)) * 100.0,
				(1.0 - maxf(pow(0.85, float(next_level)), 0.52)) * 100.0,
				false, 0, "%"
			))
		&"ball_lightning":
			result.append(_stat(
				"DAMAGE PER TICK", 8.0 + 2.0 * float(old_level - 1),
				8.0 + 2.0 * float(next_level - 1), unlocking, 0
			))
			result.append(_stat(
				"SPAWN INTERVAL",
				maxf(1.4 - 0.08 * float(old_level - 1), 0.72),
				maxf(1.4 - 0.08 * float(next_level - 1), 0.72),
				unlocking, 2, " s"
			))
		&"chain_reactor":
			result.append(_stat(
				"GENERATION PER ORB", 2.0 * current_level,
				2.0 * next_level, false, 0, "%"
			))
		&"ionized_membrane":
			result.append(_stat(
				"ORB LIFETIME", 35.0 * current_level,
				35.0 * next_level, false, 0, "%"
			))
		&"plasma_expansion":
			result.append(_stat(
				"ORB RADIUS", 25.0 * current_level,
				25.0 * next_level, false, 0, "%"
			))
			result.append(_stat(
				"TRAVEL SPEED",
				220.0 / (1.0 + 0.10 * current_level),
				220.0 / (1.0 + 0.10 * next_level),
				false, 0, " px/s"
			))
		&"arc_relay":
			result.append(_stat(
				"CHAIN TARGETS", 2.0 + current_level,
				2.0 + next_level, false, 0
			))
			result.append(_stat(
				"RELAY RANGE", 240.0 + 18.0 * current_level,
				240.0 + 18.0 * next_level, false, 0, " px"
			))
		&"static_claws":
			result.append(_stat(
				"CONTACT DAMAGE",
				45.0 * (1.0 + 0.15 * float(old_level - 1)),
				45.0 * (1.0 + 0.15 * float(next_level - 1)),
				unlocking, 1
			))
			if unlocking:
				result.append(_stat(
					"OVERDRIVE DURATION", 2.0, 2.0,
					true, 2, " s"
				))
		&"conductive_marrow":
			result.append(_compound_bonus(
				"ATTACK DAMAGE", 1.25, current_level, next_level
			))
		&"rapid_synapses":
			result.append(_multiplier_stat(
				"ATTACK INTERVAL", 0.88, current_level, next_level
			))
			result.append(_multiplier_stat(
				"ATTACK DAMAGE", 0.92, current_level, next_level
			))
		&"predator_tendons":
			result.append(_compound_bonus(
				"MOVE SPEED", 1.12, current_level, next_level
			))
			result.append(_multiplier_stat(
				"MAX HEALTH", 0.95, current_level, next_level
			))
		&"biomass_receptors":
			result.append(_compound_bonus(
				"BIOMASS GAIN", 1.20, current_level, next_level
			))
		&"reinforced_carapace":
			result.append(_stat(
				"MAX HEALTH", 15.0 * current_level,
				15.0 * next_level, false, 0
			))
		&"biomass_lure":
			result.append(_stat(
				"PICKUP RANGE", 60.0 * current_level,
				60.0 * next_level, false, 0, " px"
			))
		&"reflex_spurs":
			result.append(_multiplier_stat(
				"DASH COOLDOWN", 0.80, current_level, next_level
			))
		&"shed_skin":
			result.append(_stat(
				"DECOY DURATION",
				1.5 + 0.25 * float(old_level - 1),
				1.5 + 0.25 * float(next_level - 1),
				unlocking, 2, " s"
			))
			result.append(_stat(
				"LURE RADIUS",
				260.0 + 30.0 * float(old_level - 1),
				260.0 + 30.0 * float(next_level - 1),
				unlocking, 0, " px"
			))
			if next_level >= 2:
				result.append(_stat(
					"DISCHARGE DAMAGE",
					0.0 if current_level < 2 else 10.0 + 6.0 * current_level,
					10.0 + 6.0 * next_level,
					false, 0
				))
				result.append(_stat(
					"DISCHARGE RADIUS",
					0.0 if current_level < 2 else 108.0 + 18.0 * float(current_level - 2),
					108.0 + 18.0 * float(next_level - 2),
					false, 0, " px"
				))
		&"scavenger_gland":
			result.append(_stat(
				"BIOMASS DROP CHANCE",
				minf(6.0 * current_level, 30.0),
				minf(6.0 * next_level, 30.0),
				false, 0, "%"
			))
		&"hemo_recycler":
			result.append(_stat(
				"KILLS REQUIRED",
				float(maxi(12 - (old_level - 1), 8)),
				float(maxi(12 - (next_level - 1), 8)),
				unlocking, 0
			))
			result.append(_stat(
				"HEAL AMOUNT",
				6.0 + 2.0 * float(old_level - 1),
				6.0 + 2.0 * float(next_level - 1),
				unlocking, 0
			))
		&"cauterizing_blood":
			result.append(_stat(
				"FIRE KILLS REQUIRED",
				float(maxi(14 - old_level, 9)),
				float(maxi(14 - next_level, 9)),
				unlocking, 0
			))
			result.append(_stat(
				"HEAL AMOUNT", 4.0 + 2.0 * old_level,
				4.0 + 2.0 * next_level, unlocking, 0
			))
		&"flashpoint_nodes":
			result.append(_stat(
				"EXPLOSION DAMAGE", 8.0 + 4.0 * old_level,
				8.0 + 4.0 * next_level, unlocking, 0
			))
			result.append(_stat(
				"EXPLOSION RADIUS",
				86.0 + 10.0 * float(old_level - 1),
				86.0 + 10.0 * float(next_level - 1),
				unlocking, 0, " px"
			))
		&"thermal_lattice":
			result.append(_compound_bonus(
				"BURN DAMAGE", 1.18, current_level, next_level
			))
			result.append(_compound_bonus(
				"BURN DURATION", 1.12, current_level, next_level
			))
		&"mass_amplifier":
			result.append(_compound_bonus(
				"TELEKINETIC DAMAGE", 1.14, current_level, next_level
			))
			result.append(_compound_bonus(
				"TELEKINETIC FORCE", 1.12, current_level, next_level
			))
		&"vector_cortex":
			result.append(_multiplier_stat(
				"WEAPON COOLDOWN", 0.91, current_level, next_level
			))
			result.append(_compound_bonus(
				"TELEKINETIC DAMAGE", 1.08, current_level, next_level
			))
			result.append(_compound_bonus(
				"TELEKINETIC FORCE", 1.08, current_level, next_level
			))
		&"inertial_lattice":
			result.append(_compound_bonus(
				"TELEKINETIC DAMAGE", 1.08, current_level, next_level
			))
		&"orbiting_debris":
			var old_capacity := 1 + int((old_level - 1) / 2.0)
			var new_capacity := 1 + int((next_level - 1) / 2.0)
			if old_capacity != new_capacity or unlocking:
				result.append(_stat(
					"CAPTIVES", old_capacity, new_capacity, unlocking, 0
				))
			result.append(_stat(
				"COLLISION DAMAGE",
				6.0 + 2.2 * float(old_level - 1),
				6.0 + 2.2 * float(next_level - 1),
				unlocking, 1
			))
			result.append(_stat(
				"CAPTURE RANGE",
				330.0 + 35.0 * float(old_level - 1),
				330.0 + 35.0 * float(next_level - 1),
				unlocking, 0, " px"
			))
			result.append(_stat(
				"ORBIT RADIUS",
				92.0 + 7.0 * float(old_level - 1),
				92.0 + 7.0 * float(next_level - 1),
				unlocking, 0, " px"
			))
		&"blazing_stride":
			result.append(_stat(
				"DASH DAMAGE", 8.0 + 4.0 * float(old_level - 1),
				8.0 + 4.0 * float(next_level - 1), unlocking, 0
			))
			result.append(_stat(
				"TRAIL DAMAGE PER TICK", 2.0 + 0.8 * old_level,
				2.0 + 0.8 * next_level, unlocking, 1
			))
			result.append(_stat(
				"TRAIL RADIUS", 68.0 + 5.0 * old_level,
				68.0 + 5.0 * next_level, unlocking, 0, " px"
			))
			result.append(_stat(
				"TRAIL DURATION",
				2.4 + 0.15 * float(old_level - 1),
				2.4 + 0.15 * float(next_level - 1),
				unlocking, 2, " s"
			))
	return result


static func _universal_weapon_changes(
	upgrade: UpgradeData,
	current_level: int,
	next_level: int
) -> Array[String]:
	var base_cooldowns := {
		&"spine_launcher": 1.5, &"ripper_tail": 2.7,
		&"bone_saw": 0.5, &"parasite_maw": 3.2,
		&"blood_needle": 0.72, &"acid_gland": 4.2,
		&"jaw_reflex": 2.4, &"surgical_drone": 1.15,
		&"implosion_sac": 4.8,
	}
	var result: Array[String] = []
	if not base_cooldowns.has(upgrade.upgrade_id):
		return result
	var unlocking := current_level == 0
	var old_level := maxi(current_level, 1)
	match upgrade.upgrade_id:
		&"spine_launcher":
			result.append(_stat(
				"DAMAGE", 32.0 * (1.0 + 0.18 * (old_level - 1)),
				32.0 * (1.0 + 0.18 * (next_level - 1)), unlocking, 1
			))
			result.append(_stat(
				"PROJECTILE SPEED", 620.0 + 40.0 * old_level,
				620.0 + 40.0 * next_level, unlocking, 0, " px/s"
			))
		&"ripper_tail":
			result.append(_stat(
				"DAMAGE", 24.0 + 7.0 * old_level,
				24.0 + 7.0 * next_level, unlocking, 0
			))
			result.append(_stat(
				"RADIUS", 145.0 + 12.0 * old_level,
				145.0 + 12.0 * next_level, unlocking, 0, " px"
			))
		&"bone_saw":
			result.append(_stat(
				"DAMAGE PER TICK", 7.0 + 2.0 * old_level,
				7.0 + 2.0 * next_level, unlocking, 0
			))
			result.append(_stat(
				"ORBIT RADIUS", 55.0 + 6.0 * old_level,
				55.0 + 6.0 * next_level, unlocking, 0, " px"
			))
			if old_level < 4 and next_level >= 4:
				result.append(_stat("BLADES", 1.0, 2.0, false, 0))
		&"parasite_maw":
			result.append(_stat(
				"DAMAGE", 48.0 + 12.0 * old_level,
				48.0 + 12.0 * next_level, unlocking, 0
			))
			result.append(_stat(
				"BIOMASS CHANCE", 18.0 + 3.0 * old_level,
				18.0 + 3.0 * next_level, unlocking, 0, "%"
			))
		&"blood_needle":
			result.append(_stat(
				"DAMAGE", 15.0 + 3.0 * old_level,
				15.0 + 3.0 * next_level, unlocking, 0
			))
		&"acid_gland":
			result.append(_stat(
				"DAMAGE PER TICK", 5.0 + 2.0 * old_level,
				5.0 + 2.0 * next_level, unlocking, 0
			))
			result.append(_stat(
				"RADIUS", 82.0 + 8.0 * old_level,
				82.0 + 8.0 * next_level, unlocking, 0, " px"
			))
			result.append(_stat(
				"POOL DURATION", 3.0 + 0.25 * old_level,
				3.0 + 0.25 * next_level, unlocking, 2, " s"
			))
		&"jaw_reflex":
			result.append(_stat(
				"DAMAGE", 38.0 + 10.0 * old_level,
				38.0 + 10.0 * next_level, unlocking, 0
			))
		&"surgical_drone":
			result.append(_stat(
				"DAMAGE", 12.0 + 4.0 * old_level,
				12.0 + 4.0 * next_level, unlocking, 0
			))
		&"implosion_sac":
			result.append(_stat(
				"DAMAGE", 28.0 + 8.0 * old_level,
				28.0 + 8.0 * next_level, unlocking, 0
			))
	var base_cooldown := float(base_cooldowns[upgrade.upgrade_id])
	result.append(_stat(
		"COOLDOWN",
		maxf(base_cooldown * (1.0 - 0.035 * (old_level - 1)), 0.18),
		maxf(base_cooldown * (1.0 - 0.035 * (next_level - 1)), 0.18),
		unlocking, 2, " s"
	))
	return result


static func _build_item_changes(
	upgrade: UpgradeData,
	current_level: int,
	next_level: int
) -> Array[String]:
	var result: Array[String] = []
	var values := Dictionary(BuildItemCatalog.VALUES.get(upgrade.upgrade_id, {}))
	for raw_key in values.keys():
		var key := String(raw_key)
		if "per_level" not in key and not key.ends_with("_level"):
			continue
		var step := float(values[raw_key])
		var base := 0.0
		var label_key := key
		for prefix in ["damage", "chance", "cap", "pull"]:
			if key.begins_with(prefix + "_per_level") and values.has("base_" + prefix):
				base = float(values["base_" + prefix])
				label_key = prefix
				break
		var percent := absf(step) <= 1.0
		result.append(_stat(
			_build_label(label_key),
			(base + step * current_level) * (100.0 if percent else 1.0),
			(base + step * next_level) * (100.0 if percent else 1.0),
			current_level == 0 and base > 0.0,
			0,
			"%" if percent else ""
		))
		if result.size() >= 3:
			break
	return result


static func _build_label(key: String) -> String:
	var labels := {
		"damage": "DAMAGE",
		"damage_per_level_charge": "DAMAGE PER CHARGE",
		"damage_per_level_stack": "DAMAGE PER STACK",
		"damage_per_level_second": "DAMAGE PER SECOND",
		"move_speed_per_level": "MOVE SPEED",
		"radius_per_level": "RADIUS",
		"range_per_level": "RANGE",
		"speed_range_per_level": "SPEED AND RANGE",
		"width_per_level": "WIDTH",
		"chance_per_level": "CHANCE",
		"cap_per_level": "CAP",
		"duration_per_level": "DURATION",
		"refund_per_level": "COOLDOWN REFUND",
		"refund_per_level_kill": "REFUND PER KILL",
		"heal_per_hit_level": "HEAL PER HIT",
		"pull_per_level": "PULL FORCE",
		"direct_penalty_per_level": "DIRECT DAMAGE PENALTY",
		"contact_reduction_per_level": "CONTACT DAMAGE REDUCTION",
		"secondary_penalty_per_level": "SECONDARY DAMAGE PENALTY",
		"move_penalty_per_level": "MOVE SPEED PENALTY",
		"damage_penalty_per_level": "DAMAGE PENALTY",
	}
	return String(labels.get(
		key, key.replace("_per_level", "").replace("_", " ").to_upper()
	))


static func _compound_bonus(
	label: String,
	multiplier: float,
	current_level: int,
	next_level: int
) -> String:
	return _stat(
		label,
		(pow(multiplier, float(current_level)) - 1.0) * 100.0,
		(pow(multiplier, float(next_level)) - 1.0) * 100.0,
		false, 0, "%"
	)


static func _multiplier_stat(
	label: String,
	multiplier: float,
	current_level: int,
	next_level: int
) -> String:
	return _stat(
		label,
		pow(multiplier, float(current_level)) * 100.0,
		pow(multiplier, float(next_level)) * 100.0,
		false, 0, "%"
	)


static func _stat(
	label_key: String,
	old_value: float,
	new_value: float,
	unlocking: bool,
	decimals: int = 0,
	suffix: String = ""
) -> String:
	var number_format := "%.0f" if decimals <= 0 else ("%%.%df" % decimals)
	var old_text := "--" if unlocking else (number_format % old_value) + suffix
	var new_text := (number_format % new_value) + suffix
	return "%s: %s -> %s" % [_t(label_key), old_text, new_text]


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
