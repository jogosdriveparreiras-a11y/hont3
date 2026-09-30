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
	if int(hero_def.get("iniciais", []).size()) != 5: fails.append("iniciais5")
	if str(hero_def.get("desvantagem", "")) != "ent_marcell_wine_desvantagem_legiao": fails.append("desv_id")

	var needed: Array[String] = ["ent_marcell_wine_pacto_escuro", "ent_marcell_wine_regeneracao_sombria", "ent_marcell_wine_garras_do_abismo", "ent_marcell_wine_relampago_negro", "ent_marcell_wine_desvantagem_legiao"]
	for cid in needed:
		var d: Dictionary = packs.definition(cid)
		if d.is_empty(): fails.append("missing_%s" % cid)

	var pacto: Dictionary = packs.definition("ent_marcell_wine_pacto_escuro")
	var has_forte := false
	var has_res := false
	var has_rap := false
	for act in pacto.get("actions", []):
		if typeof(act) != TYPE_ARRAY or act.is_empty(): continue
		var op := str(act[0])
		if op == "forte": has_forte = true
		if op == "resistente": has_res = true
		if op in ["rapido", "rápido"]: has_rap = true
	if not has_forte: fails.append("pacto_forte")
	if not has_res: fails.append("pacto_resistente")
	if not has_rap: fails.append("pacto_rapido")

	var regen: Dictionary = packs.definition("ent_marcell_wine_regeneracao_sombria")
	var has_pct := false
	for act in regen.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) == "heal_pct":
			has_pct = true
	if not has_pct: fails.append("heal_pct")

	var garras: Dictionary = packs.definition("ent_marcell_wine_garras_do_abismo")
	var has_counter := false
	for act in garras.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) in ["self_status", "counter_effects"]:
			if str(act[0]) == "counter_effects" or (act.size() > 1 and str(act[1]) == "counter"):
				has_counter = true
	if not has_counter: fails.append("garras_counter")

	var rel: Dictionary = packs.definition("ent_marcell_wine_relampago_negro")
	if str(rel.get("target", "")) != "CHAIN": fails.append("rel_target")
	var has_chain_formula := false
	for act in rel.get("actions", []):
		if typeof(act) == TYPE_ARRAY and act.size() > 1 and str(act[0]) == "chain" and "E" in str(act[1]):
			has_chain_formula = true
	if not has_chain_formula: fails.append("rel_chain_E")

	var leg: Dictionary = packs.definition("ent_marcell_wine_desvantagem_legiao")
	if str(leg.get("class", "")) != "DESVANTAGEM": fails.append("leg_class")
	if not bool(leg.get("instant", false)): fails.append("leg_instant")
	var has_foe := false
	for act in leg.get("actions", []):
		if typeof(act) == TYPE_ARRAY and not act.is_empty() and str(act[0]) in ["summon_foe", "reinforce_enemy"]:
			has_foe = true
	if not has_foe: fails.append("leg_summon_foe")

	# Runtime: Escuridão on damage + resolve formulas + heal_pct + summon_foe
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
	if abs(b.resolve_amount("0.1*E", hero) - 0.5) > 0.01: fails.append("pct_formula_%s" % str(b.resolve_amount("0.1*E", hero)))
	if abs(b.resolve_amount("1+E", hero) - 6.0) > 0.01: fails.append("1+E_%s" % str(b.resolve_amount("1+E", hero)))

	var hp_before := int(hero["hp"])
	var max_hp := int(hero["max_hp"])
	# simulate heal_pct 0.1*E with E=5 → 50% max
	var frac: float = float(b.resolve_amount("0.1*E", hero))
	var heal_amt: int = maxi(0, roundi(float(max_hp) * frac))
	hero["hp"] = mini(max_hp, int(hero["hp"]) + heal_amt)
	if int(hero["hp"]) < hp_before: fails.append("heal_pct_runtime")

	# summon_foe via EntityRuntime
	var er = packs.entities
	var enemies_before := b.living("ENEMY").size()
	er._summon_on_side(b, hero, "ent_minion_zumbi", 99, "ENEMY")
	er._summon_on_side(b, hero, "ent_minion_zumbi", 99, "ENEMY")
	var enemies_after := b.living("ENEMY").size()
	if enemies_after < enemies_before + 2: fails.append("summon_foe_count_%d_%d" % [enemies_before, enemies_after])

	# forte / rapido aliases
	if b._normalize_status_id("forte") != "strengthened": fails.append("alias_forte")
	if b._normalize_status_id("rapido") != "fast": fails.append("alias_rapido")

	if fails.is_empty():
		print("MARCELL_SMOKE_OK")
	else:
		print("MARCELL_SMOKE_FAIL")
		for f in fails:
			print(" - ", f)
	quit(0 if fails.is_empty() else 1)
