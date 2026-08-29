extends Node

const LEVEL_DIR := "res://resources/levels/"

var levels: Array[LevelData] = []
var selected_level_index := 0


func _ready() -> void:
	for file_name in DirAccess.get_files_at(LEVEL_DIR):
		if file_name.ends_with(".tres"):
			var level := load(LEVEL_DIR + file_name) as LevelData
			if level != null:
				levels.append(level)
			else:
				push_warning("GameState: skipping invalid level resource %s" % file_name)
	levels.sort_custom(func(a, b): return a.order < b.order)

	if levels.is_empty():
		push_error("GameState: no levels found in %s" % LEVEL_DIR)
		levels.append(LevelData.new())


func get_selected_level() -> LevelData:
	selected_level_index = clampi(selected_level_index, 0, levels.size() - 1)
	return levels[selected_level_index]
