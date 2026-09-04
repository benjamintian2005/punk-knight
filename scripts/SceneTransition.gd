extends CanvasLayer

const DEFAULT_FADE_DURATION := 0.25

var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 4096
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func change_scene(path: String, fade_duration: float = DEFAULT_FADE_DURATION) -> void:
	if _busy:
		return
	_busy = true
	# Defensive: a scene change mid hit-stop (Main.gd) should never leave the
	# whole game stuck in slow motion.
	Engine.time_scale = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var out_tween := create_tween()
	out_tween.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	await out_tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var in_tween := create_tween()
	in_tween.tween_property(_fade_rect, "color:a", 0.0, fade_duration)
	await in_tween.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
