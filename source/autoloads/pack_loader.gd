extends Node

signal packs_loaded

const PACKS_FOLDER_PATH: String = "user://mods/pyramid-mods-main/PACKS/"

var all_packs: Array[PackData]


func load() -> void:
	all_packs = []
	var packs_folder = DirAccess.open(PACKS_FOLDER_PATH)

	if packs_folder:
		packs_folder.list_dir_begin()
		var pack_path = packs_folder.get_next()
		while pack_path != "":
			await get_tree().process_frame

			var pack_data = load_pack_from_path(PACKS_FOLDER_PATH + pack_path)

			if pack_data != null:
				all_packs.append(pack_data)

			pack_path = packs_folder.get_next()

		all_packs.sort_custom(_sort_packs)

	self.packs_loaded.emit()


func load_pack_from_path(pack_path: String) -> PackData:
	var pack_data = PackData.new()

	pack_data.folder_path = pack_path

	var num_parts = pack_path.get_slice_count("/")
	pack_data.title = pack_path.get_slice("/", num_parts - 1)

	var pack_folder = DirAccess.open(pack_data.folder_path)
	var files = pack_folder.get_files()

	for file_path in files:
		# only image files are actually valid
		if !(
			file_path.ends_with(".png")
			or file_path.ends_with(".jpg")
			or file_path.ends_with(".jpeg")
		):
			continue

		var image: Image = Image.load_from_file(pack_data.folder_path + "/" + file_path)
		var texture: ImageTexture = ImageTexture.create_from_image(image)

		if file_path.begins_with("b"):
			pack_data.backs.append(texture)
		elif file_path.begins_with("p"):
			pack_data.primaries.append(texture)
		elif file_path.begins_with("s"):
			pack_data.secondaries.append(texture)
		elif file_path.begins_with("c"):
			pack_data.curses.append(texture)
		else:
			print("No idea what to do with this texture:")
			print(file_path)

	if pack_data.backs.size():
		return pack_data

	print("pack does not have proper background:")
	print(pack_data.folder_path)
	return null


func _sort_packs(a: PackData, b: PackData) -> bool:
	return a.title < b.title
