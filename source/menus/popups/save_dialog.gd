class_name SaveDialog extends PopupContainer

signal save_confirmed(should_save: bool)

@onready var _save_button: Button = %Save
@onready var _no_save_button: Button = %NoSave


func _ready() -> void:
	super._ready()

	_save_button.pressed.connect(self.save_confirmed.emit.bind(true))
	_no_save_button.pressed.connect(self.save_confirmed.emit.bind(false))
