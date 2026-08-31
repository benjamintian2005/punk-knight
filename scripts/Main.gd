extends Control

var rhythm_side: Control
var battle_side: Control
var game_over_overlay: Control
var pause_overlay: Control
var pause_resume_button: Button

var shake_strength := 0.0
const SHAKE_DECAY := 70.0   # units/sec - fast, punchy, gone within ~0.2s
const SHAKE_PERFECT := 14.0
const SHAKE_GOOD := 6.0
const SHAKE_BIG := 30.0


func _ready() -> void:
	var vsize := get_viewport_rect().size
	var level: LevelData = GameState.get_selected_level()

	# The battle owns the whole screen...
	battle_side = Control.new()
	battle_side.set_script(load("res://scripts/BattleSide.gd"))
	battle_side.configure(level)
	battle_side.position = Vector2.ZERO
	battle_side.size = vsize
	add_child(battle_side)

	# ...and the lanes lie on top of it, so notes land ON the knight.
	# Added second, so it draws over the arena.
	rhythm_side = Control.new()
	rhythm_side.set_script(load("res://scripts/RhythmSide.gd"))
	rhythm_side.configure(level)
	rhythm_side.set_enemy_types(battle_side.get_enemy_roster())
	rhythm_side.position = Vector2.ZERO
	rhythm_side.size = vsize
	rhythm_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rhythm_side)

	rhythm_side.note_hit.connect(battle_side.trigger_pulse)
	rhythm_side.note_hit.connect(_on_note_hit)
	rhythm_side.note_missed.connect(battle_side.on_note_missed)
	battle_side.player_died.connect(_on_player_died)

	var level_label := Label.new()
	level_label.text = "%s  -  ESC to pause" % level.title
	level_label.position = Vector2(0.0, 2.0)
	level_label.size = Vector2(vsize.x, 16.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	add_child(level_label)

	_build_game_over_overlay(vsize)
	_build_pause_overlay(vsize)


func _process(delta: float) -> void:
	if shake_strength <= 0.0:
		return
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength
	shake_strength = maxf(shake_strength - SHAKE_DECAY * delta, 0.0)
	if shake_strength <= 0.0:
		position = Vector2.ZERO


func _on_note_hit(judgment: String) -> void:
	# max(), not add - overlapping hits refresh the shake instead of stacking
	# into something disorienting.
	var strength := SHAKE_GOOD
	if judgment == "PERFECT":
		strength = SHAKE_PERFECT
	elif judgment == "BIG":
		strength = SHAKE_BIG
	shake_strength = maxf(shake_strength, strength)


func _build_dim_rect() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	return dim


func _build_game_over_overlay(vsize: Vector2) -> void:
	game_over_overlay = Control.new()
	game_over_overlay.anchor_right = 1.0
	game_over_overlay.anchor_bottom = 1.0
	game_over_overlay.visible = false
	# z_index sorts across the WHOLE canvas, not just among siblings - notes
	# in RhythmSide get up to ~SPAWN_RADIUS (300) for their own depth
	# ordering, so this needs to clear that or they'd render on top of us.
	game_over_overlay.z_index = 1000
	add_child(game_over_overlay)
	game_over_overlay.add_child(_build_dim_rect())

	var label := Label.new()
	label.text = "GAME OVER\n\nPress ENTER to restart"
	label.position = Vector2(0.0, vsize.y / 2.0 - 60.0)
	label.size = Vector2(vsize.x, 120.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	game_over_overlay.add_child(label)


func _build_pause_overlay(vsize: Vector2) -> void:
	pause_overlay = Control.new()
	pause_overlay.anchor_right = 1.0
	pause_overlay.anchor_bottom = 1.0
	pause_overlay.visible = false
	# See game_over_overlay's z_index comment - same reason.
	pause_overlay.z_index = 1000
	add_child(pause_overlay)
	pause_overlay.add_child(_build_dim_rect())

	var panel_width := 360.0
	var panel_height := 300.0
	var panel := Panel.new()
	panel.position = Vector2((vsize.x - panel_width) / 2.0, (vsize.y - panel_height) / 2.0)
	panel.size = Vector2(panel_width, panel_height)
	# Styling now comes from the shared Theme (theme/game_theme.tres) - this
	# used to hand-roll the exact same StyleBoxFlat locally.
	pause_overlay.add_child(panel)

	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0.0, 16.0)
	title.size = Vector2(panel_width, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	panel.add_child(title)

	var master_row := _build_volume_row("Master Volume", Settings.master_volume, 70.0, panel_width)
	panel.add_child(master_row.container)
	master_row.slider.value_changed.connect(_on_master_volume_changed.bind(master_row.value_label))

	var music_row := _build_volume_row("Music Volume", Settings.music_volume, 130.0, panel_width)
	panel.add_child(music_row.container)
	music_row.slider.value_changed.connect(_on_music_volume_changed.bind(music_row.value_label))

	pause_resume_button = _build_pause_button("Resume", Vector2(30.0, 200.0), panel_width - 60.0)
	pause_resume_button.pressed.connect(_resume)
	panel.add_child(pause_resume_button)

	var quit_button := _build_pause_button("Quit to Level Select", Vector2(30.0, 250.0), panel_width - 60.0)
	quit_button.pressed.connect(_quit_to_level_select)
	panel.add_child(quit_button)


func _build_volume_row(label_text: String, initial_value: float, y: float, panel_width: float) -> Dictionary:
	var row := Control.new()
	row.position = Vector2(0.0, y)
	row.size = Vector2(panel_width, 50.0)

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(30.0, 0.0)
	label.size = Vector2(panel_width - 60.0, 20.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.position = Vector2(30.0, 24.0)
	slider.size = Vector2(panel_width - 100.0, 20.0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(round(initial_value * 100.0))
	value_label.position = Vector2(panel_width - 62.0, 24.0)
	value_label.size = Vector2(40.0, 20.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	row.add_child(value_label)

	return {"container": row, "slider": slider, "value_label": value_label}


func _build_pause_button(text: String, pos: Vector2, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(width, 40.0)
	return button


func _on_master_volume_changed(value: float, value_label: Label) -> void:
	Settings.set_master_volume(value)
	value_label.text = "%d%%" % int(round(value * 100.0))


func _on_music_volume_changed(value: float, value_label: Label) -> void:
	Settings.set_music_volume(value)
	value_label.text = "%d%%" % int(round(value * 100.0))


func _open_pause() -> void:
	pause_overlay.visible = true
	rhythm_side.set_active(false)
	battle_side.set_active(false)
	pause_resume_button.grab_focus()


func _resume() -> void:
	pause_overlay.visible = false
	rhythm_side.set_active(true)
	battle_side.set_active(true)


func _quit_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")


func _on_player_died() -> void:
	rhythm_side.set_active(false)
	game_over_overlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if game_over_overlay.visible:
			get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
		elif pause_overlay.visible:
			_resume()
		else:
			_open_pause()
		return

	if game_over_overlay.visible and event.is_action_pressed("ui_accept"):
		_restart()


func _restart() -> void:
	rhythm_side.reset()
	battle_side.reset()
	game_over_overlay.visible = false
