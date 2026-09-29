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

	if fails.is_empty():
		print("InstantDominikaNeroSmoke OK")
	else:
		print("InstantDominikaNeroSmoke FAIL")
		for f in fails: print(" - ", f)
	quit(0 if fails.is_empty() else 1)
