extends Control

signal note_hit(judgment: String)
signal note_missed

const LANE_COUNT := 4
const LANE_KEY_LABELS := ["←", "↓", "↑", "→"]
const LANE_COLORS := [
	Color(0.95, 0.28, 0.35),
	Color(0.30, 0.85, 0.45),
	Color(0.30, 0.60, 0.98),
	Color(0.98, 0.85, 0.25),
]

const NOTE_TRAVEL_TIME := 1.4
const HIT_LINE_Y_RATIO := 0.5
const NOTE_ARC_HALF := 0.17   # half-width of the slice a creature carries
const ARC_GAP := 0.05   # radians trimmed off each end so the four read as four

# D F J K -> left, down, up, right. Outward from the knight.
const LANE_DIRS := [Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]
const WEDGE_HALF_ANGLE := PI / 4.0   # 45 deg each side -> the four wedges tile
                                     # the full circle with no dead ground
const STRIKE_RADIUS := 88.0    # where a creature is judged
const SPAWN_RADIUS := 300.0    # where it appears; same on every rail, so
                               # distance reads as time identically in all four

# How hard the target reacts. A whiff barely twitches; PERFECT slams.
const WHIFF_POP := 1.05
const GOOD_POP := 1.15
const PERFECT_POP := 1.34

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

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const LANE_ARC_SCRIPT := preload("res://scripts/LaneArc.gd")

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

var arena_center: Vector2
var lane_anchor: Array = []
var enemy_types: Array[EnemyType] = []

var song_time := 0.0
var beatmap: Array = []
var next_note_index := 0
var active_notes: Array = []

var score := 0
var combo := 0
var max_combo := 0
var combo_tier := -1

var notes_layer: Control
var lane_arcs: Array = []
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
	# One arena: the knight at the centre, four rails running out from him.
	arena_center = Vector2(size.x / 2.0, size.y * HIT_LINE_Y_RATIO)

	for i in LANE_COUNT:
		var base: float = LANE_DIRS[i].angle()
		lane_anchor.append(arena_center + LANE_DIRS[i] * STRIKE_RADIUS)

		# A 90-degree arc of the strike ring. Pivot is the knight, so popping it
		# scales the arc outward from him.
		var arc := Control.new()
		arc.set_script(LANE_ARC_SCRIPT)
		arc.size = size
		arc.pivot_offset = arena_center
		arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arc.centre = arena_center
		arc.radius = STRIKE_RADIUS
		arc.color = LANE_COLORS[i]
		arc.start_angle = base - WEDGE_HALF_ANGLE + ARC_GAP
		arc.end_angle = base + WEDGE_HALF_ANGLE - ARC_GAP
		add_child(arc)
		lane_arcs.append(arc)
		ring_tweens.append(null)

		var key_label := Label.new()
		key_label.size = Vector2(40.0, 20.0)
		key_label.position = arena_center + LANE_DIRS[i] * (STRIKE_RADIUS + 30.0) - key_label.size / 2.0
		key_label.text = LANE_KEY_LABELS[i]
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.add_theme_font_size_override("font_size", 20)
		key_label.add_theme_color_override("font_color", Color(LANE_COLORS[i].r, LANE_COLORS[i].g, LANE_COLORS[i].b, 0.75))
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

	# The rails claim up/down/left/right, so text lives on the DIAGONALS.
	judgment_label = Label.new()
	judgment_label.text = ""
	judgment_label.size = Vector2(260.0, 40.0)
	judgment_label.position = arena_center + Vector2(-200.0, -160.0) - judgment_label.size / 2.0
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	judgment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	judgment_label.add_theme_font_size_override("font_size", 22)
	judgment_label.modulate = Color(1, 1, 1, 0)
	judgment_label.pivot_offset = judgment_label.size / 2.0
	add_child(judgment_label)

	combo_label = Label.new()
	combo_label.text = ""
	combo_label.size = Vector2(360.0, 52.0)
	combo_label.position = arena_center + Vector2(150.0, -180.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_label.add_theme_font_size_override("font_size", 36)
	combo_label.modulate = Color(1, 1, 1, 0)
	combo_label.pivot_offset = Vector2(0.0, 26.0)
	combo_label.rotation = MILESTONE_TILT
	add_child(combo_label)


func set_enemy_types(types: Array[EnemyType]) -> void:
	enemy_types = types


func _pick_enemy_type() -> EnemyType:
	if enemy_types.is_empty():
		return EnemyType.new()
	var total := 0
	for t in enemy_types:
		total += t.spawn_weight
	if total <= 0:
		return enemy_types[0]
	var roll := randi_range(1, total)
	var acc := 0
	for t in enemy_types:
		acc += t.spawn_weight
		if roll <= acc:
			return t
	return enemy_types[0]


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
		_place_note(note, t_remaining)
		if not note["judged"] and t_remaining < -MISS_WINDOW:
			judge_miss(note)

	queue_redraw()


func _draw() -> void:
	# Every creature carries the slice of the ring it is going to land on: an arc
	# at its own radius, spanning its own angle. As it closes, the slice shrinks
	# onto the strike ring and brightens - arriving exactly fills in that piece
	# of the circle. Drawn here on the parent, so it sits UNDER the creatures.
	for note in active_notes:
		var dist: float = note.get("dist", SPAWN_RADIUS)
		var ang: float = note.get("angle", 0.0)
		var near: float = 1.0 - clampf((dist - STRIKE_RADIUS) / (SPAWN_RADIUS - STRIKE_RADIUS), 0.0, 1.0)
		var col: Color = LANE_COLORS[note["lane"]]
		draw_arc(arena_center, dist, ang - NOTE_ARC_HALF, ang + NOTE_ARC_HALF, 28,
			Color(col.r, col.g, col.b, lerpf(0.22, 1.0, near)),
			lerpf(2.5, 7.0, near), true)


func _place_note(note: Dictionary, t_remaining: float) -> void:
	# Distance IS time: full travel time sits at SPAWN_RADIUS, zero sits exactly
	# on the strike ring, negative keeps walking in toward the knight.
	var lane: int = note["lane"]
	var f: float = clampf(t_remaining / NOTE_TRAVEL_TIME, -1.0, 1.0)
	var dist: float = STRIKE_RADIUS + f * (SPAWN_RADIUS - STRIKE_RADIUS)

	# Each lane owns a full 90-degree wedge, and its arc spans that whole wedge -
	# so a creature just walks straight in on whatever angle it spawned at and
	# still crosses its own lane's target. No convergence needed.
	#
	# The offset is ANGULAR, so radial distance is untouched, and that is what
	# the timing is measured on. Spread costs nothing mechanically.
	var dir: Vector2 = LANE_DIRS[lane].rotated(float(note["spread"]) * WEDGE_HALF_ANGLE)
	var anchor: Vector2 = arena_center + dir * dist

	note["angle"] = dir.angle()
	note["dist"] = dist

	var node: Control = note["node"]
	# Bottom-centre is the anchor, so the creature stands ON its rune and the
	# rune is what lines up with the ring.
	node.position = anchor - Vector2(node.size.x / 2.0, node.size.y)
	# It walks inward, so it faces the way it came from.
	node.set_facing(dir.x > 0.0)
	# Nearer draws over further, so overlap reads as depth instead of a glitch.
	# Must stay NON-NEGATIVE: z_index sorts across the whole canvas layer, not
	# just among siblings, so a negative value hides these behind BattleSide's
	# opaque background.
	node.z_index = maxi(0, int(SPAWN_RADIUS - dist))


func spawn_note(beat: Dictionary) -> void:
	var lane: int = beat["lane"]
	var type: EnemyType = _pick_enemy_type()

	var node := Control.new()
	node.set_script(ENEMY_SCRIPT)
	node.setup(type)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_layer.add_child(node)

	var note := {
		"node": node,
		"lane": lane,
		"hit_time": beat["time"],
		"judged": false,
		# Where in this lane's wedge it comes from: -1 one edge, +1 the other.
		"spread": randf_range(-0.88, 0.88),
	}
	active_notes.append(note)
	_place_note(note, NOTE_TRAVEL_TIME)

	# They appear on-screen rather than off it, so fade them in.
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, 0.22)


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
	var node: Control = note["node"]
	node.set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, 0.18)
	tween.tween_property(node, "scale", Vector2(1.4, 1.4), 0.18)
	tween.chain().tween_callback(node.queue_free)


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
	# Kill any pop still in flight, or a press during a flare fights it.
	var existing = ring_tweens[lane]
	if existing != null and existing.is_valid():
		existing.kill()

	var arc: Control = lane_arcs[lane]
	arc.scale = Vector2(amount, amount)
	var t := create_tween()
	t.tween_property(arc, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_tweens[lane] = t


func flash_hit_line(lane: int) -> void:
	# Fires on EVERY press, hit or not - so a whiff still feels like something.
	_pop_ring(lane, WHIFF_POP, 0.16)
	var arc: Control = lane_arcs[lane]
	var glow := create_tween()
	glow.tween_property(arc, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.03)
	glow.tween_property(arc, "modulate", Color(1, 1, 1, 1), 0.15)


func flare_target(lane: int, is_perfect: bool) -> void:
	_pop_ring(lane, PERFECT_POP if is_perfect else GOOD_POP, 0.34 if is_perfect else 0.22)
	_spawn_burst(lane, is_perfect)

	var arc: Control = lane_arcs[lane]
	arc.modulate = Color(2.6, 2.6, 2.6, 1.0) if is_perfect else Color(1.8, 1.8, 1.8, 1.0)
	var cool := create_tween()
	cool.tween_property(arc, "modulate", Color(1, 1, 1, 1), 0.35 if is_perfect else 0.2)


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
		lane_anchor[lane],
		18.0,
		18.0 * (3.0 if is_perfect else 1.8),
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
		_spawn_ring_at(lane_anchor[i], 18.0,
			18.0 * (2.2 + tier * 0.5), col, 3, 0.42)

	# ...and one big wave rolls off the knight himself.
	_spawn_ring_at(arena_center, 18.0,
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
