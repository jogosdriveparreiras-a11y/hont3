extends SceneTree

const Content = preload("res://game/Content.gd")

# Execute após a importação: godot --headless --path . -s res://tools/SceneSmoke.gd
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://game/GameRoot.tscn")
	assert(scene != null, "A cena principal deve carregar")
	var game = scene.instantiate()
	assert(game != null, "A cena principal deve instanciar")
	root.add_child(game)
	await process_frame
	assert(game.get("hud") != null, "O menu deve criar a interface")
	assert(game.get("sound") != null and game.get("presentation") != null, "Áudio e apresentação devem inicializar")
	for action in ["hotn_next", "hotn_previous", "hotn_target_next", "hotn_confirm", "hotn_redraw", "hotn_end", "hotn_move"]:
		assert(InputMap.has_action(action), "Controle ausente: " + action)
	game.call("_set_volume", 0.2, "SFX")
	assert(is_equal_approx(game.get("sound_levels")["SFX"], 0.2), "Volume deve ser ajustável")
	game.set("reduce_motion", false)
	game.call("_toggle_motion")
	assert(game.get("reduce_motion"), "Redução de movimento deve ser ajustável")
	game.set("reduce_motion", false)
	game.set("best_stars", {})
	game.set("improvements", {})
	game.set("essence", 0)
	assert(game.call("_mission_unlocked", "road"), "Primeira missão deve estar disponível")
	assert(not game.call("_mission_unlocked", "eclipse"), "Chefe exige as duas missões intermediárias")
	assert(game.call("_award_victory", 1) == 5, "Primeira vitória deve conceder bônus e duas Essências por estrela")
	assert(game.call("_award_victory", 1) == 0, "Repetir desempenho não pode acumular Essência")
	assert(game.call("_mission_unlocked", "ritual") and game.call("_mission_unlocked", "watch"), "Vitória inicial libera o meio da campanha")
	var test_stars: Dictionary = game.get("best_stars")
	test_stars["ritual"] = 1
	assert(not game.call("_mission_unlocked", "eclipse"), "Chefe exige duas vitórias intermediárias")
	test_stars["watch"] = 1
	assert(game.call("_mission_unlocked", "eclipse"), "Chefe deve abrir após as duas missões")
	game.set("best_stars", {})
	game.set("essence", 3)
	game.call("_upgrade_card", "mago:raio")
	assert(game.get("essence") == 0 and game.get("improvements")["mago:raio"]["upgrade"] >= 1, "Melhoria deve gastar Essência")
	game.call("_upgrade_card", "mago:raio")
	assert(game.get("essence") == 0, "Melhoria sem recursos não deve progredir")
	# Equipe sem conflito com inimigos da missão "road"
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	game.set("mission_id", "road")
	game.call("_show_collection_screen")
	await process_frame
	game.call("_ensure_owned_cards")
	var owned_deck: Array = game.call("_combat_deck_for_hero", "ent_adam")
	assert(owned_deck.size() >= 5, "Coleção inicial deve formar o deck automaticamente")
	var adam: Dictionary = Content.HEROES["ent_adam"]
	if not adam.get("evoluidas", []).is_empty():
		var reward_card := str(adam["evoluidas"][0])
		game.call("_grant_owned_card", "ent_adam", reward_card)
		assert(game.call("_combat_deck_for_hero", "ent_adam").has(reward_card), "Carta adquirida deve entrar automaticamente no deck")
	# Conflito de herói único vs pool inimigo
	assert(game.call("_hero_conflicts_with_mission", "ent_akuji", "road"), "Akuji deve conflitar com a estrada")
	assert(not game.call("_hero_conflicts_with_mission", "ent_adam", "road"), "Adam não conflita com a estrada")
	game.call("_start_mission")
	await process_frame
	var battle: HotNBattle = game.get("battle")
	assert(battle != null and battle.phase == "PLAYER", "A missão deve entrar na fase do jogador")
	assert(battle.living("ALLY").size() == 3 and battle.living("ENEMY").size() > 0, "Equipes devem aparecer")
	assert(game.get("card_meshes").size() == battle.hand.size(), "Cada carta comprada deve ter malha 3D")
	assert(game.get("actor_nodes").size() == battle.living("ALLY").size() + battle.living("ENEMY").size(), "Personagens devem ter nós visuais persistentes")
	game.call("_render_battle")
	assert(game.get("actor_nodes").size() == battle.living("ALLY").size() + battle.living("ENEMY").size(), "Atualizar interface não deve duplicar personagens")
	for resolution in [Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		game.call("_render_battle")
		await process_frame
		var hud: Control = game.get("hud")
		var right_panel: ScrollContainer = hud.get_node_or_null("RightPanel")
		assert(right_panel != null, "Painel direito deve existir")
		assert(game.get("hero_hud") != null, "HUD do herói deve existir")
		assert(game.get("economy_hud") != null, "HUD de economia deve existir")
		var space := game.get_viewport().get_visible_rect().size
		assert(right_panel.position.x + right_panel.size.x <= space.x + 1.0, "Painel direito precisa caber na viewport")
		assert(right_panel.position.y + right_panel.size.y < space.y - 40.0, "Painel direito não pode cobrir a base inteira")
	battle.end_player_turn()
	await process_frame
	assert(battle.phase in ["PLAYER", "FINISHED"] and battle.turn >= 2, "O turno inimigo deve terminar")
	print("OK: cena, menu, controles, ajustes, atores persistentes, coleção automática, cartas 3D e turno")
	quit(0)
