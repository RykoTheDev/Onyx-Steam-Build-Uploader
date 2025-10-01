extends Control
class_name SetupPopup

@onready var content_builder_path_line_edit: LineEdit = %Content_Builder_Path_LineEdit
@onready var content_builder_browse_button: Button = %Content_Builder_Browse_Button
@onready var app_list_container: VBoxContainer = %Apps_List_Container

var error_label: Label
var file_dialog: FileDialog
var feedback_tween: Tween

func _ready() -> void:
	# Error label
	error_label = Label.new()
	error_label.text = "Invalid ContentBuilder folder!"
	error_label.modulate = Color(1, 0.4, 0.4)
	error_label.visible = false
	error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_label.add_theme_font_size_override("font_size", 12)
	content_builder_path_line_edit.get_parent().get_parent().add_child(error_label)
	
	# File dialog
	file_dialog = FileDialog.new()
	file_dialog.set_file_mode(FileDialog.FILE_MODE_OPEN_DIR)
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.set_use_native_dialog(true)
	add_child(file_dialog)

	content_builder_browse_button.pressed.connect(_on_browse_button_pressed)
	file_dialog.dir_selected.connect(_on_dir_selected)

	var create_app_button: Button = %Create_App_Button
	if create_app_button:
		create_app_button.pressed.connect(_on_create_app_button_pressed)


# ===============================
# Browse and validation
# ===============================

func _on_browse_button_pressed() -> void:
	file_dialog.popup_centered()

func _on_dir_selected(dir_path: String) -> void:
	content_builder_path_line_edit.text = dir_path
	
	if _is_valid_content_builder_path(dir_path):
		error_label.visible = false
		_add_depot_card(dir_path)
		_play_success_animation()
	else:
		error_label.visible = true
		_clear_depot_cards()
		_play_error_animation()

func _is_valid_content_builder_path(dir_path: String) -> bool:
	var required = ["content", "output", "scripts"]
	for sub in required:
		var check_path = dir_path.path_join(sub)
		if not DirAccess.dir_exists_absolute(check_path):
			return false
	return true


# ===============================
# Card spawning
# ===============================

func _add_depot_card(dir_path: String) -> void:
	_clear_depot_cards()
	var scripts_path = dir_path.path_join("scripts")
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
					_spawn_app_card(app_id_str, dir_path, scripts_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _spawn_app_card(app_id: String, dir_path: String, vdf_path: String) -> void:
	var card: Control = SceneManager.CREATE_APP_CARD.instantiate()
	card.set_meta("content_builder_path", dir_path)
	app_list_container.add_child(card)
	
	var app_id_line_edit: LineEdit = card.get_node_or_null("%App_ID_LineEdit")
	if app_id_line_edit:
		app_id_line_edit.text = app_id
	
	var depots_container: VBoxContainer = card.get_node_or_null("%Depots_List_Container")
	if not depots_container:
		return
	
	# Connect Add Depot button
	var add_button: Button = card.get_node_or_null("%App_Depot_Button")
	if add_button:
		add_button.pressed.connect(_on_add_depot_button_pressed.bind(depots_container, dir_path))
	
	# Load depots from vdf
	for child in depots_container.get_children():
		child.queue_free()
	depots_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var depots = _parse_vdf_for_depots(vdf_path)
	for depot_id in depots:
		_create_depot_card(depots_container, dir_path, depot_id)


func _create_depot_card(depots_container: VBoxContainer, dir_path: String, depot_id: String = "") -> void:
	var depot_card: Control = SceneManager.CREATE_DEPOT_CARD.instantiate()
	depot_card.set_meta("content_builder_path", dir_path)
	
	if depot_id != "":
		depot_card.set_meta("depot_id", depot_id)
	
	depots_container.add_child(depot_card)
	
	# Fill Depot ID if provided
	var depot_id_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_ID_LineEdit")
	if depot_id_line_edit and depot_id != "":
		depot_id_line_edit.text = depot_id
	
	# Fill Depot path if provided
	if depot_id != "":
		var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
		var depot_contentroot = _parse_depot_vdf_for_contentroot(depot_vdf_path)
		
		var depot_path_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_Path_LineEdit")
		if depot_path_line_edit and depot_contentroot != "":
			depot_path_line_edit.text = depot_contentroot
	
	# Hook delete button
	var delete_button: Button = depot_card.get_node_or_null("%Delete_Depot_Button")
	if delete_button:
		delete_button.pressed.connect(_on_delete_depot_button_pressed.bind(depot_card))


# ===============================
# Add/Delete handlers
# ===============================

func _on_add_depot_button_pressed(depots_container: VBoxContainer, dir_path: String) -> void:
	# Create an empty depot card (user will fill manually)
	_create_depot_card(depots_container, dir_path)

func _on_delete_depot_button_pressed(depot_card: Control) -> void:
	var dir_path: String = depot_card.get_meta("content_builder_path", "")
	var depot_id: String = depot_card.get_meta("depot_id", "")
	if dir_path == "" or depot_id == "":
		depot_card.queue_free()
		return
	
	var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
	if FileAccess.file_exists(depot_vdf_path):
		var err = DirAccess.remove_absolute(depot_vdf_path)
		if err != OK:
			printerr("❌ Failed to delete: ", depot_vdf_path, " (error code: ", err, ")")
		else:
			print("🗑️ Deleted depot file: ", depot_vdf_path)
	
	depot_card.queue_free()

func _on_create_app_button_pressed() -> void:
	var dir_path = content_builder_path_line_edit.text.strip_edges()
	if not _is_valid_content_builder_path(dir_path):
		# Show "Add path first" error instead of creating a card
		error_label.text = "Add path first!"
		error_label.visible = true
		_play_error_animation()
		return
	
	# Hide the error if path is valid
	error_label.visible = false

	# Spawn an empty App Card
	var card: Control = SceneManager.CREATE_APP_CARD.instantiate()
	card.set_meta("content_builder_path", dir_path)
	app_list_container.add_child(card)

	# Initialize empty depot container
	var depots_container: VBoxContainer = card.get_node_or_null("%Depots_List_Container")
	if depots_container:
		depots_container.alignment = BoxContainer.ALIGNMENT_BEGIN

		# Connect Add Depot button inside this new App card
		var add_button: Button = card.get_node_or_null("%App_Depot_Button")
		if add_button:
			add_button.pressed.connect(_on_add_depot_button_pressed.bind(depots_container, dir_path))

	# Optional: clear the App ID field for the user to fill
	var app_id_line_edit: LineEdit = card.get_node_or_null("%App_ID_LineEdit")
	if app_id_line_edit:
		app_id_line_edit.text = ""

# ===============================
# VDF Parsers
# ===============================

func _parse_vdf_for_depots(vdf_path: String) -> Array[String]:
	var depots: Array[String] = []
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return depots
	
	var inside_depots := false
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("\"depots\""):
			inside_depots = true
			continue
		
		if inside_depots:
			if line.begins_with("}"):
				break
			
			var tokens = line.split("\"", false)
			var clean_tokens: Array[String] = []
			for t in tokens:
				var trimmed = t.strip_edges()
				if not trimmed.is_empty():
					clean_tokens.append(trimmed)
			
			if clean_tokens.size() >= 2:
				var depot_id = clean_tokens[0]
				if depot_id.is_valid_int():
					depots.append(depot_id)
		
	file.close()
	return depots

func _parse_depot_vdf_for_contentroot(vdf_path: String) -> String:
	var file := FileAccess.open(vdf_path, FileAccess.READ)
	if not file:
		return ""
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.begins_with("\"contentroot\""):
			var tokens = line.split("\"", false)
			if tokens.size() >= 3:
				var path = tokens[2].strip_edges()
				file.close()
				return path
	file.close()
	return ""


# ===============================
# Helpers
# ===============================

func _clear_depot_cards() -> void:
	for child in app_list_container.get_children():
		child.queue_free()


# ===============================
# Animations
# ===============================

# ===============================
# Animations
# ===============================

func _play_error_animation() -> void:
	if feedback_tween and feedback_tween.is_running():
		feedback_tween.kill()
	
	feedback_tween = create_tween()
	content_builder_path_line_edit.modulate = Color(1, 0.4, 0.4) # red tint
	feedback_tween.tween_property(content_builder_path_line_edit, "modulate", Color(1, 1, 1), 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_success_animation() -> void:
	if feedback_tween and feedback_tween.is_running():
		feedback_tween.kill()
	
	feedback_tween = create_tween()
	content_builder_path_line_edit.modulate = Color(0.4, 1, 0.4) # green tint
	feedback_tween.tween_property(content_builder_path_line_edit, "modulate", Color(1, 1, 1), 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
