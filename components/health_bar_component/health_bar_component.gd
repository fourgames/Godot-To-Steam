@icon("uid://81fmijj0c7h0")
extends Sprite3D
class_name HealthBarComponent


@onready var health_progress_bar: ProgressBar = %HealthProgressBar
@onready var under_progress_bar: ProgressBar = %UnderProgressBar
@onready var wait_timer: Timer = %WaitTimer

func _ready() -> void:
	%HealthProgressBar.value = %HealthProgressBar.max_value
	%UnderProgressBar.value = %UnderProgressBar.max_value
	#health_progress_bar.add_theme_stylebox_override("background", load("uid://kuw0m6acholl"))
	#health_progress_bar.add_theme_stylebox_override("fill", load("uid://cljc642ndq70v"))
	#
	#under_progress_bar.add_theme_stylebox_override("background", load("uid://xafwcgqcyvwy"))
	#under_progress_bar.add_theme_stylebox_override("fill", load("uid://cxc3y1u6v10h"))

# TODO think weird visual behavior sometimes and also implement theme variants above
var heal : bool
func apply_health_bar(amount: int, health_component: HealthComponent) -> void:
	var max_health_value = health_component.max_health
	%HealthProgressBar.max_value = max_health_value
	%UnderProgressBar.max_value = max_health_value
	
	if amount > 0: # Heal
		%UnderProgressBar.value = clamp(%UnderProgressBar.value + amount, 0, max_health_value)
		heal = true
	elif amount < 0: # Hurt
		%HealthProgressBar.value = clamp(%HealthProgressBar.value + amount, 0, max_health_value)
		heal = false
	
	%WaitTimer.start()


func _on_wait_timer_timeout() -> void:
	if heal == true:
		%HealthProgressBar.value = %UnderProgressBar.value
	elif heal == false:
		%UnderProgressBar.value = %HealthProgressBar.value
