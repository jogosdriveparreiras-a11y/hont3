extends RefCounted
class_name HotNBattle

signal changed
signal event(message: String)
signal visual(kind: String, source_id: int, target_id: int, value: int)
signal finished(victory: bool)

const Content = preload("res://game/Content.gd")
const PackBridge = preload("res://game/PackBridge.gd")
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
## Callback opcional: Callable(category, action, detail_dict) → SessionReport.
var report_cb: Callable
var moves := 0
var item_uses := 0
var impulse := 0
var turn := 0
var phase := "PREPARING"
var protect_hp := 0
var items: Dictionary = {"potion": 1, "bomb": 1, "antidote": 1}
var environmental_used: Dictionary = {}
var combo_used := false
var combo_zero_owners: Dictionary = {}  # actor_id -> true (Manobras custam 0 INI neste round)
var team_ko_charges := 0
var improvements: Dictionary = {}
var next_actor_id := 0
var next_card_id := 0
var played_cards := 0
var enemy_deck: Array[Dictionary] = []
var enemy_hand: Array[Dictionary] = []
var enemy_discard: Array[Dictionary] = []
var enemy_exhausted: Array[Dictionary] = []
var enemy_card_plays := 0
var enemy_redraws := 0
var enemy_moves := 0
var enemy_impulse := 0
var enemy_combo_used := false
var request_end_turn := false
var pending_recover: Dictionary = {}  # {count, owner_id} owner_id -1 = qualquer
const NEGATIVE := ["weak", "vulnerable", "marked", "stun", "bind", "bound", "fragil", "poison", "bleed", "burn", "silence", "blind", "slow", "wounded", "corrupted", "confused", "banished", "webbed_up", "taunted", "berserk_enemy", "feeding_frenzy", "drop", "overload", "spike_bomb"]
## Posturas: status exclusivo (só 1) + classe de carta POSTURA. INI gain capped 1×/postura/rodada.
const POSTURES := {
	"tanque": {"gain": 1, "label": "Tanque"},
	"furioso": {"gain": 1, "label": "Furioso"},
	"curador": {"gain": 2, "label": "Curador"},
	"empatico": {"gain": 2, "label": "Empático"},
	"atirador": {"gain": 2, "label": "Atirador"},
	"drenador": {"gain": 2, "label": "Drenador"},
	"controlador": {"gain": 2, "label": "Controlador"},
	"garra": {"gain": 3, "label": "Garra"},
	"vingador": {"gain": 2, "label": "Vingador"},
	"executor": {"gain": 2, "label": "Executor"},
	"indomavel": {"gain": 2, "label": "Indomável"},
	"sobrevivente": {"gain": 3, "label": "Sobrevivente"},
	"intocavel": {"gain": 2, "label": "Intocável"},
	"preparo": {"gain": 3, "label": "Preparo"},
}


func _rpt(category: String, action: String, detail: Dictionary = {}) -> void:
	if report_cb.is_valid():
		report_cb.call(category, action, detail)

func _card_brief(card: Dictionary) -> Dictionary:
	return {
		"uid": int(card.get("uid", -1)),
		"id": str(card.get("id", "")),
		"owner": int(card.get("owner", -1)),
		"class": str(card.get("class", "")),
		"instant": bool(card.get("instant", false)),
	}

func _hand_briefs(side: String) -> Array:
	var rows: Array = []
	for c in _hand_of(side):
		rows.append(_card_brief(c))
	return rows

func _acting() -> String:
	return "ENEMY" if phase == "ENEMY" else "ALLY"

func _hand_of(side: String) -> Array[Dictionary]:
	return enemy_hand if side == "ENEMY" else hand

func _deck_of(side: String) -> Array[Dictionary]:
	return enemy_deck if side == "ENEMY" else deck

func _discard_of(side: String) -> Array[Dictionary]:
	return enemy_discard if side == "ENEMY" else discard

func _exhausted_of(side: String) -> Array[Dictionary]:
	return enemy_exhausted if side == "ENEMY" else exhausted

func _get_impulse(side: String) -> int:
	return enemy_impulse if side == "ENEMY" else impulse

func _set_impulse(side: String, value: int) -> void:
	if side == "ENEMY": enemy_impulse = value
	else: impulse = value

func _get_plays(side: String) -> int:
	return enemy_card_plays if side == "ENEMY" else card_plays

func _set_plays(side: String, value: int) -> void:
	if side == "ENEMY": enemy_card_plays = value
	else: card_plays = value

func _add_plays(side: String, amount: int) -> void:
	_set_plays(side, _get_plays(side) + amount)

func begin(mission_id: String, team: Array[String], equipped: Dictionary, seed_value: int = 0, card_improvements: Dictionary = {}, selected_items: Dictionary = {}) -> void:
	if not PackBridge.packs_merged:
		PackBridge.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	mission = Content.MISSIONS[mission_id].duplicate(true)
	actors.clear()
	deck.clear()
	hand.clear()
	discard.clear()
	exhausted.clear()
	enemy_deck.clear()
	enemy_hand.clear()
	enemy_discard.clear()
	enemy_exhausted.clear()
	next_actor_id = 0
	next_card_id = 0
	played_cards = 0
	turn = 0
	impulse = 0
	enemy_impulse = 0
	enemy_card_plays = 0
	enemy_redraws = 0
	enemy_moves = 0
	enemy_combo_used = false
	phase = "PREPARING"
	protect_hp = int(mission.get("protect_hp", 0))
	environmental_used.clear()
	combo_used = false
	combo_zero_owners.clear()
	request_end_turn = false
	pending_recover = {}
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
	var item_owner := 0
	var allies_now: Array[Dictionary] = living("ALLY")
	if not allies_now.is_empty():
		item_owner = int(allies_now[0]["id"])
	for item_key in ["potion", "bomb", "antidote"]:
		var copies := int(items.get(item_key, 0))
		for _copy in copies:
			var item_card := "item_" + str(item_key)
			if not Content.CARDS.has(item_card):
				continue
			var idef: Dictionary = Content.CARDS[item_card]
			# Não traz item se owner_hero definido e ausente da equipe.
			if idef.has("owner_hero"):
				var need := str(idef["owner_hero"])
				var in_team := false
				for tid in team:
					if str(tid) == need:
						in_team = true
						break
				if not in_team:
					_log("Item %s omitido: dono %s fora da equipe." % [item_card, need])
					continue
			deck.append(_create_card(item_card, item_owner))
	for id in mission.get("enemies", []):
		spawn_enemy(str(id))
	_shuffle(deck)
	_shuffle(enemy_deck)
	_draw_side("ALLY", int(rules["opening_hand"]))
	_draw_side("ENEMY", int(rules["opening_hand"]))
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
	actor["shield"] = 0  # escudo temporário de carta (camada); atributo permanente é escudo/escudo
	if not actor.has("escudo"):
		actor["escudo"] = int(actor.get("armor", 0))
	if not actor.has("archetype_stat"):
		actor["archetype_stat"] = str(actor.get("combat_archetype", "Nenhum"))
	if not actor.has("species"):
		actor["species"] = "Humano"
	if not actor.has("sprite_scale"):
		actor["sprite_scale"] = float(actor.get("scale_factor", 1.0))
	actor["statuses"] = {}
	actor["pending"] = []
	actor["phase"] = 1  # só para chefes (fase 2), NÃO turno individual
	actors.append(actor)
	return actor

func _create_card(card_id: String, owner_id: int, changes: Dictionary = {}) -> Dictionary:
	next_card_id += 1
	return {"uid": next_card_id, "id": card_id, "owner": owner_id, "class": Content.CARDS.get(card_id, {}).get("class", ""), "upgrade": int(changes.get("upgrade", 0)), "mod": changes.get("mod", "")}

func purge_owner_cards(owner_id: int) -> void:
	# Remove cartas deste dono de mão/baralho/descarte (ambos os lados).
	var removed := 0
	var ids: Array = []
	for pile in [hand, deck, discard, enemy_hand, enemy_deck, enemy_discard]:
		for i in range(pile.size() - 1, -1, -1):
			var card: Dictionary = pile[i]
			if int(card.get("owner", -1)) == owner_id:
				ids.append(str(card.get("id", "")))
				pile.remove_at(i)
				removed += 1
	_rpt("battle", "purge_owner_cards", {"owner_id": owner_id, "removed": removed, "ids": ids})

func purge_summons_of(summoner_id: int) -> void:
	# Lacaios convocados pelo conjurador morrem e perdem cartas de mão/pilhas.
	for actor in actors:
		if not bool(actor.get("is_summon", false)):
			continue
		if int(actor.get("summoner_id", -1)) != summoner_id:
			continue
		if int(actor.get("hp", 0)) <= 0:
			purge_owner_cards(int(actor["id"]))
			continue
		actor["hp"] = 0
		purge_owner_cards(int(actor["id"]))
		_log("%s dissipou-se com o conjurador." % actor.get("name", "?"))
		visual.emit("death", summoner_id, int(actor["id"]), 0)

func spawn_enemy(enemy_id: String) -> void:
	if not Content.HEROES.has(enemy_id):
		return
	var template: Dictionary = Content.HEROES[enemy_id]
	# minion = true é a exceção que permite duas ou mais instâncias do mesmo personagem no mesmo lado.
	if not template.get("minion", false):
		for actor in actors:
			if actor["side"] == "ENEMY" and str(actor.get("archetype", "")) == enemy_id and int(actor.get("hp", 0)) > 0:
				return
	var enemy := _create_actor(template, "ENEMY", enemy_id)
	for card_id in template.get("cards", []):
		if Content.CARDS.has(str(card_id)):
			enemy_deck.append(_create_card(str(card_id), int(enemy["id"])))
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


func apply_combo_zero_cost(member_actor_ids: Array) -> void:
	# Combo jogado: Manobras desses atores custam 0 Iniciativa neste round.
	for aid in member_actor_ids:
		combo_zero_owners[int(aid)] = true
	_log("Combo: Manobras dos membros custam 0 Iniciativa neste round.")

func manobra_initiative_cost(source: Dictionary, base_cost: int) -> int:
	var cost := base_cost
	if combo_zero_owners.get(int(source.get("id", -1)), false):
		return 0
	if _has_status(source, "fast"):
		cost -= 1
	if _has_status(source, "slow"):
		cost += 1
	return maxi(0, cost)

func _apply_reshuffle_fatigue() -> void:
	# Quando o descarte volta ao baralho, toda a equipe aliada recebe Lento 1.
	for ally in living("ALLY"):
		_add_status(ally, "slow", 1, 1, int(ally["id"]))
	_log("Fadiga: equipe aliada recebe Lento 1 (reshuffle).")
	changed.emit()

func _shuffle(pile: Array[Dictionary]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := pile[i]
		pile[i] = pile[j]
		pile[j] = temp

func _draw(amount: int) -> void:
	_draw_side(_acting(), amount)

func _summon_leaves_cycle(owner: Dictionary) -> bool:
	# Só lacaio/invocação sai do ciclo (morte do lacaio ou do conjurador).
	# Herói morto permanece em mão, baralho e descarte.
	if owner.is_empty():
		return false
	return bool(owner.get("is_summon", false)) or bool(owner.get("minion", false))

func units_on_field(side: String) -> Array[Dictionary]:
	# Vivos e caídos (sprite permanece). Banido sai de cena.
	var found: Array[Dictionary] = []
	for actor in actors:
		if str(actor.get("side", "")) != side:
			continue
		if _has_status(actor, "banished"):
			continue
		found.append(actor)
	return found

func dead_on_side(side: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for actor in actors:
		if str(actor.get("side", "")) != side:
			continue
		if int(actor.get("hp", 0)) > 0:
			continue
		if _has_status(actor, "banished"):
			continue
		# Lacaio dissipado não entra em Reanimar (cartas já saíram do ciclo).
		if _summon_leaves_cycle(actor):
			continue
		found.append(actor)
	return found

func _reanimar_host(side: String) -> Dictionary:
	var alive := living(side)
	if alive.is_empty():
		return {}
	return alive[0]

func _sync_reanimar(side: String) -> void:
	# Uma cópia de Reanimar enquanto houver aliado caído neste lado.
	# Some de mão, baralho, descarte e exhausted quando ninguém está morto.
	var exhausted_pile := _exhausted_of(side)
	for index in range(exhausted_pile.size() - 1, -1, -1):
		if str(exhausted_pile[index].get("id", "")) == "reanimar":
			exhausted_pile.remove_at(index)
	var piles: Array = [_hand_of(side), _deck_of(side), _discard_of(side)]
	var dead := dead_on_side(side)
	var kept := false
	var removed := 0
	for pile in piles:
		for index in range(pile.size() - 1, -1, -1):
			var card: Dictionary = pile[index]
			if str(card.get("id", "")) != "reanimar":
				continue
			if dead.is_empty() or kept:
				pile.remove_at(index)
				removed += 1
				continue
			kept = true
			var owner := actor_by_id(int(card.get("owner", -1)))
			if owner.is_empty() or int(owner.get("hp", 0)) <= 0 or str(owner.get("side", "")) != side:
				var host := _reanimar_host(side)
				if not host.is_empty():
					card["owner"] = int(host["id"])
					pile[index] = card
	if dead.is_empty():
		if removed > 0:
			_rpt("card", "reanimar_remove", {"side": side, "removed": removed})
		return
	if kept:
		return
	var host := _reanimar_host(side)
	if host.is_empty():
		return
	var fresh := _create_card("reanimar", int(host["id"]))
	var pile_deck := _deck_of(side)
	var at := 0
	if not pile_deck.is_empty():
		at = rng.randi_range(0, pile_deck.size())
	pile_deck.insert(at, fresh)
	_log("Reanimar entrou no baralho.")
	_rpt("card", "reanimar_insert", {"side": side, "owner": int(host["id"]), "deck": pile_deck.size()})

func _draw_side(side: String, amount: int) -> void:
	var pile_hand := _hand_of(side)
	var pile_deck := _deck_of(side)
	var pile_discard := _discard_of(side)
	var drawn := 0
	var skipped_summon := 0
	var guard := 0
	# Compra `amount` cartas. Herói morto CONSOME a cota (carta fica na mão, injogável).
	# Só carta de lacaio/invocação morta é descartada do ciclo sem contar.
	while drawn < amount and guard < 64:
		guard += 1
		if pile_hand.size() >= int(rules["hand_max"]):
			break
		if pile_deck.is_empty():
			if pile_discard.is_empty():
				break
			for used_card in pile_discard:
				pile_deck.append(used_card)
			pile_discard.clear()
			_shuffle(pile_deck)
			# Fadiga: reshuffle do time aliado aplica Lento 1 em todos os aliados vivos.
			if side == "ALLY":
				_apply_reshuffle_fatigue()
			_rpt("battle", "reshuffle", {"side": side, "deck": pile_deck.size()})
		if pile_deck.is_empty():
			break
		var card: Dictionary = pile_deck.pop_back()
		var owner := actor_by_id(int(card.get("owner", -1)))
		if _summon_leaves_cycle(owner) and int(owner.get("hp", 0)) <= 0:
			skipped_summon += 1
			_rpt("card", "draw_skip_dead_summon", {
				"side": side, "card": _card_brief(card),
				"owner": int(card.get("owner", -1)),
			})
			continue
		if Content.CARDS.get(card["id"], {}).has("roulette"):
			var choices: Array = Content.CARDS[card["id"]]["roulette"]
			if not choices.is_empty(): card["roulette_effect"] = choices[rng.randi_range(0, choices.size() - 1)]
		card.erase("infected")
		card["drawn_turn"] = int(turn)
		var cdef: Dictionary = Content.CARDS.get(str(card.get("id", "")), {})
		if bool(cdef.get("ephemeral", false)): card["ephemeral"] = true
		if bool(cdef.get("instant", false)): card["instant"] = true
		# Desvantagem SEMPRE Instantâneo (regra de kit).
		if str(cdef.get("class", card.get("class", ""))) == "DESVANTAGEM":
			card["instant"] = true
		if int(cdef.get("warmup", 0)) > 0: card["warmup"] = int(cdef["warmup"])
		pile_hand.append(card)
		drawn += 1
		var owner_id := int(card.get("owner", -1))
		if not owner.is_empty():
			owner_id = int(owner["id"])
		visual.emit("draw", owner_id, owner_id, 1)
		_rpt("card", "draw", {
			"side": side, "card": _card_brief(card),
			"owner_name": str(owner.get("name", "")),
			"owner_dead": int(owner.get("hp", 0)) <= 0 and not owner.is_empty(),
			"hand_size": pile_hand.size(),
			"deck_left": pile_deck.size(),
		})
	if skipped_summon > 0 or drawn > 0:
		_rpt("battle", "draw_batch", {
			"side": side, "requested": amount, "drawn": drawn,
			"skipped_summon": skipped_summon, "hand": pile_hand.size(),
			"deck": pile_deck.size(), "discard": pile_discard.size(),
		})

func start_turn() -> void:
	if phase == "FINISHED":
		return
	_purge_ephemeral_hand("ENEMY")
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
	combo_zero_owners.clear()
	card_plays = int(rules["card_plays"])
	redraws = int(rules["redraws"])
	_rpt("battle", "phase", {
		"phase": "PLAYER", "turn": turn,
		"impulse": impulse, "plays": card_plays, "redraws": redraws,
		"hand": _hand_briefs("ALLY"),
		"deck": deck.size(), "discard": discard.size(), "exhausted": exhausted.size(),
	})
	moves = int(rules["moves"])
	item_uses = int(rules["item_uses"])
	for ally in living("ALLY"):
		if _has_status(ally, "next_turn_plays"):
			var bonus_plays: int = maxi(1, _status_stacks(ally, "next_turn_plays"))
			card_plays += bonus_plays
			_ensure_statuses(ally).erase("next_turn_plays")
		if _has_status(ally, "neurally_enhanced"):
			var neu_bonus: int = maxi(1, _status_stacks(ally, "neurally_enhanced"))
			card_plays += neu_bonus
			_ensure_statuses(ally).erase("neurally_enhanced")
		match ally.get("passive", ""):
			"vanguarda":
				if ally["row"] == "front": _add_status(ally, "barrier", 1, 2, int(ally["id"]))
			"canalizar": impulse = min(int(rules["impulse_max"]), impulse + 1)
			"baluarte": _add_status(ally, "barrier", 1, 2, int(ally["id"]))
	if turn > 1:
		var has_strongest: bool = living("ALLY").any(func(a): return _has_status(a, "strongest_there_is"))
		var extra: int = 1 if has_strongest else 0
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

func card_warmup_ready(card: Dictionary, definition: Dictionary = {}) -> bool:
	var warmup: int = int(card.get("warmup", definition.get("warmup", 0)))
	if warmup <= 0:
		for action in definition.get("actions", []):
			if typeof(action) == TYPE_ARRAY and action.size() > 1 and str(action[0]) == "warmup":
				warmup = int(action[1])
				break
	if warmup <= 0:
		return true
	var drawn: int = int(card.get("drawn_turn", card.get("draw_turn", turn)))
	return int(turn) >= drawn + warmup

func is_instant_card(card: Dictionary, definition: Dictionary = {}) -> bool:
	if bool(card.get("instant", false)) or bool(definition.get("instant", false)):
		return true
	# Regra: toda DESVANTAGEM é Instantâneo (a menos que o designer diga o contrário).
	if str(definition.get("class", card.get("class", ""))) == "DESVANTAGEM":
		return true
	for action in definition.get("actions", []):
		if typeof(action) == TYPE_ARRAY and not action.is_empty() and str(action[0]) == "instant":
			return true
	return false

func is_ephemeral_card(card: Dictionary, definition: Dictionary = {}) -> bool:
	if bool(card.get("ephemeral", false)) or bool(definition.get("ephemeral", false)):
		return true
	for action in definition.get("actions", []):
		if typeof(action) == TYPE_ARRAY and not action.is_empty() and str(action[0]) == "ephemeral":
			return true
	return false


func hand_has_instantaneo(side: String = "") -> bool:
	var acting := side if side != "" else _acting()
	var acting_hand := _hand_of(acting)
	for held in acting_hand:
		var definition: Dictionary = Content.CARDS.get(str(held.get("id", "")), {})
		if is_instant_card(held, definition):
			return true
	return false

## Instantâneo *jogável* na mão (requisitos, INI, jogadas, dono vivo).
func hand_has_playable_instantaneo(side: String = "") -> bool:
	return not playable_instantaneo_indices(side).is_empty()

func playable_instantaneo_indices(side: String = "") -> Array:
	var acting := side if side != "" else _acting()
	var acting_hand := _hand_of(acting)
	var out: Array = []
	for i in range(acting_hand.size()):
		var held: Dictionary = acting_hand[i]
		var definition: Dictionary = Content.CARDS.get(str(held.get("id", "")), {})
		if not is_instant_card(held, definition):
			continue
		if _instant_card_playable(held, definition, acting):
			out.append(i)
	return out

func _instant_card_playable(card: Dictionary, definition: Dictionary, side: String) -> bool:
	var source := actor_by_id(int(card.get("owner", -1)))
	if source.is_empty() or int(source.get("hp", 0)) <= 0:
		return false
	if str(source.get("side", "")) != side:
		return false
	for locked in ["stun", "bind", "bound", "banished", "finalized"]:
		if _has_status(source, locked) and not bool(definition.get("play_while_disabled", false)):
			return false
	if not card_warmup_ready(card, definition):
		return false
	var cost := _cost(source, definition)
	var plays: int = 0 if bool(definition.get("free", false)) or card_has_flag(definition, "free") else int(definition.get("plays", 1))
	# quick também não gasta jogada
	if bool(definition.get("quick", false)) or card_has_flag(definition, "quick"):
		plays = 0
	if _get_impulse(side) < cost or _get_plays(side) < plays:
		return false
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		if op == "requires_self_status":
			var need_st := str(action[1] if action.size() > 1 else "")
			var need_n: int = int(round(resolve_amount(action[2] if action.size() > 2 else 1, source)))
			if _status_stacks(source, need_st) < need_n:
				return false
		elif op == "requires_alone":
			if living(side).size() > 1:
				return false
		elif op == "requires_own_minion_front":
			var has_minion := false
			for ally in living(side):
				if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]) and str(ally.get("row", "")) == "front":
					has_minion = true
					break
			if not has_minion:
				return false
	# Precisa existir pelo menos um alvo legal
	var kind := str(definition.get("target", "SELF"))
	match kind:
		"SELF", "ALL_ALLIES", "ALL_OTHERS":
			return true
		"OWN_MINION":
			for ally in living(side):
				if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]):
					return true
			return false
		_:
			return true

func can_end_turn() -> bool:
	# Só Instantâneo *jogável* impede Encerrar / passar.
	if phase != "PLAYER":
		return false
	return not hand_has_playable_instantaneo("ALLY")

## Bloqueia jogar outra carta enquanto houver Instantâneo jogável.
func must_play_instantaneo_first(card: Dictionary, definition: Dictionary = {}, side: String = "") -> bool:
	var acting := side if side != "" else _acting()
	if not hand_has_playable_instantaneo(acting):
		return false
	var def2: Dictionary = definition if not definition.is_empty() else Content.CARDS.get(str(card.get("id", "")), {})
	return not is_instant_card(card, def2)

func _ensure_statuses(actor: Dictionary) -> Dictionary:
	## Guarantees actor["statuses"] is a Dictionary (GDScript 4 [] throws on missing keys).
	if not actor.has("statuses") or typeof(actor["statuses"]) != TYPE_DICTIONARY:
		actor["statuses"] = {}
	return actor["statuses"]

func _status_state(actor: Dictionary, id: String) -> Dictionary:
	## Normalized, safe status entry. Empty dict if missing / wrong type.
	id = _normalize_status_id(id)
	var statuses: Variant = actor.get("statuses", {})
	if typeof(statuses) != TYPE_DICTIONARY:
		return {}
	var state: Variant = statuses.get(id, {})
	if typeof(state) != TYPE_DICTIONARY:
		return {}
	return state

func _normalize_status_id(id: String) -> String:
	var key := id.strip_edges().to_lower()
	match key:
		"dazed":
			return "stun"
		"protected", "protecting":
			return "protecao"
		"resist", "protection", "protecao":
			return "protecao"
		"barrier", "barreira":
			return "barrier"
		"invulneravel", "invulnerable":
			return "invulnerable"
		"resistente", "resistant", "harden":
			return "resistente"
		"fragil", "fragile", "frailty":
			return "fragil"
		"atento", "attentive":
			return "atento"
		"escuridao", "escuro", "darkness":
			return "escuridao"
		"wounded", "wound", "ferido":
			return "wounded"
		"slow", "lento":
			return "slow"
		"vitima", "victim", "tanque":
			return "tanque"
		"furioso", "furious":
			return "furioso"
		"curador", "healer":
			return "curador"
		"empatico", "empathetic", "empatia":
			return "empatico"
		"atirador", "marksman":
			return "atirador"
		"drenador", "drainer":
			return "drenador"
		"controlador", "controller":
			return "controlador"
		"garra", "claw":
			return "garra"
		"vingador", "avenger":
			return "vingador"
		"executor", "executioner":
			return "executor"
		"indomavel", "indomitable":
			return "indomavel"
		"sobrevivente", "survivor":
			return "sobrevivente"
		"intocavel", "untouchable":
			return "intocavel"
		"preparo_postura":
			return "preparo"
		_:
			return key

func _status_stacks(actor: Dictionary, id: String) -> int:
	if not _has_status(actor, id):
		return 0
	return int(_status_state(actor, id).get("stacks", 0))

## Shared formula map: status stacks + aliases (E / escuridao). Static ints still work via resolve_amount.
func formula_vars(actor: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in actor.get("statuses", {}).keys():
		var n: int = int(actor["statuses"][id].get("stacks", 0))
		out[str(id)] = n
		out[str(id).to_upper()] = n
	var e: int = int(out.get("escuridao", 0))
	out["E"] = e
	out["e"] = e
	return out

## Resolve card amount: number, status token, or simple expr (1+E, 2*E, 2×E).
func resolve_amount(raw: Variant, actor: Dictionary) -> float:
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return float(raw)
	var s := str(raw).strip_edges()
	if s == "":
		return 0.0
	if s.is_valid_float():
		return float(s)
	var expr := s.replace(" ", "").replace("×", "*").replace("x", "*").replace("X", "*")
	var vars := formula_vars(actor)
	# Replace longer keys first to avoid partial overlaps.
	var keys: Array = vars.keys()
	keys.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for k in keys:
		var token := str(k)
		if token.is_empty():
			continue
		expr = expr.replace(token, str(int(vars[k])))
	# Only digits and + - * / . left
	var cleaned := ""
	for ch in expr:
		if ch in "0123456789+-*/.()":
			cleaned += ch
	if cleaned.is_empty():
		return 0.0
	if cleaned.is_valid_float():
		return float(cleaned)
	var engine := Expression.new()
	var err := engine.parse(cleaned)
	if err != OK:
		push_warning("resolve_amount parse fail: %s -> %s" % [str(raw), cleaned])
		return 0.0
	var result: Variant = engine.execute()
	if engine.has_execute_failed():
		return 0.0
	return float(result)

func _barrier_hp(actor: Dictionary) -> int:
	if not _has_status(actor, "barrier"):
		return 0
	var state: Dictionary = _status_state(actor, "barrier")
	return int(state.get("barrier_hp", state.get("stacks", 0)))

func card_has_flag(definition: Dictionary, flag: String) -> bool:
	if bool(definition.get(flag, false)):
		return true
	for action in definition.get("actions", []):
		if typeof(action) == TYPE_ARRAY and not action.is_empty() and str(action[0]) == flag:
			return true
	return false

func _purge_ephemeral_hand(side: String) -> void:
	var acting_hand := _hand_of(side)
	var pile_discard := _discard_of(side)
	for index in range(acting_hand.size() - 1, -1, -1):
		var held: Dictionary = acting_hand[index]
		var definition: Dictionary = Content.CARDS.get(str(held.get("id", "")), {})
		if is_ephemeral_card(held, definition):
			pile_discard.append(acting_hand.pop_at(index))
			_log("%s efêmera foi descartada." % definition.get("name", held.get("id", "?")))

func draw_own(owner_id: int, amount: int) -> int:
	# Compra do baralho do herói; se não houver, embaralha descarte e tenta de novo.
	var side := _acting()
	var pile_hand := _hand_of(side)
	var pile_deck := _deck_of(side)
	var pile_discard := _discard_of(side)
	var drawn := 0
	for _i in range(amount):
		if pile_hand.size() >= int(rules["hand_max"]):
			break
		var found := -1
		for index in range(pile_deck.size() - 1, -1, -1):
			if int(pile_deck[index].get("owner", -1)) == owner_id:
				found = index
				break
		if found < 0:
			if pile_discard.is_empty():
				break
			for used_card in pile_discard:
				pile_deck.append(used_card)
			pile_discard.clear()
			_shuffle(pile_deck)
			for index in range(pile_deck.size() - 1, -1, -1):
				if int(pile_deck[index].get("owner", -1)) == owner_id:
					found = index
					break
		if found < 0:
			break
		var card: Dictionary = pile_deck.pop_at(found)
		var owner := actor_by_id(int(card["owner"]))
		if _summon_leaves_cycle(owner) and int(owner.get("hp", 0)) <= 0:
			continue
		card["drawn_turn"] = int(turn)
		var cdef: Dictionary = Content.CARDS.get(str(card.get("id", "")), {})
		if bool(cdef.get("ephemeral", false)): card["ephemeral"] = true
		if bool(cdef.get("instant", false)): card["instant"] = true
		if int(cdef.get("warmup", 0)) > 0: card["warmup"] = int(cdef["warmup"])
		pile_hand.append(card)
		visual.emit("draw", owner_id, owner_id, 1)
		drawn += 1
	return drawn

func recover_from_discard(owner_filter: int, amount: int, auto: bool = true) -> int:
	# owner_filter < 0 = qualquer; auto = pega as mais recentes do descarte.
	var side := _acting()
	var pile_hand := _hand_of(side)
	var pile_discard := _discard_of(side)
	if not auto:
		pending_recover = {"count": amount, "owner_id": owner_filter, "side": side}
		return 0
	var recovered := 0
	for _i in range(amount):
		if pile_hand.size() >= int(rules["hand_max"]):
			break
		var found := -1
		for index in range(pile_discard.size() - 1, -1, -1):
			if owner_filter < 0 or int(pile_discard[index].get("owner", -1)) == owner_filter:
				found = index
				break
		if found < 0:
			break
		var card: Dictionary = pile_discard.pop_at(found)
		card["drawn_turn"] = int(turn)
		pile_hand.append(card)
		recovered += 1
	return recovered

func finish_recover_pick(discard_index: int) -> bool:
	if pending_recover.is_empty():
		return false
	var side: String = str(pending_recover.get("side", _acting()))
	var pile_hand := _hand_of(side)
	var pile_discard := _discard_of(side)
	if discard_index < 0 or discard_index >= pile_discard.size():
		return false
	if pile_hand.size() >= int(rules["hand_max"]):
		pending_recover = {}
		return false
	var owner_filter: int = int(pending_recover.get("owner_id", -1))
	var card: Dictionary = pile_discard[discard_index]
	if owner_filter >= 0 and int(card.get("owner", -1)) != owner_filter:
		return false
	pile_discard.remove_at(discard_index)
	card["drawn_turn"] = int(turn)
	pile_hand.append(card)
	var left: int = int(pending_recover.get("count", 1)) - 1
	if left <= 0:
		pending_recover = {}
	else:
		pending_recover["count"] = left
	changed.emit()
	return true

func discard_from_hand(amount: int, prefer_random: bool = true) -> int:
	var side := _acting()
	var acting_hand := _hand_of(side)
	var pile_discard := _discard_of(side)
	var dropped := 0
	for _i in range(amount):
		if acting_hand.is_empty():
			break
		var index: int = rng.randi_range(0, acting_hand.size() - 1) if prefer_random else acting_hand.size() - 1
		pile_discard.append(acting_hand.pop_at(index))
		dropped += 1
	return dropped

func grant_next_turn_plays(actor: Dictionary, amount: int) -> void:
	_add_status(actor, "next_turn_plays", 2, maxi(1, amount), int(actor.get("id", 0)))

func is_posture_id(id: String) -> bool:
	return POSTURES.has(_normalize_status_id(id))

func _clear_other_postures(actor: Dictionary, keep: String) -> void:
	var statuses := _ensure_statuses(actor)
	keep = _normalize_status_id(keep)
	for pid in POSTURES.keys():
		if str(pid) != keep and statuses.has(pid):
			statuses.erase(pid)
	# legado
	if keep != "tanque":
		statuses.erase("vitima")

## +INI de postura: no máx. 1 ativação por postura por rodada (turn).
func try_posture_trigger(actor: Dictionary, posture_id: String) -> bool:
	if actor.is_empty() or int(actor.get("hp", 0)) <= 0:
		return false
	posture_id = _normalize_status_id(posture_id)
	if not POSTURES.has(posture_id):
		return false
	if not _has_status(actor, posture_id):
		return false
	var fired: Variant = actor.get("posture_fired", {})
	if typeof(fired) != TYPE_DICTIONARY:
		fired = {}
	if int(fired.get(posture_id, -1)) == int(turn):
		return false
	var gain: int = int(POSTURES[posture_id].get("gain", 1))
	var side := str(actor.get("side", "ALLY"))
	_set_impulse(side, mini(int(rules["impulse_max"]), _get_impulse(side) + gain))
	fired[posture_id] = int(turn)
	actor["posture_fired"] = fired
	var label := str(POSTURES[posture_id].get("label", posture_id))
	_log("%s (%s): +%d Iniciativa." % [actor.get("name", "?"), label, gain])
	visual.emit("ini_gain", int(actor["id"]), int(actor["id"]), gain)
	_rpt("battle", "posture_trigger", {
		"actor_id": int(actor["id"]), "name": str(actor.get("name", "")),
		"posture": posture_id, "label": label, "gain": gain, "impulse": _get_impulse(side),
	})
	return true

func _posture_end_of_side(side: String) -> void:
	var living_side := living(side)
	for actor in living_side:
		if _has_status(actor, "indomavel"):
			# Vida abaixo de 1/3
			if int(actor["hp"]) * 3 < int(actor["max_hp"]):
				try_posture_trigger(actor, "indomavel")
		if _has_status(actor, "sobrevivente") and living_side.size() == 1:
			try_posture_trigger(actor, "sobrevivente")

func _notify_card_posture_hooks(source: Dictionary, definition: Dictionary) -> void:
	if source.is_empty() or definition.is_empty():
		return
	if bool(definition.get("reach", false)):
		try_posture_trigger(source, "atirador")
	if bool(definition.get("drain", false)) or card_has_flag(definition, "drain"):
		try_posture_trigger(source, "drenador")
	if bool(definition.get("item", false)) or str(definition.get("id", "")).begins_with("item_"):
		try_posture_trigger(source, "preparo")

func _has_status(actor: Dictionary, id: String) -> bool:
	var state := _status_state(actor, id)
	return not state.is_empty() and int(state.get("duration", 0)) > 0

func _add_status(actor: Dictionary, id: String, duration: int, stacks: int, source: int) -> void:
	# 100% Gordura: imune a Ferido, Sangrando, Preso.
	if str(actor.get("passive", "")) == "gordura_100":
		var nid := _normalize_status_id(id)
		if nid in ["wounded", "bleed", "bind", "bound"]:
			_log("%s: 100%% Gordura ignorou %s." % [actor["name"], nid])
			visual.emit("immune", int(source), int(actor["id"]), 0)
			return
	# Counter metadata: preserve effects/mode if já setados no state parcial via caller.
	if actor.is_empty() or actor["hp"] <= 0:
		return
	id = _normalize_status_id(id)
	# protected/protecting removidos — Row cobre posicionamento; viram Proteção.
	if id == "":
		return
	var statuses := _ensure_statuses(actor)
	# Posturas são exclusivas: aplicar uma remove as demais.
	if POSTURES.has(id):
		_clear_other_postures(actor, id)
	if id in ["stun", "bind", "bound"]:
		statuses.erase("protecting")
		statuses.erase("protected")
	# Resistente ↔ Frágil: cancelamento mútuo (só um permanece).
	if id == "resistente":
		if _has_status(actor, "fragil"):
			var fragile: int = _status_stacks(actor, "fragil")
			var apply: int = stacks
			if apply <= fragile:
				var fs: Dictionary = _status_state(actor, "fragil")
				fs["stacks"] = fragile - apply
				if int(fs["stacks"]) <= 0:
					statuses.erase("fragil")
				else:
					statuses["fragil"] = fs
				_log("%s: Frágil absorveu Resistente (%d)." % [actor["name"], apply])
				return
			stacks = apply - fragile
			statuses.erase("fragil")
		stacks = mini(5, stacks)
	elif id == "fragil":
		if _has_status(actor, "resistente"):
			var hard: int = _status_stacks(actor, "resistente")
			var apply2: int = stacks
			if apply2 <= hard:
				var hs: Dictionary = _status_state(actor, "resistente")
				hs["stacks"] = hard - apply2
				if int(hs["stacks"]) <= 0:
					statuses.erase("resistente")
				else:
					statuses["resistente"] = hs
				_log("%s: Resistente absorveu Frágil (%d)." % [actor["name"], apply2])
				return
			stacks = apply2 - hard
			statuses.erase("resistente")
		stacks = mini(5, stacks)
	var state: Dictionary = statuses.get(id, {"duration": 0, "stacks": 0, "source": source})
	if id == "barrier":
		# duration = rodadas; stacks/barrier_hp = HP da barreira.
		var add_hp: int = maxi(1, stacks)
		state["duration"] = max(int(state.get("duration", 0)), maxi(1, duration))
		state["barrier_hp"] = int(state.get("barrier_hp", state.get("stacks", 0))) + add_hp
		state["stacks"] = int(state["barrier_hp"])
	elif id == "protecao":
		# stacks = ataques ignorados; duration alta só para o status viver até stacks zerarem.
		state["duration"] = max(int(state.get("duration", 0)), maxi(duration, maxi(stacks, 1)))
		state["stacks"] = mini(15, int(state.get("stacks", 0)) + maxi(1, stacks))
	elif id in ["resistente", "fragil"]:
		state["duration"] = max(int(state.get("duration", 0)), maxi(1, duration))
		state["stacks"] = mini(5, int(state.get("stacks", 0)) + maxi(1, stacks))
	elif id == "escuridao":
		# Persistente: acumula ao sofrer dano; não tiqueia stacks.
		state["duration"] = 99
		state["stacks"] = mini(20, int(state.get("stacks", 0)) + maxi(1, stacks))
	elif id == "bleed":
		# Bleed X: dura X rodadas, causa X no tick; stacks = dano restante.
		var add: int = maxi(1, stacks)
		state["stacks"] = int(state.get("stacks", 0)) + add
		state["duration"] = maxi(int(state.get("duration", 0)), int(state["stacks"]))
	elif POSTURES.has(id):
		# Postura: duração em rodadas; stacks fixo 1 (não acumula).
		state["duration"] = maxi(1, duration)
		state["stacks"] = 1
	elif id in ["atento", "wounded", "slow"]:
		var add2: int = maxi(1, stacks)
		state["stacks"] = int(state.get("stacks", 0)) + add2
		state["duration"] = max(int(state.get("duration", 0)), maxi(duration, add2))
	else:
		state["duration"] = max(int(state["duration"]), duration)
		state["stacks"] = min(9, int(state["stacks"]) + stacks)
	state["source"] = source
	state["play_stamp"] = played_cards if phase == "PLAYER" else -1
	if id == "summoning": state["armed"] = false
	statuses[id] = state
	_log("%s: %s (%d)." % [actor["name"], id, state["stacks"]])
	_rpt("battle", "status_add", {
		"actor_id": int(actor.get("id", -1)), "name": str(actor.get("name", "")),
		"status": id, "duration": int(state.get("duration", 0)),
		"stacks": int(state.get("stacks", 0)), "source": source,
		"is_posture": is_posture_id(id),
	})
	# Postura Controlador / Garra: status negativo inimigo↔alvo.
	if id in NEGATIVE:
		var applier := actor_by_id(source)
		if not applier.is_empty() and int(applier.get("id", -1)) != int(actor.get("id", -2)):
			if str(applier.get("side", "")) != str(actor.get("side", "")):
				try_posture_trigger(applier, "controlador")
				try_posture_trigger(actor, "garra")

func _cleanse(actor: Dictionary) -> void:
	for id in NEGATIVE:
		actor["statuses"].erase(id)


## Counter padrão: só frente vs frente; se não houver frente no time atacante, usa regras de alcance corpo-a-corpo.
func _counter_can_strike(defender: Dictionary, attacker: Dictionary) -> bool:
	if defender.is_empty() or attacker.is_empty() or int(attacker.get("hp", 0)) <= 0:
		return false
	var mode := str(defender.get("statuses", {}).get("counter", {}).get("mode", "default"))
	if mode == "any":
		return true
	# default: frente vs frente; se o atacante não tem frente no time, mesmas regras de melee (can_reach sem Alcance).
	var atk_side := str(attacker.get("side", ""))
	var def_side := str(defender.get("side", ""))
	var atk_has_front := living(atk_side).any(func(a): return a["row"] == "front")
	var def_has_front := living(def_side).any(func(a): return a["row"] == "front")
	if atk_has_front and def_has_front:
		return str(defender.get("row", "")) == "front" and str(attacker.get("row", "")) == "front"
	# Sem frente: regras de alcance corpo-a-corpo (carta sem reach).
	var faux := {"reach": false}
	return can_reach(defender, attacker, faux)

func _resolve_counter_effects(defender: Dictionary, attacker: Dictionary, effects: Array) -> void:
	for a in effects:
		if typeof(a) != TYPE_ARRAY or a.is_empty():
			continue
		var op := str(a[0])
		match op:
			"hit":
				var card_amt: float = resolve_amount(a[1] if a.size() > 1 else 0, defender)
				var base: float = card_amt + float(defender.get("attack", 0))
				var dmg: int = maxi(1, roundi(base) - int(attacker.get("armor", 0)))
				_take_damage(defender, attacker, dmg, false, false)
			"status":
				var st := str(a[1] if a.size() > 1 else "wounded")
				var stacks := maxi(1, int(round(resolve_amount(a[2] if a.size() > 2 else 1, defender))))
				_add_status(attacker, st, stacks, stacks, int(defender["id"]))
			_:
				pass

func can_reach(source: Dictionary, target: Dictionary, card: Dictionary) -> bool:
	if source.is_empty() or target.is_empty() or target["hp"] <= 0:
		return false
	if source["side"] != target["side"]:
		# conceal ainda esconde; protected/protecting removidos (Row cobre posição).
		if _has_status(target, "conceal") and not card.get("ignore_conceal", false):
			return false
		if not card.get("reach", false):
			if source["row"] == "back" and living(source["side"]).any(func(a): return a["row"] == "front"):
				return false
			if target["row"] == "back" and living(target["side"]).any(func(a): return a["row"] == "front"):
				return false
			# Barreira agora é pool de HP — não bloqueia mira.
	return true

func _targets(source: Dictionary, primary: Dictionary, card: Dictionary, chain_ids: Array = [], roll_random: bool = true) -> Array[Dictionary]:
	var target_kind: String = card.get("target", "ENEMY")
	var opposite: String = "ENEMY" if source["side"] == "ALLY" else "ALLY"
	var result: Array[Dictionary] = []
	if primary.is_empty(): return result
	if target_kind == "SELF":
		result.append(source)
	elif target_kind == "OWN_MINION":
		if primary.get("side", "") == source.get("side", "") and bool(primary.get("is_summon", false)) and int(primary.get("summoner_id", -1)) == int(source["id"]) and int(primary.get("hp", 0)) > 0:
			result.append(primary)
	elif target_kind == "ALLY":
		if primary["side"] == source["side"] and primary["hp"] > 0:
			result.append(primary)
	elif target_kind == "DEAD_ALLY":
		if primary["side"] == source["side"] and int(primary.get("hp", 0)) <= 0 and not _has_status(primary, "banished") and not _summon_leaves_cycle(primary):
			result.append(primary)
	elif target_kind == "ALL_ALLIES":
		if primary["side"] == source["side"] and primary["hp"] > 0: result = living(source["side"])
	elif target_kind == "ALL_ENEMIES":
		if primary["side"] == opposite and can_reach(source, primary, card):
			for actor in living(opposite):
				result.append(actor)
	elif target_kind == "ALL_OTHERS":
		# Todos vivos exceto o conjurador (aliados e inimigos).
		for actor in actors:
			if actor["hp"] > 0 and int(actor["id"]) != int(source["id"]) and not _has_status(actor, "banished"):
				result.append(actor)
	elif target_kind in ["ENEMY_ROW", "ROW", "FRONT_ROW", "BACK_ROW"]:
		var chosen_row: String = "front" if target_kind == "FRONT_ROW" else "back" if target_kind == "BACK_ROW" else primary["row"]
		if primary["side"] == opposite and primary["row"] == chosen_row and can_reach(source, primary, card):
			for actor in living(opposite):
				if actor["row"] == chosen_row or _has_status(source, "unleashed"):
					result.append(actor)
	elif target_kind == "ADJACENT":
		if primary["side"] == opposite and can_reach(source, primary, card):
			var neighbors: Array[Dictionary] = []
			for actor in living(opposite):
				if actor["row"] == primary["row"]: neighbors.append(actor)
			var middle := neighbors.find(primary)
			var radius: int = int(card.get("adjacent", 1)) + (1 if _has_status(source, "unleashed") else 0)
			for index in range(neighbors.size()):
				if abs(index - middle) <= radius:
					result.append(neighbors[index])
	elif target_kind == "RANDOM":
		if primary["side"] == opposite and can_reach(source, primary, card):
			var candidates: Array[Dictionary] = []
			for actor in living(opposite):
				if can_reach(source, actor, card): candidates.append(actor)
			if not candidates.is_empty():
				if roll_random: result.append(candidates[rng.randi_range(0, candidates.size() - 1)])
				else: result = candidates
	elif target_kind == "CHAIN":
		var ids: Array = chain_ids if not chain_ids.is_empty() else [primary["id"]]
		if ids.size() <= int(card.get("chain", 1)):
			for id in ids:
				var chain_target := actor_by_id(int(id))
				if chain_target.get("side", "") == opposite and can_reach(source, chain_target, card):
					result.append(chain_target)
		if result.size() != ids.size(): result.clear()
	elif target_kind == "ANY_UNIT":
		if primary["hp"] > 0 and (primary["side"] == source["side"] or can_reach(source, primary, card)):
			result.append(primary)
	else:
		if primary["side"] == opposite and can_reach(source, primary, card):
			result.append(primary)
	return result

func _damage_value(source: Dictionary, target: Dictionary, effect: Dictionary, card: Dictionary) -> int:
	var attack_stat: int = int(source.get(str(effect.get("stat", "attack")), 0))
	var upgrade: int = int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)
	var base: int = int(effect.get("amount", 0)) + attack_stat + upgrade * 2
	if card.get("mod", "") == "damage":
		base += 3
	var attack_bonus := 0.0
	if _has_status(source, "strengthened"): attack_bonus += 0.50
	if _has_status(source, "weak"): attack_bonus -= 0.50
	if _has_status(source, "critical"): attack_bonus += 0.50
	if _has_status(source, "binary") or _has_status(source, "overpowered") or _has_status(source, "strongest_there_is"): attack_bonus += 1.0
	if _has_status(source, "offensive_rush"): attack_bonus += 0.25
	if _has_status(source, "ravenous"): attack_bonus += 0.15 * float(_status_stacks(source, "ravenous"))
	if _has_status(source, "en_fuego"): attack_bonus += 0.15 * float(_status_stacks(source, "en_fuego"))
	if _has_status(source, "fatal_fury"): attack_bonus += 1.0
	if (card.get("enhanced_triggered", false) or _has_status(source, "enhanced") and _get_impulse(str(source.get("side", "ALLY"))) >= 4) and (int(card.get("cost", 0)) > 0 or str(card.get("stat", "")) == "power" or str(effect.get("stat", "")) == "power"): attack_bonus += 0.25
	base = roundi(base * maxf(0.0, 1.0 + attack_bonus))
	if _has_status(source, "blind"):
		base = roundi(base * 0.75)
	if source.get("passive", "") == "rastreador" and source["row"] == "back":
		base += 2
	if source.get("passive", "") == "oportunista" and _has_status(target, "marked"):
		base += 2
	if card.get("id", "") == "dueto":
		var partner: Dictionary = actor_by_id(int(card.get("partner", -1)))
		if partner.get("hp", 0) > 0:
			base += floori(float(partner.get("power", 0)) / 2.0)
	var multiplier: float = Content.TYPES.get(source.get("type", ""), {}).get(target.get("type", ""), 1.0)
	if _has_status(target, "vulnerable"):
		multiplier *= 1.5
	if effect.get("environment", false) and _has_status(target, "webbed_up"):
		multiplier *= 1.5
	if _has_status(source, "blessed") and target.get("faction", "") == "abissal":
		multiplier *= 2.0
	# Espécie: cartas podem ter vs_species { "Mutante": 0.25, ... } (±25% típico).
	var vs_species: Dictionary = {}
	if card.has("vs_species"):
		vs_species = card.get("vs_species", {})
	elif Content.CARDS.has(str(card.get("id", ""))):
		vs_species = Content.CARDS[str(card["id"])].get("vs_species", {})
	var target_species := str(target.get("species", ""))
	if target_species != "" and vs_species.has(target_species):
		var vs_mod: float = float(vs_species[target_species])
		# Atento: ignora desvantagem de espécie/tipo (mods negativos).
		if vs_mod < 0.0 and _has_status(source, "atento"):
			vs_mod = 0.0
		multiplier *= 1.0 + vs_mod
	# Arquétipo intransitivo (DESLIGADO por padrão via RULES.archetype_matchup).
	if bool(Content.RULES.get("archetype_matchup", false)):
		multiplier *= _archetype_multiplier(source, target)
	var damage_stat := str(effect.get("stat", card.get("stat", "attack")))
	var penetrating: bool = bool(effect.get("penetrating", false)) or bool(card.get("penetrating", false))
	var defense: int = _defense_for_stat(target, damage_stat, penetrating)
	return max(1, roundi(base * multiplier) - defense)


func _defense_for_stat(target: Dictionary, damage_stat: String, penetrating: bool = false) -> int:
	# Impacto → Armadura; Poder → Escudo (atributos permanentes).
	# Resistente/Frágil: ±2 Armadura e ±2 Escudo por stack (máx 5).
	# Penetrante: só metade da Armadura/Escudo se aplica.
	var hard: int = _status_stacks(target, "resistente")
	var frail: int = _status_stacks(target, "fragil")
	var status_bonus: int = 2 * hard - 2 * frail
	var defense: int = 0
	if damage_stat == "power":
		defense = int(target.get("escudo", 0)) + status_bonus
	else:
		defense = int(target.get("armor", 0)) + (2 * int(target.get("statuses", {}).get("armor", {}).get("stacks", 0))) + status_bonus
	defense = maxi(0, defense)
	if penetrating:
		defense = int(round(float(defense) * 0.5))
	return defense

func _archetype_multiplier(source: Dictionary, target: Dictionary) -> float:
	# Armadura > Impacto > Escudo > Poder > Armadura. Versátil/Nenhum = neutro.
	var atk := str(source.get("archetype_stat", source.get("combat_archetype", "")))
	var dfn := str(target.get("archetype_stat", target.get("combat_archetype", "")))
	if atk in ["", "Nenhum", "Versátil", "Preparo"] or dfn in ["", "Nenhum", "Versátil", "Preparo"]:
		return 1.0
	if Content.ARCHETYPE_BEATS.get(atk, "") == dfn:
		return 1.25
	if Content.ARCHETYPE_BEATS.get(dfn, "") == atk:
		# Atento: ignora desvantagem de arquétipo.
		if _has_status(source, "atento"):
			return 1.0
		return 0.75
	return 1.0

func _take_damage(source: Dictionary, target: Dictionary, amount: int, pierce: bool = false, counter_allowed: bool = true, environmental: bool = false, area: bool = false, melee: bool = false, attack_card: bool = false, from_card: bool = false, remove_stun: bool = true) -> bool:
	if target["hp"] <= 0:
		return false
	if amount > 0 and source["id"] != target["id"]:
		target["statuses"].erase("summoning")
		if melee and _has_status(target, "symbiote_skin"):
			_add_status(source, "bound", 1, 1, int(target["id"]))
			target["statuses"].erase("symbiote_skin")
	# Pipeline: Invulnerável → Proteção → Barreira (salvo pierce) → escudo/block legado → Vida.
	if _has_status(target, "invulnerable") and not _has_status(source, "atento"):
		_log("%s está invulnerável." % target["name"])
		visual.emit("immune", int(source["id"]), int(target["id"]), 0)
		return false
	# Proteção: ignora o ataque (cada hit de Chain conta). Penetrante ignora Proteção.
	if amount > 0 and not pierce and _has_status(target, "protecao"):
		var prot: Dictionary = _status_state(target, "protecao")
		prot["stacks"] = int(prot.get("stacks", 1)) - 1
		if int(prot.get("stacks", 0)) <= 0:
			_ensure_statuses(target).erase("protecao")
		else:
			_ensure_statuses(target)["protecao"] = prot
		_log("%s: Proteção absorveu o ataque." % target["name"])
		visual.emit("resist", int(source["id"]), int(target["id"]), 0)
		# Intocável: evitou ataque inimigo via Proteção.
		if int(source.get("id", -1)) != int(target.get("id", -2)) and str(source.get("side", "")) != str(target.get("side", "")):
			try_posture_trigger(target, "intocavel")
		return false
	# Leftover raw "resist" key (pre-normalize). _has_status("resist") aliases to protecao — never [] on alias.
	if amount > 0 and not pierce and _ensure_statuses(target).has("resist"):
		var layers: Dictionary = target["statuses"].get("resist", {})
		if not layers.is_empty():
			layers["stacks"] = int(layers.get("stacks", 1)) - 1
			if int(layers.get("stacks", 0)) <= 0: target["statuses"].erase("resist")
			else: target["statuses"]["resist"] = layers
			_log("%s resistiu ao ataque." % target["name"])
			visual.emit("resist", int(source["id"]), int(target["id"]), 0)
			return false
	if environmental and _has_status(target, "webbed_up"):
		amount = roundi(amount * 1.5)
	if environmental and _has_status(source, "full_force"):
		amount = roundi(amount * 1.5)
	if target.get("minion", false) and amount > 0:
		amount = max(amount, int(target["hp"]))
	var hp_before := int(target["hp"])
	var remaining := amount
	# Barreira (pool de HP próprio). Penetrante ignora por completo (não gasta HP da barreira).
	if remaining > 0 and not pierce and _has_status(target, "barrier"):
		var bar: Dictionary = _status_state(target, "barrier")
		var bhp: int = int(bar.get("barrier_hp", bar.get("stacks", 0)))
		var soaked: int = mini(remaining, bhp)
		bhp -= soaked
		remaining -= soaked
		if bhp <= 0:
			target["statuses"].erase("barrier")
			_log("%s: Barreira destruída." % target["name"])
		else:
			bar["barrier_hp"] = bhp
			bar["stacks"] = bhp
			target["statuses"]["barrier"] = bar
			_log("%s: Barreira absorveu %d (%d restante)." % [target["name"], soaked, bhp])
	# Escudo/bloqueio legados (cartas Cap / passivas) — ainda absorvem após Barreira.
	if remaining > 0 and not pierce:
		for layer in ["shield", "block"]:
			var absorbed: int = min(remaining, target[layer])
			target[layer] -= absorbed
			remaining -= absorbed
	target["hp"] = max(0, int(target["hp"]) - remaining)
	var hp_lost := hp_before - int(target["hp"])
	if hp_lost > 0:
		if remove_stun:
			target["statuses"].erase("stun")
		if area or environmental: target["statuses"].erase("conceal")
		# Alyssa passive Escuridão: +1 stack cada vez que perde Vida.
		if str(target.get("passive", "")) == "escuridao":
			_add_status(target, "escuridao", 99, 1, int(target["id"]))
		# Posturas: Tanque / Furioso / Empático (1× por postura / rodada).
		try_posture_trigger(target, "tanque")
		if int(source.get("id", -1)) != int(target.get("id", -2)):
			if str(source.get("side", "")) != str(target.get("side", "")):
				try_posture_trigger(source, "furioso")
			else:
				try_posture_trigger(source, "empatico")
		# Derretimento: Atordoado ao ser atingido por PROJETIVO ou QUIMICO.
		if str(target.get("desvantagem", "")) == "ent_dominika_seur_desvantagem_derretimento" or str(target.get("passive_derretimento", "")) == "1":
			var atype := str(source.get("type", ""))
			if atype in ["PROJETIVO", "QUIMICO"] and int(source.get("id", -1)) != int(target.get("id", -2)):
				_add_status(target, "stun", 1, 1, int(source["id"]))
				_log("%s: Derretimento (Atordoado)." % target["name"])
		if source["id"] != target["id"] and from_card and (_has_status(source, "lifesteal") or _has_status(source, "blood_magic") and attack_card or _has_status(source, "berserk_lifesteal") or _has_status(source, "vampiric_essence")):
			source["hp"] = min(int(source["max_hp"]), int(source["hp"]) + hp_lost)
		if source["id"] != target["id"] and not environmental and (from_card or not counter_allowed) and _has_status(source, "bloodlust"):
			_add_status(target, "bleed", 2, 1, int(source["id"]))
		if source["id"] != target["id"] and from_card and _has_status(source, "make_em_bleed"):
			_add_status(target, "bleed", 2, 2, int(source["id"]))
		if not melee: target["statuses"].erase("symbiote_skin")
	if int(target.get("block", 0)) <= 0 and _barrier_hp(target) <= 0:
		for id in ["binary", "bloodlust"]: target["statuses"].erase(id)
	if hp_lost > 0: visual.emit("hit", int(source["id"]), int(target["id"]), hp_lost)
	elif amount > 0: visual.emit("block", int(source["id"]), int(target["id"]), amount)
	_log("%s sofreu %d de dano (%d Vida)." % [target["name"], amount, target["hp"]])
	var died: bool = target["hp"] <= 0
	if died:
		_log("%s caiu." % target["name"])
		_rpt("battle", "death", {
			"actor_id": int(target.get("id", -1)),
			"name": str(target.get("name", "")),
			"archetype": str(target.get("archetype", "")),
			"side": str(target.get("side", "")),
			"is_summon": bool(target.get("is_summon", false)),
			"minion": bool(target.get("minion", false)),
			"summoner_id": int(target.get("summoner_id", -1)),
			"killer_id": int(source.get("id", -1)),
		})
		# Posturas: Executor (matou inimigo) / Vingador (aliado morreu).
		if int(source.get("id", -1)) != int(target.get("id", -2)) and str(source.get("side", "")) != str(target.get("side", "")):
			try_posture_trigger(source, "executor")
		var dead_side := str(target.get("side", ""))
		for ally in living(dead_side):
			try_posture_trigger(ally, "vingador")
		if bool(target.get("is_summon", false)) or bool(target.get("minion", false)):
			purge_owner_cards(int(target["id"]))
			_log("%s caiu — cartas removidas do baralho." % target.get("name", "?"))
		# Conjurador (ex.: Nero/Naomi) cai → todos os lacaios invocados caem e perdem cartas.
		purge_summons_of(int(target["id"]))
		# Herói morto permanece no campo e no ciclo. Reanimar entra no baralho do lado.
		_sync_reanimar(str(target.get("side", "")))
		visual.emit("death", int(source["id"]), int(target["id"]), 0)
		var ability_ko: bool = source["id"] != target["id"] and source["side"] != target["side"] and (not environmental or from_card)
		if ability_ko and _has_status(source, "fury_totem"): _draw(1)
		if ability_ko and _has_status(source, "en_fuego"):
			_add_status(source, "en_fuego", 99, 1, int(source["id"]))
		if ability_ko and team_ko_charges > 0 and _has_status(source, "all_together_now"):
			var helper := actor_by_id(int(_status_state(source, "all_together_now").get("source", -1)))
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
		if _counter_can_strike(target, source):
			_log("%s contra-atacou." % target["name"])
			visual.emit("counter", int(target["id"]), int(source["id"]), 0)
			var cst: Dictionary = _status_state(target, "counter")
			var cfx: Array = cst.get("effects", [])
			if typeof(cfx) == TYPE_ARRAY and not cfx.is_empty():
				_resolve_counter_effects(target, source, cfx)
			else:
				_take_damage(target, source, max(1, 3 + floori(float(target["attack"]) / 2.0)), false, false)
	return died

func _purge_dead_cards() -> void:
	# Só lacaios/invocações mortos. Herói morto fica no ciclo (mão/baralho/descarte).
	var removed := 0
	var by_owner: Dictionary = {}
	for pile in [hand, deck, discard, enemy_hand, enemy_deck, enemy_discard]:
		for index in range(pile.size() - 1, -1, -1):
			var card: Dictionary = pile[index]
			var owner := actor_by_id(int(card.get("owner", -1)))
			if owner.is_empty():
				continue
			if not _summon_leaves_cycle(owner):
				continue
			if int(owner.get("hp", 0)) <= 0 and not owner.get("statuses", {}).has("soulbound"):
				var oid := int(owner.get("id", -1))
				by_owner[oid] = int(by_owner.get(oid, 0)) + 1
				pile.remove_at(index)
				removed += 1
	if removed > 0:
		_rpt("battle", "purge_dead_summon_cards", {"removed": removed, "by_owner": by_owner})

func _resolve(source: Dictionary, targets: Array[Dictionary], card: Dictionary, card_data: Dictionary) -> Array[int]:
	var fallen: Array[int] = []
	var fatal_targets: Array[Dictionary] = []
	var damage_effects: Array = card_data.get("effects", [])
	var fatal_active: bool = _has_status(source, "fatal_fury") and damage_effects.any(func(e): return e.get("kind", "") == "DAMAGE")
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
			var acting_hand := _hand_of(_acting())
			if Content.CARDS.has(new_id) and acting_hand.size() < int(rules["hand_max"]):
				var generated := _create_card(new_id, int(source["id"]))
				generated["temporary"] = true
				acting_hand.append(generated)
		elif kind == "CARD_PLAY":
			_add_plays(_acting(), int(effect.get("amount", 1)))
		elif kind == "SUMMON":
			if source["side"] == "ENEMY":
				spawn_enemy(effect.get("id", "fera"))
		elif kind == "NEXT_TURN":
			source["pending"].append(effect.get("effects", [{"kind": "DRAW", "amount": 1}]))
		elif kind == "INFECT":
			var viable: Array[Dictionary] = []
			var owner_id: int = int(targets[0]["id"]) if not targets.is_empty() else int(source["id"])
			var acting_hand := _hand_of(_acting())
			for owned_card in acting_hand:
				if owned_card["owner"] == owner_id: viable.append(owned_card)
			if not viable.is_empty(): viable[rng.randi_range(0, viable.size() - 1)]["infected"] = true
		else:
			for target in effect_targets:
				if kind == "REVIVE":
					_revive_unit(source, target, float(effect.get("fraction", 0.25)))
					continue
				if target["hp"] <= 0:
					continue
				match kind:
					"DAMAGE":
						var is_area: bool = str(card_data.get("target", "")) in ["ENEMY_ROW", "ROW", "FRONT_ROW", "BACK_ROW", "ADJACENT", "ALL_ENEMIES"]
						var is_melee: bool = (not bool(card_data.get("reach", false))) and source["side"] != target["side"]
						var original_hp := int(target["hp"])
						var penetrating: bool = bool(effect.get("penetrating", false)) or bool(card.get("penetrating", false)) or bool(card_data.get("penetrating", false))
						var dmg_effect: Dictionary = effect.duplicate(true)
						if penetrating: dmg_effect["penetrating"] = true
						var keep_stun: bool = bool(card_data.get("lethargic", false)) or bool(card.get("lethargic", false))
						var hit_amount: int = _damage_value(source, target, dmg_effect, card)
						if _take_damage(source, target, hit_amount, bool(effect.get("pierce", false)) or penetrating, true, false, is_area, is_melee, card_data.get("class", "") == "ATTACK", true, not keep_stun):
							fallen.append(int(target["id"]))
						if bool(card_data.get("recoil", false)) or bool(card.get("recoil", false)):
							var recoil_amt: int = maxi(0, roundi(float(hit_amount) / 3.0))
							if recoil_amt > 0: _take_damage(source, source, recoil_amt, true, false)
						if bool(card_data.get("drain", false)) or bool(card.get("drain", false)):
							var drain_amt: int = maxi(0, roundi(float(hit_amount) / 4.0))
							if drain_amt > 0: source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + drain_amt)
						if fatal_active and target["hp"] > 0 and target["hp"] < original_hp and not fatal_targets.has(target): fatal_targets.append(target)
					"HEAL":
						var before_heal := int(target["hp"])
						var bonus: int = (int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)) * 2 + (3 if str(source.get("passive", "")) == "devocao" else 0)
						target["hp"] = min(int(target["max_hp"]), int(target["hp"]) + int(effect.get("amount", 0)) + bonus)
						var healed_amt: int = int(target["hp"]) - before_heal
						visual.emit("heal", int(source["id"]), int(target["id"]), healed_amt)
						_log("%s recuperou vida (%d PV)." % [target["name"], target["hp"]])
						if healed_amt > 0:
							try_posture_trigger(source, "curador")
					"BLOCK", "SHIELD":
						# Migrado: BLOCK/SHIELD de Content → Barreira (pool). Cap usa Proteção via packs.
						var bamt: int = int(effect.get("amount", 0)) + (int(card.get("upgrade", 0)) + (1 if _has_status(source, "strongest_there_is") else 0)) * 2
						var br: int = 2 if bamt >= 10 else 1
						_add_status(target, "barrier", br, maxi(1, bamt), int(source["id"]))
						visual.emit("guard", int(source["id"]), int(target["id"]), bamt)
					"STATUS":
						if effect["id"] == "all_together_now": team_ko_charges = int(effect.get("stacks", 2))
						_add_status(target, effect["id"], int(effect.get("duration", 1)), int(effect.get("stacks", 1)), int(source["id"]))
						visual.emit("status", int(source["id"]), int(target["id"]), 0)
					"CURE": _cleanse(target)
					"CLEANSE", "DISPEL":
						for id in effect.get("ids", []):
							target["statuses"].erase(id)
					"PUSH":
						if _has_status(target, "bound"):
							continue
						var force: int = int(effect.get("force", 1)) * (2 if bool(effect.get("forceful", false)) else 1)
						if _has_status(source, "portal"):
							if _take_damage(source, target, roundi(source["attack"] * 1.5), false, false, true, false, false, false, true): fallen.append(int(target["id"]))
							source["statuses"].erase("portal")
						if target["row"] == "front":
							target["row"] = "back"
							visual.emit("move", int(source["id"]), int(target["id"]), 0)
							_log("%s recuou para a retaguarda." % target["name"])
							if force > 1 and _take_damage(source, target, 4 * force, false, false, true, false, false, false, true): fallen.append(int(target["id"]))
						elif force > 1:
							if _take_damage(source, target, 4 * force, false, false, true, false, false, false, true): fallen.append(int(target["id"]))
							_log("%s colidiu com o cenário." % target["name"])
						if _has_status(target, "drop") and target["hp"] > 0 and not target.get("boss", false):
							var chance := clampf(1.0 - float(target["hp"]) / float(target["max_hp"]), 0.1, 0.9)
							if rng.randf() < chance:
								if _take_damage(source, target, int(target["hp"]), true, false, true, false, false, false, true): fallen.append(int(target["id"]))
					"PULL":
						if target["row"] == "back" and not _has_status(target, "bound"):
							target["row"] = "front"
							visual.emit("move", int(source["id"]), int(target["id"]), 0)
							_log("%s foi puxado para a frente." % target["name"])
					"MOVE":
						if not _has_status(target, "bound"):
							target["row"] = "back" if target["row"] == "front" else "front"
							visual.emit("move", int(source["id"]), int(target["id"]), 0)
	if fatal_active:
		source["statuses"].erase("fatal_fury")
		for victim in fatal_targets: _add_status(victim, "wounded", 2, 1, int(source["id"]))
	return fallen

func _revive_unit(source: Dictionary, target: Dictionary, fraction: float) -> void:
	if target.is_empty() or int(target.get("hp", 0)) > 0:
		return
	if str(target.get("side", "")) != str(source.get("side", "")):
		return
	if _has_status(target, "banished"):
		return
	var max_hp := maxi(1, int(target.get("max_hp", 1)))
	var healed := maxi(1, roundi(float(max_hp) * fraction))
	target["hp"] = mini(max_hp, healed)
	_log("%s foi reanimado com %d de Vida." % [target.get("name", "?"), int(target["hp"])])
	visual.emit("heal", int(source.get("id", -1)), int(target["id"]), int(target["hp"]))
	_rpt("battle", "revive", {
		"actor_id": int(target["id"]),
		"name": str(target.get("name", "")),
		"hp": int(target["hp"]),
		"max_hp": max_hp,
		"side": str(target.get("side", "")),
	})

func _cost(source: Dictionary, definition: Dictionary) -> int:
	# Único recurso de turno compartilhado: Iniciativa (impulse). Sem pool de "Poder".
	var cost: int = int(definition.get("cost", 0))
	if combo_zero_owners.get(int(source.get("id", -1)), false):
		if str(definition.get("tier", "")) != "combo":
			return 0
	if cost > 0:
		if _has_status(source, "fast"): cost -= 1
		if _has_status(source, "slow"): cost += 1
		if _has_status(source, "enhanced") and _get_impulse(str(source.get("side", "ALLY"))) >= 4:
			cost = max(0, cost - _status_stacks(source, "enhanced"))
	return max(0, cost)

func _after_card_play() -> void:
	for actor in actors:
		if actor["hp"] <= 0: continue
		# "dazed" aliases → stun (duration-ticked). Never play-tick under the alias key.
		for id in ["frenzy", "confused", "feeding_frenzy"]:
			var nid := _normalize_status_id(id)
			if not _has_status(actor, nid): continue
			var statuses := _ensure_statuses(actor)
			var state: Dictionary = _status_state(actor, nid)
			if state.is_empty():
				continue
			if id == "feeding_frenzy" and (_has_status(actor, "stun") or _has_status(actor, "bind") or _has_status(actor, "bound")):
				statuses.erase(nid)
				continue
			if state.get("play_stamp", -1) == played_cards: continue
			state["stacks"] = int(state.get("stacks", 1)) - 1
			if id == "confused" and not _has_status(actor, "stun") and not _has_status(actor, "bind") and not _has_status(actor, "bound"):
				var possible := living("ALLY") + living("ENEMY")
				possible.erase(actor)
				if not possible.is_empty():
					var victim: Dictionary = possible[rng.randi_range(0, possible.size() - 1)]
					_take_damage(actor, victim, max(1, int(actor["attack"])), false, false)
			if int(state.get("stacks", 0)) > 0:
				statuses[nid] = state
				continue
			statuses.erase(nid)
			match id:
				"frenzy":
					pass
				"feeding_frenzy":
					if mission.get("objective", "") == "PROTECT": protect_hp = max(0, protect_hp - 9)

func play(hand_index: int, target_id: int, chain_ids: Array = []) -> bool:
	if phase != "PLAYER" and phase != "ENEMY":
		return false
	var side := _acting()
	var acting_hand := _hand_of(side)
	if hand_index < 0 or hand_index >= acting_hand.size():
		return false
	var card: Dictionary = acting_hand[hand_index]
	var source := actor_by_id(card["owner"])
	var target := actor_by_id(target_id)
	var definition: Dictionary = Content.CARDS.get(card["id"], {})
	if source.is_empty() or target.is_empty() or source["hp"] <= 0 or definition.is_empty() or source.get("side", "") != side:
		return false
	if card["id"] == "dueto" and actor_by_id(int(card.get("partner", -1))).get("hp", 0) <= 0:
		return false
	if not card_warmup_ready(card, definition):
		_log("%s ainda em aquecimento." % definition.get("name", card["id"]))
		return false
	var cost := _cost(source, definition)
	# Instantâneo NÃO é free por padrão (é restrição negativa); só free se marcado.
	var plays: int = 0 if bool(definition.get("free", false)) or card_has_flag(definition, "free") else int(definition.get("plays", 1))
	if _get_impulse(side) < cost or _get_plays(side) < plays or _has_status(source, "stun") or _has_status(source, "bind") or _has_status(source, "bound") or _has_status(source, "dazed") or _has_status(source, "banished") or _has_status(source, "finalized"):
		return false
	if _has_status(source, "silence") and definition.get("class", "") in ["SKILL", "ESTADO", "POSTURA", "POWER"]:
		return false
	var targets := _targets(source, target, definition, chain_ids)
	if definition.get("target", "") == "CHAIN" and chain_ids.size() != int(definition.get("chain", 1)):
		return false
	if targets.is_empty() or definition.get("target", "") == "CHAIN" and not chain_ids.is_empty() and targets.size() != chain_ids.size():
		return false
	var had_momentum := _has_status(source, "momentum")
	card["enhanced_triggered"] = _has_status(source, "enhanced") and _get_impulse(side) >= 4
	_set_plays(side, _get_plays(side) - plays)
	var gained: int = int(definition.get("gain", 0)) + (1 if card.get("mod", "") == "impulse" else 0)
	_set_impulse(side, clampi(_get_impulse(side) - cost + gained, 0, int(rules["impulse_max"])))
	_log("%s usou %s." % [source["name"], definition["name"]])
	visual.emit("cast", int(source["id"]), int(target["id"]), 0)
	acting_hand.remove_at(hand_index)
	played_cards += 1
	if card.get("infected", false): _add_status(source, "bleed", 1, 1, int(source["id"]))
	if _has_status(source, "wounded"):
		_take_damage(source, source, 3 * _status_stacks(source, "wounded"), true, false)
	var fallen: Array[int] = []
	if source["hp"] > 0:
		var bleed_effects: Array = definition.get("effects", [])
		var bleed_charge: bool = _has_status(source, "make_em_bleed") and bleed_effects.any(func(e): return e.get("kind", "") == "DAMAGE")
		fallen = _resolve(source, targets, card, definition)
		if bleed_charge and _has_status(source, "make_em_bleed"):
			var charges: Dictionary = _status_state(source, "make_em_bleed")
			charges["stacks"] = int(charges.get("stacks", 1)) - 1
			if int(charges.get("stacks", 0)) <= 0: _ensure_statuses(source).erase("make_em_bleed")
			else: _ensure_statuses(source)["make_em_bleed"] = charges
		if definition.get("target", "") == "CHAIN" and definition.has("full_combo") and chain_ids.size() == int(definition.get("chain", 1)) and chain_ids.all(func(id): return id == chain_ids[0]):
			var combo_target := actor_by_id(int(chain_ids[0]))
			if combo_target.get("hp", 0) > 0:
				var one: Array[Dictionary] = [combo_target]
				_resolve(source, one, card, {"effects": definition["full_combo"]})
	_notify_card_posture_hooks(source, definition)
	if source.get("archetype", "") == "clerigo" and definition.get("effects", []).any(func(e): return e.get("kind", "") == "HEAL"):
		_set_impulse(side, min(int(rules["impulse_max"]), _get_impulse(side) + 1))
		_log("Clérigo ganhou Iniciativa ao curar.")
	if plays > 0 and (definition.get("quick", false) and fallen.has(target_id) or fallen.any(func(id): return _has_status(actor_by_id(id), "marked"))):
		_add_plays(side, 1)
		_log("Ação recuperada.")
	if definition.get("final", false): _add_status(source, "finalized", 1, 1, int(source["id"]))
	if _has_status(source, "conceal") and definition.get("target", "") not in ["SELF", "ALL_ALLIES"]:
		source["statuses"].erase("conceal")
	if had_momentum and definition.get("class", "") != "MOVE": source["statuses"].erase("momentum")
	if _has_status(source, "ravenous") and (definition.get("class", "") in ["ATTACK", "POWER"] or definition.get("effects", []).any(func(e): return e.get("kind", "") == "DAMAGE")):
		var rav: Dictionary = _status_state(source, "ravenous")
		rav["stacks"] = max(0, int(rav.get("stacks", 0)) - 1)
		if int(rav.get("stacks", 0)) <= 0: _ensure_statuses(source).erase("ravenous")
		else: _ensure_statuses(source)["ravenous"] = rav
	if card.get("temporary", false) or definition.get("exhaust", false):
		card.erase("enhanced_triggered")
		_exhausted_of(side).append(card)
	else:
		card.erase("infected")
		card.erase("enhanced_triggered")
		_discard_of(side).append(card)
	# Flags Content base: actions NEXT_TURN plays, recover, draw_own, discard, instant.
	for effect in definition.get("effects", []):
		match str(effect.get("kind", "")):
			"ACTIONS", "NEXT_PLAYS":
				grant_next_turn_plays(source, int(effect.get("amount", 1)))
			"DRAW_OWN":
				draw_own(int(source["id"]), int(effect.get("amount", 1)))
			"RECOVER_OWN":
				recover_from_discard(int(source["id"]), int(effect.get("amount", 1)), true)
			"RECOVER":
				recover_from_discard(-1, int(effect.get("amount", 1)), false)
			"DISCARD":
				discard_from_hand(int(effect.get("amount", 1)), true)
	# Instantâneo: NÃO encerra a fase. Só impede Encerrar enquanto estiver na mão.
	# Invulnerável some ao jogar qualquer carta.
	if _has_status(source, "invulnerable"):
		source["statuses"].erase("invulnerable")
		_log("%s perdeu Invulnerável ao jogar uma carta." % source["name"])
	_after_card_play()
	_check_combo()
	# Reanimar jogada vai ao descarte aqui; se ninguém segue caído, some do ciclo.
	if str(card.get("id", "")) == "reanimar" or dead_on_side(side).is_empty():
		_sync_reanimar(side)
	_check_end()
	changed.emit()
	return true

func _check_combo() -> void:
	var side := _acting()
	var acting_hand := _hand_of(side)
	var used: bool = enemy_combo_used if side == "ENEMY" else combo_used
	if used or living(side).size() < 2:
		return
	if _get_impulse(side) >= 4 and not acting_hand.any(func(c): return c["id"] == "dueto") and acting_hand.size() < int(rules["hand_max"]):
		var combo := _create_card("dueto", int(living(side)[0]["id"]))
		combo["partner"] = int(living(side)[1]["id"])
		acting_hand.append(combo)
		if side == "ENEMY": enemy_combo_used = true
		else: combo_used = true
		_log("Uma combinação de equipe entrou na mão.")

func redraw(hand_index: int) -> bool:
	return _redraw_side("ALLY", hand_index)

func _redraw_side(side: String, hand_index: int) -> bool:
	if side == "ENEMY" and phase != "ENEMY": return false
	if side != "ENEMY" and phase != "PLAYER": return false
	var acting_hand := _hand_of(side)
	var redraw_left: int = enemy_redraws if side == "ENEMY" else redraws
	if redraw_left <= 0 or hand_index < 0 or hand_index >= acting_hand.size():
		return false
	var peek: Dictionary = acting_hand[hand_index]
	var definition: Dictionary = Content.CARDS.get(peek["id"], {})
	if is_instant_card(peek, definition):
		_log("Instantâneo não pode ser recomprado.")
		return false
	# Item com dono explícito: dono precisa estar vivo no time atuante.
	if definition.get("item", false) and definition.has("owner_hero"):
		var need := str(definition["owner_hero"])
		var owner_alive := false
		for ally in living(side):
			if str(ally.get("archetype", "")) == need:
				owner_alive = true
				break
		if not owner_alive:
			_log("Item bloqueado: dono %s indisponível." % need)
			return false
	var card: Dictionary = acting_hand.pop_at(hand_index)
	if side == "ENEMY": enemy_redraws -= 1
	else: redraws -= 1
	var source := actor_by_id(card["owner"])
	var targets: Array[Dictionary] = [source]
	_resolve(source, targets, card, {"effects": definition.get("on_redraw", [])})
	if card.get("mod", "") == "redraw":
		_set_impulse(side, min(int(rules["impulse_max"]), _get_impulse(side) + 1))
	if card.get("temporary", false): _exhausted_of(side).append(card)
	else:
		card.erase("infected")
		_discard_of(side).append(card)
	_draw_side(side, 1)
	_log("Carta redesenhada.")
	_rpt("card", "redraw", {
		"side": side,
		"discarded": _card_brief(card),
		"redraws_left": (enemy_redraws if side == "ENEMY" else redraws),
		"hand": _hand_briefs(side),
	})
	visual.emit("redraw", int(source["id"]), int(source["id"]), 0)
	changed.emit()
	return true

func move_actor(id: int) -> bool:
	var actor := actor_by_id(id)
	if phase != "PLAYER" or moves <= 0 and not _has_status(actor, "momentum") or actor.get("side", "") != "ALLY" or actor.get("hp", 0) <= 0 or _has_status(actor, "bind") or _has_status(actor, "bound") or _has_status(actor, "stun") or _has_status(actor, "banished") or _has_status(actor, "finalized"):
		return false
	actor["row"] = "back" if actor["row"] == "front" else "front"
	if not _has_status(actor, "momentum"): moves -= 1
	_log("%s mudou de linha." % actor["name"])
	visual.emit("move", int(actor["id"]), int(actor["id"]), 0)
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
	# Preparo: +3 INI ao usar item (qualquer aliado com a postura).
	for ally in living("ALLY"):
		try_posture_trigger(ally, "preparo")
	_check_end()
	changed.emit()
	return true

func use_environment(index: int) -> bool:
	var objects: Array = mission.get("environment", [])
	if phase != "PLAYER" or index < 0 or index >= objects.size() or environmental_used.get(index, false) or living("ALLY").is_empty():
		return false
	var object: Dictionary = objects[index]
	var user: Dictionary = living("ALLY")[0]
	var cost: int = int(object.get("cost", 0))
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
		var opp: Dictionary = _status_state(user, "opportunist")
		opp["stacks"] = int(opp.get("stacks", 1)) - 1
		if int(opp.get("stacks", 0)) <= 0: _ensure_statuses(user).erase("opportunist")
		else: _ensure_statuses(user)["opportunist"] = opp
	environmental_used[index] = true
	for enemy in living("ENEMY"):
		if object.get("target", "front") == enemy["row"]:
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
		var aim: Dictionary = _status_state(user, "perfect_aim")
		aim["stacks"] = int(aim.get("stacks", 1)) - 1
		if int(aim.get("stacks", 0)) <= 0: _ensure_statuses(user).erase("perfect_aim")
		else: _ensure_statuses(user)["perfect_aim"] = aim
	_check_end()
	changed.emit()
	return true

func _estimate_hit(victim: Dictionary, state: Dictionary, estimate: Dictionary, raw: int, pierce: bool = false) -> void:
	if state["hp"] <= 0 or _has_status(victim, "invulnerable"): return
	if not pierce and int(state.get("protecao", state.get("resist", 0))) > 0:
		state["protecao"] = int(state.get("protecao", state.get("resist", 0))) - 1
		state["resist"] = int(state.get("resist", 0)) - 1
		estimate["resist_used"] += 1
		return
	var remaining: int = maxi(raw, int(state["hp"])) if bool(victim.get("minion", false)) else raw
	# Penetrante ignora Barreira por completo na prévia também.
	if remaining > 0 and not pierce and int(state.get("barrier_hp", 0)) > 0:
		var soak: int = mini(remaining, int(state["barrier_hp"]))
		state["barrier_hp"] -= soak
		remaining -= soak
		estimate["absorbed"] += soak
	if remaining > 0 and not pierce:
		for layer in ["shield", "block"]:
			var absorbed: int = mini(remaining, int(state[layer]))
			state[layer] -= absorbed
			remaining -= absorbed
			estimate["absorbed"] += absorbed
	var lost: int = mini(int(state["hp"]), remaining)
	state["hp"] -= lost
	estimate["damage"] += lost
	estimate["hp_after"] = state["hp"]
	estimate["shield_after"] = state["shield"]
	estimate["block_after"] = state["block"]
	estimate["hits"] += 1

func _estimate_impact(source: Dictionary, victim: Dictionary, state: Dictionary, estimate: Dictionary, amount: int) -> void:
	if _has_status(victim, "webbed_up"): amount = roundi(amount * 1.5)
	if _has_status(source, "full_force"): amount = roundi(amount * 1.5)
	_estimate_hit(victim, state, estimate, amount)

func preview(hand_index: int, target_id: int, chain_ids: Array = []) -> Dictionary:
	var acting_hand := _hand_of(_acting())
	if hand_index < 0 or hand_index >= acting_hand.size(): return {}
	var card: Dictionary = acting_hand[hand_index]
	var source := actor_by_id(card["owner"])
	var target := actor_by_id(target_id)
	if source.is_empty() or target.is_empty(): return {}
	var definition: Dictionary = Content.CARDS.get(card["id"], {})
	if definition.is_empty(): return {}
	var resolved_def: Dictionary = definition.duplicate(true)
	if definition.has("target_by_stacks"):
		var tbs: Dictionary = definition["target_by_stacks"]
		var st_id := str(tbs.get("status", "escuridao"))
		var st_n: int = _status_stacks(source, st_id)
		var chosen := str(resolved_def.get("target", "ENEMY"))
		for row in tbs.get("thresholds", []):
			if typeof(row) != TYPE_ARRAY or row.size() < 2:
				continue
			if st_n >= int(row[0]):
				chosen = str(row[1])
				break
		resolved_def["target"] = chosen
	var random_target: bool = str(resolved_def.get("target", "")) == "RANDOM"
	var targets := _targets(source, target, resolved_def, chain_ids, false)
	if targets.is_empty(): return {}
	var rows: Array[String] = []
	var estimates := {}
	var defenses := {}
	for victim in targets:
		if not defenses.has(victim["id"]):
			defenses[victim["id"]] = {"hp": int(victim["hp"]), "shield": int(victim["shield"]), "block": int(victim["block"]), "resist": int(victim["statuses"].get("resist", {}).get("stacks", 0)), "protecao": int(victim["statuses"].get("protecao", {}).get("stacks", 0)), "barrier_hp": _barrier_hp(victim), "row": victim["row"]}
			estimates[victim["id"]] = {"damage": 0, "hp_after": int(victim["hp"]), "shield_after": int(victim["shield"]), "block_after": int(victim["block"]), "row_after": victim["row"], "hits": 0, "resist_used": 0, "absorbed": 0, "statuses": [], "drop_chance": 0.0}
			if not rows.has(victim["row"]): rows.append(victim["row"])
	var effects: Array = definition.get("effects", []).duplicate(true)
	if card.has("roulette_effect"): effects.append(card["roulette_effect"])
	var self_effects: Array[String] = []
	var other_effects: Array[String] = []
	var portal_ready: bool = _has_status(source, "portal")
	for effect in effects:
		if effect.get("self", false) and not targets.has(source):
			if effect.get("kind", "") == "STATUS" and not self_effects.has(effect["id"]): self_effects.append(effect["id"])
			continue
		if effect.get("kind", "") in ["DRAW", "GENERATE", "CARD_PLAY", "NEXT_TURN", "CURE"]:
			other_effects.append(str(effect["kind"]))
		for victim in targets:
			if effect.get("self", false) and victim["id"] != source["id"]: continue
			var state: Dictionary = defenses[victim["id"]]
			var estimate: Dictionary = estimates[victim["id"]]
			if str(effect.get("kind", "")) == "REVIVE":
				var back := maxi(1, roundi(float(victim.get("max_hp", 1)) * float(effect.get("fraction", 0.25))))
				state["hp"] = back
				estimate["hp_after"] = back
				if not estimate["statuses"].has("wounded"):
					estimate["statuses"].append("wounded")
				continue
			if state["hp"] <= 0: continue
			match effect.get("kind", ""):
				"DAMAGE":
					var pen: bool = bool(effect.get("penetrating", false)) or bool(card.get("penetrating", false)) or bool(definition.get("penetrating", false))
					var est_fx: Dictionary = effect.duplicate(true)
					if pen: est_fx["penetrating"] = true
					_estimate_hit(victim, state, estimate, _damage_value(source, victim, est_fx, card), bool(effect.get("pierce", false)) or pen)
				"STATUS":
					if not estimate["statuses"].has(effect["id"]): estimate["statuses"].append(effect["id"])
				"HEAL":
					state["hp"] = min(int(victim["max_hp"]), int(state["hp"]) + int(effect.get("amount", 0)) + int(card.get("upgrade", 0)) * 2)
					estimate["hp_after"] = state["hp"]
				"SHIELD", "BLOCK":
					var layer: String = "shield" if str(effect["kind"]) == "SHIELD" else "block"
					state[layer] += int(effect.get("amount", 0)) + int(card.get("upgrade", 0)) * 2
					estimate[layer + "_after"] = state[layer]
				"PULL":
					if state["row"] == "back" and not _has_status(victim, "bound"):
						state["row"] = "front"
						estimate["row_after"] = state["row"]
				"PUSH":
					if _has_status(victim, "bound"): continue
					if portal_ready:
						_estimate_impact(source, victim, state, estimate, roundi(int(source["attack"]) * 1.5))
						portal_ready = false
					if state["hp"] <= 0: continue
					if state["row"] == "front":
						state["row"] = "back"
						estimate["row_after"] = "back"
					var force: int = int(effect.get("force", 1)) * (2 if bool(effect.get("forceful", false)) else 1)
					if force > 1: _estimate_impact(source, victim, state, estimate, 4 * force)
					if _has_status(victim, "drop") and state["hp"] > 0 and not victim.get("boss", false):
						estimate["drop_chance"] = clampf(1.0 - float(state["hp"]) / float(victim["max_hp"]), 0.1, 0.9)
				"MOVE":
					if not _has_status(victim, "bound"):
						state["row"] = "back" if state["row"] == "front" else "front"
						estimate["row_after"] = state["row"]
	# Cartas de pacote (actions): estimar hit/status como no EntityRuntime.
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		if op in ["hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "hit_from_protecao", "hit_from_barrier", "roulette_hit"]:
			var card_amt: float = resolve_amount(action[1] if action.size() > 1 else 0, source)
			if op == "hit_per_impulse":
				card_amt *= float(_get_impulse(_acting()))
			if op == "hit_per_hand":
				card_amt *= float(acting_hand.size())
			if op == "hit_from_block":
				card_amt = float(source.get("block", 0))
			if op == "hit_from_protecao":
				card_amt = float(source.get("statuses", {}).get("protecao", {}).get("stacks", 0))
			if op == "hit_from_barrier":
				var _bh: Dictionary = source.get("statuses", {}).get("barrier", {})
				card_amt = float(_bh.get("barrier_hp", _bh.get("stacks", 0)))
			var damage_stat := str(definition.get("stat", "attack"))
			var offense: float = float(source.get("power" if damage_stat == "power" else "attack", 0))
			var penetrating: bool = bool(definition.get("penetrating", false))
			for victim in targets:
				var state2: Dictionary = defenses[victim["id"]]
				var estimate2: Dictionary = estimates[victim["id"]]
				if state2["hp"] <= 0:
					continue
				var multiplier: float = 0.5 if _has_status(source, "weak") else 1.0
				if _has_status(source, "strengthened"):
					multiplier *= 1.5
				if _has_status(victim, "vulnerable"):
					multiplier *= 1.5
				var defense: int = _defense_for_stat(victim, damage_stat, penetrating)
				var raw: int = maxi(1, roundi((card_amt + offense) * multiplier) - defense)
				_estimate_hit(victim, state2, estimate2, raw, penetrating)
		elif op == "status":
			var sid := str(action[1]) if action.size() > 1 else ""
			if sid == "":
				continue
			for victim in targets:
				var estimate3: Dictionary = estimates[victim["id"]]
				if not estimate3["statuses"].has(sid):
					estimate3["statuses"].append(sid)
		elif op == "self_status":
			var sid2 := str(action[1]) if action.size() > 1 else ""
			if sid2 != "" and not self_effects.has(sid2):
				self_effects.append(sid2)
		elif op == "push":
			for victim in targets:
				var state3: Dictionary = defenses[victim["id"]]
				var estimate4: Dictionary = estimates[victim["id"]]
				if state3["hp"] <= 0 or _has_status(victim, "bound"):
					continue
				if state3["row"] == "front":
					state3["row"] = "back"
					estimate4["row_after"] = "back"
		elif op == "pull":
			for victim in targets:
				var state_p: Dictionary = defenses[victim["id"]]
				var estimate_p: Dictionary = estimates[victim["id"]]
				if state_p["hp"] <= 0 or _has_status(victim, "bound"):
					continue
				if state_p["row"] == "back":
					state_p["row"] = "front"
					estimate_p["row_after"] = "front"
		elif op == "heal":
			var heal_amt: int = int(round(resolve_amount(action[1] if action.size() > 1 else 0, source)))
			for victim in targets:
				var state4: Dictionary = defenses[victim["id"]]
				var estimate5: Dictionary = estimates[victim["id"]]
				state4["hp"] = mini(int(victim["max_hp"]), int(state4["hp"]) + heal_amt)
				estimate5["hp_after"] = state4["hp"]
	var plays: int = 0 if bool(definition.get("free", false)) else int(definition.get("plays", 1))
	var side := _acting()
	var affordable: bool = _get_impulse(side) >= _cost(source, definition) and _get_plays(side) >= plays
	var plays_after := _get_plays(side) - plays
	for effect in effects:
		if effect.get("kind", "") == "CARD_PLAY": plays_after += int(effect.get("amount", 1))
	if plays > 0 and not random_target:
		var refund: bool = bool(definition.get("quick", false)) and estimates.has(target_id) and int(estimates[target_id]["hp_after"]) == 0
		for victim_id in estimates:
			if estimates[victim_id]["hp_after"] == 0 and _has_status(actor_by_id(int(victim_id)), "marked"): refund = true
		if refund: plays_after += 1
	return {"targets": estimates, "rows": rows, "random": random_target, "self_effects": self_effects, "other_effects": other_effects, "impulse_after": clampi(_get_impulse(side) - _cost(source, definition) + int(definition.get("gain", 0)), 0, int(rules["impulse_max"])), "plays_after": plays_after, "playable": affordable and (definition.get("target", "") != "CHAIN" or chain_ids.size() == int(definition.get("chain", 1))), "effects": effects}

func begin_enemy_phase() -> void:
	if phase != "PLAYER": return
	_posture_end_of_side("ALLY")
	_purge_ephemeral_hand("ALLY")
	_purge_dead_cards()
	request_end_turn = false
	phase = "ENEMY"
	enemy_card_plays = int(rules["card_plays"])
	enemy_redraws = int(rules["redraws"])
	enemy_moves = int(rules["moves"])
	if living("ENEMY").any(func(enemy): return bool(enemy.get("boss", false)) and int(enemy.get("phase", 1)) >= 2):
		enemy_card_plays += 1
	for enemy in living("ENEMY"):
		if _has_status(enemy, "next_turn_plays"):
			var e_bonus: int = maxi(1, _status_stacks(enemy, "next_turn_plays"))
			enemy_card_plays += e_bonus
			_ensure_statuses(enemy).erase("next_turn_plays")
		if _has_status(enemy, "neurally_enhanced"):
			var e_neu: int = maxi(1, _status_stacks(enemy, "neurally_enhanced"))
			enemy_card_plays += e_neu
			_ensure_statuses(enemy).erase("neurally_enhanced")
		match enemy.get("passive", ""):
			"vanguarda":
				if enemy["row"] == "front": _add_status(enemy, "barrier", 1, 2, int(enemy["id"]))
			"canalizar": enemy_impulse = min(int(rules["impulse_max"]), enemy_impulse + 1)
			"baluarte": _add_status(enemy, "barrier", 1, 2, int(enemy["id"]))
	if turn > 1:
		var has_strongest: bool = living("ENEMY").any(func(actor): return _has_status(actor, "strongest_there_is"))
		var extra: int = 1 if has_strongest else 0
		_draw_side("ENEMY", int(rules["turn_draw"]) + extra)
	for actor in living("ENEMY"):
		for payload in actor["pending"]:
			var owner_targets: Array[Dictionary] = [actor]
			_resolve(actor, owner_targets, {}, {"effects": payload})
		actor["pending"].clear()
	_log("Vez dos adversários.")
	changed.emit()

func peek_enemy_play() -> Dictionary:
	if phase != "ENEMY" or living("ALLY").is_empty():
		return {}
	if enemy_card_plays <= 0:
		if enemy_redraws > 0 and not enemy_hand.is_empty():
			var ri0 := _best_enemy_redraw_index()
			if ri0 >= 0:
				return {"kind": "redraw", "index": ri0}
		return {}
	var choice := _best_enemy_play()
	if choice.is_empty():
		if enemy_redraws > 0 and not enemy_hand.is_empty():
			var ri := _best_enemy_redraw_index()
			if ri >= 0:
				return {"kind": "redraw", "index": ri}
		return {}
	var card: Dictionary = enemy_hand[int(choice["index"])]
	return {
		"kind": "play",
		"index": int(choice["index"]),
		"target": int(choice["target"]),
		"chain": choice["chain"],
		"card": card.duplicate(true),
	}

func enemy_step() -> bool:
	var choice := peek_enemy_play()
	if choice.is_empty():
		return false
	if str(choice.get("kind", "")) == "redraw":
		return _redraw_side("ENEMY", int(choice.get("index", 0)))
	var card_id := str(choice.get("card", {}).get("id", ""))
	# Cartas ent_/ms_ resolvem actions via PackBridge (battle.play só lê effects).
	if card_id.begins_with("ent_") or card_id.begins_with("ms_"):
		var bridge: PackBridge = PackBridge.new()
		var mode := "entities" if card_id.begins_with("ent_") else "external"
		return bridge.play_card(self, mode, int(choice["index"]), int(choice["target"]), choice.get("chain", []))
	return play(int(choice["index"]), int(choice["target"]), choice.get("chain", []))

func finish_enemy_phase() -> void:
	if phase != "ENEMY": return
	_posture_end_of_side("ENEMY")
	_tick_statuses()
	if mission.get("objective", "") == "PROTECT" and not living("ENEMY").is_empty():
		protect_hp = max(0, protect_hp - max(1, living("ENEMY").size() * 2))
		_log("A sentinela sofreu pressão: %d Vida." % protect_hp)
	_check_end()
	if phase != "FINISHED": start_turn()
	changed.emit()

func end_player_turn() -> void:
	begin_enemy_phase()
	var guard := 0
	while phase == "ENEMY" and guard < 16:
		guard += 1
		if not enemy_step():
			finish_enemy_phase()

func _enemy_owner_locked(source: Dictionary) -> bool:
	if source.is_empty() or int(source.get("hp", 0)) <= 0:
		return true
	for locked in ["stun", "bind", "bound", "dazed", "banished", "finalized"]:
		if _has_status(source, locked):
			return true
	return false

func _best_enemy_redraw_index() -> int:
	# Prioriza limpar mão: mortos / indefinidas / caras demais.
	# Não queima cartas baratas se o único sobrevivente está só incapacitated (bind etc.) —
	# isso esvaziava Iniciativa e deixava a IA sem Manobra jogável nas rodadas seguintes.
	var any_unlocked := false
	for enemy in living("ENEMY"):
		if not _enemy_owner_locked(enemy):
			any_unlocked = true
			break
	for index in range(enemy_hand.size()):
		var card: Dictionary = enemy_hand[index]
		var source := actor_by_id(int(card.get("owner", -1)))
		var definition: Dictionary = Content.CARDS.get(str(card.get("id", "")), {})
		if source.is_empty() or int(source.get("hp", 0)) <= 0 or definition.is_empty():
			return index
		if _cost(source, definition) > _get_impulse("ENEMY"):
			return index
	if any_unlocked:
		for index in range(enemy_hand.size()):
			var card2: Dictionary = enemy_hand[index]
			var source2 := actor_by_id(int(card2.get("owner", -1)))
			if _enemy_owner_locked(source2):
				return index
		# Dono vivo e livre, mas sem alvo legal (alcance/conceal): tenta recompra.
		return 0 if not enemy_hand.is_empty() else -1
	return -1

func diagnose_enemy_hand() -> Array:
	# Para SessionReport: por que cada carta da mão inimiga não é jogável agora.
	var rows: Array = []
	for index in range(enemy_hand.size()):
		var card: Dictionary = enemy_hand[index]
		var source := actor_by_id(int(card.get("owner", -1)))
		var definition: Dictionary = Content.CARDS.get(str(card.get("id", "")), {})
		var reason := ""
		if definition.is_empty():
			reason = "no_definition"
		elif source.is_empty() or int(source.get("hp", 0)) <= 0:
			reason = "owner_dead"
		elif _enemy_owner_locked(source):
			reason = "owner_locked"
		elif _cost(source, definition) > _get_impulse("ENEMY"):
			reason = "unaffordable"
		else:
			var kind := str(definition.get("target", "ENEMY"))
			var candidates: Array[Dictionary] = []
			if kind == "SELF":
				candidates = [source]
			elif kind in ["ALLY", "ALL_ALLIES"]:
				candidates = living("ENEMY")
			elif kind == "DEAD_ALLY":
				candidates = dead_on_side("ENEMY")
			elif kind == "ANY_UNIT":
				candidates = living("ALLY") + living("ENEMY")
			else:
				candidates = living("ALLY")
			var any_ok := false
			for target in candidates:
				var chain: Array = []
				if kind == "CHAIN":
					var need := int(definition.get("chain", 1))
					for _hit in range(need):
						chain.append(int(target["id"]))
				var estimate: Dictionary = preview(index, int(target["id"]), chain)
				if not estimate.is_empty() and estimate.get("playable", false):
					any_ok = true
					break
			reason = "ok" if any_ok else "no_legal_target"
		rows.append({
			"index": index,
			"id": str(card.get("id", "")),
			"owner": int(card.get("owner", -1)),
			"target_kind": str(definition.get("target", "")),
			"reason": reason,
		})
	return rows

func _best_enemy_play() -> Dictionary:
	var best := {}
	var best_score := -0.001
	var force_instant := hand_has_playable_instantaneo("ENEMY")
	for index in range(enemy_hand.size()):
		var card: Dictionary = enemy_hand[index]
		var definition: Dictionary = Content.CARDS.get(card["id"], {})
		var source := actor_by_id(int(card["owner"]))
		if source.is_empty() or source.get("hp", 0) <= 0 or definition.is_empty(): continue
		if force_instant and not is_instant_card(card, definition):
			continue
		if _has_status(source, "stun") or _has_status(source, "bind") or _has_status(source, "bound") or _has_status(source, "dazed") or _has_status(source, "banished") or _has_status(source, "finalized"):
			continue
		var kind := str(definition.get("target", "ENEMY"))
		var candidates: Array[Dictionary] = []
		if kind == "SELF": candidates = [source]
		elif kind == "OWN_MINION":
			candidates = []
			for ally in living("ENEMY"):
				if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]):
					candidates.append(ally)
		elif kind in ["ALLY", "ALL_ALLIES"]: candidates = living("ENEMY")
		elif kind == "DEAD_ALLY": candidates = dead_on_side("ENEMY")
		elif kind == "ANY_UNIT": candidates = living("ALLY") + living("ENEMY")
		else: candidates = living("ALLY")
		if kind not in ["SELF", "ALLY", "ALL_ALLIES"] and definition.get("class", "") == "ATTACK":
			var forced: Array[Dictionary] = []
			for ally in living("ALLY"):
				if _has_status(ally, "taunt"): forced.append(ally)
			if not forced.is_empty(): candidates = forced
		for target in candidates:
			var chain: Array = []
			if kind == "CHAIN":
				var need := int(definition.get("chain", 1))
				for _hit in range(need): chain.append(int(target["id"]))
			var estimate: Dictionary = preview(index, int(target["id"]), chain)
			if estimate.is_empty() or not estimate.get("playable", false): continue
			var score := _score_enemy_preview(source, definition, estimate)
			if score > best_score:
				best_score = score
				best = {"index": index, "target": int(target["id"]), "chain": chain}
	return best

func _score_enemy_preview(source: Dictionary, definition: Dictionary, estimate: Dictionary) -> float:
	# Fase inimiga em grupo: escolhe até card_plays (3) melhores cartas legais por valor/economia.
	# Sem ordenação por Velocidade — só fase de grupo ENEMY.
	var score := 0.0
	for id in estimate["targets"]:
		var line: Dictionary = estimate["targets"][id]
		score += float(line["damage"])
		if int(line["hp_after"]) == 0: score += 18.0
		score += float(line["statuses"].size()) * 3.0
		if line["row_after"] != actor_by_id(int(id)).get("row", ""): score += 2.0
	score += float(estimate["self_effects"].size()) * 2.0
	# Economia de Iniciativa: favorece ganho e custo baixo relativo ao impacto.
	var cost := float(_cost(source, definition))
	var gain := float(definition.get("gain", 0))
	score += gain * 2.5 - cost * 1.5
	if cost <= _get_impulse("ENEMY") and cost > 0:
		score += 1.0
	if str(definition.get("target", "")) == "DEAD_ALLY": score += 22.0
	if definition.get("class", "") == "SKILL" and str(source.get("ai", "")) == "DEFENSIVO": score += 4.0
	if definition.get("class", "") == "ATTACK" and str(source.get("ai", "")) == "ASSASSINO": score += 3.0
	if definition.get("stat", "") == "power" and str(source.get("ai", "")) == "AGRESSIVO": score += 2.0
	return score

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
			var group_id := int(_status_state(actor, "soulbound").get("source", -1))
			if not linked_groups.has(group_id): linked_groups[group_id] = []
			linked_groups[group_id].append(actor)
	for actor in turn_actors:
		if actor["hp"] <= 0: continue
		if _has_status(actor, "chaos_field"): field_emitters.append(actor)
		for id in statuses_at_start[actor["id"]]:
			if not actor["statuses"].has(id): continue
			var state: Dictionary = actor["statuses"][id]
			match id:
				"poison", "burn", "corrupted":
					_take_damage(actor, actor, max(1, int(state["stacks"]) * 2), true, false)
					if id == "corrupted":
						for other in actors:
							if other["id"] != actor["id"] and other["hp"] > 0 and other["row"] == actor["row"]:
								_add_status(other, "corrupted", 2, 1, int(actor["id"]))
				"bleed":
					# Bleed X: causa X, depois stacks −1 (dano diminui a cada tick).
					var bleed_dmg: int = maxi(1, int(state.get("stacks", 1)))
					_take_damage(actor, actor, bleed_dmg, true, false)
					if actor["statuses"].has("bleed"):
						state = actor["statuses"]["bleed"]
						state["stacks"] = int(state.get("stacks", 1)) - 1
						if state["stacks"] <= 0:
							actor["statuses"].erase("bleed")
						else:
							state["duration"] = maxi(1, int(state.get("stacks", 1)))
							actor["statuses"]["bleed"] = state
				"regen": actor["hp"] = min(int(actor["max_hp"]), int(actor["hp"]) + int(state["stacks"]) * 3)
				"ravenous": state["stacks"] = min(5, int(state["stacks"]) + 1)
				"summoning":
					if state.get("armed", false):
						if actor["side"] == "ENEMY": spawn_enemy("fera")
						state["duration"] = 1
					else: state["armed"] = true
			if not actor["statuses"].has(id): continue
			if id in ["binary", "bloodlust"] and (int(actor.get("block", 0)) > 0 or _barrier_hp(actor) > 0): continue
			# Escuridão não tiqueia (acumula só por dano). Bleed já tratou stacks acima.
			if id == "escuridao":
				continue
			if id == "bleed":
				continue
			# Proteção / Resistente / Frágil: stacks −1 por rodada; some em 0.
			if id in ["protecao", "resistente", "fragil"]:
				state["stacks"] = int(state.get("stacks", 1)) - 1
				if state["stacks"] <= 0:
					actor["statuses"].erase(id)
				else:
					state["duration"] = max(1, int(state.get("duration", 1)))
					actor["statuses"][id] = state
				continue
			# Barreira: duração em rodadas; HP próprio (barrier_hp).
			if id == "barrier":
				state["duration"] = int(state.get("duration", 1)) - 1
				if state["duration"] <= 0 or int(state.get("barrier_hp", state.get("stacks", 0))) <= 0:
					actor["statuses"].erase("barrier")
				else:
					actor["statuses"][id] = state
				continue
			state["duration"] -= 1
			if state["duration"] <= 0: actor["statuses"].erase(id)
			else: actor["statuses"][id] = state
	# Tormenta agora é Instantâneo jogável (carta DESVANTAGEM); sem tick passivo.
	for actor in field_emitters:
		if actor["hp"] <= 0: continue
		for ally in actors:
			if ally["side"] == actor["side"] and ally["hp"] > 0 and ally["row"] == actor["row"]:
				_add_status(ally, "protecao", 1, 1, int(actor["id"]))
	for group_id in linked_groups:
		var linked: Array = linked_groups[group_id]
		if not linked.any(func(a): return a["hp"] > 0): continue
		var pool := 0
		for actor in linked: pool += int(actor["hp"])
		var shared: int = maxi(1, floori(float(pool) / float(linked.size())))
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
