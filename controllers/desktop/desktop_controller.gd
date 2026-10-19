extends Control

@onready var clock_label: Label = %ClockLabel


func _ready() -> void:
	_update_clock()
	ClockManager.second_tick.connect(_update_clock)


func _update_clock() -> void:
	clock_label.text = ClockManager.get_time_string()
