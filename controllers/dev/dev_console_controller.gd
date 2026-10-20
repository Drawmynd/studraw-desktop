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
@onready var force_wifi_check: CheckButton = %ForceWifiCheck

var sync_manager: Node
var desktop: Node

const RAW_FILE_SCENE: PackedScene = preload("res://controllers/dev/raw_file_controller.tscn")

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
	if sync_manager == null:
		sync_manager = get_node_or_null("/root/SyncManager")
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
	force_wifi_check.toggled.connect(_on_force_wifi_toggled)
	if sync_manager != null and sync_manager.has_signal("mode_changed"):
		sync_manager.mode_changed.connect(_on_sync_mode_changed)
	if sync_manager != null and not sync_manager.sync_finished.is_connected(_on_sync_finished):
		sync_manager.sync_finished.connect(_on_sync_finished)
	if sync_manager != null:
		force_wifi_check.button_pressed = sync_manager.force_remote_ok
	_populate_sync_fields()
	_update_last_sync_label()
	_set_status("Prêt.")


func _apply_palette() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COMMISSION_PANEL_BACKGROUND
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	header.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	status_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	sync_header.add_theme_color_override("font_color", Palette.COMMISSION_TEXT)
	last_sync_label.add_theme_color_override("font_color", Palette.COMMISSION_META_TEXT)
	for child in buttons_box.get_children():
		if child is Button:
			_style_button(child)
	_style_button(save_config_button)
	_style_button(sync_button)
	_style_button(raw_file_button)
	for field in [mode_option, local_path_edit, remote_url_edit, interval_edit]:
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


func _make_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


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
