extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const EntityRuntime = preload("res://addons/hotn3_entities/EntityRuntime.gd")
const Content = preload("res://game/Content.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []
	var runtime = EntityRuntime.new()

	var hero: Dictionary = packs.entities.catalog.hero("ent_alyssa_wine")
	if hero.is_empty(): fails.append("alyssa_missing")
	if str(hero.get("passive", "")) != "escuridao": fails.append("passive_alias")
	var apr = hero.get("aprimoramento", {})
	var apr_id: String = ""
	if typeof(apr) == TYPE_DICTIONARY:
		apr_id = str(apr.get("id", ""))
	else:
		apr_id = str(apr)
	if apr_id != "escuridao": fails.append("aprimoramento=%s" % apr_id)
	if int(hero.get("iniciais", []).size()) != 5: fails.append("iniciais_count=%d" % hero.get("iniciais", []).size())
	if str(hero.get("desvantagem", "")) == "": fails.append("desvantagem_missing")
	if int(hero.get("melhoradas", []).size()) < 5: fails.append("melhoradas")
	if int(hero.get("grupos", []).size()) < 1: fails.append("grupos")

	var bastao: Dictionary = packs.definition("ent_alyssa_wine_bastao_retratil")
	if str(bastao.get("tier", "")) != "inicial": fails.append("bastao_tier")
	var plus: Dictionary = packs.definition("ent_alyssa_wine_bastao_retratil_plus")
	if plus.is_empty() or str(plus.get("tier", "")) != "melhorada": fails.append("bastao_plus")
	if not str(plus.get("name", "")).ends_with("+"): fails.append("plus_name")
	if str(plus.get("melhorada_de", "")) != "ent_alyssa_wine_bastao_retratil": fails.append("melhorada_de")

	if not runtime.deck_valid("ent_alyssa_wine", hero.get("iniciais", [])):
		fails.append("deck_valid_5")

	# Reshuffle fatigue: Lento 1 on allies
	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 42)
	for ally in b.living("ALLY"):
		if b._has_status(ally, "slow"): fails.append("slow_before")
	# Move all deck into discard then force draw reshuffle
	while not b.deck.is_empty():
		b.discard.append(b.deck.pop_back())
	var before_hand: int = b.hand.size()
	b._draw_side("ALLY", 1)
	for ally in b.living("ALLY"):
		if not b._has_status(ally, "slow"):
			fails.append("reshuffle_lento_%s" % ally.get("name", "?"))
			break
	if b.hand.size() < before_hand + 1 and b.hand.size() < int(b.rules["hand_max"]):
		# may already be at hand max — only fail if discard wasn't consumed
		if not b.discard.is_empty() and b.deck.is_empty():
			fails.append("reshuffle_draw_failed")

	# Deploy Alyssa kit size: 5 + desv = 6; with 3 heroes sharing no group typically 18
	# Force shared group for combo check via catalog mutation on copies
	var ids: Array[String] = ["ent_alyssa_wine", "ent_adam", "ent_akuji"]
	# Inject shared group
	for id in ids:
		var h: Dictionary = runtime.catalog.hero(id)
		if h.is_empty(): 
			fails.append("hero_" + id)
			continue
		h["grupos"] = ["SmokeGrupo", "X", "Y"]
	var b2 = Battle.new()
	if not runtime.deploy(b2, "road", ids, {}, 99):
		fails.append("deploy_failed")
	else:
		var manobras: int = 0
		var desvs: int = 0
		var combos: int = 0
		var piles: Array = []
		piles.append_array(b2.deck)
		piles.append_array(b2.hand)
		for card in piles:
			var cid := str(card.get("id", ""))
			var def: Dictionary = packs.definition(cid)
			if def.is_empty() and Content.CARDS.has(cid):
				def = Content.CARDS[cid]
			var tier := str(card.get("tier", def.get("tier", "")))
			var cls := str(card.get("class", def.get("class", "")))
			if tier == "combo" or cid.begins_with("combo_"):
				combos += 1
			elif cls == "DESVANTAGEM":
				desvs += 1
			else:
				manobras += 1
		# Also count Content.CARDS combo defs created
		var combo_in_content: int = 0
		for cid in Content.CARDS.keys():
			if str(cid).begins_with("combo_SmokeGrupo"):
				combo_in_content += 1
		if combo_in_content < 4 and combos < 4:
			fails.append("combos=%d content=%d" % [combos, combo_in_content])
		# 3*5 manobras + 3 desv (+ combos). Alyssa has desv; adam/akuji may not.
		if manobras + desvs + combos < 15:
			fails.append("deck_too_small=%d (m=%d d=%d c=%d)" % [manobras+desvs+combos, manobras, desvs, combos])

	# Content merge fields
	var merged: Dictionary = Content.HEROES.get("ent_alyssa_wine", {})
	if merged.is_empty(): fails.append("merge_alyssa")
	if not merged.has("grupos"): fails.append("merge_grupos")
	if not merged.has("aprimoramento") and str(merged.get("passive","")) != "escuridao":
		fails.append("merge_apr")

	if fails.is_empty():
		print("OK: NomenclatureSmoke")
		quit(0)
		return
	print("FAIL: NomenclatureSmoke " + ", ".join(fails))
	quit(1)
