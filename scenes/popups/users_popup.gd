extends Control
class_name UsersPopup

@onready var steam_username_line_edit: LineEdit = %Steam_Username_LineEdit
@onready var steam_password_line_edit: LineEdit = %Steam_Password_LineEdit
@onready var save_button: Button = %Save_Button
@onready var saved_button: Button = %Saved_Button
@onready var add_user_button: Button = %Add_User_Button
@onready var users_list_container: VBoxContainer = %Users_List_Container

var is_saved: bool = false

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	saved_button.pressed.connect(_on_saved_pressed)
	add_user_button.pressed.connect(_on_add_user_pressed)
	
	save_button.visible = true
	saved_button.visible = false
	
	_load_users_from_config()

func _on_save_pressed() -> void:
	save_button.visible = false
	saved_button.visible = true
	is_saved = true

func _on_saved_pressed() -> void:
	saved_button.visible = false
	save_button.visible = true
	is_saved = false

func _on_add_user_pressed() -> void:
	var username := steam_username_line_edit.text.strip_edges()
	var password := steam_password_line_edit.text.strip_edges()
	
	if username == "" or password == "":
		push_warning("Both username and password must be filled before adding a user.")
		return
	
	if is_saved:
		SettingManager.save_user(username, password, false)
	
	var user_data = {
		"username": username,
		"password": password,
		"is_selected": false
	}
	_add_user_card(user_data)
	
	steam_username_line_edit.text = ""
	steam_password_line_edit.text = ""

func _add_user_card(user_data: Dictionary) -> void:
	var card: SteamUserCard = SceneManager.STEAM_USER_CARD.instantiate()
	card.user_selected.connect(_on_user_selected)
	
	var remove_button: Button = card.get_node("%Remove_User_Button")
	remove_button.pressed.connect(_on_remove_card_pressed.bind(card))
	
	users_list_container.add_child(card)
	
	card.setup(user_data)

func _on_remove_card_pressed(card: SteamUserCard) -> void:
	var username = card.username
	card.queue_free()
	
	if SettingManager.config.has_section_key("users", username):
		SettingManager.config.erase_section_key("users", username)
		SettingManager.save_settings()

func _on_user_selected(selected_card: SteamUserCard, is_selected: bool) -> void:
	for child in users_list_container.get_children():
		if child is SteamUserCard:
			child.is_selected_user = (child == selected_card and is_selected)
			child._update_button_state(child.is_selected_user)

func _load_users_from_config() -> void:
	var users = SettingManager.load_users()
	
	if users.is_empty():
		print("⚠️ No [users] section in config or no valid users.")
		return
	
	for username in users.keys():
		var user_data = users[username]
		if typeof(user_data) == TYPE_DICTIONARY:
			var saved_username = user_data.get("username", "")
			var saved_password = user_data.get("password", "")
			
			if saved_username != "" and saved_password != "":
				_add_user_card(user_data)
