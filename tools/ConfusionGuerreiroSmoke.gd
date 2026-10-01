extends SceneTree
## Smoke: deploy não loga Guerreiro; Confusão não thrasha na carta que aplica nem self-hit.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _ok(msg: String) -> void:
	print("OK: ", msg)

func _initialize() -> void:
	var packs = PackBridge.new()
	var battle = Battle.new()
	var logs: Array[String] = []
	# Capture _log via monkeypatch: append to battle by wrapping changed — use report sink.
	var ids: Array[String] = ["ent_marcell_wine"]
	if not packs.entities.deploy(battle, "road", ids, {}, 42):
		_fail("deploy arena marcell failed"); return
	var ally_name := str(battle.living("ALLY")[0].get("name", ""))
	if ally_name == "Guerreiro" or ally_name == "":
		_fail("ally ainda Guerreiro/vazio: %s" % ally_name); return
	_ok("ally name=%s" % ally_name)
	# Hand owners must not be Guerreiro
	for card in battle.hand:
		var owner: Dictionary = battle.actor_by_id(int(card.get("owner", -1)))
		if str(owner.get("name", "")) == "Guerreiro":
			_fail("carta na mão com owner Guerreiro"); return
	_ok("mão sem Guerreiro")

	# Confusão: aplicar via status direto + after_card_play na mesma jogada não deve thrash.
	var marcell: Dictionary = battle.living("ALLY")[0]
	var enemies: Array = battle.living("ENEMY")
	if enemies.is_empty():
		_fail("sem inimigos na arena"); return
	var hp_before: Dictionary = {}
	for a in battle.actors:
		hp_before[int(a["id"])] = int(a["hp"])
	battle.played_cards = 10
	battle.phase = "ENEMY"
	battle._add_status(marcell, "confused", 2, 2, int(enemies[0]["id"]))
	# play_stamp == 10; after_card_play com played_cards=10 deve pular thrash
	battle._after_card_play()
	for a in battle.actors:
		if int(a["hp"]) != int(hp_before[int(a["id"])]):
			_fail("Confusão thrashou na jogada que aplicou (id=%s hp %s→%s)" % [a["id"], hp_before[int(a["id"])], a["hp"]]); return
	if not battle._has_status(marcell, "confused"):
		_fail("Confusão sumiu sem thrash (stamp deveria preservar stacks)"); return
	# Stacks: after_card_play still decrements even when skipping damage? Looking at code:
	# play_stamp == played_cards → continue BEFORE stacks decrement. Good — stacks stay 2.
	var st: Dictionary = battle._status_state(marcell, "confused")
	if int(st.get("stacks", 0)) != 2:
		_fail("stacks deveria permanecer 2 no skip; got %s" % st.get("stacks")); return
	_ok("apply-play não thrasha (enemy phase stamp)")

	# Próxima carta: thrash, nunca self
	battle.played_cards = 11
	hp_before.clear()
	for a in battle.actors:
		hp_before[int(a["id"])] = int(a["hp"])
	battle._after_card_play()
	var lost: int = 0
	var self_hit := false
	for a in battle.actors:
		var hid := int(a["id"])
		if int(a["hp"]) < int(hp_before[hid]):
			lost += 1
			if hid == int(marcell["id"]):
				self_hit = true
	if self_hit:
		_fail("Confusão self-hit no confundido"); return
	if lost != 1:
		_fail("esperado exatamente 1 thrash hit; lost=%d" % lost); return
	_ok("thrash 1 alvo, sem self-hit")

	# EntityRuntime play order: stamp after increment before resolve
	battle2_check()
	print("ConfusionGuerreiroSmoke PASS")
	quit(0)

func battle2_check() -> void:
	var packs = PackBridge.new()
	var battle = Battle.new()
	var ids2: Array[String] = ["ent_marcell_wine"]
	if not packs.entities.deploy(battle, "road", ids2, {}, 99):
		_fail("deploy2 failed"); return
	battle.phase = "PLAYER"
	var before: int = battle.played_cards
	# Simulate EntityRuntime order: increment then status
	battle.played_cards += 1
	var m: Dictionary = battle.living("ALLY")[0]
	battle._add_status(m, "confused", 2, 2, int(m["id"]))
	var hp0 := int(m["hp"])
	for e in battle.living("ENEMY"):
		hp0 = hp0  # silence
	var hps: Dictionary = {}
	for a in battle.actors:
		hps[int(a["id"])] = int(a["hp"])
	battle._after_card_play()
	for a in battle.actors:
		if int(a["hp"]) != int(hps[int(a["id"])]):
			_fail("PLAYER path: thrash na apply-play após increment-before-resolve"); return
	_ok("PLAYER stamp skip após increment pré-resolve (played was %d→%d)" % [before, battle.played_cards])
