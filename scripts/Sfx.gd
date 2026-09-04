extends Node

const MIX_RATE := 44100
const POOL_SIZE := 8
const BUS_NAME := "SFX"

var _clips: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_build_clips()
	_build_player_pool()


func play(name: String, pitch_variance: float = 0.05, volume_db: float = 0.0) -> void:
	if not _clips.has(name):
		return
	var player := _get_free_player()
	player.stream = _clips[name]
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.volume_db = volume_db
	player.play()


func _build_player_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		add_child(p)
		_players.append(p)


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# All busy - steal round-robin rather than dropping the sound entirely.
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return p


func _build_clips() -> void:
	_clips["hit_perfect"] = _make_tone(1046.5, 0.12, 14.0, 0.25)
	_clips["hit_good"] = _make_tone(784.0, 0.10, 10.0)
	_clips["miss"] = _make_noise(0.14, 9.0, 0.25)
	_clips["combo_milestone"] = _make_tone(1318.5, 0.22, 5.0, 0.3)
	_clips["big"] = _make_big()
	_clips["enemy_death"] = _make_sweep(700.0, 140.0, 0.12, 8.0)
	_clips["ui_click"] = _make_tone(1500.0, 0.035, 40.0)


func _make_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.data = bytes
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


# Exponentially-decaying sine tone (optionally with a quiet 2nd harmonic for
# timbre) - covers every chime/blip sound in the clip table.
func _make_tone(freq: float, duration: float, decay: float, harmonic_amt: float = 0.0) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for i in frame_count:
		var t := float(i) / MIX_RATE
		var envelope := exp(-decay * t)
		var s := sin(TAU * freq * t)
		if harmonic_amt > 0.0:
			s += harmonic_amt * sin(TAU * freq * 2.0 * t)
		s *= envelope
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _make_stream(bytes)


# One-pole low-passed white noise with a decay envelope - turns hiss into a
# dull thud, used for miss/whiff feedback.
func _make_noise(duration: float, decay: float, lowpass: float = 0.3) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var filtered := 0.0
	for i in frame_count:
		var t := float(i) / MIX_RATE
		var envelope := exp(-decay * t)
		filtered += (randf_range(-1.0, 1.0) - filtered) * lowpass
		bytes.encode_s16(i * 2, int(clampf(filtered * envelope, -1.0, 1.0) * 32767.0))
	return _make_stream(bytes)


# Frequency sweep with an accumulated phase (not sin(freq(t)*t), which would
# produce audible discontinuities) - a quick descending "pop".
func _make_sweep(freq_start: float, freq_end: float, duration: float, decay: float) -> AudioStreamWAV:
	var frame_count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var phase := 0.0
	for i in frame_count:
		var t := float(i) / MIX_RATE
		var f := lerpf(freq_start, freq_end, t / duration)
		phase += TAU * f / MIX_RATE
		var envelope := exp(-decay * t)
		bytes.encode_s16(i * 2, int(clampf(sin(phase) * envelope, -1.0, 1.0) * 32767.0))
	return _make_stream(bytes)


# Low boom + noise crunch mixed into a single buffer, for the rare 5-perfect
# BIG streak reward - the loudest/lowest sound in the set.
func _make_big() -> AudioStreamWAV:
	var duration := 0.35
	var frame_count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var filtered := 0.0
	for i in frame_count:
		var t := float(i) / MIX_RATE
		var tone := sin(TAU * 110.0 * t) * exp(-4.0 * t)
		filtered += (randf_range(-1.0, 1.0) - filtered) * 0.4
		var noise := filtered * exp(-6.0 * t)
		var mixed := 0.7 * tone + 0.3 * noise
		bytes.encode_s16(i * 2, int(clampf(mixed, -1.0, 1.0) * 32767.0))
	return _make_stream(bytes)
