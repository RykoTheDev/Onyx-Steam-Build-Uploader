extends PanelContainer

@onready var main_panel: PanelContainer = %Main_Panel
@onready var no_apps_panel: PanelContainer = %No_Apps_Panel

@onready var no_apps_set_directory_button: Button = %No_Apps_Set_Directory_Button
@onready var no_apps_refresh_button: Button = %No_Apps_Refresh_Button
@onready var setup_button: Button = %Setup_Button

@onready var apps_list: VBoxContainer = %Apps_List

@onready var popups_layer: CanvasLayer = %PopupsLayer

@onready var refresh_button: Button = %Refresh_Button


func _ready() -> void:
	_check_content_builder_path()

	no_apps_set_directory_button.pressed.connect(_on_no_apps_set_directory_pressed)
	setup_button.pressed.connect(_on_no_apps_set_directory_pressed)
	no_apps_refresh_button.pressed.connect(_check_content_builder_path)
	refresh_button.pressed.connect(_on_refresh_pressed)

func _on_refresh_pressed() -> void:
	_check_content_builder_path()

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


func _close_popup(popup_scene) -> void:
	var tween = create_tween()
	tween.tween_property(popup_scene, "scale", Vector2(0, 0), 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): 
		popup_scene.queue_free()
		_check_content_builder_path()
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
	# Clear existing list
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

	# === App ID ===
	if id_text:
		id_text.text = app_id

	# === Description ===
	var description := _parse_app_vdf_for_desc(vdf_path)
	if description_line:
		description_line.text = description

	# === Depots ===
	var depots := _parse_vdf_for_depots(vdf_path)
	if depots_button:
		depots_button.text = "Depots: %02d" % depots.size()


# ===================================================
# VDF Parsing
# ===================================================

func _parse_app_vdf_for_desc(vdf_path: String) -> String:
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		# Look for: "desc" "something"
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
