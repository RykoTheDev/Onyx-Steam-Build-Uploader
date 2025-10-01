extends Control
class_name SetupPopup

@onready var content_builder_path_line_edit: LineEdit = %Content_Builder_Path_LineEdit
@onready var content_builder_browse_button: Button = %Content_Builder_Browse_Button
@onready var app_list_container: VBoxContainer = %Apps_List_Container
@onready var generate_vdfs_button: Button = %Generate_VDFs_Button

var app_vdf_template_path: String = "res://templates/app_template.md"
var depot_vdf_template_path: String = "res://templates/depot_template.md"

var error_label: Label
var file_dialog: FileDialog
var feedback_tween: Tween

func _ready() -> void:
	# ===============================
	# Error label (absolute positioned)
	# ===============================
	error_label = Label.new()
	error_label.modulate = Color(1, 0.4, 0.4)
	error_label.visible = false
	error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_label.add_theme_font_size_override("font_size", 11)
	add_child(error_label)
	error_label.anchor_left = 0
	error_label.anchor_top = 0
	error_label.anchor_right = 0
	error_label.anchor_bottom = 0
	_update_error_label_position()
	
	# ===============================
	# File Dialog
	# ===============================
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	add_child(file_dialog)
	
	content_builder_browse_button.pressed.connect(_on_browse_button_pressed)
	file_dialog.dir_selected.connect(_on_dir_selected)
	
	var create_app_button: Button = %Create_App_Button
	if create_app_button:
		create_app_button.pressed.connect(_on_create_app_button_pressed)
	
	if generate_vdfs_button:
		generate_vdfs_button.pressed.connect(_on_generate_vdfs_pressed)


# ===============================
# Error label helpers
# ===============================
func _update_error_label_position() -> void:
	var lineedit_global_pos = content_builder_path_line_edit.get_global_position()
	error_label.position = lineedit_global_pos + Vector2(25, content_builder_path_line_edit.size.y + 45)

func _show_error(text: String) -> void:
	error_label.text = text
	error_label.visible = true
	_play_error_animation()

func _hide_error() -> void:
	error_label.visible = false

# ===============================
# Browse and validation
# ===============================
func _on_browse_button_pressed() -> void:
	file_dialog.popup_centered()

func _on_dir_selected(dir_path: String) -> void:
	content_builder_path_line_edit.text = dir_path
	if _is_valid_content_builder_path(dir_path):
		_hide_error()
		_add_depot_card(dir_path)
		_play_success_animation()
	else:
		_show_error("Invalid ContentBuilder folder!")
		_clear_depot_cards()

func _is_valid_content_builder_path(dir_path: String) -> bool:
	var required = ["content", "output", "scripts"]
	for sub in required:
		if not DirAccess.dir_exists_absolute(dir_path.path_join(sub)):
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
	
	var delete_app_button: Button = card.get_node_or_null("%Delete_App_Button")
	if delete_app_button:
		delete_app_button.pressed.connect(_on_delete_app_button_pressed.bind(card))
	var app_id_line_edit: LineEdit = card.get_node_or_null("%App_ID_LineEdit")
	if app_id_line_edit:
		app_id_line_edit.text = app_id
	
	var depots_container: VBoxContainer = card.get_node_or_null("%Depots_List_Container")
	if not depots_container:
		return
	
	var add_button: Button = card.get_node_or_null("%App_Depot_Button")
	if add_button:
		add_button.pressed.connect(_on_add_depot_button_pressed.bind(depots_container, dir_path))
	
	for child in depots_container.get_children():
		child.queue_free()
	depots_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	for depot_id in _parse_vdf_for_depots(vdf_path):
		_create_depot_card(depots_container, dir_path, depot_id)

func _create_depot_card(depots_container: VBoxContainer, dir_path: String, depot_id: String = "") -> void:
	for child in depots_container.get_children():
		if child is Label:
			child.queue_free()
	
	var depot_card: Control = SceneManager.CREATE_DEPOT_CARD.instantiate()
	depot_card.set_meta("content_builder_path", dir_path)
	if depot_id != "":
		depot_card.set_meta("depot_id", depot_id)
	depots_container.add_child(depot_card)
	
	var depot_id_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_ID_LineEdit")
	if depot_id_line_edit and depot_id != "":
		depot_id_line_edit.text = depot_id
	
	if depot_id != "":
		var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
		var depot_contentroot = _parse_depot_vdf_for_contentroot(depot_vdf_path)
		var depot_path_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_Path_LineEdit")
		if depot_path_line_edit and depot_contentroot != "":
			depot_path_line_edit.text = depot_contentroot
	
	var delete_button: Button = depot_card.get_node_or_null("%Delete_Depot_Button")
	if delete_button:
		delete_button.pressed.connect(_on_delete_depot_button_pressed.bind(depot_card))

# ===============================
# Add/Delete handlers
# ===============================
func _on_add_depot_button_pressed(depots_container: VBoxContainer, dir_path: String) -> void:
	_create_depot_card(depots_container, dir_path)

func _on_delete_depot_button_pressed(depot_card: Control) -> void:
	var dir_path: String = depot_card.get_meta("content_builder_path", "")
	var depot_id: String = depot_card.get_meta("depot_id", "")
	if dir_path == "" or depot_id == "":
		depot_card.queue_free()
		return
	
	var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
	if FileAccess.file_exists(depot_vdf_path):
		if DirAccess.remove_absolute(depot_vdf_path) != OK:
			printerr("❌ Failed to delete: ", depot_vdf_path)
		else:
			print("🗑️ Deleted depot file: ", depot_vdf_path)
	
	depot_card.queue_free()

func _on_create_app_button_pressed() -> void:
	var dir_path = content_builder_path_line_edit.text.strip_edges()
	if dir_path == "":
		_show_error("Add a path first!")
		return
	
	if not _is_valid_content_builder_path(dir_path):
		_show_error("Invalid ContentBuilder folder!")
		return
	
	_hide_error()
	var card: Control = SceneManager.CREATE_APP_CARD.instantiate()
	card.set_meta("content_builder_path", dir_path)
	app_list_container.add_child(card)
	
	var delete_app_button: Button = card.get_node_or_null("%Delete_App_Button")
	if delete_app_button:
		delete_app_button.pressed.connect(_on_delete_app_button_pressed.bind(card))
		
	var depots_container: VBoxContainer = card.get_node_or_null("%Depots_List_Container")
	if depots_container:
		depots_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		var add_button: Button = card.get_node_or_null("%App_Depot_Button")
		if add_button:
			add_button.pressed.connect(_on_add_depot_button_pressed.bind(depots_container, dir_path))
		
	var app_id_line_edit: LineEdit = card.get_node_or_null("%App_ID_LineEdit")
	if app_id_line_edit:
		app_id_line_edit.text = ""

func _on_delete_app_button_pressed(app_card: Control) -> void:
	var dir_path: String = app_card.get_meta("content_builder_path", "")
	if dir_path == "":
		app_card.queue_free()
		return
		
	var app_id_line_edit: LineEdit = app_card.get_node_or_null("%App_ID_LineEdit")
	if not app_id_line_edit:
		app_card.queue_free()
		return
	var app_id = app_id_line_edit.text.strip_edges()
	if app_id == "":
		app_card.queue_free()
		return
		
	var app_vdf_path = dir_path.path_join("scripts").path_join("app_%s.vdf" % app_id)
	if FileAccess.file_exists(app_vdf_path):
		if DirAccess.remove_absolute(app_vdf_path) != OK:
			printerr("❌ Failed to delete: ", app_vdf_path)
		else:
			print("🗑️ Deleted app file: ", app_vdf_path)
		
	var depots_container: VBoxContainer = app_card.get_node_or_null("%Depots_List_Container")
	if depots_container:
		for depot_card in depots_container.get_children():
			var depot_id_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_ID_LineEdit")
			if depot_id_line_edit and depot_id_line_edit.text.strip_edges() != "":
				var depot_id = depot_id_line_edit.text.strip_edges()
				var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
				if FileAccess.file_exists(depot_vdf_path):
					if DirAccess.remove_absolute(depot_vdf_path) == OK:
						print("🗑️ Deleted depot file for app: ", depot_vdf_path)
		
	app_card.queue_free()

func _on_generate_vdfs_pressed() -> void:
	var dir_path = content_builder_path_line_edit.text.strip_edges()
	if not _is_valid_content_builder_path(dir_path):
		_show_error("Invalid ContentBuilder folder!")
		return

	for app_card in app_list_container.get_children():
		var app_id_line_edit: LineEdit = app_card.get_node_or_null("%App_ID_LineEdit")
		if not app_id_line_edit:
			continue
		var app_id = app_id_line_edit.text.strip_edges()
		if app_id == "":
			continue
		
		# === DEPOTS for this app ===
		var depots_container: VBoxContainer = app_card.get_node_or_null("%Depots_List_Container")
		var depot_lines: Array[String] = []
		if depots_container:
			for depot_card in depots_container.get_children():
				var depot_id_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_ID_LineEdit")
				var depot_path_line_edit: LineEdit = depot_card.get_node_or_null("%Depot_Path_LineEdit")
				if not depot_id_line_edit or depot_id_line_edit.text.strip_edges() == "":
					continue
				
				var depot_id = depot_id_line_edit.text.strip_edges()
				var depot_contentroot = depot_path_line_edit.text.strip_edges() if depot_path_line_edit else ""
				
				var depot_vdf_path = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
				if not FileAccess.file_exists(depot_vdf_path):
					_write_vdf_from_template(depot_vdf_template_path, depot_vdf_path, {
						"DEPOT_ID": depot_id,
						"APP_ID": app_id,
						"CONTENTROOT": depot_contentroot
					})
			
				var depot_vdf_relpath = dir_path.path_join("scripts").path_join("depot_%s.vdf" % depot_id)
				depot_lines.append("\t\t\"%s\" \"%s\"" % [depot_id, depot_vdf_relpath])
			
		
		# === APP VDF ===
		var depots_text = "\n".join(depot_lines)
		if depots_text == "":
			depots_text = "\t\t// No depots"
		
		var app_vdf_path = dir_path.path_join("scripts").path_join("app_%s.vdf" % app_id)
		_write_vdf_from_template(app_vdf_template_path, app_vdf_path, {
			"APP_ID": app_id,
			"DEPOT_ID": "",
			"DEPOT_PATH": "",
			"DEPOTS_BLOCK": depots_text
		})

# ===============================
# VDF Parsers
# ===============================

func _write_vdf_from_template(template_path: String, target_path: String, replacements: Dictionary) -> void:
	var template_file := FileAccess.open(template_path, FileAccess.READ)
	if not template_file:
		printerr("❌ Could not open template: ", template_path)
		return
	
	var content = template_file.get_as_text()
	template_file.close()
	
	for key in replacements.keys():
		content = content.replace("{%s}" % key, replacements[key])
	
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if not file:
		printerr("❌ Could not write VDF: ", target_path)
		return
	file.store_string(content)
	file.close()
	print("✅ Created VDF: ", target_path)


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
func _play_error_animation() -> void:
	if feedback_tween and feedback_tween.is_running():
		feedback_tween.kill()
	feedback_tween = create_tween()
	content_builder_path_line_edit.modulate = Color(1, 0.4, 0.4)
	feedback_tween.tween_property(content_builder_path_line_edit, "modulate", Color(1, 1, 1), 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_success_animation() -> void:
	if feedback_tween and feedback_tween.is_running():
		feedback_tween.kill()
	feedback_tween = create_tween()
	content_builder_path_line_edit.modulate = Color(0.4, 1, 0.4)
	feedback_tween.tween_property(content_builder_path_line_edit, "modulate", Color(1, 1, 1), 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
