extends Control

const WINDOW_SCENE: PackedScene = preload("res://components/window/window_component.tscn")
const MAIL_APP_SCENE: PackedScene = preload("res://controllers/mail/mail_app_controller.tscn")
const COMMISSIONS_APP_SCENE: PackedScene = preload(
	"res://controllers/commissions/commissions_app_controller.tscn"
)
const DEV_CONSOLE_SCENE: PackedScene = preload("res://controllers/dev/dev_console_controller.tscn")
const CASCADE_ORIGIN := Vector2(96, 72)
const CASCADE_STEPS := 6
const NOTIFICATION_DURATION := 6.0

@onready var clock_label: Label = %ClockLabel
@onready var windows_layer: Control = %Windows
@onready var window_list: HBoxContainer = %WindowList
@onready var background: ColorRect = %Background
@onready var taskbar: PanelContainer = %Taskbar
@onready var mail_button: Button = %MailButton
@onready var commissions_button: Button = %CommissionsButton
@onready var dev_button: Button = %DevButton
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel

var _cascade_index: int = 0
var _window_buttons: Dictionary = {}
var _notification_queue: Array[String] = []
var _notification_timer: Timer
var _notification_visible: bool = false


func _ready() -> void:
	_apply_palette()
	_update_clock()
	ClockManager.second_tick.connect(_update_clock)
	mail_button.pressed.connect(_open_mail_app)
	commissions_button.pressed.connect(_open_commissions_app)
	dev_button.pressed.connect(_open_dev_console)
	CommissionManager.commission_reminder.connect(_on_commission_reminder)
	CommissionManager.commission_completed.connect(_on_commission_completed)
	CommissionManager.commission_failed.connect(_on_commission_failed)
	MailManager.ensure_welcome_mail()
	CommissionManager.ensure_demo_offer()
	_notification_timer = Timer.new()
	_notification_timer.one_shot = true
	_notification_timer.wait_time = NOTIFICATION_DURATION
	_notification_timer.timeout.connect(_on_notification_timeout)
	add_child(_notification_timer)


func _apply_palette() -> void:
	background.color = Palette.DESKTOP_BACKGROUND
	var taskbar_style := StyleBoxFlat.new()
	taskbar_style.bg_color = Palette.TASKBAR_BACKGROUND
	taskbar_style.content_margin_left = 16.0
	taskbar_style.content_margin_right = 16.0
	taskbar.add_theme_stylebox_override("panel", taskbar_style)
	_style_app_button(mail_button)
	_style_app_button(commissions_button)
	_style_app_button(dev_button)
	var notification_style := StyleBoxFlat.new()
	notification_style.bg_color = Palette.NOTIFICATION_BACKGROUND
	notification_style.border_color = Palette.NOTIFICATION_BORDER
	notification_style.set_border_width_all(1)
	notification_style.set_corner_radius_all(4)
	notification_style.content_margin_left = 12.0
	notification_style.content_margin_right = 12.0
	notification_style.content_margin_top = 8.0
	notification_style.content_margin_bottom = 8.0
	notification_panel.add_theme_stylebox_override("panel", notification_style)
	notification_label.add_theme_color_override("font_color", Palette.NOTIFICATION_TEXT)
	notification_panel.hide()


func _style_app_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_stylebox_override(
		"normal", _make_app_button_style(Palette.APP_BUTTON_BACKGROUND)
	)
	button.add_theme_stylebox_override(
		"hover", _make_app_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_app_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED)
	)
	button.add_theme_stylebox_override(
		"focus", _make_app_button_style(Palette.APP_BUTTON_BACKGROUND)
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
	open_window("Commandes", COMMISSIONS_APP_SCENE.instantiate())


func _open_dev_console() -> void:
	open_window("Console dev", DEV_CONSOLE_SCENE.instantiate())


func _on_commission_reminder(commission_id: String, hours_remaining: int) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	var title := str(commission.get("titre", commission_id))
	_show_notification("Rappel : %s — %d h restantes" % [title, hours_remaining])


func _on_commission_completed(commission_id: String) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	var title := str(commission.get("title", commission_id))
	_show_notification("Commande terminée : %s" % title)


func _on_commission_failed(commission_id: String) -> void:
	var commission := CommissionManager.get_commission(commission_id)
	_show_notification("Commande échouée : %s" % str(commission.get("titre", commission_id)))


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
