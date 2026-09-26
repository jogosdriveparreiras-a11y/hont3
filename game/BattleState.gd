extends RefCounted
class_name HotNBattle

signal changed
signal event(message: String)
signal finished(victory: bool)

const Content = preload("res://game/Content.gd")
var rng := RandomNumberGenerator.new()
var rules: Dictionary = Content.RULES.duplicate(true)
var mission: Dictionary = {}
var actors: Array[Dictionary] = []
var deck: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var exhausted: Array[Dictionary] = []
var card_plays := 0
var redraws := 0
var moves := 0
var item_uses := 0
var impulse := 0
var initiative := 5
var turn := 0
var phase := "PREPARING"
var protect_hp := 0
var items: Dictionary = {"potion": 1, "bomb": 1, "antidote": 1}
var environmental_used: Dictionary = {}
var combo_used := false
var team_ko_charges := 0
var improvements: Dictionary = {}
var next_actor_id := 0
var next_card_id := 0
var played_cards := 0
const NEGATIVE := ["weak", "vulnerable", "marked", "stun", "bind", "bound", "dazed", "poison", "bleed", "burn", "silence", "blind", "slow", "wounded", "corrupted", "confused", "banished", "webbed_up", "taunted", "berserk_enemy", "feeding_frenzy", "drop", "overload", "spike_bomb"]

func begin(mission_id: String, team: Array[String], equipped: Dictionary, seed_value: int = 0, card_improvements: Dictionary = {}, selected_items: Dictionary = {}) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	mission = Content.MISSIONS[mission_id].duplicate(true)
	actors.clear()
	deck.clear()
	hand.clear()
	discard.clear()
	exhausted.clear()
	next_actor_id = 0
	next_card_id = 0
	played_cards = 0
	turn = 0
	impulse = 0
	initiative = 5
	phase = "PREPARING"
	protect_hp = int(mission.get("protect_hp", 0))
	environmental_used.clear()
	combo_used = false
	team_ko_charges = 0
	improvements = card_improvements.duplicate(true)
	items = selected_items.duplicate(true) if not selected_items.is_empty() else {"potion": 1, "bomb": 1, "antidote": 1}
	for id in team:
		if Content.HEROES.has(id):
			var hero := _create_actor(Content.HEROES[id], "ALLY", id)
			var equipped_ids: Array = equipped.get(id, Content.HEROES[id]["cards"])
			for card_id in equipped_ids:
				if Content.CARDS.has(card_id):
					deck.append(_create_card(card_id, hero["id"], improvements.get(id + ":" + card_id, {})))
	for id in mission.get("enemies", []):
		spawn_enemy(id)
	_shuffle(deck)
	_draw(int(rules["opening_hand"]))
	_log("Missão: %s" % mission["name"])
	start_turn()

func _create_actor(template: Dictionary, side: String, archetype: String) -> Dictionary:
	next_actor_id += 1
	var actor := template.duplicate(true)
	actor["id"] = next_actor_id
	actor["archetype"] = archetype
	actor["side"] = side
	actor["max_hp"] = actor["hp"]
	actor["block"] = 0
	actor["shield"] = 0
	actor["statuses"] = {}
	actor["pending"] = []
	actor["phase"] = 1
	actors.append(actor)
	return actor

func _create_card(card_id: String, owner_id: int, changes: Dictionary = {}) -> Dictionary:
	next_card_id += 1
	return {"uid": next_card_id, "id": card_id, "owner": owner_id, "class": Content.CARDS.get(card_id, {}).get("class", ""), "upgrade": int(changes.get("upgrade", 0)), "mod": changes.get("mod", "")}

func spawn_enemy(enemy_id: String) -> void:
	if Content.ENEMIES.has(enemy_id):
		var enemy := _create_actor(Content.ENEMIES[enemy_id], "ENEMY", enemy_id)
		_log("%s entrou na arena." % enemy["name"])

func actor_by_id(id: int) -> Dictionary:
	for actor in actors:
		if actor["id"] == id:
			return actor
	return {}

func living(side: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for actor in actors:
		if actor["side"] == side and actor["hp"] > 0 and not _has_status(actor, "banished"):
			found.append(actor)
	return found

func _shuffle(pile: Array[Dictionary]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := pile[i]
		pile[i] = pile[j]
		pile[j] = temp

func _draw(amount: int) -> void:
	for i in range(amount):
		if hand.size() >= int(rules["hand_max"]):
			return
		if deck.is_empty():
			if discard.is_empty():
				return
			for used_card in discard:
				deck.append(used_card)
			discard.clear()
			_shuffle(deck)
		var card: Dictionary = deck.pop_back()
		var owner := actor_by_id(card["owner"])
		if owner.get("hp", 0) > 0:
			if Content.CARDS.get(card["id"], {}).has("roulette"):
				var choices: Array = Content.CARDS[card["id"]]["roulette"]
				if not choices.is_empty(): card["roulette_effect"] = choices[rng.randi_range(0, choices.size() - 1)]
			card.erase("infected")
			hand.append(card)

func start_turn() -> void:
	if phase == "FINISHED":
		return
	turn += 1
	for actor in actors:
		if actor["hp"] <= 0: continue
		if _has_status(actor, "overload"):
			actor["statuses"].erase("overload")
			_take_damage(actor, actor, 9, true, false, true)
		if actor["hp"] > 0 and _has_status(actor, "spike_bomb"):
			actor["statuses"].erase("spike_bomb")
			if not _has_status(actor, "stun") and not _has_status(actor, "bound"):
				for victim in actors:
					if victim["hp"] > 0 and victim["row"] == actor["row"]:
						_take_damage(actor, victim, 9, false, false, true, true)
						_add_status(victim, "bleed", 2, 1, int(actor["id"]))
	_check_end()
	if phase == "FINISHED": return
	phase = "PLAYER"
	card_plays = int(rules["card_plays"])
	redraws = int(rules["redraws"])
	moves = int(rules["moves"])
	item_uses = int(rules["item_uses"])
	for ally in living("ALLY"):
		if _has_status(ally, "next_turn_plays") or _has_status(ally, "neurally_enhanced"):
			card_plays = max(card_plays, 4)
			ally["statuses"].erase("next_turn_plays")
			ally["statuses"].erase("neurally_enhanced")
		match ally.get("passive", ""):
			"vanguarda":
				if ally["row"] == "front": ally["block"] += 2
			"canalizar": impulse = min(int(rules["impulse_max"]), impulse + 1)
			"baluarte": ally["shield"] += 2
	if turn > 1:
		var extra := 1 if living("ALLY").any(func(a): return _has_status(a, "strongest_there_is")) else 0
		_draw(int(rules["turn_draw"]) + extra)
	for actor in living("ALLY"):
		for payload in actor["pending"]:
			var owner_targets: Array[Dictionary] = [actor]
			_resolve(actor, owner_targets, {}, {"effects": payload})
		actor["pending"].clear()
	var arriving: Array = mission.get("reinforcements", {}).get(turn, [])
	for enemy_id in arriving:
		spawn_enemy(enemy_id)
	if not arriving.is_empty():
		_log("Reforços inimigos chegaram na rodada %d." % turn)
	_log("Rodada %d: sua vez." % turn)
	changed.emit()

func _has_status(actor: Dictionary, id: String) -> bool:
	return actor.get("statuses", {}).has(id) and actor["statuses"][id]["duration"] > 0

func _add_status(actor: Dictionary, id: String, duration: int, stacks: int, source: int) -> void:
	if actor.is_empty() or actor["hp"] <= 0:
		return
	if id in ["stun", "bind", "bound"]:
		actor["statuses"].erase("protecting")
	var state: Dictionary = actor["statuses"].get(id, {"duration": 0, "stacks": 0, "source": source})
	state["duration"] = max(int(state["duration"]), duration)
	state["stacks"] = min(9, int(state["stacks"]) + stacks)
	state["source"] = source
	state["play_stamp"] = played_cards if phase == "PLAYER" else -1
	if id == "summoning": state["armed"] = false
	actor["statuses"][id] = state
	_log("%s: %s (%d)." % [actor["name"], id, state["stacks"]])

func _cleanse(actor: Dictionary) -> void:
	for id in NEGATIVE:
		actor["statuses"].erase(id)

func can_reach(source: Dictionary, target: Dictionary, card: Dictionary) -> bool:
	if source.is_empty() or target.is_empty() or target["hp"] <= 0:
		return false
	if source["side"] != target["side"]:
		if (_has_status(target, "conceal") or _has_status(target, "protected")) and not card.get("ignore_conceal", false):
			return false
		if not card.get("reach", false):
			if source["row"] == "back" and living(source["side"]).any(func(a): return a["row"] == "front"):
				return false
			if target["row"] == "back" and living(target["side"]).any(func(a): return a["row"] == "front"):
				return false
			if _has_status(target, "barrier"):
				return false
	return true

func _targets(source: Dictionary, primary: Dictionary, card: Dictionary, chain_ids: Array = []) -> Array[Dictionary]:
	var target_kind: String = card.get("target", "ENEMY")
	var opposite := "ENEMY" if source["side"] == "ALLY" else "ALLY"
	var result: Array[Dictionary] = []
	if target_kind == "SELF":
		result.append(source)
	elif target_kind == "ALLY":
		if primary["side"] == source["side"] and primary["hp"] > 0:
			result.append(primary)
	elif target_kind == "ALL_ALLIES":
		result = living(source["side"])
	elif target_kind == "ALL_ENEMIES":
		for actor in living(opposite):
			if not _has_status(actor, "protected"):
				result.append(actor)
	elif target_kind == "ENEMY_ROW":
		if primary["side"] == opposite and can_reach(source, primary, card):
			for actor in living(opposite):
				if (actor["row"] == primary["row"] or _has_status(source, "unleashed")) and not _has_status(actor, "protected"):
					result.append(actor)
	elif target_kind == "CHAIN":
		var ids: Array = chain_ids if not chain_ids.is_empty() else [primary["id"]]
		if ids.size() <= int(card.get("chain", 1)):
			for id in ids:
				var chain_target := actor_by_id(int(id))
				if chain_target.get("side", "") == opposite and can_reach(source, chain_target, card):
					result.append(chain_target)
		if result.size() != ids.size(): result.clear()
	else:
		if primary["side"] == opposite and can_reach(source, primary, card):
			result.append(primary)
	return result

func _damage_value(source: Dictionary, target: Dictionary, effect: Dictionary, card: Dictionary) -> int:
	var attack_stat := int(source.get(effect.get("stat", "attack"), 0))
	var upgrade := int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)
	var base := int(effect.get("amount", 0)) + attack_stat + upgrade * 2
	if card.get("mod", "") == "damage":
		base += 3
	var attack_bonus := 0.0
	if _has_status(source, "strengthened"): attack_bonus += 0.50
	if _has_status(source, "weak"): attack_bonus -= 0.50
	if _has_status(source, "critical"): attack_bonus += 0.50
	if _has_status(source, "binary") or _has_status(source, "overpowered") or _has_status(source, "strongest_there_is"): attack_bonus += 1.0
	if _has_status(source, "offensive_rush"): attack_bonus += 0.25
	if _has_status(source, "ravenous"): attack_bonus += 0.15 * int(source["statuses"]["ravenous"]["stacks"])
	if _has_status(source, "en_fuego"): attack_bonus += 0.15 * int(source["statuses"]["en_fuego"]["stacks"])
	if _has_status(source, "fatal_fury"): attack_bonus += 1.0
	if (card.get("enhanced_triggered", false) or _has_status(source, "enhanced") and impulse >= 4) and card.get("class", "") == "POWER": attack_bonus += 0.25
	base = roundi(base * maxf(0.0, 1.0 + attack_bonus))
	if _has_status(source, "blind"):
		base = roundi(base * 0.75)
	if source.get("passive", "") == "rastreador" and source["row"] == "back":
		base += 2
	if source.get("passive", "") == "oportunista" and _has_status(target, "marked"):
		base += 2
	if card.get("id", "") == "dueto":
		var partner := actor_by_id(int(card.get("partner", -1)))
		if partner.get("hp", 0) > 0:
			base += floori(float(partner.get("power", 0)) / 2.0)
	var multiplier: float = Content.TYPES.get(source.get("type", ""), {}).get(target.get("type", ""), 1.0)
	if _has_status(target, "vulnerable"):
		multiplier *= 1.5
	if effect.get("environment", false) and _has_status(target, "webbed_up"):
		multiplier *= 1.5
	if _has_status(source, "blessed") and target.get("faction", "") == "abissal":
		multiplier *= 2.0
	var armor := int(target.get("armor", 0)) + (2 * int(target["statuses"].get("armor", {}).get("stacks", 0)))
	return max(1, roundi(base * multiplier) - armor)

func _take_damage(source: Dictionary, target: Dictionary, amount: int, pierce: bool = false, counter_allowed: bool = true, environmental: bool = false, area: bool = false, melee: bool = false, attack_card: bool = false, from_card: bool = false) -> bool:
	if target["hp"] <= 0:
		return false
	if amount > 0 and source["id"] != target["id"]:
		target["statuses"].erase("summoning")
		if melee and _has_status(target, "symbiote_skin"):
			_add_status(source, "bound", 1, 1, int(target["id"]))
			target["statuses"].erase("symbiote_skin")
	if _has_status(target, "invulnerable"):
		_log("%s está invulnerável." % target["name"])
		return false
	if not pierce and _has_status(target, "resist"):
		var layers := target["statuses"]["resist"]
		layers["stacks"] -= 1
		if layers["stacks"] <= 0: target["statuses"].erase("resist")
		else: target["statuses"]["resist"] = layers
		_log("%s resistiu ao ataque." % target["name"])
		return false
	if environmental and _has_status(target, "webbed_up"):
		amount = roundi(amount * 1.5)
	if environmental and _has_status(source, "full_force"):
		amount = roundi(amount * 1.5)
	if target.get("minion", false) and amount > 0:
		amount = max(amount, int(target["hp"]))
	var hp_before := int(target["hp"])
	var remaining := amount
	if not pierce:
		for layer in ["shield", "block"]:
			var absorbed: int = min(remaining, target[layer])
			target[layer] -= absorbed
			remaining -= absorbed
	target["hp"] = max(0, int(target["hp"]) - remaining)
	var hp_lost := hp_before - int(target["hp"])
	if hp_lost > 0:
		target["statuses"].erase("stun")
		if area or environmental: target["statuses"].erase("conceal")
		if source["id"] != target["id"] and from_card and (_has_status(source, "lifesteal") or _has_status(source, "blood_magic") and attack_card or _has_status(source, "berserk_lifesteal") or _has_status(source, "vampiric_essence")):
			source["hp"] = min(int(source["max_hp"]), int(source["hp"]) + hp_lost)
		if source["id"] != target["id"] and not environmental and (from_card or not counter_allowed) and _has_status(source, "bloodlust"):
			_add_status(target, "bleed", 2, 1, int(source["id"]))
		if source["id"] != target["id"] and from_card and _has_status(source, "make_em_bleed"):
			_add_status(target, "bleed", 2, 2, int(source["id"]))
		if not melee: target["statuses"].erase("symbiote_skin")
	if target["block"] <= 0:
		for id in ["binary", "bloodlust", "protecting"]: target["statuses"].erase(id)
	_log("%s sofreu %d de dano (%d PV)." % [target["name"], amount, target["hp"]])
	var died: bool = target["hp"] <= 0
	if died:
		_log("%s caiu." % target["name"])
		if _has_status(source, "fury_totem"): _draw(1)
		if _has_status(source, "en_fuego"):
			_add_status(source, "en_fuego", 99, 1, int(source["id"]))
		if team_ko_charges > 0 and _has_status(source, "all_together_now"):
			var helper := actor_by_id(int(source["statuses"]["all_together_now"]["source"]))
			if helper.get("hp", 0) > 0 and helper["id"] != source["id"]: _add_status(helper, "en_fuego", 99, 1, int(helper["id"]))
			team_ko_charges -= 1
			if team_ko_charges <= 0:
				for ally in actors: ally["statuses"].erase("all_together_now")
		_purge_dead_cards()
	if not died and target.get("boss", false) and target["phase"] == 1 and target["hp"] <= int(target["max_hp"]) / 2:
		target["phase"] = 2
		_add_status(target, "strengthened", 3, 1, int(target["id"]))
		spawn_enemy("fera")
		_log("O Guardião iniciou a segunda fase.")
	if not died and counter_allowed and _has_status(target, "counter") and source["hp"] > 0:
		_log("%s contra-atacou." % target["name"])
		_take_damage(target, source, max(1, 3 + floori(float(target["attack"]) / 2.0)), false, false)
	return died

func _purge_dead_cards() -> void:
	for pile in [deck, hand, discard]:
		for index in range(pile.size() - 1, -1, -1):
			if actor_by_id(pile[index]["owner"]).get("hp", 0) <= 0 and not actor_by_id(pile[index]["owner"]).get("statuses", {}).has("soulbound"):
				pile.remove_at(index)

func _resolve(source: Dictionary, targets: Array[Dictionary], card: Dictionary, card_data: Dictionary) -> Array[int]:
	var fallen: Array[int] = []
	var fatal_targets: Array[Dictionary] = []
	var fatal_active := _has_status(source, "fatal_fury") and card_data.get("effects", []).any(func(e): return e.get("kind", "") == "DAMAGE")
	var effects: Array = card_data.get("effects", []).duplicate(true)
	if card_data.has("roulette") and card.has("roulette_effect"): effects.append(card["roulette_effect"])
	for effect in effects:
		var kind: String = effect.get("kind", "")
		var effect_targets: Array[Dictionary] = []
		if effect.get("self", false):
			effect_targets.append(source)
		else:
			effect_targets = targets
		if kind == "DRAW":
			_draw(int(effect.get("amount", 1)))
		elif kind == "GENERATE":
			var new_id: String = effect.get("id", "")
			if Content.CARDS.has(new_id) and hand.size() < int(rules["hand_max"]):
				var generated := _create_card(new_id, int(source["id"]))
				generated["temporary"] = true
				hand.append(generated)
		elif kind == "CARD_PLAY":
			card_plays += int(effect.get("amount", 1))
		elif kind == "SUMMON":
			if source["side"] == "ENEMY":
				spawn_enemy(effect.get("id", "fera"))
		elif kind == "NEXT_TURN":
			source["pending"].append(effect.get("effects", [{"kind": "DRAW", "amount": 1}]))
		elif kind == "INFECT":
			var viable: Array[Dictionary] = []
			var owner_id := int(targets[0]["id"]) if not targets.is_empty() else int(source["id"])
			for owned_card in hand:
				if owned_card["owner"] == owner_id: viable.append(owned_card)
			if not viable.is_empty(): viable[rng.randi_range(0, viable.size() - 1)]["infected"] = true
		else:
			for target in effect_targets:
				if target["hp"] <= 0:
					continue
				match kind:
					"DAMAGE":
						var is_area := card_data.get("target", "") in ["ENEMY_ROW", "ALL_ENEMIES"]
						var is_melee := not card_data.get("reach", false) and source["side"] != target["side"]
						var original_hp := int(target["hp"])
						if _take_damage(source, target, _damage_value(source, target, effect, card), effect.get("pierce", false), true, false, is_area, is_melee, card_data.get("class", "") == "ATTACK", true):
							fallen.append(int(target["id"]))
						if fatal_active and target["hp"] > 0 and target["hp"] < original_hp and not fatal_targets.has(target): fatal_targets.append(target)
					"HEAL":
						var bonus := (int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)) * 2
						target["hp"] = min(int(target["max_hp"]), int(target["hp"]) + int(effect.get("amount", 0)) + bonus)
						_log("%s recuperou vida (%d PV)." % [target["name"], target["hp"]])
					"BLOCK":
						target["block"] += int(effect.get("amount", 0)) + (int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)) * 2
					"SHIELD":
						target["shield"] += int(effect.get("amount", 0)) + (int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)) * 2
					"STATUS":
						if effect["id"] == "all_together_now": team_ko_charges = int(effect.get("stacks", 2))
						_add_status(target, effect["id"], int(effect.get("duration", 1)), int(effect.get("stacks", 1)), int(source["id"]))
					"CURE": _cleanse(target)
					"CLEANSE", "DISPEL":
						for id in effect.get("ids", []):
							target["statuses"].erase(id)
					"PUSH":
						if _has_status(target, "bound") or _has_status(target, "protecting"):
							continue
						var force := int(effect.get("force", 1)) * (2 if effect.get("forceful", false) else 1)
						if _has_status(source, "portal"):
							if _take_damage(source, target, roundi(source["attack"] * 1.5), false, false, true): fallen.append(int(target["id"]))
							source["statuses"].erase("portal")
						if target["row"] == "front":
							target["row"] = "back"
							_log("%s recuou para a retaguarda." % target["name"])
							if force > 1 and _take_damage(source, target, 4 * force, false, false, true): fallen.append(int(target["id"]))
						elif force > 1:
							if _take_damage(source, target, 4 * force, false, false, true): fallen.append(int(target["id"]))
							_log("%s colidiu com o cenário." % target["name"])
						if _has_status(target, "drop") and target["hp"] > 0 and not target.get("boss", false):
							var chance := clampf(1.0 - float(target["hp"]) / float(target["max_hp"]), 0.1, 0.9)
							if rng.randf() < chance:
								if _take_damage(source, target, int(target["hp"]), true, false, true): fallen.append(int(target["id"]))
					"PULL":
						if target["row"] == "back" and not _has_status(target, "bound") and not _has_status(target, "protecting"):
							target["row"] = "front"
							_log("%s foi puxado para a frente." % target["name"])
					"MOVE":
						if not _has_status(target, "bound"):
							target["row"] = "back" if target["row"] == "front" else "front"
	if fatal_active:
		source["statuses"].erase("fatal_fury")
		for victim in fatal_targets: _add_status(victim, "wounded", 2, 1, int(source["id"]))
	return fallen

func _cost(source: Dictionary, definition: Dictionary) -> int:
	var cost := int(definition.get("cost", 0))
	if definition.get("class", "") in ["POWER", "COMBO"]:
		if _has_status(source, "fast"): cost -= 1
		if _has_status(source, "slow"): cost += 1
		if _has_status(source, "enhanced") and impulse >= 4:
			cost = max(0, cost - int(source["statuses"]["enhanced"]["stacks"]))
	return max(0, cost)

func _after_card_play() -> void:
	for actor in actors:
		if actor["hp"] <= 0: continue
		for id in ["dazed", "frenzy", "confused", "feeding_frenzy"]:
			if not _has_status(actor, id): continue
			var state: Dictionary = actor["statuses"][id]
			if id == "feeding_frenzy" and (_has_status(actor, "stun") or _has_status(actor, "bind") or _has_status(actor, "bound")):
				actor["statuses"].erase(id)
				continue
			if state.get("play_stamp", -1) == played_cards: continue
			state["stacks"] -= 1
			if id == "confused" and not _has_status(actor, "stun") and not _has_status(actor, "bind") and not _has_status(actor, "bound") and not _has_status(actor, "dazed"):
				var possible := living("ALLY") + living("ENEMY")
				possible.erase(actor)
				if not possible.is_empty():
					var victim: Dictionary = possible[rng.randi_range(0, possible.size() - 1)]
					_take_damage(actor, victim, max(1, int(actor["attack"])), false, false)
			if state["stacks"] > 0:
				actor["statuses"][id] = state
				continue
			actor["statuses"].erase(id)
			match id:
				"frenzy":
					if actor["side"] == "ENEMY": _enemy_action(actor)
				"feeding_frenzy":
					if mission.get("objective", "") == "PROTECT": protect_hp = max(0, protect_hp - 9)

func play(hand_index: int, target_id: int, chain_ids: Array = []) -> bool:
	if phase != "PLAYER" or hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = hand[hand_index]
	var source := actor_by_id(card["owner"])
	var target := actor_by_id(target_id)
	var definition: Dictionary = Content.CARDS.get(card["id"], {})
	if source.is_empty() or target.is_empty() or source["hp"] <= 0 or definition.is_empty():
		return false
	if card["id"] == "dueto" and actor_by_id(int(card.get("partner", -1))).get("hp", 0) <= 0:
		return false
	var cost := _cost(source, definition)
	var plays := 0 if definition.get("free", false) else int(definition.get("plays", 1))
	var initiative_change := int(definition.get("init_mod", 0))
	if impulse < cost or card_plays < plays or initiative + initiative_change < 0 or _has_status(source, "stun") or _has_status(source, "bind") or _has_status(source, "bound") or _has_status(source, "dazed") or _has_status(source, "banished") or _has_status(source, "finalized"):
		return false
	if _has_status(source, "silence") and definition.get("class", "") in ["SKILL", "POWER"]:
		return false
	var targets := _targets(source, target, definition, chain_ids)
	if definition.get("target", "") == "CHAIN" and chain_ids.size() != int(definition.get("chain", 1)):
		return false
	if targets.is_empty() or definition.get("target", "") == "CHAIN" and not chain_ids.is_empty() and targets.size() != chain_ids.size():
		return false
	var had_momentum := _has_status(source, "momentum")
	card["enhanced_triggered"] = _has_status(source, "enhanced") and impulse >= 4
	card_plays -= plays
	initiative = clampi(initiative + initiative_change, 0, 10)
	impulse = clampi(impulse - cost + int(definition.get("gain", 0)) + (1 if card.get("mod", "") == "impulse" else 0), 0, int(rules["impulse_max"]))
	_log("%s usou %s." % [source["name"], definition["name"]])
	hand.remove_at(hand_index)
	played_cards += 1
	if card.get("infected", false): _add_status(source, "bleed", 1, 1, int(source["id"]))
	if _has_status(source, "wounded"):
		_take_damage(source, source, 3 * int(source["statuses"]["wounded"]["stacks"]), true, false)
	var fallen: Array[int] = []
	if source["hp"] > 0:
		var bleed_charge := _has_status(source, "make_em_bleed") and definition.get("effects", []).any(func(e): return e.get("kind", "") == "DAMAGE")
		fallen = _resolve(source, targets, card, definition)
		if bleed_charge and _has_status(source, "make_em_bleed"):
			var charges: Dictionary = source["statuses"]["make_em_bleed"]
			charges["stacks"] -= 1
			if charges["stacks"] <= 0: source["statuses"].erase("make_em_bleed")
			else: source["statuses"]["make_em_bleed"] = charges
		if definition.get("target", "") == "CHAIN" and definition.has("full_combo") and chain_ids.size() == int(definition.get("chain", 1)) and chain_ids.all(func(id): return id == chain_ids[0]):
			var combo_target := actor_by_id(int(chain_ids[0]))
			if combo_target.get("hp", 0) > 0:
				var one: Array[Dictionary] = [combo_target]
				_resolve(source, one, card, {"effects": definition["full_combo"]})
	if source.get("archetype", "") == "clerigo" and definition.get("effects", []).any(func(e): return e.get("kind", "") == "HEAL"):
		impulse = min(int(rules["impulse_max"]), impulse + 1)
		_log("Clérigo ganhou Ímpeto ao curar.")
	if plays > 0 and (definition.get("quick", false) and fallen.has(target_id) or fallen.any(func(id): return _has_status(actor_by_id(id), "marked"))):
		card_plays += 1
		_log("Ação recuperada.")
	if definition.get("final", false): _add_status(source, "finalized", 1, 1, int(source["id"]))
	if _has_status(source, "conceal") and definition.get("target", "") not in ["SELF", "ALL_ALLIES"]:
		source["statuses"].erase("conceal")
	if had_momentum and definition.get("class", "") != "MOVE": source["statuses"].erase("momentum")
	if _has_status(source, "ravenous") and definition.get("class", "") in ["ATTACK", "POWER"]:
		source["statuses"]["ravenous"]["stacks"] = max(0, int(source["statuses"]["ravenous"]["stacks"]) - 1)
	if card.get("temporary", false) or definition.get("exhaust", false):
		card.erase("enhanced_triggered")
		exhausted.append(card)
	else:
		card.erase("infected")
		card.erase("enhanced_triggered")
		discard.append(card)
	_after_card_play()
	_check_combo()
	_check_end()
	changed.emit()
	return true

func _check_combo() -> void:
	if combo_used or living("ALLY").size() < 2:
		return
	if impulse >= 4 and not hand.any(func(c): return c["id"] == "dueto") and hand.size() < int(rules["hand_max"]):
		var combo := _create_card("dueto", int(living("ALLY")[0]["id"]))
		combo["partner"] = int(living("ALLY")[1]["id"])
		hand.append(combo)
		combo_used = true
		_log("Uma combinação de equipe entrou na mão.")

func redraw(hand_index: int) -> bool:
	if phase != "PLAYER" or redraws <= 0 or hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = hand.pop_at(hand_index)
	redraws -= 1
	var definition: Dictionary = Content.CARDS.get(card["id"], {})
	var source := actor_by_id(card["owner"])
	var targets: Array[Dictionary] = [source]
	_resolve(source, targets, card, {"effects": definition.get("on_redraw", [])})
	if card.get("mod", "") == "redraw":
		impulse = min(int(rules["impulse_max"]), impulse + 1)
	if card.get("temporary", false): exhausted.append(card)
	else:
		card.erase("infected")
		discard.append(card)
	_draw(1)
	_log("Carta redesenhada.")
	changed.emit()
	return true

func move_actor(id: int) -> bool:
	var actor := actor_by_id(id)
	if phase != "PLAYER" or moves <= 0 and not _has_status(actor, "momentum") or actor.get("side", "") != "ALLY" or actor.get("hp", 0) <= 0 or _has_status(actor, "bind") or _has_status(actor, "bound") or _has_status(actor, "stun") or _has_status(actor, "banished") or _has_status(actor, "finalized"):
		return false
	actor["row"] = "back" if actor["row"] == "front" else "front"
	if not _has_status(actor, "momentum"): moves -= 1
	_log("%s mudou de linha." % actor["name"])
	changed.emit()
	return true

func use_item(id: String, target_id: int) -> bool:
	var target := actor_by_id(target_id)
	if phase != "PLAYER" or item_uses <= 0 or items.get(id, 0) <= 0 or target.is_empty() or target.get("hp", 0) <= 0:
		return false
	if id in ["potion", "antidote"] and target["side"] != "ALLY":
		return false
	if id == "bomb" and target["side"] != "ENEMY":
		return false
	match id:
		"potion": target["hp"] = min(int(target["max_hp"]), int(target["hp"]) + 15)
		"antidote":
			for status in ["poison", "bleed", "burn"]: target["statuses"].erase(status)
		"bomb":
			if living("ALLY").is_empty(): return false
			_take_damage(living("ALLY")[0], target, 12)
	items[id] -= 1
	item_uses -= 1
	_log("Item utilizado: %s." % id)
	_check_end()
	changed.emit()
	return true

func use_environment(index: int) -> bool:
	var objects: Array = mission.get("environment", [])
	if phase != "PLAYER" or index < 0 or index >= objects.size() or environmental_used.get(index, false) or living("ALLY").is_empty():
		return false
	var object: Dictionary = objects[index]
	var user: Dictionary = living("ALLY")[0]
	var cost := int(object.get("cost", 0))
	for ally in living("ALLY"):
		if _has_status(ally, "opportunist"):
			user = ally
			break
		if _has_status(ally, "full_force") or _has_status(ally, "naturalist") or _has_status(ally, "perfect_aim"):
			user = ally
	if _has_status(user, "opportunist"):
		cost = 0
	elif _has_status(user, "naturalist") or _has_status(user, "full_force"):
		cost = max(0, cost - 1)
	if impulse < cost:
		return false
	impulse -= cost
	if _has_status(user, "opportunist"):
		user["statuses"]["opportunist"]["stacks"] -= 1
		if user["statuses"]["opportunist"]["stacks"] <= 0: user["statuses"].erase("opportunist")
	environmental_used[index] = true
	for enemy in living("ENEMY"):
		if object.get("target", "front") == enemy["row"] and not _has_status(enemy, "protected"):
			if object.has("damage"):
				var amount := int(object["damage"])
				if _has_status(user, "perfect_aim"): amount = roundi(amount * 1.5)
				_take_damage(user, enemy, amount, false, false, true, true)
			if object.has("status"):
				_add_status(enemy, object["status"], 2, 1, 0)
	if object.get("target", "") == "ally":
		for ally in living("ALLY"):
			ally["hp"] = min(int(ally["max_hp"]), int(ally["hp"]) + int(object.get("heal", 0)))
	_log("Cenário ativado: %s." % object["name"])
	if object.has("damage") and _has_status(user, "perfect_aim"):
		user["statuses"]["perfect_aim"]["stacks"] -= 1
		if user["statuses"]["perfect_aim"]["stacks"] <= 0: user["statuses"].erase("perfect_aim")
	_check_end()
	changed.emit()
	return true

func preview(hand_index: int, target_id: int, chain_ids: Array = []) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size(): return {}
	var card: Dictionary = hand[hand_index]
	var source := actor_by_id(card["owner"])
	var target := actor_by_id(target_id)
	if source.is_empty() or target.is_empty(): return {}
	var definition: Dictionary = Content.CARDS.get(card["id"], {})
	var targets := _targets(source, target, definition, chain_ids)
	if targets.is_empty(): return {}
	var rows: Array[String] = []
	var estimates := {}
	var defenses := {}
	for victim in targets:
		if not defenses.has(victim["id"]):
			defenses[victim["id"]] = {"hp": int(victim["hp"]), "shield": int(victim["shield"]), "block": int(victim["block"]), "resist": int(victim["statuses"].get("resist", {}).get("stacks", 0))}
			estimates[victim["id"]] = {"damage": 0, "hp_after": int(victim["hp"])}
			rows.append(victim["row"])
	for effect in definition.get("effects", []):
		if effect.get("kind", "") != "DAMAGE": continue
		for victim in targets:
			var state: Dictionary = defenses[victim["id"]]
			if state["hp"] <= 0 or _has_status(victim, "invulnerable"): continue
			if not effect.get("pierce", false) and state["resist"] > 0:
				state["resist"] -= 1
				continue
			var damage := _damage_value(source, victim, effect, card)
			if victim.get("minion", false): damage = max(damage, int(state["hp"]))
			if not effect.get("pierce", false):
				for layer in ["shield", "block"]:
					var blocked := min(damage, int(state[layer]))
					state[layer] -= blocked
					damage -= blocked
			var lost := min(int(state["hp"]), damage)
			state["hp"] -= lost
			estimates[victim["id"]]["damage"] += lost
			estimates[victim["id"]]["hp_after"] = state["hp"]
	return {"targets": estimates, "rows": rows, "impulse_after": clampi(impulse - _cost(source, definition) + int(definition.get("gain", 0)), 0, int(rules["impulse_max"])), "effects": definition.get("effects", [])}

func end_player_turn() -> void:
	if phase != "PLAYER": return
	phase = "ENEMY"
	var enemies := living("ENEMY")
	enemies.sort_custom(func(a, b): return a["speed"] > b["speed"])
	for enemy in enemies:
		if enemy["hp"] <= 0 or _has_status(enemy, "stun") or _has_status(enemy, "bind") or _has_status(enemy, "bound") or _has_status(enemy, "dazed") or _has_status(enemy, "banished"):
			continue
		var actions := 2 if enemy.get("boss", false) and enemy["phase"] >= 2 else 1
		for action in range(actions):
			if enemy["hp"] <= 0 or living("ALLY").is_empty(): break
			_enemy_action(enemy)
	_tick_statuses()
	if mission.get("objective", "") == "PROTECT" and not living("ENEMY").is_empty():
		protect_hp = max(0, protect_hp - max(1, living("ENEMY").size() * 2))
		_log("A sentinela sofreu pressão: %d PV." % protect_hp)
	_check_end()
	if phase != "FINISHED": start_turn()
	changed.emit()

func _enemy_action(enemy: Dictionary) -> void:
	if enemy["hp"] <= 0 or _has_status(enemy, "stun") or _has_status(enemy, "bind") or _has_status(enemy, "bound") or _has_status(enemy, "dazed") or _has_status(enemy, "banished"): return
	if _has_status(enemy, "summoning"): return
	if _has_status(enemy, "wounded"):
		_take_damage(enemy, enemy, 3 * int(enemy["statuses"]["wounded"]["stacks"]), true, false)
		if enemy["hp"] <= 0: return
	if _has_status(enemy, "berserk_enemy"):
		enemy["statuses"].erase("berserk_enemy")
		var nearby: Array[Dictionary] = []
		for actor in actors:
			if actor["id"] != enemy["id"] and actor["hp"] > 0 and actor["row"] == enemy["row"]:
				nearby.append(actor)
		if not nearby.is_empty():
			var victim: Dictionary = nearby[rng.randi_range(0, nearby.size() - 1)]
			_take_damage(enemy, victim, int(enemy["attack"]) + 4, false, false)
		return
	var forced: Array[Dictionary] = []
	if not _has_status(enemy, "fatal_fury") and not _has_status(enemy, "overload") and not _has_status(enemy, "summoning"):
		for ally in living("ALLY"):
			if _has_status(ally, "taunt"): forced.append(ally)
		if _has_status(enemy, "taunted"):
			var taunter := actor_by_id(int(enemy["statuses"]["taunted"]["source"]))
			if taunter.get("hp", 0) > 0:
				forced.clear()
				forced.append(taunter)
	var best_score := -100000.0
	var best_card: Dictionary = {}
	var best_target: Dictionary = {}
	for ability in enemy.get("skills", []):
		var card: Dictionary = Content.ENEMY_CARDS.get(ability, {})
		if card.is_empty(): continue
		if card.has("objective") and mission.get("objective", "") != card["objective"]: continue
		if card.get("target", "") == "SELF" and card.get("effects", []).any(func(e): return e.get("kind", "") == "STATUS" and _has_status(enemy, e.get("id", ""))): continue
		var possibilities := [enemy] if card.get("target", "") == "SELF" else (forced if not forced.is_empty() else living("ALLY"))
		for target in possibilities:
			if card.get("target", "") != "SELF" and not can_reach(enemy, target, card): continue
			var score := 0.0
			if card.get("target", "") == "SELF":
				score = float(card.get("priority", 0)) + (1.0 - float(enemy["hp"]) / float(enemy["max_hp"])) * 12.0 - float(enemy["block"]) * 0.3
			else:
				for effect in card.get("effects", []):
					if effect.get("kind", "") == "DAMAGE":
						var estimate := _damage_value(enemy, target, effect, {})
						score += estimate + (18 if estimate >= target["hp"] + target["block"] + target["shield"] else 0)
					elif effect.get("kind", "") == "STATUS": score += 3
				if _has_status(target, "vulnerable"): score += 4
				if _has_status(target, "taunt"): score += 30
				if target["row"] == "back": score += 1
				if mission.get("objective", "") == "PROTECT": score += 2
			if score > best_score:
				best_score = score
				best_card = card
				best_target = target
	if not best_card.is_empty():
		_log("%s usou %s." % [enemy["name"], best_card["name"]])
		_resolve(enemy, _targets(enemy, best_target, best_card), {}, best_card)

func _tick_statuses() -> void:
	var field_emitters: Array[Dictionary] = []
	var linked_groups: Dictionary = {}
	var statuses_at_start: Dictionary = {}
	var initially_dead: Array[Dictionary] = []
	var turn_actors: Array[Dictionary] = []
	for actor in actors: turn_actors.append(actor)
	for actor in turn_actors:
		statuses_at_start[actor["id"]] = actor["statuses"].keys()
		if actor["hp"] <= 0: initially_dead.append(actor)
		if _has_status(actor, "soulbound"):
			var group_id := int(actor["statuses"]["soulbound"]["source"])
			if not linked_groups.has(group_id): linked_groups[group_id] = []
			linked_groups[group_id].append(actor)
	for actor in turn_actors:
		if actor["hp"] <= 0: continue
		if _has_status(actor, "chaos_field"): field_emitters.append(actor)
		for id in statuses_at_start[actor["id"]]:
			if not actor["statuses"].has(id): continue
			var state: Dictionary = actor["statuses"][id]
			match id:
				"poison", "bleed", "burn", "corrupted":
					_take_damage(actor, actor, max(1, int(state["stacks"]) * 2), true, false)
					if id == "corrupted":
						for other in actors:
							if other["id"] != actor["id"] and other["hp"] > 0 and other["row"] == actor["row"]:
								_add_status(other, "corrupted", 2, 1, int(actor["id"]))
				"regen": actor["hp"] = min(int(actor["max_hp"]), int(actor["hp"]) + int(state["stacks"]) * 3)
				"ravenous": state["stacks"] = min(5, int(state["stacks"]) + 1)
				"summoning":
					if state.get("armed", false):
						if actor["side"] == "ENEMY": spawn_enemy("fera")
						state["duration"] = 1
					else: state["armed"] = true
			if not actor["statuses"].has(id): continue
			if id in ["binary", "bloodlust", "protecting"] and actor["block"] > 0: continue
			state["duration"] -= 1
			if state["duration"] <= 0: actor["statuses"].erase(id)
			else: actor["statuses"][id] = state
	for actor in field_emitters:
		if actor["hp"] <= 0: continue
		for ally in actors:
			if ally["side"] == actor["side"] and ally["hp"] > 0 and ally["row"] == actor["row"]:
				_add_status(ally, "resist", 1, 1, int(actor["id"]))
	for group_id in linked_groups:
		var linked: Array = linked_groups[group_id]
		if not linked.any(func(a): return a["hp"] > 0): continue
		var pool := 0
		for actor in linked: pool += int(actor["hp"])
		var shared := max(1, floori(float(pool) / float(linked.size())))
		for actor in linked: actor["hp"] = min(int(actor["max_hp"]), shared)
	for actor in initially_dead:
		for id in statuses_at_start[actor["id"]]:
			if not actor["statuses"].has(id): continue
			var state: Dictionary = actor["statuses"][id]
			state["duration"] -= 1
			if state["duration"] <= 0: actor["statuses"].erase(id)
			else: actor["statuses"][id] = state
	_purge_dead_cards()

func _check_end() -> void:
	if phase == "FINISHED": return
	if not actors.any(func(a): return a["side"] == "ALLY" and a["hp"] > 0) or mission.get("objective", "") == "PROTECT" and protect_hp <= 0:
		phase = "FINISHED"
		finished.emit(false)
		return
	var objective: String = mission.get("objective", "ELIMINATE")
	var victory := false
	match objective:
		"ELIMINATE": victory = not actors.any(func(a): return a["side"] == "ENEMY" and a["hp"] > 0) and mission.get("reinforcements", {}).keys().all(func(t): return t <= turn)
		"BOSS":
			victory = not actors.any(func(a): return a.get("boss", false) and a["hp"] > 0)
			for boss in actors:
				if not victory or not boss.get("boss", false) or not _has_status(boss, "soulbound"): continue
				var link := int(boss["statuses"]["soulbound"]["source"])
				if actors.any(func(a): return a["hp"] > 0 and a.get("statuses", {}).has("soulbound") and int(a["statuses"]["soulbound"]["source"]) == link):
					victory = false
		"SURVIVE", "PROTECT": victory = turn >= int(mission.get("turns", 0)) and phase == "ENEMY"
	if victory:
		phase = "FINISHED"
		finished.emit(true)

func _log(message: String) -> void:
	event.emit(message)
