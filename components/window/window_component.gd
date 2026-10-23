class_name WindowComponent
extends Control

signal closed(window: WindowComponent)
signal minimize_toggled(window: WindowComponent, minimized: bool)

const CORNER_RADIUS := 6
const RESIZE_DIRECTIONS := {
	"ResizeLeft": Vector2i(-1, 0),
	"ResizeRight": Vector2i(1, 0),
	"ResizeTop": Vector2i(0, -1),
	"ResizeBottom": Vector2i(0, 1),
	"ResizeTopLeft": Vector2i(-1, -1),
	"ResizeTopRight": Vector2i(1, -1),
	"ResizeBottomLeft": Vector2i(-1, 1),
	"ResizeBottomRight": Vector2i(1, 1),
}

@export var window_title: String = "Fenêtre"
@export var initial_size: Vector2 = Vector2(560, 380)
@export var minimum_window_size: Vector2 = Vector2(320, 200)
@export var taskbar_height: float = 40.0
@export var cascade_offset: float = 24.0

@onready var panel: PanelContainer = %Panel
@onready var title_bar: PanelContainer = %TitleBar
@onready var title_label: Label = %TitleLabel
@onready var minimize_button: Button = %MinimizeButton
@onready var maximize_button: Button = %MaximizeButton
@onready var close_button: Button = %CloseButton
@onready var content_scroll: ScrollContainer = %ContentScroll
@onready var resize_handles: Control = %ResizeHandles

var is_minimized: bool = false
var is_maximized: bool = false

var _title_style: StyleBoxFlat
var _content: Control
var _restore_rect: Rect2
var _dragging: bool = false
var _drag_offset: Vector2
var _resizing: bool = false
var _resize_direction: Vector2i
var _resize_start_rect: Rect2
var _resize_start_mouse: Vector2


func _ready() -> void:
	custom_minimum_size = minimum_window_size
	size = initial_size
	title_label.text = window_title
	_build_styles()
	set_focused(false)
	minimize_button.pressed.connect(_on_minimize_pressed)
	maximize_button.pressed.connect(_on_maximize_pressed)
	close_button.pressed.connect(_on_close_pressed)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	for handle in resize_handles.get_children():
		handle.gui_input.connect(_on_resize_handle_gui_input.bind(handle))
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_clamp_position()


func setup(title: String, content: Control) -> void:
	window_title = title
	title_label.text = title
	if content == null:
		return
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content)
	_fit_labels(content)
	_watch_children(content)
	_content = content
	_sync_content_minimum()


func _sync_content_minimum() -> void:
	if _content == null:
		return
	var minimum := Vector2.ZERO
	for child in _content.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		var is_full_rect := (
			control.anchor_left == 0.0
			and control.anchor_top == 0.0
			and control.anchor_right == 1.0
			and control.anchor_bottom == 1.0
		)
		if not is_full_rect:
			continue
		var inset := Vector2(
			maxf(control.offset_left - control.offset_right, 0.0),
			maxf(control.offset_top - control.offset_bottom, 0.0)
		)
		minimum = minimum.max(control.get_combined_minimum_size() + inset)
		if not control.minimum_size_changed.is_connected(_on_content_minimum_changed):
			control.minimum_size_changed.connect(_on_content_minimum_changed)
	if _content.custom_minimum_size != minimum:
		_content.custom_minimum_size = minimum


func _on_content_minimum_changed() -> void:
	_sync_content_minimum()


func _fit_labels(node: Node) -> void:
	if node is Label and not (node.get_parent() is HBoxContainer or node.get_parent() is GridContainer):
		var label := node as Label
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in node.get_children():
		_fit_labels(child)


func _watch_children(node: Node) -> void:
	if node is Container and not node.child_entered_tree.is_connected(_on_child_entered):
		node.child_entered_tree.connect(_on_child_entered)
	for child in node.get_children():
		_watch_children(child)


func _on_child_entered(node: Node) -> void:
	_fit_labels(node)
	_watch_children(node)


func focus() -> void:
	set_focused(true)
	move_to_front()


func set_focused(value: bool) -> void:
	_title_style.bg_color = Palette.TITLE_BACKGROUND_ACTIVE if value else Palette.TITLE_BACKGROUND_INACTIVE
	title_label.add_theme_color_override(
		"font_color", Palette.TITLE_TEXT_ACTIVE if value else Palette.TITLE_TEXT_INACTIVE
	)


func toggle_maximize() -> void:
	if is_maximized:
		restore_from_maximize()
	else:
		maximize()


func maximize() -> void:
	if is_maximized:
		return
	_restore_rect = Rect2(global_position, size)
	is_maximized = true
	_dragging = false
	_resizing = false
	resize_handles.hide()
	var area := _work_area()
	global_position = area.position
	size = area.size
	maximize_button.text = "❐"


func restore_from_maximize() -> void:
	if not is_maximized:
		return
	is_maximized = false
	size = _restore_rect.size
	global_position = _restore_rect.position
	resize_handles.show()
	maximize_button.text = "□"
	clamp_into_work_area()


func minimize() -> void:
	if is_minimized:
		return
	is_minimized = true
	_dragging = false
	_resizing = false
	hide()
	minimize_toggled.emit(self, true)


func restore() -> void:
	if not is_minimized:
		return
	is_minimized = false
	show()
	minimize_toggled.emit(self, false)


func clamp_into_work_area() -> void:
	if is_maximized:
		return
	var area := _work_area()
	size.x = minf(size.x, area.size.x)
	size.y = minf(size.y, area.size.y)
	_clamp_position()


func _build_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.WINDOW_BACKGROUND
	panel_style.border_color = Palette.WINDOW_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(CORNER_RADIUS)
	panel.add_theme_stylebox_override("panel", panel_style)
	_title_style = StyleBoxFlat.new()
	_title_style.corner_radius_top_left = CORNER_RADIUS
	_title_style.corner_radius_top_right = CORNER_RADIUS
	_title_style.content_margin_left = 10.0
	_title_style.content_margin_top = 4.0
	_title_style.content_margin_right = 4.0
	_title_style.content_margin_bottom = 4.0
	title_bar.add_theme_stylebox_override("panel", _title_style)


func _work_area() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var height := maxf(viewport_size.y - taskbar_height, minimum_window_size.y)
	return Rect2(Vector2.ZERO, Vector2(viewport_size.x, height))


func _clamp_position() -> void:
	var area := _work_area()
	var max_position := area.position + area.size - size
	position.x = clampf(position.x, area.position.x, maxf(area.position.x, max_position.x))
	position.y = clampf(position.y, area.position.y, maxf(area.position.y, max_position.y))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_dragging = false
			_resizing = false
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			global_position = motion.position - _drag_offset
			_clamp_position()
		elif _resizing:
			_apply_resize(motion.position)


func _on_title_bar_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.double_click:
		_dragging = false
		toggle_maximize()
	elif event.pressed and not is_maximized:
		_dragging = true
		_drag_offset = event.global_position - global_position


func _on_resize_handle_gui_input(event: InputEvent, handle: Control) -> void:
	if is_maximized:
		return
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		return
	_resizing = true
	_resize_direction = RESIZE_DIRECTIONS[handle.name]
	_resize_start_rect = Rect2(global_position, size)
	_resize_start_mouse = event.global_position


func _apply_resize(mouse_position: Vector2) -> void:
	var delta := mouse_position - _resize_start_mouse
	var rect := _resize_start_rect
	var area := _work_area()
	if _resize_direction.x < 0:
		rect.position.x = maxf(_resize_start_rect.position.x + delta.x, area.position.x)
		rect.size.x = _resize_start_rect.end.x - rect.position.x
	elif _resize_direction.x > 0:
		rect.size.x = minf(_resize_start_rect.size.x + delta.x, area.end.x - rect.position.x)
	if _resize_direction.y < 0:
		rect.position.y = maxf(_resize_start_rect.position.y + delta.y, area.position.y)
		rect.size.y = _resize_start_rect.end.y - rect.position.y
	elif _resize_direction.y > 0:
		rect.size.y = minf(_resize_start_rect.size.y + delta.y, area.end.y - rect.position.y)
	if rect.size.x < minimum_window_size.x:
		if _resize_direction.x < 0:
			rect.position.x = _resize_start_rect.end.x - minimum_window_size.x
		rect.size.x = minimum_window_size.x
	if rect.size.y < minimum_window_size.y:
		if _resize_direction.y < 0:
			rect.position.y = _resize_start_rect.end.y - minimum_window_size.y
		rect.size.y = minimum_window_size.y
	global_position = rect.position
	size = rect.size


func _on_minimize_pressed() -> void:
	minimize()


func _on_maximize_pressed() -> void:
	toggle_maximize()


func close() -> void:
	closed.emit(self)
	queue_free()


func _on_close_pressed() -> void:
	close()


func _on_viewport_size_changed() -> void:
	if is_maximized:
		var area := _work_area()
		global_position = area.position
		size = area.size
	else:
		clamp_into_work_area()
