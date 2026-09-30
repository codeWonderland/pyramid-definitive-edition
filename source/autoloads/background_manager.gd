extends Node

signal backgrounds_loaded

const BACKGROUNDS_PATH: String = "user://mods/pyramid-mods-main/BACKGROUNDS/"
const DEFAULT_BACKGROUND = preload("res://assets/sprites/ui/background.png")
## The light-blue line art that was the default before the Steam capsule look.
## Built in rather than shipped as a mod background, so it is always available.
const CLASSIC_BACKGROUND = preload("res://assets/sprites/ui/background_classic.png")

var backgrounds: Dictionary = {}


func _ready() -> void:
	self.load()


func load() -> void:
	backgrounds = {"Default": DEFAULT_BACKGROUND, "Classic": CLASSIC_BACKGROUND}
	var backgrounds_folder = DirAccess.open(BACKGROUNDS_PATH)

	if backgrounds_folder:
		var images = backgrounds_folder.get_files()

		for image_path in images:
			# only image files are actually valid
			if !(
				image_path.ends_with(".png")
				or image_path.ends_with(".jpg")
				or image_path.ends_with(".jpeg")
			):
				continue

			var image: Image = Image.load_from_file(BACKGROUNDS_PATH + image_path)
			if image == null:
				push_warning("BackgroundManager: couldn't load image %s" % image_path)
				continue

			var texture: ImageTexture = ImageTexture.create_from_image(image)
			var image_name: String = image_path.split(".")[0]

			backgrounds[image_name] = texture

	self.backgrounds_loaded.emit()
