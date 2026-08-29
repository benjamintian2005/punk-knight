extends Resource
class_name LevelData

@export var order: int = 0
@export var title: String = ""
@export var description: String = ""
@export var bpm: float = 120.0
@export var beat_pattern: Array = []  # lane index per step, -1 = rest
@export var pattern_repeats: int = 4
@export var enemy_spawn_min: float = 1.0
@export var enemy_spawn_max: float = 2.2
@export var enemy_types: Array[EnemyType] = []  # empty = BattleSide's default roster
