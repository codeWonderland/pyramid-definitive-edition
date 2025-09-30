extends Node

signal packs_updated

var selected_packs: Array[PackData] = []


func add_pack(pack_data: PackData) -> void:
	if selected_packs.size() < 10:
		selected_packs.append(pack_data)
		self.packs_updated.emit()


func remove_pack(pack_data: PackData) -> void:
	var index = 0
	for pack in selected_packs:
		if pack.title == pack_data.title:
			selected_packs.remove_at(index)
			break

		index += 1
	self.packs_updated.emit()
