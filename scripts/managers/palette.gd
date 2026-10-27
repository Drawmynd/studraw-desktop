@tool
extends Node

const PALETTE_PATH := "res://theme/palette.tres"
const TASKBAR_BUTTON_MINIMIZED_ALPHA := 0.55
const TASKBAR_ALPHA := 0.92

var colors: PaletteData = PaletteData.new()
var using_fallback := false


func _ready() -> void:
	var loaded := load_from(PALETTE_PATH)
	using_fallback = loaded == null
	colors = loaded if loaded != null else PaletteData.new()
	if using_fallback:
		push_warning("Palette: %s is unavailable, using built-in defaults" % PALETTE_PATH)


func load_from(path: String) -> PaletteData:
	if not ResourceLoader.exists(path):
		return null
	var loaded := ResourceLoader.load(path)
	if loaded is PaletteData:
		return loaded
	return null


func color(entry: PaletteData.Colors) -> Color:
	return colors.get(PaletteData.Colors.keys()[entry].to_lower())


func status_color(kind: String) -> Color:
	if kind == "error":
		return colors.danger
	return colors.text_strong
