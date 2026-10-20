extends Control

@onready var panel: PanelContainer = %Panel
@onready var commission_list: VBoxContainer = %CommissionList
@onready var empty_label: Label = %EmptyLabel

var commission_manager: Node
var clock_manager: Node

var _deadline_labels: Dictionary = {}


func _ready() -> void:
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")
	if clock_manager == null:
		clock_manager = get_node_or_null("/root/ClockManager")
	_apply_palette()
	if clock_manager != null and clock_manager.has_signal("second_tick"):
		clock_manager.second_tick.connect(_refresh_countdowns)
	if commission_manager != null:
		commission_manager.commissions_changed.connect(_refresh)
	_refresh()


func _apply_palette() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COMMISSION_PANEL_BACKGROUND
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	empty_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)


func _refresh() -> void:
	for child in commission_list.get_children():
		commission_list.remove_child(child)
		child.queue_free()
	_deadline_labels.clear()
	empty_label.visible = true
	if commission_manager == null:
		return
	var active: Array[Dictionary] = commission_manager.get_active_commissions()
	empty_label.visible = active.is_empty()
	for commission in active:
		commission_list.add_child(_make_row(commission))
	_refresh_countdowns()


func _make_row(commission: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COMMISSION_ROW_BACKGROUND
	style.border_color = Palette.COMMISSION_ROW_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)
	var title := Label.new()
	title.text = str(commission["title"])
	title.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	var meta := Label.new()
	meta.text = "Client : %s — type : %s — durée : %s" % [
		str(commission.get("client", "")),
		str(commission.get("type", "")),
		_format_duration(int(commission.get("duration_minutes", 0))),
	]
	meta.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	box.add_child(meta)
	var deadline := Label.new()
	deadline.add_theme_color_override("font_color", Palette.COMMISSION_DEADLINE_TEXT)
	box.add_child(deadline)
	_deadline_labels[str(commission["id"])] = deadline
	return row


func _refresh_countdowns() -> void:
	for commission_id in _deadline_labels:
		var label: Label = _deadline_labels[commission_id]
		var commission: Dictionary = commission_manager.get_commission(commission_id)
		if commission.is_empty():
			continue
		var remaining := int(commission["deadline"]) - _now()
		label.text = "Délai restant : %s" % _format_remaining(remaining)


func _format_duration(minutes: int) -> String:
	if minutes <= 0:
		return "—"
	if minutes % 60 == 0:
		return "%d h" % int(minutes / 60)
	return "%d min" % minutes


func _format_remaining(remaining: int) -> String:
	if remaining <= 0:
		return "dépassé"
	var hours := remaining / 3600
	var minutes := (remaining % 3600) / 60
	var seconds := remaining % 60
	if hours > 0:
		return "%d h %02d min" % [hours, minutes]
	if minutes > 0:
		return "%d min %02d s" % [minutes, seconds]
	return "%d s" % seconds


func _now() -> int:
	if clock_manager != null and clock_manager.has_method("get_unix_time"):
		return int(clock_manager.get_unix_time())
	return int(Time.get_unix_time_from_system())
