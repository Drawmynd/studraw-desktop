extends Node

signal session_changed(authenticated: bool, is_admin: bool)
signal profiles_changed

const DEFAULT_PROFILES_PATH := "user://profiles.json"
const DEFAULT_LEGACY_SAVE_PATH := "user://save.json"
const DEFAULT_PROFILE_SAVE_DIR := "user://profiles"
const DEFAULT_ADMIN_ID := "prof_admin"
const DEFAULT_ADMIN_PSEUDO := "admin"
const DEFAULT_ADMIN_PASSWORD := "admin"
const MIN_PASSWORD_LENGTH := 4

var profiles_path: String = DEFAULT_PROFILES_PATH
var legacy_save_path: String = DEFAULT_LEGACY_SAVE_PATH
var profile_save_dir: String = DEFAULT_PROFILE_SAVE_DIR

var _profiles: Array[Dictionary] = []
var _current_profile_id: String = ""


func _ready() -> void:
	load_state()


func load_state() -> void:
	_profiles.clear()
	var loaded_from_disk := false
	if FileAccess.file_exists(profiles_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(profiles_path))
		if parsed is Dictionary and parsed.get("profiles") is Array:
			for entry in parsed["profiles"]:
				if not (entry is Dictionary) or str(entry.get("id", "")) == "":
					continue
				_profiles.append(_normalize_profile(entry))
			loaded_from_disk = not _profiles.is_empty()
	if not loaded_from_disk:
		_seed_defaults()
		if not FileAccess.file_exists(profiles_path):
			save_state()
	for profile in _profiles:
		_ensure_profile_dir(str(profile["id"]))
	migrate_legacy_save()


func save_state() -> void:
	var payload := {"version": 1, "profiles": _profiles}
	var file := FileAccess.open(profiles_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func get_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in _profiles:
		result.append({
			"id": str(profile["id"]),
			"pseudo": str(profile["pseudo"]),
			"is_admin": bool(profile["is_admin"]),
			"created_at": int(profile["created_at"]),
			"updated_at": int(profile["updated_at"]),
		})
	result.sort_custom(_sort_profiles)
	return result


func get_profile(profile_id: String) -> Dictionary:
	var profile := _find_profile(profile_id)
	if profile.is_empty():
		return {}
	return {
		"id": str(profile["id"]),
		"pseudo": str(profile["pseudo"]),
		"is_admin": bool(profile["is_admin"]),
		"created_at": int(profile["created_at"]),
		"updated_at": int(profile["updated_at"]),
	}


func get_current_profile() -> Dictionary:
	return get_profile(_current_profile_id)


func get_profile_save_path(profile_id: String) -> String:
	return "%s/%s/save.json" % [profile_save_dir, profile_id]


func is_authenticated() -> bool:
	return _current_profile_id != ""


func is_dev_session() -> bool:
	var profile := get_current_profile()
	return not profile.is_empty() and bool(profile["is_admin"])


func verify(profile_id: String, password: String) -> bool:
	var profile := _find_profile(profile_id)
	if profile.is_empty():
		return false
	return str(profile["password_hash"]) == password.sha256_text()


func authenticate(profile_id: String, password: String) -> bool:
	if not verify(profile_id, password):
		return false
	if _current_profile_id == profile_id:
		return true
	_current_profile_id = profile_id
	session_changed.emit(true, is_dev_session())
	return true


func logout() -> void:
	if _current_profile_id == "":
		return
	_current_profile_id = ""
	session_changed.emit(false, false)


func create_profile(pseudo: String, password: String) -> Dictionary:
	var clean_pseudo := pseudo.strip_edges()
	if clean_pseudo == "":
		return _error("Pseudo requis.")
	if password.length() < MIN_PASSWORD_LENGTH:
		return _error("Mot de passe : %d caractères minimum." % MIN_PASSWORD_LENGTH)
	if _is_pseudo_taken(clean_pseudo, ""):
		return _error("Ce pseudo est déjà utilisé.")
	var now := int(Time.get_unix_time_from_system())
	var profile := {
		"id": _new_profile_id(),
		"pseudo": clean_pseudo,
		"password_hash": password.sha256_text(),
		"is_admin": false,
		"created_at": now,
		"updated_at": now,
	}
	_profiles.append(profile)
	_ensure_profile_dir(str(profile["id"]))
	save_state()
	profiles_changed.emit()
	return {"ok": true, "id": str(profile["id"]), "error": ""}


func change_credentials(
	profile_id: String, current_password: String, new_pseudo: String, new_password: String
) -> Dictionary:
	var profile := _find_profile(profile_id)
	if profile.is_empty():
		return _error("Profil introuvable.")
	if not verify(profile_id, current_password):
		return _error("Mot de passe actuel incorrect.")
	var clean_pseudo := new_pseudo.strip_edges()
	if clean_pseudo == "":
		clean_pseudo = str(profile["pseudo"])
	if _is_pseudo_taken(clean_pseudo, profile_id):
		return _error("Ce pseudo est déjà utilisé.")
	if new_password != "" and new_password.length() < MIN_PASSWORD_LENGTH:
		return _error("Mot de passe : %d caractères minimum." % MIN_PASSWORD_LENGTH)
	profile["pseudo"] = clean_pseudo
	if new_password != "":
		profile["password_hash"] = new_password.sha256_text()
	profile["updated_at"] = int(Time.get_unix_time_from_system())
	save_state()
	profiles_changed.emit()
	return {"ok": true, "id": profile_id, "error": ""}


func delete_profile(profile_id: String, password: String) -> Dictionary:
	if _find_profile(profile_id).is_empty():
		return _error("Profil introuvable.")
	if not verify(profile_id, password):
		return _error("Mot de passe incorrect.")
	var guard := _guard_last_admin(profile_id)
	if not guard["ok"]:
		return guard
	_remove_profile(profile_id)
	return {"ok": true, "id": profile_id, "error": ""}


func delete_profile_as_admin(profile_id: String, admin_password: String) -> Dictionary:
	if not is_dev_session():
		return _error("Session administrateur requise.")
	if not verify(_current_profile_id, admin_password):
		return _error("Mot de passe administrateur incorrect.")
	if _find_profile(profile_id).is_empty():
		return _error("Profil introuvable.")
	var guard := _guard_last_admin(profile_id)
	if not guard["ok"]:
		return guard
	_remove_profile(profile_id)
	return {"ok": true, "id": profile_id, "error": ""}


func migrate_legacy_save() -> void:
	for profile in _profiles:
		if not bool(profile["is_admin"]):
			continue
		var target := get_profile_save_path(str(profile["id"]))
		if FileAccess.file_exists(target) or not FileAccess.file_exists(legacy_save_path):
			return
		_copy_save(legacy_save_path, target)
		return


func _remove_profile(profile_id: String) -> void:
	for index in _profiles.size():
		if str(_profiles[index]["id"]) == profile_id:
			_profiles.remove_at(index)
			break
	_remove_save(profile_id)
	if _current_profile_id == profile_id:
		_current_profile_id = ""
		session_changed.emit(false, false)
	save_state()
	profiles_changed.emit()


func _remove_save(profile_id: String) -> void:
	var path := get_profile_save_path(profile_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _copy_save(source_path: String, target_path: String) -> void:
	var text := FileAccess.get_file_as_string(source_path)
	if text == "":
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_path.get_base_dir())
	)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _seed_defaults() -> void:
	var now := int(Time.get_unix_time_from_system())
	_profiles.append({
		"id": DEFAULT_ADMIN_ID,
		"pseudo": DEFAULT_ADMIN_PSEUDO,
		"password_hash": DEFAULT_ADMIN_PASSWORD.sha256_text(),
		"is_admin": true,
		"created_at": now,
		"updated_at": now,
	})


func _ensure_profile_dir(profile_id: String) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("%s/%s" % [profile_save_dir, profile_id])
	)


func _guard_last_admin(profile_id: String) -> Dictionary:
	var profile := _find_profile(profile_id)
	if profile.is_empty() or not bool(profile["is_admin"]):
		return {"ok": true, "id": profile_id, "error": ""}
	var admin_count := 0
	for entry in _profiles:
		if bool(entry["is_admin"]):
			admin_count += 1
	if admin_count <= 1:
		return _error("Le profil administrateur ne peut pas être supprimé.")
	return {"ok": true, "id": profile_id, "error": ""}


func _is_pseudo_taken(pseudo: String, ignored_id: String) -> bool:
	for profile in _profiles:
		if str(profile["id"]) == ignored_id:
			continue
		if str(profile["pseudo"]).to_lower() == pseudo.to_lower():
			return true
	return false


func _find_profile(profile_id: String) -> Dictionary:
	for profile in _profiles:
		if str(profile["id"]) == profile_id:
			return profile
	return {}


func _new_profile_id() -> String:
	return "prof_%d_%04x" % [int(Time.get_unix_time_from_system()), randi() & 0xffff]


func _normalize_profile(entry: Dictionary) -> Dictionary:
	return {
		"id": str(entry.get("id", "")),
		"pseudo": str(entry.get("pseudo", "")),
		"password_hash": str(entry.get("password_hash", "")),
		"is_admin": bool(entry.get("is_admin", false)),
		"created_at": int(entry.get("created_at", 0)),
		"updated_at": int(entry.get("updated_at", 0)),
	}


func _sort_profiles(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["is_admin"]) != bool(b["is_admin"]):
		return bool(a["is_admin"])
	return str(a["pseudo"]).to_lower() < str(b["pseudo"]).to_lower()


func _error(message: String) -> Dictionary:
	return {"ok": false, "id": "", "error": message}
