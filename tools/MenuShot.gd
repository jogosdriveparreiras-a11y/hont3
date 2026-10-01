extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: PackedScene = load("res://game/GameRoot.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var outp := "user://playtest_shots/menu_boot.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest_shots"))
	img.save_png(outp)
	print("MENU_SHOT=", ProjectSettings.globalize_path(outp), " hud=", game.get("hud") != null, " children=", game.hud.get_child_count() if game.get("hud") else -1)
	# Also check if center panel exists
	var found_title := false
	if game.get("hud") != null:
		for n in game.hud.find_children("*", "Label", true, false):
			if str(n.text).contains("HEROES") or str(n.text).contains("NIGHTMARE"):
				found_title = true
				print("MENU_TITLE_LABEL=", n.text)
	print("MENU_TITLE_FOUND=", found_title)
	quit(0 if found_title else 2)