extends Control

# A {5/2} star polygon - five points, each joined to the one two steps round,
# which is what gives the pentagram its crossed lines and open middle.

var color: Color = Color.WHITE
var radius: float = 13.0
var line_width: float = 2.0


func _draw() -> void:
	var c := size / 2.0
	var points := PackedVector2Array()
	for i in 5:
		# i * 2 walks 0, 2, 4, 1, 3 around the circle - the "skip one" order.
		var angle := -PI / 2.0 + float(i * 2) * TAU / 5.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])   # close the figure
	draw_polyline(points, color, line_width, true)
