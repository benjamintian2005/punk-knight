extends Control

const PLAYER_TEXTURE := preload("res://art/knight_title.png")
const PLAYER_HEIGHT := 72.0
const PLAYER_SPEED := 280.0
const INTERACT_RADIUS := 64.0

# Same palette used for the rhythm lanes in-game, so a flag's color already
# means something by the time the player reaches the level itself.
const FLAG_COLORS := [
	Color(0.95, 0.28, 0.35),
	Color(0.30, 0.85, 0.45),
	Color(0.30, 0.60, 0.98),
	Color(0.98, 0.85, 0.25),
]

var player: TextureRect
var player_pos: Vector2
var flags: Array = []   # [{ "level": LevelData, "index": int, "pos": Vector2 }]
var nearby_index := -1
var prompt_label: Label


func _ready() -> void:
	var vsize := get_viewport_rect().size

	var background := ColorRect.new()
	background.color = Color(0.07, 0.10, 0.08)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var title := Label.new()
	title.text = "PUNK KNIGHT"
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(vsize.x, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 0.85))
	add_child(title)

	var hint := Label.new()
	hint.text = "Walk to a flag and press ENTER"
	hint.position = Vector2(0.0, 52.0)
	hint.size = Vector2(vsize.x, 24.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
	add_child(hint)

	var levels: Array[LevelData] = GameState.levels
	for i in levels.size():
		_build_flag(levels[i], i, vsize)
	queue_redraw()

	player_pos = vsize / 2.0
	var player_w := PLAYER_HEIGHT * (float(PLAYER_TEXTURE.get_width()) / float(PLAYER_TEXTURE.get_height()))
	player = TextureRect.new()
	player.texture = PLAYER_TEXTURE
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player.size = Vector2(player_w, PLAYER_HEIGHT)
	player.pivot_offset = player.size / 2.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	_update_player_position()

	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.size = Vector2(360.0, 24.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	prompt_label.modulate.a = 0.0
	add_child(prompt_label)


# A winding path across the world, one flag per level in order.
func _build_flag(level: LevelData, index: int, vsize: Vector2) -> void:
	var count: int = maxi(GameState.levels.size() - 1, 1)
	var t := float(index) / float(count)
	var pos := Vector2(
		lerp(vsize.x * 0.16, vsize.x * 0.84, t),
		vsize.y * 0.52 + sin(t * TAU * 0.6) * vsize.y * 0.2,
	)

	var pole := ColorRect.new()
	pole.color = Color(0.5, 0.4, 0.32)
	pole.size = Vector2(4.0, 60.0)
	pole.position = pos - Vector2(2.0, 60.0)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pole)

	var flag := Panel.new()
	flag.size = Vector2(38.0, 26.0)
	flag.position = pos - Vector2(0.0, 60.0)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FLAG_COLORS[index % FLAG_COLORS.size()]
	style.set_corner_radius_all(3)
	flag.add_theme_stylebox_override("panel", style)
	add_child(flag)

	var label := Label.new()
	label.text = level.title
	label.size = Vector2(220.0, 22.0)
	label.position = pos - Vector2(110.0, 96.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	add_child(label)

	flags.append({"level": level, "index": index, "pos": pos})


func _draw() -> void:
	# The dirt path connecting the flags - drawn on this node so it renders
	# under the flags/player, which are added as children on top of it.
	if flags.size() < 2:
		return
	var points := PackedVector2Array()
	for f in flags:
		points.append(f["pos"])
	draw_polyline(points, Color(0.45, 0.38, 0.3, 0.55), 8.0, true)


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("lane_0"):
		dir.x -= 1.0
	if Input.is_action_pressed("lane_3"):
		dir.x += 1.0
	if Input.is_action_pressed("lane_2"):
		dir.y -= 1.0
	if Input.is_action_pressed("lane_1"):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		var vsize := get_viewport_rect().size
		player_pos += dir.normalized() * PLAYER_SPEED * delta
		player_pos.x = clampf(player_pos.x, 24.0, vsize.x - 24.0)
		player_pos.y = clampf(player_pos.y, 90.0, vsize.y - 24.0)
		player.flip_h = dir.x < 0.0
		_update_player_position()

	_update_nearby_flag()

	if nearby_index >= 0 and Input.is_action_just_pressed("ui_accept"):
		GameState.selected_level_index = nearby_index
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _update_player_position() -> void:
	player.position = player_pos - Vector2(player.size.x / 2.0, player.size.y)


func _update_nearby_flag() -> void:
	var closest := -1
	var closest_dist := INTERACT_RADIUS
	for f in flags:
		var d: float = player_pos.distance_to(f["pos"])
		if d < closest_dist:
			closest_dist = d
			closest = int(f["index"])

	if closest != nearby_index:
		nearby_index = closest
		if nearby_index >= 0:
			var lvl: LevelData = flags[nearby_index]["level"]
			prompt_label.text = "Press ENTER to play %s" % lvl.title
		prompt_label.modulate.a = 1.0 if nearby_index >= 0 else 0.0

	if nearby_index >= 0:
		prompt_label.position = player_pos - Vector2(prompt_label.size.x / 2.0, PLAYER_HEIGHT + 40.0)
