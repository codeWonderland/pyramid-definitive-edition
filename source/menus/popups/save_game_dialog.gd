class_name SaveGameDialog extends PopupContainer

var save_data: SaveData = null
var _selected_slot: int = -1

@onready var _save_slots: Array[SaveSlot] = [%SaveSlot, %SaveSlot2, %SaveSlot3]
@onready var _delete_confirmation: DeleteConfirmation = %DeleteConfirmation
@onready var _overwrite_confirmation: OverwriteConfirmation = %OverwriteConfirmation
@onready var _save_confirmation: SaveConfirmation = %SaveConfirmation


func _ready() -> void:
	super._ready()

	var slot_index = 0
	for slot in _save_slots:
		slot.slot_index = slot_index
		slot.pressed.connect(_on_save_slot_selected)
		slot.delete.connect(_on_save_slot_delete_selected)
		slot_index += 1

	_delete_confirmation.closing.connect(_on_popup_closing)
	_save_confirmation.closing.connect(_on_popup_closing)
	_overwrite_confirmation.closing.connect(_on_popup_closing)

	_delete_confirmation.confirm_delete.connect(_on_delete_confirmed)
	_save_confirmation.confirm_save.connect(_on_save_confirmed)
	_overwrite_confirmation.confirm_overwrite.connect(_on_overwrite_confirmed)


func _on_save_slot_selected(slot_index: int) -> void:
	_selected_slot = slot_index

	if _save_slots[slot_index].save_data == null:
		_save_confirmation.confirm(slot_index, save_data)
	else:
		_overwrite_confirmation.confirm(slot_index)


func _on_save_slot_delete_selected(slot_index: int) -> void:
	if (
		_delete_confirmation.visible
		or _overwrite_confirmation.visible
		or _save_confirmation.visible
	):
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


func _on_save_confirmed() -> void:
	get_tree().change_scene_to_packed(load("res://source/menus/main_menu.tscn"))


func _on_overwrite_confirmed() -> void:
	_overwrite_confirmation.hide()
	_save_confirmation.confirm(_selected_slot, save_data)
