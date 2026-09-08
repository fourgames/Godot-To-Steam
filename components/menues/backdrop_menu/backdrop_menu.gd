extends CanvasLayer


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func play_backwards() -> void:
	animation_player.play_backwards("fade_animation")
	await animation_player.animation_finished
