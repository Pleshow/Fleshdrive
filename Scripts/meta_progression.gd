extends Node


signal gems_changed(total_gems: int)
signal upgrade_changed(upgrade_id: StringName, level: int)
signal statistics_changed(statistics: Dictionary)
signal fleshdrive_changed(fleshdrive_id: StringName, core_level: int)

const DEFAULT_SAVE_PATH := "user://fleshdrive_meta_progression.cfg"
const SAVE_VERSION := 3
const SYSTEM_SECTION := "system"
const SAVE_SECTION := "meta"
const UPGRADE_SECTION := "upgrades"
const STATISTICS_SECTION := "statistics"
const FLESHDRIVE_SECTION := "fleshdrives"
const UPGRADE_DEFINITIONS := {
	&"vitality": {
		"title": "HARDENED HEART",
		"description": "+5 starting maximum health per level.",
		"max_level": 5,
		"base_cost": 2,
		"cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_vitality.png",
		"position": Vector2(780, 450),
		"requires": &"",
	},
	&"power": {
		"title": "PREDATOR CORE",
		"description": "+1 starting attack damage per level.",
		"max_level": 5,
		"base_cost": 3,
		"cost_step": 3,
		"icon": "res://Assets/ui/meta/skill_power.png",
		"position": Vector2(500, 450),
		"requires": &"",
	},
	&"mobility": {
		"title": "QUICKENED TENDONS",
		"description": "+4 starting movement speed per level.",
		"max_level": 5,
		"base_cost": 2,
		"cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_mobility.png",
		"position": Vector2(1060, 450),
		"requires": &"",
	},
	&"reflex": {
		"title": "RAPID SYNAPSES",
		"description": "3% faster starting attack rate per level.",
		"max_level": 5, "base_cost": 3, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_4.png",
		"position": Vector2(300, 220), "requires": &"power",
	},
	&"harvester": {
		"title": "BIOMASS RECEPTORS",
		"description": "+5% biomass gained per level.",
		"max_level": 5, "base_cost": 2, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_5.png",
		"position": Vector2(500, 150), "requires": &"power",
	},
	&"magnetism": {
		"title": "MAGNETIC TISSUE",
		"description": "+10 biomass pickup range per level.",
		"max_level": 5, "base_cost": 2, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_6.png",
		"position": Vector2(690, 100), "requires": &"vitality",
	},
	&"reach": {
		"title": "PREDATORY REACH",
		"description": "+8 base attack range per level.",
		"max_level": 5, "base_cost": 3, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_7.png",
		"position": Vector2(870, 100), "requires": &"vitality",
	},
	&"conduction": {
		"title": "CONDUCTIVE NERVES",
		"description": "+4% chain damage per level.",
		"max_level": 5, "base_cost": 3, "cost_step": 3,
		"icon": "res://Assets/ui/meta/skill_8.png",
		"position": Vector2(1060, 150), "requires": &"mobility",
	},
	&"dash_recovery": {
		"title": "DASH METABOLISM",
		"description": "4% shorter dash cooldown per level.",
		"max_level": 5, "base_cost": 2, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_9.png",
		"position": Vector2(1260, 220), "requires": &"mobility",
	},
	&"weapon_metabolism": {
		"title": "WEAPON METABOLISM",
		"description": "3% faster secondary weapons per level.",
		"max_level": 5, "base_cost": 4, "cost_step": 3,
		"icon": "res://Assets/ui/meta/skill_10.png",
		"position": Vector2(300, 690), "requires": &"power",
	},
	&"early_growth": {
		"title": "EARLY GROWTH",
		"description": "2% less biomass needed for level 2 per level.",
		"max_level": 5, "base_cost": 2, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_11.png",
		"position": Vector2(580, 760), "requires": &"vitality",
	},
	&"targeting": {
		"title": "HUNTER SENSE",
		"description": "+8 manual and semi-auto targeting radius per level.",
		"max_level": 5, "base_cost": 3, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_12.png",
		"position": Vector2(980, 760), "requires": &"mobility",
	},
	&"nerve_drive": {
		"title": "NERVE DRIVE",
		"description": "+60 movement acceleration per level.",
		"max_level": 5, "base_cost": 2, "cost_step": 2,
		"icon": "res://Assets/ui/meta/skill_13.png",
		"position": Vector2(1260, 690), "requires": &"mobility",
	},
}

var save_path: String = DEFAULT_SAVE_PATH
var red_gems: int = 0
# Test harnesses can disable persistence while still exercising the exact
# transaction and signal path used by the level-up UI.
var persist_blood_memory_spending: bool = true
var upgrade_levels: Dictionary = {}
var instance_number: int = 1
var total_runs: int = 0
var total_deaths: int = 0
var boss_victories: int = 0
var best_run_time: float = 0.0
var total_kills: int = 0
var open_flesh_tree_on_menu: bool = false
var unlocked_fleshdrive_blueprints: Dictionary = {
	FleshdriveCatalog.ELECTRIC: true,
	FleshdriveCatalog.FIRE: true,
	FleshdriveCatalog.TELEKINETIC: false,
}
var fleshdrive_core_levels: Dictionary = {
	FleshdriveCatalog.ELECTRIC: 1,
	FleshdriveCatalog.FIRE: 1,
	FleshdriveCatalog.TELEKINETIC: 0,
}
var last_blueprint_unlock: StringName = &""
var pending_blueprint_notice: StringName = &""
var fleshdrive_run_metrics: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_progression()


func add_gems(amount: int) -> void:
	if amount <= 0:
		return
	red_gems += amount
	_save_progression()
	gems_changed.emit(red_gems)


func get_blood_memory() -> int:
	return red_gems


func spend_blood_memory(amount: int) -> bool:
	if amount <= 0:
		return true
	if red_gems < amount:
		return false
	red_gems -= amount
	if persist_blood_memory_spending:
		_save_progression()
	gems_changed.emit(red_gems)
	return true


func get_upgrade_level(upgrade_id: StringName) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_upgrade_cost(upgrade_id: StringName) -> int:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(
		upgrade_id,
		{}
	)
	if definition.is_empty():
		return 0
	var level := get_upgrade_level(upgrade_id)
	return int(definition.base_cost) + level * int(definition.cost_step)


func can_purchase_upgrade(upgrade_id: StringName) -> bool:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(
		upgrade_id,
		{}
	)
	if definition.is_empty():
		return false
	var level := get_upgrade_level(upgrade_id)
	return (
		level < int(definition.max_level)
		and is_upgrade_unlocked(upgrade_id)
		and red_gems >= get_upgrade_cost(upgrade_id)
	)


func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	var definition: Dictionary = UPGRADE_DEFINITIONS.get(upgrade_id, {})
	if definition.is_empty():
		return false
	var required_id: StringName = definition.get("requires", &"")
	return required_id.is_empty() or get_upgrade_level(required_id) > 0


func purchase_upgrade(upgrade_id: StringName) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
	var cost := get_upgrade_cost(upgrade_id)
	var new_level := get_upgrade_level(upgrade_id) + 1
	red_gems -= cost
	upgrade_levels[upgrade_id] = new_level
	_save_progression()
	gems_changed.emit(red_gems)
	upgrade_changed.emit(upgrade_id, new_level)
	return true


func apply_to_player(player: Node) -> void:
	player.max_health += 5.0 * get_upgrade_level(&"vitality")
	player.attack_damage += 1.0 * get_upgrade_level(&"power")
	player.move_speed += 4.0 * get_upgrade_level(&"mobility")
	player.attack_interval *= pow(0.97, get_upgrade_level(&"reflex"))
	player.biomass_gain_multiplier *= (
		1.0 + 0.05 * get_upgrade_level(&"harvester")
	)
	player.biomass_pickup_radius += 10.0 * get_upgrade_level(&"magnetism")
	player.attack_range += 8.0 * get_upgrade_level(&"reach")
	player.chain_damage_multiplier += 0.04 * get_upgrade_level(&"conduction")
	player.dash_cooldown *= pow(
		0.96,
		get_upgrade_level(&"dash_recovery")
	)
	player.weapon_cooldown_multiplier *= pow(
		0.97,
		get_upgrade_level(&"weapon_metabolism")
	)
	player.starting_biomass_required *= pow(
		0.98,
		get_upgrade_level(&"early_growth")
	)
	var targeting_bonus := 8.0 * get_upgrade_level(&"targeting")
	player.manual_target_radius += targeting_bonus
	player.semi_auto_target_radius += targeting_bonus
	player.acceleration += 60.0 * get_upgrade_level(&"nerve_drive")


func respec_upgrades() -> int:
	var transaction_snapshot := _capture_transaction_state()
	var refunded_gems := 0
	for upgrade_id in UPGRADE_DEFINITIONS:
		var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
		var level := get_upgrade_level(upgrade_id)
		for purchased_level in range(level):
			refunded_gems += (
				int(definition.base_cost)
				+ purchased_level * int(definition.cost_step)
			)
		upgrade_levels[upgrade_id] = 0
	red_gems += refunded_gems
	if not _save_progression():
		_restore_transaction_state(transaction_snapshot)
		return 0
	gems_changed.emit(red_gems)
	for upgrade_id in UPGRADE_DEFINITIONS:
		upgrade_changed.emit(upgrade_id, 0)
	return refunded_gems


func reset_all_progress() -> void:
	var transaction_snapshot := _capture_transaction_state()
	red_gems = 0
	upgrade_levels.clear()
	instance_number = 1
	total_runs = 0
	total_deaths = 0
	boss_victories = 0
	best_run_time = 0.0
	total_kills = 0
	fleshdrive_run_metrics.clear()
	open_flesh_tree_on_menu = false
	unlocked_fleshdrive_blueprints = {
		FleshdriveCatalog.ELECTRIC: true,
		FleshdriveCatalog.FIRE: true,
		FleshdriveCatalog.TELEKINETIC: false,
	}
	fleshdrive_core_levels = {
		FleshdriveCatalog.ELECTRIC: 1,
		FleshdriveCatalog.FIRE: 1,
		FleshdriveCatalog.TELEKINETIC: 0,
	}
	last_blueprint_unlock = &""
	pending_blueprint_notice = &""
	if not _save_progression():
		_restore_transaction_state(transaction_snapshot)
		return
	gems_changed.emit(red_gems)
	for upgrade_id in UPGRADE_DEFINITIONS:
		upgrade_changed.emit(upgrade_id, 0)
	for fleshdrive_id in fleshdrive_core_levels:
		fleshdrive_changed.emit(
			fleshdrive_id,
			get_fleshdrive_level(fleshdrive_id)
		)
	statistics_changed.emit(get_statistics())


func record_run_result(
	victory: bool,
	run_time: float,
	kills: int,
	active_fleshdrive_id: StringName = &""
) -> Dictionary:
	total_runs += 1
	total_kills += maxi(kills, 0)
	best_run_time = maxf(best_run_time, maxf(run_time, 0.0))
	if victory:
		boss_victories += 1
		if not is_fleshdrive_unlocked(FleshdriveCatalog.TELEKINETIC):
			unlock_fleshdrive_blueprint(
				FleshdriveCatalog.TELEKINETIC,
				false
			)
			last_blueprint_unlock = FleshdriveCatalog.TELEKINETIC
		if not active_fleshdrive_id.is_empty():
			award_fleshdrive_core(active_fleshdrive_id, false)
	else:
		total_deaths += 1
		instance_number += 1
	_record_fleshdrive_metrics(
		active_fleshdrive_id,
		victory,
		run_time
	)
	_save_progression()
	var statistics := get_statistics()
	statistics["blueprint_unlocked"] = last_blueprint_unlock
	statistics["fleshdrive_leveled"] = (
		active_fleshdrive_id if victory else &""
	)
	statistics["fleshdrive_level"] = (
		get_fleshdrive_level(active_fleshdrive_id)
		if victory and not active_fleshdrive_id.is_empty()
		else 0
	)
	if not last_blueprint_unlock.is_empty():
		statistics["reward_message"] = (
			"BLUEPRINT ACQUIRED: %s"
			% FleshdriveCatalog.get_display_name(last_blueprint_unlock)
		)
		last_blueprint_unlock = &""
	statistics_changed.emit(statistics)
	return statistics


func get_fleshdrive_level(fleshdrive_id: StringName) -> int:
	return clampi(
		int(fleshdrive_core_levels.get(fleshdrive_id, 0)),
		0,
		FleshdriveCatalog.MAX_CORE_LEVEL
	)


func is_fleshdrive_unlocked(fleshdrive_id: StringName) -> bool:
	return bool(unlocked_fleshdrive_blueprints.get(fleshdrive_id, false))


func get_unlocked_fleshdrives() -> Array[StringName]:
	var result: Array[StringName] = []
	for fleshdrive_id in FleshdriveCatalog.DEFINITIONS:
		if is_fleshdrive_unlocked(fleshdrive_id):
			result.append(fleshdrive_id)
	return result


func unlock_fleshdrive_blueprint(
	fleshdrive_id: StringName,
	save_immediately: bool = true
) -> bool:
	if not FleshdriveCatalog.DEFINITIONS.has(fleshdrive_id):
		return false
	if is_fleshdrive_unlocked(fleshdrive_id):
		return false
	unlocked_fleshdrive_blueprints[fleshdrive_id] = true
	pending_blueprint_notice = fleshdrive_id
	fleshdrive_core_levels[fleshdrive_id] = maxi(
		get_fleshdrive_level(fleshdrive_id),
		1
	)
	if save_immediately:
		_save_progression()
	fleshdrive_changed.emit(
		fleshdrive_id,
		get_fleshdrive_level(fleshdrive_id)
	)
	return true


func award_fleshdrive_core(
	fleshdrive_id: StringName,
	save_immediately: bool = true
) -> int:
	if not FleshdriveCatalog.DEFINITIONS.has(fleshdrive_id):
		return 0
	if not is_fleshdrive_unlocked(fleshdrive_id):
		unlocked_fleshdrive_blueprints[fleshdrive_id] = true
	var old_level := maxi(get_fleshdrive_level(fleshdrive_id), 1)
	var new_level := mini(
		old_level + 1,
		FleshdriveCatalog.MAX_CORE_LEVEL
	)
	fleshdrive_core_levels[fleshdrive_id] = new_level
	if save_immediately:
		_save_progression()
	fleshdrive_changed.emit(fleshdrive_id, new_level)
	return new_level


func get_statistics() -> Dictionary:
	return {
		"instance_number": instance_number,
		"instance_label": format_instance_number(instance_number),
		"runs": total_runs,
		"deaths": total_deaths,
		"boss_victories": boss_victories,
		"best_time": best_run_time,
		"total_kills": total_kills,
		"fleshdrive_metrics": fleshdrive_run_metrics.duplicate(true),
	}


func get_fleshdrive_metrics(fleshdrive_id: StringName) -> Dictionary:
	return (
		fleshdrive_run_metrics.get(
			fleshdrive_id,
			_default_fleshdrive_metrics()
		) as Dictionary
	).duplicate(true)


func _record_fleshdrive_metrics(
	fleshdrive_id: StringName,
	victory: bool,
	run_time: float
) -> void:
	if fleshdrive_id.is_empty():
		return
	var metrics := get_fleshdrive_metrics(fleshdrive_id)
	metrics["runs"] = int(metrics.get("runs", 0)) + 1
	metrics["total_time"] = (
		float(metrics.get("total_time", 0.0)) + maxf(run_time, 0.0)
	)
	if victory:
		metrics["victories"] = int(metrics.get("victories", 0)) + 1
		var previous_best := float(metrics.get("best_boss_time", 0.0))
		if previous_best <= 0.0 or run_time < previous_best:
			metrics["best_boss_time"] = maxf(run_time, 0.0)
	fleshdrive_run_metrics[fleshdrive_id] = metrics


func _default_fleshdrive_metrics() -> Dictionary:
	return {
		"runs": 0,
		"victories": 0,
		"total_time": 0.0,
		"best_boss_time": 0.0,
	}


func consume_blueprint_notice() -> StringName:
	var notice := pending_blueprint_notice
	pending_blueprint_notice = &""
	if not notice.is_empty():
		_save_progression()
	return notice


func format_instance_number(value: int = -1) -> String:
	var resolved_value := instance_number if value < 0 else value
	return "K0D4-%03d" % maxi(resolved_value, 1)


func request_flesh_tree_on_menu() -> void:
	open_flesh_tree_on_menu = true


func consume_flesh_tree_request() -> bool:
	var requested := open_flesh_tree_on_menu
	open_flesh_tree_on_menu = false
	return requested


func _load_progression() -> void:
	var repository := get_tree().root.get_node_or_null("SaveRepository")
	var config := ConfigFile.new()
	var loaded_version := 1
	if repository != null:
		var result := Dictionary(repository.call(
			"load_versioned", save_path, SAVE_VERSION
		))
		if not bool(result.get("ok", false)):
			if int(result.get("error", ERR_FILE_NOT_FOUND)) != ERR_FILE_NOT_FOUND:
				push_warning("MetaProgression: save and backup are unreadable; using safe defaults.")
			return
		config = result.get("config") as ConfigFile
		loaded_version = int(result.get("version", 1))
		if bool(result.get("recovered_from_backup", false)):
			push_warning("MetaProgression: recovered progression from backup.")
	else:
		var load_error := config.load(save_path)
		if load_error != OK:
			return
		loaded_version = int(config.get_value(SYSTEM_SECTION, "save_version", 1))
	red_gems = maxi(
		int(config.get_value(SAVE_SECTION, "red_gems", 0)),
		0
	)
	instance_number = maxi(
		int(config.get_value(
			STATISTICS_SECTION,
			"instance_number",
			1
		)),
		1
	)
	total_runs = maxi(
		int(config.get_value(STATISTICS_SECTION, "runs", 0)),
		0
	)
	total_deaths = maxi(
		int(config.get_value(STATISTICS_SECTION, "deaths", 0)),
		0
	)
	boss_victories = maxi(
		int(config.get_value(
			STATISTICS_SECTION,
			"boss_victories",
			0
		)),
		0
	)
	best_run_time = maxf(
		float(config.get_value(
			STATISTICS_SECTION,
			"best_time",
			0.0
		)),
		0.0
	)
	total_kills = maxi(
		int(config.get_value(
			STATISTICS_SECTION,
			"total_kills",
			0
		)),
		0
	)
	fleshdrive_run_metrics.clear()
	for fleshdrive_id in FleshdriveCatalog.DEFINITIONS:
		var id_text := String(fleshdrive_id)
		fleshdrive_run_metrics[fleshdrive_id] = {
			"runs": maxi(int(config.get_value(
				STATISTICS_SECTION,
				"%s_runs" % id_text,
				0
			)), 0),
			"victories": maxi(int(config.get_value(
				STATISTICS_SECTION,
				"%s_victories" % id_text,
				0
			)), 0),
			"total_time": maxf(float(config.get_value(
				STATISTICS_SECTION,
				"%s_total_time" % id_text,
				0.0
			)), 0.0),
			"best_boss_time": maxf(float(config.get_value(
				STATISTICS_SECTION,
				"%s_best_boss_time" % id_text,
				0.0
			)), 0.0),
		}
	pending_blueprint_notice = StringName(
		String(config.get_value(
			FLESHDRIVE_SECTION,
			"pending_blueprint_notice",
			""
		))
	)
	for upgrade_id in UPGRADE_DEFINITIONS:
		var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
		var saved_level := int(
			config.get_value(UPGRADE_SECTION, String(upgrade_id), 0)
		)
		upgrade_levels[upgrade_id] = clampi(
			saved_level,
			0,
			int(definition.max_level)
		)
	for fleshdrive_id in FleshdriveCatalog.DEFINITIONS:
		var id_text := String(fleshdrive_id)
		unlocked_fleshdrive_blueprints[fleshdrive_id] = bool(
			config.get_value(
				FLESHDRIVE_SECTION,
				"%s_unlocked" % id_text,
				fleshdrive_id != FleshdriveCatalog.TELEKINETIC
			)
		)
		fleshdrive_core_levels[fleshdrive_id] = clampi(
			int(config.get_value(
				FLESHDRIVE_SECTION,
				"%s_level" % id_text,
				(
					0
					if fleshdrive_id == FleshdriveCatalog.TELEKINETIC
					else 1
				)
			)),
			0,
			FleshdriveCatalog.MAX_CORE_LEVEL
		)
	if loaded_version < SAVE_VERSION:
		_save_progression()


func _save_progression() -> bool:
	var config := ConfigFile.new()
	config.set_value(SYSTEM_SECTION, "save_version", SAVE_VERSION)
	config.set_value(SAVE_SECTION, "red_gems", red_gems)
	config.set_value(
		STATISTICS_SECTION,
		"instance_number",
		instance_number
	)
	config.set_value(STATISTICS_SECTION, "runs", total_runs)
	config.set_value(STATISTICS_SECTION, "deaths", total_deaths)
	config.set_value(
		STATISTICS_SECTION,
		"boss_victories",
		boss_victories
	)
	config.set_value(
		STATISTICS_SECTION,
		"best_time",
		best_run_time
	)
	config.set_value(
		STATISTICS_SECTION,
		"total_kills",
		total_kills
	)
	for fleshdrive_id in FleshdriveCatalog.DEFINITIONS:
		var id_text := String(fleshdrive_id)
		var metrics := get_fleshdrive_metrics(fleshdrive_id)
		config.set_value(
			STATISTICS_SECTION,
			"%s_runs" % id_text,
			int(metrics.get("runs", 0))
		)
		config.set_value(
			STATISTICS_SECTION,
			"%s_victories" % id_text,
			int(metrics.get("victories", 0))
		)
		config.set_value(
			STATISTICS_SECTION,
			"%s_total_time" % id_text,
			float(metrics.get("total_time", 0.0))
		)
		config.set_value(
			STATISTICS_SECTION,
			"%s_best_boss_time" % id_text,
			float(metrics.get("best_boss_time", 0.0))
		)
	for upgrade_id in UPGRADE_DEFINITIONS:
		config.set_value(
			UPGRADE_SECTION,
			String(upgrade_id),
			get_upgrade_level(upgrade_id)
		)
	for fleshdrive_id in FleshdriveCatalog.DEFINITIONS:
		var id_text := String(fleshdrive_id)
		config.set_value(
			FLESHDRIVE_SECTION,
			"%s_unlocked" % id_text,
			is_fleshdrive_unlocked(fleshdrive_id)
		)
		config.set_value(
			FLESHDRIVE_SECTION,
			"%s_level" % id_text,
			get_fleshdrive_level(fleshdrive_id)
		)
	config.set_value(
		FLESHDRIVE_SECTION,
		"pending_blueprint_notice",
		String(pending_blueprint_notice)
	)
	var repository := get_tree().root.get_node_or_null("SaveRepository")
	var save_error := (
		int(repository.call("commit", config, save_path, SAVE_VERSION))
		if repository != null
		else config.save(save_path)
	)
	if save_error != OK:
		push_error(
			"MetaProgression: unable to save progression (%s)."
			% error_string(save_error)
		)
		return false
	if repository == null:
		var backup_error := config.save(save_path + ".bak")
		if backup_error != OK:
			push_warning("MetaProgression: primary save succeeded, backup failed.")
	return true


func _capture_transaction_state() -> Dictionary:
	return {
		"red_gems": red_gems,
		"upgrade_levels": upgrade_levels.duplicate(true),
		"instance_number": instance_number,
		"total_runs": total_runs,
		"total_deaths": total_deaths,
		"boss_victories": boss_victories,
		"best_run_time": best_run_time,
		"total_kills": total_kills,
		"metrics": fleshdrive_run_metrics.duplicate(true),
		"unlocked": unlocked_fleshdrive_blueprints.duplicate(true),
		"levels": fleshdrive_core_levels.duplicate(true),
		"last_unlock": last_blueprint_unlock,
		"pending_notice": pending_blueprint_notice,
	}


func _restore_transaction_state(snapshot: Dictionary) -> void:
	red_gems = int(snapshot.get("red_gems", 0))
	upgrade_levels = Dictionary(snapshot.get("upgrade_levels", {})).duplicate(true)
	instance_number = int(snapshot.get("instance_number", 1))
	total_runs = int(snapshot.get("total_runs", 0))
	total_deaths = int(snapshot.get("total_deaths", 0))
	boss_victories = int(snapshot.get("boss_victories", 0))
	best_run_time = float(snapshot.get("best_run_time", 0.0))
	total_kills = int(snapshot.get("total_kills", 0))
	fleshdrive_run_metrics = Dictionary(snapshot.get("metrics", {})).duplicate(true)
	unlocked_fleshdrive_blueprints = Dictionary(snapshot.get("unlocked", {})).duplicate(true)
	fleshdrive_core_levels = Dictionary(snapshot.get("levels", {})).duplicate(true)
	last_blueprint_unlock = StringName(snapshot.get("last_unlock", &""))
	pending_blueprint_notice = StringName(snapshot.get("pending_notice", &""))
