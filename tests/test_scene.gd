extends Node

const WIFI_INDICATOR_SCRIPT := preload("res://components/wifi/wifi_indicator.gd")


class FakeDesktop:
	extends Node

	var windows: Array[Dictionary] = []

	func open_window(title: String, content: Control) -> void:
		windows.append({"title": title, "content": content})
		add_child(content)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results := {}
	results["T-CLK"] = _test_clock_manager()
	results["T-WIN"] = await _test_window_component()
	results["T-DSK"] = await _test_desktop_controller()
	results["T-MAIL"] = _test_mail_manager()
	results["T-COM"] = await _test_commission_manager()
	results["T-SYNC"] = await _test_sync_manager()
	results["T-SYNC-COM"] = await _test_sync_commission_merge()
	results["T-SYNC-MAIL"] = await _test_sync_mail_offers()
	results["T-CHEAT-SYNC"] = await _test_cheat_sync()
	results["T-WIFI"] = await _test_wifi_indicator()
	results["T-AUTH"] = await _test_auth_manager()
	results["T-AUTH-SAVE"] = await _test_auth_profile_saves()
	results["T-PAL"] = _test_palette()
	var failure_count := 0
	for test_name in results:
		var failures: Array = results[test_name]
		if failures.is_empty():
			print("PASS  %s" % test_name)
			continue
		failure_count += failures.size()
		print("FAIL  %s" % test_name)
		for failure in failures:
			print("      %s" % failure)
	print("%d test(s), %d failure(s)" % [results.size(), failure_count])
	get_tree().quit(1 if failure_count > 0 else 0)


func _test_clock_manager() -> Array[String]:
	var failures: Array[String] = []
	var clock = load("res://managers/clock_manager.gd").new()
	var counter := {"ticks": 0}
	clock.second_tick.connect(func() -> void: counter["ticks"] += 1)
	clock._process(1.4)
	clock._process(0.9)
	clock._process(1.2)
	if counter["ticks"] != 3:
		failures.append("expected ticks: 3, got: %d" % counter["ticks"])
	var value: String = clock.get_time_string()
	var pattern := RegEx.new()
	pattern.compile("^\\d{2}:\\d{2}:\\d{2}$")
	if pattern.search(value) == null:
		failures.append("expected format HH:MM:SS, got: %s" % value)
	clock.free()
	return failures


func _test_window_component() -> Array[String]:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://components/window/window_component.tscn")
	var window: WindowComponent = scene.instantiate()
	add_child(window)
	await get_tree().process_frame
	var usable_height: float = get_viewport().get_visible_rect().size.y - window.taskbar_height
	window.position = Vector2(100, 100)

	var title_point: Vector2 = window.global_position + Vector2(window.size.x * 0.5, 17.0)
	var drag_target: Vector2 = title_point + Vector2(124, 111)
	_push_button(title_point, true)
	_push_motion(drag_target)
	_push_button(drag_target, false)
	_compare_rect(failures, "drag", window.get_global_rect(), Rect2(224, 211, 560, 380))
	_compare_bottom(failures, window, usable_height)

	var corner: Vector2 = window.global_position + window.size - Vector2(6, 6)
	var resize_target: Vector2 = corner + Vector2(100, 50)
	_push_button(corner, true)
	_push_motion(resize_target)
	_push_button(resize_target, false)
	_compare_rect(failures, "resize", window.get_global_rect(), Rect2(224, 211, 660, 430))
	_compare_bottom(failures, window, usable_height)

	var restored_rect: Rect2 = window.get_global_rect()
	window.maximize()
	_compare_rect(
		failures,
		"maximize",
		window.get_global_rect(),
		Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size.x, usable_height))
	)
	window.restore_from_maximize()
	_compare_rect(failures, "restore after maximize", window.get_global_rect(), restored_rect)

	corner = window.global_position + window.size - Vector2(6, 6)
	var shrink_target: Vector2 = corner - Vector2(1000, 1000)
	_push_button(corner, true)
	_push_motion(shrink_target)
	_push_button(shrink_target, false)
	_compare_rect(
		failures,
		"minimum size",
		window.get_global_rect(),
		Rect2(224, 211, window.minimum_window_size.x, window.minimum_window_size.y)
	)

	window.minimize()
	if window.is_visible_in_tree():
		failures.append("minimize: window still visible")
	window.restore()
	if not window.is_visible_in_tree():
		failures.append("restore after minimize: window invisible")

	var closed_count := {"value": 0}
	window.closed.connect(func(_closed_window: WindowComponent) -> void: closed_count["value"] += 1)
	var close_point: Vector2 = window.close_button.get_global_rect().get_center()
	_push_button(close_point, true)
	_push_button(close_point, false)
	if closed_count["value"] != 1:
		failures.append("close: closed signal emitted %d times" % closed_count["value"])
	await get_tree().process_frame
	if is_instance_valid(window):
		failures.append("close: window not freed")
	return failures


func _test_desktop_controller() -> Array[String]:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://controllers/desktop/desktop_controller.tscn")
	var desktop = scene.instantiate()
	add_child(desktop)
	await get_tree().process_frame
	var first: WindowComponent = desktop.open_window("A", Label.new())
	var second: WindowComponent = desktop.open_window("B", Label.new())
	await get_tree().process_frame

	if desktop.window_list.get_child_count() != 2:
		failures.append("taskbar: expected 2 buttons, got %d" % desktop.window_list.get_child_count())
	else:
		var first_button: Button = desktop.window_list.get_child(0)
		var second_button: Button = desktop.window_list.get_child(1)
		if first_button.text != "A" or second_button.text != "B":
			failures.append("taskbar: titles %s / %s" % [first_button.text, second_button.text])

	if _topmost(desktop) != second:
		failures.append("open: last window is not topmost")

	_push_button(Vector2(110, 85), true)
	_push_button(Vector2(110, 85), false)
	if _topmost(desktop) != first:
		failures.append("click back window: focus not taken")

	_push_button(Vector2(300, 300), true)
	_push_button(Vector2(300, 300), false)
	if _topmost(desktop) != first:
		failures.append("click overlap: underlying window took focus")

	_push_button(Vector2(668, 464), true)
	_push_button(Vector2(668, 464), false)
	if _topmost(desktop) != second:
		failures.append("click front window: focus not taken")

	first.minimize()
	await get_tree().process_frame
	var minimized_button: Button = desktop.window_list.get_child(0)
	if not is_equal_approx(minimized_button.modulate.a, Palette.TASKBAR_BUTTON_MINIMIZED_ALPHA):
		failures.append("minimize: button not dimmed (alpha %f)" % minimized_button.modulate.a)
	_push_button(minimized_button.get_global_rect().get_center(), true)
	_push_button(minimized_button.get_global_rect().get_center(), false)
	if not first.is_visible_in_tree():
		failures.append("click minimized button: window not restored")
	if _topmost(desktop) != first:
		failures.append("click minimized button: window not focused")
	if not is_equal_approx(minimized_button.modulate.a, 1.0):
		failures.append("restore: button still dimmed (alpha %f)" % minimized_button.modulate.a)

	var closed_count := {"value": 0}
	first.closed.connect(func(_closed_window: WindowComponent) -> void: closed_count["value"] += 1)
	var close_point: Vector2 = first.close_button.get_global_rect().get_center()
	_push_button(close_point, true)
	_push_button(close_point, false)
	await get_tree().process_frame
	if closed_count["value"] != 1:
		failures.append("close: closed signal emitted %d times" % closed_count["value"])
	if desktop.window_list.get_child_count() != 1:
		failures.append("close: task button remaining %d" % desktop.window_list.get_child_count())
	if is_instance_valid(minimized_button):
		failures.append("close: task button not freed")

	var remaining_button: Button = desktop.window_list.get_child(0)
	_push_button(remaining_button.get_global_rect().get_center(), true)
	_push_button(remaining_button.get_global_rect().get_center(), false)
	if _topmost(desktop) != second or not second.is_visible_in_tree():
		failures.append("after close: remaining window unusable")

	desktop.queue_free()
	await get_tree().process_frame
	return failures


func _test_mail_manager() -> Array[String]:
	var failures: Array[String] = []
	var manager = load("res://managers/mail_manager.gd").new()
	var save_path: String = "user://test_mail_%d.json" % Time.get_ticks_usec()
	manager.save_path = save_path
	var signal_count := {"value": 0}
	manager.mails_changed.connect(func() -> void: signal_count["value"] += 1)
	manager.load_state()
	manager.ensure_welcome_mail()
	if manager.get_mails().size() != 1:
		failures.append("seed: expected 1 mail, got %d" % manager.get_mails().size())
	manager.ensure_welcome_mail()
	if manager.get_mails().size() != 1:
		failures.append("seed: duplicated mail")
	var welcome_id: String = str(manager.get_mails()[0]["id"])
	var copy: Array[Dictionary] = manager.get_mails()
	copy[0]["read"] = true
	if bool(manager.get_mail(welcome_id)["read"]):
		failures.append("get_mails: copy mutates internal state")
	manager.mark_read(welcome_id)
	if not bool(manager.get_mail(welcome_id)["read"]):
		failures.append("mark read: state not updated")
	var reloaded = load("res://managers/mail_manager.gd").new()
	reloaded.save_path = save_path
	reloaded.load_state()
	if reloaded.get_mails().is_empty() or not bool(reloaded.get_mail(welcome_id)["read"]):
		failures.append("persistence: read state not reloaded")
	manager.add_mail({
		"id": "autre",
		"sender": "Client",
		"subject": "Test",
		"body": "Corps",
		"received_at": 1,
	})
	if manager.get_mails().size() != 2:
		failures.append("add: expected 2 mails, got %d" % manager.get_mails().size())
	manager.archive_mail("autre")
	if manager.get_mails().size() != 1:
		failures.append(
			"archive: expected 1 inbox mail, got %d"
			% manager.get_mails().size()
		)
	if manager.get_mails(true).size() != 2:
		failures.append(
			"archive: expected 2 total mails, got %d" % manager.get_mails(true).size()
		)
	if not bool(manager.get_mail("autre")["archived"]):
		failures.append("archive: archived flag not set")
	var reloaded_archive = load("res://managers/mail_manager.gd").new()
	reloaded_archive.save_path = save_path
	reloaded_archive.load_state()
	if reloaded_archive.get_mails().size() != 1 or reloaded_archive.get_mails(true).size() != 2:
		failures.append("persistence: archive not reloaded")
	if signal_count["value"] != 4:
		failures.append("mails_changed signal: expected 4 emissions, got %d" % signal_count["value"])
	manager.free()
	reloaded.free()
	reloaded_archive.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	return failures


func _test_commission_manager() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_commission_%d.json" % Time.get_ticks_usec()
	var mail_manager = load("res://managers/mail_manager.gd").new()
	mail_manager.save_path = save_path
	mail_manager.load_state()
	var commission := {
		"id": "offre_test",
		"title": "Test poster",
		"type": "illustration",
		"duration": null,
		"description": "A poster used to verify the commission lifecycle.",
		"mail_request": "Please produce this poster.",
		"mail_success": "Thank you, the poster is complete.",
		"mail_failure": "The poster deadline has passed.",
	}
	mail_manager.add_mail({
		"id": "offre_test_mail",
		"sender": "Studio Studraw",
		"subject": "New commission: Test poster",
		"body": "Please produce this poster.",
		"received_at": 1,
		"type": "commission_offer",
		"commission": commission,
	})
	var clock = load("res://managers/clock_manager.gd").new()
	var manager = load("res://managers/commission_manager.gd").new()
	manager.save_path = save_path
	manager.mail_manager = mail_manager
	manager.clock_manager = clock
	add_child(manager)
	await get_tree().process_frame

	var commissions_app = load(
		"res://controllers/commissions/commissions_app_controller.tscn"
	).instantiate()
	commissions_app.commission_manager = manager
	commissions_app.clock_manager = clock
	add_child(commissions_app)
	await get_tree().process_frame
	if commissions_app.commission_list.get_child_count() != 0:
		failures.append(
			"commissions app: list not empty on open (%d)"
			% commissions_app.commission_list.get_child_count()
		)

	var mail_app = load("res://controllers/mail/mail_app_controller.tscn").instantiate()
	mail_app.mail_manager = mail_manager
	mail_app.commission_manager = manager
	add_child(mail_app)
	await get_tree().process_frame
	mail_app.select_mail("offre_test_mail")
	if not mail_app.accept_button.visible:
		failures.append("commission offer mail: accept button hidden")
	mail_app.accept_selected()
	await get_tree().process_frame

	var state: Dictionary = manager.get_commission("offre_test")
	if state.is_empty() or str(state.get("status", "")) != "active":
		failures.append("accept: commission is not active")
	else:
		var expected_deadline := int(state["accepted_at"]) + int(
			manager.TYPE_DURATIONS_MINUTES["illustration"]
		) * 60
		if int(state["deadline"]) != expected_deadline:
			failures.append(
				"accept: expected deadline %d, got %d"
				% [expected_deadline, int(state["deadline"])]
			)
	if not bool(mail_manager.get_mail("offre_test_mail").get("archived", false)):
		failures.append("accept: offer mail not archived")
	if commissions_app.commission_list.get_child_count() != 1:
		failures.append(
			"mail-to-list transfer: expected 1 commission, got %d"
			% commissions_app.commission_list.get_child_count()
		)

	var reminders: Array[String] = []
	manager.commission_reminder.connect(
		func(commission_id: String, hours_remaining: int) -> void:
			reminders.append("%s:%d" % [commission_id, hours_remaining])
	)
	var now := int(Time.get_unix_time_from_system())
	manager.accept({
		"id": "rappel_24",
		"title": "Reminder 24",
		"type": "affiche",
		"duration": 2880,
		"mail_success": "",
		"mail_failure": "",
	}, now - 24 * 3600 - 5)
	manager.accept({
		"id": "rappel_1",
		"title": "Reminder 1",
		"type": "affiche",
		"duration": 2880,
		"mail_success": "",
		"mail_failure": "",
	}, now - 47 * 3600 - 5)
	clock._process(60.0)
	if mail_manager.get_mail("rappel_24_rappel_24").is_empty():
		failures.append("24h reminder: mail missing")
	if mail_manager.get_mail("rappel_1_rappel_1").is_empty():
		failures.append("1h reminder: mail missing")
	if reminders.size() != 2:
		failures.append("reminders: expected 2 emissions, got %d" % reminders.size())
	clock._process(60.0)
	if _count_mails(mail_manager.get_mails(true), "rappel_24_rappel_24") != 1:
		failures.append("24h reminder: duplicate mail")
	if _count_mails(mail_manager.get_mails(true), "rappel_1_rappel_1") != 1:
		failures.append("1h reminder: duplicate mail")
	if reminders.size() != 2:
		failures.append("reminders: duplicate emissions (%d)" % reminders.size())

	mail_app.queue_free()
	commissions_app.queue_free()
	manager.queue_free()
	mail_manager.free()
	clock.free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	return failures


func _test_sync_manager() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_sync_%d.json" % Time.get_ticks_usec()
	var cache_path := "user://test_sync_cache_%d.json" % Time.get_ticks_usec()
	var config_path := "user://test_sync_config_%d.json" % Time.get_ticks_usec()
	var isolated := _make_isolated_managers(save_path)
	var sync = load("res://managers/sync_manager.gd").new()
	add_child(sync)
	await get_tree().process_frame
	sync.cache_path = cache_path
	sync.config_path = config_path
	sync.commission_manager = isolated["commission_manager"]
	sync.mode = "local"
	sync.local_path = "user://test_sync_missing_%d.json" % Time.get_ticks_usec()
	sync.remote_url = ""
	sync.apply_interval(0)

	var first_payload := {
		"version": 2,
		"updated_at": 5,
		"commissions": [_payload_definition("sync_a", "Sync A")],
	}
	if sync.apply_payload(first_payload) != 1:
		failures.append("apply: expected 1 new offer")
	var cache: Dictionary = sync.load_cache()
	if int(cache.get("version", 0)) != 2:
		failures.append("cache: version not stored")
	if not (cache.get("commissions") is Array) or cache["commissions"].size() != 1:
		failures.append("cache: commissions not stored")

	if sync.apply_payload({
		"version": 1,
		"commissions": [_payload_definition("sync_b", "Sync B")],
	}) != 0:
		failures.append("version guard: older payload applied")
	if not isolated["mail_manager"].get_mail("offre_sync_b").is_empty():
		failures.append("version guard: older payload created an offer")

	if sync.apply_payload({}) != 0:
		failures.append("validation: empty payload accepted")
	if sync.apply_payload({"version": 3, "commissions": "nope"}) != 0:
		failures.append("validation: non-array commissions accepted")
	if int(sync.load_cache().get("version", 0)) != 2:
		failures.append("validation: cache overwritten by invalid payload")
	if sync.apply_payload({"version": 3, "commissions": [{"title": "no id"}, 7]}) != 0:
		failures.append("validation: invalid entries accepted")
	if int(sync.load_cache().get("version", 0)) != 2:
		failures.append("validation: cache overwritten by empty entries")

	var finished := {"count": 0, "reachable": -1, "offers": -1}
	sync.sync_finished.connect(
		func(reachable: bool, new_offers: int) -> void:
			finished["count"] += 1
			finished["reachable"] = 1 if reachable else 0
			finished["offers"] = new_offers
	)
	sync.fetch()
	if finished["count"] != 1 or finished["reachable"] != 0 or finished["offers"] != 0:
		failures.append("offline fetch: cache applied but source reported reachable")
	if int(sync.load_cache().get("version", 0)) != 2:
		failures.append("offline fetch: cache lost")

	sync.cache_path = "user://test_sync_empty_%d.json" % Time.get_ticks_usec()
	sync.fetch()
	if finished["reachable"] != 0:
		failures.append("offline fetch without cache: expected unreachable")

	sync.cache_path = cache_path
	sync.apply_interval(0)
	if not sync._timer.is_stopped():
		failures.append("interval 0: timer still running")
	sync.apply_interval(30)
	if sync._timer.is_stopped() or not is_equal_approx(sync._timer.wait_time, 1800.0):
		failures.append("interval 30: timer not configured")
	sync.apply_interval(0)

	sync.mode = "remote"
	sync.local_path = "user://configured_%d.json" % Time.get_ticks_usec()
	sync.remote_url = "https://example.invalid/commissions.json"
	sync.sync_interval_minutes = 7
	sync.save_config()
	var reloaded = load("res://managers/sync_manager.gd").new()
	reloaded.config_path = config_path
	reloaded.load_config()
	if reloaded.mode != "remote":
		failures.append("config: mode not reloaded")
	if reloaded.remote_url != sync.remote_url:
		failures.append("config: remote url not reloaded")
	if reloaded.sync_interval_minutes != 7:
		failures.append("config: interval not reloaded")
	if reloaded.local_path != sync.local_path:
		failures.append("config: local path not reloaded")
	reloaded.free()

	sync.queue_free()
	isolated["mail_manager"].free()
	isolated["commission_manager"].free()
	await get_tree().process_frame
	_remove_file(save_path)
	_remove_file(cache_path)
	_remove_file(config_path)
	return failures


func _test_sync_commission_merge() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_sync_com_%d.json" % Time.get_ticks_usec()
	var cache_path := "user://test_sync_com_cache_%d.json" % Time.get_ticks_usec()
	var isolated := _make_isolated_managers(save_path)
	var mail_manager = isolated["mail_manager"]
	var commission_manager = isolated["commission_manager"]
	var sync = load("res://managers/sync_manager.gd").new()
	sync.cache_path = cache_path
	sync.commission_manager = commission_manager

	var payload := {
		"version": 1,
		"commissions": [
			_payload_definition("com_a", "A"),
			_payload_definition("com_b", "B"),
			_payload_definition("com_c", "C"),
			_payload_definition("com_a", "A bis"),
		],
	}
	if sync.apply_payload(payload) != 3:
		failures.append("merge: expected 3 offers")
	if not commission_manager.has_seen("com_a") or not commission_manager.has_seen("com_c"):
		failures.append("merge: ids not marked as seen")
	if mail_manager.get_mail("offre_com_a").is_empty():
		failures.append("merge: offer mail missing")
	if str(commission_manager.get_commission("com_a").get("client", "")) != "Client com_a":
		failures.append("merge: client not stored on the definition")
	if str(mail_manager.get_mail("offre_com_a").get("sender", "")) != "sender@com_a.example":
		failures.append("merge: mail sender does not come from the commission")

	if sync.apply_payload(payload) != 0:
		failures.append("replay: offers created again")
	if mail_manager.get_mails(true).size() != 3:
		failures.append("replay: duplicate mails (%d)" % mail_manager.get_mails(true).size())

	commission_manager.accept(_payload_definition("com_b", "B"))
	commission_manager.refuse("com_a")
	mail_manager.mark_read("offre_com_c")

	var second_payload := {
		"version": 2,
		"commissions": [
			_payload_definition("com_a", "A modifiée"),
			_payload_definition("com_b", "B modifiée"),
			_payload_definition("com_c", "C modifiée"),
			_payload_definition("com_d", "D"),
		],
	}
	if sync.apply_payload(second_payload) != 1:
		failures.append("merge: expected 1 new offer after update")
	if str(commission_manager.get_commission("com_b").get("title", "")) != "B":
		failures.append("merge: accepted commission was modified")
	if str(commission_manager.get_commission("com_c").get("title", "")) != "C modifiée":
		failures.append("merge: pending offer not refreshed")
	if not str(mail_manager.get_mail("offre_com_c").get("subject", "")).contains("C modifiée"):
		failures.append("merge: pending offer mail not refreshed")
	if not bool(mail_manager.get_mail("offre_com_c").get("read", false)):
		failures.append("merge: refresh reset the read state")
	if str(mail_manager.get_mail("offre_com_a").get("subject", "")).contains("modifiée"):
		failures.append("merge: refused offer was refreshed")

	var reloaded = load("res://managers/commission_manager.gd").new()
	reloaded.save_path = save_path
	reloaded.load_state()
	if not reloaded.has_seen("com_a") or not reloaded.has_seen("com_d"):
		failures.append("persistence: seen ids not reloaded")
	reloaded.free()

	sync.free()
	mail_manager.free()
	commission_manager.free()
	_remove_file(save_path)
	_remove_file(cache_path)
	return failures


func _test_sync_mail_offers() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_sync_mail_%d.json" % Time.get_ticks_usec()
	var cache_path := "user://test_sync_mail_cache_%d.json" % Time.get_ticks_usec()
	var isolated := _make_isolated_managers(save_path)
	var mail_manager = isolated["mail_manager"]
	var commission_manager = isolated["commission_manager"]
	var sync = load("res://managers/sync_manager.gd").new()
	sync.cache_path = cache_path
	sync.commission_manager = commission_manager
	var mail_changes := {"value": 0}
	mail_manager.mails_changed.connect(func() -> void: mail_changes["value"] += 1)

	sync.apply_payload({
		"version": 1,
		"commissions": [
			_payload_definition("com_m1", "M1"),
			_payload_definition("com_m2", "M2"),
		],
	})
	var mails: Array[Dictionary] = mail_manager.get_mails(true)
	if mails.size() != 2:
		failures.append("offers: expected 2 mails, got %d" % mails.size())
	for mail in mails:
		if str(mail.get("type", "")) != "commission_offer":
			failures.append("offers: mail %s is not a commission offer" % mail["id"])
		if bool(mail.get("read", false)) or bool(mail.get("archived", false)):
			failures.append("offers: mail %s is read or archived" % mail["id"])
		if not str(mail["id"]).begins_with("offre_com_m"):
			failures.append("offers: unexpected mail id %s" % mail["id"])
		if not (mail.get("commission") is Dictionary):
			failures.append("offers: mail %s has no commission" % mail["id"])
		if str(mail["commission"].get("client", "")) == "":
			failures.append("offers: mail %s has no client" % mail["id"])
		if mail["sender"] != "sender@%s.example" % str(mail["commission"]["id"]):
			failures.append("offers: mail %s has a wrong sender" % mail["id"])
	if mail_changes["value"] != 2:
		failures.append("offers: expected 2 mail signals, got %d" % mail_changes["value"])

	var mail_app = load("res://controllers/mail/mail_app_controller.tscn").instantiate()
	mail_app.mail_manager = mail_manager
	mail_app.commission_manager = commission_manager
	add_child(mail_app)
	await get_tree().process_frame
	mail_app.select_mail("offre_com_m1")
	if not mail_app.accept_button.visible or not mail_app.refuse_button.visible:
		failures.append("offers: accept / refuse buttons hidden")

	var original_subject := str(mail_manager.get_mail("offre_com_m1")["subject"])
	var total_before: int = mail_manager.get_mails(true).size()
	mail_manager.archive_mail("offre_com_m1")
	sync.apply_payload({
		"version": 2,
		"commissions": [_payload_definition("com_m1", "M1 modifiée")],
	})
	if mail_manager.get_mails(true).size() != total_before:
		failures.append("offers: archived offer duplicated")
	if not bool(mail_manager.get_mail("offre_com_m1")["archived"]):
		failures.append("offers: archived flag lost")
	if str(mail_manager.get_mail("offre_com_m1")["subject"]) != original_subject:
		failures.append("offers: archived offer refreshed")

	mail_app.queue_free()
	sync.free()
	mail_manager.free()
	commission_manager.free()
	await get_tree().process_frame
	_remove_file(save_path)
	_remove_file(cache_path)
	return failures


func _test_cheat_sync() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_cheat_sync_%d.json" % Time.get_ticks_usec()
	var cache_path := "user://test_cheat_sync_cache_%d.json" % Time.get_ticks_usec()
	var config_path := "user://test_cheat_sync_config_%d.json" % Time.get_ticks_usec()
	var feed_path := "user://test_cheat_sync_feed_%d.json" % Time.get_ticks_usec()
	var isolated := _make_isolated_managers(save_path)
	var sync = load("res://managers/sync_manager.gd").new()
	add_child(sync)
	await get_tree().process_frame
	sync.config_path = config_path
	sync.cache_path = cache_path
	sync.commission_manager = isolated["commission_manager"]
	sync.mode = "local"
	sync.local_path = feed_path
	sync.apply_interval(0)

	var console = load("res://controllers/dev/dev_console_controller.tscn").instantiate()
	console.sync_manager = sync
	add_child(console)
	await get_tree().process_frame

	console.mode_option.selected = 1
	console.remote_url_edit.text = "https://example.invalid/commissions.json"
	console.local_path_edit.text = "user://cheat_clone/commissions.json"
	console.interval_edit.text = "9"
	console.save_sync_config()
	if not FileAccess.file_exists(config_path):
		failures.append("cheat config: file not written")
	var reloaded = load("res://managers/sync_manager.gd").new()
	reloaded.config_path = config_path
	reloaded.load_config()
	if reloaded.mode != "remote" or reloaded.sync_interval_minutes != 9:
		failures.append("cheat config: mode or interval not saved")
	if reloaded.remote_url != "https://example.invalid/commissions.json":
		failures.append("cheat config: remote url not saved")
	if reloaded.local_path != "user://cheat_clone/commissions.json":
		failures.append("cheat config: local path not saved")
	reloaded.free()

	_write_json(feed_path, {
		"version": 1,
		"commissions": [_payload_definition("cheat_sync_a", "Cheat sync")],
	})
	console.mode_option.selected = 0
	console.local_path_edit.text = feed_path
	console.interval_edit.text = "0"
	console.save_sync_config()
	if not sync._timer.is_stopped():
		failures.append("cheat config: interval 0 did not stop the timer")
	console.sync_now()
	if not console.status_label.text.contains("1"):
		failures.append("cheat sync: status does not report the new offer")
	if isolated["mail_manager"].get_mail("offre_cheat_sync_a").is_empty():
		failures.append("cheat sync: offer mail missing")
	if console.last_sync_label.text == "Dernière sync : —":
		failures.append("cheat sync: last sync label not updated")
	if not console.last_sync_label.text.contains("succès"):
		failures.append("cheat sync: last sync label does not report success")

	var fake_desktop := FakeDesktop.new()
	add_child(fake_desktop)
	console.desktop = fake_desktop
	console.show_raw_file()
	if fake_desktop.windows.size() != 1:
		failures.append("raw file: no window opened")
	else:
		if str(fake_desktop.windows[0]["title"]) != "Fichier local":
			failures.append("raw file: wrong window title")
		await get_tree().process_frame
		var view = fake_desktop.windows[0]["content"]
		if not view.content.text.contains("cheat_sync_a"):
			failures.append("raw file: content does not show the local file")
	fake_desktop.queue_free()

	console.queue_free()
	sync.queue_free()
	isolated["mail_manager"].free()
	isolated["commission_manager"].free()
	await get_tree().process_frame
	_remove_file(save_path)
	_remove_file(cache_path)
	_remove_file(config_path)
	_remove_file(feed_path)
	return failures


func _test_wifi_indicator() -> Array[String]:
	var failures: Array[String] = []
	var save_path := "user://test_wifi_%d.json" % Time.get_ticks_usec()
	var config_path := "user://test_wifi_config_%d.json" % Time.get_ticks_usec()
	var cache_path := "user://test_wifi_cache_%d.json" % Time.get_ticks_usec()
	var feed_path := "user://test_wifi_feed_%d.json" % Time.get_ticks_usec()
	_write_json(feed_path, {
		"version": 1,
		"commissions": [_payload_definition("wifi_a", "Wifi A")],
	})
	var isolated := _make_isolated_managers(save_path)
	var previous := {
		"mode": SyncManager.mode,
		"config_path": SyncManager.config_path,
		"cache_path": SyncManager.cache_path,
		"local_path": SyncManager.local_path,
		"remote_url": SyncManager.remote_url,
		"interval": SyncManager.sync_interval_minutes,
		"last_sync_at": SyncManager.last_sync_at,
		"last_sync_ok": SyncManager.last_sync_ok,
		"last_sync_mode": SyncManager.last_sync_mode,
		"commission_manager": SyncManager.commission_manager,
	}
	SyncManager.config_path = config_path
	SyncManager.cache_path = cache_path
	SyncManager.local_path = feed_path
	SyncManager.remote_url = ""
	SyncManager.sync_interval_minutes = 0
	SyncManager.commission_manager = isolated["commission_manager"]
	SyncManager.set_mode("local")
	SyncManager.last_sync_at = 0
	SyncManager.last_sync_ok = false
	SyncManager.last_sync_mode = ""

	var desktop = load("res://controllers/desktop/desktop_controller.tscn").instantiate()
	add_child(desktop)
	await get_tree().process_frame
	var indicator: Control = desktop.wifi_indicator
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_LOCAL:
		failures.append("wifi: local mode is not local")

	SyncManager.last_sync_mode = "remote"
	SyncManager.last_sync_ok = false
	desktop._update_wifi_state()
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_LOCAL:
		failures.append("wifi: a remote failure is still shown after switching to local")
	SyncManager.last_sync_ok = false
	SyncManager.last_sync_mode = ""

	indicator.pressed.emit()
	if SyncManager.mode != "remote":
		failures.append("wifi: click did not switch to remote")
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_ERROR:
		failures.append("wifi: remote without url is not an error")
	if not desktop.notification_panel.visible or not desktop.notification_label.text.contains("Synchronisation impossible"):
		failures.append("wifi: failed sync did not notify")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not (saved is Dictionary) or str(saved.get("mode", "")) != "remote":
		failures.append("wifi: mode not saved in the config")

	SyncManager._finish(true, 0)
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_REMOTE:
		failures.append("wifi: successful remote sync is not remote")
	if not SyncManager.get_last_sync_text().contains("succès"):
		failures.append("wifi: last sync text does not report success")

	SyncManager._finish(false, 0)
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_ERROR:
		failures.append("wifi: failed sync is not an error")

	indicator.pressed.emit()
	if SyncManager.mode != "local":
		failures.append("wifi: click did not switch back to local")
	if not SyncManager.last_sync_ok:
		failures.append("wifi: local sync did not succeed")
	if indicator.get_state() != WIFI_INDICATOR_SCRIPT.STATE_LOCAL:
		failures.append("wifi: successful local sync is not local")

	desktop.queue_free()
	await get_tree().process_frame
	SyncManager.mode = previous["mode"]
	SyncManager.config_path = previous["config_path"]
	SyncManager.cache_path = previous["cache_path"]
	SyncManager.local_path = previous["local_path"]
	SyncManager.remote_url = previous["remote_url"]
	SyncManager.sync_interval_minutes = previous["interval"]
	SyncManager.last_sync_at = previous["last_sync_at"]
	SyncManager.last_sync_ok = previous["last_sync_ok"]
	SyncManager.last_sync_mode = previous["last_sync_mode"]
	SyncManager.commission_manager = previous["commission_manager"]
	SyncManager.apply_interval(SyncManager.sync_interval_minutes)
	isolated["mail_manager"].free()
	isolated["commission_manager"].free()
	_remove_file(save_path)
	_remove_file(config_path)
	_remove_file(cache_path)
	_remove_file(feed_path)
	return failures


func _test_auth_manager() -> Array[String]:
	var failures: Array[String] = []
	var base := "user://test_auth_%d" % Time.get_ticks_usec()
	var profiles_path := "%s_profiles.json" % base
	var save_dir := "%s_saves" % base
	var auth = load("res://managers/auth_manager.gd").new()
	auth.profiles_path = profiles_path
	auth.profile_save_dir = save_dir
	auth.legacy_save_path = "%s_legacy.json" % base
	add_child(auth)

	var profiles: Array[Dictionary] = auth.get_profiles()
	if profiles.size() != 1:
		failures.append("seed: expected 1 profile, got %d" % profiles.size())
	var admin_id: String = str(profiles[0]["id"]) if not profiles.is_empty() else ""
	if not bool(profiles[0]["is_admin"]):
		failures.append("seed: admin profile is not flagged as admin")
	if profiles[0].has("password_hash"):
		failures.append("profiles: the password hash is exposed")
	if not auth.verify(admin_id, "admin"):
		failures.append("seed: the default password is rejected")
	if auth.verify(admin_id, "wrong"):
		failures.append("seed: a wrong password is accepted")

	var session_events := {"value": 0}
	auth.session_changed.connect(func(_authenticated: bool, _admin: bool) -> void:
		session_events["value"] += 1)

	if auth.create_profile("Alice", "abc").get("ok", false):
		failures.append("create: a short password was accepted")
	if auth.create_profile("", "secret").get("ok", false):
		failures.append("create: an empty pseudo was accepted")
	var created: Dictionary = auth.create_profile("Alice", "secret")
	if not bool(created.get("ok", false)):
		failures.append("create: a valid profile was rejected (%s)" % created.get("error", ""))
	var alice_id := str(created.get("id", ""))
	if auth.create_profile("alice", "secret").get("ok", false):
		failures.append("create: a duplicate pseudo was accepted")
	if auth.get_profiles().size() != 2:
		failures.append("create: expected 2 profiles")

	if not auth.authenticate(alice_id, "secret"):
		failures.append("login: a valid password was rejected")
	if auth.is_dev_session():
		failures.append("login: a standard profile is an admin session")
	if str(auth.get_current_profile().get("pseudo", "")) != "Alice":
		failures.append("login: the current profile is wrong")
	if auth.authenticate(alice_id, "wrong"):
		failures.append("login: a wrong password was accepted")
	if str(auth.get_current_profile().get("id", "")) != alice_id:
		failures.append("login: a failed attempt dropped the session")

	if auth.change_credentials(alice_id, "wrong", "Bobby", "secret2").get("ok", false):
		failures.append("credentials: a wrong current password was accepted")
	var changed: Dictionary = auth.change_credentials(alice_id, "secret", "Bobby", "secret2")
	if not bool(changed.get("ok", false)):
		failures.append("credentials: a valid change was rejected (%s)" % changed.get("error", ""))
	if auth.verify(alice_id, "secret"):
		failures.append("credentials: the old password still works")
	if not auth.verify(alice_id, "secret2"):
		failures.append("credentials: the new password does not work")
	if str(auth.get_profile(alice_id).get("pseudo", "")) != "Bobby":
		failures.append("credentials: the pseudo was not changed")
	if auth.get_profile(alice_id).get("password_hash") != null:
		failures.append("credentials: the hash leaks through get_profile")
	if not FileAccess.get_file_as_string(profiles_path).contains("Bobby"):
		failures.append("credentials: the change was not persisted")

	if auth.delete_profile(alice_id, "wrong").get("ok", false):
		failures.append("delete: a wrong password was accepted")
	if not auth.delete_profile(alice_id, "secret2").get("ok", false):
		failures.append("delete: a valid password was rejected")
	if auth.get_profiles().size() != 1:
		failures.append("delete: the profile was not removed")
	if FileAccess.file_exists(auth.get_profile_save_path(alice_id)):
		failures.append("delete: the profile save was kept")

	if not auth.authenticate(admin_id, "admin"):
		failures.append("login: the admin login failed")
	if not auth.is_dev_session():
		failures.append("login: the admin session is not a dev session")
	var second: Dictionary = auth.create_profile("Carol", "secret")
	var carol_id := str(second.get("id", ""))
	if auth.delete_profile_as_admin(carol_id, "wrong").get("ok", false):
		failures.append("admin delete: a wrong admin password was accepted")
	if not auth.delete_profile_as_admin(carol_id, "admin").get("ok", false):
		failures.append("admin delete: a valid admin password was rejected")
	if auth.delete_profile(admin_id, "admin").get("ok", false):
		failures.append("delete: the last admin profile was removed")
	if auth.delete_profile_as_admin(admin_id, "admin").get("ok", false):
		failures.append("admin delete: the last admin profile was removed")

	auth.logout()
	if auth.is_authenticated() or auth.is_dev_session():
		failures.append("logout: the session is still open")
	if session_events["value"] != 4:
		failures.append("session: expected 4 signals, got %d" % session_events["value"])
	auth.queue_free()

	var corrupt_path := "%s_corrupt.json" % base
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("not json")
		corrupt.close()
	var broken = load("res://managers/auth_manager.gd").new()
	broken.profiles_path = corrupt_path
	broken.profile_save_dir = save_dir
	broken.legacy_save_path = "%s_legacy.json" % base
	add_child(broken)
	if broken.get_profiles().size() != 1:
		failures.append("corrupt: no fallback admin profile")
	if FileAccess.get_file_as_string(corrupt_path) != "not json":
		failures.append("corrupt: the profile file was overwritten")
	broken.queue_free()

	await get_tree().process_frame
	_remove_file(profiles_path)
	_remove_file(corrupt_path)
	_remove_directory(save_dir)
	return failures


func _test_auth_profile_saves() -> Array[String]:
	var failures: Array[String] = []
	var base := "user://test_auth_save_%d" % Time.get_ticks_usec()
	var profiles_path := "%s_profiles.json" % base
	var save_dir := "%s_saves" % base
	var legacy_path := "%s_legacy.json" % base
	var auth = load("res://managers/auth_manager.gd").new()
	auth.profiles_path = profiles_path
	auth.profile_save_dir = save_dir
	auth.legacy_save_path = legacy_path
	add_child(auth)

	var admin_id := str(auth.get_profiles()[0]["id"])
	var alice_id := str(auth.create_profile("Alice", "secret").get("id", ""))
	var admin_save: String = auth.get_profile_save_path(admin_id)
	var alice_save: String = auth.get_profile_save_path(alice_id)
	if admin_save == alice_save:
		failures.append("saves: two profiles share the same save path")

	var admin_mails = load("res://managers/mail_manager.gd").new()
	admin_mails.save_path = admin_save
	admin_mails.load_state()
	admin_mails.add_mail({"id": "mail_admin", "sender": "admin@test.example", "subject": "A", "body": "A"})
	var alice_mails = load("res://managers/mail_manager.gd").new()
	alice_mails.save_path = alice_save
	alice_mails.load_state()
	if not alice_mails.get_mail("mail_admin").is_empty():
		failures.append("saves: a mail leaked into another profile")
	alice_mails.add_mail({"id": "mail_alice", "sender": "alice@test.example", "subject": "B", "body": "B"})
	var admin_reloaded = load("res://managers/mail_manager.gd").new()
	admin_reloaded.save_path = admin_save
	admin_reloaded.load_state()
	if admin_reloaded.get_mail("mail_admin").is_empty():
		failures.append("saves: the admin mail was not persisted")
	if not admin_reloaded.get_mail("mail_alice").is_empty():
		failures.append("saves: the admin save contains another profile's mail")
	admin_mails.free()
	alice_mails.free()
	admin_reloaded.free()

	_write_json(legacy_path, {
		"mails": [{"id": "legacy_mail", "sender": "legacy@test.example", "subject": "L", "body": "L"}],
	})
	var migrated = load("res://managers/auth_manager.gd").new()
	migrated.profiles_path = "%s_profiles_migrated.json" % base
	migrated.profile_save_dir = "%s_saves_migrated" % base
	migrated.legacy_save_path = legacy_path
	add_child(migrated)
	var migrated_save: String = migrated.get_profile_save_path(str(migrated.get_profiles()[0]["id"]))
	if not FileAccess.file_exists(migrated_save):
		failures.append("migration: the legacy save was not copied")
	else:
		var migrated_mails = load("res://managers/mail_manager.gd").new()
		migrated_mails.save_path = migrated_save
		migrated_mails.load_state()
		if migrated_mails.get_mail("legacy_mail").is_empty():
			failures.append("migration: the legacy mail is missing")
		migrated.load_state()
		var migrated_again = load("res://managers/mail_manager.gd").new()
		migrated_again.save_path = migrated_save
		migrated_again.load_state()
		if migrated_again.get_mails(true).size() != 1:
			failures.append("migration: the second load duplicated the state")
		migrated_mails.free()
		migrated_again.free()
	migrated.queue_free()
	auth.queue_free()

	await get_tree().process_frame
	_remove_file(profiles_path)
	_remove_file("%s_profiles_migrated.json" % base)
	_remove_file(legacy_path)
	_remove_directory(save_dir)
	_remove_directory("%s_saves_migrated" % base)
	return failures


func _make_isolated_managers(save_path: String) -> Dictionary:
	var mail_manager = load("res://managers/mail_manager.gd").new()
	mail_manager.save_path = save_path
	mail_manager.load_state()
	var commission_manager = load("res://managers/commission_manager.gd").new()
	commission_manager.save_path = save_path
	commission_manager.mail_manager = mail_manager
	commission_manager.load_state()
	return {"mail_manager": mail_manager, "commission_manager": commission_manager}


func _payload_definition(commission_id: String, title: String) -> Dictionary:
	return {
		"id": commission_id,
		"title": title,
		"type": "affiche",
		"duration": 60,
		"client": "Client %s" % commission_id,
		"sender": "sender@%s.example" % commission_id,
		"description": "Commande de synchronisation.",
		"mail_request": "Merci de réaliser %s." % title,
		"mail_success": "Merci.",
		"mail_failure": "Trop tard.",
	}


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_directory(path: String) -> void:
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
			_remove_directory(child)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = handle.get_next()
	handle.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _count_mails(mails: Array[Dictionary], mail_id: String) -> int:
	var count := 0
	for mail in mails:
		if str(mail["id"]) == mail_id:
			count += 1
	return count


func _test_palette() -> Array[String]:
	var failures: Array[String] = []
	var files: Array[String] = []
	_collect_sources("res://", files)
	for path in files:
		if path == "res://managers/palette.gd":
			continue
		if FileAccess.get_file_as_string(path).contains("Color("):
			failures.append("%s contains a literal color" % path)
	return failures


func _collect_sources(directory: String, results: Array[String]) -> void:
	var handle := DirAccess.open(directory)
	if handle == null:
		return
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = handle.get_next()
			continue
		var path := directory.path_join(entry)
		if handle.current_is_dir():
			if path != "res://tests" and path != "res://addons":
				_collect_sources(path, results)
		else:
			var extension := path.get_extension()
			if extension == "gd" or extension == "tscn":
				results.append(path)
		entry = handle.get_next()
	handle.list_dir_end()


func _topmost(desktop: Control) -> WindowComponent:
	var children: Array = desktop.windows_layer.get_children()
	return children[children.size() - 1] as WindowComponent


func _compare_rect(
	failures: Array[String], label: String, actual: Rect2, expected: Rect2
) -> void:
	if actual.position.is_equal_approx(expected.position) and actual.size.is_equal_approx(expected.size):
		return
	failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _compare_bottom(failures: Array[String], window: WindowComponent, usable_height: float) -> void:
	if window.global_position.y + window.size.y <= usable_height + 0.5:
		return
	failures.append("taskbar overlap: bottom at %f, limit %f" % [
		window.global_position.y + window.size.y, usable_height
	])


func _push_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event, true)


func _push_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event, true)
