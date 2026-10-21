extends Control

signal login_succeeded(profile_id: String)

const DESKTOP_SCENE := "res://controllers/desktop/desktop_controller.tscn"
const ADMIN_REVEAL_CLICKS := 5

@onready var background: ColorRect = %Background
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var step_label: Label = %StepLabel
@onready var selection_box: VBoxContainer = %SelectionBox
@onready var profile_list: ItemList = %ProfileList
@onready var continue_button: Button = %ContinueButton
@onready var new_profile_button: Button = %NewProfileButton
@onready var creation_box: VBoxContainer = %CreationBox
@onready var create_pseudo_edit: LineEdit = %CreatePseudoEdit
@onready var create_password_edit: LineEdit = %CreatePasswordEdit
@onready var create_confirm_edit: LineEdit = %CreateConfirmEdit
@onready var create_button: Button = %CreateButton
@onready var creation_back_button: Button = %CreationBackButton
@onready var credentials_box: VBoxContainer = %CredentialsBox
@onready var credentials_label: Label = %CredentialsLabel
@onready var password_edit: LineEdit = %PasswordEdit
@onready var login_button: Button = %LoginButton
@onready var credentials_back_button: Button = %CredentialsBackButton
@onready var status_label: Label = %StatusLabel

var auth_manager: Node
var mail_manager: Node
var commission_manager: Node

var _profile_ids: Array[String] = []
var _admin_revealed: bool = false
var _title_click_count: int = 0


func _ready() -> void:
	_resolve_dependencies()
	_apply_palette()
	continue_button.pressed.connect(open_credentials)
	new_profile_button.pressed.connect(open_creation)
	profile_list.item_activated.connect(_on_profile_activated)
	create_button.pressed.connect(create_profile)
	creation_back_button.pressed.connect(back_to_selection)
	login_button.pressed.connect(login)
	credentials_back_button.pressed.connect(back_to_selection)
	password_edit.text_submitted.connect(_on_password_submitted)
	title_label.gui_input.connect(_on_title_input)
	populate_profiles()
	back_to_selection()


func _resolve_dependencies() -> void:
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")
	if mail_manager == null:
		mail_manager = get_node_or_null("/root/MailManager")
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")


func populate_profiles(selected_id: String = "") -> void:
	if auth_manager == null or profile_list == null:
		return
	if selected_id == "":
		selected_id = selected_profile_id()
	profile_list.clear()
	_profile_ids.clear()
	for profile in auth_manager.get_profiles():
		if bool(profile["is_admin"]) and not _admin_revealed:
			continue
		var index := profile_list.add_item(str(profile["pseudo"]))
		profile_list.set_item_metadata(index, str(profile["id"]))
		_profile_ids.append(str(profile["id"]))
	if _profile_ids.is_empty():
		return
	var target := 0
	if selected_id != "":
		var found := _profile_ids.find(selected_id)
		if found >= 0:
			target = found
	profile_list.select(target)


func selected_profile_id() -> String:
	if profile_list == null:
		return ""
	var selection := profile_list.get_selected_items()
	if selection.is_empty():
		return ""
	return _profile_ids[selection[0]]


func open_creation() -> void:
	_show_step(creation_box, "Nouveau profil")
	_set_status("")
	create_pseudo_edit.grab_focus()


func open_credentials() -> void:
	if selected_profile_id() == "":
		_set_status("Sélectionnez un profil.", "error")
		return
	var profile: Dictionary = {}
	if auth_manager != null:
		profile = auth_manager.get_profile(selected_profile_id())
	credentials_label.text = "Connexion : %s" % str(profile.get("pseudo", ""))
	_show_step(credentials_box, "Étape 2 sur 2 — Mot de passe")
	_set_status("")
	password_edit.text = ""
	password_edit.grab_focus()


func back_to_selection() -> void:
	_show_step(selection_box, "Étape 1 sur 2 — Choisissez un compte")
	_set_status("")


func login() -> bool:
	if auth_manager == null:
		_set_status("Gestionnaire de profils indisponible.", "error")
		return false
	var profile_id := selected_profile_id()
	if profile_id == "":
		_set_status("Sélectionnez un profil.", "error")
		return false
	if not auth_manager.authenticate(profile_id, password_edit.text):
		_set_status("Mot de passe incorrect.", "error")
		return false
	password_edit.text = ""
	_wire_profile(profile_id)
	login_succeeded.emit(profile_id)
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(DESKTOP_SCENE)
	return true


func create_profile() -> bool:
	if auth_manager == null:
		_set_status("Gestionnaire de profils indisponible.", "error")
		return false
	if create_password_edit.text != create_confirm_edit.text:
		_set_status("Les mots de passe ne correspondent pas.", "error")
		return false
	var result: Dictionary = auth_manager.create_profile(
		create_pseudo_edit.text, create_password_edit.text
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Création impossible.")), "error")
		return false
	create_pseudo_edit.text = ""
	create_password_edit.text = ""
	create_confirm_edit.text = ""
	populate_profiles(str(result.get("id", "")))
	open_credentials()
	_set_status("Profil créé.")
	return true


func reveal_admin() -> void:
	if _admin_revealed or auth_manager == null:
		return
	var admin_id := ""
	for profile in auth_manager.get_profiles():
		if bool(profile.get("is_admin", false)):
			admin_id = str(profile["id"])
			break
	if admin_id == "":
		return
	_admin_revealed = true
	populate_profiles(admin_id)
	open_credentials()


func _on_title_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	_title_click_count += 1
	if _title_click_count >= ADMIN_REVEAL_CLICKS:
		reveal_admin()


func _show_step(step: Control, caption: String) -> void:
	step_label.text = caption
	for box in [selection_box, creation_box, credentials_box]:
		box.visible = box == step


func _on_profile_activated(_index: int) -> void:
	open_credentials()


func _on_password_submitted(_text: String) -> void:
	login()


func _wire_profile(profile_id: String) -> void:
	if auth_manager == null:
		return
	var save_path := str(auth_manager.get_profile_save_path(profile_id))
	if mail_manager != null and mail_manager.has_method("load_state"):
		mail_manager.save_path = save_path
		mail_manager.load_state()
	if commission_manager != null and commission_manager.has_method("load_state"):
		commission_manager.save_path = save_path
		if mail_manager != null:
			commission_manager.mail_manager = mail_manager
		commission_manager.load_state()


func _set_status(message: String, kind: String = "neutral") -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Palette.status_color(kind))


func _apply_palette() -> void:
	background.color = Palette.DESKTOP_BACKGROUND
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.COMMISSION_PANEL_BACKGROUND
	panel_style.border_color = Palette.WINDOW_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", panel_style)
	title_label.add_theme_color_override("font_color", Palette.TITLE_TEXT_ACTIVE)
	step_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	credentials_label.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	status_label.add_theme_color_override("font_color", Palette.STATUS_TEXT)
	profile_list.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	profile_list.add_theme_color_override("font_selected_color", Palette.TITLE_TEXT_ACTIVE)
	profile_list.add_theme_stylebox_override("panel", _make_button_style(Palette.MAIL_LIST_BACKGROUND))
	profile_list.add_theme_stylebox_override(
		"selected", _make_button_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	profile_list.add_theme_stylebox_override(
		"selected_focus", _make_button_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	for button in [continue_button, new_profile_button, create_button, login_button]:
		_style_button(button)
	for button in [creation_back_button, credentials_back_button]:
		_style_button(button)
	for field in [password_edit, create_pseudo_edit, create_password_edit, create_confirm_edit]:
		_style_field(field)


func _style_field(field: Control) -> void:
	field.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	field.add_theme_color_override("font_placeholder_color", Palette.COMMISSION_META_TEXT)
	field.add_theme_stylebox_override("normal", _make_button_style(Palette.APP_BUTTON_BACKGROUND))
	field.add_theme_stylebox_override("hover", _make_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	field.add_theme_stylebox_override("pressed", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))
	field.add_theme_stylebox_override("focus", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_stylebox_override("normal", _make_button_style(Palette.APP_BUTTON_BACKGROUND))
	button.add_theme_stylebox_override("hover", _make_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	button.add_theme_stylebox_override("pressed", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))
	button.add_theme_stylebox_override("focus", _make_button_style(Palette.APP_BUTTON_BACKGROUND))


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


