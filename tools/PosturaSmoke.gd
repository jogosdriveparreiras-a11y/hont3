extends SceneTree
## Smoke: Postura exclusivity, per-turn cap, Tanque/Furioso/Dominika alias.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var fails: Array[String] = []

	var card: Dictionary = packs.definition("ent_dominika_seur_eu_sou_a_vitima")
	if card.is_empty(): fails.append("missing_vitima_card")
	if str(card.get("name", "")) != "Eu Sou a Vítima!": fails.append("card_name")
	if str(card.get("class", "")) != "POSTURA": fails.append("card_class")
	var has_tanque := false
	for a in card.get("actions", []):
		if typeof(a) == TYPE_ARRAY and a.size() >= 2 and str(a[0]) == "self_status" and str(a[1]) == "tanque":
			has_tanque = true
	if not has_tanque: fails.append("card_actions_tanque")

	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 91)
	var ally: Dictionary = b.living("ALLY")[0]
	var foe: Dictionary = b.living("ENEMY")[0]
	var ini0: int = b._get_impulse("ALLY")

	# Alias vitima → tanque
	b._add_status(ally, "vitima", 3, 3, int(ally["id"]))
	if not b._has_status(ally, "tanque"): fails.append("vitima_alias")
	if b._has_status(ally, "vitima") and not b._has_status(ally, "tanque"):
		fails.append("vitima_still_raw")
	# Exclusive: furioso replaces tanque
	b._add_status(ally, "furioso", 2, 1, int(ally["id"]))
	if b._has_status(ally, "tanque"): fails.append("exclusive_tanque_remain")
	if not b._has_status(ally, "furioso"): fails.append("exclusive_furioso")

	# Re-apply tanque for damage tests
	b._add_status(ally, "tanque", 3, 1, int(ally["id"]))
	b._set_impulse("ALLY", 0)
	b._take_damage(foe, ally, 4, false, false)
	if b._get_impulse("ALLY") != 1: fails.append("tanque_gain_expected_1_got_%d" % b._get_impulse("ALLY"))
	# Second hit same turn: no extra INI
	b._take_damage(foe, ally, 2, false, false)
	if b._get_impulse("ALLY") != 1: fails.append("tanque_cap_broken_%d" % b._get_impulse("ALLY"))

	# Furioso on foe dealing... actually ally has tanque not furioso. Put furioso on foe.
	b._add_status(foe, "furioso", 2, 1, int(foe["id"]))
	var e_ini0: int = b._get_impulse("ENEMY")
	b._take_damage(foe, ally, 3, false, false)
	if b._get_impulse("ENEMY") != e_ini0 + 1: fails.append("furioso_gain")
	b._take_damage(foe, ally, 3, false, false)
	if b._get_impulse("ENEMY") != e_ini0 + 1: fails.append("furioso_cap")

	# Intocável via Proteção
	var ally2: Dictionary = b.living("ALLY")[1] if b.living("ALLY").size() > 1 else ally
	b._add_status(ally2, "intocavel", 2, 1, int(ally2["id"]))
	b._add_status(ally2, "protecao", 3, 2, int(ally2["id"]))
	# exclusivity wiped intocavel if we added protecao? protecao is not posture — ok
	# Wait: adding protecao doesn't clear postures. But adding intocavel then we need both.
	if not b._has_status(ally2, "intocavel"):
		b._add_status(ally2, "intocavel", 2, 1, int(ally2["id"]))
	var a2_side := str(ally2.get("side", "ALLY"))
	var a2_ini := b._get_impulse(a2_side)
	b._take_damage(foe, ally2, 5, false, false)  # should be blocked by protecao
	if int(ally2["hp"]) <= 0: fails.append("protecao_failed")
	if b._get_impulse(a2_side) < a2_ini + 2: fails.append("intocavel_gain")

	# End-of-turn Indomável
	var survivor: Dictionary = b.living("ALLY")[0]
	b._add_status(survivor, "indomavel", 2, 1, int(survivor["id"]))
	survivor["hp"] = maxi(1, int(survivor["max_hp"]) / 4)
	var s_ini := b._get_impulse("ALLY")
	b._posture_end_of_side("ALLY")
	if b._get_impulse("ALLY") < s_ini + 2: fails.append("indomavel_gain")

	if fails.is_empty():
		print("PosturaSmoke OK")
		quit(0)
	else:
		print("PosturaSmoke FAIL: ", ", ".join(fails))
		quit(1)
