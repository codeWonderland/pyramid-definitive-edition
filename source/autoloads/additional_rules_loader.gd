extends Node

signal rules_loaded

const ADDITIONAL_RULES_PATH: String = "user://mods/pyramid-mods-main/multiplayer-coop-rules.csv"

var additional_rules: Dictionary = {}


func load() -> void:
	var parsed_rules = CSVParser.parse_file(ADDITIONAL_RULES_PATH)

	for rule in parsed_rules:
		additional_rules[rule["name"]] = {
			"multiplayer": rule["multiplayer"],
			"coop": rule["coop"],
		}

	self.rules_loaded.emit()
