extends VBoxContainer


const CREDIT_CONTAINER = preload(PathManager.CREDIT_CONTAINER)


func _ready() -> void:
	for credit in DataManager.payload.credits.credits_list:
		var instance = CREDIT_CONTAINER.instantiate()
		add_child(instance)
		instance.name_label.text = credit.name
		instance.role_label.text = credit.role
		
