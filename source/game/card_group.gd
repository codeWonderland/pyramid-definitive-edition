class_name CardGroup extends Control

const CHALLENGE_CARD: PackedScene = preload("res://source/game/challenge_card.tscn")
const CURSE_FLY_TIME: float = 0.4
const PILE_Z: int = 2
const CARD_BASE_Z: int = 5

var pack: PackData = null:
	set(value):
		pack = value
		if not _loading_from_save and pack != null:
			_setup_new()

var _loading_from_save: bool = false

var _primary_deck: CardDeck = CardDeck.new()
var _secondary_deck: CardDeck = CardDeck.new()
var _primary_pile: CardPile = null
var _secondary_pile: CardPile = null
var _back_texture: Texture2D = null
# Every card currently on the table for this group (active, loose, curse).
var _table_cards: Array[ChallengeCard] = []
var _curse_card: ChallengeCard = null


func _ready() -> void:
	_resize()
	get_tree().get_root().size_changed.connect(_resize)


# --- Setup ---


func _clear_table() -> void:
	for card in _table_cards:
		if is_instance_valid(card):
			card.queue_free()
	_table_cards.clear()
	_curse_card = null

	if _primary_pile != null and is_instance_valid(_primary_pile):
		_primary_pile.queue_free()
	if _secondary_pile != null and is_instance_valid(_secondary_pile):
		_secondary_pile.queue_free()
	_primary_pile = null
	_secondary_pile = null


func _setup_new() -> void:
	_clear_table()
	_primary_deck = CardDeck.new()
	_primary_deck.build_primary(pack.primaries.size(), pack.curses.size())
	_secondary_deck = CardDeck.new()
	_secondary_deck.build_secondary(pack.secondaries.size())

	_build_piles()
	_deal_initial()


func _deal_initial() -> void:
	# The initial deal is just the first draw (no flip), so a run can start with
	# a curse already revealed in the curse slot.
	_draw_primary_card(false, false)

	if pack.secondaries.size() > 0:
		_draw_secondary_card(false, false)
	else:
		_secondary_pile.hide()


func _build_piles() -> void:
	_back_texture = pack.backs[0] if pack.backs.size() > 0 else null
	var card_size := _scaled_card_size()

	_primary_pile = _make_pile(_slot_position(false))
	_primary_pile.setup(_back_texture, card_size)
	_primary_pile.draw_requested.connect(_on_primary_draw_requested)

	_secondary_pile = _make_pile(_slot_position(true))
	_secondary_pile.setup(_back_texture, card_size)
	_secondary_pile.draw_requested.connect(_on_secondary_draw_requested)


func _make_pile(slot: Vector2) -> CardPile:
	var pile := CardPile.new()
	pile.z_as_relative = false
	pile.z_index = PILE_Z
	add_child(pile)
	pile.position = slot
	return pile


# --- Drawing ---


func _on_primary_draw_requested(start_dragging: bool) -> void:
	if RunManager.popup_open:
		return
	_draw_primary_card(true, start_dragging)


func _on_secondary_draw_requested(start_dragging: bool) -> void:
	if RunManager.popup_open:
		return
	_draw_secondary_card(true, start_dragging)


func _draw_primary_card(flip: bool, start_dragging: bool) -> void:
	var result := _primary_deck.draw_primary()
	if result.is_empty():
		_primary_pile.set_remaining(0)
		return

	var primary_entry: int = result["primary"]
	var card := _spawn_card(primary_entry, false, false, _slot_position(false), flip)
	if start_dragging:
		card.begin_drag_from_pile()

	if result.has("curse"):
		var curse_entry: int = result["curse"]
		_reveal_curse(curse_entry)

	_primary_pile.set_remaining(_primary_deck.size())


func _draw_secondary_card(flip: bool, start_dragging: bool) -> void:
	var entry := _secondary_deck.draw_secondary()
	if entry == -1:
		_secondary_pile.set_remaining(0)
		return

	var card := _spawn_card(entry, true, false, _slot_position(true), flip)
	if start_dragging:
		card.begin_drag_from_pile()

	_secondary_pile.set_remaining(_secondary_deck.size())


func _reveal_curse(curse_entry: int) -> void:
	# Only one curse is shown at a time; retire the previous one.
	if _curse_card != null and is_instance_valid(_curse_card):
		_table_cards.erase(_curse_card)
		_curse_card.queue_free()

	# Fly the curse from the primary pile to the curse slot.
	var card := _spawn_card(curse_entry, false, true, _slot_position(false), true)
	_curse_card = card

	var fly := card.create_tween()
	fly.tween_property(card, "position", _curse_slot_position(), CURSE_FLY_TIME).set_trans(
		Tween.TRANS_QUAD
	)


# --- Trash ---


func _on_card_trashed(card: ChallengeCard) -> void:
	_table_cards.erase(card)
	if card == _curse_card:
		_curse_card = null

	if card.deck_is_secondary:
		_secondary_deck.trash_to_bottom(card.deck_entry)
		_secondary_pile.set_remaining(_secondary_deck.size())
	else:
		_primary_deck.trash_to_bottom(card.deck_entry)
		_primary_pile.set_remaining(_primary_deck.size())

	card.queue_free()


# --- Card spawning ---


func _spawn_card(
	entry: int, is_secondary: bool, is_curse_card: bool, slot: Vector2, flip: bool
) -> ChallengeCard:
	var card := CHALLENGE_CARD.instantiate() as ChallengeCard
	card.is_curse = is_curse_card
	card.deck_entry = entry
	card.deck_is_secondary = is_secondary
	card.back_texture = _back_texture
	card.z_as_relative = false
	card.z_index = CARD_BASE_Z
	add_child(card)
	card.position = slot

	var front := _texture_for(entry, is_secondary)
	if flip:
		card.play_flip(front)
	else:
		card.texture = front

	card.request_trash.connect(_on_card_trashed)
	_table_cards.append(card)
	return card


func _texture_for(entry: int, is_secondary: bool) -> Texture2D:
	var index := CardDeck.decode_index(entry)
	if is_secondary:
		return pack.secondaries[index]
	if CardDeck.is_curse(entry):
		return pack.curses[index]
	return pack.primaries[index]


# --- Save / load ---


func generate_card_group_data() -> CardGroupData:
	var data := CardGroupData.new()
	data.pack_path = pack.folder_path
	data.primary_deck = _primary_deck.to_array()
	data.secondary_deck = _secondary_deck.to_array()

	var table: Array[Dictionary] = []
	for card in _table_cards:
		if not is_instance_valid(card):
			continue
		(
			table
			. append(
				{
					"entry": card.deck_entry,
					"secondary": card.deck_is_secondary,
					"curse": card.is_curse,
					"x": card.position.x,
					"y": card.position.y,
				}
			)
		)
	data.table_cards = table
	return data


func load_from_card_group_data(data: CardGroupData) -> void:
	_loading_from_save = true

	pack = PackDataLoader.load_pack_from_path(data.pack_path)
	if pack == null:
		push_warning("CardGroup: pack no longer available at %s" % data.pack_path)
		_loading_from_save = false
		return

	# Older saves predate the deck model: just start a fresh, shuffled game.
	if data.primary_deck.is_empty() and data.table_cards.is_empty():
		_setup_new()
		_loading_from_save = false
		return

	_clear_table()
	_primary_deck = CardDeck.new()
	_primary_deck.from_array(data.primary_deck)
	_secondary_deck = CardDeck.new()
	_secondary_deck.from_array(data.secondary_deck)

	_build_piles()
	for saved in data.table_cards:
		_restore_card(saved)

	_primary_pile.set_remaining(_primary_deck.size())
	_secondary_pile.set_remaining(_secondary_deck.size())
	if pack.secondaries.is_empty():
		_secondary_pile.hide()

	_loading_from_save = false


func _restore_card(saved: Dictionary) -> void:
	var entry: int = saved.get("entry", 0)
	var is_secondary: bool = saved.get("secondary", false)
	var is_curse_card: bool = saved.get("curse", false)
	var pos := Vector2(saved.get("x", 0.0), saved.get("y", 0.0))

	var card := _spawn_card(entry, is_secondary, is_curse_card, pos, false)
	if is_curse_card:
		_curse_card = card


# --- Layout ---


func _scaled_card_size() -> Vector2:
	var screen_size := get_viewport().size as Vector2
	var scale_mult := screen_size.x / 1280.0
	if screen_size.y / 720.0 < scale_mult:
		scale_mult = screen_size.y / 720.0
	return RunManager.get_card_size() * scale_mult


func _slot_position(is_secondary: bool) -> Vector2:
	if is_secondary:
		return Vector2(_scaled_card_size().x, 0.0)
	return Vector2.ZERO


func _curse_slot_position() -> Vector2:
	var card_size := _scaled_card_size()
	return Vector2(card_size.x * 0.5, card_size.y * 0.5)


func _resize() -> void:
	var card_size := _scaled_card_size()
	custom_minimum_size = Vector2(card_size.x * 2.0, card_size.y * 1.5)
	size = custom_minimum_size

	if _primary_pile != null:
		_primary_pile.position = _slot_position(false)
		_primary_pile.setup(_back_texture, card_size)
		_primary_pile.set_remaining(_primary_deck.size())
	if _secondary_pile != null:
		_secondary_pile.position = _slot_position(true)
		_secondary_pile.setup(_back_texture, card_size)
		_secondary_pile.set_remaining(_secondary_deck.size())
		if pack != null and pack.secondaries.is_empty():
			_secondary_pile.hide()
