extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out := ProjectSettings.globalize_path("res://playtest_out/ux20260928_fixes")
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
	game.set("sensitive_content", true)
	game.set("battle_view_mode", "lateral")
	game.call("_start_mission")
	for i in range(45):
		await process_frame
	await create_timer(0.4).timeout

	if game.hud.get_node_or_null("BattleMenuButton") == null:
		push_error("Menu button missing at battle start")
		quit(1)

	# Hand hover: only hovered card scales
	if game.battle != null and game.battle.hand.size() > 0:
		game.set_process(false)
		game.set("hovered_card", 0)
		if game.presentation != null:
			game.presentation.zoom = 1.55
		for i in range(12):
			game.call("_update_hand_card_visuals")
			game.call("_compensate_hand_for_camera_fov")
			await process_frame
		await _shot(out, "01_hand_hover_no_group_zoom.png")
		var meshes: Array = game.get("card_meshes")
		if meshes.size() > 1:
			var h: MeshInstance3D = meshes[0]
			var o: MeshInstance3D = meshes[1]
			if h.scale.x <= 1.05:
				push_error("Hovered card did not scale up")
				quit(1)
			if o.scale.x > 1.05:
				push_error("Non-hovered card was scaled")
				quit(1)
		game.set_process(true)

	# Pick ENEMY-target damage card for selection / targeting flow
	var enemy_card: int = _find_enemy_card(game)
	if enemy_card < 0:
		push_error("No ENEMY-target card in hand")
		quit(1)
	game.call("_select_card", enemy_card)
	for i in range(12):
		await process_frame
	await _shot(out, "02_selected_card_mode.png")
	if game.hud.get_node_or_null("SelectedCardOverlay") == null:
		push_error("Selected overlay missing")
		quit(1)

	game.call("_confirm_selected_card", enemy_card)
	for i in range(14):
		await process_frame
	await _shot(out, "03_targeting_mode.png")
	if not bool(game.get("card_confirmed")):
		push_error("card_confirmed false after confirm (auto-resolved?)")
		quit(1)

	var enemy_id: int = -1
	for actor in game.battle.living("ENEMY"):
		enemy_id = int(actor["id"])
		break
	var hand_before: int = game.battle.hand.size()
	game.call("_activate_actor", enemy_id)
	for i in range(14):
		await process_frame
	await _shot(out, "04_target_preview_confirm.png")
	if int(game.get("pending_target_id")) != enemy_id:
		push_error("pending_target_id not set (got %s)" % str(game.get("pending_target_id")))
		quit(1)
	if game.battle.hand.size() != hand_before:
		push_error("Card resolved immediately on enemy click")
		quit(1)
	if game.hud.get_node_or_null("PendingTargetActions") == null:
		push_error("Pending target confirm UI missing")
		quit(1)

	game.call("_confirm_pending_target")
	for i in range(24):
		await process_frame
	await _shot(out, "05_after_confirm_resolve.png")

	game.call("_open_battle_menu")
	for i in range(12):
		await process_frame
	await _shot(out, "06_battle_menu.png")
	if game.hud.get_node_or_null("BattleMenuOverlay") == null:
		push_error("Battle menu overlay missing")
		quit(1)
	game.call("_set_weather", "rain")
	for i in range(10):
		await process_frame
	await _shot(out, "07_weather_rain.png")
	game.call("_close_battle_menu")

	# Fresh battle for Impacto / icons shot
	game.set("battle_view_mode", "normal")
	game.call("_apply_battle_view")
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.3).timeout
	var dmg_idx: int = _find_enemy_card(game)
	if dmg_idx < 0:
		dmg_idx = 0
	game.call("_select_card", dmg_idx)
	for i in range(12):
		await process_frame
	await _shot(out, "08_impacto_left_short_text.png")
	await _shot(out, "09_hp_type_icons.png")

	var any_icon: bool = false
	for id in game.actor_nodes.keys():
		var body: Node3D = game.actor_nodes[id]
		var plate: Label3D = body.get_node_or_null("Nameplate")
		if plate == null:
			continue
		var txt := str(plate.text)
		if "💥" in txt or "⚔️" in txt or "👁️" in txt or "🎭" in txt or "⚡" in txt or "🧪" in txt or txt.contains(" "):
			# Icon prefix present (emoji or spaced number)
			if txt.find("/") > 0 and not txt.begins_with(str(int(txt.substr(0, 1)) if txt.substr(0,1).is_valid_int() else "x")):
				any_icon = true
				break
			any_icon = true
			break
	if not any_icon:
		push_error("Type icons missing from HP nameplates")
		quit(1)

	var src := FileAccess.get_file_as_string("res://game/GameRoot.gd")
	if "vp.warp_mouse" in src:
		push_error("warp_mouse still called")
		quit(1)

	print("OK: UxFixes20260928")
	quit(0)

func _find_enemy_card(game) -> int:
	if game.battle == null:
		return -1
	for i in range(game.battle.hand.size()):
		var def: Dictionary = game.call("_card_def", str(game.battle.hand[i]["id"]))
		var tgt := str(def.get("target", "ENEMY"))
		if tgt in ["ENEMY", "SINGLE", "ANY_UNIT", "ALLY"] and bool(game.call("_card_has_damage", def)):
			# Needs player choice
			if bool(game.call("_target_needs_player_choice", tgt)):
				return i
	for i in range(game.battle.hand.size()):
		var def2: Dictionary = game.call("_card_def", str(game.battle.hand[i]["id"]))
		if bool(game.call("_target_needs_player_choice", str(def2.get("target", "ENEMY")))):
			return i
	return -1

func _shot(out: String, name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		push_error("null screenshot " + name)
		return
	var path := out.path_join(name)
	img.save_png(path)
	print("saved ", name, " ", img.get_width(), "x", img.get_height())
