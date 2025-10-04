class_name LoadGameDialog extends PopupContainer

var _selected_slot: int = -1

@onready var _save_slots: Array[SaveSlot] = [%SaveSlot, %SaveSlot2, %SaveSlot3]
@onready var _delete_confirmation: DeleteConfirmation = %DeleteConfirmation
@onready var _load_confirmation: LoadConfirmation = %LoadConfirmation


func _ready() -> void:
	super._ready()

	var slot_index = 0
	for slot in _save_slots:
		slot.slot_index = slot_index
		slot.pressed.connect(_on_save_slot_selected)
		slot.delete.connect(_on_save_slot_delete_selected)
		slot_index += 1

	_delete_confirmation.closing.connect(_on_popup_closing)
	_load_confirmation.closing.connect(_on_popup_closing)

	_delete_confirmation.confirm_delete.connect(_on_delete_confirmed)
	_load_confirmation.confirm_load.connect(_on_load_confirmed)


func _on_save_slot_selected(slot_index: int) -> void:
	if _save_slots[slot_index].save_data != null:
		_selected_slot = slot_index
		_load_confirmation.confirm(slot_index)


func _on_save_slot_delete_selected(slot_index: int) -> void:
	if _delete_confirmation.visible or _load_confirmation.visible:
		return

	_selected_slot = slot_index

	_delete_confirmation.confirm(slot_index)


func _on_popup_closing() -> void:
	_selected_slot = -1


func _on_delete_confirmed() -> void:
	SaveManager.delete_save(_selected_slot)
	_delete_confirmation.hide()
	_save_slots[_selected_slot].refresh()
	_selected_slot = -1


func _on_load_confirmed() -> void:
	var save_data = _save_slots[_selected_slot].save_data

	RunManager.save_data = save_data

	get_tree().change_scene_to_packed(load("res://source/game/game.tscn"))
