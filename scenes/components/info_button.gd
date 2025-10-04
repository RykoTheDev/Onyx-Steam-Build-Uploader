extends Button

@export var link: String

func _ready() -> void:
	self.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	OS.shell_open(link)
	pass
