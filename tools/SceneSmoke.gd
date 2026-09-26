extends SceneTree

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
	game.call("_toggle_motion")
	assert(game.get("reduce_motion"), "Redução de movimento deve ser ajustável")
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
	game.call("_show_decks")
	await process_frame
	assert(game.call("_equip_card", "mago", 0, "fagulha_incerta"), "Equipar carta do pool deve funcionar")
	assert(game.call("_equip_card", "mago", 1, "fagulha_incerta"), "Até duas cópias devem ser permitidas")
	assert(not game.call("_equip_card", "mago", 2, "fagulha_incerta"), "A terceira cópia deve ser recusada")
	assert(game.call("_equip_card", "paladino", 0, "cerco_frente"), "Carta rara deve equipar")
	assert(not game.call("_equip_card", "paladino", 1, "cerco_frente"), "Carta de limite um não admite cópia adicional")
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
		var left_panel: ScrollContainer = hud.get_node("LeftPanel")
		var right_panel: ScrollContainer = hud.get_node("RightPanel")
		var hand_scroller: ScrollContainer = hud.get_node("HandScroller")
		assert(left_panel.position.x + left_panel.size.x < right_panel.position.x, "Painéis laterais não podem se sobrepor")
		assert(left_panel.position.y + left_panel.size.y < hand_scroller.position.y, "Painéis devem terminar antes da mão")
		assert(hand_scroller.position.x + hand_scroller.size.x <= resolution.x, "Mão precisa caber na viewport")
	battle.end_player_turn()
	await process_frame
	assert(battle.phase in ["PLAYER", "FINISHED"] and battle.turn >= 2, "O turno inimigo deve terminar")
	print("OK: cena, menu, controles, ajustes, atores persistentes, decks, cartas 3D e turno")
	quit(0)
