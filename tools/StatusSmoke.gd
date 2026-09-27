extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const Content = preload("res://game/Content.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var _packs = PackBridge.new()
	var battle = Battle.new()
	var team: Array[String] = ["guerreiro", "mago", "clerigo"]
	battle.begin("road", team, {}, 42)
	var hero: Dictionary = battle.living("ALLY")[0]
	var enemy: Dictionary = battle.living("ENEMY")[0]
	var strike := {"amount": 5, "stat": "attack"}
	var base: int = battle._damage_value(hero, enemy, strike, {})
	battle._add_status(hero, "weak", 2, 1, int(enemy["id"]))
	assert(battle._damage_value(hero, enemy, strike, {}) < base, "Weak deve reduzir Ataque")
	hero["statuses"].erase("weak")
	battle._add_status(enemy, "vulnerable", 2, 1, int(hero["id"]))
	assert(battle._damage_value(hero, enemy, strike, {}) > base, "Vulnerable deve aumentar dano")
	enemy["statuses"].erase("vulnerable")
	var before: int = enemy["hp"]
	battle._add_status(enemy, "protecao", 2, 1, int(enemy["id"]))
	battle._take_damage(hero, enemy, 5)
	assert(enemy["hp"] == before and not battle._has_status(enemy, "protecao"), "Proteção deve impedir um ataque")
	battle._add_status(enemy, "stun", 2, 1, int(hero["id"]))
	battle._take_damage(hero, enemy, 3)
	assert(not battle._has_status(enemy, "stun"), "Stun deve terminar ao sofrer dano")
	enemy["hp"] = 5
	battle.hand.clear()
	battle.hand.append(battle._create_card("corte", int(hero["id"])))
	battle.card_plays = 3
	assert(battle.play(0, int(enemy["id"])), "Quick deve poder ser jogada")
	assert(battle.card_plays == 3, "Quick deve devolver uma jogada quando elimina")
	var other: Dictionary = battle.living("ENEMY")[0]
	battle._add_status(other, "banished", 1, 1, int(hero["id"]))
	assert(not battle.living("ENEMY").has(other), "Banished deve retirar o alvo da arena")
	assert(other["hp"] > 0, "Banished não é uma eliminação")
	var second = Battle.new()
	second.begin("road", team, {}, 71)
	var allies: Array[Dictionary] = second.living("ALLY")
	var source: Dictionary = allies[2]
	for ally in allies: second._add_status(ally, "soulbound", 1, 1, int(source["id"]))
	allies[0]["hp"] = 0
	allies[1]["block"] = 11
	second._tick_statuses()
	assert(allies[0]["hp"] > 0, "Soulbound deve reviver mesmo na última rodada")
	assert(allies[1]["block"] == 11, "Block não deve desaparecer antes da próxima ação inimiga")
	second._add_status(source, "overload", 1, 1, int(source["id"]))
	second._add_status(source, "drop", 1, 1, int(source["id"]))
	second._cleanse(source)
	assert(not second._has_status(source, "overload") and not second._has_status(source, "drop"), "Cure remove estados negativos")
	second._add_status(source, "slow", 2, 1, int(source["id"]))
	assert(second._cost(source, {"cost": 1, "class": "POWER"}) == 2, "Slow aumenta custo Heroico")
	var third = Battle.new()
	var rogue_team: Array[String] = ["ladino", "guerreiro", "mago"]
	third.begin("road", rogue_team, {}, 73)
	var rogue: Dictionary = third.living("ALLY")[0]
	var first: Dictionary = third.living("ENEMY")[0]
	var second_target: Dictionary = third.living("ENEMY")[1]
	third._add_status(rogue, "make_em_bleed", 2, 2, int(rogue["id"]))
	third.hand.clear()
	third.hand.append(third._create_card("corrente", int(rogue["id"])))
	assert(not third.play(0, int(first["id"]), [first["id"]]) and third.hand.size() == 1, "Chain 3 não pode ser jogada com um acerto")
	assert(third.play(0, int(first["id"]), [first["id"], second_target["id"], first["id"]]), "Chain deve aceitar alvos repetidos")
	assert(third._has_status(rogue, "make_em_bleed") and rogue["statuses"]["make_em_bleed"]["stacks"] == 1, "Make em Bleed usa uma carga por carta")
	var fourth = Battle.new()
	fourth.begin("road", rogue_team, {}, 79)
	var enemy_source: Dictionary = fourth.living("ENEMY")[0]
	var front: Array[Dictionary] = [fourth.living("ALLY")[0], fourth.living("ALLY")[1]]
	fourth._add_status(enemy_source, "fatal_fury", 1, 1, int(enemy_source["id"]))
	fourth._resolve(enemy_source, front, {}, Content.ENEMY_CARDS["sweep"])
	assert(not fourth._has_status(enemy_source, "fatal_fury"), "Fatal Fury consome a ação inteira")
	assert(front.all(func(a): return fourth._has_status(a, "wounded")), "Fatal Fury afeta todos os alvos atingidos")
	var fifth = Battle.new()
	fifth.begin("road", team, {}, 83)
	var spreader: Dictionary = fifth.living("ALLY")[0]
	var opposite: Dictionary = fifth.living("ENEMY")[0]
	opposite["row"] = spreader["row"]
	fifth._add_status(spreader, "corrupted", 2, 1, int(opposite["id"]))
	fifth._tick_statuses()
	assert(fifth._has_status(opposite, "corrupted"), "Corrupted deve atingir unidades próximas de qualquer lado")
	spreader["block"] = 30
	fifth._add_status(spreader, "protecao", 2, 2, int(spreader["id"]))
	fifth._add_status(spreader, "bleed", 2, 1, int(opposite["id"]))
	var bleeding_hp: int = spreader["hp"]
	fifth._tick_statuses()
	assert(spreader["hp"] < bleeding_hp and spreader["block"] == 30 and fifth._has_status(spreader, "protecao") and int(spreader["statuses"]["protecao"]["stacks"]) == 1, "Bleed ignora Bloqueio e Proteção (−1 stack/rodada)")
	var sixth = Battle.new()
	sixth.begin("road", team, {}, 89)
	var pusher: Dictionary = sixth.living("ALLY")[0]
	var pushed: Dictionary = sixth.living("ENEMY")[0]
	pushed["hp"] = sixth._damage_value(pusher, pushed, Content.CARDS["investida"]["effects"][0], {}) + 1
	sixth._add_status(pushed, "marked", 2, 1, int(pusher["id"]))
	sixth.hand.clear()
	sixth.hand.append(sixth._create_card("investida", int(pusher["id"])))
	var impact_preview: Dictionary = sixth.preview(0, int(pushed["id"]))
	assert(impact_preview["targets"][pushed["id"]]["hp_after"] == 0 and impact_preview["targets"][pushed["id"]]["row_after"] == "back", "Prévia deve calcular colisão e mudança de linha")
	assert(pushed["hp"] > 0 and pushed["row"] == "front", "Prévia não deve alterar combate")
	assert(sixth.play(0, int(pushed["id"])), "Investida deve ser jogável")
	assert(pushed["hp"] == 0 and sixth.card_plays == int(sixth.rules["card_plays"]), "Eliminação pelo impacto deve recuperar ação de Marcado")
	var seventh = Battle.new()
	seventh.begin("road", team, {}, 97)
	var warrior: Dictionary = seventh.living("ALLY")[0]
	var mage: Dictionary = seventh.living("ALLY")[1]
	var ranger = Battle.new()
	var scout_team: Array[String] = ["patrulheiro", "paladino", "guerreiro"]
	ranger.begin("road", scout_team, {}, 101)
	var fronts: Array[Dictionary] = ranger._targets(ranger.living("ALLY")[1], ranger.living("ENEMY")[0], Content.CARDS["cerco_frente"])
	assert(fronts.size() >= 2 and fronts.all(func(a): return a["row"] == "front"), "FRONT_ROW afeta apenas a frente")
	var archer: Dictionary = ranger.living("ENEMY")[2]
	var backs: Array[Dictionary] = ranger._targets(ranger.living("ALLY")[0], archer, Content.CARDS["tiro_retaguarda"])
	assert(backs.size() == 1 and backs[0]["row"] == "back", "BACK_ROW afeta apenas a retaguarda")
	var flanks: Array[Dictionary] = seventh._targets(warrior, seventh.living("ENEMY")[1], Content.CARDS["corte_adj"])
	assert(flanks.size() >= 2, "ADJACENT deve alcançar vizinhos da mesma linha")
	var cleric: Dictionary = seventh.living("ALLY")[2]
	var any_card: Dictionary = Content.CARDS["balanca"]
	assert(seventh._targets(cleric, warrior, any_card).size() == 1 and seventh._targets(cleric, seventh.living("ENEMY")[0], any_card).size() == 1, "ANY_UNIT deve admitir aliados e inimigos")
	seventh.hand.clear()
	seventh.hand.append(seventh._create_card("fagulha_incerta", int(mage["id"])))
	var before_random: int = seventh.rng.state
	var uncertain: Dictionary = seventh.preview(0, int(seventh.living("ENEMY")[0]["id"]))
	assert(uncertain["random"] and uncertain["targets"].size() >= 2 and seventh.rng.state == before_random, "Prévia aleatória não deve consumir RNG")
	var eighth = Battle.new()
	eighth.begin("road", team, {}, 109)
	var fading: Dictionary = eighth.living("ALLY")[0]
	eighth._add_status(fading, "en_fuego", 99, 1, int(fading["id"]))
	fading["hp"] = 1
	eighth._add_status(fading, "bleed", 2, 1, int(fading["id"]))
	eighth._tick_statuses()
	assert(fading["hp"] == 0 and int(fading["statuses"]["en_fuego"]["stacks"]) == 1, "Dano próprio não deve contar como eliminação de inimigo")

	# --- Defesa redesenhada + Instantâneo ---
	var defb = Battle.new()
	defb.begin("road", team, {}, 101)
	var tank: Dictionary = defb.living("ALLY")[0]
	var foe: Dictionary = defb.living("ENEMY")[0]
	var hp0: int = int(foe["hp"])
	defb._add_status(foe, "invulnerable", 2, 1, int(foe["id"]))
	defb._take_damage(tank, foe, 9)
	assert(int(foe["hp"]) == hp0, "Invulnerável bloqueia dano")
	var tank2: Dictionary = defb.living("ALLY")[0]
	defb._add_status(tank2, "invulnerable", 2, 1, int(tank2["id"]))
	var self_card_id := "estandarte" if Content.CARDS.has("estandarte") else "corte"
	defb.hand.clear()
	defb.hand.append(defb._create_card(self_card_id, int(tank2["id"])))
	defb.card_plays = 3
	defb.impulse = 5
	var tgt := int(tank2["id"]) if self_card_id == "estandarte" else int(foe["id"])
	assert(defb.play(0, tgt), "Jogar carta limpa Invulnerável")
	assert(not defb._has_status(tank2, "invulnerable"), "Invulnerável some ao jogar carta")

	foe["statuses"].erase("invulnerable")
	foe["statuses"].erase("protecao")
	foe["block"] = 0
	foe["shield"] = 0
	defb._add_status(foe, "barrier", 2, 8, int(foe["id"]))
	var hp1: int = int(foe["hp"])
	assert(defb._barrier_hp(foe) == 8, "Barreira inicia com 8 HP")
	defb._take_damage(tank, foe, 5)
	assert(int(foe["hp"]) == hp1 and defb._barrier_hp(foe) == 3, "Barreira absorve 5 de 8")
	defb._take_damage(tank, foe, 10)
	assert(not defb._has_status(foe, "barrier") and int(foe["hp"]) < hp1, "Overflow da Barreira atinge Vida")

	# Penetrante ignora Barreira por completo (não gasta HP da barreira).
	foe["statuses"].erase("barrier")
	foe["block"] = 0
	foe["shield"] = 0
	defb._add_status(foe, "barrier", 2, 8, int(foe["id"]))
	var hp_pierce: int = int(foe["hp"])
	defb._take_damage(tank, foe, 5, true)
	assert(defb._barrier_hp(foe) == 8 and int(foe["hp"]) == hp_pierce - 5, "Penetrante ignora Barreira e acerta Vida")

	defb._add_status(foe, "resistente", 3, 2, int(foe["id"]))
	defb._add_status(foe, "fragil", 3, 3, int(foe["id"]))
	assert(not defb._has_status(foe, "resistente") and defb._has_status(foe, "fragil") and int(foe["statuses"]["fragil"]["stacks"]) == 1, "Frágil cancela Resistente")

	var inst = Battle.new()
	inst.begin("road", team, {}, 202)
	var owner: Dictionary = inst.living("ALLY")[0]
	var fake := inst._create_card("corte", int(owner["id"]))
	fake["instant"] = true
	inst.hand.clear()
	inst.hand.append(fake)
	assert(inst.hand_has_instantaneo("ALLY"), "Detecta Instantâneo na mão")
	assert(not inst.can_end_turn(), "Instantâneo bloqueia Encerrar")
	inst.request_end_turn = false
	inst.card_plays = 3
	inst.impulse = 5
	var enemy_id: int = int(inst.living("ENEMY")[0]["id"])
	assert(inst.play(0, enemy_id), "Jogar Instantâneo")
	assert(not inst.request_end_turn, "Instantâneo NÃO pede fim de turno")
	assert(inst.can_end_turn(), "Sem Instantâneo na mão, pode encerrar")

	print("OK: estados, Chain, Soulbound, impacto, prévia, alvos especiais e KO próprio")
	quit(0)
