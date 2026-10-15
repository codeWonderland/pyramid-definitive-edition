class_name HowToPlayPage extends Resource

## One screen's "How to play" card: shown the first time a player reaches that
## screen. Each page is a .tres in pages/, so the tips can be reworded in the
## editor without touching code.

## Remembered once the card has been seen, so it isn't shown again.
@export var id: StringName
@export var title: String
## One tip per line, in the order they're shown.
@export_multiline var tips: Array[String] = []
