class_name CardGroupData extends Resource

@export var pack_path: String = ""

# --- Deck state (full persistence) ---
# Draw piles as CardDeck-encoded ints (see card_deck.gd).
@export var primary_deck: Array[int] = []
@export var secondary_deck: Array[int] = []
# Cards currently on the table. Each entry:
#   { "entry": int, "secondary": bool, "curse": bool, "x": float, "y": float }
@export var table_cards: Array[Dictionary] = []

# --- Legacy fields (older saves predate the deck model) ---
@export var primary: int = 0
@export var secondary: int = -1
@export var curse: int = -1
