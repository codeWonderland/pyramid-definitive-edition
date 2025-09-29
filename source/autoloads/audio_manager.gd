extends Node

const DICE_ROLL: AudioStream = preload("res://assets/audio/sfx/dice-roll.wav")

@onready var sfx: AudioStreamPlayer2D = %SFX
@onready var bgm: AudioStreamPlayer2D = %BGM


func _ready() -> void:
	_update_music_volume()
	_update_sfx_volume()

	UserSettingsManager.music_volume_updated.connect(_update_music_volume)
	UserSettingsManager.sfx_volume_updated.connect(_update_sfx_volume)


func play_sfx(sfx_stream: AudioStream) -> void:
	sfx.stream = sfx_stream
	sfx.play()


func _update_music_volume():
	bgm.volume_db = UserSettingsManager.volume_to_db(UserSettingsManager.music_volume)


func _update_sfx_volume():
	sfx.volume_db = UserSettingsManager.volume_to_db(UserSettingsManager.sfx_volume)
