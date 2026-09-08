@icon("uid://cdmyxwtwjrli8")
extends Node


enum GameState { MAIN_MENU, PLAYING, PAUSE_MENU, OPTIONS_MENU, DEMO }

var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

const MAIN_MENU = preload(PathManager.MAIN_MENU)
const PAUSE_MENU = preload(PathManager.PAUSE_MENU)
const OPTIONS_MENU = preload(PathManager.OPTIONS_MENU)
const BACKDROP = preload(PathManager.BACKDROP)

var backdrop = null
var active_menu = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var invisible_options_instance = OPTIONS_MENU.instantiate()
	invisible_options_instance.visible = false
	add_child(invisible_options_instance)
	if not invisible_options_instance.is_node_ready():
		await invisible_options_instance.ready
		
	invisible_options_instance.queue_free()
	change_state(GameState.MAIN_MENU)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		match current_state:
			GameState.PLAYING:
				change_state(GameState.PAUSE_MENU)
			GameState.PAUSE_MENU:
				change_state(GameState.PLAYING)
			GameState.OPTIONS_MENU:
				change_state(previous_state)

func change_state(new_state):
	if current_state != new_state:
		previous_state = current_state
	
	current_state = new_state
	
	if active_menu:
		await active_menu.play_backwards()
		active_menu.queue_free()
		active_menu = null
	
	if current_state == GameState.PLAYING:
		if backdrop: 
			await backdrop.play_backwards()
			backdrop.queue_free()
			backdrop = null
	elif !backdrop:
		backdrop = BACKDROP.instantiate()
		add_child(backdrop)
		move_child(backdrop, 0)
	
	match current_state:
		GameState.MAIN_MENU:
			get_tree().paused = true
			active_menu = MAIN_MENU.instantiate()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		GameState.PLAYING:
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
		GameState.PAUSE_MENU:
			get_tree().paused = true
			active_menu = PAUSE_MENU.instantiate()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		GameState.OPTIONS_MENU:
			active_menu = OPTIONS_MENU.instantiate()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
		GameState.DEMO:
			active_menu = null
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
	if active_menu:
		add_child(active_menu)
