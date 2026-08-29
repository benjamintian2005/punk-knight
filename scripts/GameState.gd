extends Node

const LEVEL_DIR := "res://resources/levels/"

var levels: Array[LevelData] = []
var selected_level_index := 0


func _ready() -> void:
	for file_name in DirAccess.get_files_at(LEVEL_DIR):
		if file_name.ends_with(".tres"):
			levels.append(load(LEVEL_DIR + file_name) as LevelData)
	levels.sort_custom(func(a, b): return a.order < b.order)


func get_selected_level() -> LevelData:
	return levels[selected_level_index]
