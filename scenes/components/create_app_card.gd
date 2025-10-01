extends PanelContainer
class_name CreateDepotCard

@onready var header_button: Button = $Header_Button
@onready var content: Control = %Scroll_Container
var tween: Tween

var is_open := false
var collapsed_height := 0.0

func _ready() -> void:
	content.custom_minimum_size.y = collapsed_height
	content.visible = false
	header_button.pressed.connect(_on_header_pressed)

	var inner = content.get_child(0) if content.get_child_count() > 0 else null
	if inner:
		inner.child_entered_tree.connect(_on_child_changed)
		inner.child_exiting_tree.connect(_on_child_changed)

func _on_header_pressed() -> void:
	is_open = !is_open
	_animate_fold(is_open)

func _animate_fold(open: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()

	if open:
		await get_tree().process_frame
		content.visible = true
		var expanded_height = _get_content_height()
		tween.tween_property(content, "custom_minimum_size:y", expanded_height, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_after_open)
	else:
		tween.tween_property(content, "custom_minimum_size:y", collapsed_height, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(_after_close)

func _get_content_height() -> float:
	var total_height := 0.0
	for child in content.get_children():
		if child is Control:
			total_height += child.get_combined_minimum_size().y
	return max(total_height, 100)

func _after_open() -> void:
	content.custom_minimum_size.y = _get_content_height()

func _after_close() -> void:
	content.visible = false

func _on_child_changed(_child: Node) -> void:
	if is_open:
		var new_height = _get_content_height()
		if tween and tween.is_running():
			tween.kill()
		content.custom_minimum_size.y = new_height
