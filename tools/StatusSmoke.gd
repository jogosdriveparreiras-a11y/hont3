extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const Content = preload("res://game/Content.gd")

func _initialize() -> void:
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
	battle._add_status(enemy, "resist", 2, 1, int(enemy["id"]))
	battle._take_damage(hero, enemy, 5)
	assert(enemy["hp"] == before and not battle._has_status(enemy, "resist"), "Resist deve impedir um dano")
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
	assert(second._cost(source, {"cost": 0, "class": "POWER"}) == 1, "Slow aumenta custo Heroico zero")
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
	fifth._add_status(spreader, "resist", 2, 1, int(spreader["id"]))
	fifth._add_status(spreader, "bleed", 2, 1, int(opposite["id"]))
	var bleeding_hp: int = spreader["hp"]
	fifth._tick_statuses()
	assert(spreader["hp"] < bleeding_hp and spreader["block"] == 30 and fifth._has_status(spreader, "resist"), "Bleed ignora Bloqueio e Resistência")
	var sixth = Battle.new()
	sixth.begin("road", team, {}, 89)
	var pusher: Dictionary = sixth.living("ALLY")[0]
	var pushed: Dictionary = sixth.living("ENEMY")[0]
	pushed["hp"] = sixth._damage_value(pusher, pushed, Content.CARDS["investida"]["effects"][0], {}) + 1
	sixth._add_status(pushed, "marked", 2, 1, int(pusher["id"]))
	sixth.hand.clear()
	sixth.hand.append(sixth._create_card("investida", int(pusher["id"])))
	assert(sixth.play(0, int(pushed["id"])), "Investida deve ser jogável")
	assert(pushed["hp"] == 0 and sixth.card_plays == int(sixth.rules["card_plays"]), "Eliminação pelo impacto deve recuperar ação de Marcado")
	print("OK: Weak, Vulnerable, Resist, Stun, Quick, Banished, Soulbound, Block, Cure, Slow, Chain, Make em Bleed, Fatal Fury, Corrupted, Bleed, Marked impact")
	quit(0)
