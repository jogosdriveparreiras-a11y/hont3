extends SceneTree
## Smoke: mão inimiga sem cartas de morto; recompra não queima cartas com dono só em bind.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const Content = preload("res://game/Content.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _ok(msg: String) -> void:
	print("OK: ", msg)

func _initialize() -> void:
	var _packs = PackBridge.new()
	var battle = Battle.new()
	battle.begin("road", ["guerreiro", "mago", "clerigo"], {}, 202)
	if battle.living("ENEMY").size() < 2:
		_fail("precisa de 2+ inimigos na mission road"); return
	var a: Dictionary = battle.living("ENEMY")[0]
	var b: Dictionary = battle.living("ENEMY")[1]
	# Simula carta do morto na mão inimiga + carta viva.
	a["hp"] = 0
	battle.enemy_hand.clear()
	battle.enemy_hand.append(battle._create_card("ent_akuji_brasa_negra", int(a["id"])))
	battle.enemy_hand.append(battle._create_card("ent_akuji_chama_sem_luz", int(b["id"])))
	battle._purge_dead_cards()
	for card in battle.enemy_hand:
		if int(card.get("owner", -1)) == int(a["id"]):
			_fail("purge deveria remover carta do morto da enemy_hand"); return
	if battle.enemy_hand.size() != 1:
		_fail("mão inimiga deveria ficar com 1 carta viva"); return
	_ok("purge remove morto da enemy_hand")

	# Bind no único vivo: sem jogada legal → recompra deve recusar (não queimar mão).
	for enemy in battle.actors:
		if enemy.get("side", "") == "ENEMY" and int(enemy.get("id", -1)) != int(b["id"]):
			enemy["hp"] = 0
	battle._purge_dead_cards()
	if battle.living("ENEMY").size() != 1:
		_fail("deveria restar só 1 inimigo vivo"); return
	battle.phase = "ENEMY"
	battle.enemy_card_plays = 3
	battle.enemy_redraws = 2
	battle.enemy_impulse = 0
	b["statuses"] = {"bind": {"stacks": 1, "duration": 1, "source": int(b["id"])}}
	# Coloca só carta barata do dono bound.
	battle.enemy_hand.clear()
	var pick := ""
	for cid in Content.CARDS.keys():
		var d: Dictionary = Content.CARDS[cid]
		if str(cid).begins_with("ent_") and str(d.get("target", "")) == "SELF" and int(d.get("cost", 0)) == 0:
			pick = str(cid)
			break
	if pick == "":
		_fail("sem carta SELF cost 0 ent_ após merge"); return
	battle.enemy_hand.append(battle._create_card(pick, int(b["id"])))
	var choice: Dictionary = battle.peek_enemy_play()
	if not choice.is_empty():
		_fail("com dono em bind e só carta própria, peek deveria ser vazio (sem recompra suicida); got %s" % str(choice)); return
	var diag: Array = battle.diagnose_enemy_hand()
	if diag.is_empty() or str(diag[0].get("reason", "")) != "owner_locked":
		_fail("diagnose deveria marcar owner_locked; got %s" % str(diag)); return
	_ok("bind: sem recompra suicida + diagnose owner_locked")

	# Desbloqueia: deve jogar no self.
	b["statuses"] = {}
	choice = battle.peek_enemy_play()
	if choice.is_empty() or str(choice.get("kind", "")) != "play":
		_fail("dono livre deveria jogar SELF; got %s" % str(choice)); return
	if int(choice.get("target", -1)) != int(b["id"]):
		_fail("SELF deveria mirar o dono"); return
	_ok("SELF mira o dono após liberar bind")

	# Ataque ENEMY deve mirar aliado do jogador.
	var atk := ""
	for cid in Content.CARDS.keys():
		var d2: Dictionary = Content.CARDS[cid]
		if str(cid).begins_with("ent_") and str(d2.get("target", "")) == "ENEMY" and str(d2.get("class", "")) == "ATTACK" and bool(d2.get("reach", false)):
			atk = str(cid)
			break
	if atk == "":
		_fail("sem ataque ent_ ENEMY reach"); return
	b["row"] = "front"
	b["statuses"] = {}
	for ally in battle.living("ALLY"):
		ally["row"] = "front"
		ally["statuses"] = {}
	battle.enemy_hand.clear()
	battle.enemy_hand.append(battle._create_card(atk, int(b["id"])))
	battle.enemy_impulse = 10
	battle.enemy_card_plays = 3
	choice = battle.peek_enemy_play()
	if choice.is_empty() or str(choice.get("kind", "")) != "play":
		_fail("ataque deveria ser jogável; got %s" % str(choice)); return
	var tid := int(choice.get("target", -1))
	var tgt: Dictionary = battle.actor_by_id(tid)
	if tgt.get("side", "") != "ALLY":
		_fail("ataque ENEMY deve mirar ALY (jogador); target side=%s id=%s" % [tgt.get("side", ""), tid]); return
	_ok("ATTACK ENEMY mira unidade do jogador (id=%d)" % tid)
	print("EnemyAiTargetSmoke PASS")
	quit(0)
