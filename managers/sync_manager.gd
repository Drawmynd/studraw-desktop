extends Node

signal sync_finished(reachable: bool, new_offers: int)
signal mode_changed(mode: String)

const DEFAULT_CONFIG_PATH := "user://sync_config.json"
const DEFAULT_CACHE_PATH := "user://commissions_cache.json"
const DEFAULT_DEV_CONFIG_PATH := "user://dev_config.json"
const DEFAULT_LOCAL_PATH := "res://data/commissions.json"
const DEFAULT_GIT_REMOTE := "origin"
const DEFAULT_GIT_BRANCH := "main"
const COMMIT_SUBJECT := "chore(data): publish commissions v%d"
const GIT_EXECUTABLE := "git"
const MODE_LOCAL := "local"
const MODE_REMOTE := "remote"
const REQUEST_TIMEOUT_SECONDS := 10.0
const SECONDS_PER_MINUTE := 60
const DEFAULT_INTERVAL_MINUTES := 30

var config_path: String = DEFAULT_CONFIG_PATH
var cache_path: String = DEFAULT_CACHE_PATH
var dev_config_path: String = DEFAULT_DEV_CONFIG_PATH
var mode: String = MODE_LOCAL
var local_path: String = DEFAULT_LOCAL_PATH
var remote_url: String = ""
var sync_interval_minutes: int = DEFAULT_INTERVAL_MINUTES
var repo_path: String = ""
var git_remote: String = DEFAULT_GIT_REMOTE
var git_branch: String = DEFAULT_GIT_BRANCH
var commission_manager: Node
var auth_manager: Node
var last_sync_at: int = 0
var last_sync_ok: bool = false
var last_sync_mode: String = ""
var force_remote_ok: bool = false

var _http_request: HTTPRequest
var _timer: Timer
var _fetch_in_flight: bool = false


func _ready() -> void:
	load_config()
	load_dev_config()
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	apply_interval(sync_interval_minutes)


func start() -> void:
	if DisplayServer.get_name() == "headless":
		return
	fetch()


func fetch() -> void:
	if _fetch_in_flight:
		return
	if mode == MODE_REMOTE:
		if remote_url == "":
			_finish(false, 0)
			return
		_fetch_remote()
		return
	_fetch_local()


func set_mode(value: String) -> void:
	var resolved := MODE_REMOTE if value == MODE_REMOTE else MODE_LOCAL
	if resolved == mode:
		return
	mode = resolved
	mode_changed.emit(mode)


func get_last_sync_text() -> String:
	if last_sync_at <= 0:
		return "—"
	var offset_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var local_unix := last_sync_at + offset_minutes * SECONDS_PER_MINUTE
	var stamp := Time.get_datetime_string_from_unix_time(local_unix, true)
	return "%s — %s" % [stamp, "succès" if last_sync_ok else "échec"]


func apply_payload(payload: Dictionary, write_cache: bool = true) -> int:
	if not (payload.get("commissions") is Array):
		return 0
	var entries: Array = []
	for entry in payload["commissions"]:
		if not (entry is Dictionary):
			continue
		if str(entry.get("id", "")) == "" or str(entry.get("title", "")) == "":
			continue
		entries.append(entry)
	if entries.is_empty():
		return 0
	var version := int(payload.get("version", 0))
	var cached := load_cache()
	var cached_version := int(cached.get("version", 0))
	if not cached.is_empty() and version < cached_version:
		return 0
	var apply_updates := cached.is_empty() or version > cached_version
	if write_cache:
		save_cache({
			"version": version,
			"updated_at": int(payload.get("updated_at", 0)),
			"commissions": entries,
		})
	if commission_manager == null:
		commission_manager = get_node_or_null("/root/CommissionManager")
	if commission_manager == null:
		return 0
	var created := 0
	for entry in entries:
		if commission_manager.create_offer(entry):
			created += 1
		elif apply_updates:
			commission_manager.refresh_offer(entry)
	return created


func load_config() -> void:
	mode = MODE_LOCAL
	local_path = DEFAULT_LOCAL_PATH
	remote_url = ""
	sync_interval_minutes = DEFAULT_INTERVAL_MINUTES
	if not FileAccess.file_exists(config_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not (parsed is Dictionary):
		return
	var configured_mode := str(parsed.get("mode", MODE_LOCAL))
	mode = configured_mode if configured_mode == MODE_REMOTE else MODE_LOCAL
	local_path = str(parsed.get("local_path", DEFAULT_LOCAL_PATH))
	remote_url = str(parsed.get("remote_url", ""))
	sync_interval_minutes = max(0, int(parsed.get("sync_interval_minutes", DEFAULT_INTERVAL_MINUTES)))


func save_config() -> void:
	var data := {
		"mode": mode,
		"local_path": local_path,
		"remote_url": remote_url,
		"sync_interval_minutes": sync_interval_minutes,
	}
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_dev_config() -> void:
	repo_path = ProjectSettings.globalize_path("res://").trim_suffix("/")
	git_remote = DEFAULT_GIT_REMOTE
	git_branch = DEFAULT_GIT_BRANCH
	if not FileAccess.file_exists(dev_config_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dev_config_path))
	if not (parsed is Dictionary):
		return
	var configured_repo := str(parsed.get("repo_path", "")).strip_edges()
	if configured_repo != "":
		repo_path = configured_repo
	var configured_remote := str(parsed.get("remote", "")).strip_edges()
	if configured_remote != "":
		git_remote = configured_remote
	var configured_branch := str(parsed.get("branch", "")).strip_edges()
	if configured_branch != "":
		git_branch = configured_branch


func save_dev_config() -> void:
	var data := {
		"repo_path": repo_path,
		"remote": git_remote,
		"branch": git_branch,
	}
	var file := FileAccess.open(dev_config_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func publish() -> Dictionary:
	var auth := _resolve_auth_manager()
	if auth == null or not auth.is_dev_session():
		return _publish_result(false, "Session administrateur requise.")
	if repo_path.strip_edges() == "":
		return _publish_result(false, "Dépôt git non configuré.")
	var repository := _absolute_path(repo_path)
	if not DirAccess.dir_exists_absolute(repository):
		return _publish_result(false, "Dépôt introuvable : %s." % repo_path)
	var git_check := _run_git(repository, PackedStringArray(["rev-parse", "--is-inside-work-tree"]))
	if int(git_check["exit_code"]) < 0:
		return _publish_result(false, "git est introuvable dans le PATH.")
	if int(git_check["exit_code"]) != 0 or not str(git_check["text"]).contains("true"):
		return _publish_result(false, "Le chemin configuré n'est pas un dépôt git.", 0, git_check["lines"])
	var remote_check := _run_git(repository, PackedStringArray(["remote", "get-url", git_remote]))
	if int(remote_check["exit_code"]) != 0:
		return _publish_result(false, "Remote git introuvable : %s." % git_remote, 0, remote_check["lines"])
	var source := _absolute_path(local_path)
	if not FileAccess.file_exists(source):
		return _publish_result(false, "Source introuvable : %s." % local_path)
	var relative := _relative_to_repository(source, repository)
	if relative == "":
		return _publish_result(false, "La source n'est pas dans le dépôt configuré.")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not (parsed is Dictionary):
		return _publish_result(false, "Source illisible : publication refusée.")
	var version := int(parsed.get("version", 0))
	var lines: PackedStringArray = []
	var added := _run_git(repository, PackedStringArray(["add", "--", relative]))
	lines.append_array(added["lines"])
	if int(added["exit_code"]) != 0:
		return _publish_result(false, "Ajout git refusé.", version, lines)
	var staged := _run_git(repository, PackedStringArray(["diff", "--cached", "--quiet", "--", relative]))
	if int(staged["exit_code"]) < 0 or int(staged["exit_code"]) > 1:
		return _publish_result(false, "État git illisible.", version, lines)
	var changed := int(staged["exit_code"]) == 1
	if changed:
		var committed := _run_git(
			repository,
			PackedStringArray(["commit", "-m", COMMIT_SUBJECT % version, "--", relative])
		)
		lines.append_array(committed["lines"])
		if int(committed["exit_code"]) != 0:
			return _publish_result(false, "Commit git refusé.", version, lines)
	var pushed := _run_git(
		repository, PackedStringArray(["push", git_remote, git_branch])
	)
	lines.append_array(pushed["lines"])
	if int(pushed["exit_code"]) != 0:
		return _publish_result(false, "Push git refusé.", version, lines)
	return _publish_result(true, "", version, lines)


func _publish_result(ok: bool, error: String, version: int = 0, lines = []) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"version": version,
		"lines": PackedStringArray(lines) if lines is Array else lines,
	}


func _resolve_auth_manager() -> Node:
	if auth_manager == null:
		auth_manager = get_node_or_null("/root/AuthManager")
	return auth_manager


func _run_git(repository: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var full_arguments := PackedStringArray(["-C", repository])
	full_arguments.append_array(arguments)
	var exit_code := OS.execute(GIT_EXECUTABLE, full_arguments, output, true, false)
	var lines: PackedStringArray = []
	for entry in output:
		lines.append(str(entry).strip_edges())
	return {"exit_code": exit_code, "lines": lines, "text": "\n".join(lines)}


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").trim_suffix("/")


func _relative_to_repository(source: String, repository: String) -> String:
	var source_path := source.replace("\\", "/")
	var root := repository.replace("\\", "/").trim_suffix("/") + "/"
	if OS.get_name() == "Windows":
		if not source_path.to_lower().begins_with(root.to_lower()):
			return ""
	else:
		if not source_path.begins_with(root):
			return ""
	return source_path.substr(root.length())


func apply_interval(minutes: int) -> void:
	sync_interval_minutes = max(0, minutes)
	if _timer == null:
		return
	if sync_interval_minutes <= 0:
		_timer.stop()
		return
	_timer.wait_time = float(sync_interval_minutes * SECONDS_PER_MINUTE)
	_timer.start()


func load_cache() -> Dictionary:
	if not FileAccess.file_exists(cache_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	if not (parsed is Dictionary):
		return {}
	return parsed


func save_cache(payload: Dictionary) -> void:
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _fetch_local() -> void:
	if not FileAccess.file_exists(local_path):
		_fallback_to_cache()
		return
	_handle_text(FileAccess.get_file_as_string(local_path))


func _fetch_remote() -> void:
	_fetch_in_flight = true
	var error := _http_request.request(remote_url)
	if error != OK:
		_fetch_in_flight = false
		_fallback_to_cache()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetch_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fallback_to_cache()
		return
	_handle_text(body.get_string_from_utf8())


func _handle_text(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fallback_to_cache()
		return
	_finish(true, apply_payload(parsed))


func _fallback_to_cache() -> void:
	var cached := load_cache()
	if cached.is_empty():
		_finish(false, 0)
		return
	_finish(false, apply_payload(cached, false))


func _on_timer_timeout() -> void:
	fetch()


func _finish(reachable: bool, new_offers: int) -> void:
	last_sync_at = int(Time.get_unix_time_from_system())
	last_sync_ok = reachable
	last_sync_mode = mode
	apply_interval(sync_interval_minutes)
	sync_finished.emit(reachable, new_offers)
