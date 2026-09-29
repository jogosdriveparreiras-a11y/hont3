extends SceneTree
## Empurrar nunca puxa; puxar nunca empurra. Daeva Cobertura = push + anim push.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const Content = preload("res://game/Content.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _play_ent(bridge: PackBridge, battle, card_id: String, owner_id: int, target_id: int) -> bool:
	battle.hand.clear()
	battle.hand.append(battle._create_card(card_id, owner_id))
	return bridge.play_card(battle, "entities", 0, target_id, [])

func _initialize() -> void:
	var bridge = PackBridge.new()
	var battle = Battle.new()
	battle.begin("street", ["guerreiro", "mago", "clerigo"], {}, 202)
	if battle.living("ALLY").is_empty() or battle.living("ENEMY").is_empty():
		_fail("street precisa de aliados e inimigos"); return

	var ally: Dictionary = battle.living("ALLY")[0]
	var foe: Dictionary = battle.living("ENEMY")[0]
	ally["row"] = "front"
	ally["statuses"] = {}
	foe["statuses"] = {}
	battle.impulse = 10
	battle.card_plays = 8
	battle.phase = "PLAYER"

	# --- push from front → back ---
	foe["row"] = "front"
	var hp_before := int(foe["hp"])
	if not _play_ent(bridge, battle, "ent_daeva_cobertura_de_corredor", int(ally["id"]), int(foe["id"])):
		_fail("Cobertura (front) não jogou"); return
	print("after front push: row=", foe["row"], " hp=", foe["hp"], " (was ", hp_before, ")")
	if foe["row"] != "back":
		_fail("push front→back falhou (row=%s)" % foe["row"]); return
	print("OK push front→back")

	# --- push already back → stay back (must NOT pull to front) ---
	foe["row"] = "back"
	foe["hp"] = maxi(8, int(foe["hp"]))
	battle.impulse = 10
	battle.card_plays = 8
	if not _play_ent(bridge, battle, "ent_daeva_cobertura_de_corredor", int(ally["id"]), int(foe["id"])):
		_fail("Cobertura (back) não jogou"); return
	print("after back push: row=", foe["row"])
	if foe["row"] != "back":
		_fail("push on back PULLED (row=%s)" % foe["row"]); return
	print("OK push on back stays back (no pull)")

	# --- pull back→front ---
	foe["row"] = "back"
	battle.impulse = 10
	battle.card_plays = 8
	if not _play_ent(bridge, battle, "ent_evelyn_graves_puxao_do_reino_quebrado", int(ally["id"]), int(foe["id"])):
		_fail("Puxão não jogou"); return
	if foe["row"] != "front":
		_fail("pull back→front falhou (row=%s)" % foe["row"]); return
	print("OK pull back→front")

	# --- pull already front → stay front ---
	foe["row"] = "front"
	battle.impulse = 10
	battle.card_plays = 8
	if not _play_ent(bridge, battle, "ent_evelyn_graves_puxao_do_reino_quebrado", int(ally["id"]), int(foe["id"])):
		_fail("Puxão (front) não jogou"); return
	if foe["row"] != "front":
		_fail("pull on front changed row to %s" % foe["row"]); return
	print("OK pull on front stays front")

	# --- flavor: Cobertura anim + actions ---
	var def: Dictionary = Content.CARDS.get("ent_daeva_cobertura_de_corredor", {})
	if def.is_empty():
		_fail("Cobertura missing from Content.CARDS"); return
	var at = def.get("anim_target", [])
	var at0 := str(at[0]) if typeof(at) == TYPE_ARRAY and not at.is_empty() else str(at)
	if at0 != "push":
		_fail("Cobertura anim_target=%s expected push" % at0); return
	var has_push := false
	var has_pull := false
	for a in def.get("actions", []):
		if typeof(a) == TYPE_ARRAY and not a.is_empty():
			if str(a[0]) == "push": has_push = true
			if str(a[0]) == "pull": has_pull = true
	if not has_push or has_pull:
		_fail("Cobertura actions push/pull wrong: %s" % str(def.get("actions"))); return
	print("OK Daeva Cobertura flavor: Empurra + anim push")

	var bad := 0
	for cid in Content.CARDS.keys():
		var c: Dictionary = Content.CARDS[cid]
		var s = c.get("anim_self", null)
		var t = c.get("anim_target", null)
		var sn := 0
		var tn := 0
		if typeof(s) == TYPE_ARRAY: sn = s.size()
		elif typeof(s) == TYPE_STRING and str(s) != "": sn = 1
		if typeof(t) == TYPE_ARRAY: tn = t.size()
		elif typeof(t) == TYPE_STRING and str(t) != "": tn = 1
		if sn != 1 or tn != 1:
			bad += 1
			if bad <= 5:
				print("VIOL ", cid, " self=", s, " target=", t)
	if bad > 0:
		_fail("anim 1+1 violations: %d" % bad); return
	print("OK anim 1+1 for all Content.CARDS (%d)" % Content.CARDS.size())

	print("PASS PushPullSmoke")
	quit(0)
