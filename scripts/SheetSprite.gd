extends Control

# A looping horizontal sprite sheet - one row, equal frames left to right,
# the same layout the enemies use (see Enemy.gd).

var sheet: Texture2D = null
var frame_count := 1
var frame_w := 0.0
var frame_h := 0.0
var fps := 10.0
var frame := 0
var frame_t := 0.0


func setup(texture: Texture2D, frames: int, frames_per_second: float, height: float) -> void:
	sheet = texture
	frame_count = maxi(1, frames)
	fps = maxf(1.0, frames_per_second)
	frame_w = float(sheet.get_width()) / float(frame_count)
	frame_h = float(sheet.get_height())
	size = Vector2(height * (frame_w / frame_h), height)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	frame_t += delta
	var step := 1.0 / fps
	while frame_t >= step:
		frame_t -= step
		frame = (frame + 1) % frame_count
	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, size),
		Rect2(frame * frame_w, 0.0, frame_w, frame_h))
