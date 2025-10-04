class_name SaveConfirmation extends PopupContainer

signal confirm_save

@onready var _label: Label = %Label
@onready var _exit_button: Button = %Exit


func _ready() -> void:
	super._ready()

	_exit_button.pressed.connect(self.confirm_save.emit)


func confirm(slot_index: int, save_data: SaveData) -> void:
	show()
	SaveManager.create_save(slot_index, save_data)
	_label.text = "Saved to Slot #{slot_number}".format({slot_number = slot_index + 1})
	_exit_button.show()
