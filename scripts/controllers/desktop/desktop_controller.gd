extends Control

const WINDOW_SCENE: PackedScene = preload("res://scenes/components/window/window_component.tscn")
const MAIL_APP_SCENE: PackedScene = preload("res://scenes/controllers/mail/mail_app_controller.tscn")
const COMMISSIONS_APP_SCENE: PackedScene = preload(
	"res://scenes/controllers/commissions/commissions_app_controller.tscn"
)
const DEV_CONSOLE_SCENE: PackedScene = preload("res://scenes/controllers/dev/dev_console_controller.tscn")
const EDITOR_SCENE: PackedScene = preload(
	"res://scenes/controllers/editor/commission_editor_controller.tscn"
)
const DELIVERY_SCENE: PackedScene = preload(
	"res://scenes/controllers/delivery/delivery_controller.tscn"
)
const GALLERY_SCENE: PackedScene = preload("res://scenes/controllers/gallery/gallery_app_controller.tscn")
const PROFILE_APP_SCENE: PackedScene = preload("res://scenes/controllers/profile/profile_controller.tscn")
const LOGIN_SCENE := "res://scenes/controllers/login/login_controller.tscn"
const WIFI_INDICATOR_SCRIPT := preload("res://scripts/components/wifi/wifi_indicator.gd")
const CASCADE_ORIGIN := Vector2(96, 72)
const CASCADE_STEPS := 6
const NOTIFICATION_DURATION := 6.0

@onready var clock_label: Label = %ClockLabel
@onready var windows_layer: Control = %Windows
@onready var window_list: HBoxContainer = %WindowList
@onready var background: ColorRect = %Background
@onready var taskbar: PanelContainer = %Taskbar
@onready var wifi_indicator: Control = %WifiIndicator
@onready var mail_button: Button = %MailButton
@onready var commissions_button: Button = %CommissionsButton
@onready var gallery_button: Button = %GalleryButton
@onready var editor_button: Button = %EditorButton
@onready var dev_button: Button = %DevButton
@onready var profile_button: Button = %ProfileButton
@onready var logout_button: Button = %LogoutButton
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel

@export_group("Bureau")
@export var desktop_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND
@export var taskbar_background_color: PaletteData.Colors = PaletteData.Colors.BACKGROUND

@export_group("Notifications")
@export var notification_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var notification_border_color: PaletteData.Colors = PaletteData.Colors.BORDER
@export var notification_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_STRONG

@export_group("Boutons")
@export var app_button_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var app_button_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var app_button_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var app_button_text_color: PaletteData.Colors = PaletteData.Colors.TEXT

var auth_manager: Node

var _cascade_index: int = 0
var _window_buttons: Dictionary = {}
var _notification_queue: Array[String] = []
var _notification_timer: Timer
var _notification_visible: bool = false


func _ready() -> void:
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")
	_apply_palette()
	_update_clock()
	ClockManager.second_tick.connect(_update_clock)
	mail_button.pressed.connect(_open_mail_app)
	commissions_button.pressed.connect(_open_commissions_app)
	gallery_button.pressed.connect(_open_gallery)
	editor_button.pressed.connect(_open_commission_editor)
	dev_button.pressed.connect(_open_dev_console)
	profile_button.pressed.connect(_open_profile_app)
	logout_button.pressed.connect(_on_logout_pressed)
	if auth_manager != null and auth_manager.has_signal("session_changed"):
		auth_manager.session_changed.connect(_on_session_changed)
	_update_admin_visibility()
	CommissionManager.commission_reminder.connect(_on_commission_reminder)
	CommissionManager.commission_completed.connect(_on_commission_completed)
	CommissionManager.commission_failed.connect(_on_commission_failed)
	SyncManager.sync_finished.connect(_on_sync_finished)
	SyncManager.mode_changed.connect(_on_sync_mode_changed)
	wifi_indicator.pressed.connect(_on_wifi_pressed)
	_update_wifi_state()
	MailManager.ensure_welcome_mail()
	_notification_timer = Timer.new()
	_notification_timer.one_shot = true
	_notification_timer.wait_time = NOTIFICATION_DURATION
	_notification_timer.timeout.connect(_on_notification_timeout)
	add_child(_notification_timer)
	SyncManager.start()


func _apply_palette() -> void:
	background.color = Palette.color(desktop_background_color)
	var taskbar_background := Palette.color(taskbar_background_color)
	taskbar_background.a = Palette.TASKBAR_ALPHA
	var taskbar_style := StyleBoxFlat.new()
	taskbar_style.bg_color = taskbar_background
	taskbar_style.content_margin_left = 16.0
	taskbar_style.content_margin_right = 16.0
	taskbar.add_theme_stylebox_override("panel", taskbar_style)
	_style_app_button(mail_button)
	_style_app_button(commissions_button)
	_style_app_button(gallery_button)
	_style_app_button(editor_button)
	_style_app_button(dev_button)
	_style_app_button(profile_button)
	_style_app_button(logout_button)
	var notification_style := StyleBoxFlat.new()
	notification_style.bg_color = Palette.color(notification_background_color)
	notification_style.border_color = Palette.color(notification_border_color)
	notification_style.set_border_width_all(1)
	notification_style.set_corner_radius_all(4)
	notification_style.content_margin_left = 12.0
	notification_style.content_margin_right = 12.0
	notification_style.content_margin_top = 8.0
	notification_style.content_margin_bottom = 8.0
	notification_panel.add_theme_stylebox_override("panel", notification_style)
	notification_label.add_theme_color_override("font_color", Palette.color(notification_text_color))
	notification_panel.hide()


func _style_app_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.color(app_button_text_color))
	button.add_theme_color_override("font_hover_color", Palette.color(app_button_text_color))
	button.add_theme_color_override("font_pressed_color", Palette.color(app_button_text_color))
	button.add_theme_color_override("font_focus_color", Palette.color(app_button_text_color))
	button.add_theme_stylebox_override(
		"normal", _make_app_button_style(Palette.color(app_button_background_color))
	)
	button.add_theme_stylebox_override(
		"hover", _make_app_button_style(Palette.color(app_button_hover_color))
	)
	button.add_theme_stylebox_override(
		"pressed", _make_app_button_style(Palette.color(app_button_pressed_color))
	)
	button.add_theme_stylebox_override(
		"focus", _make_app_button_style(Palette.color(app_button_background_color))
	)


func _make_app_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _on_app_pressed(app_title: String) -> void:
	open_window(app_title, _make_placeholder_content("%s — bientôt disponible." % app_title))


func _open_mail_app() -> void:
	open_window("Courrier", MAIL_APP_SCENE.instantiate())


func _open_commissions_app() -> void:
	var app := COMMISSIONS_APP_SCENE.instantiate()
	app.delivery_requested.connect(_open_delivery)
	open_window("Commandes", app)


func _open_gallery() -> void:
	var gallery := GALLERY_SCENE.instantiate()
	gallery.commission_manager = CommissionManager
	gallery.delivery_manager = DeliveryManager
	var window: WindowComponent = open_window("Galerie", gallery)
	window.size = Vector2(820, 600)
	window.clamp_into_work_area()


func _open_delivery(commission_id: String) -> void:
	var delivery := DELIVERY_SCENE.instantiate()
	delivery.commission_manager = CommissionManager
	delivery.delivery_manager = DeliveryManager
	delivery.setup(commission_id)
	var window: WindowComponent = open_window("Livraison", delivery)
	window.size = Vector2(720, 560)
	window.clamp_into_work_area()
	delivery.delivered.connect(_on_delivery_delivered.bind(window))


func _on_delivery_delivered(commission_id: String, window: WindowComponent) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	var title := str(commission.get("title", commission_id))
	if is_instance_valid(window):
		window.close()
	if bool(commission.get("delivery_late", false)):
		_show_notification("Livraison envoyée (trop tard) : %s" % title)
		return
	_show_notification("Livraison envoyée : %s" % title)


func _open_commission_editor() -> void:
	var window: WindowComponent = open_window("Éditeur", EDITOR_SCENE.instantiate())
	window.size = Vector2(880, 600)
	window.clamp_into_work_area()


func _open_dev_console() -> void:
	var console = DEV_CONSOLE_SCENE.instantiate()
	console.desktop = self
	if auth_manager != null:
		console.auth_manager = auth_manager
	open_window("Console dev", console)


func _open_profile_app() -> void:
	var profile = PROFILE_APP_SCENE.instantiate()
	if auth_manager != null:
		profile.auth_manager = auth_manager
	profile.logout_requested.connect(_on_logout_requested)
	open_window("Profil", profile)


func _update_admin_visibility() -> void:
	var is_admin: bool = auth_manager != null and auth_manager.is_dev_session()
	dev_button.visible = is_admin
	editor_button.visible = is_admin


func _on_session_changed(_authenticated: bool, _is_admin: bool) -> void:
	_update_admin_visibility()


func _on_logout_pressed() -> void:
	if auth_manager != null:
		auth_manager.logout()
	_on_logout_requested()


func _on_logout_requested() -> void:
	_update_admin_visibility()
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(LOGIN_SCENE)


func _on_commission_reminder(commission_id: String, hours_remaining: int) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	var title := str(commission.get("title", commission_id))
	_show_notification("Rappel : %s — %d h restantes" % [title, hours_remaining])


func _on_commission_completed(commission_id: String) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	var title := str(commission.get("title", commission_id))
	_show_notification("Commande terminée : %s" % title)


func _on_commission_failed(commission_id: String) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	_show_notification("Commande échouée : %s" % str(commission.get("title", commission_id)))


func _on_sync_finished(reachable: bool, new_offers: int) -> void:
	var was_error: bool = wifi_indicator.get_state() == WIFI_INDICATOR_SCRIPT.STATE_ERROR
	_update_wifi_state()
	if not reachable:
		if not was_error:
			_show_notification("Synchronisation impossible : source injoignable")
		return
	if new_offers <= 0:
		return
	if new_offers == 1:
		_show_notification("Nouvelle commande reçue")
		return
	_show_notification("%d nouvelles commandes reçues" % new_offers)


func _on_sync_mode_changed(_mode: String) -> void:
	_update_wifi_state()


func _on_wifi_pressed() -> void:
	var next_mode := SyncManager.MODE_LOCAL
	if SyncManager.mode == SyncManager.MODE_LOCAL:
		next_mode = SyncManager.MODE_REMOTE
	SyncManager.set_mode(next_mode)
	SyncManager.save_config()
	SyncManager.fetch()


func _update_wifi_state() -> void:
	if SyncManager.force_remote_ok:
		wifi_indicator.set_state(WIFI_INDICATOR_SCRIPT.STATE_REMOTE)
		return
	if SyncManager.last_sync_mode == SyncManager.mode and not SyncManager.last_sync_ok:
		wifi_indicator.set_state(WIFI_INDICATOR_SCRIPT.STATE_ERROR)
		return
	if SyncManager.mode == SyncManager.MODE_REMOTE:
		wifi_indicator.set_state(WIFI_INDICATOR_SCRIPT.STATE_REMOTE)
		return
	wifi_indicator.set_state(WIFI_INDICATOR_SCRIPT.STATE_LOCAL)


func _show_notification(message: String) -> void:
	if _notification_visible:
		_notification_queue.append(message)
		return
	_notification_visible = true
	notification_label.text = message
	notification_panel.show()
	_notification_timer.start()


func _on_notification_timeout() -> void:
	if _notification_queue.is_empty():
		_notification_visible = false
		notification_panel.hide()
		return
	notification_label.text = _notification_queue.pop_front()
	_notification_timer.start()


func _update_clock() -> void:
	clock_label.text = ClockManager.get_time_string()


func open_window(title: String, content: Control) -> WindowComponent:
	var window: WindowComponent = WINDOW_SCENE.instantiate()
	windows_layer.add_child(window)
	window.setup(title, content)
	var step := _cascade_index % CASCADE_STEPS
	window.position = CASCADE_ORIGIN + Vector2.ONE * (step * window.cascade_offset)
	_cascade_index += 1
	window.clamp_into_work_area()
	window.closed.connect(_on_window_closed)
	window.minimize_toggled.connect(_on_window_minimize_toggled)
	_add_window_button(window)
	_focus_window(window)
	return window


func _add_window_button(window: WindowComponent) -> void:
	var button := Button.new()
	button.text = window.window_title
	button.custom_minimum_size = Vector2(120, 26)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_window_button_pressed.bind(window))
	window_list.add_child(button)
	_window_buttons[window] = button


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var window := _topmost_window_at(event.position)
		if window != null:
			_focus_window(window)


func _topmost_window_at(point: Vector2) -> WindowComponent:
	var topmost: WindowComponent
	for child in windows_layer.get_children():
		if child is WindowComponent and child.is_visible_in_tree():
			if child.get_global_rect().has_point(point):
				topmost = child
	return topmost


func _focus_window(window: WindowComponent) -> void:
	for child in windows_layer.get_children():
		if child is WindowComponent:
			child.set_focused(child == window)
	window.focus()


func _on_window_button_pressed(window: WindowComponent) -> void:
	if window.is_minimized:
		window.restore()
	_focus_window(window)


func _on_window_minimize_toggled(window: WindowComponent, minimized: bool) -> void:
	var button: Button = _window_buttons.get(window)
	if button != null:
		button.modulate.a = Palette.TASKBAR_BUTTON_MINIMIZED_ALPHA if minimized else 1.0


func _on_window_closed(window: WindowComponent) -> void:
	var button: Button = _window_buttons.get(window)
	if button != null:
		button.queue_free()
	_window_buttons.erase(window)


func _make_placeholder_content(message: String) -> Control:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label
