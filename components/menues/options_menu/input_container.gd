extends HSplitContainer


@onready var primary_input_progress_bar: ProgressBar = %PrimaryInputProgressBar
@onready var secondary_input_progress_bar: ProgressBar = %SecondaryInputProgressBar

@onready var input_name_label = %InputLabel
@onready var input_reset_button: TextureButton = %InputResetButton

@onready var primary_input_button = %PrimaryInputButton
@onready var primary_input_texture_button = %PrimaryInputTextureButton

@onready var secondary_input_button = %SecondaryInputButton
@onready var secondary_input_texture_button = %SecondaryInputTextureButton

var action_name: String
var is_rebind_primary: bool = false
var is_listening: bool = false


func _ready():
	primary_input_button.pressed.connect(_on_primary_pressed)
	secondary_input_button.pressed.connect(_on_secondary_pressed)
	input_reset_button.pressed.connect(_on_reset_pressed)
	
	primary_input_progress_bar.visible = false
	secondary_input_progress_bar.visible = false


func set_action(p_name: String):
	action_name = p_name
	input_name_label.text = p_name.capitalize()
	_sync_input_map_from_payload()
	update_icons()


func _on_primary_pressed():
	start_listening(true)


func _on_secondary_pressed():
	start_listening(false)


func _on_reset_pressed():
	primary_input_button.grab_focus()
	var list = DataManager.payload.input.inpit_list
	for i in range(list.size() - 1, -1, -1):
		if list[i]["action"] == action_name:
			list.remove_at(i)
	
	DataManager.payload.input.inpit_list = list
	DataManager.save_data()
	
	var setting_path = "input/" + action_name
	if ProjectSettings.has_setting(setting_path):
		InputMap.action_erase_events(action_name)
		var defaults = ProjectSettings.get_setting(setting_path)["events"]
		for event in defaults:
			InputMap.action_add_event(action_name, event)
	
	update_icons()


func start_listening(is_primary: bool):
	is_listening = true
	is_rebind_primary = is_primary
	
	if is_primary:
		primary_input_progress_bar.visible = true
		primary_input_texture_button.modulate.a = 0.3
	else:
		secondary_input_progress_bar.visible = true
		secondary_input_texture_button.modulate.a = 0.3


func _input(event):
	if not is_listening: return
	if event is InputEventMouseMotion: return
	
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		if event.is_pressed():
			accept_new_event(event)
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.5:
			accept_new_event(event)


func accept_new_event(new_event: InputEvent):
	get_viewport().set_input_as_handled()
	
	var new_text = _event_to_string(new_event)
	var list = DataManager.payload.input.inpit_list
	var found_entry = null
	
	for entry in list:
		if entry["action"] == action_name:
			found_entry = entry
			break
	
	if found_entry == null:
		var current_events = InputMap.action_get_events(action_name)
		var p_str = ""
		var s_str = ""
		
		if current_events.size() > 0: p_str = _event_to_string(current_events[0])
		if current_events.size() > 1: s_str = _event_to_string(current_events[1])
		
		found_entry = {"action": action_name, "primary": p_str, "secondary": s_str}
		list.append(found_entry)
	
	if is_rebind_primary:
		found_entry["primary"] = new_text
	else:
		found_entry["secondary"] = new_text
	
	DataManager.payload.input.inpit_list = list
	
	_sync_input_map_from_payload()
	DataManager.save_data()
	
	is_listening = false
	primary_input_progress_bar.visible = false
	secondary_input_progress_bar.visible = false
	primary_input_texture_button.modulate.a = 1.0
	secondary_input_texture_button.modulate.a = 1.0
	update_icons()


func _sync_input_map_from_payload():
	var custom_entry = null
	for entry in DataManager.payload.input.inpit_list:
		if entry["action"] == action_name:
			custom_entry = entry
			break
			
	if custom_entry == null: return
		
	InputMap.action_erase_events(action_name)
	
	var p_ev = _parse_string_to_event(custom_entry["primary"])
	if p_ev:
		InputMap.action_add_event(action_name, p_ev)
	else:
		var placeholder = InputEventKey.new()
		placeholder.keycode = KEY_NONE
		placeholder.physical_keycode = KEY_NONE
		InputMap.action_add_event(action_name, placeholder)
		
	var s_ev = _parse_string_to_event(custom_entry["secondary"])
	if s_ev:
		InputMap.action_add_event(action_name, s_ev)


func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		var code = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if code == KEY_NONE: return ""
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var btn = "Left"
		if event.button_index == MOUSE_BUTTON_RIGHT: btn = "Right"
		elif event.button_index == MOUSE_BUTTON_MIDDLE: btn = "Middle"
		return "Mouse " + btn
	if event is InputEventJoypadButton:
		return "Joypad Button " + str(event.button_index)
	if event is InputEventJoypadMotion:
		var sign_str = "+" if event.axis_value > 0 else "-"
		return "Joypad Axis " + str(event.axis) + " " + sign_str
	return ""


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


func update_icons():
	primary_input_button.text = ""
	secondary_input_button.text = ""
	
	var events = InputMap.action_get_events(action_name)
	
	if events.size() > 0:
		var ev = events[0]
		var is_placeholder = ev is InputEventKey and ev.keycode == KEY_NONE and ev.physical_keycode == KEY_NONE
		if is_placeholder:
			primary_input_texture_button.texture_normal = null
		else:
			var p_path = ControllerIcons._convert_event_to_path(ev)
			primary_input_texture_button.texture_normal = ControllerIcons.parse_path(p_path)
	else:
		primary_input_texture_button.texture_normal = null
	
	if events.size() > 1:
		var s_path = ControllerIcons._convert_event_to_path(events[1])
		secondary_input_texture_button.texture_normal = ControllerIcons.parse_path(s_path)
	else:
		secondary_input_texture_button.texture_normal = null
		
	_update_reset_button_visibility()


func _update_reset_button_visibility():
	var custom_entry = null
	for entry in DataManager.payload.input.inpit_list:
		if entry["action"] == action_name:
			custom_entry = entry
			break
	
	if custom_entry == null:
		input_reset_button.visible = false
		return

	var setting_path = "input/" + action_name
	if ProjectSettings.has_setting(setting_path):
		var defaults = ProjectSettings.get_setting(setting_path)["events"]
		var def_p = ""
		var def_s = ""
		if defaults.size() > 0: def_p = _event_to_string(defaults[0])
		if defaults.size() > 1: def_s = _event_to_string(defaults[1])
		
		input_reset_button.visible = (custom_entry["primary"] != def_p or custom_entry["secondary"] != def_s)
	else:
		input_reset_button.visible = true
