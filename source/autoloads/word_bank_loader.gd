extends Node

signal word_bank_loaded

const WORD_BANK_PATH: String = "user://mods/pyramid-mods-main/word_bank.json"

var adjectives: Array = []
var nouns: Array = []


func load() -> void:
	# The word bank lives in user-supplied mod data, so treat every step as
	# potentially missing/malformed and always emit so the loading screen never
	# hangs waiting on this loader.
	adjectives = []
	nouns = []

	var word_bank_file = FileAccess.open(WORD_BANK_PATH, FileAccess.READ)
	if word_bank_file == null:
		push_warning("WordBankLoader: couldn't open %s" % WORD_BANK_PATH)
		self.word_bank_loaded.emit()
		return

	var word_bank = JSON.parse_string(word_bank_file.get_as_text())
	if word_bank is Dictionary:
		if word_bank.get("adjectives") is Array:
			adjectives = word_bank["adjectives"]
		if word_bank.get("nouns") is Array:
			nouns = word_bank["nouns"]
	else:
		push_warning("WordBankLoader: %s is not valid JSON" % WORD_BANK_PATH)

	self.word_bank_loaded.emit()
