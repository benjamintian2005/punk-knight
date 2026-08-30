extends Control

signal player_died

const CHARACTER_RADIUS := 26.0
const CHARACTER_MAX_HP := 100.0
const MISS_DAMAGE := 5.0

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")

# Level-dependent spawn pressure; overridden by configure() before _ready runs.
var enemy_spawn_min := 1.0
var enemy_spawn_max := 2.2

# Level-dependent enemy roster; overridden by configure() before _ready runs.
# Falls back to _get_default_enemy_types() when a level doesn't specify one.
var default_enemy_types: Array[EnemyType] = []
var active_enemy_types: Array[EnemyType] = []

const PERFECT_RADIUS := 240.0
const PERFECT_DAMAGE := 100.0
const PERFECT_DURATION := 0.35
const PERFECT_COLOR := Color(1.0, 0.85, 0.25)

const GOOD_RADIUS := 190.0
const GOOD_KNOCKBACK := 90.0
const GOOD_DURATION := 0.3
const GOOD_COLOR := Color(0.5, 0.9, 1.0)

var active := true
var elapsed_time := 0.0
var time_to_next_spawn := 1.0

var character_center: Vector2
var character_hp := CHARACTER_MAX_HP
var character_node: Panel
var hp_fill: ColorRect
var hp_bar_width := 220.0
var hp_label: Label

var enemies_layer: Control
var pulses_layer: Control
var enemies: Array = []
var pulses: Array = []


func configure(level: LevelData) -> void:
	enemy_spawn_min = level.enemy_spawn_min
	enemy_spawn_max = level.enemy_spawn_max
	active_enemy_types = level.enemy_types if not level.enemy_types.is_empty() else _get_default_enemy_types()


func _get_default_enemy_types() -> Array[EnemyType]:
	if default_enemy_types.is_empty():
		default_enemy_types = [
			_make_enemy_type("circle", Color(0.85, 0.25, 0.35), 15.0, 100.0, 55.0, 12.0, 5),
			_make_enemy_type("triangle", Color(0.95, 0.55, 0.2), 16.0, 60.0, 95.0, 10.0, 3),
			_make_enemy_type("square", Color(0.55, 0.4, 0.9), 17.0, 180.0, 38.0, 16.0, 2),
			_make_enemy_type("diamond", Color(0.9, 0.35, 0.75), 15.0, 90.0, 70.0, 18.0, 2),
		]
	return default_enemy_types


func _make_enemy_type(shape: String, color: Color, radius: float, hp: float, speed: float, damage: float, weight: int) -> EnemyType:
	var t := EnemyType.new()
	t.shape = shape
	t.color = color
	t.radius = radius
	t.hp = hp
	t.speed = speed
	t.contact_damage = damage
	t.spawn_weight = weight
	return t


func _ready() -> void:
	_build_ui()
	time_to_next_spawn = randf_range(enemy_spawn_min, enemy_spawn_max)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.05, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	character_center = size / 2.0

	var hp_bg := Panel.new()
	# Bottom of the screen - the top half is now the note runway.
	hp_bg.position = Vector2((size.x - hp_bar_width) / 2.0, size.y - 46.0)
	hp_bg.size = Vector2(hp_bar_width, 16.0)
	var hp_bg_style := StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.2, 0.05, 0.08)
	hp_bg_style.corner_radius_top_left = 4
	hp_bg_style.corner_radius_top_right = 4
	hp_bg_style.corner_radius_bottom_left = 4
	hp_bg_style.corner_radius_bottom_right = 4
	hp_bg.add_theme_stylebox_override("panel", hp_bg_style)
	add_child(hp_bg)

	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.35, 0.85, 0.4)
	hp_fill.position = hp_bg.position
	hp_fill.size = hp_bg.size
	add_child(hp_fill)

	hp_label = Label.new()
	hp_label.position = hp_bg.position - Vector2(0.0, 22.0)
	hp_label.size = Vector2(hp_bar_width, 20.0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 14)
	add_child(hp_label)

	enemies_layer = Control.new()
	enemies_layer.anchor_right = 1.0
	enemies_layer.anchor_bottom = 1.0
	enemies_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemies_layer)

	character_node = Panel.new()
	character_node.size = Vector2(CHARACTER_RADIUS * 2.0, CHARACTER_RADIUS * 2.0)
	character_node.position = character_center - character_node.size / 2.0
	character_node.pivot_offset = character_node.size / 2.0
	character_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var char_style := StyleBoxFlat.new()
	char_style.bg_color = Color(0.55, 0.65, 1.0)
	char_style.corner_radius_top_left = int(CHARACTER_RADIUS)
	char_style.corner_radius_top_right = int(CHARACTER_RADIUS)
	char_style.corner_radius_bottom_left = int(CHARACTER_RADIUS)
	char_style.corner_radius_bottom_right = int(CHARACTER_RADIUS)
	character_node.add_theme_stylebox_override("panel", char_style)
	add_child(character_node)

	pulses_layer = Control.new()
	pulses_layer.anchor_right = 1.0
	pulses_layer.anchor_bottom = 1.0
	pulses_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pulses_layer)

	update_hp_bar()


func _process(delta: float) -> void:
	if not active:
		return

	elapsed_time += delta

	time_to_next_spawn -= delta
	if time_to_next_spawn <= 0.0:
		spawn_enemy()
		time_to_next_spawn = randf_range(enemy_spawn_min, enemy_spawn_max)

	_update_enemies(delta)
	_update_pulses()


func _pick_enemy_type() -> EnemyType:
	var total := 0
	for t in active_enemy_types:
		total += t.spawn_weight
	var roll := randi_range(1, total)
	var acc := 0
	for t in active_enemy_types:
		acc += t.spawn_weight
		if roll <= acc:
			return t
	return active_enemy_types[0]


func spawn_enemy() -> void:
	var type: EnemyType = _pick_enemy_type()
	var angle := randf() * TAU
	var spawn_radius: float = min(size.x, size.y) / 2.0 - 10.0
	var pos: Vector2 = character_center + Vector2(cos(angle), sin(angle)) * spawn_radius

	var node := Control.new()
	node.set_script(ENEMY_SCRIPT)
	node.setup(type.shape, type.color, type.radius)
	node.position = pos - node.size / 2.0
	enemies_layer.add_child(node)

	enemies.append({
		"node": node,
		"center": pos,
		"hp": type.hp,
		"radius": type.radius,
		"speed": type.speed,
		"damage": type.contact_damage,
	})


func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		var dir: Vector2 = (character_center - enemy["center"]).normalized()
		enemy["center"] = enemy["center"] + dir * float(enemy["speed"]) * delta
		enemy["node"].position = enemy["center"] - enemy["node"].size / 2.0

		if enemy["center"].distance_to(character_center) <= CHARACTER_RADIUS + float(enemy["radius"]):
			take_damage(float(enemy["damage"]))
			_remove_enemy(enemy)


func trigger_pulse(judgment: String) -> void:
	if not active:
		return

	var is_perfect := judgment == "PERFECT"
	var color: Color = PERFECT_COLOR if is_perfect else GOOD_COLOR
	var max_radius: float = PERFECT_RADIUS if is_perfect else GOOD_RADIUS
	var duration: float = PERFECT_DURATION if is_perfect else GOOD_DURATION

	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2.ZERO
	ring.position = character_center
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = color
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 500
	style.corner_radius_top_right = 500
	style.corner_radius_bottom_left = 500
	style.corner_radius_bottom_right = 500
	ring.add_theme_stylebox_override("panel", style)
	pulses_layer.add_child(ring)

	pulses.append({
		"node": ring,
		"style": style,
		"start_time": elapsed_time,
		"duration": duration,
		"max_radius": max_radius,
		"is_perfect": is_perfect,
		"hit_ids": {},
	})

	_punch_character()


func _update_pulses() -> void:
	for pulse in pulses.duplicate():
		var t: float = clamp((elapsed_time - pulse["start_time"]) / pulse["duration"], 0.0, 1.0)
		var radius: float = lerp(0.0, float(pulse["max_radius"]), t)

		pulse["node"].size = Vector2(radius * 2.0, radius * 2.0)
		pulse["node"].position = character_center - Vector2(radius, radius)

		var style: StyleBoxFlat = pulse["style"]
		var border_color: Color = style.border_color
		border_color.a = 1.0 - t
		style.border_color = border_color

		for enemy in enemies.duplicate():
			var id: int = enemy["node"].get_instance_id()
			if pulse["hit_ids"].has(id):
				continue
			if enemy["center"].distance_to(character_center) <= radius:
				pulse["hit_ids"][id] = true
				if pulse["is_perfect"]:
					_apply_damage(enemy, PERFECT_DAMAGE)
				else:
					_apply_knockback(enemy)

		if t >= 1.0:
			pulse["node"].queue_free()
			pulses.erase(pulse)


func _apply_damage(enemy: Dictionary, amount: float) -> void:
	enemy["hp"] -= amount
	if enemy["hp"] <= 0.0:
		_remove_enemy(enemy)
	else:
		_flash(enemy["node"])


func _apply_knockback(enemy: Dictionary) -> void:
	var dir: Vector2 = (enemy["center"] - character_center).normalized()
	enemy["center"] = enemy["center"] + dir * GOOD_KNOCKBACK
	_flash(enemy["node"])


func _flash(node: Control) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color(1.4, 1.4, 1.4), 0.05)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.15)


func _remove_enemy(enemy: Dictionary) -> void:
	enemies.erase(enemy)
	var node: Control = enemy["node"]
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.12)
	tween.tween_callback(node.queue_free)


func _punch_character() -> void:
	var tween := create_tween()
	tween.tween_property(character_node, "scale", Vector2(1.15, 1.15), 0.05)
	tween.tween_property(character_node, "scale", Vector2(1.0, 1.0), 0.12)


func on_note_missed() -> void:
	if not active:
		return
	take_damage(MISS_DAMAGE)


func _flinch_character() -> void:
	var tween := create_tween()
	tween.tween_property(character_node, "modulate", Color(1.7, 0.45, 0.45), 0.05)
	tween.tween_property(character_node, "modulate", Color(1, 1, 1), 0.22)


func take_damage(amount: float) -> void:
	_flinch_character()
	character_hp = max(character_hp - amount, 0.0)
	update_hp_bar()
	if character_hp <= 0.0 and active:
		active = false
		player_died.emit()


func update_hp_bar() -> void:
	var ratio: float = character_hp / CHARACTER_MAX_HP
	hp_fill.size.x = hp_bar_width * ratio
	hp_label.text = "%d / %d" % [int(character_hp), int(CHARACTER_MAX_HP)]


func set_active(value: bool) -> void:
	active = value


func reset() -> void:
	for enemy in enemies.duplicate():
		enemy["node"].queue_free()
	enemies.clear()
	for pulse in pulses.duplicate():
		pulse["node"].queue_free()
	pulses.clear()
	character_hp = CHARACTER_MAX_HP
	update_hp_bar()
	elapsed_time = 0.0
	time_to_next_spawn = randf_range(enemy_spawn_min, enemy_spawn_max)
	active = true
