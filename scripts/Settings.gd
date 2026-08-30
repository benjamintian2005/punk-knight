extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS_NAME := "Music"

var master_volume: float = 1.0
var music_volume: float = 1.0

var _master_bus_idx: int = 0
var _music_bus_idx: int = -1
var _save_timer: Timer


func _ready() -> void:
	_ensure_music_bus()
	load_settings()
	apply_master_volume(master_volume)
	apply_music_volume(music_volume)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)


func _ensure_music_bus() -> void:
	_master_bus_idx = AudioServer.get_bus_index("Master")
	_music_bus_idx = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if _music_bus_idx == -1:
		_music_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_music_bus_idx)
		AudioServer.set_bus_name(_music_bus_idx, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(_music_bus_idx, "Master")


func apply_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_master_bus_idx, linear_to_db(master_volume) if master_volume > 0.0 else -80.0)


func apply_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_music_bus_idx, linear_to_db(music_volume) if music_volume > 0.0 else -80.0)


func set_master_volume(value: float) -> void:
	apply_master_volume(value)
	_save_timer.start()


func set_music_volume(value: float) -> void:
	apply_music_volume(value)
	_save_timer.start()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var loaded_master: Variant = cfg.get_value("audio", "master_volume", master_volume)
	var loaded_music: Variant = cfg.get_value("audio", "music_volume", music_volume)
	if loaded_master is float or loaded_master is int:
		master_volume = clampf(loaded_master, 0.0, 1.0)
	if loaded_music is float or loaded_music is int:
		music_volume = clampf(loaded_music, 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)
