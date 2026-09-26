extends SceneTree

# Visual playtest helper. Windowed (NOT --headless):
#   Godot --path . --script res://tools/VisualPlaytest.gd
# Captures PNGs under res://_playtest/ and /workspace when available.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out_dir := ProjectSettings.globalize_path("res://_playtest")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var workspace_dir := "/workspace"
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", true)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	if game.get("sound") != null:
		game.call("_set_volume", 0.0, "MASTER")
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	game.call("_start_mission")
	for i in range(30):
		await process_frame
	await create_timer(1.0).timeout
	for i in range(20):
		await process_frame
	_save(out_dir, workspace_dir, "playtest_hotn3_ui_battle.png")
	_save(out_dir, workspace_dir, "playtest_hotn3_ui_hud.png")
	if game.get("battle") != null and game.get("battle").hand.size() > 0:
		game.set("hovered_card", 0)
		game.call("_render_battle")
		for i in range(15):
			await process_frame
		_save(out_dir, workspace_dir, "playtest_hotn3_ui_hover.png")
		game.set("inspected_card", 0)
		game.call("_render_battle")
		for i in range(25):
			await process_frame
		_save(out_dir, workspace_dir, "playtest_hotn3_ui_inspect.png")
		# Focus economy / hero HUD framing
		_save(out_dir, workspace_dir, "playtest_hotn3_ui_after.png")
	print("VISUAL_PLAYTEST_DONE")
	quit(0)

func _save(out_dir: String, workspace_dir: String, name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name))
	print("VISUAL wrote " + out_dir.path_join(name))
	if DirAccess.dir_exists_absolute(workspace_dir):
		img.save_png(workspace_dir.path_join(name))
		print("VISUAL wrote " + workspace_dir.path_join(name))
