extends Resource
class_name EnemyType

@export var shape: String = "circle"  # circle, square, triangle, diamond
@export var color: Color = Color.WHITE
@export var radius: float = 15.0
@export var hp: float = 100.0
@export var speed: float = 55.0
@export var contact_damage: float = 12.0
@export var spawn_weight: int = 1
