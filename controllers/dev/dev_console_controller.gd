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

const FIXTURES := [
	{
		"id": "test_illustration",
		"title": "Illustration de test",
		"type": "illustration",
		"duration": null,
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
		"description": "Commande de test courte.",
		"mail_request": "Merci de réaliser ce croquis de test.",
		"mail_success": "Le croquis de test est terminé.",
		"mail_failure": "Le croquis de test a dépassé son délai.",
	},
]


func _ready() -> void:
	_apply_palette()
	clean_button.pressed.connect(_on_clean_pressed)
	offer_button.pressed.connect(_on_offer_pressed)
	reminder_24_button.pressed.connect(_on_reminder_pressed.bind(24))
	reminder_1_button.pressed.connect(_on_reminder_pressed.bind(1))
	failure_button.pressed.connect(_on_failure_pressed)
	success_button.pressed.connect(_on_success_pressed)
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
	for child in buttons_box.get_children():
		if child is Button:
			_style_button(child)


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
	CommissionManager.ensure_demo_offer()
	for fixture in FIXTURES:
		CommissionManager.accept(fixture)
	_set_status("État de test prêt : accueil, offre et 3 commandes actives.")


func _on_offer_pressed() -> void:
	var commission_id := "cheat_offer_%d" % Time.get_ticks_usec()
	MailManager.add_mail({
		"id": "%s_mail" % commission_id,
		"from": "Studio Studraw",
		"subject": "Nouvelle commande : Affiche éclair",
		"body": "Offre de test pour la boîte de réception.",
		"received_at": int(Time.get_unix_time_from_system()),
		"type": "commission_offer",
		"commission": {
			"id": commission_id,
			"title": "Affiche éclair",
			"type": "affiche",
			"duration": 60,
			"description": "Offre de test.",
			"mail_request": "Offre de test pour la boîte de réception.",
			"mail_success": "Merci pour cette affiche éclair.",
			"mail_failure": "L'affiche éclair a dépassé son délai.",
		},
	})
	_set_status("Nouvelle offre ajoutée.")


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
		"description": "Commande de test générée par la console dev.",
		"mail_request": "Commande de test.",
		"mail_success": "Commande de test terminée.",
		"mail_failure": "Commande de test échouée.",
	})
	return commission_id


func _set_status(message: String) -> void:
	status_label.text = message
