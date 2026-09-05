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
		"slime":
			_draw_slime(center, radius)
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


# A squashed blob with a gloss highlight and two eyes, so every recolor still
# reads as a slime instead of a plain circle.
func _draw_slime(center: Vector2, r: float) -> void:
	var body_center := center + Vector2(0.0, r * 0.12)
	draw_set_transform(body_center, 0.0, Vector2(1.0, 0.82))
	draw_circle(Vector2.ZERO, r, enemy_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(center + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1.0, 1.0, 1.0, 0.35))

	var eye_dx := r * 0.32
	var eye_y := center.y - r * 0.05
	var eye_r := maxf(1.5, r * 0.13)
	var eye_color := enemy_color.darkened(0.75)
	draw_circle(Vector2(center.x - eye_dx, eye_y), eye_r, eye_color)
	draw_circle(Vector2(center.x + eye_dx, eye_y), eye_r, eye_color)
