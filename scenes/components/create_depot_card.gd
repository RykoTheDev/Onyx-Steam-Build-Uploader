extends PanelContainer
class_name DepotCard

@onready var depot_browse_button: Button = %Depot_Browse_Button
@onready var depot_path_line_edit: LineEdit = %Depot_Path_LineEdit

var file_dialog: FileDialog

func _ready() -> void:
	file_dialog = FileDialog.new()
	file_dialog.set_file_mode(FileDialog.FILE_MODE_OPEN_DIR)
	file_dialog.set_access(FileDialog.ACCESS_FILESYSTEM)
	file_dialog.set_use_native_dialog(true)
	add_child(file_dialog)
	
	depot_browse_button.pressed.connect(_on_browse_button_pressed)
	file_dialog.dir_selected.connect(_on_dir_selected)

func _on_browse_button_pressed() -> void:
	file_dialog.popup_centered()

func _on_dir_selected(dir_path: String) -> void:
	depot_path_line_edit.text = dir_path
