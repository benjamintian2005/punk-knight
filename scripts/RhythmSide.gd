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

# How long an arc is on screen before it lands. This IS the reaction window,
# so it is the first thing to turn up if the chart feels unreadable.
const NOTE_TRAVEL_TIME := 2.2
const HIT_LINE_Y_RATIO := 0.5
const ARC_GAP := 0.05   # radians trimmed off each end so the four read as four
const ARC_SEGMENTS := 48   # a full 90-degree sweep needs more than a slice did

# D F J K -> left, down, up, right. Outward from the knight.
const LANE_DIRS := [Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]
const WEDGE_HALF_ANGLE := PI / 4.0   # 45 deg each side -> the four wedges tile
									 # the full circle with no dead ground
const STRIKE_RADIUS := 88.0    # where a creature is judged

# The rune under a creature and the strike ring are both strokes, so they touch
# when the gap between their centre lines closes to half of each: the ring core
# is LaneArc.thickness (5) wide, the rune tops out at NOTE_ARC_WIDTH_NEAR (7).
const NOTE_ARC_WIDTH_FAR := 3.5
const NOTE_ARC_WIDTH_NEAR := 7.0
const CONTACT_BAND := 6.0

# Contact lights the quadrant almost instantly and lets it cool slowly, so the
# ring reads as struck rather than blinking.
const GLOW_ATTACK := 22.0
const GLOW_RELEASE := 3.5
# Bloom stacked under a touching rune, same faked-glow trick the ring uses.
const CONTACT_GLOW_PASSES := [[4.2, 0.10], [2.4, 0.16], [1.5, 0.24]]
# Where an arc appears - the same on every rail, so distance reads as time
# identically in all four. Sized to the arena rather than fixed, so the extra
# room on a bigger window becomes extra runway instead of dead margin.
const SPAWN_MARGIN := 16.0
var spawn_radius := 300.0

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

var song_time := 0.0
var beatmap: Array = []
var next_note_index := 0
var active_notes: Array = []

var score := 0
var combo := 0
var max_combo := 0
var combo_tier := -1

# Consecutive PERFECTs only - breaks on a GOOD, not just a miss, so it stays
# a genuine precision reward rather than a looser combo variant.
var perfect_streak := 0
const BIG_PULSE_STREAK := 5

var lane_arcs: Array = []
var lane_glow: Array = []
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
	# Every rail has to fit on screen, so the shorter axis sets the runway.
	spawn_radius = minf(size.x, size.y) / 2.0 - SPAWN_MARGIN

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
		lane_glow.append(0.0)
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


# The chart's first beat, for anything that wants to line up with it - the
# horde uses it to time its arrival. Absolute song time, offset included.
func first_note_time() -> float:
	return float(beatmap[0]["time"]) if beatmap.size() > 0 else 0.0


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

	var lane_lit := []
	lane_lit.resize(LANE_COUNT)
	lane_lit.fill(false)

	for note in active_notes.duplicate():
		var t_remaining: float = note["hit_time"] - song_time
		_place_note(note, t_remaining)
		# Latched on first touch: a creature that walks THROUGH the ring keeps
		# its rune lit instead of blinking off on the way past.
		if not note["contact"] and absf(float(note["dist"]) - STRIKE_RADIUS) <= CONTACT_BAND:
			note["contact"] = true
		if note["contact"]:
			lane_lit[note["lane"]] = true
		if not note["judged"] and t_remaining < -MISS_WINDOW:
			judge_miss(note)

	_update_lane_glow(lane_lit, delta)
	queue_redraw()


func _update_lane_glow(lane_lit: Array, delta: float) -> void:
	for lane in LANE_COUNT:
		var target: float = 1.0 if lane_lit[lane] else 0.0
		var rate: float = GLOW_ATTACK if target > lane_glow[lane] else GLOW_RELEASE
		lane_glow[lane] = move_toward(lane_glow[lane], target, rate * delta)
		lane_arcs[lane].glow = lane_glow[lane]


func _draw() -> void:
	# A beat IS its quadrant's arc, drawn out at its own radius and closing in.
	# It spans exactly the angles of the strike arc underneath it, so the arc
	# gets physically shorter as it approaches and lands filling that quadrant
	# precisely - the shrink is the timing cue.
	for note in active_notes:
		var lane: int = note["lane"]
		var target: Control = lane_arcs[lane]
		var dist: float = note.get("dist", spawn_radius)
		var near: float = 1.0 - clampf((dist - STRIKE_RADIUS) / (spawn_radius - STRIKE_RADIUS), 0.0, 1.0)
		var col: Color = LANE_COLORS[lane]
		var width: float = lerpf(NOTE_ARC_WIDTH_FAR, NOTE_ARC_WIDTH_NEAR, near)
		# Touching down blooms the arc out around its core, so the landing
		# reads as a flare and not just the end of a fade.
		if note["contact"]:
			for glow_pass in CONTACT_GLOW_PASSES:
				draw_arc(arena_center, dist, target.start_angle, target.end_angle, ARC_SEGMENTS,
					Color(col.r, col.g, col.b, glow_pass[1]), width * glow_pass[0], true)
		# Brightness ramps early rather than linearly, so an arc is readable as
		# soon as it appears instead of only once it is nearly on top of you.
		draw_arc(arena_center, dist, target.start_angle, target.end_angle, ARC_SEGMENTS,
			Color(col.r, col.g, col.b, lerpf(0.45, 1.0, sqrt(near))), width, true)


func _place_note(note: Dictionary, t_remaining: float) -> void:
	# Distance IS time: full travel time sits at spawn_radius, zero sits exactly
	# on the strike ring, negative keeps closing in on the knight. The angles
	# never move - only the radius does - so the arc sweeps the same quadrant
	# the whole way in and simply contracts onto its target.
	var f: float = clampf(t_remaining / NOTE_TRAVEL_TIME, -1.0, 1.0)
	note["dist"] = STRIKE_RADIUS + f * (spawn_radius - STRIKE_RADIUS)


func spawn_note(beat: Dictionary) -> void:
	var note := {
		"lane": beat["lane"],
		"hit_time": beat["time"],
		"judged": false,
		# Set once the arc reaches the ring; lights the arc and its quadrant.
		"contact": false,
	}
	active_notes.append(note)
	_place_note(note, NOTE_TRAVEL_TIME)


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
	Sfx.play("hit_perfect" if is_perfect else "hit_good")
	show_judgment(text, color, 1.9 if is_perfect else 1.3)
	flare_target(note["lane"], is_perfect)
	_refresh_combo(tier)
	if tier >= 0:
		_combo_flair(tier)
		Sfx.play("combo_milestone")
	remove_note(note)
	note_hit.emit(text)

	if is_perfect:
		perfect_streak += 1
		if perfect_streak >= BIG_PULSE_STREAK:
			perfect_streak = 0
			Sfx.play("big", 0.0)
			note_hit.emit("BIG")
	else:
		perfect_streak = 0


func judge_miss(note: Dictionary) -> void:
	note["judged"] = true
	combo = 0
	combo_tier = -1
	perfect_streak = 0
	update_labels()
	_hide_combo()
	Sfx.play("miss")
	show_judgment("MISS", Color(1.0, 0.35, 0.35))
	remove_note(note)
	note_missed.emit()


func judge_whiff() -> void:
	combo = 0
	combo_tier = -1
	perfect_streak = 0
	update_labels()
	_hide_combo()
	Sfx.play("miss")
	show_judgment("MISS", Color(1.0, 0.35, 0.35))
	note_missed.emit()


func remove_note(note: Dictionary) -> void:
	# The arc is drawn straight from active_notes, so dropping it is the whole
	# cleanup - the ring flare in flare_target() is what sells the hit.
	active_notes.erase(note)


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
	active_notes.clear()
	song_time = 0.0
	next_note_index = 0
	score = 0
	combo = 0
	combo_tier = -1
	max_combo = 0
	perfect_streak = 0
	update_labels()
	judgment_label.modulate.a = 0.0
	combo_label.modulate.a = 0.0
	active = true
	if audio != null:
		audio.stop()
		audio.play()
