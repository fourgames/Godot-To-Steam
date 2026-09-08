@icon("uid://bv085ck83vmx6")
extends Node


const MAX_SOUNDS = 8
const MIN_INTERVAL_MS = 50
var _history = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func play_sound(stream: AudioStream, bus = "SFX", pos = null):
	if AudioServer.get_bus_index(bus) == -1:
		push_warning("AudioManager: bus not found. Sounds will play on Master.")
		
	var now = Time.get_ticks_msec()
	
	if not stream or get_child_count() >= MAX_SOUNDS:
		return
	
	if _history.get(stream, 0) + MIN_INTERVAL_MS > now:
		return
	
	_history[stream] = now
	
	var p 
	if pos is Vector3:
		p = AudioStreamPlayer3D.new() 
	elif pos is Vector2:
		p = AudioStreamPlayer2D.new()
	else:
		p = AudioStreamPlayer.new()
	add_child(p)
	
	p.stream = stream
	p.bus = bus
	
	if p is AudioStreamPlayer3D:
		p.global_position = pos
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	elif p is AudioStreamPlayer2D:
		p.global_position = pos
	
	p.pitch_scale = randf_range(0.95, 1.05)
	p.volume_db = randf_range(-3.0, 0.0)
	
	p.play()
	p.finished.connect(p.queue_free)
