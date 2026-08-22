class_name KodaStatSheet
extends RefCounted


# This ordered data table is the single character-sheet contract. Adding a
# future stat is intentionally a one-line definition plus a value mapping in
# snapshot(); UI code iterates the table and does not need layout changes.
const DEFINITIONS: Array[Dictionary] = [
	{"id": &"max_health", "name": "MAX HEALTH", "base": 100.0, "format": &"number"},
	{"id": &"damage", "name": "DAMAGE", "base": 15.0, "format": &"decimal"},
	{"id": &"attack_speed", "name": "ATTACK SPEED", "base": 1.25, "format": &"rate"},
	{"id": &"move_speed", "name": "MOVE SPEED", "base": 210.0, "format": &"number"},
	{"id": &"armor", "name": "ARMOR", "base": 0.0, "format": &"percent"},
	{"id": &"lifesteal", "name": "LIFESTEAL", "base": 0.0, "format": &"percent"},
	{"id": &"critical_chance", "name": "CRITICAL CHANCE", "base": 0.05, "format": &"percent"},
	{"id": &"critical_damage", "name": "CRITICAL DAMAGE", "base": 1.50, "format": &"percent"},
	{"id": &"ability_haste", "name": "ABILITY HASTE", "base": 0.0, "format": &"percent"},
	{"id": &"pickup_radius", "name": "PICKUP RADIUS", "base": 120.0, "format": &"number"},
]


static func snapshot(player: Koda = null) -> Dictionary:
	var values := {
		&"max_health": 100.0,
		&"damage": 15.0,
		&"attack_speed": 1.25,
		&"move_speed": 210.0,
		&"armor": 0.0,
		&"lifesteal": 0.0,
		&"critical_chance": 0.05,
		&"critical_damage": 1.50,
		&"ability_haste": 0.0,
		&"pickup_radius": 120.0,
	}
	var abilities: Array[Dictionary] = [{
		"id": &"base_arc",
		"name": "BASE ARC",
		"level": 1,
	}]
	if is_instance_valid(player):
		values[&"max_health"] = player.max_health
		values[&"damage"] = player.attack_damage
		values[&"attack_speed"] = 1.0 / maxf(player.attack_interval, 0.01)
		values[&"move_speed"] = player.move_speed
		values[&"armor"] = float(player.get_meta("armor", 0.0))
		values[&"lifesteal"] = float(player.get_meta("lifesteal", 0.0))
		values[&"critical_chance"] = float(player.get_meta("critical_chance", 0.05))
		values[&"critical_damage"] = float(player.get_meta("critical_multiplier", 1.5))
		values[&"ability_haste"] = maxf(1.0 / maxf(player.weapon_cooldown_multiplier, 0.01) - 1.0, 0.0)
		values[&"pickup_radius"] = player.biomass_pickup_radius
		abilities = _collect_abilities(player)
	var rows: Array[Dictionary] = []
	for definition in DEFINITIONS:
		var row := definition.duplicate(true)
		row["value"] = float(values.get(definition["id"], definition["base"]))
		rows.append(row)
	return {"stats": rows, "abilities": abilities}


static func _collect_abilities(player: Koda) -> Array[Dictionary]:
	var base_id := &"base_arc"
	var base_name := "BASE ARC"
	if player.active_fleshdrive_id == FleshdriveCatalog.FIRE:
		base_id = &"base_fireball"
		base_name = "BASE FIREBALL"
	elif player.active_fleshdrive_id == FleshdriveCatalog.TELEKINETIC:
		base_id = &"base_kinetic_shard"
		base_name = "BASE KINETIC SHARD"
	var result: Array[Dictionary] = [{
		"id": base_id, "name": base_name, "level": 1,
	}]
	for upgrade_id in player.upgrade_levels:
		var level := player.get_upgrade_level(StringName(upgrade_id))
		if level <= 0 or StringName(upgrade_id) not in player.EXTRA_WEAPON_IDS:
			continue
		result.append({
			"id": StringName(upgrade_id),
			"name": String(upgrade_id).replace("_", " ").to_upper(),
			"level": level,
		})
	return result


static func format_value(row: Dictionary) -> String:
	var value := float(row.get("value", 0.0))
	match StringName(row.get("format", &"number")):
		&"decimal": return "%.1f" % value
		&"rate": return "%.2f / sec" % value
		&"percent": return "%.0f%%" % (value * 100.0)
	return "%.0f" % value
