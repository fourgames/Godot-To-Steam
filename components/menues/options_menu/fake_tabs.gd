extends HBoxContainer


@onready var tabs = [%FakeTabVideo, %FakeTabAudio, %FakeTabInput, %FakeTabCredits]


func _ready() -> void:
	for i in tabs.size():
		tabs[i].focus_entered.connect(_switch_tab.bind(i))
		tabs[i].pressed.connect(_switch_tab.bind(i))


func _input(event: InputEvent) -> void:
	var dir = int(event.is_action_pressed("menu_next")) - int(event.is_action_pressed("menu_previous"))
	if dir != 0:
		var next_index = posmod(%TabContainer.current_tab + dir, tabs.size())
		_switch_tab(next_index)
		get_viewport().set_input_as_handled()


func _switch_tab(index: int) -> void:
	if index < tabs.size() and tabs[index]:
		if %TabContainer.current_tab != index:
			%TabContainer.current_tab = index
		
		if not tabs[index].has_focus():
			tabs[index].grab_focus()
