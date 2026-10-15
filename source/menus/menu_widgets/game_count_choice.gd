class_name GameCountChoice extends Button

## One answer to "how many games this run?", shown as that many cards rather than
## a bare number - a single card, a small stack, a pile - so it reads as a size
## and not as part of "135". The cards are the backs of the games the player
## drafted. Hovering or focusing fans them out a little.

const CARD_SIZE: Vector2 = Vector2(180, 257)
## How far each card turns away from the one before it, in degrees, at rest and
## when the choice is hovered.
const FAN_DEGREES: float = 6.0
const FAN_DEGREES_HOVER: float = 11.0
## How far each card sits from the one before it, in pixels.
const FAN_STEP: float = 18.0
const FAN_STEP_HOVER: float = 34.0
const FAN_TIME: float = 0.15
## The caption's colour when the choice is hovered or focused, matching the menu
## text's highlight.
const HIGHLIGHT: Color = Color(1, 0.82, 0.38, 1)

@export var count: int = 1

var _cards: Array[TextureRect] = []
var _spread: float = 0.0

@onready var _pile: Control = %Pile
@onready var _caption: Label = %Caption


func _ready() -> void:
	_caption.text = "%d game" % count if count == 1 else "%d games" % count
	mouse_entered.connect(_fan.bind(1.0))
	mouse_exited.connect(_fan.bind(0.0))
	focus_entered.connect(_fan.bind(1.0))
	focus_exited.connect(_fan.bind(0.0))
	_pile.resized.connect(_lay_out)


## Deals `count` cards from `backs`, repeating them if there are fewer.
func set_backs(backs: Array[Texture2D]) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	for i in range(count):
		var card := TextureRect.new()
		card.texture = backs[i % backs.size()] if not backs.is_empty() else null
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.size = CARD_SIZE
		card.pivot_offset = Vector2(CARD_SIZE.x / 2, CARD_SIZE.y)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pile.add_child(card)
		_cards.append(card)
	_lay_out()


func _fan(to: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_spread, _spread, to, FAN_TIME)


func _set_spread(value: float) -> void:
	_spread = value
	_caption.modulate = Color.WHITE.lerp(HIGHLIGHT, value)
	_lay_out()


## Fans the cards about the middle one, bottoms together, like a hand of cards.
func _lay_out() -> void:
	var degrees := lerpf(FAN_DEGREES, FAN_DEGREES_HOVER, _spread)
	var step := lerpf(FAN_STEP, FAN_STEP_HOVER, _spread)
	var middle := (_cards.size() - 1) / 2.0
	var centre := Vector2((_pile.size.x - CARD_SIZE.x) / 2, (_pile.size.y - CARD_SIZE.y) / 2)
	for i in _cards.size():
		var offset := i - middle
		_cards[i].position = centre + Vector2(offset * step, absf(offset) * step * 0.25)
		_cards[i].rotation_degrees = offset * degrees
