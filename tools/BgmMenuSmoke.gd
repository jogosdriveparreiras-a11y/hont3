extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var out := ProjectSettings.globalize_path("res://playtest_out/bgm_menu_20260928")
	DirAccess.make_dir_recursive_absolute(out)

	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	for i in range(20):
		await process_frame

	# Mute for CI; we only assert track ids / UI.
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	for ch in ["MASTER", "MUSIC", "SFX", "UI", "AMBIENCE"]:
		if game.sound != null:
			game.sound.set_level(ch, 0.0)

	var menu_default: String = str(game.get("MENU_BGM_DEFAULT"))
	if menu_default != "title":
		push_error("MENU_BGM_DEFAULT expected title, got %s" % menu_default)
		quit(1)
		return

	# Title screen should play title (unless __stop__)
	game.set("bgm_track", "title")
	game.call("_ensure_bgm_for", "menu")
	await process_frame
	var cur := str(game.sound.current_bgm) if game.sound else ""
	if cur != "title":
		push_error("Menu BGM expected title, got %s" % cur)
		quit(1)
		return
	await _shot(out, "01_title_menu.png")

	# Settings: Tocar after Parar must resume pick, not __stop__
	game.call("_show_settings")
	await process_frame
	game.call("_stop_bgm_setting")
	await process_frame
	if str(game.get("bgm_track")) != "__stop__":
		push_error("Parar did not set __stop__")
		quit(1)
		return
	var pick := str(game.call("_bgm_resolve_pick"))
	if pick == "" or pick == "__stop__":
		push_error("bgm_pick lost after stop: %s" % pick)
		quit(1)
		return
	game.call("_apply_bgm_track", pick)
	await process_frame
	if str(game.sound.current_bgm) == "__stop__":
		push_error("Tocar/apply still stopped after resume")
		quit(1)
		return
	await _shot(out, "02_settings_bgm.png")

	# Battle default
	game.set("bgm_track", "title")  # menu default → battle should switch to Battle1
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	game.set("sensitive_content", true)
	game.set("reduce_motion", true)
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.3).timeout
	var battle_bgm := str(game.sound.current_bgm) if game.sound else ""
	if battle_bgm != "Battle1":
		push_error("Battle BGM expected Battle1, got %s" % battle_bgm)
		quit(1)
		return
	await _shot(out, "03_battle.png")

	game.call("_open_battle_menu")
	for i in range(12):
		await process_frame
	var overlay = game.hud.get_node_or_null("BattleMenuOverlay")
	if overlay == null:
		push_error("Battle menu overlay missing")
		quit(1)
		return
	var found_voltar := false
	for btn in _find_buttons(overlay):
		if str(btn.text).findn("menu principal") >= 0:
			found_voltar = true
			break
	if not found_voltar:
		push_error("Missing 'Voltar ao menu principal' in battle menu")
		quit(1)
		return
	await _shot(out, "04_battle_menu.png")

	game.call("_return_to_main_menu")
	for i in range(16):
		await process_frame
	if game.battle != null:
		push_error("battle not cleared after return to menu")
		quit(1)
		return
	var back := str(game.sound.current_bgm) if game.sound else ""
	# After return, bgm_track was Battle1 from battle ensure (mutated pick); ensure menu runs.
	# _ensure_bgm_for("menu") with bgm_track==Battle1 switches to title.
	if back != "title" and str(game.get("bgm_track")) != "__stop__":
		# If user/battle left a custom track, OK; only fail if silent
		if back == "" or back == "__stop__":
			push_error("Menu silent after return: %s" % back)
			quit(1)
			return
	await _shot(out, "05_back_to_menu.png")

	print("BgmMenuSmoke OK menu=%s battle=Battle1 pick_resume=%s" % [menu_default, pick])
	quit(0)

func _find_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_buttons(c))
	return out

func _shot(dir: String, name: String) -> void:
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [dir, name])
