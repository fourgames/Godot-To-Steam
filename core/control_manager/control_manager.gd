@icon("uid://b6ynqcq6i2vlo")
extends Node

var UI_HOVER_SOUND = preload(PathManager.UI_HOVER_SOUND)
var UI_PRESS_SOUND = preload(PathManager.UI_PRESS_SOUND)

var _active_tweens: Dictionary = {}


func _enter_tree() -> void:
	SignalManager.control_node_added.connect(_on_node_manager_received)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_node_manager_received(node: Node) -> void:
	node.process_mode = PROCESS_MODE_ALWAYS
	
	if node is BaseButton:
		node.pivot_offset_ratio = Vector2(0.5, 0.5)
		
		node.mouse_entered.connect(node.grab_focus)
		node.focus_entered.connect(_handle_ui_event.bind(node, "hover"))
		node.focus_exited.connect(_handle_ui_event.bind(node, "unhover"))
		
		node.button_down.connect(_handle_ui_event.bind(node, "press"))
		node.button_up.connect(_handle_ui_event.bind(node, "hover"))
	elif node is Slider:
		node.pivot_offset_ratio = Vector2(0.5, 0.5)
		
		node.mouse_entered.connect(node.grab_focus)
		node.focus_entered.connect(_handle_ui_event.bind(node, "hover"))
		node.focus_exited.connect(_handle_ui_event.bind(node, "unhover"))
		
		node.drag_started.connect(_handle_ui_event.bind(node, "press"))
		node.drag_ended.connect(_handle_ui_event.bind(node, "hover").unbind(1))
	elif node is LineEdit:
		node.pivot_offset_ratio = Vector2(0.5, 0.5)
		
		node.mouse_entered.connect(node.grab_focus)
		node.focus_entered.connect(_handle_ui_event.bind(node, "hover"))
		node.focus_exited.connect(_handle_ui_event.bind(node, "unhover"))
		
		node.text_submitted.connect(_handle_ui_event.bind(node, "press").unbind(1))
		node.editing_toggled.connect(_handle_ui_event.bind(node, "hover").unbind(1))


func _handle_ui_event(node: Control, type: String) -> void:
	if type == "hover":
		AudioManager.play_sound(UI_HOVER_SOUND)
	elif type == "press":
		AudioManager.play_sound(UI_PRESS_SOUND)
	
	_animate_button(node, type)


func _animate_button(node: Control, type: String):
	if _active_tweens.has(node):
		_active_tweens[node].kill()
	
	var tween = node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tweens[node] = tween
	
	match type:
		"hover":
			tween.tween_property(node, "scale", Vector2(1.05, 1.05), 0.12)
		"unhover":
			tween.tween_property(node, "scale", Vector2.ONE, 0.1)
		"press":
			tween.tween_property(node, "scale", Vector2(0.95, 0.95), 0.05)
			tween.chain().tween_property(node, "scale", Vector2(1.05, 1.05), 0.1)
			
	tween.finished.connect(func(): if is_instance_valid(node): _active_tweens.erase(node))
