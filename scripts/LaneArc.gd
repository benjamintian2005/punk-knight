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

# 0 dormant, 1 fully lit. Driven by RhythmSide the moment a creature's rune
# touches this quadrant - purely cosmetic, it changes no timing or judgment.
var glow := 0.0: set = _set_glow

# [width multiplier, alpha] - widest and faintest first.
const GLOW_PASSES := [[6.0, 0.045], [3.4, 0.075], [1.9, 0.13], [1.0, 0.34]]
# The same stack lit up: wider bloom, brighter core. Cross-faded in by `glow`.
const LIT_PASSES := [[9.0, 0.10], [5.2, 0.17], [2.6, 0.30], [1.0, 0.78]]


func _set_glow(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, glow):
		return
	glow = value
	queue_redraw()


func _draw() -> void:
	# Glow, faked as a few wide faint passes under a brighter core. Nothing here
	# is opaque - the arc is a light the creatures walk into, not a wall.
	for i in GLOW_PASSES.size():
		var dim: Array = GLOW_PASSES[i]
		var lit: Array = LIT_PASSES[i]
		draw_arc(centre, radius, start_angle, end_angle, 64,
			Color(color.r, color.g, color.b, lerpf(dim[1], lit[1], glow)),
			thickness * lerpf(dim[0], lit[0], glow), true)
