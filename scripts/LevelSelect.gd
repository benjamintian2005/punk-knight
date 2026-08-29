extends Control

const CARD_WIDTH := 440.0
const CARD_HEIGHT := 96.0
const CARD_GAP := 20.0


func _ready() -> void:
	var vsize := get_viewport_rect().size

	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var title := Label.new()
	title.text = "PUNK KNIGHT"
	title.position = Vector2(0.0, vsize.y * 0.14)
	title.size = Vector2(vsize.x, 50.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Select a Level"
	subtitle.position = Vector2(0.0, vsize.y * 0.14 + 54.0)
	subtitle.size = Vector2(vsize.x, 30.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
	add_child(subtitle)

	var levels: Array[LevelData] = GameState.levels
	var total_height := levels.size() * CARD_HEIGHT + (levels.size() - 1) * CARD_GAP
	var start_y: float = vsize.y * 0.14 + 54.0 + 60.0
	var start_x := (vsize.x - CARD_WIDTH) / 2.0

	var first_button: Button = null

	for i in levels.size():
		var lvl: LevelData = levels[i]
		var card_y := start_y + i * (CARD_HEIGHT + CARD_GAP)
		var button := _build_card(lvl, Vector2(start_x, card_y))
		button.pressed.connect(_on_level_pressed.bind(i))
		add_child(button)
		if i == 0:
			first_button = button

	if first_button:
		first_button.grab_focus()


func _build_card(lvl: LevelData, card_pos: Vector2) -> Button:
	var button := Button.new()
	button.position = card_pos
	button.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	button.text = ""

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.13, 0.13, 0.17)
	normal_style.border_color = Color(0.3, 0.3, 0.36)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(10)

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(0.18, 0.18, 0.24)
	hover_style.border_color = Color(0.55, 0.65, 1.0)

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.1, 0.13)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style.duplicate())

	var name_label := Label.new()
	name_label.text = lvl.title
	name_label.position = Vector2(0.0, 14.0)
	name_label.size = Vector2(CARD_WIDTH, 32.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	button.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = lvl.description
	desc_label.position = Vector2(0.0, 52.0)
	desc_label.size = Vector2(CARD_WIDTH, 24.0)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.7))
	button.add_child(desc_label)

	return button


func _on_level_pressed(index: int) -> void:
	GameState.selected_level_index = index
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
