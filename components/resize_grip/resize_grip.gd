extends Control

signal height_changed(height: float)

const DEFAULT_MIN_HEIGHT := 40.0
const DEFAULT_MAX_HEIGHT := 400.0
const GRIP_HEIGHT := 10.0
const GRIP_WIDTH := 28.0

@export var target: Control
@export var min_height: float = DEFAULT_MIN_HEIGHT
@export var max_height: float = DEFAULT_MAX_HEIGHT

var _dragging: bool = false
var _hovered: bool = false
var _start_global_y: float = 0.0
var _start_height: float = 0.0


func _ready() -> void:
	custom_minimum_size.y = GRIP_HEIGHT
	mouse_default_cursor_shape = Control.CURSOR_VSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Glisser pour agrandir ou réduire"
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	resized.connect(queue_redraw)


func _draw() -> void:
	var center_x := size.x * 0.5
	var center_y := size.y * 0.5
	var half_width := minf(GRIP_WIDTH, size.x) * 0.5
	var color: Color = Palette.MAIL_META_TEXT
	color.a = 0.9 if _hovered or _dragging else 0.5
	for offset in [-2.0, 2.0]:
		draw_line(
			Vector2(center_x - half_width, center_y + offset),
			Vector2(center_x + half_width, center_y + offset),
			color,
			1.5
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag(event.global_position.y)
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_apply_drag(event.global_position.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag()


func _start_drag(global_y: float) -> void:
	if target == null:
		return
	_start_global_y = global_y
	_start_height = target.custom_minimum_size.y
	if _start_height <= 0.0:
		_start_height = target.size.y
	_dragging = true
	set_process_input(true)
	queue_redraw()


func _apply_drag(global_y: float) -> void:
	if target == null:
		return
	var height := clampf(_start_height + global_y - _start_global_y, min_height, max_height)
	if is_equal_approx(height, target.custom_minimum_size.y):
		return
	target.custom_minimum_size.y = height
	height_changed.emit(height)


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	set_process_input(false)
	queue_redraw()


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()
