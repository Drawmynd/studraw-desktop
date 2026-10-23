extends Node

signal mails_changed

const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String = DEFAULT_SAVE_PATH

var _mails: Array[Dictionary] = []


func _ready() -> void:
	load_state()


func load_state() -> void:
	_mails.clear()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or not (parsed.get("mails") is Array):
		return
	for entry in parsed["mails"]:
		if entry is Dictionary:
			_mails.append(_normalize_mail(entry))


func ensure_welcome_mail() -> void:
	if not get_mail("bienvenue").is_empty():
		return
	_mails.append({
		"id": "bienvenue",
		"sender": "Studio Studraw",
		"subject": "Bienvenue dans votre atelier",
		"body": "Bonjour,\n\nVotre atelier est prêt. Les commandes arriveront ici, dans votre boîte de réception.\n\nBonne création !",
		"received_at": int(Time.get_unix_time_from_system()),
		"read": false,
		"archived": false,
	})
	save_state()
	mails_changed.emit()


func clear_all() -> void:
	_mails.clear()
	save_state()
	mails_changed.emit()


func get_mails(include_archived: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mail in _mails:
		if include_archived or not bool(mail["archived"]):
			result.append(mail.duplicate(true))
	result.sort_custom(_sort_by_received_at)
	return result


func get_mail(id: String) -> Dictionary:
	for mail in _mails:
		if mail["id"] == id:
			return mail.duplicate(true)
	return {}


func get_unread_count() -> int:
	var count := 0
	for mail in _mails:
		if not bool(mail["archived"]) and not bool(mail["read"]):
			count += 1
	return count


func add_mail(mail: Dictionary) -> void:
	var normalized := _normalize_mail(mail)
	if normalized["id"] == "":
		normalized["id"] = str(Time.get_ticks_usec())
	_mails.append(normalized)
	save_state()
	mails_changed.emit()


func update_mail(id: String, changes: Dictionary) -> void:
	for index in _mails.size():
		if _mails[index]["id"] != id:
			continue
		var updated := _mails[index].duplicate(true)
		updated.merge(changes, true)
		var normalized := _normalize_mail(updated)
		if normalized == _mails[index]:
			return
		_mails[index] = normalized
		save_state()
		mails_changed.emit()
		return


func mark_read(id: String) -> void:
	for mail in _mails:
		if mail["id"] != id:
			continue
		if bool(mail["read"]):
			return
		mail["read"] = true
		save_state()
		mails_changed.emit()
		return


func archive_mail(id: String) -> void:
	for mail in _mails:
		if mail["id"] != id:
			continue
		if bool(mail["archived"]):
			return
		mail["archived"] = true
		save_state()
		mails_changed.emit()
		return


func save_state() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var existing := FileAccess.open(save_path, FileAccess.READ)
		if existing != null:
			var parsed = JSON.parse_string(existing.get_as_text())
			existing.close()
			if parsed is Dictionary:
				data = parsed
	data["mails"] = _mails
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _normalize_mail(entry: Dictionary) -> Dictionary:
	var commission: Dictionary = {}
	if entry.get("commission") is Dictionary:
		commission = entry["commission"].duplicate(true)
	return {
		"id": str(entry.get("id", "")),
		"sender": str(entry.get("sender", entry.get("from", ""))),
		"subject": str(entry.get("subject", "")),
		"body": str(entry.get("body", "")),
		"received_at": int(entry.get("received_at", 0)),
		"read": bool(entry.get("read", false)),
		"archived": bool(entry.get("archived", false)),
		"type": str(entry.get("type", "info")),
		"commission": commission,
	}


func _sort_by_received_at(a: Dictionary, b: Dictionary) -> bool:
	return int(a["received_at"]) > int(b["received_at"])
