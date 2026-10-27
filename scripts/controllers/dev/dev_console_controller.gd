@tool
extends Control

@onready var panel: PanelContainer = %Panel
@onready var header: Label = %Header
@onready var status_label: Label = %StatusLabel
@onready var buttons_box: GridContainer = %Buttons
@onready var clean_button: Button = %CleanButton
@onready var offer_button: Button = %OfferButton
@onready var reminder_24_button: Button = %Reminder24Button
@onready var reminder_1_button: Button = %Reminder1Button
@onready var failure_button: Button = %FailureButton
@onready var success_button: Button = %SuccessButton
@onready var sync_header: Label = %SyncHeader
@onready var mode_option: OptionButton = %ModeOption
@onready var local_path_edit: LineEdit = %LocalPathEdit
@onready var remote_url_edit: LineEdit = %RemoteUrlEdit
@onready var interval_edit: LineEdit = %IntervalEdit
@onready var save_config_button: Button = %SaveConfigButton
@onready var sync_button: Button = %SyncButton
@onready var raw_file_button: Button = %RawFileButton
@onready var last_sync_label: Label = %LastSyncLabel
@onready var publish_header: Label = %PublishHeader
@onready var repo_path_edit: LineEdit = %RepoPathEdit
@onready var git_remote_edit: LineEdit = %GitRemoteEdit
@onready var git_branch_edit: LineEdit = %GitBranchEdit
@onready var save_dev_config_button: Button = %SaveDevConfigButton
@onready var publish_button: Button = %PublishButton
@onready var publish_log: TextEdit = %PublishLog
@onready var force_wifi_check: CheckButton = %ForceWifiCheck
@onready var profiles_separator: HSeparator = %ProfilesSeparator
@onready var profiles_header: Label = %ProfilesHeader
@onready var profile_list: ItemList = %ProfileList
@onready var admin_password_edit: LineEdit = %AdminPasswordEdit
@onready var delete_profile_button: Button = %DeleteProfileButton

@export_group("Panneau")
@export var panel_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE

@export_group("Textes")
@export var header_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var status_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var section_header_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var log_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var log_text_color: PaletteData.Colors = PaletteData.Colors.TEXT

@export_group("Liste")
@export var list_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var list_selected_background_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var list_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var list_selected_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG

@export_group("Boutons")
@export var button_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var button_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var button_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var button_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var danger_background_color: PaletteData.Colors = PaletteData.Colors.DANGER
@export var danger_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG

@export_group("Champs")
@export var field_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var field_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var field_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var field_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var field_placeholder_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED

var sync_manager: Node
var auth_manager: Node
var desktop: Node

var _profile_ids: Array[String] = []

const RAW_FILE_SCENE: PackedScene = preload("res://scenes/controllers/dev/raw_file_controller.tscn")

const FIXTURE_OFFER := {
	"id": "fixture_offer",
	"title": "Affiche fixture",
	"type": "affiche",
	"duration": 240,
	"client": "Studio fixture",
	"sender": "contact@studio-fixture.example",
	"description": "Offre générée par l'état de test propre.",
	"mail_request": "Merci de réaliser cette affiche de test.",
	"mail_success": "L'affiche de test est terminée.",
	"mail_failure": "L'affiche de test a dépassé son délai.",
}

const FIXTURES := [
	{
		"id": "test_illustration",
		"title": "Illustration de test",
		"type": "illustration",
		"duration": null,
		"client": "Studio de test",
		"sender": "contact@studio-de-test.example",
		"description": "Commande de test pour le type illustration.",
		"mail_request": "Merci de réaliser cette illustration de test.",
		"mail_success": "L'illustration de test est terminée.",
		"mail_failure": "L'illustration de test a dépassé son délai.",
	},
	{
		"id": "test_affiche",
		"title": "Affiche de test",
		"type": "affiche",
		"duration": 1800,
		"client": "Studio de test",
		"sender": "contact@studio-de-test.example",
		"description": "Commande de test avec une durée personnalisée.",
		"mail_request": "Merci de réaliser cette affiche de test.",
		"mail_success": "L'affiche de test est terminée.",
		"mail_failure": "L'affiche de test a dépassé son délai.",
	},
	{
		"id": "test_croquis",
		"title": "Croquis de test",
		"type": "croquis",
		"duration": 180,
		"client": "Studio de test",
		"sender": "contact@studio-de-test.example",
		"description": "Commande de test courte.",
		"mail_request": "Merci de réaliser ce croquis de test.",
		"mail_success": "Le croquis de test est terminé.",
		"mail_failure": "Le croquis de test a dépassé son délai.",
	},
]


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_palette()
		return
	if sync_manager == null:
		sync_manager = get_node_or_null("/root/SyncManager")
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")
	_apply_palette()
	clean_button.pressed.connect(_on_clean_pressed)
	offer_button.pressed.connect(_on_offer_pressed)
	reminder_24_button.pressed.connect(_on_reminder_pressed.bind(24))
	reminder_1_button.pressed.connect(_on_reminder_pressed.bind(1))
	failure_button.pressed.connect(_on_failure_pressed)
	success_button.pressed.connect(_on_success_pressed)
	save_config_button.pressed.connect(save_sync_config)
	sync_button.pressed.connect(sync_now)
	raw_file_button.pressed.connect(show_raw_file)
	save_dev_config_button.pressed.connect(save_dev_config)
	publish_button.pressed.connect(publish_now)
	force_wifi_check.toggled.connect(_on_force_wifi_toggled)
	delete_profile_button.pressed.connect(delete_selected_profile)
	if auth_manager != null and auth_manager.has_signal("profiles_changed"):
		auth_manager.profiles_changed.connect(_on_profiles_changed)
	if auth_manager != null and auth_manager.has_signal("session_changed"):
		auth_manager.session_changed.connect(_on_auth_session_changed)
	if sync_manager != null and sync_manager.has_signal("mode_changed"):
		sync_manager.mode_changed.connect(_on_sync_mode_changed)
	if sync_manager != null and not sync_manager.sync_finished.is_connected(_on_sync_finished):
		sync_manager.sync_finished.connect(_on_sync_finished)
	if sync_manager != null:
		force_wifi_check.button_pressed = sync_manager.force_remote_ok
	_populate_sync_fields()
	_populate_dev_fields()
	_update_last_sync_label()
	_populate_profiles()
	_update_profiles_visibility()
	_set_status("Prêt.")


func _apply_palette() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(panel_background_color)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	header.add_theme_color_override("font_color", Palette.color(header_text_color))
	status_label.add_theme_color_override("font_color", Palette.color(status_text_color))
	sync_header.add_theme_color_override("font_color", Palette.color(section_header_text_color))
	publish_header.add_theme_color_override(
		"font_color", Palette.color(section_header_text_color)
	)
	profiles_header.add_theme_color_override(
		"font_color", Palette.color(section_header_text_color)
	)
	last_sync_label.add_theme_color_override("font_color", Palette.color(status_text_color))
	publish_log.add_theme_color_override("font_color", Palette.color(log_text_color))
	publish_log.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.color(log_background_color))
	)
	publish_log.add_theme_stylebox_override(
		"read_only", _make_button_style(Palette.color(log_background_color))
	)
	publish_log.add_theme_stylebox_override(
		"focus", _make_button_style(Palette.color(log_background_color))
	)
	for child in buttons_box.get_children():
		if child is Button:
			_style_button(child)
	_style_button(save_config_button)
	_style_button(sync_button)
	_style_button(raw_file_button)
	_style_button(save_dev_config_button)
	_style_button(publish_button)
	_style_danger_button(delete_profile_button)
	profile_list.add_theme_color_override("font_color", Palette.color(list_text_color))
	profile_list.add_theme_color_override(
		"font_selected_color", Palette.color(list_selected_text_color)
	)
	profile_list.add_theme_stylebox_override(
		"panel", _make_button_style(Palette.color(list_background_color))
	)
	profile_list.add_theme_stylebox_override(
		"selected", _make_button_style(Palette.color(list_selected_background_color))
	)
	for field in [
		mode_option,
		local_path_edit,
		remote_url_edit,
		interval_edit,
		admin_password_edit,
		repo_path_edit,
		git_remote_edit,
		git_branch_edit,
	]:
		_style_field(field)


func _style_field(field: Control) -> void:
	field.add_theme_color_override("font_color", Palette.color(field_text_color))
	field.add_theme_color_override(
		"font_placeholder_color", Palette.color(field_placeholder_color)
	)
	field.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.color(field_background_color))
	)
	field.add_theme_stylebox_override("hover", _make_button_style(Palette.color(field_hover_color)))
	field.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.color(field_pressed_color))
	)
	field.add_theme_stylebox_override(
		"focus", _make_button_style(Palette.color(field_pressed_color))
	)


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_hover_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_pressed_color", Palette.color(button_text_color))
	button.add_theme_color_override("font_focus_color", Palette.color(button_text_color))
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


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _style_danger_button(button: Button) -> void:
	var background_color := Palette.color(danger_background_color)
	var text_color := Palette.color(danger_text_color)
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


func _populate_profiles(selected_id: String = "") -> void:
	if auth_manager == null or profile_list == null:
		return
	if selected_id == "":
		selected_id = _selected_profile_id()
	profile_list.clear()
	_profile_ids.clear()
	for profile in auth_manager.get_profiles():
		var label := str(profile["pseudo"])
		if bool(profile["is_admin"]):
			label = "%s (admin)" % label
		var index := profile_list.add_item(label)
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


func _selected_profile_id() -> String:
	if profile_list == null:
		return ""
	var selection := profile_list.get_selected_items()
	if selection.is_empty():
		return ""
	return _profile_ids[selection[0]]


func delete_selected_profile() -> bool:
	if auth_manager == null:
		_set_status("Gestionnaire de profils indisponible.")
		return false
	var profile_id := _selected_profile_id()
	if profile_id == "":
		_set_status("Sélectionnez un profil.")
		return false
	var result: Dictionary = auth_manager.delete_profile_as_admin(
		profile_id, admin_password_edit.text
	)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Suppression impossible.")))
		return false
	admin_password_edit.text = ""
	_populate_profiles()
	_set_status("Profil supprimé.")
	return true


func _update_profiles_visibility() -> void:
	var is_admin: bool = auth_manager != null and auth_manager.is_dev_session()
	profiles_separator.visible = is_admin
	profiles_header.visible = is_admin
	profile_list.visible = is_admin
	admin_password_edit.visible = is_admin
	delete_profile_button.visible = is_admin


func _on_profiles_changed() -> void:
	_populate_profiles()


func _on_auth_session_changed(_authenticated: bool, _is_admin: bool) -> void:
	_update_profiles_visibility()


func _on_clean_pressed() -> void:
	MailManager.clear_all()
	CommissionManager.clear_all()
	MailManager.ensure_welcome_mail()
	CommissionManager.create_offer(FIXTURE_OFFER)
	for fixture in FIXTURES:
		CommissionManager.accept(fixture)
	_set_status("État de test prêt : accueil, offre et 3 commandes actives.")


func _on_offer_pressed() -> void:
	CommissionManager.create_offer({
		"id": "cheat_offer_%d" % Time.get_ticks_usec(),
		"title": "Affiche éclair",
		"type": "affiche",
		"duration": 60,
		"client": "Studio éclair",
		"sender": "contact@studio-eclair.example",
		"description": "Offre de test.",
		"mail_request": "Offre de test pour la boîte de réception.",
		"mail_success": "Merci pour cette affiche éclair.",
		"mail_failure": "L'affiche éclair a dépassé son délai.",
	})
	_set_status("Nouvelle offre ajoutée.")


func _populate_sync_fields() -> void:
	if sync_manager == null:
		return
	mode_option.selected = 1 if sync_manager.mode == "remote" else 0
	local_path_edit.text = sync_manager.local_path
	remote_url_edit.text = sync_manager.remote_url
	interval_edit.text = str(sync_manager.sync_interval_minutes)


func save_sync_config() -> void:
	if sync_manager == null:
		_set_status("SyncManager indisponible.")
		return
	sync_manager.set_mode("remote" if mode_option.selected == 1 else "local")
	sync_manager.local_path = local_path_edit.text.strip_edges()
	sync_manager.remote_url = remote_url_edit.text.strip_edges()
	sync_manager.sync_interval_minutes = max(0, int(interval_edit.text))
	sync_manager.save_config()
	sync_manager.apply_interval(sync_manager.sync_interval_minutes)
	_set_status("Config de synchronisation enregistrée.")


func _populate_dev_fields() -> void:
	if sync_manager == null:
		return
	repo_path_edit.text = sync_manager.repo_path
	git_remote_edit.text = sync_manager.git_remote
	git_branch_edit.text = sync_manager.git_branch


func save_dev_config() -> void:
	if sync_manager == null:
		_set_status("SyncManager indisponible.")
		return
	sync_manager.repo_path = repo_path_edit.text.strip_edges()
	sync_manager.git_remote = git_remote_edit.text.strip_edges()
	sync_manager.git_branch = git_branch_edit.text.strip_edges()
	sync_manager.save_dev_config()
	_set_status("Config de publication enregistrée.")


func publish_now() -> bool:
	if sync_manager == null:
		_set_status("SyncManager indisponible.")
		return false
	save_dev_config()
	_set_status("Publication en cours…")
	var result: Dictionary = sync_manager.publish()
	_append_publish_log(result)
	if not bool(result.get("ok", false)):
		_set_status(str(result.get("error", "Publication impossible.")))
		return false
	_set_status("Publié — version %d." % int(result.get("version", 0)))
	if sync_manager.has_method("fetch"):
		sync_manager.fetch()
	return true


func _append_publish_log(result: Dictionary) -> void:
	var lines: PackedStringArray = result.get("lines", PackedStringArray())
	var text := "\n".join(lines)
	if publish_log.text.strip_edges() != "" and text != "":
		text = "%s\n%s" % [publish_log.text, text]
	elif publish_log.text.strip_edges() != "":
		text = publish_log.text
	publish_log.text = text
	publish_log.scroll_vertical = publish_log.get_line_count()


func sync_now() -> void:
	if sync_manager == null:
		_set_status("SyncManager indisponible.")
		return
	if not sync_manager.sync_finished.is_connected(_on_sync_finished):
		sync_manager.sync_finished.connect(_on_sync_finished)
	_set_status("Synchronisation…")
	sync_manager.fetch()


func show_raw_file() -> void:
	if desktop == null or sync_manager == null:
		_set_status("Affichage du fichier local impossible hors du bureau.")
		return
	var view = RAW_FILE_SCENE.instantiate()
	view.setup(sync_manager.local_path)
	desktop.open_window("Fichier local", view)


func _on_sync_finished(reachable: bool, new_offers: int) -> void:
	_update_last_sync_label()
	if not reachable:
		_set_status("Source injoignable : cache utilisé s'il existe.")
		return
	_set_status("Synchronisé : %d nouvelle(s) offre(s)." % new_offers)


func _on_sync_mode_changed(mode: String) -> void:
	mode_option.selected = 1 if mode == "remote" else 0

func _on_force_wifi_toggled(enabled: bool) -> void:
	if sync_manager != null:
		sync_manager.force_remote_ok = enabled
	if desktop != null:
		desktop._update_wifi_state()


func _update_last_sync_label() -> void:
	if sync_manager == null:
		last_sync_label.text = "Dernière sync : —"
		return
	last_sync_label.text = "Dernière sync : %s" % sync_manager.get_last_sync_text()


func _on_reminder_pressed(hours: int) -> void:
	var commission_id := _accept_test_commission("%d h" % hours, hours * 60)
	CommissionManager.check_deadlines()
	_set_status("Rappel %d h déclenché (%s)." % [hours, commission_id])


func _on_failure_pressed() -> void:
	var commission_id := _accept_test_commission("Échec", 0)
	CommissionManager.check_deadlines()
	_set_status("Échec déclenché (%s)." % commission_id)


func _on_success_pressed() -> void:
	var commission_id := _accept_test_commission("Succès", 60)
	CommissionManager.complete(commission_id)
	_set_status("Succès déclenché (%s)." % commission_id)


func _accept_test_commission(label: String, duration_minutes: int) -> String:
	var commission_id := "cheat_%d" % Time.get_ticks_usec()
	CommissionManager.accept({
		"id": commission_id,
		"title": "Commande %s" % label,
		"type": "affiche",
		"duration": duration_minutes,
		"client": "Studio de test",
		"sender": "contact@studio-de-test.example",
		"description": "Commande de test générée par la console dev.",
		"mail_request": "Commande de test.",
		"mail_success": "Commande de test terminée.",
		"mail_failure": "Commande de test échouée.",
	})
	return commission_id


func _set_status(message: String) -> void:
	status_label.text = message
