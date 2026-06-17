class_name PackSelectCard extends TextureRect

signal pressed(pack_data: PackData)
signal favorite_toggled(pack_data: PackData)

var pack_data: PackData:
	set(value):
		pack_data = value
		_set_back()
		_update_favorite()

var _heart: FavoriteHeart = null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	resized.connect(_layout_heart)

	_heart = FavoriteHeart.new()
	_heart.visible = false
	add_child(_heart)
	_layout_heart()

	FavoritesManager.favorites_changed.connect(_update_favorite)

	if pack_data:
		_set_back()
		_update_favorite()


func _set_back() -> void:
	texture = pack_data.backs[0]


func _update_favorite() -> void:
	if _heart == null or pack_data == null:
		return
	_heart.visible = FavoritesManager.is_favorite(pack_data.folder_path)


func _layout_heart() -> void:
	if _heart == null:
		return

	var heart_size := minf(size.x, size.y) * 0.3
	if heart_size <= 0.0:
		return

	_heart.size = Vector2(heart_size, heart_size)
	_heart.position = Vector2(size.x - heart_size - heart_size * 0.15, heart_size * 0.15)
	_heart.queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.is_pressed()):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		self.pressed.emit(pack_data)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		self.favorite_toggled.emit(pack_data)
