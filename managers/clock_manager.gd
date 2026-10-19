extends Node

signal second_tick

const SECONDS_PER_TICK := 1.0

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= SECONDS_PER_TICK:
		_accumulator -= SECONDS_PER_TICK
		second_tick.emit()


func get_time_string() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
