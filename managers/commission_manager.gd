extends Node

signal commissions_changed
signal commission_accepted(commission_id: String)
signal commission_refused(commission_id: String)
signal commission_completed(commission_id: String)
signal commission_failed(commission_id: String)
signal commission_reminder(commission_id: String, hours_remaining: int)

const DEFAULT_SAVE_PATH := "user://save.json"
const STATUS_ACTIVE := "active"
const STATUS_SUCCESS := "success"
const STATUS_FAILED := "failed"
const SECONDS_PER_MINUTE := 60
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_DAY := 86400
const TYPE_DURATIONS_MINUTES := {
	"illustration": 2880,
	"affiche": 1440,
	"croquis": 120,
}

var save_path: String = DEFAULT_SAVE_PATH
var mail_manager: Node
var clock_manager: Node

var _commissions: Array[Dictionary] = []
var _refused: Array[String] = []
var _seen: Array[String] = []
var _definitions: Dictionary = {}


func _ready() -> void:
	_resolve_dependencies()
	load_state()
	if clock_manager != null and clock_manager.has_signal("minute_tick"):
		clock_manager.minute_tick.connect(_on_minute_tick)


func _resolve_dependencies() -> void:
	if mail_manager == null:
		mail_manager = get_node_or_null("/root/MailManager")
	if clock_manager == null:
		clock_manager = get_node_or_null("/root/ClockManager")


func accept(commission: Dictionary, now: int = -1) -> String:
	var definition := _normalize_commission(commission)
	var commission_id := str(definition["id"])
	if commission_id == "":
		commission_id = str(Time.get_ticks_usec())
	definition["id"] = commission_id
	_definitions[commission_id] = definition.duplicate(true)
	if not _find_state(commission_id).is_empty():
		return commission_id
	_refused.erase(commission_id)
	var accepted_at := _now() if now < 0 else now
	var duration_minutes := _resolve_duration_minutes(definition)
	var state := {
		"id": commission_id,
		"status": STATUS_ACTIVE,
		"accepted_at": accepted_at,
		"deadline": accepted_at + duration_minutes * SECONDS_PER_MINUTE,
		"reminded_24": false,
		"reminded_1": false,
		"title": str(definition["title"]),
		"type": str(definition["type"]),
		"duration": definition["duration"],
		"duration_minutes": duration_minutes,
		"client": str(definition["client"]),
		"sender": str(definition["sender"]),
		"description": str(definition["description"]),
		"mail_request": str(definition["mail_request"]),
		"mail_success": str(definition["mail_success"]),
		"mail_failure": str(definition["mail_failure"]),
	}
	_commissions.append(state)
	save_state()
	commissions_changed.emit()
	commission_accepted.emit(commission_id)
	return commission_id


func refuse(commission_id: String) -> void:
	if commission_id == "" or _refused.has(commission_id):
		return
	_refused.append(commission_id)
	save_state()
	commissions_changed.emit()
	commission_refused.emit(commission_id)


func clear_all() -> void:
	_commissions.clear()
	_refused.clear()
	_seen.clear()
	_definitions.clear()
	save_state()
	commissions_changed.emit()


func complete(commission_id: String) -> void:
	var state := _find_state(commission_id)
	if state.is_empty() or str(state["status"]) != STATUS_ACTIVE:
		return
	state["status"] = STATUS_SUCCESS
	save_state()
	commissions_changed.emit()
	commission_completed.emit(commission_id)
	var title := str(state["title"])
	var body := str(state.get("mail_success", ""))
	if body == "":
		body = "Votre commande « %s » est terminée." % title
	_send_mail("succes_%s" % commission_id, _mail_sender(state), "Succès : %s" % title, body)


func check_deadlines(now: int = -1) -> void:
	var current_time := _now() if now < 0 else now
	var changed := false
	for state in _commissions:
		if str(state["status"]) != STATUS_ACTIVE:
			continue
		var commission_id := str(state["id"])
		var remaining := int(state["deadline"]) - current_time
		if remaining <= 0:
			state["status"] = STATUS_FAILED
			changed = true
			commission_failed.emit(commission_id)
			var fail_body := str(state.get("mail_failure", ""))
			if fail_body == "":
				fail_body = "Le délai de la commande « %s » est dépassé." % str(state["title"])
			_send_mail(
				"echec_%s" % commission_id,
				_mail_sender(state),
				"Échec : %s" % str(state["title"]),
				fail_body
			)
		elif remaining <= SECONDS_PER_HOUR:
			if not bool(state["reminded_1"]):
				state["reminded_1"] = true
				state["reminded_24"] = true
				changed = true
				commission_reminder.emit(commission_id, 1)
				_send_mail(
					"rappel_1_%s" % commission_id,
					_mail_sender(state),
					"Rappel : %s" % str(state["title"]),
					"Il reste moins d'une heure pour terminer « %s »." % str(state["title"])
				)
		elif remaining <= SECONDS_PER_DAY:
			if not bool(state["reminded_24"]):
				state["reminded_24"] = true
				changed = true
				commission_reminder.emit(commission_id, 24)
				_send_mail(
					"rappel_24_%s" % commission_id,
					_mail_sender(state),
					"Rappel : %s" % str(state["title"]),
					"Il reste moins de 24 heures pour terminer « %s »." % str(state["title"])
				)
	if changed:
		save_state()
		commissions_changed.emit()


func get_commission(commission_id: String) -> Dictionary:
	var state := _find_state(commission_id)
	if not state.is_empty():
		return state.duplicate(true)
	if _definitions.has(commission_id):
		return _definitions[commission_id].duplicate(true)
	return {}


func get_active_commissions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in _commissions:
		if str(state["status"]) == STATUS_ACTIVE:
			result.append(state.duplicate(true))
	result.sort_custom(_sort_by_deadline)
	return result


func get_all_commissions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in _commissions:
		result.append(state.duplicate(true))
	result.sort_custom(_sort_by_deadline)
	return result


func is_refused(commission_id: String) -> bool:
	return _refused.has(commission_id)


func has_open_offer(commission: Dictionary) -> bool:
	var commission_id := str(commission.get("id", ""))
	return not _find_state(commission_id).is_empty() or _refused.has(commission_id)


func get_duration_minutes(commission: Dictionary) -> int:
	return _resolve_duration_minutes(_normalize_commission(commission))


func load_state() -> void:
	_commissions.clear()
	_refused.clear()
	_seen.clear()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	if parsed.get("commissions") is Array:
		for entry in parsed["commissions"]:
			if entry is Dictionary:
				_commissions.append(_normalize_state(entry))
	if parsed.get("refused") is Array:
		for entry in parsed["refused"]:
			_refused.append(str(entry))
	if parsed.get("seen_commissions") is Array:
		for entry in parsed["seen_commissions"]:
			_seen.append(str(entry))


func save_state() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var existing := FileAccess.open(save_path, FileAccess.READ)
		if existing != null:
			var parsed = JSON.parse_string(existing.get_as_text())
			existing.close()
			if parsed is Dictionary:
				data = parsed
	data["commissions"] = _commissions
	data["refused"] = _refused
	data["seen_commissions"] = _seen
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func create_offer(commission: Dictionary) -> bool:
	var definition := _normalize_commission(commission)
	var commission_id := str(definition["id"])
	if commission_id == "":
		return false
	if _seen.has(commission_id) or not _find_state(commission_id).is_empty():
		return false
	if _refused.has(commission_id):
		return false
	_seen.append(commission_id)
	_definitions[commission_id] = definition.duplicate(true)
	save_state()
	if mail_manager == null:
		return true
	mail_manager.add_mail({
		"id": _offer_mail_id(commission_id),
		"sender": _mail_sender(definition),
		"subject": "Nouvelle commande : %s" % str(definition["title"]),
		"body": str(definition["mail_request"]),
		"received_at": _now(),
		"type": "commission_offer",
		"commission": definition.duplicate(true),
	})
	return true


func refresh_offer(commission: Dictionary) -> bool:
	var definition := _normalize_commission(commission)
	var commission_id := str(definition["id"])
	if commission_id == "" or mail_manager == null:
		return false
	if not _seen.has(commission_id):
		return false
	if not _find_state(commission_id).is_empty() or _refused.has(commission_id):
		return false
	var mail_id := _offer_mail_id(commission_id)
	var mail: Dictionary = mail_manager.get_mail(mail_id)
	if mail.is_empty() or bool(mail.get("archived", false)):
		return false
	_definitions[commission_id] = definition.duplicate(true)
	save_state()
	mail_manager.update_mail(mail_id, {
		"sender": _mail_sender(definition),
		"subject": "Nouvelle commande : %s" % str(definition["title"]),
		"body": str(definition["mail_request"]),
		"commission": definition.duplicate(true),
	})
	return true


func has_seen(commission_id: String) -> bool:
	return _seen.has(commission_id)


func _on_minute_tick() -> void:
	check_deadlines()


func _find_state(commission_id: String) -> Dictionary:
	for state in _commissions:
		if str(state["id"]) == commission_id:
			return state
	return {}


func _send_mail(mail_id: String, sender: String, subject: String, body: String) -> void:
	if mail_manager == null:
		return
	mail_manager.add_mail({
		"id": mail_id,
		"sender": sender,
		"subject": subject,
		"body": body,
		"received_at": _now(),
	})


func _offer_mail_id(commission_id: String) -> String:
	return "offre_%s" % commission_id


func _mail_sender(commission: Dictionary) -> String:
	var sender := str(commission.get("sender", ""))
	if sender != "":
		return sender
	var client := str(commission.get("client", ""))
	if client != "":
		return client
	return "Studio Studraw"


func _resolve_duration_minutes(commission: Dictionary) -> int:
	var override = commission.get("duration", null)
	if override != null:
		return int(override)
	var type := str(commission.get("type", ""))
	if TYPE_DURATIONS_MINUTES.has(type):
		return int(TYPE_DURATIONS_MINUTES[type])
	return 0


func _now() -> int:
	if clock_manager != null and clock_manager.has_method("get_unix_time"):
		return int(clock_manager.get_unix_time())
	return int(Time.get_unix_time_from_system())


func _normalize_commission(entry: Dictionary) -> Dictionary:
	return {
		"id": str(entry.get("id", "")),
		"title": str(entry.get("title", "")),
		"type": str(entry.get("type", "")),
		"duration": entry.get("duration", null),
		"client": str(entry.get("client", "")),
		"sender": str(entry.get("sender", "")),
		"description": str(entry.get("description", "")),
		"mail_request": str(entry.get("mail_request", "")),
		"mail_success": str(entry.get("mail_success", "")),
		"mail_failure": str(entry.get("mail_failure", "")),
	}


func _normalize_state(entry: Dictionary) -> Dictionary:
	return {
		"id": str(entry.get("id", "")),
		"status": str(entry.get("status", STATUS_ACTIVE)),
		"accepted_at": int(entry.get("accepted_at", 0)),
		"deadline": int(entry.get("deadline", 0)),
		"reminded_24": bool(entry.get("reminded_24", false)),
		"reminded_1": bool(entry.get("reminded_1", false)),
		"title": str(entry.get("title", "")),
		"type": str(entry.get("type", "")),
		"duration": entry.get("duration", null),
		"duration_minutes": int(entry.get("duration_minutes", 0)),
		"client": str(entry.get("client", "")),
		"sender": str(entry.get("sender", "")),
		"description": str(entry.get("description", "")),
		"mail_request": str(entry.get("mail_request", "")),
		"mail_success": str(entry.get("mail_success", "")),
		"mail_failure": str(entry.get("mail_failure", "")),
	}


func _sort_by_deadline(a: Dictionary, b: Dictionary) -> bool:
	return int(a["deadline"]) < int(b["deadline"])
