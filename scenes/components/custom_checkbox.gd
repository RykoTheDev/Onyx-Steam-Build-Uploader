extends Button
class_name CustomCheckbox

@onready var check_icon: TextureRect = $Icon

func _ready() -> void:
	toggle_mode = true
	check_icon.scale = Vector2.ZERO
	check_icon.visible = false

	if button_pressed:
		_show_icon()
	else:
		_hide_icon(true)

	pressed.connect(_on_toggled)

func _on_toggled() -> void:
	if button_pressed:
		_show_icon()
	else:
		_hide_icon()

func _show_icon() -> void:
	check_icon.visible = true
	check_icon.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(check_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_icon(initial := false) -> void:
	if initial:
		check_icon.visible = false
		check_icon.scale = Vector2.ZERO
		return

	var tween = create_tween()
	tween.tween_property(check_icon, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func(): check_icon.visible = false)

func is_checked() -> bool:
	return button_pressed

func set_checked(value: bool) -> void:
	button_pressed = value
	if button_pressed:
		_show_icon()
	else:
		_hide_icon()
