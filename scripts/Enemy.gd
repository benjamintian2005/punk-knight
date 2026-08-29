extends Control

var shape := "circle"
var enemy_color := Color.WHITE
var radius := 15.0


func setup(p_shape: String, p_color: Color, p_radius: float) -> void:
	shape = p_shape
	enemy_color = p_color
	radius = p_radius
	size = Vector2(radius * 2.0, radius * 2.0)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	match shape:
		"square":
			var r := radius * 0.85
			draw_rect(Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), enemy_color)
		"triangle":
			var points := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius * 0.87, radius * 0.6),
				center + Vector2(-radius * 0.87, radius * 0.6),
			])
			draw_colored_polygon(points, enemy_color)
		"diamond":
			var points := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
			])
			draw_colored_polygon(points, enemy_color)
		_:
			draw_circle(center, radius, enemy_color)
