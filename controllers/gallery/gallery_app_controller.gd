extends Control

const TILE_SIZE := Vector2(160, 160)
const GRID_COLUMNS := 3

@onready var list_panel: PanelContainer = %ListPanel
@onready var viewer_panel: PanelContainer = %ViewerPanel
@onready var header_label: Label = %HeaderLabel
@onready var view_toggle: Button = %ViewToggle
@onready var empty_label: Label = %EmptyLabel
@onready var grid_scroll: ScrollContainer = %GridScroll
@onready var grid: GridContainer = %Grid
@onready var list_scroll: ScrollContainer = %ListScroll
@onready var gallery_list: ItemList = %GalleryList
@onready var viewer_title: Label = %ViewerTitle
@onready var viewer_meta: Label = %ViewerMeta
@onready var viewer_frame: PanelContainer = %ViewerFrame
@onready var viewer: TextureRect = %Viewer
@onready var missing_label: Label = %MissingLabel

var commission_manager: Node
var delivery_manager: Node

var _entries: Array[Dictionary] = []
var _selected_id: String = ""
var _list_refreshing: bool = false


func _ready() -> void:
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")
	if delivery_manager == null:
		delivery_manager = get_node_or_null("/root/DeliveryManager")
	_apply_palette()
	grid.columns = GRID_COLUMNS
	view_toggle.toggled.connect(_on_view_toggled)
	gallery_list.item_selected.connect(_on_list_selected)
	if commission_manager != null and commission_manager.has_signal("commissions_changed"):
		commission_manager.commissions_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_list_refreshing = true
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	gallery_list.clear()
	_entries = []
	if delivery_manager != null:
		_entries = delivery_manager.get_deliveries()
	for entry in _entries:
		grid.add_child(_make_tile(entry))
		var index := gallery_list.add_item(_entry_label(entry))
		gallery_list.set_item_metadata(index, entry["id"])
	_list_refreshing = false
	empty_label.visible = _entries.is_empty()
	var selected_exists := not _find_entry(_selected_id).is_empty()
	if not selected_exists:
		_selected_id = str(_entries[0]["id"]) if not _entries.is_empty() else ""
	if _selected_id == "":
		_show_empty()
		return
	_select(_selected_id)


func _make_tile(entry: Dictionary) -> Control:
	var tile: BaseButton
	var texture: ImageTexture
	if bool(entry["exists"]):
		texture = delivery_manager.load_texture(str(entry["path"]))
	if texture != null:
		var image_button := TextureButton.new()
		image_button.texture_normal = texture
		image_button.ignore_texture_size = true
		image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tile = image_button
	else:
		var fallback := Button.new()
		fallback.text = "Image introuvable"
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_button(fallback)
		tile = fallback
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = str(entry["title"])
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(_on_tile_pressed.bind(str(entry["id"])))
	return tile


func _on_tile_pressed(commission_id: String) -> void:
	_select(commission_id)


func _on_list_selected(index: int) -> void:
	if _list_refreshing:
		return
	_select(str(gallery_list.get_item_metadata(index)))


func _select(commission_id: String) -> void:
	var entry := _find_entry(commission_id)
	if entry.is_empty():
		return
	_selected_id = commission_id
	viewer_title.text = str(entry["title"])
	var late := " — livré trop tard" if bool(entry["late"]) else ""
	viewer_meta.text = "Client : %s — type : %s — livrée le %s%s" % [
		str(entry["client"]),
		str(entry["type"]),
		_format_date(int(entry["delivered_at"])),
		late,
	]
	var texture: ImageTexture
	if bool(entry["exists"]):
		texture = delivery_manager.load_texture(str(entry["path"]))
	if texture == null:
		viewer.texture = null
		viewer.hide()
		missing_label.show()
	else:
		viewer.texture = texture
		viewer.show()
		missing_label.hide()
	_sync_list_selection()


func _sync_list_selection() -> void:
	for index in gallery_list.item_count:
		if str(gallery_list.get_item_metadata(index)) != _selected_id:
			continue
		var selected: PackedInt32Array = gallery_list.get_selected_items()
		if selected.size() != 1 or selected[0] != index:
			_list_refreshing = true
			gallery_list.select(index)
			_list_refreshing = false
		return


func _on_view_toggled(list_view: bool) -> void:
	grid_scroll.visible = not list_view
	list_scroll.visible = list_view
	view_toggle.text = "Vue grille" if list_view else "Vue liste"


func _show_empty() -> void:
	viewer.texture = null
	viewer.hide()
	missing_label.hide()
	viewer_title.text = "Aucune livraison"
	viewer_meta.text = "Les commandes livrées apparaîtront ici."


func _find_entry(commission_id: String) -> Dictionary:
	for entry in _entries:
		if str(entry["id"]) == commission_id:
			return entry
	return {}


func _entry_label(entry: Dictionary) -> String:
	var late := " — livré trop tard" if bool(entry["late"]) else ""
	return "%s — %s — %s%s" % [
		str(entry["title"]),
		str(entry["client"]),
		_format_date(int(entry["delivered_at"])),
		late,
	]


func _format_date(timestamp: int) -> String:
	if timestamp <= 0:
		return "—"
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%04d" % [int(date["day"]), int(date["month"]), int(date["year"])]


func _apply_palette() -> void:
	_style_panel(list_panel, Palette.MAIL_LIST_BACKGROUND)
	_style_panel(viewer_panel, Palette.MAIL_READING_BACKGROUND)
	_style_panel(viewer_frame, Palette.MAIL_LIST_BACKGROUND)
	header_label.add_theme_color_override("font_color", Palette.MAIL_HEADER_TEXT)
	viewer_title.add_theme_color_override("font_color", Palette.MAIL_HEADER_TEXT)
	viewer_meta.add_theme_color_override("font_color", Palette.MAIL_META_TEXT)
	empty_label.add_theme_color_override("font_color", Palette.MAIL_META_TEXT)
	missing_label.add_theme_color_override("font_color", Palette.MAIL_META_TEXT)
	gallery_list.add_theme_color_override("font_color", Palette.MAIL_TEXT)
	gallery_list.add_theme_color_override("font_selected_color", Palette.MAIL_HEADER_TEXT)
	gallery_list.add_theme_stylebox_override("panel", _make_style(Palette.MAIL_LIST_BACKGROUND))
	gallery_list.add_theme_stylebox_override("selected", _make_style(Palette.MAIL_SELECTED_BACKGROUND))
	gallery_list.add_theme_stylebox_override(
		"selected_focus", _make_style(Palette.MAIL_SELECTED_BACKGROUND)
	)
	_style_button(view_toggle)


func _style_panel(target: PanelContainer, background_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	target.add_theme_stylebox_override("panel", style)


func _make_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_color_override("font_focus_color", Palette.APP_BUTTON_TEXT)
	button.add_theme_stylebox_override("normal", _make_button_style(Palette.APP_BUTTON_BACKGROUND))
	button.add_theme_stylebox_override("hover", _make_button_style(Palette.APP_BUTTON_BACKGROUND_HOVER))
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(Palette.APP_BUTTON_BACKGROUND_PRESSED)
	)
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
