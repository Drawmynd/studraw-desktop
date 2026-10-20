extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results := {}
	results["T-CLK"] = _test_clock_manager()
	results["T-WIN"] = await _test_window_component()
	results["T-DSK"] = await _test_desktop_controller()
	results["T-MAIL"] = _test_mail_manager()
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
	print("%d test(s), %d échec(s)" % [results.size(), failure_count])
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
		failures.append("ticks attendus: 3, obtenus: %d" % counter["ticks"])
	var value: String = clock.get_time_string()
	var pattern := RegEx.new()
	pattern.compile("^\\d{2}:\\d{2}:\\d{2}$")
	if pattern.search(value) == null:
		failures.append("format attendu HH:MM:SS, obtenu: %s" % value)
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
	_compare_rect(failures, "déplacement", window.get_global_rect(), Rect2(224, 211, 560, 380))
	_compare_bottom(failures, window, usable_height)

	var corner: Vector2 = window.global_position + window.size - Vector2(6, 6)
	var resize_target: Vector2 = corner + Vector2(100, 50)
	_push_button(corner, true)
	_push_motion(resize_target)
	_push_button(resize_target, false)
	_compare_rect(failures, "redimensionnement", window.get_global_rect(), Rect2(224, 211, 660, 430))
	_compare_bottom(failures, window, usable_height)

	var restored_rect: Rect2 = window.get_global_rect()
	window.maximize()
	_compare_rect(
		failures,
		"maximisation",
		window.get_global_rect(),
		Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size.x, usable_height))
	)
	window.restore_from_maximize()
	_compare_rect(failures, "restauration après maximisation", window.get_global_rect(), restored_rect)

	corner = window.global_position + window.size - Vector2(6, 6)
	var shrink_target: Vector2 = corner - Vector2(1000, 1000)
	_push_button(corner, true)
	_push_motion(shrink_target)
	_push_button(shrink_target, false)
	_compare_rect(
		failures,
		"taille minimale",
		window.get_global_rect(),
		Rect2(224, 211, window.minimum_window_size.x, window.minimum_window_size.y)
	)

	window.minimize()
	if window.is_visible_in_tree():
		failures.append("réduction: fenêtre encore visible")
	window.restore()
	if not window.is_visible_in_tree():
		failures.append("restauration après réduction: fenêtre invisible")

	var closed_count := {"value": 0}
	window.closed.connect(func(_closed_window: WindowComponent) -> void: closed_count["value"] += 1)
	var close_point: Vector2 = window.close_button.get_global_rect().get_center()
	_push_button(close_point, true)
	_push_button(close_point, false)
	if closed_count["value"] != 1:
		failures.append("fermeture: signal closed émis %d fois" % closed_count["value"])
	await get_tree().process_frame
	if is_instance_valid(window):
		failures.append("fermeture: fenêtre non libérée")
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
		failures.append("barre des tâches: 2 boutons attendus, obtenus %d" % desktop.window_list.get_child_count())
	else:
		var first_button: Button = desktop.window_list.get_child(0)
		var second_button: Button = desktop.window_list.get_child(1)
		if first_button.text != "A" or second_button.text != "B":
			failures.append("barre des tâches: titres %s / %s" % [first_button.text, second_button.text])

	if _topmost(desktop) != second:
		failures.append("ouverture: la dernière fenêtre n'est pas au premier plan")

	_push_button(Vector2(110, 85), true)
	_push_button(Vector2(110, 85), false)
	if _topmost(desktop) != first:
		failures.append("clic sur fenêtre arrière: focus non pris")

	_push_button(Vector2(300, 300), true)
	_push_button(Vector2(300, 300), false)
	if _topmost(desktop) != first:
		failures.append("clic sur recouvrement: la fenêtre du dessous a pris le focus")

	_push_button(Vector2(668, 464), true)
	_push_button(Vector2(668, 464), false)
	if _topmost(desktop) != second:
		failures.append("clic sur fenêtre avant: focus non pris")

	first.minimize()
	await get_tree().process_frame
	var minimized_button: Button = desktop.window_list.get_child(0)
	if not is_equal_approx(minimized_button.modulate.a, Palette.TASKBAR_BUTTON_MINIMIZED_ALPHA):
		failures.append("réduction: bouton non estompé (alpha %f)" % minimized_button.modulate.a)
	_push_button(minimized_button.get_global_rect().get_center(), true)
	_push_button(minimized_button.get_global_rect().get_center(), false)
	if not first.is_visible_in_tree():
		failures.append("clic sur bouton réduit: fenêtre non restaurée")
	if _topmost(desktop) != first:
		failures.append("clic sur bouton réduit: fenêtre non focalisée")
	if not is_equal_approx(minimized_button.modulate.a, 1.0):
		failures.append("restauration: bouton toujours estompé (alpha %f)" % minimized_button.modulate.a)

	var closed_count := {"value": 0}
	first.closed.connect(func(_closed_window: WindowComponent) -> void: closed_count["value"] += 1)
	var close_point: Vector2 = first.close_button.get_global_rect().get_center()
	_push_button(close_point, true)
	_push_button(close_point, false)
	await get_tree().process_frame
	if closed_count["value"] != 1:
		failures.append("fermeture: signal closed émis %d fois" % closed_count["value"])
	if desktop.window_list.get_child_count() != 1:
		failures.append("fermeture: bouton de tâche restant %d" % desktop.window_list.get_child_count())
	if is_instance_valid(minimized_button):
		failures.append("fermeture: bouton de tâche non libéré")

	var remaining_button: Button = desktop.window_list.get_child(0)
	_push_button(remaining_button.get_global_rect().get_center(), true)
	_push_button(remaining_button.get_global_rect().get_center(), false)
	if _topmost(desktop) != second or not second.is_visible_in_tree():
		failures.append("après fermeture: fenêtre restante inutilisable")

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
		failures.append("amorce: 1 mail attendu, obtenu %d" % manager.get_mails().size())
	manager.ensure_welcome_mail()
	if manager.get_mails().size() != 1:
		failures.append("amorce: mail dupliqué")
	var welcome_id: String = str(manager.get_mails()[0]["id"])
	var copy: Array[Dictionary] = manager.get_mails()
	copy[0]["read"] = true
	if bool(manager.get_mail(welcome_id)["read"]):
		failures.append("get_mails: la copie modifie l'état interne")
	manager.mark_read(welcome_id)
	if not bool(manager.get_mail(welcome_id)["read"]):
		failures.append("marquage lu: état non mis à jour")
	var reloaded = load("res://managers/mail_manager.gd").new()
	reloaded.save_path = save_path
	reloaded.load_state()
	if reloaded.get_mails().is_empty() or not bool(reloaded.get_mail(welcome_id)["read"]):
		failures.append("persistance: état lu non rechargé")
	manager.add_mail({
		"id": "autre",
		"from": "Client",
		"subject": "Test",
		"body": "Corps",
		"received_at": 1,
	})
	if manager.get_mails().size() != 2:
		failures.append("ajout: 2 mails attendus, obtenu %d" % manager.get_mails().size())
	manager.archive_mail("autre")
	if manager.get_mails().size() != 1:
		failures.append(
			"archivage: 1 mail en boîte de réception attendu, obtenu %d"
			% manager.get_mails().size()
		)
	if manager.get_mails(true).size() != 2:
		failures.append(
			"archivage: 2 mails au total attendus, obtenu %d" % manager.get_mails(true).size()
		)
	if not bool(manager.get_mail("autre")["archived"]):
		failures.append("archivage: indicateur archived non positionné")
	var reloaded_archive = load("res://managers/mail_manager.gd").new()
	reloaded_archive.save_path = save_path
	reloaded_archive.load_state()
	if reloaded_archive.get_mails().size() != 1 or reloaded_archive.get_mails(true).size() != 2:
		failures.append("persistance: archivage non rechargé")
	if signal_count["value"] != 4:
		failures.append("signal mails_changed: 4 émissions attendues, obtenu %d" % signal_count["value"])
	manager.free()
	reloaded.free()
	reloaded_archive.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	return failures


func _test_palette() -> Array[String]:
	var failures: Array[String] = []
	var files: Array[String] = []
	_collect_sources("res://", files)
	for path in files:
		if path == "res://managers/palette.gd":
			continue
		if FileAccess.get_file_as_string(path).contains("Color("):
			failures.append("%s contient une couleur littérale" % path)
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
	failures.append("%s: attendu %s, obtenu %s" % [label, expected, actual])


func _compare_bottom(failures: Array[String], window: WindowComponent, usable_height: float) -> void:
	if window.global_position.y + window.size.y <= usable_height + 0.5:
		return
	failures.append("recouvrement de la barre des tâches: bas à %f, limite %f" % [
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
