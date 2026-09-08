extends Node


func _ready() -> void:
	%VsyncOptionButton.item_selected.connect(_on_VsyncOptionButton_item_selected)
	%VsyncResetButton.pressed.connect(_on_VsyncResetButton_pressed)
	
	setup_vsync_options()


func setup_vsync_options() -> void:
	%VsyncOptionButton.clear()
	
	var saved_vsync_id = DataManager.payload.video.VSyncMode
	var mode_names = ClassDB.class_get_enum_constants("DisplayServer", "VSyncMode")
	
	for mode_name in mode_names:
		var mode_value = ClassDB.class_get_integer_constant("DisplayServer", mode_name)
		
		var display_text = mode_name.trim_prefix("VSYNC_").capitalize()
		%VsyncOptionButton.add_item(display_text, mode_value)
		
		if mode_value == saved_vsync_id:
			%VsyncOptionButton.select(%VsyncOptionButton.item_count - 1)
	
	DisplayServer.window_set_vsync_mode(saved_vsync_id as DisplayServer.VSyncMode)
	%VsyncResetButton.visible = (saved_vsync_id != DataManager.payload.video.DefaultVSyncMode)


func _on_VsyncOptionButton_item_selected(index: int) -> void:
	var selected_id = %VsyncOptionButton.get_item_id(index)
	
	DisplayServer.window_set_vsync_mode(selected_id as DisplayServer.VSyncMode)
	
	DataManager.payload.video.VSyncMode = selected_id
	DataManager.save_data()
	
	%VsyncResetButton.visible = (selected_id != DataManager.payload.video.DefaultVSyncMode)


func _on_VsyncResetButton_pressed() -> void:
	var default_id = DataManager.payload.video.DefaultVSyncMode
	
	%VsyncOptionButton.grab_focus()
	for i in %VsyncOptionButton.item_count:
		if %VsyncOptionButton.get_item_id(i) == default_id:
			%VsyncOptionButton.select(i)
			_on_VsyncOptionButton_item_selected(i)
			break
