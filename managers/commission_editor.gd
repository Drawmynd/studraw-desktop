extends Node

const DEFAULT_DRAFT_PATH := "user://pending_commissions.json"
const LEGACY_TYPE_DURATIONS := {
	"illustration": 2880,
	"affiche": 1440,
	"croquis": 120,
}
const CLIENT_PREFIX := "cli"
const TYPE_PREFIX := "typ"
const COMMISSION_PREFIX := "comm"
const MIN_DURATION_MINUTES := 1
const FALLBACK_TYPE_DURATION := 60
const UNKNOWN_CLIENT_NAME := "Sans client"
const UNKNOWN_TYPE_NAME := "autre"

var auth_manager: Node
var sync_manager: Node
var draft_path: String = DEFAULT_DRAFT_PATH

var document: Dictionary = {}


func _ready() -> void:
	_resolve_dependencies()


func _resolve_dependencies() -> void:
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")
	if sync_manager == null:
		sync_manager = get_node_or_null("/root/SyncManager")


func can_publish() -> bool:
	return auth_manager != null and auth_manager.is_dev_session()


func load_document() -> Dictionary:
	if FileAccess.file_exists(draft_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(draft_path))
		if not (parsed is Dictionary) or not (parsed.get("commissions") is Array):
			return {"ok": false, "error": "Brouillon illisible : chargement refusé.", "document": {}}
		document = _normalize(parsed)
		return {"ok": true, "error": "", "document": document}
	if sync_manager == null:
		return {"ok": false, "error": "Source de synchronisation indisponible.", "document": {}}
	var source := _read_source(str(sync_manager.local_path))
	if not bool(source.get("ok", false)):
		return {"ok": false, "error": str(source.get("error", "")), "document": {}}
	document = _migrate(source["payload"])
	return {"ok": true, "error": "", "document": document}


func add_client(name: String, email: String) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var clean := name.strip_edges()
	if clean == "":
		return {"ok": false, "error": "Le nom du client est obligatoire."}
	if not _find_by_name(document["clients"], clean).is_empty():
		return {"ok": false, "error": "Ce client existe déjà."}
	var client := {
		"id": _next_id(document["clients"], CLIENT_PREFIX),
		"name": clean,
		"email": email.strip_edges(),
	}
	document["clients"].append(client)
	_save_draft()
	return {"ok": true, "error": "", "id": str(client["id"])}


func update_client(client_id: String, name: String, email: String) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var client := _find_by_id(document["clients"], client_id)
	if client.is_empty():
		return {"ok": false, "error": "Client introuvable."}
	var clean := name.strip_edges()
	if clean == "":
		return {"ok": false, "error": "Le nom du client est obligatoire."}
	var duplicate := _find_by_name(document["clients"], clean)
	if not duplicate.is_empty() and str(duplicate["id"]) != client_id:
		return {"ok": false, "error": "Ce client existe déjà."}
	client["name"] = clean
	client["email"] = email.strip_edges()
	_rename_commission_clients(client_id, client)
	_save_draft()
	return {"ok": true, "error": "", "id": client_id}


func remove_client(client_id: String) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	if _client_in_use(client_id):
		return {"ok": false, "error": "Client utilisé par une commande."}
	if not _remove_by_id(document["clients"], client_id):
		return {"ok": false, "error": "Client introuvable."}
	_save_draft()
	return {"ok": true, "error": ""}


func add_type(name: String, duration_minutes) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var clean := name.strip_edges()
	if clean == "":
		return {"ok": false, "error": "Le nom du type est obligatoire."}
	if not _find_by_name(document["types"], clean).is_empty():
		return {"ok": false, "error": "Ce type existe déjà."}
	var duration = _parse_duration(duration_minutes)
	if duration == null or int(duration) < MIN_DURATION_MINUTES:
		return {"ok": false, "error": "La durée doit être un nombre de minutes positif."}
	var element := {
		"id": _next_id(document["types"], TYPE_PREFIX),
		"name": clean,
		"duration_minutes": int(duration),
	}
	document["types"].append(element)
	_save_draft()
	return {"ok": true, "error": "", "id": str(element["id"])}


func update_type(type_id: String, name: String, duration_minutes) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var element := _find_by_id(document["types"], type_id)
	if element.is_empty():
		return {"ok": false, "error": "Type introuvable."}
	var clean := name.strip_edges()
	if clean == "":
		return {"ok": false, "error": "Le nom du type est obligatoire."}
	var duplicate := _find_by_name(document["types"], clean)
	if not duplicate.is_empty() and str(duplicate["id"]) != type_id:
		return {"ok": false, "error": "Ce type existe déjà."}
	var duration = _parse_duration(duration_minutes)
	if duration == null or int(duration) < MIN_DURATION_MINUTES:
		return {"ok": false, "error": "La durée doit être un nombre de minutes positif."}
	element["name"] = clean
	element["duration_minutes"] = int(duration)
	_rename_commission_types(type_id, element)
	_save_draft()
	return {"ok": true, "error": "", "id": type_id}


func remove_type(type_id: String) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	if _type_in_use(type_id):
		return {"ok": false, "error": "Type utilisé par une commande."}
	if not _remove_by_id(document["types"], type_id):
		return {"ok": false, "error": "Type introuvable."}
	_save_draft()
	return {"ok": true, "error": ""}


func add_commission(form: Dictionary) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var built := _build_commission(form)
	if not bool(built.get("ok", false)):
		return built
	var commission: Dictionary = built["commission"]
	commission["id"] = _next_commission_id()
	document["commissions"].append(commission)
	_save_draft()
	return {"ok": true, "error": "", "id": str(commission["id"])}


func update_commission(commission_id: String, form: Dictionary) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var existing := _find_by_id(document["commissions"], commission_id)
	if existing.is_empty():
		return {"ok": false, "error": "Commande introuvable."}
	var built := _build_commission(form)
	if not bool(built.get("ok", false)):
		return built
	var commission: Dictionary = built["commission"]
	commission["id"] = commission_id
	for index in document["commissions"].size():
		if str(document["commissions"][index].get("id", "")) == commission_id:
			document["commissions"][index] = commission
			break
	_save_draft()
	return {"ok": true, "error": "", "id": commission_id}


func remove_commission(commission_id: String) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	if not _remove_by_id(document["commissions"], commission_id):
		return {"ok": false, "error": "Commande introuvable."}
	_save_draft()
	return {"ok": true, "error": ""}


func validate_document() -> String:
	for client in document["clients"]:
		if str(client.get("name", "")).strip_edges() == "":
			return "Un client n'a pas de nom."
	for element in document["types"]:
		if str(element.get("name", "")).strip_edges() == "":
			return "Un type n'a pas de nom."
		if _to_int(element.get("duration_minutes")) < MIN_DURATION_MINUTES:
			return "Un type n'a pas de durée valide."
	for commission in document["commissions"]:
		if str(commission.get("title", "")).strip_edges() == "":
			return "Une commande n'a pas de titre."
		if str(commission.get("mail_request", "")).strip_edges() == "":
			return "Une commande n'a pas de message de demande."
		if _find_by_id(document["clients"], str(commission.get("client_id", ""))).is_empty():
			return "Une commande référence un client inconnu."
		if _find_by_id(document["types"], str(commission.get("type_id", ""))).is_empty():
			return "Une commande référence un type inconnu."
	return ""


func push(now: int = -1) -> Dictionary:
	var guard := _guard()
	if guard != "":
		return {"ok": false, "error": guard}
	var error := validate_document()
	if error != "":
		return {"ok": false, "error": error}
	if sync_manager == null:
		return {"ok": false, "error": "Source de synchronisation indisponible."}
	var path := str(sync_manager.local_path)
	if path == "":
		return {"ok": false, "error": "Source de synchronisation non configurée."}
	var source := _read_source(path)
	if not bool(source.get("ok", false)):
		return source
	var payload: Dictionary = source["payload"]
	payload["clients"] = document["clients"].duplicate(true)
	payload["types"] = document["types"].duplicate(true)
	payload["commissions"] = document["commissions"].duplicate(true)
	payload["version"] = _to_int(payload.get("version")) + 1
	payload["updated_at"] = _now() if now < 0 else now
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Écriture impossible dans la source."}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_save_draft()
	return {"ok": true, "error": "", "version": int(payload["version"])}


func _guard() -> String:
	if not can_publish():
		return "Session administrateur requise."
	if document.is_empty():
		return "Aucun document chargé."
	return ""


func _read_source(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "payload": {"version": 0, "updated_at": 0, "commissions": []}}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed.get("commissions") is Array):
		return {"ok": false, "error": "Source illisible : écriture refusée."}
	return {"ok": true, "payload": parsed}


func _normalize(parsed: Dictionary) -> Dictionary:
	var result := {"clients": [], "types": [], "commissions": []}
	for key in ["clients", "types", "commissions"]:
		if not (parsed.get(key) is Array):
			continue
		for entry in parsed[key]:
			if entry is Dictionary:
				result[key].append(entry.duplicate(true))
	return result


func _migrate(payload: Dictionary) -> Dictionary:
	document = {"clients": [], "types": [], "commissions": []}
	if payload.get("clients") is Array:
		for entry in payload["clients"]:
			if entry is Dictionary and str(entry.get("id", "")) != "":
				document["clients"].append(entry.duplicate(true))
	if payload.get("types") is Array:
		for entry in payload["types"]:
			if entry is Dictionary and str(entry.get("id", "")) != "":
				document["types"].append(entry.duplicate(true))
	if payload.get("commissions") is Array:
		for entry in payload["commissions"]:
			if not (entry is Dictionary):
				continue
			var commission: Dictionary = entry.duplicate(true)
			var client_id := str(commission.get("client_id", ""))
			if _find_by_id(document["clients"], client_id).is_empty():
				client_id = _ensure_client(
					str(commission.get("client", "")), str(commission.get("sender", ""))
				)
			commission["client_id"] = client_id
			var type_id := str(commission.get("type_id", ""))
			if _find_by_id(document["types"], type_id).is_empty():
				type_id = _ensure_type(
					str(commission.get("type", "")), _to_int(commission.get("duration"))
				)
			commission["type_id"] = type_id
			if str(commission.get("id", "")) == "":
				commission["id"] = _next_commission_id()
			document["commissions"].append(commission)
	return document


func _ensure_client(name: String, email: String) -> String:
	var clean := name.strip_edges()
	if clean == "":
		clean = UNKNOWN_CLIENT_NAME
	var existing := _find_by_name(document["clients"], clean)
	if not existing.is_empty():
		return str(existing["id"])
	var client := {"id": _next_id(document["clients"], CLIENT_PREFIX), "name": clean, "email": email}
	document["clients"].append(client)
	return str(client["id"])


func _ensure_type(name: String, duration_hint: int) -> String:
	var clean := name.strip_edges()
	if clean == "":
		clean = UNKNOWN_TYPE_NAME
	var existing := _find_by_name(document["types"], clean)
	if not existing.is_empty():
		return str(existing["id"])
	var duration := int(LEGACY_TYPE_DURATIONS.get(clean, 0))
	if duration < MIN_DURATION_MINUTES:
		duration = duration_hint if duration_hint >= MIN_DURATION_MINUTES else FALLBACK_TYPE_DURATION
	var element := {
		"id": _next_id(document["types"], TYPE_PREFIX),
		"name": clean,
		"duration_minutes": duration,
	}
	document["types"].append(element)
	return str(element["id"])


func _build_commission(form: Dictionary) -> Dictionary:
	var title := str(form.get("title", "")).strip_edges()
	if title == "":
		return {"ok": false, "error": "Le titre est obligatoire."}
	if str(form.get("mail_request", "")).strip_edges() == "":
		return {"ok": false, "error": "Le message de demande est obligatoire."}
	var client := _find_by_id(document["clients"], str(form.get("client_id", "")))
	if client.is_empty():
		return {"ok": false, "error": "Le client est obligatoire."}
	var element := _find_by_id(document["types"], str(form.get("type_id", "")))
	if element.is_empty():
		return {"ok": false, "error": "Le type est obligatoire."}
	var duration = _parse_duration(form.get("duration", null))
	if duration == null:
		duration = _to_int(element.get("duration_minutes"))
	if int(duration) < MIN_DURATION_MINUTES:
		return {"ok": false, "error": "La durée doit être un nombre de minutes positif."}
	return {
		"ok": true,
		"error": "",
		"commission": {
			"id": "",
			"title": title,
			"type": str(element["name"]),
			"type_id": str(element["id"]),
			"duration": int(duration),
			"client": str(client["name"]),
			"client_id": str(client["id"]),
			"sender": str(client.get("email", "")),
			"description": str(form.get("description", "")).strip_edges(),
			"mail_request": str(form.get("mail_request", "")),
			"mail_success": str(form.get("mail_success", "")),
			"mail_failure": str(form.get("mail_failure", "")),
		},
	}


func _rename_commission_clients(client_id: String, client: Dictionary) -> void:
	for commission in document["commissions"]:
		if str(commission.get("client_id", "")) != client_id:
			continue
		commission["client"] = str(client["name"])
		commission["sender"] = str(client.get("email", ""))


func _rename_commission_types(type_id: String, element: Dictionary) -> void:
	for commission in document["commissions"]:
		if str(commission.get("type_id", "")) != type_id:
			continue
		commission["type"] = str(element["name"])


func _client_in_use(client_id: String) -> bool:
	for commission in document["commissions"]:
		if str(commission.get("client_id", "")) == client_id:
			return true
	return false


func _type_in_use(type_id: String) -> bool:
	for commission in document["commissions"]:
		if str(commission.get("type_id", "")) == type_id:
			return true
	return false


func _find_by_id(elements: Array, element_id: String) -> Dictionary:
	if element_id == "":
		return {}
	for element in elements:
		if str(element.get("id", "")) == element_id:
			return element
	return {}


func _find_by_name(elements: Array, name: String) -> Dictionary:
	var clean := name.strip_edges().to_lower()
	if clean == "":
		return {}
	for element in elements:
		if str(element.get("name", "")).strip_edges().to_lower() == clean:
			return element
	return {}


func _remove_by_id(elements: Array, element_id: String) -> bool:
	for index in elements.size():
		if str(elements[index].get("id", "")) == element_id:
			elements.remove_at(index)
			return true
	return false


func _next_id(elements: Array, prefix: String, width: int = 3) -> String:
	var highest := 0
	for element in elements:
		var identifier := str(element.get("id", ""))
		if not identifier.begins_with("%s-" % prefix):
			continue
		var suffix := identifier.trim_prefix("%s-" % prefix)
		if suffix.is_valid_int():
			highest = maxi(highest, int(suffix))
	return "%s-%s" % [prefix, str(highest + 1).pad_zeros(width)]


func _next_commission_id() -> String:
	var year := int(Time.get_datetime_dict_from_unix_time(_now()).get("year", 0))
	return _next_id(document["commissions"], "%s-%d" % [COMMISSION_PREFIX, year])


func _to_int(value, fallback: int = 0) -> int:
	if value == null:
		return fallback
	if value is int or value is float:
		return int(value)
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	return fallback


func _parse_duration(raw):
	if raw == null:
		return null
	var text := str(raw).strip_edges()
	if text == "":
		return null
	if not text.is_valid_int():
		return -1
	return int(text)


func _save_draft() -> void:
	var file := FileAccess.open(draft_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"clients": document["clients"],
		"types": document["types"],
		"commissions": document["commissions"],
	}, "\t"))
	file.close()


func _now() -> int:
	return int(Time.get_unix_time_from_system())
