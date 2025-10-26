class_name SaveSlot extends Control

signal pressed
signal delete

const DEFAULT_CARD_TEXTURE = preload("res://assets/sprites/ui/buttons/blank-card.png")

var save_data: SaveData = null
var slot_index: int = -1:
	set(value):
		slot_index = value
		refresh()

@onready var _card_container: Control = %CardContainer
@onready var _card: TextureRect = %Card
@onready var _card_label: Label = %CardLabel
@onready var _slot_label: Label = %SlotLabel
@onready var _delete_button: TextureButton = %Delete


func _ready() -> void:
	_update_slot_label()
	_display_save_data()
	_card_container.gui_input.connect(_on_gui_input)
	_delete_button.pressed.connect(func(): self.delete.emit(slot_index))


func refresh() -> void:
	save_data = SaveManager.load_save(slot_index)
	_update_slot_label()
	_display_save_data()


func _update_slot_label() -> void:
	_slot_label.text = "Slot #{slot_number}".format({slot_number = slot_index + 1})


func _display_save_data() -> void:
	if slot_index == -1:
		return

	if save_data == null:
		_card.texture = DEFAULT_CARD_TEXTURE
		_card_label.show()
		_delete_button.hide()
	else:
		var first_pack: PackData = PackDataLoader.load_pack_from_path(
			save_data.card_groups[0].pack_path
		)
		_card.texture = first_pack.backs[0]
		_card_label.hide()
		_delete_button.show()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed == true:
		self.pressed.emit(slot_index)
