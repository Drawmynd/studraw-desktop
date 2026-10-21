extends Control

signal logout_requested

@onready var panel: PanelContainer = %Panel
@onready var pseudo_label: Label = %PseudoLabel
@onready var role_label: Label = %RoleLabel
@onready var step_label: Label = %StepLabel
@onready var actions_box: VBoxContainer = %ActionsBox
@onready var change_button: Button = %ChangeButton
@onready var delete_button: Button = %DeleteButton
@onready var logout_button: Button = %LogoutButton
@onready var credentials_box: VBoxContainer = %CredentialsBox
@onready var pseudo_edit: LineEdit = %PseudoEdit
@onready var password_edit: LineEdit = %PasswordEdit
@onready var confirm_edit: LineEdit = %ConfirmEdit
@onready var credentials_continue_button: Button = %CredentialsContinueButton
@onready var credentials_back_button: Button = %CredentialsBackButton
@onready var password_box: VBoxContainer = %PasswordBox
@onready var current_password_edit: LineEdit = %CurrentPasswordEdit
@onready var password_save_button: Button = %PasswordSaveButton
@onready var password_back_button: Button = %PasswordBackButton
@onready var delete_box: VBoxContainer = %DeleteBox
@onready var delete_password_edit: LineEdit = %DeletePasswordEdit
@onready var delete_confirm_button: Button = %DeleteConfirmButton
@onready var delete_back_button: Button = %DeleteBackButton
@onready var status_label: Label = %StatusLabel

var auth_manager: Node

var _pending_pseudo: String = ""
var _pending_password: String = ""


func _ready() -> void:
	_resolve_dependencies()
	_apply_palette()
	change_button.pressed.connect(open_credentials)
	delete_button.pressed.connect(open_delete)
	logout_button.pressed.connect(request_logout)
	credentials_continue_button.pressed.connect(open_password)
	credentials_back_button.pressed.connect(back_to_actions)
	password_save_button.pressed.connect(save_credentials)
	password_back_button.pressed.connect(open_credentials.bind(false))
	delete_confirm_button.pressed.connect(delete_profile)
	delete_back_button.pressed.connect(back_to_actions)
	refresh()


func _resolve_dependencies() -> void:
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")


func refresh() -> void:
	var profile: Dictionary = {}
	if auth_manager != null:
		profile = auth_manager.get_current_profile()
	if profile.is_empty():
		pseudo_label.text = "Session fermée"
		role_label.text = ""
		back_to_actions()
		return
	pseudo_label.text = str(profile.get("pseudo", ""))
	role_label.text = "Administrateur" if bool(profile.get("is_admin", false)) else "Profil standard"
	back_to_actions()


func open_credentials(reset: bool = true) -> void:
	if reset:
		_pending_pseudo = ""
		_pending_password = ""
	pseudo_edit.text = _pending_pseudo
	password_edit.text = ""
	confirm_edit.text = ""
	_show_step(credentials_box, "Changer mes identifiants")
	_set_status("Laissez un champ vide pour conserver sa valeur.")
	pseudo_edit.grab_focus()


func open_password() -> void:
	if password_edit.text != confirm_edit.text:
		_set_status("Les mots de passe ne correspondent pas.", "error")
		return
	_pending_pseudo = pseudo_edit.text
	_pending_password = password_edit.text
	current_password_edit.text = ""
	_show_step(password_box, "Mot de passe actuel")
	_set_status("Confirmez avec votre mot de passe actuel.")
	current_password_edit.grab_focus()


func open_delete() -> void:
	delete_password_edit.text = ""
	_show_step(delete_box, "Supprimer le profil")
	_set_status("Le profil et sa progression seront supprimés.", "error")
	delete_password_edit.grab_focus()


func back_to_actions() -> void:
	_show_step(actions_box, "Mon compte")
	_set_status("Que voulez-vous faire ?")


func save_credentials() -> bool:
	if auth_manager == null:
		_set_status("Gestionnaire de profils indisponible.", "error")
		return false
	var profile: Dictionary = auth_manager.get_current_profile()
	if profile.is_empty():
		_set_status("Aucune session ouverte.", "error")
		return false
	var result: Dictionary = auth_manager.change_credentials(
		str(profile["id"]),
		current_password_edit.text,
		_pending_pseudo,
		_pending_password
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Modification impossible.")), "error")
		return false
	_pending_pseudo = ""
	_pending_password = ""
	refresh()
	_set_status("Identifiants enregistrés.")
	return true


func delete_profile() -> bool:
	if auth_manager == null:
		_set_status("Gestionnaire de profils indisponible.", "error")
		return false
	var profile: Dictionary = auth_manager.get_current_profile()
	if profile.is_empty():
		_set_status("Aucune session ouverte.", "error")
		return false
	var result: Dictionary = auth_manager.delete_profile(
		str(profile["id"]), delete_password_edit.text
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Suppression impossible.")), "error")
		return false
	delete_password_edit.text = ""
	logout_requested.emit()
	return true


func request_logout() -> void:
	if auth_manager != null:
		auth_manager.logout()
	logout_requested.emit()


func _show_step(step: Control, caption: String) -> void:
	step_label.text = caption
	for box in [actions_box, credentials_box, password_box, delete_box]:
		box.visible = box == step


func _set_status(message: String, kind: String = "neutral") -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Palette.status_color(kind))


func _apply_palette() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.COMMISSION_PANEL_BACKGROUND
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)
	pseudo_label.add_theme_color_override("font_color", Palette.TITLE_TEXT_ACTIVE)
	role_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	step_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	status_label.add_theme_color_override("font_color", Palette.STATUS_TEXT)
	_style_button(change_button, false)
	_style_button(logout_button, false)
	_style_button(credentials_continue_button, false)
	_style_button(credentials_back_button, false)
	_style_button(password_save_button, false)
	_style_button(password_back_button, false)
	_style_button(delete_button, true)
	_style_button(delete_confirm_button, true)
	_style_button(delete_back_button, false)
	for field in [current_password_edit, pseudo_edit, password_edit, confirm_edit, delete_password_edit]:
		_style_field(field)


func _style_field(field: Control) -> void:
	field.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	field.add_theme_color_override("font_placeholder_color", Palette.COMMISSION_META_TEXT)
	field.add_theme_stylebox_override("normal", _make_button_style(Palette.APP_BUTTON_BACKGROUND))
	field.add_theme_stylebox_override("hover", _make_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	field.add_theme_stylebox_override("pressed", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))
	field.add_theme_stylebox_override("focus", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED))


func _style_button(button: Button, danger: bool) -> void:
	var text_color := Palette.DANGER_TEXT if danger else Palette.APP_BUTTON_TEXT
	var normal := Palette.DANGER_BACKGROUND if danger else Palette.APP_BUTTON_BACKGROUND
	var hover := Palette.DANGER_BACKGROUND_HOVER if danger else Palette.APP_BUTTON_BACKGROUND_HOVER
	var pressed := Palette.DANGER_BACKGROUND_PRESSED if danger else Palette.APP_BUTTON_BACKGROUND_PRESSED
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_stylebox_override("normal", _make_button_style(normal))
	button.add_theme_stylebox_override("hover", _make_button_style(hover))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed))
	button.add_theme_stylebox_override("focus", _make_button_style(normal))


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


