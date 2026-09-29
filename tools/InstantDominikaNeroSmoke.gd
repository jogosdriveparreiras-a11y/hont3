extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []

	var dom = packs.entities.catalog.hero("ent_dominika_seur")
	var apr = dom.get("aprimoramento", "")
	var apr_id := str(apr.get("id", "")) if typeof(apr) == TYPE_DICTIONARY else str(apr)
	if apr_id != "gordura_100": fails.append("dom_apr")
	for need in ["ent_dominika_seur_peitada", "ent_dominika_seur_barrigada", "ent_dominika_seur_corpo_de_manteiga", "ent_dominika_seur_cair_por_cima", "ent_dominika_seur_rolar", "ent_dominika_seur_desvantagem_derretimento"]:
		if packs.definition(need).is_empty(): fails.append("missing_" + need)
	var corpo = packs.definition("ent_dominika_seur_corpo_de_manteiga")
	if bool(corpo.get("reach", false)): fails.append("corpo_reach")
	var cair = packs.definition("ent_dominika_seur_cair_por_cima")
	if not cair.has("counter_effects"): fails.append("cair_counter_fx")

	var nero = packs.entities.catalog.hero("ent_nero")
	var napr = nero.get("aprimoramento", "")
	var nid := str(napr.get("id", "")) if typeof(napr) == TYPE_DICTIONARY else str(napr)
	if nid != "naomi_despertar": fails.append("nero_apr")
	var faca = packs.definition("ent_nero_faca_de_osso")
	if not faca.has("naomi_actions"): fails.append("faca_naomi")
	if packs.entities.catalog.hero("ent_minion_zumbi").is_empty(): fails.append("zumbi")
	if packs.entities.catalog.hero("ent_minion_lich").is_empty(): fails.append("lich")

	# Gordura immunity
	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 31)
	var h: Dictionary = b.living("ALLY")[0]
	h["passive"] = "gordura_100"
	b._add_status(h, "wounded", 2, 1, int(h["id"]))
	if b._has_status(h, "wounded"): fails.append("gordura_wounded")
	b._add_status(h, "bleed", 2, 1, int(h["id"]))
	if b._has_status(h, "bleed"): fails.append("gordura_bleed")
	b._add_status(h, "bind", 2, 1, int(h["id"]))
	if b._has_status(h, "bind"): fails.append("gordura_bind")

	# Counter front-vs-front gate
	var b2 = Battle.new()
	b2.begin("road", ["guerreiro", "mago", "clerigo"], {}, 32)
	var d: Dictionary = b2.living("ALLY")[0]
	d["row"] = "front"
	var e: Dictionary = b2.living("ENEMY")[0]
	e["row"] = "back"
	# ensure enemy has a front so back attacker is blocked by default counter
	var e2: Dictionary = b2.living("ENEMY")[1]
	e2["row"] = "front"
	b2._add_status(d, "counter", 1, 1, int(d["id"]))
	if b2._counter_can_strike(d, e): fails.append("counter_should_block_back")
	e["row"] = "front"
	if not b2._counter_can_strike(d, e): fails.append("counter_should_allow_front")

	# Alcance audit sample: random SELF card without reach
	var adam_self = packs.definition("ent_adam_avaliar_o_risco")
	if bool(adam_self.get("reach", false)): fails.append("adam_self_reach")

	# --- Arena deck merge: owned stale Dominika/Nero must not wipe kits ---
	var CollectionRules = load("res://game/CollectionRules.gd")
	var Content = load("res://game/Content.gd")
	PackBridge.packs_merged = false
	var packs2 = PackBridge.new()
	var stale: Dictionary = {
		"ent_dominika_seur": ["ent_dominika_seur_engolfamento", "ent_dominika_seur_massa_em_avanco"],
		"ent_nero": ["ent_nero_foice_de_sangue", "ent_nero_escudo_de_ossos"],
		"ent_alyssa_wine": ["ent_alyssa_wine_bastao_retratil", "ent_alyssa_wine_desvantagem_tormenta"],
	}
	var fixed: Dictionary = CollectionRules.ensure_owned(Content.HEROES, Content.CARDS, stale)
	var dom_owned: Array = fixed.get("ent_dominika_seur", [])
	var nero_owned: Array = fixed.get("ent_nero", [])
	if "ent_dominika_seur_peitada" not in dom_owned: fails.append("stale_dom_reset")
	if "ent_dominika_seur_desvantagem_derretimento" not in dom_owned: fails.append("stale_dom_desv")
	if "ent_nero_faca_de_osso" not in nero_owned: fails.append("stale_nero_reset")
	if "ent_nero_desvantagem_solidao" not in nero_owned: fails.append("stale_nero_desv")
	if "ent_dominika_seur_engolfamento" in dom_owned: fails.append("stale_dom_kept_old")

	# deploy must succeed with stale equipped and put all 3 owners in deck
	var b3 = Battle.new()
	var team3: Array[String] = ["ent_nero", "ent_alyssa_wine", "ent_dominika_seur"]
	var equipped_stale: Dictionary = {
		"ent_nero": ["ent_nero_foice_de_sangue"],
		"ent_alyssa_wine": ["ent_alyssa_wine_bastao_retratil", "ent_alyssa_wine_desvantagem_tormenta"],
		"ent_dominika_seur": ["ent_dominika_seur_engolfamento"],
	}
	if not packs2.entities.deploy(b3, "road", team3, equipped_stale, 99):
		fails.append("deploy_stale_failed")
	else:
		var owners: Dictionary = {}
		for c in b3.deck + b3.hand:
			var arch := ""
			for a in b3.actors:
				if int(a["id"]) == int(c.get("owner", -1)):
					arch = str(a.get("archetype", ""))
					break
			if arch != "": owners[arch] = true
		if not owners.has("ent_nero"): fails.append("deck_missing_nero")
		if not owners.has("ent_dominika_seur"): fails.append("deck_missing_dom")
		if not owners.has("ent_alyssa_wine"): fails.append("deck_missing_alyssa")
		# Nenhuma carta com id removido
		for c in b3.deck + b3.hand:
			var cid := str(c.get("id", ""))
			if cid in ["ent_dominika_seur_engolfamento", "ent_nero_foice_de_sangue"]:
				fails.append("deck_has_stale_" + cid)

	# Tormenta: cost 0, Instantâneo; com Slow NÃO exige INI; gate só se jogável
	var tor = packs2.definition("ent_alyssa_wine_desvantagem_tormenta")
	if int(tor.get("cost", -1)) != 0: fails.append("tormenta_cost")
	if not bool(tor.get("instant", false)): fails.append("tormenta_instant")
	var b4 = Battle.new()
	b4.begin("road", ["guerreiro", "mago", "clerigo"], {}, 55)
	var ally: Dictionary = b4.living("ALLY")[0]
	ally["archetype"] = "ent_alyssa_wine"
	b4._add_status(ally, "escuridao", 2, 99, int(ally["id"]))
	b4._add_status(ally, "slow", 1, 2, int(ally["id"]))
	b4.impulse = 0
	b4.card_plays = 3
	var fake_t: Dictionary = {"id": "ent_alyssa_wine_desvantagem_tormenta", "owner": int(ally["id"]), "uid": 1, "instant": true}
	Content.CARDS["ent_alyssa_wine_desvantagem_tormenta"] = tor.duplicate(true)
	if not b4._instant_card_playable(fake_t, tor, "ALLY"):
		fails.append("tormenta_should_be_playable_at_0_ini")
	var cost_chk: int = b4._cost(ally, tor)
	if cost_chk != 0: fails.append("tormenta_cost_with_slow_%d" % cost_chk)
	# Sem Escuridão → não jogável → não bloqueia Encerrar
	b4._add_status(ally, "escuridao", 0, 0, int(ally["id"]))
	ally["statuses"].erase("escuridao")
	if b4._instant_card_playable(fake_t, tor, "ALLY"):
		fails.append("tormenta_playable_without_E")

	if fails.is_empty():
		print("InstantDominikaNeroSmoke OK")
	else:
		print("InstantDominikaNeroSmoke FAIL")
		for f in fails: print(" - ", f)
	quit(0 if fails.is_empty() else 1)
