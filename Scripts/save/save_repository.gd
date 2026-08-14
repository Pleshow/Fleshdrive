extends Node


const SYSTEM_SECTION := "system"
const VERSION_KEY := "save_version"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_versioned(path: String, current_version: int) -> Dictionary:
	var primary := _try_load(path, current_version)
	if bool(primary.get("ok", false)):
		return primary
	var backup_path := path + ".bak"
	var backup := _try_load(backup_path, current_version)
	if bool(backup.get("ok", false)):
		_preserve_corrupt_file(path)
		var config := backup.get("config") as ConfigFile
		commit(config, path, current_version)
		backup["recovered_from_backup"] = true
		return backup
	return {
		"ok": false,
		"config": ConfigFile.new(),
		"version": 0,
		"recovered_from_backup": false,
		"error": primary.get("error", ERR_FILE_CORRUPT),
	}


func commit(config: ConfigFile, path: String, version: int) -> Error:
	if config == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	config.set_value(SYSTEM_SECTION, VERSION_KEY, version)
	var absolute := ProjectSettings.globalize_path(path)
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var save_error := config.save(temporary)
	if save_error != OK:
		return save_error
	var validation := ConfigFile.new()
	var validation_error := validation.load(temporary)
	if validation_error != OK:
		DirAccess.remove_absolute(temporary)
		return validation_error
	if int(validation.get_value(SYSTEM_SECTION, VERSION_KEY, -1)) != version:
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(absolute):
		DirAccess.copy_absolute(absolute, backup)
		var remove_error := DirAccess.remove_absolute(absolute)
		if remove_error != OK:
			DirAccess.remove_absolute(temporary)
			return remove_error
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, absolute)
		return rename_error
	# The backup must always be a known-good complete file, including on a
	# first save where no previous primary existed.
	if not FileAccess.file_exists(backup):
		DirAccess.copy_absolute(absolute, backup)
	return OK


func _try_load(path: String, current_version: int) -> Dictionary:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return {"ok": false, "config": config, "version": 0, "error": error}
	if config.get_sections().is_empty():
		return {"ok": false, "config": config, "version": 0, "error": ERR_FILE_CORRUPT}
	var version := int(config.get_value(SYSTEM_SECTION, VERSION_KEY, 1))
	if version <= 0 or version > current_version:
		return {"ok": false, "config": config, "version": version, "error": ERR_FILE_CORRUPT}
	return {"ok": true, "config": config, "version": version, "error": OK, "recovered_from_backup": false}


func _preserve_corrupt_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.copy_absolute(absolute, absolute + ".corrupt-" + timestamp)
