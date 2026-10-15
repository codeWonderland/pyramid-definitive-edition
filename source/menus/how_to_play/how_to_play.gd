class_name HowToPlay extends PopupContainer

## A screen's "How to play" card. Each screen that has one sets `page` in its
## scene and calls show_if_new() on arrival: the card shows the first time a
## player reaches that screen, and not again until they ask for the cards back
## in the settings menu.

## How wide the card is, against the 1920x1080 reference.
const WIDTH: float = 900.0
## How long to wait after arriving, so the card comes up once the scene fade has
## lifted rather than under it.
const ARRIVAL_DELAY: float = 0.45

@export var page: HowToPlayPage

@onready var _title: Label = %Title
@onready var _tips: VBoxContainer = %Tips
@onready var _got_it: Button = %GotIt


func _ready() -> void:
	super._ready()
	_got_it.pressed.connect(_close)


## Shows the card if this player hasn't seen it yet. Returns whether it will.
func show_if_new() -> bool:
	if not is_new():
		return false

	await get_tree().create_timer(ARRIVAL_DELAY).timeout
	show_page()
	return true


## Whether arriving should show the card: there is one, this player hasn't seen
## it, and someone is looking - headless runs are tests and tools, where a card
## popping up over the screen would only get in the way.
func is_new() -> bool:
	if page == null or DisplayServer.get_name() == "headless":
		return false
	return not UserSettingsManager.has_seen_how_to_play(page.id)


func show_page() -> void:
	_title.text = page.title
	for child in _tips.get_children():
		_tips.remove_child(child)
		child.queue_free()
	for tip in page.tips:
		var line := Label.new()
		line.text = "•  " + tip
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.theme_type_variation = &"SmallLabel"
		_tips.add_child(line)

	show()
	_resize.call_deferred()


func _close() -> void:
	if page != null:
		UserSettingsManager.mark_how_to_play_seen(page.id)
	super._close()


## Sized to its tips rather than most of the screen, and centred.
func _resize() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	var scale_mult := minf(screen_size.x / 1920.0, screen_size.y / 1080.0)
	scale = Vector2(scale_mult, scale_mult)
	size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, get_combined_minimum_size().y)
	position = screen_size / 2 - size * scale / 2
