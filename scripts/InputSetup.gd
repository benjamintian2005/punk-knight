extends Node

const LANE_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3"]

# Arrows are the real binding now - the rails ARE left/down/up/right, so the
# key and the direction it defends are the same thing.
const LANE_PRIMARY_KEYS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]

# D F J K kept as a second binding: same hand position as a normal 4-key
# rhythm game, for anyone who'd rather not play one-handed on the arrows.
const LANE_ALT_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]


func _ready() -> void:
	for i in LANE_ACTIONS.size():
		var action: String = LANE_ACTIONS[i]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_ensure_key(action, LANE_PRIMARY_KEYS[i])
		_ensure_key(action, LANE_ALT_KEYS[i])


func _ensure_key(action_name: String, key: Key) -> void:
	# Add rather than replace, so an action that already exists picks up the
	# missing binding instead of being skipped entirely.
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action_name, event)
