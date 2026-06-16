extends Node

signal rules_loaded

const ADDITIONAL_RULES_PATH: String = "user://mods/pyramid-mods-main/multiplayer-coop-rules.csv"

var additional_rules: Dictionary = {}


func load() -> void:
	var parsed_rules = CSVParser.parse_file(ADDITIONAL_RULES_PATH)

	for rule in parsed_rules:
		# CSV columns come from user-editable mod data; skip rows missing the
		# expected headers rather than crashing the loader.
		if not (rule.has("name") and rule.has("multiplayer") and rule.has("coop")):
			continue

		additional_rules[rule["name"]] = {
			"multiplayer": rule["multiplayer"],
			"coop": rule["coop"],
		}

	self.rules_loaded.emit()
