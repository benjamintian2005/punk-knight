extends Resource
class_name EnemyType

@export var shape: String = "slime"  # slime, circle, square, triangle, diamond
@export var color: Color = Color.WHITE
@export var radius: float = 15.0
@export var hp: float = 100.0
@export var speed: float = 55.0
@export var contact_damage: float = 12.0
@export var spawn_weight: int = 1

# --- sprite ------------------------------------------------------------
# A horizontal sheet of equal frames. Empty sprite_path falls back to the
# drawn shape, so shape-only enemy types still work.
@export var sprite_path: String = ""
@export var sprite_frames: int = 4
@export var sprite_fps: float = 10.0
@export var sprite_height: float = 54.0   # on-screen height; collision still uses radius
