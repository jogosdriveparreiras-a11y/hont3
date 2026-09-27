extends RefCounted
class_name HotN3ExternalCardRuntime

const Content = preload("res://game/Content.gd")
const Catalog = preload("res://addons/hotn3_external_cards/CardPack.gd")
var catalog = Catalog.new()
var memory: Dictionary = {} # Scoped to the current battle instance; reset with install().

func install(battle: Variant, owner_map: Dictionary, selected: Dictionary = {}) -> int:
	# Call after battle.begin(); owner_map maps original owner IDs to HotN3 actor IDs.
	memory.clear()
	var installed := 0
	for owner in (selected.keys() if not selected.is_empty() else owner_map.keys()):
		var actor_id: int = int(owner_map.get(owner, -1))
		var actor: Dictionary = battle.actor_by_id(actor_id)
		if actor.is_empty() or actor.get("side") != "ALLY": continue
		if owner == "deadpool": _stack(actor, "en_fuego", 0)
		if owner == "venom": _stack(actor, "ravenous", 5)
		memory[actor_id] = owner
		var entries: Array = selected.get(owner, catalog.ids_for(owner))
		for id in entries:
			if catalog.definition(str(id)).is_empty(): continue
			battle.next_card_id += 1
			battle.deck.append({"uid": battle.next_card_id, "id": str(id), "owner": actor_id, "class": catalog.definition(str(id))["class"], "upgrade": 0, "external_pack": true})
			installed += 1
	battle._shuffle(battle.deck)
	return installed

func play(battle: Variant, hand_index: int, target_id: int, chain_ids: Array = []) -> bool:
	if hand_index < 0 or hand_index >= battle.hand.size(): return false
	var card: Dictionary = battle.hand[hand_index]
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return battle.play(hand_index, target_id, chain_ids)
	var source: Dictionary = battle.actor_by_id(int(card["owner"]))
	var target: Dictionary = battle.actor_by_id(target_id)
	if battle.phase != "PLAYER" or source.is_empty() or target.is_empty(): return false
	if int(source.get("hp", 0)) <= 0 and not _has_action(def, "revive_self"): return false
	# Itens com dono explícito: dono precisa estar vivo / no time.
	if bool(def.get("item", false)) and def.has("owner_hero"):
		var need := str(def["owner_hero"])
		var ok := false
		for ally in battle.living("ALLY"):
			if str(ally.get("archetype", "")) == need:
				ok = true; break
		if not ok: return false
	if int(target.get("hp", 0)) <= 0 and not _has_action(def, "revive_self"): return false
	if not bool(def.get("play_while_disabled", false)):
		for locked in ["stun", "bind", "bound", "dazed", "banished", "finalized"]:
			if battle._has_status(source, locked): return false
	var cost: int = int(card.get("cost_override", def.get("cost", 0)))
	# Custo gasta Iniciativa (recurso compartilhado do turno) — não existe pool de "Poder".
	if cost > 0:
		if battle._has_status(source, "fast"): cost -= 1
		if battle._has_status(source, "slow"): cost += 1
		if _has_action(def, "cost_down_en_fuego"): cost -= int(_counter(source, "en_fuego"))
	cost = maxi(0, cost)
	var owner_free: bool = def.get("owner") == "spider_man" and _counter(source, "free_owner") > 0
	var plays: int = 0 if bool(def.get("free", false)) or owner_free else 1
	if battle.impulse < cost or battle.card_plays < plays: return false
	var resolved_def: Dictionary = def.duplicate(true)
	if def.get("target") == "CHAIN":
		resolved_def["chain"] = int(def.get("chain", 1)) + int(card.get("next_chain", 0))
		if _has_action(def, "grow_chain"): resolved_def["chain"] += int(_counter(source, str(_action(def, "grow_chain")[1])))
		if _has_action(def, "chain_hand_owner"):
			resolved_def["chain"] = maxi(1, battle.hand.filter(func(c): return c.get("owner") == source["id"]).size())
	var targets: Array[Dictionary] = []
	if _has_action(def, "revive_self"):
		targets.append(source)
	else:
		targets = battle._targets(source, target, resolved_def, chain_ids)
	for a in def["actions"]:
		if a[0] == "requires_status" and not battle._has_status(target, str(a[1])): return false
	if def.get("target") == "CHAIN":
		var chain_count := int(resolved_def["chain"])
		if _has_action(def, "chain_hand_owner"):
			chain_count = maxi(1, battle.hand.filter(func(c): return c.get("owner") == source["id"]).size())
		if chain_ids.size() != chain_count or targets.size() != chain_count: return false
	if targets.is_empty(): return false
	var spent_impulse: int = int(battle.impulse)
	battle.hand.remove_at(hand_index)
	battle.card_plays -= plays
	if owner_free: _consume(source, "free_owner")
	battle.impulse = clampi(battle.impulse - cost + int(def.get("gain", 0)) * (2 if battle._has_status(source, "double_gain") else 1), 0, int(battle.rules["impulse_max"]))
	var kos: Array[int] = []
	var last_hit := 0
	var acted: Array[String] = []
	for a in def["actions"]:
		var op: String = a[0]
		if acted.has(op) and op in ["quick", "free", "exhaust", "final"]: continue
		acted.append(op)
		match op:
			"hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "roulette_hit":
				# Dano aditivo: Carta + Impacto − Armadura  OU  Carta + Poder − Escudo (+ mods).
				var card_amt := float(a[1]) if a.size() > 1 else 0.0
				if op == "hit_per_impulse": card_amt *= float(spent_impulse)
				if op == "hit_per_hand": card_amt *= float(battle.hand.size())
				if op == "hit_from_block": card_amt = float(source.get("block", 0))
				if op == "roulette_hit": card_amt = float(card.get("roulette_factor", a[battle.rng.randi_range(1, a.size() - 1)]))
				for victim in targets:
					var before_hp := int(victim["hp"])
					var bonus := _bonus(battle, source, victim, def, card)
					var base := card_amt + float(_offense(source, def)) + bonus
					var multiplier: float = 0.5 if battle._has_status(source, "weak") else 1.0
					if battle._has_status(source, "strengthened"): multiplier *= 1.5
					if battle._has_status(source, "binary") or battle._has_status(source, "overpowered"): multiplier *= 2.0
					if battle._has_status(victim, "vulnerable"): multiplier *= 1.5
					if card.get("critical", false): multiplier *= 1.5
					multiplier *= 1.0 + 0.2 * float(_counter(source, "ravenous"))
					# Impacto − Armadura; Poder − Escudo (atributo). Mods % já em multiplier.
					var damage_stat := str(def.get("stat", "attack"))
					var defense: int = int(victim.get("escudo", 0)) if damage_stat == "power" else (int(victim.get("armor", 0)) + (2 * int(victim.get("statuses", {}).get("armor", {}).get("stacks", 0))))
					# Espécie (±25% tipicamente via vs_species na carta).
					var vs: Dictionary = def.get("vs_species", {})
					var sp := str(victim.get("species", ""))
					if sp != "" and vs.has(sp):
						multiplier *= 1.0 + float(vs[sp])
					# Arquétipo (DESLIGADO por padrão).
					if bool(Content.RULES.get("archetype_matchup", false)):
						multiplier *= _archetype_mult(source, victim)
					last_hit = maxi(1, roundi(base * multiplier) - defense)
					if battle._take_damage(source, victim, last_hit, false, true, false, targets.size() > 1, not bool(def.get("reach", false)), _is_damage_card(def), true):
						if not kos.has(victim["id"]): kos.append(victim["id"])
					if _has_action(def, "block_from_hit"): source["block"] += last_hit
					if _has_action(def, "lifesteal"):
						source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + maxi(0, before_hp - int(victim["hp"])))
			"choice":
				for victim in targets:
					if victim.get("side") == "ALLY":
						if a[3] == "cure": battle._cleanse(victim)
						else: victim["hp"] = mini(int(victim["max_hp"]), int(victim["hp"]) + roundi(float(source["attack"]) * float(a[4])))
					else:
						if battle._take_damage(source, victim, maxi(1, roundi(float(source["attack"]) + float(a[2]))), false, true, false, false, false, true, true): kos.append(int(victim["id"]))
			"status", "self_status":
				for victim in ([source] if op == "self_status" else targets):
					var stacks := int(a[2]) if a.size() > 2 else 1
					battle._add_status(victim, str(a[1]), maxi(1, stacks), stacks, int(source["id"]))
					if a[1] == "all_together_now": battle.team_ko_charges = stacks
			"block", "block_hp":
				for victim in targets: victim["block"] += int(a[1]) if op == "block" else roundi(float(victim["max_hp"]) * float(a[1]))
			"heal", "full_heal", "heal_all":
				var healed: Array = battle.living("ALLY") if op == "heal_all" else targets
				for victim in healed:
					# Cura = Vida absoluta (não × ATK/Impacto).
					victim["hp"] = int(victim["max_hp"]) if op == "full_heal" else mini(int(victim["max_hp"]), int(victim["hp"]) + int(round(float(a[1]) if a.size() > 1 else 0.0)))
			"cure":
				for victim in targets: battle._cleanse(victim)
			"push", "pull", "move_target":
				for victim in targets:
					if battle._has_status(victim, "bound") or battle._has_status(victim, "protecting"): continue
					victim["row"] = "front" if op == "pull" else ("back" if victim["row"] == "front" else "front")
					if op == "push":
						var force := int(a[1])
						if _has_action(def, "force_if_damaged") and int(victim["hp"]) < int(victim["max_hp"]): force *= 2
						if battle._has_status(source, "portal"):
							var portal_damage: int = roundi(float(source["attack"]) * (1.5 if battle._has_status(source, "limbos_grasp") else 0.5))
							battle._take_damage(source, victim, portal_damage, false, false, true)
							source["statuses"].erase("portal")
						if force > 1:
							if battle._take_damage(source, victim, 4 * force, false, false, true, false, false, false, true): kos.append(int(victim["id"]))
			"draw", "draw_owner", "draw_owner_to", "draw_heroic", "draw_attack_heroic":
				_draw_filtered(battle, source, op, int(a[1]))
			"discard_hand":
				for held in battle.hand: battle.discard.append(held)
				battle.hand.clear()
			"discard_random":
				if not battle.hand.is_empty(): battle.discard.append(battle.hand.pop_at(battle.rng.randi_range(0, battle.hand.size() - 1)))
			"self_damage", "self_damage_hp":
				var amount := roundi(float(source["attack"]) * float(a[1])) if op == "self_damage" else roundi(float(source["max_hp"]) * float(a[1]))
				battle._take_damage(source, source, amount, true, false)
			"consume_bleed":
				for victim in targets:
					if not battle._has_status(victim, "bleed"): continue
					var s: Dictionary = victim["statuses"]["bleed"]
					var amount: int = 3 * int(s.get("stacks", 1)) * int(s.get("duration", 1))
					victim["statuses"].erase("bleed")
					if battle._take_damage(source, victim, amount, true, false, false, false, false, false, true): kos.append(int(victim["id"]))
			"taunt":
				var provoked: Array = targets if target.get("side") == "ENEMY" else battle.living("ENEMY")
				for victim in provoked: battle._add_status(victim, "taunted", 1, 1, int(source["id"]))
			"taunt_attackers":
				for foe in battle.living("ENEMY"):
					if int(foe.get("intent_target", -1)) == int(target["id"]): battle._add_status(foe, "taunted", 1, 1, int(source["id"]))
			"rage", "ravenous": _stack(source, op, int(a[1]))
			"rage_per_targeting":
				for foe in battle.living("ENEMY"):
					if int(foe.get("intent_target", -1)) == int(source["id"]): _stack(source, "rage", 1)
			"consume_rage_heal":
				var recovered := roundi(float(_counter(source, "rage")) * 0.33 * float(source["max_hp"]))
				source["statuses"].erase("rage")
				if _has_action(def, "overheal_max") and int(source["hp"]) + recovered > int(source["max_hp"]):
					source["max_hp"] = int(source["hp"]) + recovered
				source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + recovered)
			"gain_en_fuego": battle.impulse = mini(int(battle.rules["impulse_max"]), battle.impulse + int(_counter(source, "en_fuego")) * int(a[1]))
			"draw_en_fuego": battle._draw(int(_counter(source, "en_fuego")) * int(a[1]))
			"resist_en_fuego": battle._add_status(source, "resist", 1, int(_counter(source, "en_fuego")) * int(a[1]), int(source["id"]))
			"double_impulse": battle.impulse = mini(int(battle.rules["impulse_max"]), battle.impulse * 2)
			"redraws": battle.redraws += int(a[1])
			"moves": battle.moves += int(a[1])
			"zero_random_heroic", "zero_heroics":
				var candidates: Array = battle.hand.filter(func(c): return _card_costs_initiative(c))
				if op == "zero_random_heroic" and not candidates.is_empty(): candidates = [candidates[battle.rng.randi_range(0, candidates.size() - 1)]]
				for held in candidates:
					held["cost_override"] = 0
					if op == "zero_heroics": held["cost_override_until"] = int(battle.turn)
			"copy_hand_type":
				if battle.hand.is_empty(): continue
				var chosen: Dictionary = battle.hand[battle.rng.randi_range(0, battle.hand.size() - 1)]
				var originals: Array = battle.hand.duplicate(true)
				for held in originals:
					if held.get("class") == chosen.get("class") and battle.hand.size() < battle.rules["hand_max"]:
						var copy: Dictionary = held.duplicate(true)
						battle.next_card_id += 1
						copy["uid"] = battle.next_card_id
						copy["temporary"] = true
						battle.hand.append(copy)
			"critical_hand", "upgrade_hand", "buff_hand":
				for held in battle.hand:
					if op == "critical_hand": held["critical"] = true
					elif op == "upgrade_hand": held["upgrade"] = int(held.get("upgrade", 0)) + 1
					else: held["bonus_attack"] = float(held.get("bonus_attack", 0)) + float(a[1])
			"mark_bleeding":
				for foe in battle.living("ENEMY"):
					if battle._has_status(foe, "bleed"): battle._add_status(foe, "marked", 2, int(a[1]), int(source["id"]))
			"heal_per_bleed":
				var count: int = battle.living("ENEMY").filter(func(foe): return battle._has_status(foe, "bleed")).size()
				source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + count * int(source["attack"]) * int(a[1]))
			"chance_status", "roulette_status":
				for victim in targets:
					if op == "chance_status" and battle.rng.randf() > float(a[2]): continue
					var chosen_status: String = str(a[1]) if op == "chance_status" else str(card.get("roulette_status", a[battle.rng.randi_range(1, a.size() - 1)]))
					battle._add_status(victim, chosen_status, 1, 1, int(source["id"]))
			"next_ravenous", "next_draw": source["pending"].append([{"kind": "STATUS", "id": "ravenous", "stacks": int(a[1])}] if op == "next_ravenous" else [{"kind": "DRAW", "amount": int(a[1])}])
			"next_chain", "next_damage", "next_cost", "next_quick", "next_area": card[op] = int(a[1]) if a.size() > 1 else true
			"return_attacks":
				var recovered := 0
				for index in range(battle.discard.size() - 1, -1, -1):
					if recovered >= int(a[1]) or battle.hand.size() >= battle.rules["hand_max"]: break
					if battle.discard[index].get("class") == "ATTACK":
						battle.hand.append(battle.discard.pop_at(index)); recovered += 1
			"retain_next", "free_owner": _stack(source, op, int(a[1]))
			"buff_returned":
				for held in battle.hand:
					if held.get("class") == "ATTACK": held["bonus_attack"] = float(held.get("bonus_attack", 0)) + float(a[1])
			"enhanced_resist":
				if spent_impulse >= int(a[1]):
					for ally in battle.living("ALLY"): battle._add_status(ally, "resist", 1, 1, int(source["id"]))
			"ko":
				if kos.is_empty(): continue
				match str(a[1]):
					"conceal", "strengthened": battle._add_status(source, str(a[1]), 1, 1, int(source["id"]))
					"draw2": battle._draw(2)
					"heal_ally":
						var allies: Array[Dictionary] = battle.living("ALLY")
						if not allies.is_empty():
							var beneficiary: Dictionary = allies[battle.rng.randi_range(0, allies.size() - 1)]
							beneficiary["hp"] = mini(int(beneficiary["max_hp"]), int(beneficiary["hp"]) + int(source["attack"]))
					"impulse1": battle.impulse = mini(int(battle.rules["impulse_max"]), battle.impulse + kos.size())
			"summon": _summon(battle, source, str(a[1]), int(a[2]))
			"enemy_infighting":
				for victim in targets:
					for other in targets:
						if victim["id"] != other["id"] and int(victim["hp"]) > 0 and int(other["hp"]) > 0:
							battle._take_damage(victim, other, int(victim["attack"])); break
			"revive_self":
				if source["hp"] <= 0: source["hp"] = maxi(1, roundi(float(source["max_hp"]) * float(a[1])))
			"mind_attack":
				for victim in targets:
					var foes: Array = battle.living("ENEMY") if victim["side"] == "ENEMY" else battle.living("ALLY")
					for other in foes:
						if other["id"] != victim["id"]:
							battle._take_damage(victim, other, maxi(1, int(victim["attack"]))); break
			"detonate":
				for victim in targets:
					if battle._take_damage(source, victim, int(source["attack"]) * int(a[1]), false, false, true, true): kos.append(int(victim["id"]))
			"splash":
				for foe in battle.living("ENEMY"):
					if not targets.has(foe) and foe["row"] == target["row"]: battle._take_damage(source, foe, roundi(float(source["attack"]) * float(a[1])))
			"restore_items":
				for item in battle.items.keys(): battle.items[item] = int(battle.items[item]) + 1
			"hazard": battle.environmental_used["pack_hazard_" + str(a[1])] = 0
			"grow", "grow_chain": _stack(source, str(a[1]), 1)
			"spend_all_block": source["block"] = 0
			"spend_block": source["block"] = roundi(float(source["block"]) * (1.0 - float(a[1])))
			"consume_all": battle.impulse = 0
			"activate_next_turn":
				for held in battle.hand: _activate_next(battle, held)
			"ko_recast":
				if not kos.is_empty():
					for i in range(int(a[1])):
						var foes: Array[Dictionary] = battle.living("ENEMY")
						if foes.is_empty(): break
						var victim: Dictionary = foes[battle.rng.randi_range(0, foes.size() - 1)]
						if battle._take_damage(source, victim, int(source["attack"]), false, true, false, false, false, true, true): kos.append(int(victim["id"]))
			"ko_chain":
				if not kos.is_empty():
					for foe in battle.living("ENEMY"):
						if foe["id"] != target["id"]:
							battle._take_damage(source, foe, int(source["attack"])); break
			"quick", "free", "exhaust", "final", "chain", "chain_hand_owner", "random_chain", "full_combo", "bonus_status", "bonus_damaged", "bonus_block", "bonus_targeting_self", "bonus_full_hp", "bonus_en_fuego", "force_if_damaged", "hand_block", "hand_cost_down", "hand_damage_growth", "hand_resist", "overheal_max", "cost_down_en_fuego", "area_en_fuego", "requires_status", "enhanced", "redraw_force", "redraw_bonus", "redraw_strengthened", "play_while_disabled": pass # Evaluated in preplay, hooks, or _bonus.
			_:
				push_error("Unsupported external card action: " + op)
	if (def.get("quick", false) or card.get("next_quick_active", false) or battle._has_status(source, "assimilation")) and kos.has(target_id) or kos.any(func(id): return battle._has_status(battle.actor_by_id(id), "marked")):
		battle.card_plays += 1
	if battle._has_status(source, "assimilation") and not kos.is_empty(): _draw_filtered(battle, source, "draw_attack_heroic", 1)
	if battle._has_status(source, "ravenous") and _is_damage_card(def):
		if _counter(source, "preserve_ravenous") > 0: _consume(source, "preserve_ravenous")
		else: _consume(source, "ravenous")
	if battle._has_status(source, "make_em_bleed") and _is_damage_card(def): _consume(source, "make_em_bleed")
	if _has_action(def, "full_combo") and not chain_ids.is_empty() and chain_ids.all(func(id): return id == chain_ids[0]):
		battle._add_status(source, "strengthened", 1, 1, int(source["id"]))
	if def.get("final", false): battle._add_status(source, "finalized", 1, 1, int(source["id"]))
	if def.get("exhaust", false) or card.get("temporary", false): battle.exhausted.append(card)
	elif _counter(source, "retain_next") > 0: _consume(source, "retain_next"); battle.hand.append(card)
	else: battle.discard.append(card)
	battle.played_cards += 1
	battle._after_card_play()
	battle._check_end()
	battle.changed.emit()
	return true

func on_turn_start(battle: Variant) -> void:
	for actor in battle.actors:
		if actor.has("summon_until") and int(actor["summon_until"]) < int(battle.turn): actor["hp"] = 0
	for card in battle.hand:
		if catalog.definition(str(card.get("id", ""))).is_empty(): continue
		if card.has("cost_override_until") and int(card["cost_override_until"]) < int(battle.turn):
			card.erase("cost_override")
			card.erase("cost_override_until")
		if int(card.get("draw_turn", -1)) < int(battle.turn): _activate_next(battle, card)
		var def: Dictionary = catalog.definition(card["id"])
		if _has_action(def, "hand_cost_down"): card["cost_override"] = maxi(0, int(card.get("cost_override", def.get("cost", 0))) - 1)
		if _has_action(def, "hand_block"):
			var actor: Dictionary = battle.actor_by_id(int(card["owner"]))
			actor["block"] += roundi(float(actor["max_hp"]) * 0.1)
		if _has_action(def, "hand_resist"):
			var holder: Dictionary = battle.actor_by_id(int(card["owner"]))
			battle._add_status(holder, "resist", 1, 1, int(holder["id"]))

func on_draw(battle: Variant, card: Dictionary) -> void:
	# Required after a card enters the hand, so Roulette is fixed on draw.
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return
	card.erase("next_active")
	card["draw_turn"] = int(battle.turn)
	for a in def["actions"]:
		if a[0] == "roulette_status": card["roulette_status"] = str(a[battle.rng.randi_range(1, a.size() - 1)])
		if a[0] == "roulette_hit": card["roulette_factor"] = float(a[battle.rng.randi_range(1, a.size() - 1)])

func on_damage(battle: Variant, victim_id: int, actual_hp_loss: int) -> void:
	# Call after damage resolves. No effect if the hit only removed Block.
	if actual_hp_loss <= 0: return
	var actor: Dictionary = battle.actor_by_id(victim_id)
	if actor.is_empty(): return
	if battle._has_status(actor, "block_on_hit"):
		actor["block"] += actual_hp_loss
	for card in battle.hand:
		if int(card.get("owner", -1)) != victim_id: continue
		var def: Dictionary = catalog.definition(str(card.get("id", "")))
		if _has_action(def, "hand_damage_growth"):
			card["bonus_attack"] = float(card.get("bonus_attack", 0)) + 0.5

func on_redraw(battle: Variant, card: Dictionary) -> void:
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return
	var actor: Dictionary = battle.actor_by_id(int(card["owner"]))
	if _has_action(def, "redraw_force"): card["forceful"] = true
	if _has_action(def, "redraw_bonus"): card["bonus_attack"] = float(card.get("bonus_attack", 0.0)) + 0.5
	if _has_action(def, "redraw_strengthened"): battle._add_status(actor, "strengthened", 1, 1, int(actor["id"]))

func _activate_next(battle: Variant, card: Dictionary) -> void:
	if card.get("next_active", false): return
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return
	for a in def["actions"]:
		match a[0]:
			"next_chain": card["next_chain"] = int(a[1])
			"next_damage": card["bonus_attack"] = float(card.get("bonus_attack", 0)) + float(a[1])
			"next_cost": card["cost_override"] = int(card.get("cost_override", def.get("cost", 0))) + int(a[1])
			"next_quick": card["next_quick_active"] = true
			"next_area": card["next_area_active"] = true
	card["next_active"] = true

func _bonus(battle: Variant, source: Dictionary, victim: Dictionary, def: Dictionary, card: Dictionary) -> float:
	var bonus: float = float(card.get("bonus_attack", 0.0)) + float(card.get("upgrade", 0)) * 0.25
	for a in def["actions"]:
		match a[0]:
			"bonus_status":
				if battle._has_status(victim, str(a[1])): bonus += float(a[2])
			"bonus_damaged":
				if int(victim.get("hp", 0)) < int(victim.get("max_hp", 0)): bonus += float(a[1])
			"bonus_block":
				if int(victim.get("block", 0)) > 0: bonus += float(a[1])
			"bonus_targeting_self":
				if int(victim.get("intent_target", -1)) == int(source["id"]): bonus += float(a[1])
			"bonus_full_hp":
				if int(victim["hp"]) == int(victim["max_hp"]): bonus += float(a[1])
			"bonus_en_fuego": bonus += _counter(source, "en_fuego") * float(a[1])
			"enhanced":
				if battle.impulse >= int(a[1]): bonus += float(a[2])
			"grow": bonus += mini(int(_counter(source, str(a[1]))), roundi(float(a[3]) / float(a[2]))) * float(a[2])
	return bonus

func _has_action(def: Dictionary, name: String) -> bool:
	for a in def.get("actions", []):
		if a[0] == name: return true
	return false

func _action(def: Dictionary, name: String) -> Array:
	for a in def.get("actions", []):
		if a[0] == name: return a
	return []


func _is_damage_card(def: Dictionary) -> bool:
	for a in def.get("actions", []):
		if typeof(a) == TYPE_ARRAY and not a.is_empty() and str(a[0]) in ["hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "roulette_hit"]:
			return true
	for e in def.get("effects", []):
		if str(e.get("kind", "")) == "DAMAGE":
			return true
	return false

func _is_damage_card_id(card_id: String) -> bool:
	if card_id == "":
		return false
	if Content.CARDS.has(card_id):
		return _is_damage_card(Content.CARDS[card_id])
	return _is_damage_card(catalog.definition(card_id))

func _card_costs_initiative(item: Dictionary) -> bool:
	if int(item.get("cost_override", 0)) > 0 or int(item.get("cost", 0)) > 0:
		return true
	var cid := str(item.get("id", ""))
	if cid != "" and Content.CARDS.has(cid):
		return int(Content.CARDS[cid].get("cost", 0)) > 0
	var def: Dictionary = catalog.definition(cid)
	return int(def.get("cost", 0)) > 0


func _archetype_mult(source: Dictionary, victim: Dictionary) -> float:
	var atk := str(source.get("archetype_stat", ""))
	var dfn := str(victim.get("archetype_stat", ""))
	if atk in ["", "Nenhum", "Versátil", "Preparo"] or dfn in ["", "Nenhum", "Versátil", "Preparo"]:
		return 1.0
	if Content.ARCHETYPE_BEATS.get(atk, "") == dfn:
		return 1.25
	if Content.ARCHETYPE_BEATS.get(dfn, "") == atk:
		return 0.75
	return 1.0

func _offense(actor: Dictionary, def: Dictionary) -> int:
	var stat := str(def.get("stat", "attack"))
	if stat == "power":
		return int(actor.get("power", actor.get("attack", 1)))
	if def.get("owner", "") in ["doctor_strange", "magik", "nico", "scarlet_witch", "storm"]:
		return int(actor.get("power", actor.get("attack", 1)))
	return int(actor.get("attack", 1))

func _counter(actor: Dictionary, name: String) -> int:
	return int(actor.get("statuses", {}).get(name, {}).get("stacks", 0))

func _stack(actor: Dictionary, name: String, count: int) -> void:
	var prior: Dictionary = actor["statuses"].get(name, {"stacks": 0, "duration": 99, "source": actor["id"]})
	prior["stacks"] = int(prior.get("stacks", 0)) + count
	actor["statuses"][name] = prior

func _consume(actor: Dictionary, name: String) -> void:
	var stack := _counter(actor, name)
	if stack <= 1: actor["statuses"].erase(name)
	else: actor["statuses"][name]["stacks"] = stack - 1

func _draw_filtered(battle: Variant, source: Dictionary, mode: String, amount: int) -> void:
	if mode == "draw_owner_to": amount = maxi(0, amount - battle.hand.filter(func(c): return c.get("owner") == source["id"]).size())
	for i in range(amount):
		if mode == "draw": battle._draw(1); continue
		var found := -1
		for index in range(battle.deck.size() - 1, -1, -1):
			var item: Dictionary = battle.deck[index]
			if mode in ["draw_owner", "draw_owner_to"] and item.get("owner") == source["id"] or mode == "draw_heroic" and _card_costs_initiative(item) or mode == "draw_attack_heroic" and (_is_damage_card_id(str(item.get("id", ""))) or _card_costs_initiative(item)):
				found = index; break
		if found < 0 or battle.hand.size() >= int(battle.rules["hand_max"]): break
		battle.hand.append(battle.deck.pop_at(found))

func _summon(battle: Variant, source: Dictionary, type: String, duration: int) -> void:
	# HotN3 has no allied summon action; create a combat ally with an independent ID.
	var template: Dictionary = source.duplicate(true)
	template["name"] = "Aliado convocado"
	template["hp"] = maxi(1, roundi(float(source["max_hp"]) * 0.5))
	template["statuses"] = {}
	var ally: Dictionary = battle._create_actor(template, "ALLY", type)
	ally["summon_until"] = int(battle.turn) + duration
