extends Node


## If project settings window mdoe isnt set to fullscreen on start : window mode settings wont work tested on macOS
## But you cant embed the game while in fullscreen ive made a proposal for it
func _ready() -> void:
	%WindowModeOptionButton.item_selected.connect(_on_window_mode_option_button_item_selected)
	%WindowModeResetButton.pressed.connect(_on_window_mode_reset_button_pressed)
	
	setup_window_mode_options()


func setup_window_mode_options() -> void:
	%WindowModeOptionButton.clear()
	
	var saved_mode_id = DataManager.payload.video.WindowMode
	var mode_names = ClassDB.class_get_enum_constants("Window", "Mode")
	
	for mode_name in mode_names:
		var mode_value = ClassDB.class_get_integer_constant("Window", mode_name)
		var display_text = mode_name.trim_prefix("MODE_").capitalize()
		
		%WindowModeOptionButton.add_item(display_text, mode_value)
		
		if mode_value == saved_mode_id:
			var current_index = %WindowModeOptionButton.item_count - 1
			%WindowModeOptionButton.select(current_index)
	
	get_window().mode = saved_mode_id as Window.Mode
	
	%WindowModeResetButton.visible = (DataManager.payload.video.WindowMode != DataManager.payload.video.DefaultWindowMode)


func _on_window_mode_option_button_item_selected(index: int) -> void:
	var selected_id = %WindowModeOptionButton.get_item_id(index)
	
	get_window().mode = selected_id as Window.Mode
	DataManager.payload.video.WindowMode = selected_id
	DataManager.save_data()
	
	%WindowModeResetButton.visible = (selected_id != DataManager.payload.video.DefaultWindowMode)


func _on_window_mode_reset_button_pressed() -> void:
	%WindowModeOptionButton.select(DataManager.payload.video.DefaultWindowMode)
	_on_window_mode_option_button_item_selected(DataManager.payload.video.DefaultWindowMode)
	%WindowModeOptionButton.grab_focus()
