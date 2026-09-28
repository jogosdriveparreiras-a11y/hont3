extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var out := ProjectSettings.globalize_path("res://playtest_out/ux20260927")
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
	game.set("sensitive_content", false)
	var original_sprite := "res://assets/cast/ent_adam_sprite.png"
	var safe_sprite := str(game.call("_sensitive_path", original_sprite, "sprite"))
	if not safe_sprite.begins_with("res://assets/cast_sensitive/"):
		push_error("Conteúdo sensível = Não não selecionou cast_sensitive: " + safe_sprite)
		quit(1)
	game.set("sensitive_content", true)
	if str(game.call("_sensitive_path", original_sprite, "sprite")) != original_sprite:
		push_error("Conteúdo sensível = Sim não preservou o cast original")
		quit(1)
	game.set("sensitive_content", true)
	game.set("battle_view_mode", "normal")
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.5).timeout
	_assert_children_inside(game.hero_hud, "HUD do herói")
	await _shot(out, "01_battle_normal.png")
	if game.battle != null and game.battle.hand.size() > 0:
		game.set_process(false)
		game.set("hovered_card", 0)
		for i in range(8):
			game.call("_update_hand_card_visuals")
			await process_frame
		await _shot(out, "02_card_hover.png")
		game.set_process(true)

	# First click: fixed, complete card in the same central presentation used by enemies.
	if game.battle != null and game.battle.hand.size() > 0:
		game.call("_select_card", 0)
		for i in range(12):
			await process_frame
		var selected_overlay: Control = game.hud.get_node_or_null("SelectedCardOverlay")
		if selected_overlay == null:
			push_error("Primeiro clique não criou SelectedCardOverlay")
			quit(1)
		var viewport_size := root.get_viewport().get_visible_rect().size
		var selected_end := selected_overlay.position + selected_overlay.size
		if selected_overlay.position.x < 0.0 or selected_overlay.position.y < 0.0 or selected_end.x > viewport_size.x or selected_end.y > viewport_size.y:
			push_error("Carta selecionada fora do viewport: %s / %s" % [selected_overlay.get_rect(), viewport_size])
			quit(1)
		await _shot(out, "03_card_selected_center.png")

		# Open inspect via button path
		game.call("_open_inspect", 0)
		for i in range(14):
			await process_frame
		await _shot(out, "04_inspect_overlay.png")
		game.call("_cancel_inspect")
		for i in range(8):
			await process_frame

		# Confirm targeting
		game.set("selected_card", 0)
		game.call("_confirm_selected_card", 0)
		for i in range(14):
			await process_frame
		await _shot(out, "05_confirm_targeting.png")

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
	_assert_lateral_order(game)
	await _shot(out, "06_battle_lateral.png")

	# Block sensitive content: use the safe cast alternatives.
	game.set("sensitive_content", false)
	game.call("_clear_combat_visuals")
	game.call("_render_battle")
	for i in range(16):
		await process_frame
	await _shot(out, "07_safe_cast.png")

	# Confirm that Alyssa and Dominika render from their exact files in assets/cast.
	game.set("sensitive_content", true)
	game.set("battle_view_mode", "normal")
	game.set("mission_id", "road")
	game.set("team", ["ent_alyssa_wine", "ent_dominika_seur", "ent_adam"] as Array[String])
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.5).timeout
	_assert_actor_texture(game, "ent_alyssa_wine", "res://assets/cast/ent_alyssa_wine_sprite.png")
	_assert_actor_texture(game, "ent_dominika_seur", "res://assets/cast/ent_dominika_seur_sprite.png")
	await _shot(out, "08_alyssa_dominika_cast.png")

	# Block popup demo
	game.set("sensitive_content", true)
	game.call("_show_block_popup", "Você precisa de Escuridão 3 para usar esta Manobra")
	for i in range(10):
		await process_frame
	await _shot(out, "09_block_popup.png")

	print("OK: UxBattleShots")
	quit(0)

func _assert_lateral_order(game) -> void:
	var camera: Camera3D = game.get("camera")
	var xs := PackedFloat32Array()
	for spec in [["ALLY", "back"], ["ALLY", "front"], ["ENEMY", "front"], ["ENEMY", "back"]]:
		var matching: Array = game.battle.living(spec[0]).filter(func(actor): return actor.get("row", "") == spec[1])
		if matching.is_empty():
			continue
		var actor_id := int(matching[0]["id"])
		var body: Node3D = game.actor_nodes[actor_id]
		xs.append(camera.unproject_position(body.global_position).x)
	for i in range(1, xs.size()):
		if xs[i] <= xs[i - 1]:
			push_error("Lateral fora de ordem na tela: %s" % [xs])
			quit(1)

func _assert_actor_texture(game, archetype: String, expected_path: String) -> void:
	var matching: Array = game.battle.actors.filter(func(entry): return entry.get("archetype", "") == archetype and entry.get("side", "") == "ALLY")
	if matching.is_empty():
		push_error("Ator não encontrado na captura: " + archetype)
		quit(1)
		return
	var actor: Dictionary = matching[0]
	var avatar: Sprite3D = game.actor_nodes[int(actor["id"])].get_node("Avatar")
	var actual := str(avatar.texture.resource_path)
	if avatar.texture is AtlasTexture:
		actual = str((avatar.texture as AtlasTexture).atlas.resource_path)
	if actual != expected_path:
		push_error("Textura incorreta para %s: %s (esperada %s)" % [archetype, actual, expected_path])
		quit(1)

func _assert_children_inside(control: Control, label: String) -> void:
	if control == null:
		push_error(label + " não existe")
		quit(1)
		return
	for child in control.get_children():
		if not child is Control or not child.visible:
			continue
		var widget := child as Control
		var end := widget.position + widget.size
		if widget.position.x < 0.0 or widget.position.y < 0.0 or end.x > control.size.x + 0.5 or end.y > control.size.y + 0.5:
			push_error("%s contém %s fora do painel: %s / %s" % [label, widget.name, widget.get_rect(), control.size])
			quit(1)

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
