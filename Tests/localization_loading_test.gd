extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	_validate_catalog_source()
	_validate_voltaic_catalog_source()
	var menu_scene := load("res://Scenes/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	_check(
		is_equal_approx(menu.minimum_loading_seconds, 5.0),
		"Start Run has a five-second minimum loading presentation"
	)
	_check(
		menu.get_node("LoadingScreen") is LoadingScreen,
		"Main menu owns the animated loading overlay"
	)
	var settings := root.get_node_or_null("GameSettings")
	_check(settings != null, "Language settings autoload is available")
	if settings != null:
		var options: Array = settings.call("get_language_options")
		_check(options.size() == 2, "English and Hungarian are listed")
		_check(
			bool(options[0].get("enabled", false))
			and bool(options[1].get("enabled", false)),
			"English and Hungarian are active"
		)
		_check(
			bool(settings.call("set_language", "hu", false)),
			"Hungarian can be selected"
		)
		_check(
			TranslationServer.translate("MAIN MENU") != "MAIN MENU",
			"Hungarian strings resolve through the translation server"
		)
		_check(
			TranslationServer.translate("VOLT_BALL_LIGHTNING_DESC").contains("kék gömböt")
			and TranslationServer.translate("BLOOD MEMORY: %d") != "BLOOD MEMORY: %d",
			"Voltaic cards and Blood Memory UI resolve in Hungarian"
		)
		_check(
			TranslationServer.translate("MIMICHU_OPERATION_PROMPT").contains(
				"Válaszd"
			),
			"Hungarian dynamic dialogue resolves from the canonical catalog"
		)
		_check(
			"hu" in TranslationServer.get_loaded_locales(),
			"TranslationServer reports Hungarian as loaded"
		)
		settings.call("set_language", "en", false)
	_check(
		TranslationServer.translate("START RUN") == "START RUN",
		"English strings resolve through the translation server"
	)
	_check(
		TranslationServer.translate("VOLT_STATIC_CLAWS_DESC").contains("contact damage"),
		"Revised Voltaic card explanations resolve in English"
	)
	menu.queue_free()
	await process_frame
	if failures == 0:
		print("LOCALIZATION AND LOADING TEST PASSED")
		quit(0)
		return
	quit(1)


func _validate_catalog_source() -> void:
	var file := FileAccess.open(
		"res://Localization/fleshdrive_text.csv",
		FileAccess.READ
	)
	_check(file != null, "Canonical localization CSV is readable")
	if file == null:
		return
	var header := file.get_csv_line(",")
	_check(
		header == PackedStringArray(["keys", "en", "hu"]),
		"Canonical localization header defines en and hu locales"
	)
	var seen: Dictionary = {}
	var row_count := 0
	while file.get_position() < file.get_length():
		var row := file.get_csv_line(",")
		if row.is_empty() or String(row[0]).is_empty():
			continue
		row_count += 1
		_check(row.size() == 3, "Localization row has exactly three columns")
		if row.size() < 3:
			continue
		var key := String(row[0])
		_check(not seen.has(key), "Localization key is unique: " + key)
		seen[key] = true
		_check(
			not String(row[1]).contains("�")
			and not String(row[2]).contains("�"),
			"Localization row is valid UTF-8: " + key
		)
		_check(
			_extract_placeholders(String(row[1]))
			== _extract_placeholders(String(row[2])),
			"Placeholders match for: " + key
		)
	file.close()
	_check(row_count >= 220, "Canonical catalog contains the full UI text set")


func _validate_voltaic_catalog_source() -> void:
	var file := FileAccess.open(
		"res://Localization/voltaic_cards.csv",
		FileAccess.READ
	)
	_check(file != null, "Voltaic localization CSV is readable")
	if file == null:
		return
	var header := file.get_csv_line(",")
	_check(
		header == PackedStringArray(["keys", "en", "hu"]),
		"Voltaic catalog defines English and Hungarian"
	)
	var keys: Dictionary = {}
	while file.get_position() < file.get_length():
		var row := file.get_csv_line(",")
		if row.size() != 3 or String(row[0]).is_empty():
			continue
		keys[String(row[0])] = true
	file.close()
	for upgrade_id in VoltaicCardCatalog.CARD_IDS:
		var stem := String(upgrade_id).to_upper()
		_check(
			keys.has("VOLT_%s_NAME" % stem)
			and keys.has("VOLT_%s_DESC" % stem),
			"Bilingual card copy exists for %s" % String(upgrade_id)
		)


func _extract_placeholders(text: String) -> Array[String]:
	var placeholders: Array[String] = []
	var regex := RegEx.new()
	regex.compile("%[sdf]|\\{[A-Za-z0-9_]+\\}")
	for result in regex.search_all(text):
		placeholders.append(result.get_string())
	placeholders.sort()
	return placeholders
