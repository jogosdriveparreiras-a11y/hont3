extends SceneTree

## Capture title screen + Jogar submenu for visual QA.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out := ProjectSettings.globalize_path("res://").path_join("playtest_out/title_fix_20260928")
	DirAccess.make_dir_recursive_absolute(out)
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", false)
	game.set("sensitive_content", false)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	if game.get("sound") != null:
		game.call("_set_volume", 0.0, "MASTER")
	# Ensure title menu
	game.set("title_menu_section", "")
	game.call("_show_menu")
	for i in range(20):
		await process_frame
	# Let video decode a few frames
	await create_timer(1.2).timeout
	for i in range(10):
		await process_frame
	await _shot(out, "01_title_root.png")

	game.set("title_menu_section", "jogar")
	game.call("_show_menu")
	for i in range(20):
		await process_frame
	await create_timer(0.8).timeout
	for i in range(8):
		await process_frame
	await _shot(out, "02_title_jogar.png")

	# Also dump button world Y extents for log
	var nodes: Array = game.get("title_menu_btn_nodes")
	var ys: Array = []
	for n in nodes:
		if n != null and is_instance_valid(n):
			ys.append("%.3f:%s" % [n.position.y, str(n.get_meta("title_label"))])
	print("TITLE_JOGAR_BTNS=", ",".join(ys))
	print("TITLE_MENU_SCALE=", game.get("title_menu_3d").scale if game.get("title_menu_3d") else "?")
	print("TitleMenuShot OK out=", out)
	quit(0)

func _shot(dir: String, name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		push_error("null screenshot image for %s" % name)
		return
	var path := "%s/%s" % [dir, name]
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
