extends CanvasLayer


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	%WebsiteTextureButton.pressed.connect(_on_website_texture_button_pressed)
	%PlayButton.pressed.connect(_on_play_button_pressed)
	%OptionsButton.pressed.connect(_on_settings_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	
	%PlayButton.grab_focus()


func _on_website_texture_button_pressed() -> void:
	OS.shell_open("steam://openurl/https://store.steampowered.com/publisher/fourgamesab")


func _on_play_button_pressed() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)


func _on_settings_button_pressed() -> void:
	GameManager.change_state(GameManager.GameState.OPTIONS_MENU)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func play_backwards() -> void:
	animation_player.play_backwards("fade_animation")
	await animation_player.animation_finished
