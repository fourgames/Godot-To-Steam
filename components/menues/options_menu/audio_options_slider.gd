extends HSlider


@export_enum("Master", "SFX", "Music") var bus_name: String
@export var line_edit_sibiling : LineEdit
@export var reset_button_sibiling : TextureButton

var bus_index : int

var map_bus_to_data = {
	"Master" : "MasterVolumeDB",
	"SFX" : "SFXVolumeDB",
	"Music" : "MusicVolumeDB",
}
@onready var bus_data_to_update = map_bus_to_data[bus_name]


func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	value_changed.connect(_on_h_slider_value_changed)
	
	value = DataManager.payload.audio[bus_data_to_update]
	
	if line_edit_sibiling:
		line_edit_sibiling.text_submitted.connect(_on_line_edit_text_submitted)
	else:
		push_warning("line_edit_sibiling not asigned")
	
	if reset_button_sibiling:
		reset_button_sibiling.pressed.connect(_reset_button_pressed)
	else:
		push_warning("reset_button_sibiling not asigned")


func _on_h_slider_value_changed(new_value: float) -> void:
	DataManager.payload.audio[bus_data_to_update] = new_value
	DataManager.save_data()
	
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(new_value / 100))
	if line_edit_sibiling:
		line_edit_sibiling.text = str(int(new_value))
	if reset_button_sibiling:
		var default_data_value = DataManager.payload.audio["Default" + bus_data_to_update]
		reset_button_sibiling.visible = (value != default_data_value)


func _on_line_edit_text_submitted(new_text: String) -> void:
	_on_h_slider_value_changed(new_text.to_float())
	value = new_text.to_float()


func _reset_button_pressed():
	line_edit_sibiling.grab_focus()
	var default_data_value = DataManager.payload.audio["Default" + bus_data_to_update]
	value = default_data_value
	
	
