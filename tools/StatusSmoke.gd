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
	second._tick_statuses()
	assert(allies[0]["hp"] > 0, "Soulbound deve reviver mesmo na última rodada")
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
	# Fúria Fatal aplica Ferido apenas aos sobreviventes. Mantenha os alvos
	# vivos para testar a regra, independentemente do balanceamento atual.
	for target in front:
		target["hp"] = 999
		target["max_hp"] = 999
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
	fifth._add_status(spreader, "protecao", 2, 2, int(spreader["id"]))
	fifth._add_status(spreader, "bleed", 2, 1, int(opposite["id"]))
	var bleeding_hp: int = spreader["hp"]
	fifth._tick_statuses()
	assert(spreader["hp"] < bleeding_hp and fifth._has_status(spreader, "protecao") and int(spreader["statuses"]["protecao"]["stacks"]) == 1, "Bleed ignora Proteção (−1 stack/rodada)")
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
	defb._add_status(foe, "barrier", 2, 8, int(foe["id"]))
	var hp1: int = int(foe["hp"])
	assert(defb._barrier_hp(foe) == 8, "Barreira inicia com 8 HP")
	defb._take_damage(tank, foe, 5)
	assert(int(foe["hp"]) == hp1 and defb._barrier_hp(foe) == 3, "Barreira absorve 5 de 8")
	defb._take_damage(tank, foe, 10)
	assert(not defb._has_status(foe, "barrier") and int(foe["hp"]) < hp1, "Overflow da Barreira atinge Vida")

	# Penetrante ignora Barreira por completo (não gasta HP da barreira).
	foe["statuses"].erase("barrier")
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

	# --- Voar: área, ataque direto e colisão ---
	var flight = Battle.new()
	flight.begin("road", team, {}, 303)
	var flyer: Dictionary = flight.living("ENEMY")[0]
	var attacker: Dictionary = flight.living("ALLY")[0]
	flyer["hp"] = 100
	flyer["max_hp"] = 100
	flyer["statuses"].clear()
	flight._add_status(flyer, "voar", 2, 1, int(attacker["id"]))
	flyer["row"] = "front"
	attacker["row"] = "front"
	var hp_area := int(flyer["hp"])
	flight._take_damage(attacker, flyer, 20, false, false, false, true)
	assert(int(flyer["hp"]) == hp_area and flight._has_status(flyer, "flying"), "Voar evita dano de qualquer ataque em área")
	for area_kind in ["ENEMY_ROW", "ALLY_ROW", "ROW", "FRONT_ROW", "BACK_ROW", "ADJACENT", "ALL_ENEMIES", "ALL_ALLIES", "ALL_OTHERS"]:
		assert(flight.is_area_target(area_kind), "Classifica área: %s" % area_kind)
	assert(not flight.can_reach(attacker, flyer, {"target": "ENEMY", "reach": false}), "Alvo voador exige Alcance")
	assert(flight.can_reach(attacker, flyer, {"target": "ENEMY", "reach": true}), "Alcance permite ataque direto contra Voar")
	flight._add_status(attacker, "voar", 2, 1, int(attacker["id"]))
	assert(flight.can_reach(attacker, flyer, {"target": "ENEMY", "reach": false}), "Atacante voando alcança alvo voador")
	attacker["statuses"].erase("flying")
	flight.hand.clear()
	flight.hand.append(flight._create_card("tempestade", int(attacker["id"])))
	var area_preview: Dictionary = flight.preview(0, int(flyer["id"]))
	assert(int(area_preview["targets"][flyer["id"]]["damage"]) == 0 and not area_preview["targets"][flyer["id"]]["statuses"].has("stun"), "Prévia de área omite dano e estados contra Voar")
	flight._take_damage(attacker, flyer, 10, false, false, false, false, false)
	assert(int(flyer["hp"]) == 80 and not flight._has_status(flyer, "voar"), "Ataque direto não corpo a corpo derruba Voar e soma 10% da Vida máxima")
	var collision = Battle.new()
	collision.begin("road", team, {}, 307)
	var collision_target: Dictionary = collision.living("ENEMY")[0]
	var collision_partner: Dictionary = collision.living("ENEMY")[1]
	var collision_source: Dictionary = collision.living("ALLY")[0]
	collision_target["row"] = "front"
	collision_partner["row"] = "back"
	for unit in [collision_target, collision_partner]:
		unit["hp"] = 100
		unit["max_hp"] = 100
		unit["statuses"].clear()
		collision._add_status(unit, "flying", 2, 1, int(collision_source["id"]))
	collision.reposition(collision_source, collision_target, "push", true)
	assert(int(collision_target["hp"]) == 50 and int(collision_partner["hp"]) == 50, "Colisão duplica o impacto em cada unidade voadora")
	assert(not collision._has_status(collision_target, "voar") and not collision._has_status(collision_partner, "voar"), "Colisão derruba ambos os voadores")
	var standalone = Battle.new()
	standalone.begin("road", team, {}, 311)
	var crash_target: Dictionary = standalone.living("ENEMY")[0]
	var crash_a: Dictionary = standalone.living("ENEMY")[1]
	var crash_b: Dictionary = standalone.living("ENEMY")[2]
	var crash_source: Dictionary = standalone.living("ALLY")[0]
	for unit in [crash_target, crash_a, crash_b]:
		unit["row"] = "front"
		unit["hp"] = 100
		unit["max_hp"] = 100
	var before_collision_hp := int(crash_target["hp"])
	standalone.reposition(crash_source, crash_target, "collision", true)
	assert(int(crash_target["hp"]) == before_collision_hp - 20, "Colidir sem movimento causa 10 + 10% no alvo")
	var ally_damage := [int(crash_a["hp"]), int(crash_b["hp"])].filter(func(hp): return hp == 80).size()
	assert(ally_damage == 1, "Colidir sem movimento escolhe só um aliado aleatoriamente da mesma fileira")
	var edge = Battle.new()
	edge.begin("road", team, {}, 313)
	var edge_target: Dictionary = edge.living("ENEMY")[1]
	edge_target["row"] = "back"
	edge_target["hp"] = 100
	edge_target["max_hp"] = 100
	edge.reposition(edge.living("ALLY")[0], edge_target, "push")
	assert(int(edge_target["hp"]) == 90, "Empurrar além do limite causa apenas 10% da Vida máxima")
	assert(standalone.living("ALLY")[0]["statuses"].is_empty(), "Teste de Voar começa sem estado")
	var entity_fly_id := "ent_smoke_fly"
	_packs.entities.catalog.cards[entity_fly_id] = {"id": entity_fly_id, "name": "Voar teste", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["fly", "2"]]}
	standalone.hand.clear()
	standalone.hand.append({"uid": 99001, "id": entity_fly_id, "owner": int(crash_source["id"]), "class": "SKILL", "cost_override": 0})
	standalone.card_plays = 3
	standalone.impulse = 5
	assert(_packs.play_card(standalone, "entities", 0, int(crash_source["id"])), "Interpretador de entidades executa [fly, X]")
	assert(standalone._has_status(crash_source, "flying"), "Ação Voar concede o estado ao usuário")
	var entity_collision_id := "ent_smoke_colidir"
	_packs.entities.catalog.cards[entity_collision_id] = {"id": entity_collision_id, "name": "Colidir teste entidade", "owner": "smoke", "class": "SKILL", "target": "ENEMY", "cost": 0, "actions": [["collision"]]}
	standalone.hand.clear()
	for unit in standalone.living("ENEMY"):
		unit["row"] = "front"
		unit["hp"] = 100
		unit["max_hp"] = 100
	standalone.hand.append({"uid": 99006, "id": entity_collision_id, "owner": int(crash_source["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(standalone, "entities", 0, int(standalone.living("ENEMY")[0]["id"])), "Interpretador de entidades executa Colidir sem movimento")
	assert(standalone.living("ENEMY").filter(func(unit): return int(unit["hp"]) == 80).size() == 2, "Colidir entidade causa dano no alvo e num aliado")
	var external_fly_id := "ms_smoke_voar"
	_packs.external.catalog.cards[external_fly_id] = {"id": external_fly_id, "name": "Voar teste externo", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["voar", "2"]]}
	var external_flight := Battle.new()
	external_flight.begin("road", team, {}, 315)
	var external_flyer: Dictionary = external_flight.living("ALLY")[0]
	external_flight.hand.append({"uid": 99002, "id": external_fly_id, "owner": int(external_flyer["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(external_flight, "external", 0, int(external_flyer["id"])), "Interpretador externo normaliza alias [voar, X]")
	assert(external_flight._has_status(external_flyer, "flying"), "Alias Voar concede o estado ao usuário")
	var collision_id := "ms_smoke_colidir"
	_packs.external.catalog.cards[collision_id] = {"id": collision_id, "name": "Colidir teste", "owner": "smoke", "class": "SKILL", "target": "ENEMY", "cost": 0, "actions": [["colidir"]]}
	var interpreted_collision := Battle.new()
	interpreted_collision.begin("road", team, {}, 316)
	var interpreted_target: Dictionary = interpreted_collision.living("ENEMY")[0]
	var interpreted_allies: Array = interpreted_collision.living("ENEMY").slice(1)
	var collision_owner: Dictionary = interpreted_collision.living("ALLY")[0]
	for unit in [interpreted_target] + interpreted_allies:
		unit["row"] = "front"
		unit["hp"] = 100
		unit["max_hp"] = 100
	interpreted_collision.hand.append({"uid": 99005, "id": collision_id, "owner": int(collision_owner["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(interpreted_collision, "external", 0, int(interpreted_target["id"])), "Interpretador externo executa Colidir sem movimento")
	assert(int(interpreted_target["hp"]) == 80 and interpreted_allies.filter(func(unit): return int(unit["hp"]) == 80).size() == 1, "Colidir executado pelo interpretador atinge alvo e um aliado aleatório")
	var provoke_id := "ent_smoke_provoke"
	_packs.entities.catalog.cards[provoke_id] = {"id": provoke_id, "name": "Provocar teste", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["taunt"]]}
	var taunt_battle := Battle.new()
	taunt_battle.begin("road", team, {}, 318)
	var taunt_owner: Dictionary = taunt_battle.living("ALLY")[0]
	taunt_battle.hand.append({"uid": 99007, "id": provoke_id, "owner": int(taunt_owner["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(taunt_battle, "entities", 0, int(taunt_owner["id"])), "Interpretador executa ação Provocar")
	assert(taunt_battle._has_status(taunt_owner, "taunted"), "Provocar no próprio personagem aplica o estado que direciona a IA hostil")
	var extra_plays = Battle.new()
	extra_plays.begin("road", team, {}, 317)
	var plays_owner: Dictionary = extra_plays.living("ALLY")[0]
	_packs.entities.catalog.cards["ent_smoke_actions"] = {"id": "ent_smoke_actions", "name": "Ações teste", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["actions", "2"]]}
	extra_plays.hand.append({"uid": 99008, "id": "ent_smoke_actions", "owner": int(plays_owner["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(extra_plays, "entities", 0, int(plays_owner["id"])), "Interpretador aplica Ações X")
	_packs.external.catalog.cards["ms_smoke_actions"] = {"id": "ms_smoke_actions", "name": "Ações teste externo", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["actions", "2"]]}
	extra_plays.hand.append({"uid": 99009, "id": "ms_smoke_actions", "owner": int(plays_owner["id"]), "class": "SKILL", "cost_override": 0})
	assert(_packs.play_card(extra_plays, "external", 0, int(plays_owner["id"])), "Interpretador externo aplica Ações X")
	extra_plays.start_turn()
	assert(int(extra_plays.card_plays) == 7, "Ações X de ambos os interpretadores soma ao turno seguinte")
	var redraw_plays := Battle.new()
	redraw_plays.begin("road", team, {}, 319)
	var redraw_owner: Dictionary = redraw_plays.living("ALLY")[0]
	var actions_card := {"uid": 99003, "id": "ent_smoke_redraw", "owner": int(plays_owner["id"]), "class": "SKILL"}
	_packs.entities.catalog.cards["ent_smoke_redraw"] = {"id": "ent_smoke_redraw", "name": "Ações teste", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["redraw_actions", "2"]]}
	actions_card["owner"] = int(redraw_owner["id"])
	_packs.entities.on_redraw(redraw_plays, actions_card)
	_packs.external.catalog.cards["ms_smoke_redraw"] = {"id": "ms_smoke_redraw", "name": "Ações externas teste", "owner": "smoke", "class": "SKILL", "target": "SELF", "cost": 0, "actions": [["redraw_actions", "2"]]}
	_packs.external.on_redraw(redraw_plays, {"uid": 99004, "id": "ms_smoke_redraw", "owner": int(redraw_owner["id"]), "class": "SKILL"})
	redraw_plays.start_turn()
	assert(int(redraw_plays.card_plays) == 7, "Recompra concede Ações X pelos dois interpretadores")
	assert(not flight.actors[0].has("block") and not flight.actors[0].has("shield"), "Atores não carregam pools legados de Bloqueio/Escudo")

	print("OK: estados, Chain, Soulbound, impacto, prévia, alvos especiais e KO próprio")
	quit(0)
