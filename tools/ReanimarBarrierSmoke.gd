extends SceneTree
## Smoke: Reanimar ownerless revive; block_hp absoluto; IA não zera plays em falha.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const Content = preload("res://game/Content.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _ok(msg: String) -> void:
	print("OK: ", msg)

func _initialize() -> void:
	var packs = PackBridge.new()
	# Shared pool present
	if not Content.CARDS.has("manobra_golpe"):
		_fail("manobra_golpe missing after PackBridge merge"); return
	_ok("shared pool manobra_golpe merged")

	# Designed aprimoramentos only
	var aly = Content.HEROES.get("ent_alyssa_wine", {})
	if str(aly.get("passive", "")) != "escuridao":
		_fail("Alyssa should keep escuridao"); return
	var cac = Content.HEROES.get("ent_cacadora", {})
	var apr = cac.get("aprimoramento", cac.get("passive", ""))
	var aid := str(apr.get("id", apr)) if typeof(apr) == TYPE_DICTIONARY else str(apr)
	if aid != "" and aid != "null":
		_fail("Caçadora should have no aprimoramento, got %s" % aid); return
	var kit: Array = cac.get("iniciais", cac.get("cards", []))
	if not kit.has("manobra_golpe"):
		_fail("Caçadora should use shared manobra_golpe; got %s" % str(kit)); return
	_ok("aprimoramento strip + shared kit")

	var battle = Battle.new()
	battle.begin("road", ["guerreiro", "mago", "clerigo"], {}, 77)
	# Force entity enemies with shared kits if present
	if battle.living("ENEMY").is_empty():
		_fail("no enemies"); return

	# --- barrier absolute block_hp ---
	var enemy: Dictionary = battle.living("ENEMY")[0]
	var max_hp := int(enemy["max_hp"])
	# Simulate Guarda-style actions via EntityRuntime path numbers
	# Direct: barrier with absolute 6 must not be max_hp*6
	battle._add_status(enemy, "barrier", 1, 6, int(enemy["id"]))
	var bhp := battle._barrier_hp(enemy)
	if bhp != 6:
		_fail("barrier stacks/hp expected 6 got %s" % bhp); return
	_ok("barrier absolute 6")

	# --- Reanimar ownerless ---
	enemy["hp"] = 0
	battle._sync_reanimar("ENEMY")
	var found := false
	var re_card := {}
	for pile in [battle.enemy_deck, battle.enemy_hand, battle.enemy_discard]:
		for c in pile:
			if str(c.get("id", "")) == "reanimar":
				found = true
				re_card = c
				break
	if not found:
		_fail("Reanimar not inserted"); return
	if int(re_card.get("owner", 0)) != -1 and not bool(re_card.get("ownerless", false)):
		_fail("Reanimar should be ownerless owner=-1; got %s" % str(re_card)); return
	_ok("Reanimar inserted ownerless")

	# Put reanimar in hand and try play via battle.play
	battle.enemy_hand.clear()
	battle.enemy_hand.append(re_card if not re_card.is_empty() else battle._create_card("reanimar", -1))
	battle.enemy_hand[0]["ownerless"] = true
	battle.enemy_hand[0]["owner"] = -1
	battle.phase = "ENEMY"
	battle.enemy_impulse = 10
	battle.enemy_card_plays = 3
	var dead_id := int(enemy["id"])
	var ok := battle.play(0, dead_id, [])
	if not ok:
		_fail("Reanimar play should succeed ownerless"); return
	if int(enemy.get("hp", 0)) <= 0:
		_fail("dead ally should be revived"); return
	_ok("Reanimar revived dead ally hp=%d" % int(enemy["hp"]))

	# --- AI fail mark does not zero plays ---
	battle.phase = "ENEMY"
	battle.enemy_card_plays = 3
	battle.enemy_failed_uids.clear()
	var fake := {"uid": 9999, "id": "reanimar", "owner": -1}
	battle.mark_enemy_play_failed(fake)
	if not battle.enemy_failed_uids.has(9999):
		_fail("failed uid not marked"); return
	if int(battle.enemy_card_plays) != 3:
		_fail("mark_enemy_play_failed must not change plays"); return
	_ok("AI fail mark keeps plays")

	print("ReanimarBarrierSmoke PASS")
	quit(0)
