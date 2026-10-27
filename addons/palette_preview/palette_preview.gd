@tool
extends EditorPlugin


func _enter_tree() -> void:
	_connect_inspector.call_deferred()


func _exit_tree() -> void:
	var inspector := get_editor_interface().get_inspector()
	if inspector != null and inspector.property_edited.is_connected(_on_property_edited):
		inspector.property_edited.disconnect(_on_property_edited)


func _connect_inspector() -> void:
	var inspector := get_editor_interface().get_inspector()
	if inspector == null or inspector.property_edited.is_connected(_on_property_edited):
		return
	inspector.property_edited.connect(_on_property_edited)


func _on_property_edited(_property: String) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root != null:
		_refresh(root)


func _refresh(node: Node) -> void:
	if node.has_method("_apply_palette"):
		node.call("_apply_palette")
	for child in node.get_children():
		_refresh(child)
