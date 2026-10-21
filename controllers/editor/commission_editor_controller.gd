extends Control

const FAMILY_COMMISSIONS := 0
const FAMILY_CLIENTS := 1
const FAMILY_TYPES := 2
const FAMILY_TITLES := ["Commandes", "Clients", "Types"]
const FAMILY_NEW_TEXTS := ["Nouvelle commande", "Nouveau client", "Nouveau type"]

@onready var list_panel: PanelContainer = %ListPanel
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var family_bar: TabBar = %FamilyBar
@onready var element_list: ItemList = %ElementList
@onready var new_button: Button = %NewButton
@onready var detail_title: Label = %DetailTitle
@onready var commission_form: VBoxContainer = %CommissionForm
@onready var client_form: VBoxContainer = %ClientForm
@onready var type_form: VBoxContainer = %TypeForm
@onready var title_edit: LineEdit = %TitleEdit
@onready var client_option: OptionButton = %ClientOption
@onready var type_option: OptionButton = %TypeOption
@onready var duration_edit: LineEdit = %DurationEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var request_edit: TextEdit = %RequestEdit
@onready var success_edit: TextEdit = %SuccessEdit
@onready var failure_edit: TextEdit = %FailureEdit
@onready var request_grip: Control = %RequestGrip
@onready var success_grip: Control = %SuccessGrip
@onready var failure_grip: Control = %FailureGrip
@onready var client_name_edit: LineEdit = %ClientNameEdit
@onready var client_email_edit: LineEdit = %ClientEmailEdit
@onready var type_name_edit: LineEdit = %TypeNameEdit
@onready var type_duration_edit: LineEdit = %TypeDurationEdit
@onready var save_button: Button = %SaveButton
@onready var delete_button: Button = %DeleteButton
@onready var publish_button: Button = %PublishButton
@onready var status_label: Label = %StatusLabel

var commission_editor: Node
var sync_manager: Node

var _document: Dictionary = {"clients": [], "types": [], "commissions": []}
var _family: int = FAMILY_COMMISSIONS
var _editing_id: String = ""
var _refreshing: bool = false


func _ready() -> void:
	_resolve_dependencies()
	_apply_palette()
	_wire_grips()
	for title in FAMILY_TITLES:
		family_bar.add_tab(title)
	family_bar.tab_changed.connect(_on_family_changed)
	element_list.item_selected.connect(_on_element_selected)
	new_button.pressed.connect(start_new)
	save_button.pressed.connect(save_current)
	delete_button.pressed.connect(delete_current)
	publish_button.pressed.connect(publish)
	reload()


func _wire_grips() -> void:
	for pair in [
		[request_grip, request_edit],
		[success_grip, success_edit],
		[failure_grip, failure_edit],
	]:
		pair[0].target = pair[1]


func _resolve_dependencies() -> void:
	if sync_manager == null:
		sync_manager = get_node_or_null("/root/SyncManager")
	if commission_editor == null:
		commission_editor = get_node_or_null("/root/CommissionEditor")


func reload() -> void:
	if commission_editor == null:
		_set_status("Éditeur indisponible.", "error")
		return
	var loaded: Dictionary = commission_editor.load_document()
	if not bool(loaded.get("ok", false)):
		_document = {"clients": [], "types": [], "commissions": []}
		_editing_id = ""
		_update_forms()
		_refresh_lists()
		_refresh_gate()
		_set_status(str(loaded.get("error", "Chargement impossible.")), "error")
		return
	_document = loaded["document"]
	_update_forms()
	_refresh_lists()
	_refresh_gate()


func start_new() -> void:
	_editing_id = ""
	element_list.deselect_all()
	_clear_fields()
	detail_title.text = FAMILY_NEW_TEXTS[_family]
	_refresh_gate()


func save_current() -> bool:
	if commission_editor == null:
		_set_status("Éditeur indisponible.", "error")
		return false
	var result: Dictionary
	var message := ""
	match _family:
		FAMILY_COMMISSIONS:
			message = "Commande enregistrée."
			var form := _collect_commission_form()
			if _editing_id == "":
				result = commission_editor.add_commission(form)
			else:
				result = commission_editor.update_commission(_editing_id, form)
		FAMILY_CLIENTS:
			message = "Client enregistré."
			if _editing_id == "":
				result = commission_editor.add_client(client_name_edit.text, client_email_edit.text)
			else:
				result = commission_editor.update_client(
					_editing_id, client_name_edit.text, client_email_edit.text
				)
		_:
			message = "Type enregistré."
			if _editing_id == "":
				result = commission_editor.add_type(type_name_edit.text, type_duration_edit.text)
			else:
				result = commission_editor.update_type(
					_editing_id, type_name_edit.text, type_duration_edit.text
				)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Enregistrement impossible.")), "error")
		return false
	_editing_id = str(result.get("id", ""))
	reload()
	_set_status(message)
	return true


func delete_current() -> bool:
	if commission_editor == null:
		_set_status("Éditeur indisponible.", "error")
		return false
	if _editing_id == "":
		_set_status("Sélectionnez un élément.", "error")
		return false
	var result: Dictionary
	var message := ""
	match _family:
		FAMILY_COMMISSIONS:
			message = "Commande supprimée."
			result = commission_editor.remove_commission(_editing_id)
		FAMILY_CLIENTS:
			message = "Client supprimé."
			result = commission_editor.remove_client(_editing_id)
		_:
			message = "Type supprimé."
			result = commission_editor.remove_type(_editing_id)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Suppression impossible.")), "error")
		return false
	_editing_id = ""
	reload()
	_set_status(message)
	return true


func publish() -> bool:
	if commission_editor == null:
		_set_status("Éditeur indisponible.", "error")
		return false
	var result: Dictionary = commission_editor.push()
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Publication impossible.")), "error")
		return false
	var version := int(result.get("version", 0))
	if sync_manager == null or not sync_manager.has_method("publish"):
		reload()
		_set_status("Écrit localement — version %d, publication git indisponible." % version, "error")
		return false
	var pushed: Dictionary = sync_manager.publish()
	if not bool(pushed.get("ok", false)):
		reload()
		_set_status(
			"Écrit localement — version %d, push échoué : %s" % [
				version, str(pushed.get("error", "")).trim_suffix(".")
			],
			"error"
		)
		return false
	reload()
	_set_status("Publié — version %d." % version)
	if sync_manager.has_method("fetch"):
		sync_manager.fetch()
	return true


func _update_forms() -> void:
	commission_form.visible = _family == FAMILY_COMMISSIONS
	client_form.visible = _family == FAMILY_CLIENTS
	type_form.visible = _family == FAMILY_TYPES


func _refresh_lists() -> void:
	_refreshing = true
	new_button.text = FAMILY_NEW_TEXTS[_family]
	element_list.clear()
	_refresh_client_options()
	var selected_index := -1
	for element in _family_elements():
		var element_id := str(element["id"])
		var index := element_list.add_item(_element_label(element))
		element_list.set_item_metadata(index, element_id)
		if element_id == _editing_id:
			selected_index = index
	if selected_index >= 0:
		element_list.select(selected_index)
		element_list.ensure_current_is_visible()
		_fill_fields(_family_elements()[selected_index])
	else:
		_editing_id = ""
		_clear_fields()
		detail_title.text = FAMILY_NEW_TEXTS[_family]
	_refreshing = false


func _family_elements() -> Array:
	match _family:
		FAMILY_CLIENTS:
			return _document["clients"]
		FAMILY_TYPES:
			return _document["types"]
		_:
			return _document["commissions"]


func _element_label(element: Dictionary) -> String:
	match _family:
		FAMILY_CLIENTS:
			var client_line := str(element.get("name", ""))
			if str(element.get("email", "")) != "":
				client_line = "%s — %s" % [client_line, str(element["email"])]
			return client_line
		FAMILY_TYPES:
			return "%s — %d min" % [
				str(element.get("name", "")), int(element.get("duration_minutes", 0))
			]
		_:
			return "%s — %s / %s" % [
				str(element.get("title", "")),
				str(element.get("client", "")),
				str(element.get("type", "")),
			]


func _fill_fields(element: Dictionary) -> void:
	match _family:
		FAMILY_CLIENTS:
			detail_title.text = str(element.get("name", ""))
			client_name_edit.text = str(element.get("name", ""))
			client_email_edit.text = str(element.get("email", ""))
		FAMILY_TYPES:
			detail_title.text = str(element.get("name", ""))
			type_name_edit.text = str(element.get("name", ""))
			type_duration_edit.text = str(element.get("duration_minutes", ""))
		_:
			detail_title.text = str(element.get("title", ""))
			title_edit.text = str(element.get("title", ""))
			_select_by_metadata(client_option, str(element.get("client_id", "")))
			_select_by_metadata(type_option, str(element.get("type_id", "")))
			duration_edit.text = str(element.get("duration", ""))
			description_edit.text = str(element.get("description", ""))
			request_edit.text = str(element.get("mail_request", ""))
			success_edit.text = str(element.get("mail_success", ""))
			failure_edit.text = str(element.get("mail_failure", ""))


func _clear_fields() -> void:
	title_edit.text = ""
	if client_option.item_count > 0:
		client_option.select(0)
	if type_option.item_count > 0:
		type_option.select(0)
	duration_edit.text = ""
	description_edit.text = ""
	request_edit.text = ""
	success_edit.text = ""
	failure_edit.text = ""
	client_name_edit.text = ""
	client_email_edit.text = ""
	type_name_edit.text = ""
	type_duration_edit.text = ""


func _refresh_client_options() -> void:
	client_option.clear()
	for client in _document["clients"]:
		client_option.add_item(str(client["name"]))
		client_option.set_item_metadata(client_option.item_count - 1, str(client["id"]))
	type_option.clear()
	for element in _document["types"]:
		type_option.add_item(str(element["name"]))
		type_option.set_item_metadata(type_option.item_count - 1, str(element["id"]))


func _collect_commission_form() -> Dictionary:
	return {
		"title": title_edit.text,
		"client_id": _selected_metadata(client_option),
		"type_id": _selected_metadata(type_option),
		"duration": duration_edit.text,
		"description": description_edit.text,
		"mail_request": request_edit.text,
		"mail_success": success_edit.text,
		"mail_failure": failure_edit.text,
	}


func _selected_metadata(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _select_by_metadata(option: OptionButton, value: String) -> void:
	if value == "":
		return
	for index in option.item_count:
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return


func _on_family_changed(index: int) -> void:
	_family = index
	_editing_id = ""
	_update_forms()
	_refresh_lists()
	_refresh_gate()


func _on_element_selected(index: int) -> void:
	if _refreshing:
		return
	_editing_id = str(element_list.get_item_metadata(index))
	_fill_fields(_family_elements()[index])
	_refresh_gate()


func _refresh_gate() -> void:
	var allowed: bool = commission_editor != null and commission_editor.can_publish()
	for field in [
		title_edit,
		client_option,
		type_option,
		duration_edit,
		description_edit,
		request_edit,
		success_edit,
		failure_edit,
		client_name_edit,
		client_email_edit,
		type_name_edit,
		type_duration_edit,
	]:
		if field is LineEdit or field is TextEdit:
			field.editable = allowed
		else:
			field.disabled = not allowed
	for button in [new_button, save_button, delete_button, publish_button]:
		button.disabled = not allowed
	if allowed:
		delete_button.disabled = _editing_id == ""
	else:
		_set_status("Session administrateur requise.", "error")


func _set_status(message: String, kind: String = "neutral") -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Palette.status_color(kind))


func _apply_palette() -> void:
	_style_panel(list_panel, Palette.MAIL_LIST_BACKGROUND)
	_style_panel(detail_panel, Palette.MAIL_READING_BACKGROUND)
	for node in _all_labels(self):
		node.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	detail_title.add_theme_color_override("font_color", Palette.MAIL_HEADER_TEXT)
	status_label.add_theme_color_override("font_color", Palette.STATUS_TEXT)
	family_bar.add_theme_color_override("font_selected_color", Palette.MAIL_HEADER_TEXT)
	family_bar.add_theme_color_override("font_unselected_color", Palette.MAIL_META_TEXT)
	family_bar.add_theme_color_override("font_hovered_color", Palette.MAIL_TEXT)
	element_list.add_theme_color_override("font_color", Palette.MAIL_TEXT)
	element_list.add_theme_color_override("font_selected_color", Palette.MAIL_HEADER_TEXT)
	element_list.add_theme_stylebox_override("panel", _make_box_style(Palette.MAIL_LIST_BACKGROUND))
	element_list.add_theme_stylebox_override(
		"selected", _make_box_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	element_list.add_theme_stylebox_override(
		"selected_focus", _make_box_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	element_list.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	element_list.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	for field in [
		title_edit,
		client_option,
		type_option,
		duration_edit,
		description_edit,
		request_edit,
		success_edit,
		failure_edit,
		client_name_edit,
		client_email_edit,
		type_name_edit,
		type_duration_edit,
	]:
		_style_field(field)
	for button in [new_button, save_button, publish_button]:
		_style_button(button)
	_style_delete_button(delete_button)


func _all_labels(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node)
	for child in node.get_children():
		labels.append_array(_all_labels(child))
	return labels


func _style_panel(panel: PanelContainer, background_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)


func _style_field(field: Control) -> void:
	field.add_theme_color_override("font_color", Palette.MAIL_TEXT)
	field.add_theme_color_override("font_placeholder_color", Palette.MAIL_META_TEXT)
	field.add_theme_stylebox_override("normal", _make_box_style(Palette.APP_BUTTON_BACKGROUND))
	field.add_theme_stylebox_override("hover", _make_box_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	field.add_theme_stylebox_override("pressed", _make_box_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))
	field.add_theme_stylebox_override("focus", _make_box_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_disabled_color", Palette.TITLE_TEXT_INACTIVE)
	button.add_theme_stylebox_override("normal", _make_box_style(Palette.APP_BUTTON_BACKGROUND))
	button.add_theme_stylebox_override("hover", _make_box_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	button.add_theme_stylebox_override("pressed", _make_box_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))
	button.add_theme_stylebox_override("disabled", _make_box_style(Palette.APP_BUTTON_BACKGROUND))
	button.add_theme_stylebox_override("focus", _make_box_style(Palette.APP_BUTTON_BACKGROUND))


func _style_delete_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.MAIL_DELETE_TEXT)
	button.add_theme_color_override("font_disabled_color", Palette.TITLE_TEXT_INACTIVE)
	button.add_theme_stylebox_override("normal", _make_box_style(Palette.MAIL_DELETE_BACKGROUND))
	button.add_theme_stylebox_override(
		"hover", _make_box_style(Palette.MAIL_DELETE_BACKGROUND_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_box_style(Palette.MAIL_DELETE_BACKGROUND_PRESSED)
	)
	button.add_theme_stylebox_override("disabled", _make_box_style(Palette.MAIL_DELETE_BACKGROUND))
	button.add_theme_stylebox_override("focus", _make_box_style(Palette.MAIL_DELETE_BACKGROUND))


func _make_box_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
