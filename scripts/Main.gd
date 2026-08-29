extends Control

var rhythm_side: Control
var battle_side: Control
var game_over_overlay: Control


func _ready() -> void:
	var vsize := get_viewport_rect().size
	var half := vsize.x / 2.0

	rhythm_side = Control.new()
	rhythm_side.set_script(load("res://scripts/RhythmSide.gd"))
	rhythm_side.position = Vector2.ZERO
	rhythm_side.size = Vector2(half, vsize.y)
	add_child(rhythm_side)

	battle_side = Control.new()
	battle_side.set_script(load("res://scripts/BattleSide.gd"))
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
	if not game_over_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			_restart()


func _restart() -> void:
	rhythm_side.reset()
	battle_side.reset()
	game_over_overlay.visible = false
