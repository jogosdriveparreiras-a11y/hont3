extends SceneTree
## Verifica que inimigos ent_ (actions) causam dano no time do jogador.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const Content = preload("res://game/Content.gd")
const SessionReport = preload("res://game/SessionReport.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _ally_hp_sum(battle) -> int:
	var total := 0
	for a in battle.living("ALLY"):
		total += int(a["hp"])
	return total

func _initialize() -> void:
	var _packs = PackBridge.new()
	var battle = Battle.new()
	var team: Array[String] = ["guerreiro", "mago", "clerigo"]
	battle.begin("road", team, {}, 101)
	if battle.living("ENEMY").is_empty():
		_fail("Missão road deve ter inimigos"); return
	battle.begin_enemy_phase()
	if battle.phase != "ENEMY":
		_fail("fase ENEMY"); return
	battle.enemy_impulse = 10
	battle.enemy_card_plays = 3
	var enemy: Dictionary = battle.living("ENEMY")[0]
	var attack_id := "ent_akuji_brasa_negra"
	enemy["row"] = "front"
	enemy["statuses"] = {}
	for a in battle.living("ALLY"):
		a["row"] = "front"
		a["statuses"] = {}
	battle.enemy_hand.clear()
	battle.enemy_hand.append(battle._create_card(attack_id, int(enemy["id"])))
	var sum_before := _ally_hp_sum(battle)
	var ok: bool = battle.enemy_step()
	if not ok:
		_fail("enemy_step false"); return
	var sum_after := _ally_hp_sum(battle)
	print("ally HP sum ", sum_before, " -> ", sum_after, " (delta ", sum_before - sum_after, ")")
	if sum_after >= sum_before:
		_fail("enemy_step ent_ não reduziu HP do time aliado")
		return
	# Report
	var report = SessionReport.new()
	var p: String = report.start("smoke")
	report.log_ai("enemy_hit_ok", {"delta": sum_before - sum_after})
	report.close()
	if p == "":
		_fail("report path vazio"); return
	print("OK: enemy ent_ hit via enemy_step; report=", p)
	quit(0)
