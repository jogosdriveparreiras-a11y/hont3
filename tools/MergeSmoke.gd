extends SceneTree

func _init() -> void:
	var Content = load("res://game/Content.gd")
	var before_heroes: int = Content.HEROES.size()
	var before_cards: int = Content.CARDS.size()
	var before_playable: int = 0
	for id in Content.HEROES:
		if Content.HEROES[id].get("playable", true):
			before_playable += 1
	var PackBridge = load("res://game/PackBridge.gd")
	var _packs = PackBridge.new()
	var after_heroes: int = Content.HEROES.size()
	var after_cards: int = Content.CARDS.size()
	var after_playable: int = 0
	for id in Content.HEROES:
		if Content.HEROES[id].get("playable", true):
			after_playable += 1
	var g_pool: int = Content.HEROES["guerreiro"]["pool"].size()
	var m_pool: int = Content.HEROES["mago"]["pool"].size()
	var has_adam: bool = Content.HEROES.has("ent_adam")
	var has_ms: bool = Content.CARDS.has("ms_hunter_charge")
	var has_ent_card: bool = false
	for id in Content.CARDS:
		if str(id).begins_with("ent_"):
			has_ent_card = true
			break
	var Battle = load("res://game/BattleState.gd")
	var battle = Battle.new()
	var team: Array[String] = ["guerreiro", "mago", "ladino"]
	battle.begin("road", team, {}, 42)
	var allies: Array = battle.living("ALLY")
	var ent_team: Array[String] = ["ent_akuji", "ent_adam", "ent_techna"]
	var battle2 = Battle.new()
	battle2.begin("road", ent_team, {}, 43)
	var ent_allies: Array = battle2.living("ALLY")
	var ent_names: PackedStringArray = PackedStringArray()
	for ally in ent_allies:
		ent_names.append(str(ally.get("name", "")))
	print("MERGE before heroes=%d playable=%d cards=%d" % [before_heroes, before_playable, before_cards])
	print("MERGE after heroes=%d playable=%d cards=%d" % [after_heroes, after_playable, after_cards])
	print("MERGE guerreiro_pool=%d mago_pool=%d adam=%s ms=%s ent_card=%s" % [g_pool, m_pool, has_adam, has_ms, has_ent_card])
	print("MERGE begin_default_allies=%d begin_ent_allies=%d names=%s" % [allies.size(), ent_allies.size(), ", ".join(ent_names)])
	if after_heroes <= before_heroes or after_cards <= before_cards or not has_adam or not has_ms or allies.size() != 3 or ent_allies.size() != 3:
		push_error("MERGE SMOKE FAILED")
		quit(1)
	else:
		print("OK: merge smoke")
		quit(0)
