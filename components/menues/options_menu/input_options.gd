extends VBoxContainer


@onready var sensitivity_reset_button: TextureButton = %SensitivityResetButton
@onready var sensitivity_line_edit: LineEdit = %SensitivityLineEdit
@onready var sensitivity_h_slider: HSlider = %SensitivityHSlider


const INPUT_CONTAINER = preload(PathManager.INPUT_CONTAINER)


func _ready() -> void:
	create_action_list()
	sensitivity_h_slider.value_changed.connect(_on_sensitivity_h_slider_value_changed)
	
	if sensitivity_line_edit:
		sensitivity_line_edit.text_submitted.connect(_on_sensitivity_line_edit_text_submitted)
	else:
		push_warning("line_edit_sibiling not asigned")
	
	if sensitivity_reset_button:
		sensitivity_reset_button.pressed.connect(_on_sensitivity_reset_button_pressed)
	else:
		push_warning("reset_button_sibiling not asigned")
	
	sensitivity_h_slider.value = DataManager.payload.input.sensitivity
	_update_reset_button_visibility(sensitivity_h_slider.value)



func create_action_list() -> void:
	var actions = InputMap.get_actions()
	for action in actions:
		var action_name = String(action)
		if action_name.begins_with("ui_"): 
			continue
		
		var instance = INPUT_CONTAINER.instantiate()
		add_child(instance)
		
		if instance.has_method("set_action"):
			instance.set_action(action_name)


func _update_reset_button_visibility(val: float) -> void:
	if sensitivity_reset_button:
		var default_val = DataManager.payload.input.default_sensitivity
		sensitivity_reset_button.visible = !is_equal_approx(val, default_val)


func _on_sensitivity_h_slider_value_changed(new_value: float) -> void:
	DataManager.payload.input.sensitivity = new_value
	DataManager.save_data()
	SignalManager.sensitivity_changed.emit()
	print(new_value)
	if sensitivity_line_edit:
		sensitivity_line_edit.text = str(int(new_value))
	if sensitivity_reset_button:
		_update_reset_button_visibility(new_value)

func _on_sensitivity_line_edit_text_submitted(new_text: String) -> void:
	_on_sensitivity_h_slider_value_changed(new_text.to_float())
	sensitivity_h_slider.value = new_text.to_float()


func _on_sensitivity_reset_button_pressed() -> void:
	sensitivity_line_edit.grab_focus()
	var default_data_value = DataManager.payload.input.default_sensitivity
	sensitivity_h_slider.value = default_data_value
