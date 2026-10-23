extends Control

signal pressed

const STATE_LOCAL := "local"
const STATE_REMOTE := "remote"
const STATE_ERROR := "error"
const ICON_REMOTE := "res://assets/wifi/wifi.svg"
const ICON_LOCAL := "res://assets/wifi/wifi_off.svg"
const ICON_ERROR := "res://assets/wifi/wifi_alert.svg"
const ICON_SVG_SCALE := 2.0

@export_group("Couleurs")
@export var remote_color: PaletteData.Colors = PaletteData.Colors.SUCCESS
@export var local_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var error_color: PaletteData.Colors = PaletteData.Colors.DANGER

var _state: String = STATE_LOCAL
var _textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_textures[STATE_REMOTE] = _load_icon(ICON_REMOTE)
	_textures[STATE_LOCAL] = _load_icon(ICON_LOCAL)
	_textures[STATE_ERROR] = _load_icon(ICON_ERROR)
	update_tooltip()
	queue_redraw()


func _load_icon(path: String) -> Texture2D:
	var source := FileAccess.get_file_as_string(path)
	if source == "":
		return null
	var image := Image.new()
	if image.load_svg_from_string(source, ICON_SVG_SCALE) != OK:
		return null
	return ImageTexture.create_from_image(image)


func get_state() -> String:
	return _state


func set_state(state: String) -> void:
	if state != STATE_REMOTE and state != STATE_ERROR:
		state = STATE_LOCAL
	if state == _state:
		return
	_state = state
	update_tooltip()
	queue_redraw()


func update_tooltip() -> void:
	match _state:
		STATE_REMOTE:
			tooltip_text = "Wi-Fi : distant — clic pour passer en local"
		STATE_ERROR:
			tooltip_text = "Wi-Fi : synchronisation en erreur — clic pour changer de mode"
		_:
			tooltip_text = "Wi-Fi : local (hors ligne) — clic pour passer en distant"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			pressed.emit()


func _draw() -> void:
	var texture: Texture2D = _textures.get(_state)
	if texture == null:
		return
	var side := minf(size.x, size.y)
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	draw_texture_rect(texture, Rect2(origin, Vector2(side, side)), false, _state_color())


func _state_color() -> Color:
	match _state:
		STATE_REMOTE:
			return Palette.color(remote_color)
		STATE_ERROR:
			return Palette.color(error_color)
		_:
			return Palette.color(local_color)
