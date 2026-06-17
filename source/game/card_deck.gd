class_name CardDeck extends RefCounted

## A draw pile, stored as a list of encoded ints so it shuffles, draws, and
## serializes cheaply (no texture references):
##   primary card -> its index in pack.primaries           (entry >= 0)
##   curse card   -> -(index in pack.curses) - 1            (entry <  0)
## Secondary piles only ever hold primary-style (>= 0) entries.
##
## Core invariant for primary piles: the next drawable card (the top) is always
## a primary. Drawing a primary reveals at most one curse (which the caller flies
## to the curse slot); any further consecutive curses are recycled to the bottom
## so two curses never surface back-to-back.

## Guards the recycle loop against a pile that somehow contains no primary.
const _RECYCLE_SAFETY: int = 4096

var cards: Array[int] = []


static func encode_primary(index: int) -> int:
	return index


static func encode_curse(index: int) -> int:
	return -index - 1


static func is_curse(entry: int) -> bool:
	return entry < 0


## Index into pack.primaries (for >= 0 entries) or pack.curses (for < 0 entries).
static func decode_index(entry: int) -> int:
	return entry if entry >= 0 else (-entry - 1)


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func has_primary() -> bool:
	for entry in cards:
		if not is_curse(entry):
			return true
	return false


## Top card without removing it. Caller must check is_empty() first.
func peek() -> int:
	return cards[0]


func build_primary(num_primaries: int, num_curses: int) -> void:
	cards = []
	for i in range(num_primaries):
		cards.append(encode_primary(i))
	for c in range(num_curses):
		cards.append(encode_curse(c))
	cards.shuffle()
	_ensure_top_primary()


func build_secondary(num_secondaries: int) -> void:
	cards = []
	for i in range(num_secondaries):
		cards.append(encode_primary(i))
	cards.shuffle()


## Draw the top primary. Returns:
##   { "primary": <entry> }                 when no curse is revealed
##   { "primary": <entry>, "curse": <entry> } when the card under it is a curse
##   {}                                       when no primary can be drawn
## After this call the top is guaranteed to be a primary again (or the pile is
## out of primaries).
func draw_primary() -> Dictionary:
	_ensure_top_primary()
	if is_empty() or is_curse(cards[0]):
		return {}

	var primary: int = cards.pop_front()
	var result := {"primary": primary}

	# The card now exposed: if it's a curse, it flies to the curse slot. Recycle
	# any further consecutive curses so they don't surface stacked.
	if not is_empty() and is_curse(cards[0]):
		var curse: int = cards.pop_front()
		result["curse"] = curse
		_ensure_top_primary()

	return result


## Draw the top of a secondary pile. Returns the entry, or -1 if empty.
func draw_secondary() -> int:
	if is_empty():
		return -1
	var entry: int = cards.pop_front()
	return entry


## Send a trashed card (encoded entry) to the bottom of the pile.
func trash_to_bottom(entry: int) -> void:
	cards.append(entry)


func to_array() -> Array[int]:
	return cards.duplicate()


func from_array(state: Array[int]) -> void:
	cards = state.duplicate()


## Rotate leading curses to the bottom until the top is a primary. No-op if the
## pile has no primaries (so an all-curse remainder doesn't loop forever).
func _ensure_top_primary() -> void:
	if not has_primary():
		return

	var guard := 0
	while not is_empty() and is_curse(cards[0]) and guard < _RECYCLE_SAFETY:
		cards.append(cards.pop_front())
		guard += 1
