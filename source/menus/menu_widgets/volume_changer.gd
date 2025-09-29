class_name VolumeChanger extends PanelContainer

signal on_volume_changed(new_volume: int)

const ACTIVE_COLOR: Color = Color(0.561, 0.824, 0.918)
const INACTIVE_COLOR: Color = Color(0.1, 0.1, 0.1)

@export var volume_label_text: String = "Volume"
@export_range(0, 10) var level: int = 7

@onready
var decrease: Button = $MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/Decrease
@onready
var increase: Button = $MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/Increase
@onready var level_panels: Array[Panel] = [
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level1,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level2,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level3,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level4,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level5,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level6,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level7,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level8,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level9,
	$MarginContainer/VolumeChanger/MarginContainer/HBoxContainer2/HBoxContainer/Level10
]
@onready var volume_label: Label = $MarginContainer/VolumeChanger/Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_level_panels()
	volume_label.text = volume_label_text

	for idx in range(level_panels.size()):
		level_panels[idx].gui_input.connect(
			func(event):
				if event is InputEventScreenTouch:
					set_level(idx + 1)
		)


func set_level(new_level) -> void:
	level = new_level
	self.update_level_panels()
	self.on_volume_changed.emit(level)


func update_level_panels():
	var current_panel = 0

	for panel in level_panels:
		current_panel += 1
		var style_box: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()

		if current_panel <= level:
			style_box.bg_color = ACTIVE_COLOR

		else:
			style_box.bg_color = INACTIVE_COLOR

		panel.add_theme_stylebox_override("panel", style_box)


func _on_decrease_pressed() -> void:
	if level != 0:
		level -= 1

	update_level_panels()
	self.on_volume_changed.emit(level)


func _on_increase_pressed() -> void:
	if level != 10:
		level += 1

	update_level_panels()
	self.on_volume_changed.emit(level)
