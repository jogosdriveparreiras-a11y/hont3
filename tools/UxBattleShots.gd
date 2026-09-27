extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out := "/workspace/hont3/playtest_out/ux20260927"
	DirAccess.make_dir_recursive_absolute(out)
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", true)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	game.set("battle_view_mode", "normal")
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.5).timeout
	_shot(out, "01_battle_normal.png")

	# Select first card (no inspect overlay)
	if game.battle != null and game.battle.hand.size() > 0:
		game.set("selected_card", 0)
		game.set("inspected_card", -1)
		game.set("inspect_open", false)
		game.set("card_confirmed", false)
		game.call("_render_battle")
		for i in range(12):
			await process_frame
		_shot(out, "02_card_selected_inspecionar.png")

		# Open inspect via button path
		game.call("_open_inspect", 0)
		for i in range(14):
			await process_frame
		_shot(out, "03_inspect_overlay.png")
		game.call("_cancel_inspect")
		for i in range(8):
			await process_frame

		# Confirm targeting
		game.set("selected_card", 0)
		game.call("_confirm_selected_card", 0)
		for i in range(14):
			await process_frame
		_shot(out, "04_confirm_targeting.png")

	# Lateral view + row lines + enemy flip
	game.set("selected_card", -1)
	game.set("card_confirmed", false)
	game.set("inspect_open", false)
	game.set("battle_view_mode", "lateral")
	game.call("_apply_battle_view")
	game.call("_build_arena", game.call("_arena_theme_for_mission", "road"))
	game.call("_render_battle")
	print("phase=", game.call("_phase_prompt_text"), " view=", game.get("battle_view_mode"))
	for i in range(20):
		await process_frame
	_shot(out, "05_battle_lateral.png")

	# Sensitive toggle
	game.set("sensitive_content", true)
	game.call("_clear_combat_visuals")
	game.call("_render_battle")
	for i in range(16):
		await process_frame
	_shot(out, "06_sensitive_placeholders.png")

	# Block popup demo
	game.set("sensitive_content", false)
	game.call("_show_block_popup", "Você precisa de Escuridão 3 para usar esta Manobra")
	for i in range(10):
		await process_frame
	_shot(out, "07_block_popup.png")

	print("OK: UxBattleShots")
	quit(0)

func _shot(dir: String, name: String) -> void:
	await process_frame
	await process_frame
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img == null:
		img = DisplayServer.screen_get_image(0)
	if img != null:
		img.save_png(dir.path_join(name))
		print("saved ", name, " ", img.get_width(), "x", img.get_height())
	else:
		print("FAIL shot ", name)
