extends Control

var shape := "circle"
var enemy_color := Color.WHITE
var radius := 15.0

var sheet: Texture2D = null
var frame_count := 4
var frame_w := 0.0
var frame_h := 0.0
var fps := 10.0
var frame := 0
var frame_t := 0.0
var face_left := false


func setup(type: EnemyType) -> void:
	shape = type.shape
	enemy_color = type.color
	radius = type.radius
	fps = maxf(1.0, type.sprite_fps)
	frame_count = maxi(1, type.sprite_frames)

	if type.sprite_path != "" and ResourceLoader.exists(type.sprite_path):
		sheet = load(type.sprite_path)
		frame_w = float(sheet.get_width()) / float(frame_count)
		frame_h = float(sheet.get_height())
		# The sprite is decoration drawn larger than the hitbox; `radius` is
		# still the only thing that collides.
		size = Vector2(type.sprite_height * (frame_w / frame_h), type.sprite_height)
	else:
		size = Vector2(radius * 2.0, radius * 2.0)

	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(sheet != null)
	queue_redraw()


func set_facing(left: bool) -> void:
	if left != face_left:
		face_left = left
		queue_redraw()


func _process(delta: float) -> void:
	frame_t += delta
	var step := 1.0 / fps
	while frame_t >= step:
		frame_t -= step
		frame = (frame + 1) % frame_count
	queue_redraw()


func _draw() -> void:
	if sheet != null:
		if face_left:
			# Mirror about the node's own width - the art faces right by default.
			draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, size),
			Rect2(frame * frame_w, 0.0, frame_w, frame_h))
		return

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
