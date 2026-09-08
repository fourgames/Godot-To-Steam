@icon("uid://c6t3bwxp8oxg1")
extends Node


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_node_added(node: Node) -> void:
	if not node is Control:
		return
	
	if node.has_meta(&"managed"): 
		return
	node.set_meta(&"managed", true)
	
	if node is Control:
		SignalManager.control_node_added.emit(node)
