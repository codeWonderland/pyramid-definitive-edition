class_name BannerNotice extends PanelContainer

## Says where a saved run banner went - capturing one changes nothing on screen,
## so without this it looked like the button did nothing - and offers to open the
## folder. Fades after a few seconds.

const SHOW_TIME: float = 6.0
const FADE_TIME: float = 0.4

var _path: String = ""
var _tween: Tween = null

@onready var _title: Label = %NoticeTitle
@onready var _detail: Label = %NoticeDetail
@onready var _show_button: Button = %ShowInFolder


func _ready() -> void:
	hide()
	_show_button.pressed.connect(_show_in_folder)


## Reports a banner saved at `path`.
func show_saved(path: String) -> void:
	_path = path
	_title.text = "Banner saved"
	_detail.text = describe(path)
	_show_button.show()
	_appear()


## Reports a banner that couldn't be written to `path`.
func show_failed(path: String) -> void:
	_path = ""
	_title.text = "Couldn't save the banner"
	_detail.text = "Nothing could be written to %s" % _readable_folder(path)
	_show_button.hide()
	_appear()


## "pyramid-run-....png in Pictures", for a file in a named folder.
static func describe(path: String) -> String:
	return "%s in %s" % [path.get_file(), _readable_folder(path)]


static func _readable_folder(path: String) -> String:
	var folder := ProjectSettings.globalize_path(path.get_base_dir())
	return folder.trim_suffix("/").get_file() if not folder.is_empty() else folder


func _appear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)


func _show_in_folder() -> void:
	if not _path.is_empty():
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_path))
