extends PanelContainer

@onready var main_panel: PanelContainer = %Main_Panel
@onready var no_apps_panel: PanelContainer = %No_Apps_Panel

@onready var no_apps_set_directory_button: Button = %No_Apps_Set_Directory_Button
@onready var no_apps_refresh_button: Button = %No_Apps_Refresh_Button
@onready var setup_button: Button = %Setup_Button

@onready var popups_layer: CanvasLayer = %PopupsLayer

func _ready() -> void:
	no_apps_set_directory_button.pressed.connect(_on_no_apps_set_directory_pressed)
	setup_button.pressed.connect(_on_no_apps_set_directory_pressed)

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
	tween.finished.connect(func(): popup_scene.queue_free())
