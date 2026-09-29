extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []

	# --- Derretimento: passive_like + Instantâneo (só ["instant"], efeito passivo no ator) ---
	var der = packs.definition("ent_dominika_seur_desvantagem_derretimento")
	if der.is_empty(): fails.append("der_missing")
	if not bool(der.get("passive_like", false)): fails.append("der_not_passive_like")
	if not bool(der.get("instant", false)): fails.append("der_not_instant")
	var der_ops: Array = []
	for a in der.get("actions", []):
		if typeof(a) == TYPE_ARRAY and not a.is_empty():
			der_ops.append(str(a[0]))
	if "instant" not in der_ops: fails.append("der_actions_no_instant")
	for op in der_ops:
		if op != "instant":
			fails.append("der_unexpected_action_%s" % op)
	if str(der.get("class", "")) != "DESVANTAGEM": fails.append("der_class")

	# --- Solidão / Deixe-me Viver redraw + alone ---
	var sol = packs.definition("ent_nero_desvantagem_solidao")
	if sol.is_empty(): fails.append("sol_missing")
	if not bool(sol.get("instant", false)): fails.append("sol_not_instant")
	var has_alone := false
	for a in sol.get("actions", []):
		if typeof(a) == TYPE_ARRAY and not a.is_empty() and str(a[0]) == "requires_alone":
			has_alone = true
	if not has_alone: fails.append("sol_no_alone")
	var naomi_acts: Array = sol.get("naomi_actions", [])
	if naomi_acts.is_empty(): fails.append("naomi_actions_missing")
	var naomi_alone := false
	var naomi_instant := false
	for a in naomi_acts:
		if typeof(a) == TYPE_ARRAY and not a.is_empty():
			if str(a[0]) == "requires_alone": naomi_alone = true
			if str(a[0]) == "instant": naomi_instant = true
	if naomi_alone: fails.append("naomi_still_requires_alone")
	if not naomi_instant: fails.append("naomi_not_instant")

	var b0 = Battle.new()
	b0.begin("road", ["guerreiro", "mago", "clerigo"], {}, 41)
	if not b0.is_instant_card({"id": "ent_nero_desvantagem_solidao"}, sol):
		fails.append("sol_is_instant_false")
	# Instantâneo não redesenha
	b0.hand.clear()
	b0.hand.append({"uid": 1, "id": "ent_nero_desvantagem_solidao", "owner": int(b0.living("ALLY")[0]["id"]), "class": "DESVANTAGEM", "upgrade": 0})
	b0.redraws = 2
	b0.phase = "PLAYER"
	if b0.redraw(0): fails.append("sol_redraw_allowed")

	# --- Transform after 5 Nero cards + summon purge on death ---
	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 42)
	var nero: Dictionary = b.living("ALLY")[0]
	nero["archetype"] = "ent_nero"
	nero["passive"] = "naomi_despertar"
	nero["aprimoramento"] = {"id": "naomi_despertar"}
	nero["nero_plays"] = 0
	nero["transformed"] = false
	nero["base_name"] = "Nero"
	nero["name"] = "Nero"
	nero["sprite"] = "res://assets/cast/ent_nero_sprite.png"
	nero["portrait"] = "res://assets/cast/ent_nero_portrait.png"

	var rt = packs.entities
	var transform_count := [0]
	b.visual.connect(func(kind: String, _s: int, _t: int, _a: int) -> void:
		if kind == "transform":
			transform_count[0] = int(transform_count[0]) + 1
	)

	for _i in range(4):
		rt._try_nero_transform(b, nero, "ent_nero_faca_de_osso")
	if bool(nero.get("transformed", false)): fails.append("early_transform")
	if int(nero.get("nero_plays", 0)) != 4: fails.append("plays_%d" % int(nero.get("nero_plays", -1)))
	rt._try_nero_transform(b, nero, "ent_nero_invocar_zumbi")
	if not bool(nero.get("transformed", false)): fails.append("no_transform")
	if str(nero.get("name", "")) != "Naomi": fails.append("name_%s" % nero.get("name", ""))
	if int(transform_count[0]) < 1: fails.append("no_transform_visual")
	# Arte Naomi dedicada (Cast Edited)
	if str(nero.get("sprite", "")) != "res://assets/cast/ent_naomi_sprite.png":
		fails.append("unexpected_sprite_%s" % nero.get("sprite", ""))
	if str(nero.get("portrait", "")) != "res://assets/cast/ent_naomi_portrait.png":
		fails.append("unexpected_portrait_%s" % nero.get("portrait", ""))

	# Summon two minions then kill Nero → both die + cards purged
	rt._summon(b, nero, "ent_minion_zumbi", 99)
	rt._summon(b, nero, "ent_minion_fantasma", 99)
	var summons: Array = []
	for actor in b.actors:
		if bool(actor.get("is_summon", false)) and int(actor.get("summoner_id", -1)) == int(nero["id"]):
			summons.append(actor)
	if summons.size() < 2: fails.append("summon_count_%d" % summons.size())
	for sm in summons:
		b.next_card_id += 1
		b.hand.append({"uid": b.next_card_id, "id": "punhal", "owner": int(sm["id"]), "class": "ATTACK", "upgrade": 0})
		b.next_card_id += 1
		b.deck.append({"uid": b.next_card_id, "id": "punhal", "owner": int(sm["id"]), "class": "ATTACK", "upgrade": 0})
		b.next_card_id += 1
		b.discard.append({"uid": b.next_card_id, "id": "punhal", "owner": int(sm["id"]), "class": "ATTACK", "upgrade": 0})

	var foe: Dictionary = b.living("ENEMY")[0]
	b._take_damage(foe, nero, int(nero["max_hp"]) + 50, false, true)
	if int(nero.get("hp", 1)) > 0: fails.append("nero_alive")
	for sm in summons:
		if int(sm.get("hp", 1)) > 0: fails.append("minion_alive_%s" % sm.get("name", "?"))
	for card in b.hand:
		for sm in summons:
			if int(card.get("owner", -1)) == int(sm["id"]):
				fails.append("orphan_hand_%s" % sm.get("name", "?"))
	for card in b.deck:
		for sm in summons:
			if int(card.get("owner", -1)) == int(sm["id"]):
				fails.append("orphan_deck_%s" % sm.get("name", "?"))
	for card in b.discard:
		for sm in summons:
			if int(card.get("owner", -1)) == int(sm["id"]):
				fails.append("orphan_discard_%s" % sm.get("name", "?"))

	# Naomi Solidão overlay drops requires_alone
	var resolved: Dictionary = rt._resolve_card_def(b, nero, sol)
	var resolved_alone := false
	for a in resolved.get("actions", []):
		if typeof(a) == TYPE_ARRAY and not a.is_empty() and str(a[0]) == "requires_alone":
			resolved_alone = true
	if resolved_alone: fails.append("resolved_still_alone")
	if str(resolved.get("name", "")) != "Deixe-me Viver": fails.append("resolved_name")

	if fails.is_empty():
		print("OK: NeroNaomiTransformSmoke")
		quit(0)
	else:
		print("FAIL: NeroNaomiTransformSmoke -> ", ", ".join(PackedStringArray(fails)))
		quit(1)
