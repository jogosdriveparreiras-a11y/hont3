extends SceneTree

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var _packs = PackBridge.new()
	var team: Array[String] = ["guerreiro", "mago", "clerigo"]
	for mission_id in Content.MISSIONS:
		var battle: HotNBattle = Battle.new()
		battle.begin(mission_id, team, {}, 20260926)
		assert(battle.phase == "PLAYER" and battle.turn == 1, "Mission must start: " + mission_id)
		assert(battle.living("ALLY").size() == 3, "Three allies required: " + mission_id)
		assert(not battle.living("ENEMY").is_empty(), "Enemy wave required: " + mission_id)
		match battle.mission["objective"]:
			"ELIMINATE":
				for enemy in battle.living("ENEMY"): enemy["hp"] = 0
				battle.turn = 2
				battle._check_end()
				assert(battle.phase != "FINISHED", "Expected reinforcements cannot be skipped")
				battle.turn = 3
				battle._check_end()
			"BOSS":
				for enemy in battle.living("ENEMY"):
					if enemy.get("boss", false): enemy["hp"] = 0
				battle._check_end()
			"SURVIVE", "PROTECT":
				battle.turn = int(battle.mission["turns"])
				battle.phase = "ENEMY"
				battle._check_end()
		assert(battle.phase == "FINISHED", "Mission must complete according to its objective: " + mission_id)
	print("OK: four mission objectives, reinforcement gate and boss completion")
	quit(0)
