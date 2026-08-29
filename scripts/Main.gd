extends Control

var rhythm_side: Control
var battle_side: Control
var game_over_overlay: Control


func _ready() -> void:
	var vsize := get_viewport_rect().size
	var half := vsize.x / 2.0
	var level: LevelData = GameState.get_selected_level()

	rhythm_side = Control.new()
	rhythm_side.set_script(load("res://scripts/RhythmSide.gd"))
	rhythm_side.configure(level)
	rhythm_side.position = Vector2.ZERO
	rhythm_side.size = Vector2(half, vsize.y)
	add_child(rhythm_side)

	battle_side = Control.new()
	battle_side.set_script(load("res://scripts/BattleSide.gd"))
	battle_side.configure(level)
	battle_side.position = Vector2(half, 0.0)
	battle_side.size = Vector2(vsize.x - half, vsize.y)
	add_child(battle_side)

	var divider := ColorRect.new()
	divider.color = Color(1.0, 1.0, 1.0, 0.08)
	divider.position = Vector2(half - 1.0, 0.0)
	divider.size = Vector2(2.0, vsize.y)
	add_child(divider)

	rhythm_side.note_hit.connect(battle_side.trigger_pulse)
	battle_side.player_died.connect(_on_player_died)

	var level_label := Label.new()
	level_label.text = "%s  -  ESC for level select" % level.title
	level_label.position = Vector2(0.0, 2.0)
	level_label.size = Vector2(vsize.x, 16.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	add_child(level_label)

	_build_game_over_overlay(vsize)


func _build_game_over_overlay(vsize: Vector2) -> void:
	game_over_overlay = Control.new()
	game_over_overlay.anchor_right = 1.0
	game_over_overlay.anchor_bottom = 1.0
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	game_over_overlay.add_child(dim)

	var label := Label.new()
	label.text = "GAME OVER\n\nPress ENTER to restart"
	label.position = Vector2(0.0, vsize.y / 2.0 - 60.0)
	label.size = Vector2(vsize.x, 120.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	game_over_overlay.add_child(label)


func _on_player_died() -> void:
	rhythm_side.set_active(false)
	game_over_overlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
		return

	if game_over_overlay.visible and event.is_action_pressed("ui_accept"):
		_restart()


func _restart() -> void:
	rhythm_side.reset()
	battle_side.reset()
	game_over_overlay.visible = false
