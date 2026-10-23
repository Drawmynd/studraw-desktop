extends Node

const DEFAULT_MAX_BYTES := 10 * 1024 * 1024
const ALLOWED_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const EXTENSION_LABELS := {"png": "png", "jpg": "jpg", "jpeg": "jpg", "webp": "webp"}

var max_bytes: int = DEFAULT_MAX_BYTES
var commission_manager: Node


func _ready() -> void:
	_resolve_dependencies()


func _resolve_dependencies() -> void:
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")


func deliveries_dir() -> String:
	if commission_manager == null:
		return "user://deliveries"
	return str(commission_manager.save_path).get_base_dir().path_join("deliveries")


func validate(source_path: String) -> Dictionary:
	if source_path == "" or not FileAccess.file_exists(source_path):
		return _error("Fichier introuvable.")
	var extension := source_path.get_extension().to_lower()
	if not ALLOWED_EXTENSIONS.has(extension):
		return _error("Format non pris en charge (PNG, JPG ou WebP).")
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return _error("Fichier illisible.")
	var size := int(file.get_length())
	var head := file.get_buffer(12)
	file.close()
	if size <= 0:
		return _error("Fichier illisible.")
	if size > max_bytes:
		return _error("Image trop lourde (%s maximum)." % _format_max_bytes())
	var format := _detect_format(head)
	if format == "" or format != str(EXTENSION_LABELS[extension]):
		return _error("Format non pris en charge (PNG, JPG ou WebP).")
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return _error("Image illisible.")
	return {"ok": true, "error": ""}


func deliver(commission_id: String, source_path: String, now: int = -1) -> Dictionary:
	_resolve_dependencies()
	if commission_manager == null:
		return _error("Gestionnaire de commandes indisponible.")
	var commission: Dictionary = commission_manager.get_commission(commission_id)
	if commission.is_empty():
		return _error("Commande introuvable.")
	var status := str(commission.get("status", ""))
	var current_time := int(Time.get_unix_time_from_system()) if now < 0 else now
	var expired := current_time > int(commission.get("deadline", 0))
	var validation := validate(source_path)
	if not bool(validation.get("ok", false)):
		return validation
	var target_dir := deliveries_dir().path_join(commission_id)
	_clear_directory(target_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	var target_path := target_dir.path_join(source_path.get_file())
	var bytes := FileAccess.get_file_as_bytes(source_path)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return _error("Copie impossible.")
	file.store_buffer(bytes)
	file.close()
	var delivery := {"path": target_path, "name": source_path.get_file()}
	var accepted := false
	var late := false
	if status == "active" and not expired:
		accepted = bool(commission_manager.complete(commission_id, delivery, current_time))
	else:
		if status == "active":
			commission_manager.check_deadlines(current_time)
		accepted = bool(commission_manager.record_delivery(commission_id, delivery, current_time))
		late = str(commission_manager.get_commission(commission_id).get("status", "")) == "failed"
	if not accepted:
		_remove_file(target_path)
		return _error("Livraison impossible.")
	return {"ok": true, "error": "", "path": target_path, "late": late}


func load_texture(path: String) -> ImageTexture:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func get_deliveries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_resolve_dependencies()
	if commission_manager == null:
		return result
	for commission in commission_manager.get_all_commissions():
		var path := str(commission.get("delivery_path", ""))
		if path == "":
			continue
		result.append({
			"id": str(commission["id"]),
			"title": str(commission.get("title", "")),
			"client": str(commission.get("client", "")),
			"type": str(commission.get("type", "")),
			"delivered_at": int(commission.get("delivered_at", 0)),
			"path": path,
			"name": str(commission.get("delivery_name", "")),
			"late": bool(commission.get("delivery_late", false)),
			"exists": FileAccess.file_exists(path),
			"size": _file_size(path),
		})
	result.sort_custom(_sort_by_delivered_at)
	return result


func _detect_format(head: PackedByteArray) -> String:
	if head.size() < 4:
		return ""
	if head[0] == 0x89 and head[1] == 0x50 and head[2] == 0x4e and head[3] == 0x47:
		return "png"
	if head[0] == 0xff and head[1] == 0xd8 and head[2] == 0xff:
		return "jpg"
	if head.size() >= 12:
		if (
			head[0] == 0x52
			and head[1] == 0x49
			and head[2] == 0x46
			and head[3] == 0x46
			and head[8] == 0x57
			and head[9] == 0x45
			and head[10] == 0x42
			and head[11] == 0x50
		):
			return "webp"
	return ""


func _format_max_bytes() -> String:
	var megabytes := int(max_bytes / (1024 * 1024))
	if megabytes >= 1:
		return "%d Mo" % megabytes
	return "%d Ko" % int(max_bytes / 1024)


func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := int(file.get_length())
	file.close()
	return size


func _clear_directory(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var handle := DirAccess.open(absolute)
	if handle == null:
		return
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if handle.current_is_dir():
				_clear_directory(child)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = handle.get_next()
	handle.list_dir_end()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _sort_by_delivered_at(a: Dictionary, b: Dictionary) -> bool:
	if int(a["delivered_at"]) == int(b["delivered_at"]):
		return str(a["id"]) < str(b["id"])
	return int(a["delivered_at"]) > int(b["delivered_at"])


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "path": ""}
