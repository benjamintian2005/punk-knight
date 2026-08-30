extends Control

# One quadrant of the strike ring. Four of these tile the full circle around the
# knight, so every approach angle lands on some lane's arc - there is no dead
# ground and no need for creatures to converge onto an axis.

var centre := Vector2.ZERO
var radius := 88.0
var thickness := 5.0
var start_angle := 0.0
var end_angle := 0.0
var color := Color.WHITE

# [width multiplier, alpha] - widest and faintest first.
const GLOW_PASSES := [[6.0, 0.045], [3.4, 0.075], [1.9, 0.13], [1.0, 0.34]]


func _draw() -> void:
	# Glow, faked as a few wide faint passes under a brighter core. Nothing here
	# is opaque - the arc is a light the creatures walk into, not a wall.
	for pass_i in GLOW_PASSES:
		draw_arc(centre, radius, start_angle, end_angle, 64,
			Color(color.r, color.g, color.b, pass_i[1]), thickness * pass_i[0], true)
