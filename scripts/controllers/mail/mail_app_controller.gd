extends Control

@onready var list_panel: PanelContainer = %ListPanel
@onready var reader_panel: PanelContainer = %ReaderPanel
@onready var header_label: Label = %HeaderLabel
@onready var mail_list: ItemList = %MailList
@onready var archive_toggle: Button = %ArchiveToggle
@onready var from_label: Label = %FromLabel
@onready var subject_label: Label = %SubjectLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var accept_button: Button = %AcceptButton
@onready var refuse_button: Button = %RefuseButton
@onready var archive_button: Button = %ArchiveButton

@export_group("Panneaux")
@export var list_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var reader_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE

@export_group("Textes")
@export var header_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG
@export var sender_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var subject_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG
@export var body_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var unread_text_color: PaletteData.Colors = PaletteData.Colors.ACCENT

@export_group("Liste")
@export var list_selected_background_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var list_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var list_selected_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG

@export_group("Boutons")
@export var button_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var button_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var button_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var button_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var disabled_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED

@export_group("Actions")
@export var accept_background_color: PaletteData.Colors = PaletteData.Colors.SUCCESS
@export var accept_text_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var refuse_background_color: PaletteData.Colors = PaletteData.Colors.ACCENT
@export var refuse_text_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var delete_background_color: PaletteData.Colors = PaletteData.Colors.DANGER
@export var delete_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG

var mail_manager: Node
var commission_manager: Node

var _show_archives: bool = false
var _selected_id: String = ""
var _refreshing: bool = false


func _ready() -> void:
	if mail_manager == null:
		mail_manager = MailManager
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")
	_apply_palette()
	archive_toggle.toggled.connect(_on_archive_toggled)
	accept_button.pressed.connect(accept_selected)
	refuse_button.pressed.connect(refuse_selected)
	archive_button.pressed.connect(_on_archive_pressed)
	mail_list.item_selected.connect(_on_item_selected)
	mail_manager.ensure_welcome_mail()
	mail_manager.mails_changed.connect(_refresh)
	_refresh()


func _apply_palette() -> void:
	_style_panel(list_panel, Palette.color(list_background_color))
	_style_panel(reader_panel, Palette.color(reader_background_color))
	header_label.add_theme_color_override("font_color", Palette.color(header_text_color))
	from_label.add_theme_color_override("font_color", Palette.color(sender_text_color))
	subject_label.add_theme_color_override("font_color", Palette.color(subject_text_color))
	body_label.add_theme_color_override("default_color", Palette.color(body_text_color))
	mail_list.add_theme_stylebox_override(
		"panel", _make_style(Palette.color(list_background_color))
	)
	mail_list.add_theme_stylebox_override(
		"selected", _make_style(Palette.color(list_selected_background_color))
	)
	mail_list.add_theme_stylebox_override(
		"selected_focus", _make_style(Palette.color(list_selected_background_color))
	)
	mail_list.add_theme_color_override("font_color", Palette.color(list_text_color))
	mail_list.add_theme_color_override(
		"font_selected_color", Palette.color(list_selected_text_color)
	)
	_style_button(archive_toggle)
	_style_button(accept_button)
	_style_button(refuse_button)
	_style_button(archive_button)
	_style_colored_button(
		accept_button,
		Palette.color(accept_background_color),
		Palette.color(accept_text_color)
	)
	_style_colored_button(
		refuse_button,
		Palette.color(refuse_background_color),
		Palette.color(refuse_text_color)
	)
	_style_delete_button(archive_button)


func _style_panel(panel: PanelContainer, background_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)


func _make_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


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


func _style_delete_button(button: Button) -> void:
	_style_colored_button(
		button,
		Palette.color(delete_background_color),
		Palette.color(delete_text_color)
	)


func _style_colored_button(button: Button, background_color: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
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


func _refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	mail_list.clear()
	var mails: Array[Dictionary] = []
	if _show_archives:
		for mail in mail_manager.get_mails(true):
			if bool(mail.get("archived", false)):
				mails.append(mail)
	else:
		mails = mail_manager.get_mails(false)
	var selected_index := -1
	for mail in mails:
		var index := mail_list.add_item(_mail_label(mail))
		mail_list.set_item_metadata(index, mail["id"])
		if not bool(mail["read"]):
			mail_list.set_item_custom_fg_color(index, Palette.color(unread_text_color))
		if mail["id"] == _selected_id:
			selected_index = index
	if selected_index >= 0:
		mail_list.select(selected_index)
	else:
		_selected_id = ""
	_refreshing = false
	if _selected_id == "":
		_show_empty()
	else:
		_show_mail(_selected_id)
	_update_actions()


func _mail_label(mail: Dictionary) -> String:
	var prefix := "" if bool(mail["read"]) else "● "
	return "%s%s" % [prefix, mail["subject"]]


func _on_item_selected(index: int) -> void:
	select_mail(str(mail_list.get_item_metadata(index)))


func select_mail(id: String) -> void:
	_selected_id = id
	_refreshing = true
	mail_manager.mark_read(_selected_id)
	_refreshing = false
	_refresh()


func accept_selected() -> void:
	if _selected_id == "" or commission_manager == null:
		return
	var mail: Dictionary = mail_manager.get_mail(_selected_id)
	if str(mail.get("type", "")) != "commission_offer":
		return
	var commission = mail.get("commission", {})
	if not (commission is Dictionary) or commission.is_empty():
		return
	commission_manager.accept(commission)
	mail_manager.archive_mail(_selected_id)
	_selected_id = ""
	_refresh()


func refuse_selected() -> void:
	if _selected_id == "" or commission_manager == null:
		return
	var mail: Dictionary = mail_manager.get_mail(_selected_id)
	if str(mail.get("type", "")) != "commission_offer":
		return
	var commission = mail.get("commission", {})
	if not (commission is Dictionary) or commission.is_empty():
		return
	commission_manager.refuse(str(commission.get("id", "")))
	mail_manager.archive_mail(_selected_id)
	_selected_id = ""
	_refresh()


func _on_archive_pressed() -> void:
	if _selected_id == "":
		return
	mail_manager.archive_mail(_selected_id)
	_selected_id = ""
	_refresh()


func _on_archive_toggled(toggled_on: bool) -> void:
	_show_archives = toggled_on
	_selected_id = ""
	_refresh()


func _update_actions() -> void:
	header_label.text = "Archives" if _show_archives else "Boîte de réception"
	archive_toggle.text = "Boîte de réception" if _show_archives else "Archives"
	archive_button.visible = not _show_archives
	archive_button.disabled = _selected_id == ""
	var open_offer := _selected_open_offer()
	accept_button.visible = open_offer
	refuse_button.visible = open_offer


func _selected_open_offer() -> bool:
	if _selected_id == "" or _show_archives or commission_manager == null:
		return false
	var mail: Dictionary = mail_manager.get_mail(_selected_id)
	if str(mail.get("type", "")) != "commission_offer" or bool(mail.get("archived", false)):
		return false
	var commission = mail.get("commission", {})
	if not (commission is Dictionary) or commission.is_empty():
		return false
	return not commission_manager.has_open_offer(commission)


func _show_empty() -> void:
	from_label.text = ""
	subject_label.text = "Sélectionnez un message"
	body_label.text = ""


func _mail_sender_text(mail: Dictionary) -> String:
	var sender := str(mail.get("sender", ""))
	var commission = mail.get("commission", {})
	if not (commission is Dictionary) or commission.is_empty():
		return sender
	var client := str(commission.get("client", ""))
	if client == "":
		return sender
	return "%s — client : %s" % [sender, client]


func _show_mail(id: String) -> void:
	var mail: Dictionary = mail_manager.get_mail(id)
	if mail.is_empty():
		_show_empty()
		return
	from_label.text = "De : %s" % _mail_sender_text(mail)
	subject_label.text = str(mail["subject"])
	body_label.text = str(mail["body"])
	body_label.scroll_to_line(0)
