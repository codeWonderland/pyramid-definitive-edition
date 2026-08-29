class_name CardInspector extends PopupContainer

## Shows a single card large and centred so its challenge text can actually be
## read. Opened by right-clicking a card on the table.

@onready var _card_image: TextureRect = %CardImage


func _ready() -> void:
	super._ready()
	gui_input.connect(_on_clicked)


func show_card(card_texture: Texture2D) -> void:
	_card_image.texture = card_texture
	show()


## Escape puts the card away again - the overlay exists to be read and
## dismissed, so it should not need aiming at the close button.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("Escape"):
		_close()
		get_viewport().set_input_as_handled()


## Clicking the card itself dismisses it too.
func _on_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
