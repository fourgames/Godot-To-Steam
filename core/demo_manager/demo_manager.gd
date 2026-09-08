@icon("uid://n7isbas4s1l3")
extends CanvasLayer


@onready var animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	await get_tree().create_timer(1.0).timeout
	
	GameManager.change_state(GameManager.GameState.DEMO)
	get_tree().paused = true
	animation_player.play("new_animation")
	%WishlistButton.grab_focus()


func _on_wishlist_button_pressed() -> void:
	OS.shell_open("steam://store/2807130")


func _on_restart_button_pressed() -> void:
	pass # TODO hold to reset save data
	# 1. Needs new data
	# 2. Needs progressbar fill to work


func _on_quit_button_pressed() -> void:
	get_tree().quit()
