extends Control
## A Control that draws through a callable; see lib.gd add_draw().

var fn: Callable


func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
