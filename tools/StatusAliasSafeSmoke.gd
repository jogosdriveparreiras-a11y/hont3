extends SceneTree
## Regression: dazed→stun alias must not []-crash; on_turn_start sem signature.

const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const EntityRuntime = preload("res://addons/hotn3_entities/EntityRuntime.gd")

func _initialize() -> void:
	var packs = PackBridge.new()
	var b = Battle.new()
	b.begin("road", ["guerreiro", "mago", "clerigo"], {}, 77)
	var ally: Dictionary = b.living("ALLY")[0]
	var foe: Dictionary = b.living("ENEMY")[0]
	# Stun stored under canonical key; alias "dazed" must resolve without Invalid access.
	b._add_status(ally, "stun", 2, 1, int(foe["id"]))
	assert(b._has_status(ally, "dazed"), "dazed alias should see stun")
	assert(b._status_stacks(ally, "dazed") == 1, "dazed stacks via alias")
	b.played_cards = 99
	b._after_card_play()  # must not crash (dazed removed from play-tick list)
	assert(b._has_status(ally, "stun"), "stun still present after after_card_play")
	# Minion / herói sem signature — on_turn_start não aplica Assinatura (removida).
	var runtime = EntityRuntime.new()
	runtime.catalog = packs.entities.catalog
	var minion := {
		"id": 99, "name": "Zumbi", "hp": 1, "max_hp": 1, "side": "ALLY", "row": "front",
		"archetype": "ent_minion_zumbi", "attack": 1, "statuses": {}, "block": 0, "shield": 0
	}
	b.actors.append(minion)
	b.phase = "PLAYER"
	b.turn = maxi(1, int(b.turn))
	runtime.on_turn_start(b)
	# resist alias: _has_status("resist") == protecao
	b._add_status(foe, "protecao", 2, 1, int(ally["id"]))
	assert(b._has_status(foe, "resist"), "resist aliases to protecao")
	assert(b._status_stacks(foe, "resist") >= 1, "resist stacks via alias")
	print("StatusAliasSafeSmoke OK")
	quit(0)
