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
	game.call("_start_mission")
	await process_frame
	var battle: HotNBattle = game.get("battle")
	assert(battle != null and battle.phase == "PLAYER", "A missão deve entrar na fase do jogador")
	assert(battle.living("ALLY").size() == 3 and battle.living("ENEMY").size() > 0, "Equipes devem aparecer")
	assert(game.get("card_meshes").size() == battle.hand.size(), "Cada carta comprada deve ter malha 3D")
	battle.end_player_turn()
	await process_frame
	assert(battle.phase in ["PLAYER", "FINISHED"] and battle.turn >= 2, "O turno inimigo deve terminar")
	print("OK: cena, menu, missão, combate, cartas 3D e transição de turno")
	quit(0)
