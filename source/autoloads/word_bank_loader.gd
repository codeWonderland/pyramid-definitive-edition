extends Node

signal word_bank_loaded

const WORD_BANK_PATH: String = "user://mods/pyramid-mods-main/word_bank.json"

var adjectives: Array = []
var nouns: Array = []


func load() -> void:
	var word_bank_file = FileAccess.open(WORD_BANK_PATH, FileAccess.READ)
	var word_bank_text = word_bank_file.get_as_text()
	var word_bank = JSON.parse_string(word_bank_text)

	adjectives = word_bank["adjectives"]
	nouns = word_bank["nouns"]

	self.word_bank_loaded.emit()
