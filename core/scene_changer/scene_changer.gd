@icon("uid://bg13vssnv4p04")
extends CanvasLayer


@onready var animation_player: AnimationPlayer = %AnimationPlayer


func change_scene(target_path : String):
	if OS.is_debug_build():
		get_tree().change_scene_to_file.call_deferred(target_path)
	else:
		animation_player.play("change_scene_animation")
		await animation_player.animation_finished
		get_tree().change_scene_to_file(target_path)
		
		await get_tree().process_frame
		animation_player.play_backwards("change_scene_animation")
