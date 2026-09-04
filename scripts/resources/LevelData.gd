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
@export var background_path: String = ""  # empty = BattleSide's default flat background

# --- real-song charts ---------------------------------------------------
# When note_times is non-empty it REPLACES beat_pattern/pattern_repeats:
# the notes are absolute timestamps authored against song_path.
@export var song_path: String = ""            # res:// path to the music; "" = silent
@export var audio_offset: float = 0.0         # +ve pushes the chart later vs the song
@export var note_times: PackedFloat32Array = PackedFloat32Array()
@export var note_lanes: PackedInt32Array = PackedInt32Array()
