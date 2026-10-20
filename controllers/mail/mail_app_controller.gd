extends Control

@onready var list_panel: PanelContainer = %ListPanel
@onready var reader_panel: PanelContainer = %ReaderPanel
@onready var header_label: Label = %HeaderLabel
@onready var mail_list: ItemList = %MailList
@onready var archive_toggle: Button = %ArchiveToggle
@onready var from_label: Label = %FromLabel
@onready var subject_label: Label = %SubjectLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var archive_button: Button = %ArchiveButton

var _show_archives: bool = false
var _selected_id: String = ""
var _refreshing: bool = false


func _ready() -> void:
	_apply_palette()
	archive_toggle.toggled.connect(_on_archive_toggled)
	archive_button.pressed.connect(_on_archive_pressed)
	mail_list.item_selected.connect(_on_item_selected)
	MailManager.ensure_welcome_mail()
	MailManager.mails_changed.connect(_refresh)
	_refresh()


func _apply_palette() -> void:
	_style_panel(list_panel, Palette.MAIL_LIST_BACKGROUND)
	_style_panel(reader_panel, Palette.MAIL_READING_BACKGROUND)
	header_label.add_theme_color_override("font_color", Palette.MAIL_HEADER_TEXT)
	from_label.add_theme_color_override("font_color", Palette.MAIL_META_TEXT)
	subject_label.add_theme_color_override("font_color", Palette.MAIL_HEADER_TEXT)
	body_label.add_theme_color_override("default_color", Palette.MAIL_TEXT)
	mail_list.add_theme_stylebox_override("panel", _make_style(Palette.MAIL_LIST_BACKGROUND))
	mail_list.add_theme_stylebox_override("selected", _make_style(Palette.MAIL_SELECTED_BACKGROUND))
	mail_list.add_theme_stylebox_override(
		"selected_focus", _make_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	mail_list.add_theme_color_override("font_color", Palette.MAIL_TEXT)
	mail_list.add_theme_color_override("font_selected_color", Palette.MAIL_HEADER_TEXT)
	_style_button(archive_toggle)
	_style_button(archive_button)
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
	button.add_theme_color_override("font_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_disabled_color", Palette.TITLE_TEXT_INACTIVE)
	button.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.APP_BUTTON_BACKGROUND)
	)
	button.add_theme_stylebox_override(
		"hover", _make_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED)
	)
	button.add_theme_stylebox_override(
		"focus", _make_button_style(Palette.APP_BUTTON_BACKGROUND)
	)


func _style_delete_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.MAIL_DELETE_BACKGROUND)
	)
	button.add_theme_stylebox_override(
		"hover", _make_button_style(Palette.MAIL_DELETE_BACKGROUND_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.MAIL_DELETE_BACKGROUND_PRESSED)
	)
	button.add_theme_stylebox_override(
		"focus", _make_button_style(Palette.MAIL_DELETE_BACKGROUND)
	)


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
	var mails: Array[Dictionary] = MailManager.get_mails(_show_archives)
	var selected_index := -1
	for mail in mails:
		var index := mail_list.add_item(_mail_label(mail))
		mail_list.set_item_metadata(index, mail["id"])
		if not bool(mail["read"]):
			mail_list.set_item_custom_fg_color(index, Palette.MAIL_UNREAD_TEXT)
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
	_selected_id = str(mail_list.get_item_metadata(index))
	_refreshing = true
	MailManager.mark_read(_selected_id)
	_refreshing = false
	_refresh()


func _on_archive_pressed() -> void:
	if _selected_id == "":
		return
	MailManager.archive_mail(_selected_id)
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


func _show_empty() -> void:
	from_label.text = ""
	subject_label.text = "Sélectionnez un message"
	body_label.text = ""


func _show_mail(id: String) -> void:
	var mail := MailManager.get_mail(id)
	if mail.is_empty():
		_show_empty()
		return
	from_label.text = "De : %s" % mail["from"]
	subject_label.text = str(mail["subject"])
	body_label.text = str(mail["body"])
	body_label.scroll_to_line(0)
