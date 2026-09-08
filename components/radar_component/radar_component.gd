@icon("uid://dtvo8xbs6l3rq")
extends Node3D

@export var target_group: String = "Player"

var detected_list: Array = []

# TODO A bit unnessesary comp since its such a small thing to do target = get_tree().get_nodes_in_group()
func _ready() -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 10.0
	timer.timeout.connect(_on_scan_timer_timeout)
	timer.start()


func _on_scan_timer_timeout():
	var potential_targets = get_tree().get_nodes_in_group(target_group)
	var new_list = []
	
	for target in potential_targets:
		new_list.append(target)
	
	detected_list = new_list
	print("RadarComponent found: ", detected_list.size())
