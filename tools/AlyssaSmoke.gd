extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []

	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 11)
	var hero: Dictionary = b.living("ALLY")[0]
	b._add_status(hero, "escuridao", 99, 3, int(hero["id"]))
	if abs(b.resolve_amount("1+E", hero) - 4.0) > 0.01: fails.append("1+E")
	if abs(b.resolve_amount("2*E", hero) - 6.0) > 0.01: fails.append("2*E")
	if abs(b.resolve_amount("2×E", hero) - 6.0) > 0.01: fails.append("2×E")
	if abs(b.resolve_amount(5, hero) - 5.0) > 0.01: fails.append("static")

	var b2 = Battle.new()
	b2.begin("road", ["guerreiro", "mago", "clerigo"], {}, 12)
	var a: Dictionary = b2.living("ALLY")[0]
	a["passive"] = "escuridao"
	var foe: Dictionary = b2.living("ENEMY")[0]
	b2._take_damage(foe, a, 4, true, false)
	if b2._status_stacks(a, "escuridao") < 1: fails.append("escuridao_on_dmg")

	var b3 = Battle.new()
	b3.begin("road", ["guerreiro", "mago", "clerigo"], {}, 13)
	var bl: Dictionary = b3.living("ALLY")[0]
	b3._add_status(bl, "bleed", 3, 3, int(bl["id"]))
	var hp_b: int = int(bl["hp"])
	b3._tick_statuses()
	if b3._status_stacks(bl, "bleed") != 2: fails.append("bleed_stacks=%d" % b3._status_stacks(bl, "bleed"))
	if int(bl["hp"]) != hp_b - 3: fails.append("bleed_dmg")

	var b4 = Battle.new()
	b4.begin("road", ["guerreiro", "mago", "clerigo"], {}, 14)
	var src: Dictionary = b4.living("ALLY")[0]
	var others = b4._targets(src, src, {"target": "ALL_OTHERS", "reach": true})
	if others.any(func(x): return int(x["id"]) == int(src["id"])): fails.append("all_others_self")
	if others.size() < 2: fails.append("all_others_size")

	var b5 = Battle.new()
	b5.begin("road", ["guerreiro", "mago", "clerigo"], {}, 15)
	var atk: Dictionary = b5.living("ALLY")[0]
	var vic: Dictionary = b5.living("ENEMY")[0]
	b5._add_status(vic, "invulnerable", 2, 1, int(vic["id"]))
	var hp_v: int = int(vic["hp"])
	b5._take_damage(atk, vic, 5, false, false)
	if int(vic["hp"]) != hp_v: fails.append("invuln_block")
	b5._add_status(atk, "atento", 2, 2, int(atk["id"]))
	b5._take_damage(atk, vic, 5, true, false)
	if int(vic["hp"]) >= hp_v: fails.append("atento_pierce")

	# Tormenta Instantânea: sem tick passivo; carta com instant + hit_flat.
	var b6 = Battle.new()
	b6.begin("road", ["guerreiro", "mago", "clerigo"], {}, 16)
	var storm: Dictionary = b6.living("ALLY")[0]
	storm["passive"] = "escuridao"
	b6._add_status(storm, "escuridao", 99, 4, int(storm["id"]))
	var hps: Dictionary = {}
	for actor in b6.actors:
		if int(actor["id"]) != int(storm["id"]) and int(actor["hp"]) > 0:
			hps[int(actor["id"])] = int(actor["hp"])
	b6._tick_statuses()
	for id in hps.keys():
		var victim: Dictionary = b6.actor_by_id(int(id))
		if int(victim["hp"]) != int(hps[id]):
			fails.append("tormenta_no_passive_tick_%s" % id)

	var def: Dictionary = packs.definition("ent_alyssa_wine_bastao_retratil")
	if def.is_empty(): fails.append("bastao_missing")
	var hero_def: Dictionary = packs.entities.catalog.hero("ent_alyssa_wine")
	if str(hero_def.get("passive", "")) != "escuridao": fails.append("passive")
	var apr = hero_def.get("aprimoramento", "")
	var apr_id := str(apr)
	if typeof(apr) == TYPE_DICTIONARY:
		apr_id = str(apr.get("id", ""))
	if apr_id != "escuridao": fails.append("aprimoramento")
	if int(hero_def.get("iniciais", []).size()) != 5: fails.append("iniciais5")
	var tor: Dictionary = packs.definition("ent_alyssa_wine_desvantagem_tormenta")
	if str(tor.get("class", "")) != "DESVANTAGEM": fails.append("desv_class")
	if not bool(tor.get("instant", false)): fails.append("tormenta_instant")
	var has_flat := false
	for act in tor.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) == "hit_flat":
			has_flat = true
	if not has_flat: fails.append("tormenta_hit_flat")
	# Instantâneo jogável: com E=0 Tormenta não bloqueia Encerrar; com E>=1 bloqueia.
	var bi = Battle.new()
	bi.begin("road", ["guerreiro", "mago", "clerigo"], {}, 17)
	var aly: Dictionary = bi.living("ALLY")[0]
	aly["passive"] = "escuridao"
	bi.hand.clear()
	bi.next_card_id += 1
	bi.hand.append({"uid": bi.next_card_id, "id": "ent_alyssa_wine_desvantagem_tormenta", "owner": int(aly["id"]), "instant": true, "class": "DESVANTAGEM", "upgrade": 0})
	bi.card_plays = 3
	bi.impulse = 5
	bi.phase = "PLAYER"
	if bi.hand_has_playable_instantaneo("ALLY"): fails.append("instant_unplayable_E0")
	if not bi.can_end_turn(): fails.append("can_end_E0")
	bi._add_status(aly, "escuridao", 99, 2, int(aly["id"]))
	if not bi.hand_has_playable_instantaneo("ALLY"): fails.append("instant_playable_E2")
	if bi.can_end_turn(): fails.append("cannot_end_E2")

	# wounded via entity play (lightweight)
	var b7 = Battle.new()
	b7.begin("road", ["guerreiro", "mago", "clerigo"], {}, 21)
	var wsrc: Dictionary = b7.living("ALLY")[0]
	b7._add_status(wsrc, "wounded", 2, 1, int(wsrc["id"]))
	b7.hand.clear()
	b7.next_card_id += 1
	b7.hand.append({"uid": b7.next_card_id, "id": "corte", "owner": int(wsrc["id"]), "class": "ATTACK", "upgrade": 0})
	b7.card_plays = 3
	b7.impulse = 5
	var wenemy: Dictionary = b7.living("ENEMY")[0]
	var hp_w: int = int(wsrc["hp"])
	if not b7.play(0, int(wenemy["id"])): fails.append("play_corte")
	if int(wsrc["hp"]) >= hp_w: fails.append("wounded_on_play")

	if fails.is_empty():
		print("ALYSSA_SMOKE_OK")
	else:
		print("ALYSSA_SMOKE_FAIL")
		for f in fails:
			print(" - ", f)
	quit(0 if fails.is_empty() else 1)
