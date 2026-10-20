extends Node

signal sync_finished(reachable: bool, new_offers: int)
signal mode_changed(mode: String)

const DEFAULT_CONFIG_PATH := "user://sync_config.json"
const DEFAULT_CACHE_PATH := "user://commissions_cache.json"
const DEFAULT_LOCAL_PATH := "res://data/commissions.json"
const MODE_LOCAL := "local"
const MODE_REMOTE := "remote"
const REQUEST_TIMEOUT_SECONDS := 10.0
const SECONDS_PER_MINUTE := 60
const DEFAULT_INTERVAL_MINUTES := 30

var config_path: String = DEFAULT_CONFIG_PATH
var cache_path: String = DEFAULT_CACHE_PATH
var mode: String = MODE_LOCAL
var local_path: String = DEFAULT_LOCAL_PATH
var remote_url: String = ""
var sync_interval_minutes: int = DEFAULT_INTERVAL_MINUTES
var commission_manager: Node
var last_sync_at: int = 0
var last_sync_ok: bool = false
var last_sync_mode: String = ""
var force_remote_ok: bool = false

var _http_request: HTTPRequest
var _timer: Timer
var _fetch_in_flight: bool = false


func _ready() -> void:
	load_config()
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
