extends CanvasLayer


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	%PausedButton.pressed.connect(_on_paused_button_pressed)
	%ContinueButton.pressed.connect(_on_continue_button_pressed)
	%OptionsButton.pressed.connect(_on_options_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	
	%ContinueButton.grab_focus()


func _on_paused_button_pressed() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)


func _on_continue_button_pressed() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)


func _on_options_button_pressed() -> void:
	GameManager.change_state(GameManager.GameState.OPTIONS_MENU)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func play_backwards() -> void:
	animation_player.play_backwards("fade_animation")
	await animation_player.animation_finished
