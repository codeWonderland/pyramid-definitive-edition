class_name DeleteConfirmation extends PopupContainer

signal confirm_delete

@onready var _label: Label = %Label
@onready var _confirm_button: Button = %Confirm
@onready var _cancel_button: Button = %Cancel


func _ready() -> void:
	super._ready()

	_confirm_button.pressed.connect(self.confirm_delete.emit)
	_cancel_button.pressed.connect(_close)


func confirm(slot_index: int) -> void:
	_label.text = "Delete Slot #{slot_number}".format({slot_number = slot_index + 1})
	show()
