class_name PackSelectCard extends TextureRect

signal pressed(pack_data: PackData, button_index: int)

var pack_data: PackData:
	set(value):
		pack_data = value
		_set_back()


func _ready() -> void:
	gui_input.connect(_on_gui_input)

	if pack_data:
		_set_back()


func _set_back() -> void:
	texture = pack_data.backs[0]


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_pressed()
		and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT)
	):
		self.pressed.emit(pack_data, event.button_index)
