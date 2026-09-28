extends SceneTree

const Content = preload("res://game/Content.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out := ProjectSettings.globalize_path("res://playtest_out/ux20260928_pass")
	DirAccess.make_dir_recursive_absolute(out)
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", false)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_alyssa_wine", "ent_adam", "ent_madelyn"] as Array[String])
	game.set("sensitive_content", true)
	game.set("battle_view_mode", "lateral")
	game.call("_start_mission")
	for i in range(50):
		await process_frame
	await create_timer(0.5).timeout

	# Garante cartas Alyssa na mão para testes de Escuridão / face.
	if game.battle != null:
		var alyssa_id: int = -1
		for actor in game.battle.living("ALLY"):
			if str(actor.get("archetype", "")) == "ent_alyssa_wine" or "Wine" in str(actor.get("name", "")):
				alyssa_id = int(actor["id"])
				break
		if alyssa_id < 0:
			for actor in game.battle.living("ALLY"):
				alyssa_id = int(actor["id"])
				break
		for cid in ["ent_alyssa_wine_garras_e_presas", "ent_alyssa_wine_bastao_retratil"]:
			if not Content.CARDS.has(cid):
				continue
			var card: Dictionary = game.battle._create_card(cid, alyssa_id)
			if not card.is_empty():
				game.battle.hand.append(card)
		# Zera Escuridão para o popup de requisito.
		var aly: Dictionary = game.battle.actor_by_id(alyssa_id)
		if not aly.is_empty() and aly.has("statuses"):
			aly["statuses"].erase("escuridao")
		game.call("_render_battle")
		for i in range(12):
			await process_frame

	# Breath visible: process a few frames with reduce_motion false
	var sy0 := 1.0
	var sy1 := 1.0
	if game.unit_sprites.size() > 0 and is_instance_valid(game.unit_sprites[0]):
		sy0 = game.unit_sprites[0].scale.y
		for i in range(20):
			await process_frame
		sy1 = game.unit_sprites[0].scale.y
	await _shot(out, "01_lateral_breath.png")
	print("breath scales sample: ", sy0, " -> ", sy1)

	# Escuridão gate: find Garras e Presas
	var garras := -1
	if game.battle != null:
		for i in range(game.battle.hand.size()):
			var cid := str(game.battle.hand[i].get("id", ""))
			if "garras" in cid:
				garras = i
				break
	if garras >= 0:
		var reason: String = game.call("_card_require_status_reason", garras)
		print("garras require: ", reason)
		if reason == "" or not reason.begins_with("Requer:"):
			# Alyssa may already have Escuridão from something — inject 0 by clearing
			var owner_id := int(game.battle.hand[garras].get("owner", -1))
			var actor: Dictionary = game.battle.actor_by_id(owner_id)
			if actor.has("statuses"):
				actor["statuses"].erase("escuridao")
			reason = game.call("_card_require_status_reason", garras)
			print("garras require after clear: ", reason)
		game.call("_select_card", garras)
		for i in range(16):
			await process_frame
		await _shot(out, "02_escuridao_popup.png")
		# dismiss popup if any
		var popup = game.hud.get_node_or_null("BlockPopup")
		if popup != null:
			popup.queue_free()
		await process_frame

	# Target preview + confirm with a normal ENEMY card
	var enemy_card := -1
	for i in range(game.battle.hand.size()):
		var def: Dictionary = game.call("_card_def", str(game.battle.hand[i].get("id", "")))
		var reason2: String = game.call("_card_require_status_reason", i)
		if reason2 != "":
			continue
		if str(def.get("target", "")) in ["ENEMY", "SINGLE"] and game.call("_card_has_damage", def):
			enemy_card = i
			break
	if enemy_card < 0:
		push_error("No free ENEMY damage card")
		quit(1)
	game.call("_select_card", enemy_card)
	for i in range(10):
		await process_frame
	game.call("_confirm_selected_card", enemy_card)
	for i in range(12):
		await process_frame
	var enemy_id: int = -1
	for actor in game.battle.living("ENEMY"):
		enemy_id = int(actor["id"])
		break
	var hand_before: int = game.battle.hand.size()
	game.call("_activate_actor", enemy_id)
	for i in range(16):
		await process_frame
	await _shot(out, "03_target_forecast_confirm.png")
	if int(game.get("pending_target_id")) != enemy_id:
		push_error("pending_target_id missing")
		quit(1)
	if game.battle.hand.size() != hand_before:
		push_error("Resolved instantly")
		quit(1)
	if game.hud.get_node_or_null("PendingTargetActions") == null:
		push_error("Confirm UI missing")
		quit(1)
	var preview_n: int = int(game.damage_preview_by_actor.size())
	print("damage_preview entries: ", preview_n)
	# FOV must stay near base in lateral (no hand zoom)
	var fov := float(game.camera.fov) if game.camera != null else -1.0
	print("lateral fov after sprite focus: ", fov)
	if fov > 0.0 and fov < 38.0:
		push_error("FOV zoomed in too far (hand zoom risk): %s" % fov)
		quit(1)

	game.call("_confirm_pending_target")
	for i in range(30):
		await process_frame
	await _shot(out, "04_after_resolve_fx.png")

	# Card face / inspect Garras com Escuridão 3 (texto amplificado verde).
	var garras2: int = -1
	for i in range(game.battle.hand.size()):
		if "garras" in str(game.battle.hand[i].get("id", "")):
			garras2 = i
			break
	if garras2 < 0:
		var aid: int = -1
		for actor in game.battle.living("ALLY"):
			if str(actor.get("archetype", "")) == "ent_alyssa_wine":
				aid = int(actor["id"]); break
		if aid >= 0:
			game.battle.hand.append(game.battle._create_card("ent_alyssa_wine_garras_e_presas", aid))
			garras2 = game.battle.hand.size() - 1
	if garras2 >= 0:
		var oid2: int = int(game.battle.hand[garras2].get("owner", -1))
		var a2: Dictionary = game.battle.actor_by_id(oid2)
		if not a2.is_empty():
			game.battle._add_status(a2, "escuridao", 99, 3, oid2)
		game.call("_render_battle")
		for i in range(10):
			await process_frame
		game.call("_select_card", garras2)
		for i in range(8):
			await process_frame
		game.call("_open_inspect", garras2)
		for i in range(14):
			await process_frame
		await _shot(out, "05_inspect_glossary.png")

	print("UX PASS 20260928 OK")
	quit(0)

func _shot(dir: String, name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name))
	print("shot ", name)
