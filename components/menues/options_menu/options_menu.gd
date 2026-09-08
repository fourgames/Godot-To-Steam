extends CanvasLayer

## DataManager already lodas on start but good to load again when opening options 
func _ready() -> void:
	DataManager.load_data()
	%CloseButton.grab_focus()

func _on_button_pressed() -> void:
	GameManager.change_state(GameManager.previous_state)

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play_backwards() -> void:
	animation_player.play_backwards("fade_animation")
	await animation_player.animation_finished
