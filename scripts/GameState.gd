extends Node

const LEVELS := [
	{
		"id": "warmup", "name": "Warmup",
		"description": "Slow and sparse - learn the ropes.",
		"bpm": 100.0,
		"pattern": [0, -1, -1, -1, 1, -1, -1, -1, 2, -1, -1, -1, 3, -1, -1, -1],
		"repeats": 3,
		"enemy_spawn_min": 2.0, "enemy_spawn_max": 3.4,
	},
	{
		"id": "rush_hour", "name": "Rush Hour",
		"description": "Steady groove, steady pressure.",
		"bpm": 128.0,
		"pattern": [0, -1, 1, -1, 2, 3, -1, 1, 0, 2, -1, 3, 1, -1, 0, -1],
		"repeats": 4,
		"enemy_spawn_min": 1.0, "enemy_spawn_max": 2.2,
	},
	{
		"id": "overdrive", "name": "Overdrive",
		"description": "Fast, dense, relentless.",
		"bpm": 150.0,
		"pattern": [0, 1, -1, 2, 3, 1, 0, -1, 2, 3, 0, 1, 2, -1, 3, 1],
		"repeats": 5,
		"enemy_spawn_min": 0.55, "enemy_spawn_max": 1.3,
	},
]

var selected_level_index := 0


func get_selected_level() -> Dictionary:
	return LEVELS[selected_level_index]
