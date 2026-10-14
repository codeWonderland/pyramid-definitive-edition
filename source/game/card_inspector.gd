class_name CardInspector extends Control

## Shows one card large so its challenge text can be read: the card grows out of
## where it was clicked over a dimmed screen, and clicking anywhere - or Escape -
## shrinks it back. No window or close button; it's the card itself, held up.
## Opened by right-clicking a card on the table, or clicking one in the library.

signal closing

const OPEN_TIME: float = 0.2
const CLOSE_TIME: float = 0.15
## How much of the screen's height the card fills, and at most of its width.
const HEIGHT_SHARE: float = 0.85
const WIDTH_SHARE: float = 0.9
## Without a card to grow out of, it grows from this much of its full size.
const START_SHARE: float = 0.8

var _from_rect: Rect2 = Rect2()
var _closing_now: bool = false
var _tween: Tween = null

@onready var _backdrop: ColorRect = %Backdrop
@onready var _card_image: TextureRect = %CardImage


func _ready() -> void:
	gui_input.connect(_on_clicked)
	get_tree().get_root().size_changed.connect(_on_screen_resized)


## Shows `card_texture` large, growing out of `from_rect` (in screen
## coordinates) when given - the card that was clicked.
func show_card(card_texture: Texture2D, from_rect: Rect2 = Rect2()) -> void:
	_card_image.texture = card_texture
	_closing_now = false
	_cover_screen()

	var target := _large_rect()
	_from_rect = from_rect
	if not _from_rect.has_area():
		var start_size := target.size * START_SHARE
		_from_rect = Rect2(target.get_center() - start_size / 2, start_size)

	_card_image.position = _from_rect.position
	_card_image.size = _from_rect.size
	_backdrop.modulate.a = 0.0
	show()
	_animate(target, 1.0, OPEN_TIME, Tween.EASE_OUT)


## Escape puts the card away again.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("Escape"):
		_close()
		get_viewport().set_input_as_handled()


## A click anywhere - on the card or off it - puts it away.
func _on_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
		accept_event()


## Shrinks the card back to where it came from, then hides. `closing` goes out at
## once, so whatever opened it can carry on while it shrinks.
func _close() -> void:
	if not visible or _closing_now:
		return
	_closing_now = true
	self.closing.emit()

	_animate(_from_rect, 0.0, CLOSE_TIME, Tween.EASE_IN)
	await _tween.finished
	if _closing_now:
		_closing_now = false
		hide()


func _animate(card_rect: Rect2, backdrop_alpha: float, time: float, easing: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_tween.tween_property(_card_image, "position", card_rect.position, time)
	_tween.tween_property(_card_image, "size", card_rect.size, time)
	_tween.tween_property(_backdrop, "modulate:a", backdrop_alpha, time)


## The card at full size, centred, in the texture's own proportions.
func _large_rect() -> Rect2:
	var screen := size
	var texture := _card_image.texture
	var aspect := 0.7
	if texture != null and texture.get_height() > 0:
		aspect = float(texture.get_width()) / texture.get_height()

	var card := Vector2(screen.y * HEIGHT_SHARE * aspect, screen.y * HEIGHT_SHARE)
	if card.x > screen.x * WIDTH_SHARE:
		card *= screen.x * WIDTH_SHARE / card.x
	return Rect2((screen - card) / 2, card)


func _cover_screen() -> void:
	global_position = Vector2.ZERO
	size = get_viewport_rect().size


func _on_screen_resized() -> void:
	if not visible or _closing_now:
		return
	_cover_screen()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target := _large_rect()
	_card_image.position = target.position
	_card_image.size = target.size
