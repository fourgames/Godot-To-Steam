extends CanvasLayer


func _physics_process(_delta):
	%Label.text = "FPS: " + str(Engine.get_frames_per_second())
