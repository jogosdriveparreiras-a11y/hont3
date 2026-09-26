extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var dirs: Array[String] = ["/workspace", "/tmp/hotn3_shots"]
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", false)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	if game.get("sound") != null:
		game.call("_set_volume", 0.0, "MASTER")
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	game.call("_start_mission")
	for i in range(30):
		await process_frame
	await create_timer(1.2).timeout
	for i in range(25):
		await process_frame
	_save(dirs, "playtest_hotn3_pass2_battle.png")
	_save(dirs, "playtest_hotn3_pass2_hud.png")
	var battle = game.get("battle")
	if battle != null and battle.hand.size() > 0:
		game.set("hovered_card", 0)
		game.call("_refresh_hero_hud")
		game.call("_render_battle")
		for i in range(18):
			await process_frame
		_save(dirs, "playtest_hotn3_pass2_hover.png")
		# Prefer a damage card for inspect so shield icon is visible
		var dmg_idx := 0
		for i in range(battle.hand.size()):
			var def: Dictionary = game.call("_card_def", str(battle.hand[i]["id"]))
			if game.call("_card_has_damage", def):
				dmg_idx = i
				break
		game.set("inspected_card", dmg_idx)
		game.set("hovered_card", dmg_idx)
		game.call("_render_battle")
		for i in range(28):
			await process_frame
		_save(dirs, "playtest_hotn3_pass2_inspect.png")
		game.call("_confirm_inspected")
		for i in range(22):
			await process_frame
		_save(dirs, "playtest_hotn3_pass2_target.png")
		_save(dirs, "playtest_hotn3_pass2_after.png")
	print("VISUAL_PLAYTEST_DONE")
	quit(0)

func _save(dirs: Array[String], name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("VISUAL FAIL null image for " + name)
		return
	for d in dirs:
		var path := String(d).path_join(name)
		var err := img.save_png(path)
		print("VISUAL save %s err=%d" % [path, err])
