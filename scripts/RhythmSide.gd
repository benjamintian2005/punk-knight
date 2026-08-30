extends Control

signal note_hit(judgment: String)
signal note_missed

const LANE_COUNT := 4
const LANE_KEY_LABELS := ["D", "F", "J", "K"]
const LANE_COLORS := [
	Color(0.95, 0.28, 0.35),
	Color(0.30, 0.85, 0.45),
	Color(0.30, 0.60, 0.98),
	Color(0.98, 0.85, 0.25),
]

const NOTE_TRAVEL_TIME := 1.4
const HIT_LINE_Y_RATIO := 0.5
const NOTE_RADIUS := 13.0
const TARGET_RADIUS := 20.0
const TARGET_SPACING := 92.0

# How hard the target reacts. A whiff barely twitches; PERFECT slams.
const WHIFF_POP := 1.12
const GOOD_POP := 1.4
const PERFECT_POP := 2.1

# Combo milestones, each louder than the last.
const COMBO_MILESTONES := [3, 10, 20, 30]
const MILESTONE_TILT := -0.30   # radians, ~17 degrees off level
const MILESTONE_WORDS := ["HOT", "SHRED", "BLISTERING", "INFERNAL"]
const MILESTONE_COLORS := [
	Color(1.0, 0.65, 0.20),
	Color(1.0, 0.85, 0.25),
	Color(1.0, 0.40, 0.30),
	Color(1.0, 1.0, 1.0),
]

const PENTAGRAM_SCRIPT := preload("res://scripts/Pentagram.gd")

const PERFECT_WINDOW := 0.05
const GOOD_WINDOW := 0.12
const MISS_WINDOW := 0.18

const START_OFFSET := 1.5

# Level-dependent song settings; overridden by configure() before _ready runs.
# lane index per step, -1 is a rest. One step = an eighth note at bpm.
var bpm := 120.0
var beat_pattern := [0, -1, 1, -1, 2, 3, -1, 1, 0, 2, -1, 3, 1, -1, 0, -1]
var pattern_repeats := 4

# Real-song chart (absolute timestamps). Non-empty means it wins over beat_pattern.
var song_path := ""
var audio_offset := 0.0
var note_times := PackedFloat32Array()
var note_lanes := PackedInt32Array()
var audio: AudioStreamPlayer = null

var active := true

var lane_center_x: Array = []
var hit_line_y: float
var note_size: Vector2
var note_speed: float

var song_time := 0.0
var beatmap: Array = []
var next_note_index := 0
var active_notes: Array = []

var score := 0
var combo := 0
var max_combo := 0
var combo_tier := -1

var notes_layer: Control
var target_rings: Array = []
var ring_tweens: Array = []
var score_label: Label
var judgment_label: Label
var judgment_tween: Tween
var combo_label: Label
var combo_tween: Tween


func _ready() -> void:
	generate_beatmap()
	_build_ui()
	_setup_audio()


func _build_ui() -> void:
	# No background and no lane columns - just the arena, the knight, and
	# four targets sitting on him.
	hit_line_y = size.y * HIT_LINE_Y_RATIO
	note_size = Vector2(NOTE_RADIUS * 2.0, NOTE_RADIUS * 2.0)
	note_speed = (hit_line_y - (-note_size.y)) / NOTE_TRAVEL_TIME

	for i in LANE_COUNT:
		# Four targets spread evenly about the centre of the screen.
		var cx := size.x / 2.0 + (float(i) - (LANE_COUNT - 1) / 2.0) * TARGET_SPACING
		lane_center_x.append(cx)

		# The circle a ball drops into.
		var ring := Panel.new()
		ring.size = Vector2(TARGET_RADIUS * 2.0, TARGET_RADIUS * 2.0)
		ring.position = Vector2(cx - TARGET_RADIUS, hit_line_y - TARGET_RADIUS)
		ring.pivot_offset = ring.size / 2.0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color = Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.10)
		ring_style.border_color = Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.55)
		ring_style.set_border_width_all(3)
		ring_style.set_corner_radius_all(int(TARGET_RADIUS))
		ring.add_theme_stylebox_override("panel", ring_style)
		add_child(ring)
		target_rings.append(ring)
		ring_tweens.append(null)

		# The letter stays, small, so the binding is still learnable.
		var key_label := Label.new()
		key_label.text = LANE_KEY_LABELS[i]
		key_label.position = Vector2(cx - 20.0, hit_line_y + TARGET_RADIUS + 8.0)
		key_label.size = Vector2(40.0, 20.0)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.45))
		add_child(key_label)

	notes_layer = Control.new()
	notes_layer.anchor_right = 1.0
	notes_layer.anchor_bottom = 1.0
	notes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notes_layer)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(16.0, 16.0)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.add_theme_font_size_override("font_size", 18)
	add_child(score_label)

	# Feedback goes BELOW the knight - everything above him is note runway.
	judgment_label = Label.new()
	judgment_label.text = ""
	judgment_label.position = Vector2(0.0, hit_line_y + 86.0)
	judgment_label.size = Vector2(size.x, 40.0)
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	judgment_label.add_theme_font_size_override("font_size", 22)
	judgment_label.modulate = Color(1, 1, 1, 0)
	judgment_label.pivot_offset = Vector2(size.x / 2.0, 20.0)
	add_child(judgment_label)

	combo_label = Label.new()
	combo_label.text = ""
	combo_label.position = Vector2(size.x / 2.0 + TARGET_SPACING * 2.0 + 16.0, hit_line_y - 84.0)
	combo_label.size = Vector2(400.0, 52.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_label.add_theme_font_size_override("font_size", 36)
	combo_label.modulate = Color(1, 1, 1, 0)
	# Pivot on the left edge so it scales and swings OUT from the targets.
	combo_label.pivot_offset = Vector2(0.0, 26.0)
	combo_label.rotation = MILESTONE_TILT
	add_child(combo_label)


func configure(level: LevelData) -> void:
	bpm = level.bpm
	beat_pattern = level.beat_pattern
	pattern_repeats = level.pattern_repeats
	song_path = level.song_path
	audio_offset = level.audio_offset
	note_times = level.note_times
	note_lanes = level.note_lanes


func _setup_audio() -> void:
	if song_path == "" or not ResourceLoader.exists(song_path):
		return
	audio = AudioStreamPlayer.new()
	audio.stream = load(song_path)
	add_child(audio)
	audio.play()


func has_song() -> bool:
	return audio != null


func generate_beatmap() -> void:
	beatmap.clear()

	# An authored chart: absolute times, already lined up with the recording.
	if note_times.size() > 0:
		for i in note_times.size():
			beatmap.append({"time": note_times[i] + audio_offset, "lane": note_lanes[i]})
		return

	# Otherwise fall back to the looping eighth-note pattern levels.
	var step := 60.0 / bpm / 2.0
	var t := START_OFFSET
	for r in pattern_repeats:
		for lane in beat_pattern:
			if lane >= 0 and lane < LANE_COUNT:
				beatmap.append({"time": t, "lane": lane})
			t += step


func _process(delta: float) -> void:
	if not active:
		return

	for lane in LANE_COUNT:
		if Input.is_action_just_pressed("lane_%d" % lane):
			flash_hit_line(lane)
			try_hit(lane)

	if audio != null and audio.playing:
		# The audio clock is the source of truth - the frame clock drifts from it.
		song_time = audio.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
	else:
		song_time += delta

	while next_note_index < beatmap.size() and beatmap[next_note_index]["time"] - NOTE_TRAVEL_TIME <= song_time:
		spawn_note(beatmap[next_note_index])
		next_note_index += 1

	if audio == null and next_note_index >= beatmap.size() and active_notes.is_empty():
		song_time = 0.0
		next_note_index = 0

	for note in active_notes.duplicate():
		var t_remaining: float = note["hit_time"] - song_time
		note["node"].position.y = hit_line_y - t_remaining * note_speed
		if not note["judged"] and t_remaining < -MISS_WINDOW:
			judge_miss(note)


func spawn_note(beat: Dictionary) -> void:
	var lane: int = beat["lane"]
	var note_panel := Panel.new()
	note_panel.size = note_size
	note_panel.position = Vector2(lane_center_x[lane] - note_size.x / 2.0, -note_size.y)
	var style := StyleBoxFlat.new()
	style.bg_color = LANE_COLORS[lane]
	style.corner_radius_top_left = int(NOTE_RADIUS)
	style.corner_radius_top_right = int(NOTE_RADIUS)
	style.corner_radius_bottom_left = int(NOTE_RADIUS)
	style.corner_radius_bottom_right = int(NOTE_RADIUS)
	note_panel.add_theme_stylebox_override("panel", style)

	# The sigil is a CHILD of the ball, so it rides along and fades with it.
	var sigil := Control.new()
	sigil.set_script(PENTAGRAM_SCRIPT)
	sigil.size = note_size
	sigil.radius = NOTE_RADIUS - 3.5
	sigil.line_width = 1.5
	sigil.color = Color(0.05, 0.03, 0.08, 0.8)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_panel.add_child(sigil)

	notes_layer.add_child(note_panel)

	active_notes.append({
		"node": note_panel,
		"lane": lane,
		"hit_time": beat["time"],
		"judged": false,
	})


func try_hit(lane: int) -> void:
	var best_note = null
	var best_diff := INF
	for note in active_notes:
		if note["lane"] == lane and not note["judged"]:
			var diff: float = abs(song_time - note["hit_time"])
			if diff < best_diff:
				best_diff = diff
				best_note = note

	if best_note != null and best_diff <= GOOD_WINDOW:
		if best_diff <= PERFECT_WINDOW:
			judge_hit(best_note, "PERFECT", 300, Color(1.0, 0.9, 0.3))
		else:
			judge_hit(best_note, "GOOD", 100, Color(0.6, 1.0, 0.6))
	elif best_note != null and best_diff <= MISS_WINDOW:
		# Badly mistimed but a note WAS there - burn it, so it can't be
		# punished a second time when it sails past the target.
		judge_miss(best_note)
	else:
		# Nothing anywhere near this key. Pressing it is its own mistake.
		judge_whiff()


func judge_hit(note: Dictionary, text: String, points: int, color: Color) -> void:
	note["judged"] = true
	score += points
	combo += 1
	max_combo = max(max_combo, combo)
	var tier := _milestone_tier(combo)
	if tier >= 0:
		combo_tier = tier
	update_labels()
	var is_perfect := text == "PERFECT"
	show_judgment(text, color, 1.9 if is_perfect else 1.3)
	flare_target(note["lane"], is_perfect)
	_refresh_combo(tier)
	if tier >= 0:
		_combo_flair(tier)
	remove_note(note)
	note_hit.emit(text)


func judge_miss(note: Dictionary) -> void:
	note["judged"] = true
	combo = 0
	combo_tier = -1
	update_labels()
	_hide_combo()
	show_judgment("MISS", Color(1.0, 0.35, 0.35))
	remove_note(note)
	note_missed.emit()


func judge_whiff() -> void:
	combo = 0
	combo_tier = -1
	update_labels()
	_hide_combo()
	show_judgment("MISS", Color(1.0, 0.35, 0.35))
	note_missed.emit()


func remove_note(note: Dictionary) -> void:
	active_notes.erase(note)
	var node: Panel = note["node"]
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.tween_callback(node.queue_free)


func update_labels() -> void:
	score_label.text = "Score: %d" % score


func show_judgment(text: String, color: Color, punch: float = 1.3) -> void:
	judgment_label.text = text
	judgment_label.modulate = Color(color.r, color.g, color.b, 1.0)
	judgment_label.scale = Vector2(punch, punch)

	if judgment_tween:
		judgment_tween.kill()
	judgment_tween = create_tween()
	judgment_tween.tween_property(judgment_label, "scale", Vector2(1.0, 1.0), 0.12)
	judgment_tween.tween_interval(0.15)
	judgment_tween.tween_property(judgment_label, "modulate:a", 0.0, 0.35)


func _pop_ring(lane: int, amount: float, duration: float) -> void:
	# Kill any pop still in flight, or a press mid-animation fights the flare.
	var existing = ring_tweens[lane]
	if existing != null and existing.is_valid():
		existing.kill()

	var ring: Panel = target_rings[lane]
	ring.scale = Vector2(amount, amount)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_tweens[lane] = t


func flash_hit_line(lane: int) -> void:
	# Fires on EVERY press, hit or not - so a whiff still feels like something.
	_pop_ring(lane, WHIFF_POP, 0.16)

	var style: StyleBoxFlat = target_rings[lane].get_theme_stylebox("panel")
	var glow := create_tween()
	glow.tween_property(style, "border_color:a", 1.0, 0.03)
	glow.tween_property(style, "border_color:a", 0.55, 0.15)


func flare_target(lane: int, is_perfect: bool) -> void:
	_pop_ring(lane, PERFECT_POP if is_perfect else GOOD_POP, 0.34 if is_perfect else 0.22)
	_spawn_burst(lane, is_perfect)

	# PERFECT washes the ring white; GOOD just saturates its own colour.
	var style: StyleBoxFlat = target_rings[lane].get_theme_stylebox("panel")
	var base: Color = LANE_COLORS[lane]
	var peak: Color = Color(1.0, 1.0, 1.0, 1.0) if is_perfect else Color(base.r, base.g, base.b, 1.0)
	style.border_color = peak
	var cool := create_tween()
	cool.tween_property(style, "border_color", Color(base.r, base.g, base.b, 0.55), 0.35 if is_perfect else 0.2)


func _spawn_ring_at(centre: Vector2, start_r: float, end_r: float, col: Color, width: int, dur: float) -> void:
	var ring := Panel.new()
	ring.size = Vector2(end_r * 2.0, end_r * 2.0)
	ring.pivot_offset = ring.size / 2.0
	ring.position = centre - Vector2(end_r, end_r)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	st.border_color = col
	st.set_border_width_all(width)
	st.set_corner_radius_all(int(end_r))
	ring.add_theme_stylebox_override("panel", st)
	add_child(ring)

	# Grow by SCALE rather than size, so it stays centred for free.
	var s0: float = start_r / end_r
	ring.scale = Vector2(s0, s0)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, dur)
	t.chain().tween_callback(ring.queue_free)


func _spawn_burst(lane: int, is_perfect: bool) -> void:
	_spawn_ring_at(
		Vector2(lane_center_x[lane], hit_line_y),
		TARGET_RADIUS,
		TARGET_RADIUS * (3.0 if is_perfect else 1.8),
		Color(1.0, 0.95, 0.55) if is_perfect else LANE_COLORS[lane],
		3 if is_perfect else 2,
		0.45 if is_perfect else 0.26)


func _milestone_tier(n: int) -> int:
	var idx := COMBO_MILESTONES.find(n)
	if idx != -1:
		return idx
	# Past the last milestone the top tier keeps firing every 10, so a long
	# run doesn't go silent exactly when it's most impressive.
	if n > int(COMBO_MILESTONES[-1]) and n % 10 == 0:
		return COMBO_MILESTONES.size() - 1
	return -1


func _refresh_combo(tier: int) -> void:
	if combo <= 1:
		_hide_combo()
		return

	var is_milestone := tier >= 0
	var col: Color = Color(1, 1, 1) if combo_tier < 0 else MILESTONE_COLORS[combo_tier]

	# Bare number normally; the word only shows up when a milestone lands.
	combo_label.text = ("%s  %d" % [MILESTONE_WORDS[tier], combo]) if is_milestone else ("%d" % combo)
	combo_label.add_theme_color_override("font_color", col)
	combo_label.modulate = Color(1, 1, 1, 1)

	# Every hit pulses. A milestone slams.
	var punch: float = (2.2 + tier * 0.25) if is_milestone else 1.32
	var kick: float = 0.24 if is_milestone else 0.06
	combo_label.scale = Vector2(punch, punch)
	combo_label.rotation = MILESTONE_TILT - kick

	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	combo_tween.set_parallel(true)
	combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.30 if is_milestone else 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	combo_tween.tween_property(combo_label, "rotation", MILESTONE_TILT, 0.34 if is_milestone else 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_combo() -> void:
	if combo_tween:
		combo_tween.kill()
	combo_tween = create_tween()
	combo_tween.tween_property(combo_label, "modulate:a", 0.0, 0.18)


func _combo_flair(tier: int) -> void:
	var col: Color = MILESTONE_COLORS[tier]

	# Every target fires at once...
	for i in LANE_COUNT:
		_pop_ring(i, 1.5 + tier * 0.18, 0.34)
		_spawn_ring_at(Vector2(lane_center_x[i], hit_line_y), TARGET_RADIUS,
			TARGET_RADIUS * (2.2 + tier * 0.5), col, 3, 0.42)

	# ...and one big wave rolls off the knight himself.
	_spawn_ring_at(Vector2(size.x / 2.0, hit_line_y), TARGET_RADIUS,
		140.0 + tier * 90.0, col, 4 + tier, 0.55 + tier * 0.1)


func set_active(value: bool) -> void:
	active = value
	if audio != null:
		audio.stream_paused = not value


func reset() -> void:
	for note in active_notes.duplicate():
		note["node"].queue_free()
	active_notes.clear()
	song_time = 0.0
	next_note_index = 0
	score = 0
	combo = 0
	combo_tier = -1
	max_combo = 0
	update_labels()
	judgment_label.modulate.a = 0.0
	combo_label.modulate.a = 0.0
	active = true
	if audio != null:
		audio.stop()
		audio.play()
