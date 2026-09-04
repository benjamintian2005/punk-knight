extends Control

const PENTAGRAM_SCRIPT := preload("res://scripts/Pentagram.gd")
const KNIGHT_TEXTURE := preload("res://art/knight_title.png")
const LOGO_TEXTURE := preload("res://art/title_logo.png")

var started := false


func _ready() -> void:
	var vsize := get_viewport_rect().size

	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Scale him off the viewport height so the layout holds at any window size.
	var knight_h := vsize.y * 0.94
	var knight_w := knight_h * (float(KNIGHT_TEXTURE.get_width()) / float(KNIGHT_TEXTURE.get_height()))
	var knight_pos := Vector2(vsize.x - knight_w - vsize.x * 0.05, vsize.y - knight_h)

	# A sigil haloed behind him, turning slowly.
	var sigil_size := knight_h * 0.82
	var sigil := Control.new()
	sigil.set_script(PENTAGRAM_SCRIPT)
	sigil.size = Vector2(sigil_size, sigil_size)
	sigil.position = knight_pos + Vector2(knight_w, knight_h) / 2.0 - sigil.size / 2.0
	sigil.pivot_offset = sigil.size / 2.0
	sigil.radius = sigil_size / 2.0
	sigil.line_width = 2.0
	sigil.color = Color(0.85, 0.25, 0.35, 0.16)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sigil)

	var spin := create_tween().set_loops()
	spin.tween_property(sigil, "rotation", TAU, 90.0)

	var knight := TextureRect.new()
	knight.texture = KNIGHT_TEXTURE
	knight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	knight.size = Vector2(knight_w, knight_h)
	knight.position = knight_pos
	knight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(knight)

	# The logo sits on the left, clear of him.
	var logo_w := vsize.x * 0.46
	var logo_h := logo_w * (float(LOGO_TEXTURE.get_height()) / float(LOGO_TEXTURE.get_width()))
	var logo_y := vsize.y * 0.30

	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Nearest filtering, or the halftone dither smears into grey mush.
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.size = Vector2(logo_w, logo_h)
	logo.position = Vector2(vsize.x * 0.055, logo_y)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var prompt := Label.new()
	prompt.text = "click anywhere to start"
	prompt.position = Vector2(vsize.x * 0.065, logo_y + logo_h + 26.0)
	prompt.size = Vector2(vsize.x * 0.5, 30.0)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(0.62, 0.62, 0.7))
	add_child(prompt)

	# Breathe, so the screen never looks frozen.
	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if started:
		return
	# _input, not _unhandled_input: a Control eats mouse clicks by default,
	# so clicks would never reach the unhandled stage.
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		started = true
		SceneTransition.change_scene("res://scenes/LevelSelect.tscn")
