extends HSplitContainer


## Upscaling.gd is heavily vibe coded but tested but could benefit from a refactor
func _ready() -> void:
	_populate_upscaling_modes()
	
	%Scaling3DModeOptionButton.item_selected.connect(_on_mode_selected)
	%Scaling3DModeResetButton.pressed.connect(_on_mode_reset)
	
	%Scaling3DScaleHSlider.value_changed.connect(_on_scale_slider_changed)
	%Scaling3DScaleLineEdit.text_submitted.connect(_on_scale_text_submitted)
	%Scaling3DScaleLineEdit.focus_exited.connect(func(): _on_scale_text_submitted(%Scaling3DScaleLineEdit.text))
	%Scaling3DScaleResetButton.pressed.connect(_on_scale_reset)
	
	%Scaling3DSharpnessHSlider.value_changed.connect(_on_sharpness_slider_changed)
	%Scaling3DSharpnessLineEdit.text_submitted.connect(_on_sharpness_text_submitted)
	%Scaling3DSharpnessLineEdit.focus_exited.connect(func(): _on_sharpness_text_submitted(%Scaling3DSharpnessLineEdit.text))
	%Scaling3DSharpnessResetButton.pressed.connect(_on_sharpness_reset)
	
	_sync_ui_to_data()
	
	_finalize_change()
	%Scaling3DSharpnessHSplitContainer.visible = (%Scaling3DModeOptionButton.selected == 2 or %Scaling3DModeOptionButton.selected == 4)


func _populate_upscaling_modes() -> void:
	var btn = %Scaling3DModeOptionButton
	btn.clear()
	var modes = ClassDB.class_get_enum_constants("Viewport", "Scaling3DMode")
	for mode_name in modes:
		if mode_name.ends_with("_MAX"): continue
		var mode_value = ClassDB.class_get_integer_constant("Viewport", mode_name)
		var readable_name = mode_name.replace("SCALING_3D_MODE_", "").capitalize()
		btn.add_item(readable_name, mode_value)


func _on_mode_selected(index: int) -> void:
	DataManager.payload.video.Scaling3DMode = %Scaling3DModeOptionButton.get_item_id(index)
	_finalize_change()
	%Scaling3DSharpnessHSplitContainer.visible = (index == 2 or index == 4)


func _on_scale_slider_changed(value: float) -> void:
	DataManager.payload.video.Scaling3DScale = value / 100.0
	%Scaling3DScaleLineEdit.text = str(int(value))
	_finalize_change()


func _on_scale_text_submitted(new_text: String) -> void:
	var ui_value = clamp(new_text.to_float(), 25.0, 200.0)
	DataManager.payload.video.Scaling3DScale = ui_value / 100.0
	_finalize_change()


func _on_mode_reset() -> void:
	DataManager.payload.video.Scaling3DMode = DataManager.payload.video.DefaultScaling3DMode
	_finalize_change()
	%Scaling3DSharpnessHSplitContainer.visible = (%Scaling3DModeOptionButton.selected == 2 or %Scaling3DModeOptionButton.selected == 4)
	%Scaling3DModeOptionButton.grab_focus()


func _on_scale_reset() -> void:
	DataManager.payload.video.Scaling3DScale = DataManager.payload.video.DefaultScaling3DScale
	_finalize_change()
	%Scaling3DScaleLineEdit.grab_focus()


func _on_sharpness_reset() -> void:
	DataManager.payload.video.Scaling3DSharpness = DataManager.payload.video.DefaultScaling3DSharpness
	_finalize_change()
	%Scaling3DSharpnessLineEdit.grab_focus()


func _on_sharpness_slider_changed(value: float) -> void:
	var engine_val = remap(value, 0, 100, 2.0, 0.0)
	DataManager.payload.video.Scaling3DSharpness = engine_val
	%Scaling3DSharpnessLineEdit.text = str(int(value))
	_finalize_change()


func _on_sharpness_text_submitted(new_text: String) -> void:
	var ui_value = clamp(new_text.to_float(), 0, 100)
	DataManager.payload.video.Scaling3DSharpness = remap(ui_value, 0, 100, 2.0, 0.0)
	_finalize_change()


func _sync_ui_to_data() -> void:
	var video = DataManager.payload.video
	
	%Scaling3DModeOptionButton.select(%Scaling3DModeOptionButton.get_item_index(video.Scaling3DMode))
	
	var ui_scale = video.Scaling3DScale * 100.0
	%Scaling3DScaleHSlider.set_value_no_signal(ui_scale)
	%Scaling3DScaleLineEdit.text = str(int(ui_scale))
	
	var ui_sharp = remap(video.Scaling3DSharpness, 0.0, 2.0, 100, 0)
	%Scaling3DSharpnessHSlider.set_value_no_signal(ui_sharp)
	%Scaling3DSharpnessLineEdit.text = str(int(ui_sharp))
	
	%Scaling3DModeResetButton.visible = (video.Scaling3DMode != video.DefaultScaling3DMode)
	%Scaling3DScaleResetButton.visible = !is_equal_approx(video.Scaling3DScale, video.DefaultScaling3DScale)
	%Scaling3DSharpnessResetButton.visible = !is_equal_approx(video.Scaling3DSharpness, video.DefaultScaling3DSharpness)


func _finalize_change() -> void:
	DataManager.save_data()
	
	var v = get_viewport()
	var video = DataManager.payload.video
	
	v.scaling_3d_mode = video.Scaling3DMode as Viewport.Scaling3DMode
	v.scaling_3d_scale = video.Scaling3DScale
	v.fsr_sharpness = video.Scaling3DSharpness
	
	_sync_ui_to_data()
