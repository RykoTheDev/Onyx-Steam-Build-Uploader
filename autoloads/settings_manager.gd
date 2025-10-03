extends Node

var config := ConfigFile.new()
var config_path: String

signal selected_user_changed(username: String)

func _init() -> void:
	var exe_path = OS.get_executable_path()
	var exe_dir = exe_path.get_base_dir()
	if OS.has_feature("editor"): 
		config_path = "user://settings.cfg"
	else: 
		config_path = exe_dir.path_join("settings.cfg")

func load_settings() -> void:
	var err = config.load(config_path)
	if err != OK:
		print("No settings file yet, using defaults. (err=%s)" % err)

func save_settings() -> void:
	var err = config.save(config_path)
	if err != OK:
		push_error("Failed to save settings: %s" % err)

func get_setting(section: String, key: String, default_value = null):
	if config.has_section_key(section, key):
		return config.get_value(section, key, default_value)
	return default_value

func set_setting(section: String, key: String, value) -> void:
	config.set_value(section, key, value)
	save_settings()

# --- User-specific helpers ---
func save_user(username: String, password: String, is_selected: bool = false) -> void:
	var user_data = {
		"username": username,
		"password": password,
		"is_selected": is_selected
	}
	set_setting("users", username, user_data)

func load_users() -> Dictionary:
	if not config.has_section("users"):
		return {}
	var users := {}
	for key in config.get_section_keys("users"):
		var val = config.get_value("users", key, {})
		if typeof(val) == TYPE_DICTIONARY:
			users[key] = val
	return users

func set_selected_user(username: String) -> void:
	if not config.has_section("users"):
		return
	for key in config.get_section_keys("users"):
		var val = config.get_value("users", key, {})
		if typeof(val) == TYPE_DICTIONARY:
			val["is_selected"] = (key == username)
			config.set_value("users", key, val)
	save_settings()
	selected_user_changed.emit(username)

func clear_selected_user() -> void:
	if not config.has_section("users"):
		return
	for key in config.get_section_keys("users"):
		var val = config.get_value("users", key, {})
		if typeof(val) == TYPE_DICTIONARY:
			val["is_selected"] = false
			config.set_value("users", key, val)
	save_settings()
	selected_user_changed.emit("")

func get_selected_user() -> String:
	if not config.has_section("users"):
		return ""
	for key in config.get_section_keys("users"):
		var val = config.get_value("users", key, {})
		if typeof(val) == TYPE_DICTIONARY:
			if val.get("is_selected", false):
				return val.get("username", "")
	return ""
