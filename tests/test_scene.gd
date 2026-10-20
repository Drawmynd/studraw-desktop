extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results := {}
	results["T-CLK"] = _test_clock_manager()
	results["T-WIN"] = await _test_window_component()
	results["T-DSK"] = await _test_desktop_controller()
	results["T-MAIL"] = _test_mail_manager()
	results["T-COM"] = await _test_commission_manager()
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
		"from": "Client",
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
		"from": "Studio Studraw",
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
