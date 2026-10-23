extends Node

signal second_tick
signal minute_tick

const SECONDS_PER_TICK := 1.0
const SECONDS_PER_MINUTE := 60.0

var _second_accumulator: float = 0.0
var _minute_accumulator: float = 0.0


func _process(delta: float) -> void:
	_second_accumulator += delta
	while _second_accumulator >= SECONDS_PER_TICK:
		_second_accumulator -= SECONDS_PER_TICK
		second_tick.emit()
	_minute_accumulator += delta
	while _minute_accumulator >= SECONDS_PER_MINUTE:
		_minute_accumulator -= SECONDS_PER_MINUTE
		minute_tick.emit()


func get_time_string() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]


func get_unix_time() -> int:
	return int(Time.get_unix_time_from_system())
