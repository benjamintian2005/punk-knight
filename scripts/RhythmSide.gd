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
const HIT_LINE_Y_RATIO := 0.8
const LANE_WIDTH := 96.0
const LANE_GAP := 6.0

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

var notes_layer: Control
var hit_line_panels: Array = []
var score_label: Label
var combo_label: Label
var judgment_label: Label
var judgment_tween: Tween


func _ready() -> void:
	generate_beatmap()
	_build_ui()
	_setup_audio()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.06, 0.06, 0.09)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	var total_width := LANE_COUNT * LANE_WIDTH + (LANE_COUNT - 1) * LANE_GAP
	var start_x := (size.x - total_width) / 2.0
	hit_line_y = size.y * HIT_LINE_Y_RATIO
	note_size = Vector2(LANE_WIDTH - 14.0, 26.0)
	note_speed = (hit_line_y - (-note_size.y)) / NOTE_TRAVEL_TIME

	for i in LANE_COUNT:
		var lane_x := start_x + i * (LANE_WIDTH + LANE_GAP)
		lane_center_x.append(lane_x + LANE_WIDTH / 2.0)

		var lane_panel := Panel.new()
		lane_panel.position = Vector2(lane_x, 0.0)
		lane_panel.size = Vector2(LANE_WIDTH, size.y)
		var lane_style := StyleBoxFlat.new()
		lane_style.bg_color = Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.06)
		lane_panel.add_theme_stylebox_override("panel", lane_style)
		add_child(lane_panel)

		var hit_line := Panel.new()
		hit_line.position = Vector2(lane_x, hit_line_y - 4.0)
		hit_line.size = Vector2(LANE_WIDTH, 8.0)
		var hit_style := StyleBoxFlat.new()
		hit_style.bg_color = Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.5)
		hit_style.corner_radius_top_left = 4
		hit_style.corner_radius_top_right = 4
		hit_style.corner_radius_bottom_left = 4
		hit_style.corner_radius_bottom_right = 4
		hit_line.add_theme_stylebox_override("panel", hit_style)
		add_child(hit_line)
		hit_line_panels.append(hit_line)

		var key_label := Label.new()
		key_label.text = LANE_KEY_LABELS[i]
		key_label.position = Vector2(lane_x, hit_line_y + 16.0)
		key_label.size = Vector2(LANE_WIDTH, 40.0)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 24)
		key_label.add_theme_color_override("font_color", LANE_COLORS[i])
		add_child(key_label)

	notes_layer = Control.new()
	notes_layer.anchor_right = 1.0
	notes_layer.anchor_bottom = 1.0
	notes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notes_layer)

	var title_label := Label.new()
	title_label.text = "D  F  J  K"
	title_label.position = Vector2(0.0, 20.0)
	title_label.size = Vector2(size.x, 30.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	add_child(title_label)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(16.0, 20.0)
	score_label.add_theme_font_size_override("font_size", 18)
	add_child(score_label)

	combo_label = Label.new()
	combo_label.text = ""
	combo_label.position = Vector2(0.0, hit_line_y - 80.0)
	combo_label.size = Vector2(size.x, 40.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 24)
	combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	add_child(combo_label)

	judgment_label = Label.new()
	judgment_label.text = ""
	judgment_label.position = Vector2(0.0, hit_line_y - 128.0)
	judgment_label.size = Vector2(size.x, 40.0)
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.add_theme_font_size_override("font_size", 22)
	judgment_label.modulate = Color(1, 1, 1, 0)
	judgment_label.pivot_offset = Vector2(size.x / 2.0, 20.0)
	add_child(judgment_label)


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
	audio.bus = "Music"
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
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	note_panel.add_theme_stylebox_override("panel", style)
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


func judge_hit(note: Dictionary, text: String, points: int, color: Color) -> void:
	note["judged"] = true
	score += points
	combo += 1
	max_combo = max(max_combo, combo)
	update_labels()
	show_judgment(text, color)
	remove_note(note)
	note_hit.emit(text)


func judge_miss(note: Dictionary) -> void:
	note["judged"] = true
	combo = 0
	update_labels()
	show_judgment("MISS", Color(1.0, 0.35, 0.35))
	remove_note(note)
	note_missed.emit()


func remove_note(note: Dictionary) -> void:
	active_notes.erase(note)
	var node: Panel = note["node"]
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.12)
	tween.tween_callback(node.queue_free)


func update_labels() -> void:
	score_label.text = "Score: %d" % score
	combo_label.text = ("Combo: %d" % combo) if combo > 1 else ""


func show_judgment(text: String, color: Color) -> void:
	judgment_label.text = text
	judgment_label.modulate = Color(color.r, color.g, color.b, 1.0)
	judgment_label.scale = Vector2(1.3, 1.3)

	if judgment_tween:
		judgment_tween.kill()
	judgment_tween = create_tween()
	judgment_tween.tween_property(judgment_label, "scale", Vector2(1.0, 1.0), 0.12)
	judgment_tween.tween_interval(0.15)
	judgment_tween.tween_property(judgment_label, "modulate:a", 0.0, 0.35)


func flash_hit_line(lane: int) -> void:
	var hit_line: Panel = hit_line_panels[lane]
	var style: StyleBoxFlat = hit_line.get_theme_stylebox("panel")
	var tween := create_tween()
	tween.tween_property(style, "bg_color:a", 1.0, 0.03)
	tween.tween_property(style, "bg_color:a", 0.5, 0.15)


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
	max_combo = 0
	update_labels()
	judgment_label.modulate.a = 0.0
	active = true
	if audio != null:
		audio.stop()
		audio.play()
