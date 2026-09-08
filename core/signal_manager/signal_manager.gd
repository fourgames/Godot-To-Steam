@icon("uid://cqosl7p8boage")
extends Node


@warning_ignore("unused_signal")
signal control_node_added(node : Control)
@warning_ignore("unused_signal")
signal sensitivity_changed(new_value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
