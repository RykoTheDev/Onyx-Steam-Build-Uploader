extends PanelContainer

@onready var main_panel: PanelContainer = %Main_Panel
@onready var no_apps_panel: PanelContainer = %No_Apps_Panel

@onready var no_apps_set_directory_button: Button = %No_Apps_Set_Directory_Button
@onready var no_apps_refresh_button: Button = %No_Apps_Refresh_Button
@onready var setup_button: Button = %Setup_Button

@onready var apps_list: VBoxContainer = %Apps_List

@onready var popups_layer: CanvasLayer = %PopupsLayer

@onready var refresh_button: Button = %Refresh_Button

@onready var manage_users_button: Button = %Manage_Users_Button
@onready var current_user_text: Label = %Current_User_Text

@onready var upload_button: Button = %Upload_Button
@onready var selected_apps_counter_text: Label = %Selected_Apps_Counter_Text

@onready var donate_button: Button = %Donate_Button
@onready var star_on_github_button: Button = %Star_on_Github_Button

@onready var console_scroll_container: SmoothScrollContainer = %Console_Scroll_Container
@onready var console_log_popup: Control = $PopupsLayer/Console_Log_Popup
@onready var console_label: RichTextLabel = %Console_Log
@onready var console_close_button: Button = %Console_Close_Button

var selected_apps_count: int = 0
var selected_apps_data: Array[Dictionary] = []

var _current_upload_index: int = 0
var _is_uploading: bool = false
var _current_process_id: int = -1
var _process_check_timer: Timer = null
var _output_file_path: String = ""
var _last_file_position: int = 0

var _steam_guard_timeout: float = 5.0
var _time_since_last_output: float = 0.0
var _steam_guard_prompted: bool = false
var _last_output_time: float = 0.0

func _ready() -> void:
	_check_content_builder_path()
	_update_current_user_display()
	_update_upload_button_state()
	
	console_log_popup.hide()
	
	SettingManager.selected_user_changed.connect(_on_selected_user_changed)

	no_apps_set_directory_button.pressed.connect(_on_no_apps_set_directory_pressed)
	setup_button.pressed.connect(_on_no_apps_set_directory_pressed)
	no_apps_refresh_button.pressed.connect(_check_content_builder_path)
	manage_users_button.pressed.connect(_on_manage_users_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	upload_button.pressed.connect(_on_upload_pressed)
	donate_button.pressed.connect(_on_donate_pressed)
	star_on_github_button.pressed.connect(_on_star_pressed)
	
	_process_check_timer = Timer.new()
	_process_check_timer.wait_time = 0.1
	_process_check_timer.timeout.connect(_check_process_output)
	add_child(_process_check_timer)

func _on_refresh_pressed() -> void:
	_check_content_builder_path()
	_update_current_user_display()

func _on_upload_pressed() -> void:
	if selected_apps_data.is_empty():
		return
	
	console_log_popup.show()
	
	if _is_uploading:
		_log_to_console("⚠️ Upload already in progress!")
		return
	
	SettingManager.save_settings()
	_current_upload_index = 0
	_is_uploading = true
	upload_button.disabled = true
	_log_to_console("🚀 Starting upload process...")
	_upload_next_app()

func _upload_next_app() -> void:
	if _current_upload_index >= selected_apps_data.size():
		_is_uploading = false
		upload_button.disabled = false
		_log_to_console("✅ All uploads finished!")
		_process_check_timer.stop()
		_cleanup_output_file()
		return

	var app_data = selected_apps_data[_current_upload_index]
	var vdf_path = app_data["vdf_path"]

	_steam_guard_prompted = false
	_last_output_time = Time.get_ticks_msec() / 1000.0
	_time_since_last_output = 0.0

	_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_log_to_console("📦 Starting upload for App ID: " + app_data["app_id"])
	_log_to_console("VDF: " + vdf_path)
	
	_update_vdf_desc(vdf_path, app_data)
	_log_to_console("✏️ Updated VDF description")

	var builder_path = SettingManager.get_setting("paths", "content_builder", "")
	
	_output_file_path = "user://steamcmd_output_" + str(Time.get_ticks_msec()) + ".txt"
	_last_file_position = 0
	
	var terminal_cmd: String
	var args: Array = []

	if OS.has_feature("windows"):
		var steamcmd_exe = builder_path.path_join("builder").path_join("steamcmd.exe")
		if not FileAccess.file_exists(steamcmd_exe):
			_log_to_console("❌ SteamCMD not found: " + steamcmd_exe)
			_current_upload_index += 1
			_upload_next_app()
			return
		
		terminal_cmd = "cmd.exe"
		var output_path = ProjectSettings.globalize_path(_output_file_path)
		var full_command = "\"%s\" +login %s %s +run_app_build \"%s\" +quit > \"%s\" 2>&1" % [
			steamcmd_exe,
			SettingManager.get_selected_user(),
			SettingManager.get_selected_user_password(),
			vdf_path,
			output_path
		]
		args = ["/c", full_command]

	elif OS.has_feature("linux"):
		var steamcmd_exe = builder_path.path_join("builder_linux").path_join("steamcmd.sh")
		if not FileAccess.file_exists(steamcmd_exe):
			_log_to_console("❌ SteamCMD not found: " + steamcmd_exe)
			_current_upload_index += 1
			_upload_next_app()
			return

		terminal_cmd = "bash"
		var output_path = ProjectSettings.globalize_path(_output_file_path)
		args = [
			"-c",
			"\"%s\" +login %s %s +run_app_build \"%s\" +quit > \"%s\" 2>&1" % [
				steamcmd_exe,
				SettingManager.get_selected_user(),
				SettingManager.get_selected_user_password(),
				vdf_path,
				output_path
			]
		]
	
	console_close_button.text = "CANCEL UPLOAD"
	if console_close_button.pressed.is_connected(_on_console_closed_pressed):
		console_close_button.pressed.disconnect(_on_console_closed_pressed)
	console_close_button.pressed.connect(_cancel_upload)
	_log_to_console("🔄 Executing SteamCMD...")
	_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	_current_process_id = OS.create_process(terminal_cmd, args)
	
	if _current_process_id == -1:
		_log_to_console("❌ Failed to start SteamCMD process")
		_current_upload_index += 1
		_upload_next_app()
	else:
		_log_to_console("⏳ Process started (PID: " + str(_current_process_id) + ")")
		_process_check_timer.start()

func _cancel_upload() -> void:
	if _current_process_id != -1:
		_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		_log_to_console("🛑 Cancelling upload...")
		
		OS.kill(_current_process_id)
		_current_process_id = -1
	
	_process_check_timer.stop()
	
	_is_uploading = false
	console_close_button.text = "CLOSE"
	if console_close_button.pressed.is_connected(_cancel_upload):
		console_close_button.pressed.disconnect(_cancel_upload)
	console_close_button.pressed.connect(_on_console_closed_pressed)
	
	_cleanup_output_file()
	
	_log_to_console("❌ Upload cancelled by user")
	_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	console_label.clear()
	upload_button.disabled = false
	console_log_popup.hide()

func _check_process_output() -> void:
	if _current_process_id == -1:
		return
	
	var had_new_output = _read_output_file()
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if had_new_output:
		_last_output_time = current_time
		_time_since_last_output = 0.0
	else:
		_time_since_last_output = current_time - _last_output_time
	
	if not _steam_guard_prompted and _time_since_last_output >= _steam_guard_timeout:
		if OS.is_process_running(_current_process_id):
			_steam_guard_prompted = true
			_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			_log_to_console("[color=#ffff00]⚠️ WAITING FOR INPUT[/color]")
			_log_to_console("[color=#ffff00]SteamCMD may be waiting for your Steam Guard code.[/color]")
			_log_to_console("[color=#ffff00]Please check your email or mobile authenticator,[/color]")
			_log_to_console("[color=#ffff00]then enter the code in the SteamCMD window.[/color]")
			_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	if not OS.is_process_running(_current_process_id):
		_process_check_timer.stop()
		
		await get_tree().create_timer(0.2).timeout
		_read_output_file()
		
		_log_to_console("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		_log_to_console("✅ Upload process completed!")
		console_close_button.text = "CLOSE"
		if console_close_button.pressed.is_connected(_cancel_upload):
			console_close_button.pressed.disconnect(_cancel_upload)
		console_close_button.pressed.connect(_on_console_closed_pressed)
		_cleanup_output_file()
		_current_process_id = -1
		_current_upload_index += 1
		
		await get_tree().create_timer(0.3).timeout
		_upload_next_app()

func _read_output_file() -> bool:
	if _output_file_path == "":
		return false
	
	var file := FileAccess.open(_output_file_path, FileAccess.READ)
	if not file:
		return false
	
	file.seek(_last_file_position)
	
	var had_output = false
	while not file.eof_reached():
		var line = file.get_line()
		if line != "":
			line = _strip_ansi_codes(line)
			if line.strip_edges() != "":
				_log_to_console_raw(line)
				had_output = true
	
	_last_file_position = file.get_position()
	file.close()
	
	return had_output

func _strip_ansi_codes(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\x1b\\[[0-9;]*[a-zA-Z]")
	return regex.sub(text, "", true)

func _cleanup_output_file() -> void:
	if _output_file_path != "" and FileAccess.file_exists(_output_file_path):
		DirAccess.remove_absolute(_output_file_path)
		_output_file_path = ""

func _log_to_console(message: String) -> void:
	if console_label:
		console_label.append_text(message + "\n")
		await get_tree().process_frame
		_auto_scroll_console()
	print(message)

func _log_to_console_raw(message: String) -> void:
	if console_label:
		console_label.append_text(message + "\n")
		await get_tree().process_frame
		_auto_scroll_console()
	print(message)

func _auto_scroll_console() -> void:
	if console_scroll_container:
		console_scroll_container.scroll_vertical = int(console_scroll_container.get_v_scroll_bar().max_value)

func _update_vdf_desc(vdf_path: String, app_data: Dictionary) -> void:
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return

	var lines := file.get_as_text().split("\n")
	file.close()

	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("\"desc\""):
			lines[i] = "\"desc\" \"%s\"" % app_data.get("desc", "")
			break

	file = FileAccess.open(vdf_path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()

func _on_console_closed_pressed() -> void:
	console_log_popup.hide()

func _update_current_user_display() -> void:
	var selected_user = SettingManager.get_selected_user()
	if selected_user != "":
		current_user_text.text = selected_user
	else:
		current_user_text.text = "No User Selected"

func _on_selected_user_changed(_username: String) -> void:
	_update_current_user_display()
	_update_upload_button_state()

func _update_upload_button_state() -> void:
	var user_selected = SettingManager.get_selected_user() != ""
	upload_button.disabled = (selected_apps_count == 0 or not user_selected or _is_uploading)
	selected_apps_counter_text.text = "APP(s) SELECTED: " + str(selected_apps_count)

func _on_app_checkbox_toggled(is_checked: bool, app_id: String, vdf_path: String) -> void:
	if is_checked:
		selected_apps_count += 1
		var initial_desc = ""
		for child in apps_list.get_children():
			var id_text = child.get_node("%App_ID_Text")
			var desc_line = child.get_node("%App_Description_LineEdit")
			if id_text and id_text.text == app_id and desc_line:
				initial_desc = desc_line.text
				break
		
		selected_apps_data.append({
			"app_id": app_id,
			"vdf_path": vdf_path,
			"desc": initial_desc
		})
	else:
		selected_apps_count -= 1
		for i in range(selected_apps_data.size()):
			if selected_apps_data[i].get("app_id") == app_id:
				selected_apps_data.remove_at(i)
				break
	
	selected_apps_count = max(0, selected_apps_count)
	_update_upload_button_state()

# ===================================================
# Popups
# ===================================================

func _on_no_apps_set_directory_pressed() -> void:
	var popup_scene = SceneManager.SETUP_POPUP.instantiate()
	popups_layer.add_child(popup_scene)
	
	popup_scene.scale = Vector2(0, 0)
	var tween = popup_scene.create_tween()
	tween.tween_property(popup_scene, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	var close_button = popup_scene.get_node("%Close_Button")
	if close_button:
		close_button.pressed.connect(_close_popup.bind(popup_scene))

func _on_manage_users_pressed() -> void:
	var popup_scene = SceneManager.USERS_POPUP.instantiate()
	popups_layer.add_child(popup_scene)
	
	popup_scene.scale = Vector2(0, 0)
	var tween = popup_scene.create_tween()
	tween.tween_property(popup_scene, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	var close_button = popup_scene.get_node("%Close_Button")
	if close_button:
		close_button.pressed.connect(_close_popup.bind(popup_scene))


func _close_popup(popup_scene) -> void:
	var tween = create_tween()
	tween.tween_property(popup_scene, "scale", Vector2(0, 0), 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		popup_scene.queue_free()
		_check_content_builder_path()
		_update_current_user_display()
	)


# ===================================================
# Helpers
# ===================================================
func _check_content_builder_path() -> void:
	SettingManager.load_settings()
	var builder_path = SettingManager.get_setting("paths", "content_builder", "")

	if builder_path != "" and _is_valid_content_builder_path(builder_path):
		no_apps_panel.visible = false
		main_panel.visible = true
		_populate_apps(builder_path)
	else:
		no_apps_panel.visible = true
		main_panel.visible = false
		selected_apps_count = 0
		selected_apps_data.clear()
		_update_upload_button_state()


func _is_valid_content_builder_path(dir_path: String) -> bool:
	var required = ["content", "output", "scripts"]
	for sub in required:
		if not DirAccess.dir_exists_absolute(dir_path.path_join(sub)):
			return false
	return true


# ===================================================
# App Cards
# ===================================================
func _populate_apps(builder_path: String) -> void:
	var previously_selected_apps: Dictionary = {}
	for app_data in selected_apps_data:
		previously_selected_apps[app_data["app_id"]] = app_data["desc"]
	
	selected_apps_count = 0
	selected_apps_data.clear()
	
	for child in apps_list.get_children():
		child.queue_free()

	var scripts_path = builder_path.path_join("scripts")
	if not DirAccess.dir_exists_absolute(scripts_path):
		_update_upload_button_state()
		return

	var dir := DirAccess.open(scripts_path)
	if not dir:
		_update_upload_button_state()
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".vdf") and file_name.begins_with("app_"):
			var parts = file_name.get_file().split("_")
			if parts.size() > 1:
				var app_id_str = parts[1].get_basename()
				if app_id_str.is_valid_int():
					_spawn_app_card(app_id_str, scripts_path.path_join(file_name), previously_selected_apps)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	_update_upload_button_state()


func _spawn_app_card(app_id: String, vdf_path: String, previously_selected: Dictionary = {}) -> void:
	var card = SceneManager.APP_CARD.instantiate()
	apps_list.add_child(card)

	var id_text: Label = card.get_node("%App_ID_Text")
	var description_line: LineEdit = card.get_node("%App_Description_LineEdit")
	var depots_button: Button = card.get_node("%Depots_Button")
	var checkbox: CustomCheckbox = card.get_node("%CheckBox")

	# === App ID ===
	if id_text:
		id_text.text = app_id

	# === Description ===
	var description := _parse_app_vdf_for_desc(vdf_path)
	description = SettingManager.get_app_description(app_id, description)
	if description_line:
		description_line.text = description
		description_line.text_changed.connect(func(new_text: String):
			SettingManager.save_app_description(app_id, new_text)
			for i in range(selected_apps_data.size()):
				if selected_apps_data[i]["app_id"] == app_id:
					selected_apps_data[i]["desc"] = new_text
					return
		)

	# === Depots ===
	var depots := _parse_vdf_for_depots(vdf_path)
	if depots_button:
		depots_button.text = "Depots: %02d" % depots.size()
	
	# === Checkbox ===
	if checkbox:
		if previously_selected.has(app_id):
			checkbox.set_checked(true)
			selected_apps_count += 1
			selected_apps_data.append({
				"app_id": app_id,
				"vdf_path": vdf_path,
				"desc": previously_selected[app_id]
			})
			if description_line:
				description_line.text = previously_selected[app_id]
		
		checkbox.pressed.connect(func(): _on_app_checkbox_toggled(checkbox.is_checked(), app_id, vdf_path))


# ===================================================
# VDF Parsing
# ===================================================

func _parse_app_vdf_for_desc(vdf_path: String) -> String:
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with("\"desc\""):
			var tokens = line.split("\"", false)
			if tokens.size() >= 3:
				return tokens[2].strip_edges()
	file.close()
	return ""


func _parse_vdf_for_depots(vdf_path: String) -> Array:
	var depots: Array = []
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return depots

	var inside_depots := false
	var brace_depth := 0
	var found_depots_block := false

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		if not inside_depots and line == "\"depots\"":
			found_depots_block = true
			continue
		
		if found_depots_block and not inside_depots and line == "{":
			inside_depots = true
			brace_depth = 1
			continue

		if inside_depots:
			if line == "{":
				brace_depth += 1
			elif line == "}":
				brace_depth -= 1
				if brace_depth == 0:
					break
			else:
				if brace_depth == 1 and line.contains("\""):
					var tokens = line.split("\"", false)
					if tokens.size() >= 2:
						var depot_id = tokens[0].strip_edges()
						if depot_id.is_valid_int():
							depots.append(depot_id)

	file.close()
	return depots

func _on_donate_pressed() -> void:
	OS.shell_open("https://patreon.com/SilverDemons")

func _on_star_pressed() -> void:
	OS.shell_open("https://github.com/rayzorite/SteamBuildUploader")
