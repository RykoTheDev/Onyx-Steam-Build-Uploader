extends Control

@onready var watch_tutorial_button: Button = %Watch_Tutorial_Button
@onready var close_dont_show_again_button: Button = %Close_Dont_Show_Again_Button
@onready var close_on_update_button: Button = %Close_On_Update_Button
@onready var close_button: Button = %Close_Button

var PROJECT_VERSION = ProjectSettings.get("application/config/version")

func _ready() -> void:
	close_dont_show_again_button.pressed.connect(_on_never_show_again)
	close_on_update_button.pressed.connect(_on_show_on_update)
	close_button.pressed.connect(_on_show_every_time)
	
	if not should_show_welcome():
		queue_free()

func should_show_welcome() -> bool:
	var never_show = SettingManager.get_setting("welcome_popup", "never_show_again", false)
	if never_show:
		return false
	
	var show_on_update = SettingManager.get_setting("welcome_popup", "show_on_update_only", false)
	if show_on_update:
		var last_version = SettingManager.get_setting("welcome_popup", "last_version", "")
		if last_version == PROJECT_VERSION:
			return false
	
	return true

func _on_never_show_again() -> void:
	SettingManager.set_setting("welcome_popup", "never_show_again", true)
	SettingManager.set_setting("welcome_popup", "last_version", PROJECT_VERSION)
	queue_free()

func _on_show_on_update() -> void:
	SettingManager.set_setting("welcome_popup", "show_on_update_only", true)
	SettingManager.set_setting("welcome_popup", "never_show_again", false)
	SettingManager.set_setting("welcome_popup", "last_version", PROJECT_VERSION)
	queue_free()

func _on_show_every_time() -> void:
	SettingManager.set_setting("welcome_popup", "show_on_update_only", false)
	SettingManager.set_setting("welcome_popup", "never_show_again", false)
	SettingManager.set_setting("welcome_popup", "last_version", PROJECT_VERSION)
	queue_free()
