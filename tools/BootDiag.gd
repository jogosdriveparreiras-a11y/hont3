extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	print("BOOTDIAG_START")
	var script = load("res://game/GameRoot.gd")
	print("BOOTDIAG_SCRIPT=", script != null)
	var scene: PackedScene = load("res://game/GameRoot.tscn")
	print("BOOTDIAG_SCENE=", scene != null)
	var game = scene.instantiate()
	print("BOOTDIAG_INST=", game != null, " has_script=", game.get_script() != null)
	root.add_child(game)
	await process_frame
	await process_frame
	print("BOOTDIAG_HUD=", game.get("hud") != null)
	if game.get("session_report") != null:
		print("BOOTDIAG_REPORT_PATH=", game.session_report.absolute_path())
	var hud = game.get("hud")
	if hud != null:
		print("BOOTDIAG_HUD_CHILDREN=", hud.get_child_count(), " size=", hud.size)
	print("BOOTDIAG_OK")
	quit(0)