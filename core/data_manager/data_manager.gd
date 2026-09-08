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
