extends Control
class_name SteamUserCard

@onready var steam_username_text: Label = %Steam_Username_Text
@onready var steam_password_text: Label = %Steam_Password_Text
@onready var select_user_button: Button = %Select_User_Button
@onready var selected_user_button: Button = %Selected_User_Button
@onready var remove_user_button: Button = %Remove_User_Button

var is_selected_user: bool = false
var username: String
var stored_password: String = ""

signal user_selected(card: SteamUserCard, is_selected: bool)

func _ready() -> void:
	select_user_button.pressed.connect(_on_select_pressed)
	selected_user_button.pressed.connect(_on_deselect_pressed)

func setup(user_data: Dictionary) -> void:
	username = user_data.get("username", "")
	stored_password = user_data.get("password", "")
	is_selected_user = user_data.get("is_selected", false)
	
	steam_username_text.text = username
	steam_password_text.text = "*".repeat(stored_password.length())
	
	_update_button_state(is_selected_user)

func _on_select_pressed() -> void:
	SettingManager.set_selected_user(username)
	is_selected_user = true
	_update_button_state(true)
	user_selected.emit(self, true)

func _on_deselect_pressed() -> void:
	SettingManager.clear_selected_user()
	is_selected_user = false
	_update_button_state(false)
	user_selected.emit(self, false)

func _update_button_state(is_selected: bool) -> void:
	is_selected_user = is_selected
	select_user_button.visible = not is_selected
	selected_user_button.visible = is_selected
