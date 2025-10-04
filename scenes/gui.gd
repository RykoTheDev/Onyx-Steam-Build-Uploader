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

var selected_apps_count: int = 0
var selected_apps_data: Array[Dictionary] = []

var _current_upload_index: int = 0
var _is_uploading: bool = false

func _ready() -> void:
	_check_content_builder_path()
	_update_current_user_display()
	_update_upload_button_state()
	
	SettingManager.selected_user_changed.connect(_on_selected_user_changed)

	no_apps_set_directory_button.pressed.connect(_on_no_apps_set_directory_pressed)
	setup_button.pressed.connect(_on_no_apps_set_directory_pressed)
	no_apps_refresh_button.pressed.connect(_check_content_builder_path)
	manage_users_button.pressed.connect(_on_manage_users_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	upload_button.pressed.connect(_on_upload_pressed)

func _on_refresh_pressed() -> void:
	_check_content_builder_path()
	_update_current_user_display()

func _on_upload_pressed() -> void:
	if selected_apps_data.is_empty():
		return
	
	SettingManager.save_settings()
	_current_upload_index = 0
	_upload_next_app()

func _upload_next_app() -> void:
	if _current_upload_index >= selected_apps_data.size():
		_is_uploading = false
		print("✅ All uploads finished!")
		return

	var app_data = selected_apps_data[_current_upload_index]
	var vdf_path = app_data["vdf_path"]

	print("Starting upload for app VDF:", vdf_path)
	_update_vdf_desc(vdf_path, app_data)
	print("Updated VDF description for app.")

	var builder_path = SettingManager.get_setting("paths", "content_builder", "")
	var terminal_cmd: String
	var args: Array = []

	if OS.has_feature("windows"):
		var steamcmd_exe = builder_path.path_join("builder").path_join("steamcmd.exe")
		if not FileAccess.file_exists(steamcmd_exe):
			printerr("SteamCMD not found:", steamcmd_exe)
			return
		terminal_cmd = "cmd.exe"
		args = [
			"/c",
			"start", "\"\"",
			"\"%s\"" % steamcmd_exe,
			"+login", SettingManager.get_selected_user(),
			SettingManager.get_selected_user_password(),
			"+run_app_build", vdf_path,
		    "+quit"
		]
		var exit_code = OS.execute(terminal_cmd, args, [], true, true)
		if exit_code != 0:
			printerr("❌ SteamCMD exited with code:", exit_code)

	elif OS.has_feature("linux"):
		var steamcmd_exe = builder_path.path_join("builder_linux").path_join("steamcmd.sh")
		if not FileAccess.file_exists(steamcmd_exe):
			printerr("SteamCMD not found:", steamcmd_exe)
			return

		terminal_cmd = steamcmd_exe
		args = [
			"+login", SettingManager.get_selected_user(),
			SettingManager.get_selected_user_password(),
			"+run_app_build", vdf_path,
			"+quit"
		]

		var exit_code = OS.execute(terminal_cmd, args, [], true, true)
		if exit_code != 0:
			printerr("❌ SteamCMD exited with code:", exit_code)

	_current_upload_index += 1
	_upload_next_app()

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
	upload_button.disabled = (selected_apps_count == 0 or not user_selected)
	selected_apps_counter_text.text = "APP(s) SELECTED: " + str(selected_apps_count)

func _on_app_checkbox_toggled(is_checked: bool, app_id: String, vdf_path: String) -> void:
	if is_checked:
		selected_apps_count += 1
		var initial_desc = ""  # default if not found
		# Try to read from the card
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
		# Remove from selected apps
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
	selected_apps_count = 0
	selected_apps_data.clear()
	_update_upload_button_state()
	
	for child in apps_list.get_children():
		child.queue_free()

	var scripts_path = builder_path.path_join("scripts")
	if not DirAccess.dir_exists_absolute(scripts_path):
		return

	var dir := DirAccess.open(scripts_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".vdf") and file_name.begins_with("app_"):
			var parts = file_name.get_file().split("_")
			if parts.size() > 1:
				var app_id_str = parts[1].get_basename()
				if app_id_str.is_valid_int():
					_spawn_app_card(app_id_str, scripts_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _spawn_app_card(app_id: String, vdf_path: String) -> void:
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
	if description_line:
		description_line.text = description
		# Whenever the user edits the description, update selected_apps_data
		description_line.text_changed.connect(func(new_text: String):
			# Find the entry for this app_id and update its description
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
