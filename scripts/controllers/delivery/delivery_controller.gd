extends Control

signal delivered(commission_id: String)

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var meta_label: Label = %MetaLabel
@onready var preview_panel: PanelContainer = %PreviewPanel
@onready var preview: TextureRect = %Preview
@onready var empty_label: Label = %EmptyLabel
@onready var choose_button: Button = %ChooseButton
@onready var clear_button: Button = %ClearButton
@onready var send_button: Button = %SendButton
@onready var status_label: Label = %StatusLabel
@onready var file_dialog: FileDialog = %FileDialog

@export_group("Panneaux")
@export var panel_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE
@export var preview_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND

@export_group("Textes")
@export var title_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG
@export var meta_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var empty_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED

@export_group("Boutons")
@export var button_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var button_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var button_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var button_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var disabled_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var send_background_color: PaletteData.Colors = PaletteData.Colors.SUCCESS
@export var send_text_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND

var commission_manager: Node
var delivery_manager: Node
var commission_id: String = ""
var source_path: String = ""


func _ready() -> void:
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")
	if delivery_manager == null:
		delivery_manager = get_node_or_null("/root/DeliveryManager")
	_apply_palette()
	choose_button.pressed.connect(open_picker)
	clear_button.pressed.connect(clear_source)
	send_button.pressed.connect(send)
	file_dialog.file_selected.connect(set_source_path)
	clear_source()
	_refresh_header()


func setup(commission_id_value: String) -> void:
	commission_id = commission_id_value
	if is_node_ready():
		_refresh_header()


func open_picker() -> void:
	file_dialog.popup_centered_ratio(0.7)


func set_source_path(path: String) -> bool:
	if delivery_manager == null:
		return false
	var validation: Dictionary = delivery_manager.validate(path)
	if not bool(validation.get("ok", false)):
		_show_status(str(validation.get("error", "Image refusée.")), "error")
		return false
	var texture = delivery_manager.load_texture(path)
	if texture == null:
		_show_status("Image illisible.", "error")
		return false
	source_path = path
	preview.texture = texture
	preview.show()
	empty_label.hide()
	clear_button.disabled = false
	send_button.disabled = false
	_show_status("Image prête à être envoyée.", "neutral")
	return true


func clear_source() -> void:
	source_path = ""
	if preview != null:
		preview.texture = null
		preview.hide()
	if empty_label != null:
		empty_label.show()
	if clear_button != null:
		clear_button.disabled = true
	if send_button != null:
		send_button.disabled = true
	_show_status("", "neutral")


func send() -> bool:
	if source_path == "" or delivery_manager == null:
		return false
	var result: Dictionary = delivery_manager.deliver(commission_id, source_path)
	if not bool(result.get("ok", false)):
		_show_status(str(result.get("error", "Livraison impossible.")), "error")
		return false
	choose_button.disabled = true
	clear_button.disabled = true
	send_button.disabled = true
	if bool(result.get("late", false)):
		_show_status("Livraison envoyée (trop tard).", "neutral")
	else:
		_show_status("Livraison envoyée.", "neutral")
	delivered.emit(commission_id)
	return true


func _refresh_header() -> void:
	if commission_manager == null:
		return
	var commission: Dictionary = commission_manager.get_commission(commission_id)
	if commission.is_empty():
		title_label.text = "Commande introuvable"
		meta_label.text = ""
		choose_button.disabled = true
		return
	title_label.text = str(commission.get("title", commission_id))
	var suffix := ""
	if str(commission.get("status", "")) != "active":
		suffix = " — commande terminée"
	if bool(commission.get("delivery_late", false)):
		suffix = " — livré trop tard"
	meta_label.text = "Client : %s — type : %s — à rendre avant le %s%s" % [
		str(commission.get("client", "")),
		str(commission.get("type", "")),
		_format_deadline(int(commission.get("deadline", 0))),
		suffix,
	]
	choose_button.disabled = false


func _format_deadline(timestamp: int) -> String:
	if timestamp <= 0:
		return "—"
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%04d à %02d:%02d" % [
		int(date["day"]),
		int(date["month"]),
		int(date["year"]),
		int(date["hour"]),
		int(date["minute"]),
	]


func _show_status(message: String, kind: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Palette.status_color(kind))


func _apply_palette() -> void:
	_style_panel(panel, Palette.color(panel_background_color))
	_style_panel(preview_panel, Palette.color(preview_background_color))
	title_label.add_theme_color_override("font_color", Palette.color(title_text_color))
	meta_label.add_theme_color_override("font_color", Palette.color(meta_text_color))
	empty_label.add_theme_color_override("font_color", Palette.color(empty_text_color))
	_style_button(choose_button)
	_style_button(clear_button)
	_style_primary_button(send_button)
	_show_status("", "neutral")


func _style_panel(target: PanelContainer, background_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	target.add_theme_stylebox_override("panel", style)


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_hover_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_pressed_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_focus_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_disabled_color", Palette.color(disabled_text_color))
	button.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.color(button_background_color))
	)
	button.add_theme_stylebox_override(
		"hover", _make_button_style(Palette.color(button_hover_color))
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.color(button_pressed_color))
	)
	button.add_theme_stylebox_override(
		"focus", _make_button_style(Palette.color(button_background_color))
	)


func _style_primary_button(button: Button) -> void:
	var background_color := Palette.color(send_background_color)
	var text_color := Palette.color(send_text_color)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", Palette.color(disabled_text_color))
	button.add_theme_stylebox_override("normal", _make_button_style(background_color))
	button.add_theme_stylebox_override(
		"hover", _make_button_style(background_color.lightened(0.1))
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(background_color.darkened(0.1))
	)
	button.add_theme_stylebox_override("focus", _make_button_style(background_color))


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
