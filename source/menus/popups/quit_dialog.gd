class_name QuitDialog extends PopupContainer

signal confirm_quit

@onready var _quit_button: Button = %Quit
@onready var _cancel_button: Button = %Cancel


func _ready() -> void:
	super._ready()

	_quit_button.pressed.connect(self.confirm_quit.emit)
	_cancel_button.pressed.connect(_close)
