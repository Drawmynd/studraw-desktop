extends Control

@onready var panel: PanelContainer = %Panel
@onready var path_label: Label = %PathLabel
@onready var refresh_button: Button = %RefreshButton
@onready var content: RichTextLabel = %Content

@export_group("Couleurs")
@export var panel_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE
@export var path_text_color: PaletteData.Colors = PaletteData.Colors.TEXT_MUTED
@export var content_text_color: PaletteData.Colors = PaletteData.Colors.TEXT
@export var button_background_color: PaletteData.Colors = PaletteData.Colors.SURFACE_RAISED
@export var button_hover_color: PaletteData.Colors = PaletteData.Colors.HOVER
@export var button_pressed_color: PaletteData.Colors = PaletteData.Colors.PRESSED
@export var button_text_color: PaletteData.Colors = PaletteData.Colors.TEXT

var file_path: String = ""


func setup(target_path: String) -> void:
	file_path = target_path
	if is_node_ready():
		_refresh()


func _ready() -> void:
	_apply_palette()
	refresh_button.pressed.connect(_refresh)
	_refresh()


func _apply_palette() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.color(panel_background_color)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	path_label.add_theme_color_override("font_color", Palette.color(path_text_color))
	content.add_theme_color_override("default_color", Palette.color(content_text_color))
	refresh_button.add_theme_color_override("font_color", Palette.color(button_text_color))
	refresh_button.add_theme_color_override("font_hover_color", Palette.color(button_text_color))
	refresh_button.add_theme_color_override("font_pressed_color", Palette.color(button_text_color))
	refresh_button.add_theme_color_override("font_focus_color", Palette.color(button_text_color))
	refresh_button.add_theme_stylebox_override(
		"normal", _make_button_style(Palette.color(button_background_color))
	)
	refresh_button.add_theme_stylebox_override(
		"hover", _make_button_style(Palette.color(button_hover_color))
	)
	refresh_button.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.color(button_pressed_color))
	)
	refresh_button.add_theme_stylebox_override(
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


func _refresh() -> void:
	if file_path == "":
		path_label.text = "Aucun fichier local configuré."
		content.text = ""
		return
	path_label.text = file_path
	if not FileAccess.file_exists(file_path):
		content.text = "Fichier introuvable."
		return
	content.text = FileAccess.get_file_as_string(file_path)
