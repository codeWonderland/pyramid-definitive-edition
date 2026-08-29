class_name CardDeck extends RefCounted

## A draw pile, stored as a list of encoded ints so it shuffles, draws, and
## serializes cheaply (no texture references):
##   primary card -> its index in pack.primaries           (entry >= 0)
##   curse card   -> -(index in pack.curses) - 1            (entry <  0)
## Secondary piles only ever hold primary-style (>= 0) entries.
##
## Core invariant for either pile: the next drawable card (the top) is never a
## curse. Drawing reveals at most one curse (which the caller flies to the curse
## slot); any further consecutive curses are recycled to the bottom so two curses
## never surface back-to-back.
##
## Curses normally ride the secondary pile. A pack with no secondaries has no
## secondary pile for them to live in, so there they ride the primary pile
## instead - either way only one pile carries them.

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


## Whether anything in the pile can still be drawn as a normal card.
func has_non_curse() -> bool:
	for entry in cards:
		if not is_curse(entry):
			return true
	return false


## Top card without removing it. Caller must check is_empty() first.
func peek() -> int:
	return cards[0]


## Curses only belong here when the pack has no secondary pile to carry them.
func build_primary(num_primaries: int, num_curses: int = 0) -> void:
	_build(num_primaries, num_curses)


## The usual home for curses.
func build_secondary(num_secondaries: int, num_curses: int = 0) -> void:
	_build(num_secondaries, num_curses)


func _build(num_cards: int, num_curses: int) -> void:
	cards = []
	for i in range(num_cards):
		cards.append(encode_primary(i))
	for c in range(num_curses):
		cards.append(encode_curse(c))
	cards.shuffle()
	_ensure_top_non_curse()


## Draw the top primary. Returns:
##   { "primary": <entry> }                   when no curse is revealed
##   { "primary": <entry>, "curse": <entry> } when the card under it is a curse
##   {}                                       when nothing can be drawn
## After this call the top is guaranteed not to be a curse (or the pile is out
## of ordinary cards).
func draw_primary() -> Dictionary:
	return _draw_revealing_curse("primary")


## Draw the top of a secondary pile, with the same shape as draw_primary(): this
## is where curses normally surface.
func draw_secondary() -> Dictionary:
	return _draw_revealing_curse("secondary")


func _draw_revealing_curse(key: String) -> Dictionary:
	_ensure_top_non_curse()
	if is_empty() or is_curse(cards[0]):
		return {}

	var drawn: int = cards.pop_front()
	var result := {key: drawn}

	# The card now exposed: if it's a curse, it flies to the curse slot. Recycle
	# any further consecutive curses so they don't surface stacked.
	if not is_empty() and is_curse(cards[0]):
		result["curse"] = cards.pop_front()
		_ensure_top_non_curse()

	return result


## Removes every curse from this pile and hands them back, for moving them to
## the pile that should be carrying them.
func extract_curses() -> Array[int]:
	var curses: Array[int] = []
	var kept: Array[int] = []

	for entry in cards:
		if is_curse(entry):
			curses.append(entry)
		else:
			kept.append(entry)

	cards = kept
	return curses


## Shuffles extra entries into this pile, keeping the top-is-never-a-curse rule.
func add_shuffled(entries: Array[int]) -> void:
	if entries.is_empty():
		return

	cards.append_array(entries)
	cards.shuffle()
	_ensure_top_non_curse()


## Send a trashed card (encoded entry) to the bottom of the pile.
func trash_to_bottom(entry: int) -> void:
	cards.append(entry)


func to_array() -> Array[int]:
	return cards.duplicate()


func from_array(state: Array[int]) -> void:
	cards = state.duplicate()


## Rotate leading curses to the bottom until the top is an ordinary card. No-op
## if the pile has none left (so an all-curse remainder doesn't loop forever).
func _ensure_top_non_curse() -> void:
	if not has_non_curse():
		return

	var guard := 0
	while not is_empty() and is_curse(cards[0]) and guard < _RECYCLE_SAFETY:
		cards.append(cards.pop_front())
		guard += 1
