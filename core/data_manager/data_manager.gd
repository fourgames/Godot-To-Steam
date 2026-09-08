@icon("uid://dsn4vba5b5gsq")
extends Node


const ENDPOINT = "user://SaveFile.tres"
var payload : Data = Data.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func save_data():
	ResourceSaver.save(payload, ENDPOINT)


func load_data():
	if ResourceLoader.exists(ENDPOINT):
		var response = ResourceLoader.load(ENDPOINT)
		if response is Data:
			payload = response.duplicate(true)
			sync_all_inputs()


func sync_all_inputs():
	if not payload or not payload.input: return
		
	for entry in payload.input.inpit_list:
		var action = entry["action"]
		if not InputMap.has_action(action): continue
			
		InputMap.action_erase_events(action)
		
		var p_ev = _parse_string_to_event(entry["primary"])
		if p_ev:
			InputMap.action_add_event(action, p_ev)
		else:
			var placeholder = InputEventKey.new()
			placeholder.keycode = KEY_NONE
			placeholder.physical_keycode = KEY_NONE
			InputMap.action_add_event(action, placeholder)
			
		var s_ev = _parse_string_to_event(entry["secondary"])
		if s_ev:
			InputMap.action_add_event(action, s_ev)


func _parse_string_to_event(text: String) -> InputEvent:
	if text == "" or text == "<null>": return null
	
	var key_code = OS.find_keycode_from_string(text)
	if key_code != KEY_NONE:
		var event = InputEventKey.new()
		event.keycode = key_code
		return event
	
	if text.contains("Mouse"):
		var mouse_event = InputEventMouseButton.new()
		if text.contains("Left"): mouse_event.button_index = MOUSE_BUTTON_LEFT
		elif text.contains("Right"): mouse_event.button_index = MOUSE_BUTTON_RIGHT
		elif text.contains("Middle"): mouse_event.button_index = MOUSE_BUTTON_MIDDLE
		return mouse_event
		
	if text.contains("Joypad Button"):
		var joy_event = InputEventJoypadButton.new()
		var split = text.split(" ")
		if split.size() > 2: joy_event.button_index = int(split[2])
		return joy_event
		
	if text.contains("Joypad Axis"):
		var joy_event = InputEventJoypadMotion.new()
		var split = text.split(" ")
		if split.size() > 3: 
			joy_event.axis = int(split[2])
			joy_event.axis_value = 1.0 if split[3] == "+" else -1.0
		return joy_event
	return null
