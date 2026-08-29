extends Node

const LANE_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3"]
const LANE_DEFAULT_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]


func _ready() -> void:
	for i in LANE_ACTIONS.size():
		_ensure_action(LANE_ACTIONS[i], LANE_DEFAULT_KEYS[i])


func _ensure_action(action_name: String, default_key: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = default_key
	InputMap.action_add_event(action_name, event)
