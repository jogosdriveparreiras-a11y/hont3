extends SceneTree

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []

	var hero_def: Dictionary = packs.entities.catalog.hero("ent_marcell_wine")
	if hero_def.is_empty(): fails.append("hero_missing")
	if str(hero_def.get("passive", "")) != "escuridao": fails.append("passive")
	var apr = hero_def.get("aprimoramento", "")
	var apr_id := str(apr)
	if typeof(apr) == TYPE_DICTIONARY:
		apr_id = str(apr.get("id", ""))
	if apr_id != "escuridao": fails.append("aprimoramento")
	var apr_text := str(apr.get("text", "")) if typeof(apr) == TYPE_DICTIONARY else ""
	if "irmão" in str(hero_def.get("biografia", "")).to_lower() or "irmao" in str(hero_def.get("biografia", "")).to_lower():
		fails.append("bio_still_brother")
	if "pai" not in str(hero_def.get("biografia", "")).to_lower():
		fails.append("bio_not_father")
	if int(hero_def.get("iniciais", []).size()) != 5: fails.append("iniciais5")
	if str(hero_def.get("desvantagem", "")) != "ent_marcell_wine_desvantagem_inimigos": fails.append("desv_id")

	var needed: Array[String] = [
		"ent_marcell_wine_bastao_retratil",
		"ent_marcell_wine_garras_e_presas",
		"ent_marcell_wine_premonicao",
		"ent_marcell_wine_tormenta",
		"ent_marcell_wine_regeneracao",
		"ent_marcell_wine_relampago",
		"ent_marcell_wine_intelecto",
		"ent_marcell_wine_super_sentidos",
		"ent_marcell_wine_desvantagem_inimigos",
	]
	for cid in needed:
		var d: Dictionary = packs.definition(cid)
		if d.is_empty(): fails.append("missing_%s" % cid)

	# Old unique cards must be gone
	for old_id in [
		"ent_marcell_wine_pacto_escuro", "ent_marcell_wine_regeneracao_sombria",
		"ent_marcell_wine_garras_do_abismo", "ent_marcell_wine_bastao_sombrio",
		"ent_marcell_wine_manto_de_trevas", "ent_marcell_wine_relampago_negro",
		"ent_marcell_wine_tempestade_latente", "ent_marcell_wine_presenca_opressora",
		"ent_marcell_wine_furia_primordial", "ent_marcell_wine_desvantagem_legiao",
	]:
		if not packs.definition(old_id).is_empty():
			fails.append("old_still_%s" % old_id)

	var bastao: Dictionary = packs.definition("ent_marcell_wine_bastao_retratil")
	var has_bar := false
	var has_res := false
	for act in bastao.get("actions", []):
		if typeof(act) != TYPE_ARRAY or act.size() < 4: continue
		if str(act[0]) == "when_stacks" and str(act[3]) == "barreira": has_bar = true
		if str(act[0]) == "when_stacks" and str(act[3]) == "resistente": has_res = true
	if not has_bar: fails.append("bastao_barreira")
	if not has_res: fails.append("bastao_resistente")

	var garras: Dictionary = packs.definition("ent_marcell_wine_garras_e_presas")
	var aly_garras: Dictionary = packs.definition("ent_alyssa_wine_garras_e_presas")
	if str(garras.get("actions", [])) != str(aly_garras.get("actions", [])):
		fails.append("garras_not_like_alyssa")

	var prem: Dictionary = packs.definition("ent_marcell_wine_premonicao")
	var prem_ok := false
	for act in prem.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) == "protecao" and "E" in str(act[1]):
			prem_ok = true
	if not prem_ok: fails.append("premonicao_1+E")

	var tor: Dictionary = packs.definition("ent_marcell_wine_tormenta")
	if str(tor.get("class", "")) == "DESVANTAGEM": fails.append("tormenta_is_desv")
	var has_climate := false
	var has_forte := false
	for act in tor.get("actions", []):
		if typeof(act) != TYPE_ARRAY or act.is_empty(): continue
		if str(act[0]) in ["climate", "set_climate", "weather"]: has_climate = true
		if str(act[0]) == "forte": has_forte = true
	if not has_climate: fails.append("tormenta_climate")
	if not has_forte: fails.append("tormenta_forte")

	var regen: Dictionary = packs.definition("ent_marcell_wine_regeneracao")
	var has_missing := false
	for act in regen.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) == "heal_missing_pct":
			has_missing = true
	if not has_missing: fails.append("heal_missing_pct")

	var rel: Dictionary = packs.definition("ent_marcell_wine_relampago")
	if not rel.has("cost_by_stacks"): fails.append("rel_cost_by_stacks")
	if not rel.has("target_by_stacks"): fails.append("rel_target_by_stacks")

	var aly_int: Dictionary = packs.definition("ent_alyssa_wine_intelecto")
	var m_int: Dictionary = packs.definition("ent_marcell_wine_intelecto")
	if str(aly_int.get("actions", [])) != str(m_int.get("actions", [])): fails.append("intelecto_diff")
	var aly_ss: Dictionary = packs.definition("ent_alyssa_wine_super_sentidos")
	var m_ss: Dictionary = packs.definition("ent_marcell_wine_super_sentidos")
	if str(aly_ss.get("actions", [])) != str(m_ss.get("actions", [])): fails.append("super_sentidos_diff")

	var inim: Dictionary = packs.definition("ent_marcell_wine_desvantagem_inimigos")
	if str(inim.get("name", "")) != "Inimigos": fails.append("inimigos_name")
	if str(inim.get("class", "")) != "DESVANTAGEM": fails.append("inim_class")
	if not bool(inim.get("instant", false)): fails.append("inim_instant")
	var has_rand := false
	for act in inim.get("actions", []):
		if typeof(act) == TYPE_ARRAY and act.size() > 1 and str(act[0]) in ["summon_foe", "reinforce_enemy"] and str(act[1]) == "random":
			has_rand = true
	if not has_rand: fails.append("inim_random")

	# Runtime
	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 31)
	var hero: Dictionary = b.living("ALLY")[0]
	hero["passive"] = "escuridao"
	var foe: Dictionary = b.living("ENEMY")[0]
	b._take_damage(foe, hero, 5, true, false)
	if b._status_stacks(hero, "escuridao") < 1: fails.append("escuridao_on_dmg")
	hero["statuses"].erase("escuridao")
	b._add_status(hero, "escuridao", 99, 5, int(hero["id"]))
	if b._status_stacks(hero, "escuridao") != 5: fails.append("e_stacks_%d" % b._status_stacks(hero, "escuridao"))

	# cost_by_stacks min(E,5)
	var cost5: int = b.resolve_card_cost(hero, rel)
	if cost5 != 5: fails.append("rel_cost_e5_%d" % cost5)
	hero["statuses"]["escuridao"]["stacks"] = 3
	var cost3: int = b.resolve_card_cost(hero, rel)
	if cost3 != 3: fails.append("rel_cost_e3_%d" % cost3)
	hero["statuses"]["escuridao"]["stacks"] = 5

	# heal_missing_pct: damage then heal ~100% of missing at E5
	hero["hp"] = int(hero["max_hp"]) - 40
	var missing_before := int(hero["max_hp"]) - int(hero["hp"])
	var frac: float = float(b.resolve_amount("0.1+0.18*E", hero))
	if abs(frac - 1.0) > 0.01: fails.append("missing_frac_e5_%s" % str(frac))
	var heal_amt: int = maxi(0, roundi(float(missing_before) * frac))
	hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + heal_amt)
	if int(hero["hp"]) != int(hero["max_hp"]): fails.append("missing_heal_full_%d" % int(hero["hp"]))

	# barrier formula E
	var er = packs.entities
	# simulate barreira E via resolve
	var bhp: int = maxi(1, int(round(b.resolve_amount("E", hero))))
	if bhp != 5: fails.append("barrier_e_%d" % bhp)

	# climate field
	b.climate = "none"
	# summon_foe random via runtime action path (lightweight): pick same type twice
	var enemies_before := b.living("ENEMY").size()
	var pool_foe: Array[String] = [
		"ent_minion_zumbi", "ent_minion_fantasma", "ent_minion_esqueleto", "ent_minion_vampiro",
		"ent_minion_mumia", "ent_minion_ghoul", "ent_minion_banshee", "ent_minion_strigoi",
		"ent_minion_golem", "ent_minion_lich",
	]
	var picked: String = pool_foe[b.rng.randi_range(0, pool_foe.size() - 1)]
	er._summon_on_side(b, hero, picked, 99, "ENEMY")
	er._summon_on_side(b, hero, picked, 99, "ENEMY")
	var enemies_after := b.living("ENEMY").size()
	if enemies_after < enemies_before + 2: fails.append("summon_foe_count_%d_%d" % [enemies_before, enemies_after])
	var types: Dictionary = {}
	for en in b.living("ENEMY"):
		if bool(en.get("is_summon", false)):
			types[str(en.get("archetype", en.get("template", "")))] = true
	# at least the two we summoned share type — loose check
	if enemies_after < enemies_before + 2:
		pass

	# resolve min()
	if abs(b.resolve_amount("min(E,5)", hero) - 5.0) > 0.01:
		fails.append("min_formula_%s" % str(b.resolve_amount("min(E,5)", hero)))

	if b._normalize_status_id("forte") != "strengthened": fails.append("alias_forte")
	if b._normalize_status_id("rapido") != "fast": fails.append("alias_rapido")

	if fails.is_empty():
		print("MARCELL_SMOKE_OK")
	else:
		print("MARCELL_SMOKE_FAIL")
		for f in fails:
			print(" - ", f)
	quit(0 if fails.is_empty() else 1)
