extends RefCounted
class_name HotN3EntityRuntime

const Content = preload("res://game/Content.gd")
const Catalog = preload("res://addons/hotn3_entities/EntityCatalog.gd")
const CombatRules = preload("res://game/CombatRules.gd")
var catalog = Catalog.new()
var memory: Dictionary = {} # Scoped to the current battle instance; reset with install().


func _acting_side(battle: Variant) -> String:
	if battle.has_method("_acting"):
		return str(battle._acting())
	return "ALLY" if str(battle.get("phase", "PLAYER")) != "ENEMY" else "ENEMY"

func _acting_hand(battle: Variant) -> Array:
	var side := _acting_side(battle)
	if battle.has_method("_hand_of"):
		return battle._hand_of(side)
	return battle.hand

func _acting_deck(battle: Variant) -> Array:
	var side := _acting_side(battle)
	if battle.has_method("_deck_of"):
		return battle._deck_of(side)
	return battle.deck

func _acting_discard(battle: Variant) -> Array:
	var side := _acting_side(battle)
	if battle.has_method("_discard_of"):
		return battle._discard_of(side)
	return battle.discard

func _acting_exhausted(battle: Variant) -> Array:
	var side := _acting_side(battle)
	if battle.has_method("_exhausted_of"):
		return battle._exhausted_of(side)
	return battle.exhausted

func _get_ini(battle: Variant) -> int:
	var side := _acting_side(battle)
	if battle.has_method("_get_impulse"):
		return int(battle._get_impulse(side))
	return int(battle.impulse)

func _set_ini(battle: Variant, value: int) -> void:
	var side := _acting_side(battle)
	if battle.has_method("_set_impulse"):
		battle._set_impulse(side, value)
	else:
		battle.impulse = value


func _resolve_play_cost(battle: Variant, source: Dictionary, def: Dictionary, card: Dictionary) -> int:
	if card.has("cost_override"):
		return maxi(0, int(card.get("cost_override", 0)))
	if battle.has_method("resolve_card_cost"):
		return maxi(0, int(battle.resolve_card_cost(source, def, card)))
	if def.has("cost_by_stacks"):
		var cbs: Dictionary = def["cost_by_stacks"]
		var st := str(cbs.get("status", "escuridao"))
		var stacks: int = battle._status_stacks(source, st)
		var cap: int = int(cbs.get("max", cbs.get("cap", stacks)))
		return maxi(0, mini(stacks, cap))
	var raw: Variant = def.get("cost", 0)
	if typeof(raw) == TYPE_STRING:
		return maxi(0, int(round(battle.resolve_amount(raw, source))))
	return maxi(0, int(raw))


func _get_plays(battle: Variant) -> int:
	var side := _acting_side(battle)
	if battle.has_method("_get_plays"):
		return int(battle._get_plays(side))
	return int(battle.card_plays)

func _set_plays(battle: Variant, value: int) -> void:
	var side := _acting_side(battle)
	if battle.has_method("_set_plays"):
		battle._set_plays(side, value)
	else:
		battle.card_plays = value

func _add_plays(battle: Variant, amount: int) -> void:
	_set_plays(battle, _get_plays(battle) + amount)

func _friends(battle: Variant, source: Dictionary) -> Array:
	return battle.living(str(source.get("side", "ALLY")))

func _foes(battle: Variant, source: Dictionary) -> Array:
	var side := str(source.get("side", "ALLY"))
	return battle.living("ALLY" if side == "ENEMY" else "ENEMY")


func deploy(battle: Variant, mission_id: String, entity_ids: Array[String], chosen_decks: Dictionary = {}, seed_value: int = 0, mission_override: Dictionary = {}) -> bool:
	# Adapter HotNBattle. Aceita 1–3 heróis únicos (Arena incompleta OK; missões seguem 3).
	var n := entity_ids.size()
	if n < 1 or n > 3:
		return false
	var seen_ids: Dictionary = {}
	for id in entity_ids:
		if seen_ids.has(id):
			return false
		seen_ids[id] = true
		if catalog.hero(id).is_empty():
			return false
	# begin() cria slots aliados = tamanho da equipe + inimigos da missão.
	var pool_ph: Array[String] = ["guerreiro", "mago", "ladino"]
	var placeholders: Array[String] = []
	for i in range(n):
		placeholders.append(pool_ph[i])
	# auto_open=false: evita mão/log/passiva do placeholder Guerreiro/Mago/Ladino no HUD.
	battle.begin(mission_id, placeholders, {}, seed_value, {}, {}, false, mission_override)
	var slots: Array[Dictionary] = battle.living("ALLY")
	if slots.size() != n:
		return false
	battle.deck.clear()
	battle.hand.clear()
	battle.discard.clear()
	battle.exhausted.clear()
	battle.next_card_id = 0
	battle.impulse = 0
	var owner_map: Dictionary = {}
	var selection: Dictionary = {}
	for i in range(n):
		var id: String = entity_ids[i]
		var target: Dictionary = slots[i]
		var original_id := int(target["id"])
		var replacement: Dictionary = catalog.hero(id).duplicate(true)
		target.clear()
		target.merge(replacement)
		target["id"] = original_id
		target["archetype"] = id
		target["side"] = "ALLY"
		target["max_hp"] = int(target["hp"])
		if not target.has("escudo"):
			target["escudo"] = int(replacement.get("escudo", replacement.get("armor", 0)))
		target["archetype_stat"] = str(replacement.get("archetype", "Nenhum"))
		target["species"] = str(replacement.get("species", "Humano"))
		target["statuses"] = {}
		target["pending"] = []
		target["phase"] = 1
		owner_map[id] = original_id
		var kit: Array = chosen_decks.get(id, [])
		if kit.is_empty() or not deck_valid(id, kit):
			# Kit salvo obsoleto (IDs removidos no redesign) → Iniciais + Desvantagem.
			kit = kit_manobras(id)
			var desv := kit_desvantagem(id)
			if desv != "": kit.append(desv)
		selection[id] = apply_melhorada_replace(kit)
		# Alias aprimoramento → passive para hooks existentes
		var apr = replacement.get("aprimoramento", replacement.get("passive", ""))
		if typeof(apr) == TYPE_DICTIONARY:
			target["aprimoramento"] = apr
			target["passive"] = str(apr.get("id", target.get("passive", "")))
		else:
			target["aprimoramento"] = str(apr)
			if str(apr) != "": target["passive"] = str(apr)
		target["grupos"] = replacement.get("grupos", [])
		target["biografia"] = str(replacement.get("biografia", ""))
		target["desvantagem"] = str(replacement.get("desvantagem", ""))
		target["nero_plays"] = 0
		target["transformed"] = false
		target["base_name"] = str(replacement.get("name", target.get("name", "")))
		if str(replacement.get("desvantagem", "")) == "ent_dominika_seur_desvantagem_derretimento":
			target["passive_derretimento"] = "1"
	install(battle, owner_map, selection)
	append_combo_cards(battle, entity_ids, owner_map)
	# Cartas de roteiro entram antes da mão inicial para já poderem ser sorteadas
	# nesta batalha (inclui cartas extras de inimigos).
	battle.add_campaign_extra_cards(mission_override.get("extra_cards", []))
	battle._shuffle(battle.deck)
	for ally in slots:
		var pass_id := str(ally.get("passive", ""))
		if typeof(ally.get("aprimoramento", "")) == TYPE_DICTIONARY:
			pass_id = str(ally["aprimoramento"].get("id", pass_id))
		# Passivas de rodada (vanguarda/baluarte/canalizar) aplicam em start_turn com nome real.
		match pass_id:
			"gordura_100":
				pass  # imunidade via _add_status
			"naomi_despertar":
				ally["nero_plays"] = 0
				ally["transformed"] = false
	battle._draw_side("ALLY", int(battle.rules["opening_hand"]))
	battle._draw_side("ENEMY", int(battle.rules["opening_hand"]))
	battle._log("Missão: %s" % battle.mission["name"])
	battle.start_turn()
	for card in battle.hand: on_draw(battle, card)
	on_turn_start(battle)
	battle.changed.emit()
	return true

func deck_valid(entity_id: String, deck: Array) -> bool:
	var hero: Dictionary = catalog.hero(entity_id)
	if hero.is_empty(): return false
	# Kit flexível: todas as cartas possuídas (Iniciais + Evoluídas + Melhoradas + Desvantagem).
	# Melhoradas substituem a base (sem duplicar). Aceita legado size 5 (só Iniciais) ou 8.
	if deck.is_empty(): return false
	var pool: Array = hero.get("pool", [])
	var iniciais: Array = hero.get("iniciais", hero.get("cards", []))
	var allowed: Dictionary = {}
	for cid in pool: allowed[str(cid)] = true
	for cid in iniciais: allowed[str(cid)] = true
	for cid in hero.get("evoluidas", []): allowed[str(cid)] = true
	for cid in hero.get("melhoradas", []): allowed[str(cid)] = true
	var desv := str(hero.get("desvantagem", ""))
	if desv != "": allowed[desv] = true
	var seen: Dictionary = {}
	for card_id in deck:
		var cid := str(card_id)
		if seen.has(cid): return false
		seen[cid] = true
		if not allowed.has(cid): return false
	return true

func apply_melhorada_replace(card_ids: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for cid in card_ids:
		var id := str(cid)
		var def: Dictionary = catalog.definition(id)
		var base := str(def.get("melhorada_de", ""))
		if base != "":
			if seen.has(id): continue
			seen[id] = true
			out.append(id)
			continue
		var replaced := false
		for other in card_ids:
			var odef: Dictionary = catalog.definition(str(other))
			if str(odef.get("melhorada_de", "")) == id:
				replaced = true
				break
		if replaced: continue
		if seen.has(id): continue
		seen[id] = true
		out.append(id)
	return out

func kit_manobras(entity_id: String) -> Array:
	# Até 5 manobras iniciais (não DESVANTAGEM/POSTURA) + todas POSTURA das iniciais.
	# Posturas do kit (ex.: Eu Sou a Vítima!) devem entrar no baralho mesmo além das 5.
	var hero: Dictionary = catalog.hero(entity_id)
	var out: Array = []
	var postures: Array = []
	var src: Array = hero.get("iniciais", [])
	if src.is_empty():
		src = hero.get("cards", [])
	for card_id in src:
		var cid := str(card_id)
		if cid in out or cid in postures: continue
		var def: Dictionary = catalog.definition(cid)
		var cls := str(def.get("class", ""))
		if cls == "DESVANTAGEM": continue
		if cls == "POSTURA":
			postures.append(cid)
			continue
		if out.size() >= 5: continue
		out.append(cid)
	for pid in postures:
		out.append(pid)
	return out

func kit_desvantagem(entity_id: String) -> String:
	var hero: Dictionary = catalog.hero(entity_id)
	var d := str(hero.get("desvantagem", ""))
	if d != "" and not catalog.definition(d).is_empty(): return d
	for cid in hero.get("pool", []):
		var def: Dictionary = catalog.definition(str(cid))
		if str(def.get("class", "")) == "DESVANTAGEM": return str(cid)
	return ""

func shared_group(entity_ids: Array[String]) -> String:
	# Primeiro grupo compartilhado pelos 3 heróis, ou string vazia.
	if entity_ids.size() != 3: return ""
	var sets: Array = []
	for id in entity_ids:
		var g: Array = catalog.hero(id).get("grupos", [])
		var s: Dictionary = {}
		for name in g: s[str(name)] = true
		sets.append(s)
	for name in sets[0].keys():
		if sets[1].has(name) and sets[2].has(name):
			return str(name)
	return ""

func build_combat_deck_ids(entity_ids: Array[String], owned: Dictionary = {}) -> Dictionary:
	# Retorna {entity_id: [card_ids...]} = cartas possuídas (padrão: Iniciais + Desvantagem).
	# Melhoradas substituem a versão base. IDs ausentes do catálogo são descartados.
	var per: Dictionary = {}
	for id in entity_ids:
		var entries: Array = []
		if owned.has(id) and owned[id] is Array and not owned[id].is_empty():
			for cid in owned[id]:
				var sid := str(cid)
				if catalog.definition(sid).is_empty():
					continue
				entries.append(sid)
		if entries.is_empty() or not deck_valid(id, entries):
			entries = kit_manobras(id)
			var desv := kit_desvantagem(id)
			if desv != "": entries.append(desv)
		per[id] = apply_melhorada_replace(entries)
	return per

func combo_display_name(name_bits: PackedStringArray) -> String:
	# "Combo Alyssa e Dominika" / "Combo Alyssa, Dominika e Nero"
	if name_bits.size() == 2:
		return "Combo %s e %s" % [name_bits[0], name_bits[1]]
	if name_bits.size() >= 3:
		return "Combo %s, %s e %s" % [name_bits[0], name_bits[1], name_bits[2]]
	if name_bits.is_empty():
		return "Combo"
	return "Combo %s" % name_bits[0]

func _runtime_card_def(card: Dictionary) -> Dictionary:
	# Combos de grupo vivem em Content.CARDS (injetados no deploy), não no catálogo ent_.
	var cid := str(card.get("id", ""))
	var def: Dictionary = catalog.definition(cid)
	if def.is_empty() and Content.CARDS.has(cid):
		def = Content.CARDS[cid]
	if def.is_empty():
		return {}
	var out: Dictionary = def.duplicate(true)
	if not out.has("actions"):
		out["actions"] = []
	if card.has("combo_members") and not out.has("combo_members"):
		out["combo_members"] = card["combo_members"]
	if str(out.get("tier", "")) == "combo" or out.has("combo_members"):
		out["tier"] = "combo"
		out["class"] = "COMBO"
		out["ephemeral"] = true
		out["free"] = true
		out["cost"] = 0
	return out

func append_combo_cards(battle: Variant, entity_ids: Array[String], owner_map: Dictionary) -> int:
	# Se os 3 compartilham um grupo, adiciona 4 Combos Efêmeros no deck compartilhado (3 pares + 1 trio).
	# NÃO são cartas de kit por herói — nomes de duo/trio, grátis, INI 0, Impulso 1 ao jogar.
	var group := shared_group(entity_ids)
	if group == "": return 0
	var pairs: Array = [
		[entity_ids[0], entity_ids[1]],
		[entity_ids[0], entity_ids[2]],
		[entity_ids[1], entity_ids[2]],
		[entity_ids[0], entity_ids[1], entity_ids[2]],
	]
	var added := 0
	for members in pairs:
		var member_ids: Array = members
		var id_bits: PackedStringArray = []
		var name_bits: PackedStringArray = []
		for mid in member_ids:
			id_bits.append(str(mid))
			name_bits.append(str(catalog.hero(str(mid)).get("name", mid)))
		var combo_id := "combo_%s_%s" % [group.to_lower().replace(" ", "_"), "_".join(id_bits)]
		var label := combo_display_name(name_bits)
		# Sempre (re)registra a definição — design travado.
		Content.CARDS[combo_id] = {
			"name": label,
			"class": "COMBO",
			"tier": "combo",
			"ephemeral": true,
			"free": true,
			"target": "SELF",
			"cost": 0,
			"gain": 0,
			"plays": 0,
			"party_combo": true,
			"combo_members": member_ids.duplicate(),
			"combo_group": group,
			"actions": [],
			"effects": [],
			"text": "Grátis. Efêmera (descarta se não usada). Só jogável se todos os nomes estiverem vivos. Impulso 1: a próxima Manobra de cada envolvido neste round custa 0 INI.",
		}
		var owner_actor: int = int(owner_map.get(member_ids[0], -1))
		if owner_actor < 0: continue
		battle.next_card_id += 1
		battle.deck.append({
			"uid": battle.next_card_id,
			"id": combo_id,
			"owner": owner_actor,
			"class": "COMBO",
			"tier": "combo",
			"ephemeral": true,
			"free": true,
			"combo_members": member_ids.duplicate(),
			"upgrade": 0,
			"external_pack": true,
			"party_combo": true,
		})
		added += 1
	if added > 0:
		battle._log("Grupo compartilhado '%s': +%d Manobras Combo no deck." % [group, added])
	return added
func end_player_turn(battle: Variant) -> void:
	var prior: Dictionary = {}
	for card in battle.hand: prior[int(card["uid"])] = true
	battle.end_player_turn()
	if battle.phase != "PLAYER": return
	for card in battle.hand:
		if not prior.has(int(card["uid"])): on_draw(battle, card)
	on_turn_start(battle)
	battle.changed.emit()

func redraw_card(battle: Variant, hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= battle.hand.size(): return false
	var before: Dictionary = {}
	for card in battle.hand: before[int(card["uid"])] = true
	var old: Dictionary = battle.hand[hand_index]
	if battle.phase != "PLAYER" or battle.redraws <= 0: return false
	var old_def: Dictionary = catalog.definition(str(old.get("id", "")))
	if battle.is_instant_card(old, old_def): return false
	on_redraw(battle, old)
	if not battle.redraw(hand_index): return false
	for card in battle.hand:
		if not before.has(int(card["uid"])): on_draw(battle, card)
	return true

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
			var cdef: Dictionary = catalog.definition(str(id))
			var row := {"uid": battle.next_card_id, "id": str(id), "owner": actor_id, "class": cdef.get("class", ""), "upgrade": 0, "external_pack": true}
			if str(cdef.get("class", "")) == "DESVANTAGEM" or bool(cdef.get("instant", false)):
				row["instant"] = true
			battle.deck.append(row)
			installed += 1
	battle._shuffle(battle.deck)
	return installed

func _resolve_card_def(battle: Variant, source: Dictionary, def: Dictionary) -> Dictionary:
	# Aplica overlay Naomi se o conjurador transformou.
	var out: Dictionary = def.duplicate(true)
	if bool(source.get("transformed", false)) and def.has("naomi_actions"):
		out["actions"] = def["naomi_actions"].duplicate(true)
		if def.has("naomi_name"):
			out["name"] = str(def["naomi_name"])
	return out

func _try_nero_transform(battle: Variant, source: Dictionary, card_id: String) -> void:
	var apr = source.get("aprimoramento", source.get("passive", ""))
	var apr_id := str(apr.get("id", "")) if typeof(apr) == TYPE_DICTIONARY else str(apr)
	if apr_id != "naomi_despertar" and str(source.get("passive", "")) != "naomi_despertar":
		return
	if bool(source.get("transformed", false)):
		return
	if not str(card_id).begins_with("ent_nero_"):
		return
	source["nero_plays"] = int(source.get("nero_plays", 0)) + 1
	if int(source["nero_plays"]) < 5:
		battle._log("%s: Despertar %d/5." % [source.get("name", "Nero"), int(source["nero_plays"])])
		return
	source["transformed"] = true
	var hero: Dictionary = catalog.hero(str(source.get("archetype", "ent_nero")))
	var base_sprite := str(source.get("sprite", ""))
	var base_portrait := str(source.get("portrait", ""))
	source["name"] = str(hero.get("transform_name", "Naomi"))
	if hero.has("transform_sprite"):
		source["sprite"] = str(hero["transform_sprite"])
	if hero.has("transform_portrait"):
		source["portrait"] = str(hero["transform_portrait"])
	var reused_art := str(source.get("sprite", "")) == base_sprite and str(source.get("portrait", "")) == base_portrait
	if reused_art or str(source.get("sprite", "")) == "res://assets/cast/ent_nero_sprite.png":
		battle._log("%s despertou como %s! (arte Naomi: reutilizando Nero por enquanto)" % [str(source.get("base_name", "Nero")), source["name"]])
	else:
		battle._log("%s despertou como %s!" % [str(source.get("base_name", "Nero")), source["name"]])
	if battle.has_signal("visual"):
		battle.visual.emit("transform", int(source["id"]), int(source["id"]), 0)
	battle.changed.emit()

func play_block_reason(battle: Variant, hand_index: int, target_id: int = -1, chain_ids: Array = []) -> String:
	# Motivo em pt-BR quando a Manobra não pode ser usada.
	if battle == null or hand_index < 0 or hand_index >= battle.hand.size():
		return "Carta inválida."
	var card: Dictionary = battle.hand[hand_index]
	var cid := str(card.get("id", ""))
	var def: Dictionary = _runtime_card_def(card)
	if def.is_empty():
		# Itens / ms_ / combo runtime não vivem no catálogo ent_.
		if cid.begins_with("ent_"):
			return "Carta desconhecida."
		return ""
	var source: Dictionary = battle.actor_by_id(int(card["owner"]))
	if not source.is_empty():
		def = _resolve_card_def(battle, source, def)
	if source.is_empty() or int(source.get("hp", 0)) <= 0:
		return "O herói desta carta está fora de combate."
	if battle.phase != "PLAYER":
		return "Não é a fase do jogador."
	for locked in ["stun", "bind", "bound", "banished", "finalized"]:
		if battle._has_status(source, locked) and not bool(def.get("play_while_disabled", false)) and not (locked in ["bind", "bound"] and bool(def.get("reach", false))):
			return "Você não pode usar Manobras enquanto estiver incapacitado (%s)." % locked
	var warmup: int = int(def.get("warmup", 0))
	if _has_action(def, "warmup"):
		warmup = int(_action(def, "warmup")[1])
	if warmup > 0:
		card["warmup"] = warmup
		if not battle.card_warmup_ready(card, def):
			return "Esta Manobra ainda está em aquecimento."
	var cost: int = _resolve_play_cost(battle, source, def, card)
	if str(def.get("tier", card.get("tier", ""))) != "combo" and str(def.get("class", card.get("class", ""))) != "DESVANTAGEM":
		if battle.get("combo_zero_owners") and int(battle.combo_zero_owners.get(int(source.get("id", -1)), 0)) > 0:
			cost = 0
	if cost > 0:
		cost = CombatRules.initiative_cost(cost, battle._status_stacks(source, "fast"), battle._status_stacks(source, "slow"))
	cost = maxi(0, cost)
	var plays: int = 0 if bool(def.get("free", false)) or _has_action(def, "free") else 1
	if battle.has_method("must_play_instantaneo_first") and battle.must_play_instantaneo_first(card, def, "ALLY"):
		return "Há Instantâneo jogável — jogue um Instantâneo antes de outras cartas."
	if battle.impulse < cost:
		return "Você precisa de %d Iniciativa para usar esta Manobra." % cost
	if battle.card_plays < plays:
		return "Você não tem jogadas de carta restantes neste turno."
	# Requisitos de status próprio (ex.: Escuridão)
	for a in def.get("actions", []):
		if typeof(a) != TYPE_ARRAY or a.is_empty(): continue
		if str(a[0]) == "requires_self_status":
			var need_st := str(a[1] if a.size() > 1 else "?")
			var need_default: int = int(CombatRules.formula_value("Requerimentos", "requires_self_status", "default_stacks", 1))
			var need_n: int = int(round(battle.resolve_amount(a[2] if a.size() > 2 else need_default, source)))
			var have: int = battle._status_stacks(source, need_st)
			if have < need_n:
				var pretty := need_st.capitalize()
				if need_st == "escuridao": pretty = "Escuridão"
				return "Requer: %s %d" % [pretty, need_n]
		elif str(a[0]) == "requires_alone":
			if battle.living("ALLY").size() > 1:
				return "Requer: estar sozinho no time."
		elif str(a[0]) == "requires_own_minion_front":
			var okm := false
			for ally in battle.living("ALLY"):
				if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]) and str(ally.get("row", "")) == "front":
					okm = true
					break
			if not okm:
				return "Requer: um lacaio seu na frente."
	# Alcance / fileira
	if target_id >= 0:
		var target: Dictionary = battle.actor_by_id(target_id)
		if not target.is_empty() and target.get("side", "") != source.get("side", ""):
			if not battle.can_reach(source, target, def):
				if not bool(def.get("reach", false)) and str(source.get("row", "")) == "back":
					return "Você não pode atacar sem Alcance da linha de trás."
				if not bool(def.get("reach", false)) and str(target.get("row", "")) == "back":
					return "Você não pode atingir a retaguarda sem Alcance."
				return "Alvo fora de alcance."
	var combo_members: Array = def.get("combo_members", card.get("combo_members", []))
	if str(def.get("tier", card.get("tier", ""))) == "combo" or not combo_members.is_empty():
		for mid in combo_members:
			var alive := false
			for ally in battle.living("ALLY"):
				if str(ally.get("archetype", "")) == str(mid):
					alive = true
					break
			if not alive:
				return "Combo exige que todos os membros estejam vivos."
	return ""

func play(battle: Variant, hand_index: int, target_id: int, chain_ids: Array = []) -> bool:
	# Suporta fase PLAYER e ENEMY (IA inimiga com cartas ent_).
	if str(battle.phase) not in ["PLAYER", "ENEMY"]:
		return false
	var acting_hand: Array = _acting_hand(battle)
	if hand_index < 0 or hand_index >= acting_hand.size(): return false
	var card: Dictionary = acting_hand[hand_index]
	var prior_hand: Dictionary = {}
	for held in acting_hand: prior_hand[int(held["uid"])] = true
	var def: Dictionary = _runtime_card_def(card)
	# Reanimar / ownerless Content (effects, sem actions de pacote) → BattleState.play.
	var cid0 := str(card.get("id", ""))
	if def.is_empty() or cid0 == "reanimar" or (bool(def.get("ownerless", false)) and not cid0.begins_with("ent_") and not cid0.begins_with("ms_") and not cid0.begins_with("manobra_")):
		return battle.play(hand_index, target_id, chain_ids)
	var source: Dictionary = {}
	if battle.has_method("resolve_play_source"):
		source = battle.resolve_play_source(card, _acting_side(battle))
	else:
		source = battle.actor_by_id(int(card.get("owner", -1)))
	var target: Dictionary = battle.actor_by_id(target_id)
	if source.is_empty() or target.is_empty(): return false
	if str(source.get("side", "")) != _acting_side(battle): return false
	def = _resolve_card_def(battle, source, def)
	if battle.has_method("confused_target"):
		target = battle.confused_target(source, target, def)
	# Instantâneo jogável obriga jogar Instantâneo antes de qualquer outra carta.
	if battle.has_method("must_play_instantaneo_first") and battle.must_play_instantaneo_first(card, def, _acting_side(battle)):
		battle._log("Há Instantâneo jogável — jogue-o antes de outras cartas.")
		return false
	var ownerless := bool(def.get("ownerless", false)) or bool(card.get("ownerless", false)) or cid0 == "reanimar" or bool(def.get("item", false))
	if int(source.get("hp", 0)) <= 0 and not _has_action(def, "revive_self") and not ownerless: return false
	# Itens com dono explícito: dono precisa estar vivo / no time do conjurador.
	if bool(def.get("item", false)) and def.has("owner_hero"):
		var need := str(def["owner_hero"])
		var ok := false
		for ally in _friends(battle, source):
			if str(ally.get("archetype", "")) == need:
				ok = true; break
		if not ok: return false
	var wants_dead := str(def.get("target", "")) == "DEAD_ALLY" or _has_action(def, "revive_self") or _has_action(def, "revive_ally")
	if int(target.get("hp", 0)) <= 0 and not wants_dead: return false
	if not bool(def.get("play_while_disabled", false)):
		for locked in ["stun", "bind", "bound", "banished", "finalized"]:
			if battle._has_status(source, locked) and not (locked in ["bind", "bound"] and bool(def.get("reach", false))): return false
	if battle._has_status(source, "taunted") and not _is_damage_card(def): return false
	var warmup: int = int(def.get("warmup", 0))
	if _has_action(def, "warmup"): warmup = int(_action(def, "warmup")[1])
	if warmup > 0:
		card["warmup"] = warmup
		if not battle.card_warmup_ready(card, def): return false
	var cost: int = _resolve_play_cost(battle, source, def, card)
	# Custo gasta Iniciativa (recurso compartilhado do turno) — não existe pool de "Poder".
	var used_impulso := false
	if str(def.get("tier", card.get("tier", ""))) != "combo" and str(card.get("class", "")) != "DESVANTAGEM":
		if battle.get("combo_zero_owners") and int(battle.combo_zero_owners.get(int(source.get("id", -1)), 0)) > 0:
			cost = 0
			used_impulso = true
	if cost > 0:
		cost = CombatRules.initiative_cost(cost, battle._status_stacks(source, "fast"), battle._status_stacks(source, "slow"))
		if _has_action(def, "cost_down_en_fuego"): cost -= int(_counter(source, "en_fuego"))
	cost = maxi(0, cost)
	# Combo: exige todos os membros vivos
	var combo_members: Array = def.get("combo_members", card.get("combo_members", []))
	if str(def.get("tier", card.get("tier", ""))) == "combo" or not combo_members.is_empty():
		for mid in combo_members:
			var alive := false
			for ally in _friends(battle, source):
				if str(ally.get("archetype", "")) == str(mid):
					alive = true
					break
			if not alive: return false
	var owner_free: bool = def.get("owner") == "spider_man" and _counter(source, "free_owner") > 0
	var is_instant: bool = bool(def.get("instant", false)) or _has_action(def, "instant")
	if is_instant: card["instant"] = true
	var is_party_combo: bool = str(def.get("tier", card.get("tier", ""))) == "combo" or not combo_members.is_empty()
	var plays: int = 0 if bool(def.get("free", false)) or _has_action(def, "free") or owner_free or is_party_combo else 1
	if _get_ini(battle) < cost or _get_plays(battle) < plays: return false
	var resolved_def: Dictionary = def.duplicate(true)
	# Escala de alvo por stacks (ex.: Relâmpago E4/E5/E6+).
	if def.has("target_by_stacks"):
		var tbs: Dictionary = def["target_by_stacks"]
		var st_id := str(tbs.get("status", "escuridao"))
		var st_n: int = battle._status_stacks(source, st_id)
		var chosen := str(resolved_def.get("target", "ENEMY"))
		for row in tbs.get("thresholds", []):
			if typeof(row) != TYPE_ARRAY or row.size() < 2: continue
			if st_n >= int(row[0]):
				chosen = str(row[1])
				break
		resolved_def["target"] = chosen
	if def.get("target") == "CHAIN" or resolved_def.get("target") == "CHAIN":
		resolved_def["chain"] = int(def.get("chain", 1)) + int(card.get("next_chain", 0))
		if _has_action(def, "chain"):
			var ca_chain: Array = _action(def, "chain")
			if ca_chain.size() > 1:
				resolved_def["chain"] = maxi(1, int(round(battle.resolve_amount(ca_chain[1], source)))) + int(card.get("next_chain", 0))
		if _has_action(def, "grow_chain"): resolved_def["chain"] += int(_counter(source, str(_action(def, "grow_chain")[1])))
		if _has_action(def, "chain_hand_owner"):
			resolved_def["chain"] = maxi(1, _acting_hand(battle).filter(func(c): return c.get("owner") == source["id"]).size())
	for a in def["actions"]:
		if a[0] == "requires_status":
			var need_st := str(a[1])
			var need_default: int = int(CombatRules.formula_value("Requerimentos", "status", "default_stacks", 1))
			var need_n: int = int(round(battle.resolve_amount(a[2] if a.size() > 2 else need_default, source)))
			if battle._status_stacks(target, need_st) < need_n: return false
		if a[0] == "requires_self_status":
			var need_st2 := str(a[1])
			var need_default2: int = int(CombatRules.formula_value("Requerimentos", "requires_self_status", "default_stacks", 1))
			var need_n2: int = int(round(battle.resolve_amount(a[2] if a.size() > 2 else need_default2, source)))
			if battle._status_stacks(source, need_st2) < need_n2: return false
	var targets: Array[Dictionary] = []
	if _has_action(def, "revive_self"):
		targets.append(source)
	elif _has_action(def, "revive_ally") and target.get("side", "") == source.get("side", ""):
		targets.append(target)
	else:
		targets = battle._targets(source, target, resolved_def, chain_ids)
	if str(resolved_def.get("target", def.get("target", ""))) == "CHAIN":
		var chain_count := int(resolved_def.get("chain", def.get("chain", 1)))
		if _has_action(def, "chain_hand_owner"):
			chain_count = maxi(1, _acting_hand(battle).filter(func(c): return c.get("owner") == source["id"]).size())
		if chain_ids.size() != chain_count or targets.size() != chain_count: return false
	if targets.is_empty(): return false
	var spent_impulse: int = _get_ini(battle)
	acting_hand.remove_at(hand_index)
	_set_plays(battle, _get_plays(battle) - plays)
	if owner_free: _consume(source, "free_owner")
	_set_ini(battle, clampi(spent_impulse - cost + int(def.get("gain", 0)) * (2 if battle._has_status(source, "double_gain") else 1), 0, int(battle.rules["impulse_max"])))
	battle._log("[b]%s[/b] jogou [b]%s[/b] em [b]%s[/b]." % [source.get("name", "?"), def.get("name", card.get("id", "?")), target.get("name", "?")])
	if battle.has_signal("visual"):
		battle.visual.emit("cast", int(source["id"]), int(target["id"]), 0)
	# Combo jogado → Impulso 1 nos membros (próxima Manobra de cada um custa 0 INI neste round)
	if str(def.get("tier", card.get("tier", ""))) == "combo" or not combo_members.is_empty():
		var actor_ids: Array = []
		for mid in combo_members:
			for ally in _friends(battle, source):
				if str(ally.get("archetype", "")) == str(mid):
					actor_ids.append(int(ally["id"]))
		if battle.has_method("apply_combo_zero_cost"):
			battle.apply_combo_zero_cost(actor_ids, 1)
		else:
			for aid in actor_ids:
				var sid := int(aid)
				battle.combo_zero_owners[sid] = int(battle.combo_zero_owners.get(sid, 0)) + 1
	elif used_impulso:
		var sid2 := int(source.get("id", -1))
		var left: int = int(battle.combo_zero_owners.get(sid2, 0)) - 1
		if left <= 0:
			battle.combo_zero_owners.erase(sid2)
		else:
			battle.combo_zero_owners[sid2] = left
	# Ferido: dano ao jogar carta (igual BattleState.play).
	if battle._has_status(source, "wounded"):
		battle._take_damage(source, source, CombatRules.wounded_damage(int(source.get("max_hp", 1)), battle._status_stacks(source, "wounded")), true, false)
	if battle.is_area_attack(resolved_def):
		var affectable_targets: Array[Dictionary] = []
		for victim in targets:
			if not battle._has_status(victim, "flying"):
				affectable_targets.append(victim)
		targets = affectable_targets
	var kos: Array[int] = []
	var last_hit := 0
	var acted: Array[String] = []
	if int(source.get("hp", 0)) <= 0:
		_acting_discard(battle).append(card)
		battle.played_cards += 1
		battle._after_card_play()
		battle._check_end()
		battle.changed.emit()
		return true
	# Antes do resolve: play_stamp de status (Confusão) casa com _after_card_play.
	battle.played_cards += 1
	for a in def["actions"]:
		var op: String = a[0]
		if acted.has(op) and op in ["quick", "free", "exhaust", "final"]: continue
		acted.append(op)
		match op:
			"hit", "hit_per_impulse", "hit_per_hand", "hit_from_protecao", "hit_from_barrier", "roulette_hit":
				# Dano aditivo: Carta + Impacto − Armadura  OU  Carta + Poder − Escudo (+ mods).
				var card_amt: float = battle.resolve_amount(a[1] if a.size() > 1 else 0, source)
				if op == "hit_per_impulse": card_amt *= float(spent_impulse)
				if op == "hit_per_hand": card_amt *= float(_acting_hand(battle).size())
				if op == "hit_from_protecao":
					card_amt = float(source.get("statuses", {}).get("protecao", {}).get("stacks", 0))
				if op == "hit_from_barrier":
					var _bh: Dictionary = source.get("statuses", {}).get("barrier", {})
					card_amt = float(_bh.get("barrier_hp", _bh.get("stacks", 0)))
				if op == "roulette_hit": card_amt = float(card.get("roulette_factor", a[battle.rng.randi_range(1, a.size() - 1)]))
				for victim in targets:
					var before_hp := int(victim["hp"])
					var bonus := _bonus(battle, source, victim, def, card)
					var base: float = card_amt + float(_offense(source, def)) + bonus
					var multiplier: float = CombatRules.damage_multiplier(battle._status_stacks(source, "weak"), battle._status_stacks(source, "strengthened"), battle._has_status(source, "binary") or battle._has_status(source, "overpowered"), bool(card.get("critical", false)), _counter(source, "ravenous"))
					if battle._has_status(victim, "vulnerable"): multiplier *= 1.5
					# Impacto − Armadura; Poder − Escudo (atributo). Mods % já em multiplier.
					var damage_stat := str(def.get("stat", "attack"))
					var penetrating: bool = bool(def.get("penetrating", false)) or _has_action(def, "penetrating")
					var _hard: int = int(victim.get("statuses", {}).get("resistente", {}).get("stacks", 0)) if battle._has_status(victim, "resistente") else 0
					var _frail: int = int(victim.get("statuses", {}).get("fragil", {}).get("stacks", 0)) if battle._has_status(victim, "fragil") else 0
					var armor_stacks: int = int(victim.get("statuses", {}).get("armor", {}).get("stacks", 0)) if damage_stat != "power" else 0
					var defense: int = CombatRules.defense(int(victim.get("escudo", 0)) if damage_stat == "power" else int(victim.get("armor", 0)), armor_stacks, _hard, _frail, penetrating)
					# Espécie (±25% tipicamente via vs_species na carta).
					var vs: Dictionary = def.get("vs_species", {})
					var sp := str(victim.get("species", ""))
					if sp != "" and vs.has(sp):
						var vs_mod: float = float(vs[sp])
						if vs_mod < 0.0 and battle._has_status(source, "atento"):
							vs_mod = 0.0
						multiplier *= 1.0 + vs_mod
					# Arquétipo (DESLIGADO por padrão).
					if bool(Content.RULES.get("archetype_matchup", false)):
						multiplier *= _archetype_mult(source, victim)
					last_hit = maxi(1, roundi(base * multiplier) - defense)
					var keep_stun: bool = bool(def.get("lethargic", false)) or _has_action(def, "lethargic")
					var formula := {
						"card_amt": card_amt,
						"offense": float(_offense(source, def)),
						"bonus": bonus,
						"base": base,
						"multiplier": multiplier,
						"defense": defense,
						"stat": damage_stat,
						"penetrating": penetrating,
						"final": last_hit,
					}
					if battle._take_damage(source, victim, last_hit, penetrating, true, false, battle.is_area_target(str(def.get("target", ""))), not bool(def.get("reach", false)), _is_damage_card(def), true, not keep_stun, formula):
						if not kos.has(victim["id"]): kos.append(victim["id"])
					if _has_action(def, "barrier_from_hit") and last_hit > 0:
						battle._add_status(source, "barrier", 1, last_hit, int(source["id"]))
					if _has_action(def, "lifesteal"):
						source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + maxi(0, before_hp - int(victim["hp"])))
					if _has_action(def, "drain") or bool(def.get("drain", false)):
						var drain_amt: int = CombatRules.drain_heal(last_hit)
						if drain_amt > 0: source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + drain_amt)
					if _has_action(def, "recoil") or bool(def.get("recoil", false)):
						var recoil_amt: int = CombatRules.recoil_damage(last_hit)
						if recoil_amt > 0: battle._take_damage(source, source, recoil_amt, true, false)
			"choice":
				for victim in targets:
					if victim.get("side") == source.get("side"):
						if a[3] == "cure": battle._cleanse(victim)
						else: victim["hp"] = mini(int(victim["max_hp"]), int(victim["hp"]) + roundi(float(source["attack"]) * float(a[4])))
					else:
						if battle._take_damage(source, victim, maxi(1, roundi(float(source["attack"]) + float(a[2]))), false, true, false, false, false, true, true): kos.append(int(victim["id"]))
			"status", "self_status":
				for victim in ([source] if op == "self_status" else targets):
					var stacks := int(round(battle.resolve_amount(a[2] if a.size() > 2 else 1, source)))
					stacks = maxi(1, stacks)
					var st_id := str(a[1])
					battle._add_status(victim, st_id, maxi(1, stacks), stacks, int(source["id"]))
					if st_id == "all_together_now": battle.team_ko_charges = stacks
					if st_id == "counter":
						var st: Dictionary = victim["statuses"].get("counter", {})
						st["mode"] = str(def.get("counter_mode", "default"))
						var cefx = def.get("counter_effects", [])
						if typeof(cefx) == TYPE_ARRAY and not cefx.is_empty():
							st["effects"] = cefx.duplicate(true)
						elif _has_action(def, "counter_effects"):
							# ["counter_effects", "hit", "0", "status", "wounded", "1"] → parse pairs
							var raw: Array = _action(def, "counter_effects")
							var parsed: Array = []
							var i := 1
							while i < raw.size():
								var opx := str(raw[i])
								if opx == "hit" and i + 1 < raw.size():
									parsed.append(["hit", str(raw[i+1])]); i += 2
								elif opx == "status" and i + 2 < raw.size():
									parsed.append(["status", str(raw[i+1]), str(raw[i+2])]); i += 3
								else:
									i += 1
							st["effects"] = parsed
						st["from_card"] = str(def.get("id", card.get("id", "")))
						victim["statuses"]["counter"] = st
			"barreira_hp":
				# ["barreira_hp", rounds, fraction_of_max_hp]
				var br2: int = int(a[1]) if a.size() > 1 else 1
				var frac: float = float(a[2]) if a.size() > 2 else 0.3
				for victim in targets:
					var bamt2: int = maxi(1, roundi(float(victim["max_hp"]) * frac))
					battle._add_status(victim, "barrier", maxi(1, br2), bamt2, int(source["id"]))
			"heal", "full_heal", "heal_all":
				var healed: Array = _friends(battle, source) if op == "heal_all" else targets
				var any_healed := false
				for victim in healed:
					# Cura X = 10% × X da Vida máxima do alvo.
					var before_h := int(victim["hp"])
					var heal_x: int = int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source)))
					var heal_amt: int = roundi(float(victim["max_hp"]) * 0.10 * heal_x)
					victim["hp"] = int(victim["max_hp"]) if op == "full_heal" else mini(int(victim["max_hp"]), int(victim["hp"]) + heal_amt)
					if int(victim["hp"]) > before_h:
						any_healed = true
						if battle.has_signal("visual"):
							battle.visual.emit("heal", int(source["id"]), int(victim["id"]), int(victim["hp"]) - before_h)
				if any_healed and battle.has_method("try_posture_trigger"):
					battle.try_posture_trigger(source, "curador")
			"hit_flat":
				# Dano absoluto (ex.: Tormenta 10×E), penetrante ambiental — sem ATK/Poder.
				var flat_amt: int = maxi(0, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 0, source))))
				for victim in targets:
					if battle._take_damage(source, victim, flat_amt, true, false, true, battle.is_area_target(str(def.get("target", ""))), false, true, true):
						if not kos.has(victim["id"]): kos.append(victim["id"])
			"hit_enemy_front":
				var flat2: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 0, source))))
				var opp := "ENEMY" if source.get("side", "") == "ALLY" else "ALLY"
				for foe in battle.living(opp):
					if str(foe.get("row", "")) != "front":
						continue
					var bonus2 := _bonus(battle, source, foe, def, card)
					var base2: float = float(flat2) + float(_offense(source, def)) + bonus2
					var dmg2: int = maxi(1, roundi(base2) - int(foe.get("armor", 0)))
					if battle._take_damage(source, foe, dmg2, false, true, false, true, true, true, true):
						if not kos.has(foe["id"]): kos.append(foe["id"])
			"heal_own_minions":
				var ham: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				var ham_any := false
				for ally in _friends(battle, source):
					if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]):
						var bh2 := int(ally["hp"])
						ally["hp"] = mini(int(ally["max_hp"]), int(ally["hp"]) + ham)
						if int(ally["hp"]) > bh2:
							ham_any = true
				if ham_any and battle.has_method("try_posture_trigger"):
					battle.try_posture_trigger(source, "curador")
			"sacrifice_minion":
				for victim in targets:
					if bool(victim.get("is_summon", false)) or bool(victim.get("minion", false)):
						victim["hp"] = 0
						if battle.has_method("dismiss_minion"):
							battle.dismiss_minion(victim, false)
						elif battle.has_method("purge_owner_cards"):
							battle.purge_owner_cards(int(victim["id"]))
						if not kos.has(int(victim["id"])): kos.append(int(victim["id"]))
			"self_damage_hp":
				var frac: float = float(a[1]) if a.size() > 1 else 1.0
				var raw_sd: int = maxi(1, roundi(float(source.get("max_hp", 1)) * frac))
				battle._take_damage(source, source, raw_sd, true, false)
			"counter_effects":
				pass  # metadata; aplicada ao conceder counter
			"collision", "requires_alone", "requires_own_minion_front":
				pass
			"cure":
				for victim in targets: battle._cleanse(victim)
			"push", "pull", "move_target":
				for victim in targets:
					if battle.has_method("reposition"):
						kos.append_array(battle.reposition(source, victim, "move" if op == "move_target" else op, _has_action(def, "collision")))
			"draw", "draw_owner", "draw_owner_to", "draw_heroic", "draw_attack_heroic":
				_draw_filtered(battle, source, op, int(a[1]))
			"draw_own":
				battle.draw_own(int(source["id"]), int(a[1]))
				for held in _acting_hand(battle):
					if not prior_hand.has(int(held["uid"])): on_draw(battle, held)
			"recover_own":
				battle.recover_from_discard(int(source["id"]), int(a[1]) if a.size() > 1 else 1, true)
				for held in _acting_hand(battle):
					if not prior_hand.has(int(held["uid"])): on_draw(battle, held)
			"recover":
				# UI: GameRoot escolhe no descarte; fallback automático se pending não for consumido.
				battle.recover_from_discard(-1, int(a[1]) if a.size() > 1 else 1, false)
			"discard", "discard_random":
				var drop_n: int = int(a[1]) if a.size() > 1 else 1
				battle.discard_from_hand(drop_n, true)
			"discard_hand":
				var _dh := _acting_hand(battle)
				var _dd := _acting_discard(battle)
				for held in _dh: _dd.append(held)
				_dh.clear()
			"actions":
				battle.grant_next_turn_plays(source, int(a[1]) if a.size() > 1 else 1)
			"self_damage", "self_damage_hp":
				var amount := roundi(float(source["attack"]) * float(a[1])) if op == "self_damage" else roundi(float(source["max_hp"]) * float(a[1]))
				battle._take_damage(source, source, amount, true, false)
			"consume_bleed":
				for victim in targets:
					if not battle._has_status(victim, "bleed"): continue
					var s: Dictionary = victim.get("statuses", {}).get("bleed", {})
					if s.is_empty(): continue
					var amount: int = 3 * int(s.get("stacks", 1)) * int(s.get("duration", 1))
					victim["statuses"].erase("bleed")
					if battle._take_damage(source, victim, amount, true, false, false, false, false, false, true): kos.append(int(victim["id"]))
			"taunt":
				var provoked: Array = targets if target.get("side") != source.get("side") else _foes(battle, source)
				for victim in provoked: battle._add_status(victim, "taunted", 1, 1, int(source["id"]))
			"taunt_attackers":
				for foe in _foes(battle, source):
					if int(foe.get("intent_target", -1)) == int(target["id"]): battle._add_status(foe, "taunted", 1, 1, int(source["id"]))
			"rage", "ravenous": _stack(source, op, int(a[1]))
			"rage_per_targeting":
				for foe in _foes(battle, source):
					if int(foe.get("intent_target", -1)) == int(source["id"]): _stack(source, "rage", 1)
			"consume_rage_heal":
				var recovered := roundi(float(_counter(source, "rage")) * 0.33 * float(source["max_hp"]))
				source["statuses"].erase("rage")
				if _has_action(def, "overheal_max") and int(source["hp"]) + recovered > int(source["max_hp"]):
					source["max_hp"] = int(source["hp"]) + recovered
				source["hp"] = mini(int(source["max_hp"]), int(source["hp"]) + recovered)
			"gain_en_fuego": _set_ini(battle, mini(int(battle.rules["impulse_max"]), _get_ini(battle) + int(_counter(source, "en_fuego")) * int(a[1])))
			"draw_en_fuego": battle._draw(int(_counter(source, "en_fuego")) * int(a[1]))
			"resist_en_fuego": battle._add_status(source, "protecao", 1, int(_counter(source, "en_fuego")) * int(a[1]), int(source["id"]))
			"double_impulse": _set_ini(battle, mini(int(battle.rules["impulse_max"]), _get_ini(battle) * 2))
			"redraws":
				if _acting_side(battle) == "ENEMY": battle.enemy_redraws += int(a[1])
				else: battle.redraws += int(a[1])
			"moves":
				if _acting_side(battle) == "ENEMY": battle.enemy_moves += int(a[1])
				else: battle.moves += int(a[1])
			"zero_random_heroic", "zero_heroics":
				var _zh := _acting_hand(battle)
				var candidates: Array = _zh.filter(func(c): return _card_costs_initiative(c))
				if op == "zero_random_heroic" and not candidates.is_empty(): candidates = [candidates[battle.rng.randi_range(0, candidates.size() - 1)]]
				for held in candidates:
					held["cost_override"] = 0
					if op == "zero_heroics": held["cost_override_until"] = int(battle.turn)
			"copy_hand_type":
				var _ch := _acting_hand(battle)
				if _ch.is_empty(): continue
				var chosen: Dictionary = _ch[battle.rng.randi_range(0, _ch.size() - 1)]
				var originals: Array = _ch.duplicate(true)
				for held in originals:
					if held.get("class") == chosen.get("class") and _ch.size() < battle.rules["hand_max"]:
						var copy: Dictionary = held.duplicate(true)
						battle.next_card_id += 1
						copy["uid"] = battle.next_card_id
						copy["temporary"] = true
						_ch.append(copy)
			"critical_hand", "upgrade_hand", "buff_hand":
				for held in _acting_hand(battle):
					if op == "critical_hand": held["critical"] = true
					elif op == "upgrade_hand": held["upgrade"] = int(held.get("upgrade", 0)) + 1
					else: held["bonus_attack"] = float(held.get("bonus_attack", 0)) + float(a[1])
			"mark_bleeding":
				for foe in _foes(battle, source):
					if battle._has_status(foe, "bleed"): battle._add_status(foe, "marked", 2, int(a[1]), int(source["id"]))
			"heal_per_bleed":
				var count: int = _foes(battle, source).filter(func(foe): return battle._has_status(foe, "bleed")).size()
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
				var _rd := _acting_discard(battle)
				var _rh := _acting_hand(battle)
				for index in range(_rd.size() - 1, -1, -1):
					if recovered >= int(a[1]) or _rh.size() >= battle.rules["hand_max"]: break
					if _rd[index].get("class") == "ATTACK":
						_rh.append(_rd.pop_at(index)); recovered += 1
			"retain_next", "free_owner": _stack(source, op, int(a[1]))
			"buff_returned":
				for held in _acting_hand(battle):
					if held.get("class") == "ATTACK": held["bonus_attack"] = float(held.get("bonus_attack", 0)) + float(a[1])
			"enhanced_resist":
				if spent_impulse >= int(a[1]):
					for ally in _friends(battle, source): battle._add_status(ally, "protecao", 1, 1, int(source["id"]))
			"ko":
				if kos.is_empty(): continue
				match str(a[1]):
					"conceal", "strengthened": battle._add_status(source, str(a[1]), 1, 1, int(source["id"]))
					"draw2": battle._draw(2)
					"heal_ally":
						var allies: Array[Dictionary] = []
						for fr in _friends(battle, source): allies.append(fr)
						if not allies.is_empty():
							var beneficiary: Dictionary = allies[battle.rng.randi_range(0, allies.size() - 1)]
							beneficiary["hp"] = mini(int(beneficiary["max_hp"]), int(beneficiary["hp"]) + int(source["attack"]))
					"impulse1": _set_ini(battle, mini(int(battle.rules["impulse_max"]), _get_ini(battle) + kos.size()))
			"summon": _summon(battle, source, str(a[1]), int(a[2]))
			"summon_unique":
				var created := _summon_on_side(battle, source, str(a[1]), int(a[2]), str(source.get("side", "ALLY")), true)
				if not created:
					_set_ini(battle, mini(int(battle.rules["impulse_max"]), _get_ini(battle) + 2))
					battle._log("%s já estava em campo: +2 Iniciativa." % str(a[1]))
				elif bool(def.get("summon_blessed", false)):
					for ally in _friends(battle, source):
						if bool(ally.get("is_summon", false)) and int(ally.get("summoner_id", -1)) == int(source["id"]) and str(ally.get("archetype", "")) == str(a[1]):
							battle._add_status(ally, "forte", 99, 1, int(source["id"]))
							battle._add_status(ally, "resistente", 99, 1, int(source["id"]))
			"enemy_infighting":
				for victim in targets:
					for other in targets:
						if victim["id"] != other["id"] and int(victim["hp"]) > 0 and int(other["hp"]) > 0:
							battle._take_damage(victim, other, int(victim["attack"])); break
			"revive_self":
				if source["hp"] <= 0: source["hp"] = maxi(1, roundi(float(source["max_hp"]) * float(a[1])))
			"revive_ally":
				for victim in targets:
					if victim["hp"] <= 0: victim["hp"] = maxi(1, roundi(float(victim["max_hp"]) * float(a[1])))
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
				for foe in _foes(battle, source):
					if not targets.has(foe) and foe["row"] == target["row"]: battle._take_damage(source, foe, roundi(float(source["attack"]) * float(a[1])))
			"restore_items":
				for item in battle.items.keys(): battle.items[item] = int(battle.items[item]) + 1
			"hazard": battle.environmental_used["pack_hazard_" + str(a[1])] = 0
			"grow": _stack(source, str(a[1]), 1)
			"spend_all_protecao":
				if source.get("statuses", {}).has("protecao"): source["statuses"].erase("protecao")
			"spend_protecao":
				if source.get("statuses", {}).has("protecao"):
					var _ps: Dictionary = source["statuses"]["protecao"]
					var _cur: int = int(_ps.get("stacks", 0))
					var _left: int = maxi(0, roundi(float(_cur) * (1.0 - float(a[1]))))
					if _left <= 0: source["statuses"].erase("protecao")
					else:
						_ps["stacks"] = _left
						source["statuses"]["protecao"] = _ps
			"spend_all_barrier":
				if source.get("statuses", {}).has("barrier"): source["statuses"].erase("barrier")
			"spend_barrier":
				if source.get("statuses", {}).has("barrier"):
					var _bs: Dictionary = source["statuses"]["barrier"]
					var _bhp: int = int(_bs.get("barrier_hp", _bs.get("stacks", 0)))
					var _bleft: int = maxi(0, roundi(float(_bhp) * (1.0 - float(a[1]))))
					if _bleft <= 0: source["statuses"].erase("barrier")
					else:
						_bs["barrier_hp"] = _bleft
						_bs["stacks"] = _bleft
						source["statuses"]["barrier"] = _bs
			"consume_all": _set_ini(battle, 0)
			"activate_next_turn":
				for held in _acting_hand(battle): _activate_next(battle, held)
			"ko_recast":
				if not kos.is_empty():
					for i in range(int(a[1])):
						var foes: Array[Dictionary] = []
						for f in _foes(battle, source): foes.append(f)
						if foes.is_empty(): break
						var victim: Dictionary = foes[battle.rng.randi_range(0, foes.size() - 1)]
						if battle._take_damage(source, victim, int(source["attack"]), false, true, false, false, false, true, true): kos.append(int(victim["id"]))
			"ko_chain":
				if not kos.is_empty():
					for foe in _foes(battle, source):
						if foe["id"] != target["id"]:
							battle._take_damage(source, foe, int(source["attack"])); break
			"protecao", "protection":
				var px: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				for victim in targets:
					battle._add_status(victim, "protecao", maxi(1, px), px, int(source["id"]))
			"barreira", "barrier":
				var rounds: int = 1
				var bhp: int = 5
				if a.size() >= 3:
					rounds = maxi(1, int(round(battle.resolve_amount(a[1], source))))
					bhp = maxi(1, int(round(battle.resolve_amount(a[2], source))))
				elif a.size() >= 2:
					rounds = 1
					bhp = maxi(1, int(round(battle.resolve_amount(a[1], source))))
				for victim in targets:
					battle._add_status(victim, "barrier", maxi(1, rounds), maxi(1, bhp), int(source["id"]))
			"resistente":
				var rx: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				for victim in targets:
					battle._add_status(victim, "resistente", maxi(1, rx), rx, int(source["id"]))
			"forte", "fortalecido":
				var fo: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				for victim in targets:
					battle._add_status(victim, "strengthened", maxi(1, fo), fo, int(source["id"]))
			"rapido", "rápido":
				var ra: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				for victim in targets:
					battle._add_status(victim, "fast", maxi(1, ra), ra, int(source["id"]))
			"heal_pct":
				# Cura = fração da Vida máxima (aceita fórmula, ex.: 0.1*E).
				var frac_h: float = float(battle.resolve_amount(a[1] if a.size() > 1 else 0, source))
				var any_hpct := false
				for victim in targets:
					var before_hpct := int(victim["hp"])
					var heal_pct_amt: int = maxi(0, roundi(float(victim.get("max_hp", 1)) * frac_h))
					victim["hp"] = mini(int(victim["max_hp"]), int(victim["hp"]) + heal_pct_amt)
					if int(victim["hp"]) > before_hpct:
						any_hpct = true
						if battle.has_signal("visual"):
							battle.visual.emit("heal", int(source["id"]), int(victim["id"]), int(victim["hp"]) - before_hpct)
				if any_hpct and battle.has_method("try_posture_trigger"):
					battle.try_posture_trigger(source, "curador")
			"heal_missing_pct":
				# Cura = fração da Vida faltante (max_hp - hp). Ex.: 0.1+0.18*E → E5 ≈ 100%.
				var frac_m: float = float(battle.resolve_amount(a[1] if a.size() > 1 else 0, source))
				var any_hm := false
				for victim in targets:
					var before_hm := int(victim["hp"])
					var missing: int = maxi(0, int(victim.get("max_hp", 1)) - int(victim["hp"]))
					var heal_m: int = maxi(0, roundi(float(missing) * frac_m))
					victim["hp"] = mini(int(victim["max_hp"]), int(victim["hp"]) + heal_m)
					if int(victim["hp"]) > before_hm:
						any_hm = true
						if battle.has_signal("visual"):
							battle.visual.emit("heal", int(source["id"]), int(victim["id"]), int(victim["hp"]) - before_hm)
				if any_hm and battle.has_method("try_posture_trigger"):
					battle.try_posture_trigger(source, "curador")
			"climate", "set_climate", "weather":
				# Um clima ativo por vez; partículas via GameRoot._set_weather.
				var mode := str(a[1] if a.size() > 1 else "rain").to_lower()
				if mode not in ["none", "rain", "snow", "leaves", "fog", "heat", "night"]:
					mode = "rain"
				if "climate" in battle:
					battle.climate = mode
				else:
					battle.set("climate", mode)
				var climate_ids := ["none", "rain", "snow", "leaves", "fog", "heat", "night"]
				var cidx := climate_ids.find(mode)
				if battle.has_signal("visual"):
					battle.visual.emit("climate", int(source["id"]), int(source["id"]), maxi(0, cidx))
				battle._log("Clima: %s." % mode)
			"summon_foe", "reinforce_enemy":
				# Invoca N lacaios no time inimigo. foe_id "random" = um tipo sorteado por jogada.
				var foe_id := str(a[1] if a.size() > 1 else "ent_minion_zumbi")
				var foe_n: int = maxi(1, int(round(battle.resolve_amount(a[2] if a.size() > 2 else 1, source))))
				if foe_id in ["random", "RANDOM", "*"]:
					var pool_foe: Array[String] = [
						"ent_minion_zumbi", "ent_minion_fantasma", "ent_minion_esqueleto", "ent_minion_vampiro",
						"ent_minion_mumia", "ent_minion_ghoul", "ent_minion_banshee", "ent_minion_strigoi",
						"ent_minion_golem", "ent_minion_lich",
					]
					foe_id = pool_foe[battle.rng.randi_range(0, pool_foe.size() - 1)]
				var foe_side := "ENEMY" if str(source.get("side", "ALLY")) == "ALLY" else "ALLY"
				for _fi in range(foe_n):
					_summon_on_side(battle, source, foe_id, 99, foe_side)
			"fragil":
				var fx: int = maxi(1, int(round(battle.resolve_amount(a[1] if a.size() > 1 else 1, source))))
				for victim in targets:
					battle._add_status(victim, "fragil", maxi(1, fx), fx, int(source["id"]))
			"when_stacks":
				# ["when_stacks", status, min, sub_op, ...args]
				if a.size() < 4: pass
				else:
					var w_id := str(a[1])
					var w_default: int = int(CombatRules.formula_value("Requerimentos", "when_stacks", "default_stacks", 1))
					var w_need: int = int(round(battle.resolve_amount(a[2] if a.size() > 2 else w_default, source)))
					if battle._status_stacks(source, w_id) >= w_need:
						var sub := str(a[3])
						match sub:
							"push", "pull":
								for victim in targets:
									if battle._has_status(victim, "bound"): continue
									victim["row"] = "back" if sub == "push" else "front"
							"extra_random_hit", "chain":
								var extra_n: int = int(round(battle.resolve_amount(a[4] if a.size() > 4 else 1, source)))
								var opposite := "ENEMY" if source["side"] == "ALLY" else "ALLY"
								var pool: Array[Dictionary] = []
								for foe in battle.living(opposite):
									if targets.has(foe): continue
									if battle.can_reach(source, foe, resolved_def): pool.append(foe)
								for _i in range(extra_n):
									if pool.is_empty(): break
									var pick: Dictionary = pool[battle.rng.randi_range(0, pool.size() - 1)]
									pool.erase(pick)
									var dmg: int = last_hit if last_hit > 0 else maxi(1, int(round(battle.resolve_amount("1+E", source) + float(_offense(source, def)))))
									if battle._take_damage(source, pick, dmg, bool(def.get("penetrating", false)) or _has_action(def, "penetrating"), true, false, true, not bool(def.get("reach", false)), true, true):
										if not kos.has(pick["id"]): kos.append(int(pick["id"]))
							"status", "self_status":
								var st := str(a[4]) if a.size() > 4 else "bleed"
								var sn: int = maxi(1, int(round(battle.resolve_amount(a[5] if a.size() > 5 else 1, source))))
								for victim in ([source] if sub == "self_status" else targets):
									battle._add_status(victim, st, sn, sn, int(source["id"]))
							"resistente":
								var rx2: int = maxi(1, int(round(battle.resolve_amount(a[4] if a.size() > 4 else 1, source))))
								battle._add_status(source, "resistente", maxi(1, rx2), rx2, int(source["id"]))
							"forte", "fortalecido":
								var fo2: int = maxi(1, int(round(battle.resolve_amount(a[4] if a.size() > 4 else 1, source))))
								battle._add_status(source, "strengthened", maxi(1, fo2), fo2, int(source["id"]))
							"rapido", "rápido":
								var ra2: int = maxi(1, int(round(battle.resolve_amount(a[4] if a.size() > 4 else 1, source))))
								battle._add_status(source, "fast", maxi(1, ra2), ra2, int(source["id"]))
							"protecao", "protection":
								var px2: int = maxi(1, int(round(battle.resolve_amount(a[4] if a.size() > 4 else 1, source))))
								battle._add_status(source, "protecao", maxi(1, px2), px2, int(source["id"]))
							"barreira", "barrier":
								var br2: int = 1
								var bh2: int = 5
								if a.size() >= 6:
									br2 = maxi(1, int(round(battle.resolve_amount(a[4], source))))
									bh2 = maxi(1, int(round(battle.resolve_amount(a[5], source))))
								elif a.size() >= 5:
									bh2 = maxi(1, int(round(battle.resolve_amount(a[4], source))))
								battle._add_status(source, "barrier", maxi(1, br2), maxi(1, bh2), int(source["id"]))
							_:
								pass
			"draw_items":
				# Compra todas as cartas de item do baralho do lado ativo.
				var moved: Array[Dictionary] = []
				var _deck := _acting_deck(battle)
				var _hand := _acting_hand(battle)
				var _disc := _acting_discard(battle)
				for index in range(_deck.size() - 1, -1, -1):
					var item: Dictionary = _deck[index]
					var iid := str(item.get("id", ""))
					var idef: Dictionary = catalog.definition(iid)
					if idef.is_empty() and Content.CARDS.has(iid):
						idef = Content.CARDS[iid]
					var is_item: bool = bool(idef.get("item", false)) or iid.begins_with("item_")
					if not is_item: continue
					_deck.remove_at(index)
					moved.append(item)
				for item2 in moved:
					if _hand.size() >= int(battle.rules["hand_max"]):
						_disc.append(item2)
					else:
						_hand.append(item2)
						on_draw(battle, item2)
			"redraw_actions":
				pass  # Avaliado em on_redraw.
			"requires_self_status", "requires_status":
				pass  # Pré-checagem em play().
			"quick", "free", "exhaust", "final", "chain", "grow_chain", "chain_hand_owner", "full_combo", "bonus_status", "bonus_damaged", "bonus_defense", "bonus_targeting_self", "bonus_full_hp", "bonus_en_fuego", "force_if_damaged", "hand_protecao", "hand_cost_down", "hand_damage_growth", "hand_resist", "overheal_max", "cost_down_en_fuego", "area_en_fuego", "enhanced", "redraw_force", "redraw_bonus", "redraw_strengthened", "play_while_disabled", "penetrating", "lethargic", "recoil", "drain", "instant", "ephemeral", "warmup", "barrier_from_hit", "counter_effects", "collision", "requires_alone", "requires_own_minion_front", "hit_flat", "hit_enemy_front", "heal_own_minions", "sacrifice_minion", "self_damage_hp": pass # Evaluated in preplay, hooks, or _bonus.
			_:
				push_error("Unsupported external card action: " + op)
	# Rápida: não gasta jogada (já tratado); ["quick", N] concede N jogadas extras.
	if bool(def.get("quick", false)) or _has_action(def, "quick") or card.get("next_quick_active", false):
		var qn := 0
		if _has_action(def, "quick"):
			var qa: Array = _action(def, "quick")
			if qa.size() > 1:
				qn = int(qa[1])
		if qn > 0:
			_add_plays(battle, qn)
	elif (battle._has_status(source, "assimilation") and kos.has(target_id)) or kos.any(func(id): return battle._has_status(battle.actor_by_id(id), "marked")):
		_add_plays(battle, 1)
	_try_nero_transform(battle, source, str(card.get("id", "")))
	# Erro Terrível: Ragnar ataca woman > 0 em combate corpo a corpo fora da Forma Bestial.
	if str(source.get("passive", "")) == "forma_bestial" and not bool(source.get("ragnar_form", false)) and not bool(def.get("reach", false)):
		for victim in targets:
			if int(victim.get("woman", 0)) > 0:
				battle._add_status(source, "stun", 1, 1, int(victim.get("id", -1)))
				battle._log("%s: Erro Terrível (Atordoado)." % source.get("name", "Ragnar"))
				break
	if battle._has_status(source, "assimilation") and not kos.is_empty(): _draw_filtered(battle, source, "draw_attack_heroic", 1)
	if battle._has_status(source, "ravenous") and _is_damage_card(def):
		if _counter(source, "preserve_ravenous") > 0: _consume(source, "preserve_ravenous")
		else: _consume(source, "ravenous")
	if battle._has_status(source, "make_em_bleed") and _is_damage_card(def): _consume(source, "make_em_bleed")
	if _has_action(def, "full_combo") and not chain_ids.is_empty() and chain_ids.all(func(id): return id == chain_ids[0]):
		battle._add_status(source, "strengthened", 1, 1, int(source["id"]))
	if def.get("final", false): battle._add_status(source, "finalized", 1, 1, int(source["id"]))
	if def.get("exhaust", false) or card.get("temporary", false): _acting_exhausted(battle).append(card)
	elif _counter(source, "retain_next") > 0: _consume(source, "retain_next"); _acting_hand(battle).append(card)
	else: _acting_discard(battle).append(card)
	if battle.has_method("_notify_card_posture_hooks"):
		battle._notify_card_posture_hooks(source, def)
	# Instantâneo não encerra a fase — só bloqueia Encerrar enquanto na mão.
	battle._after_card_play()
	battle._check_end()
	for held in _acting_hand(battle):
		if not prior_hand.has(int(held["uid"])): on_draw(battle, held)
	battle.changed.emit()
	return true

func on_turn_start(battle: Variant) -> void:
	for actor in battle.actors:
		if bool(actor.get("ragnar_form", false)) and int(battle.turn) > int(actor.get("ragnar_form_until", -1)):
			if battle.has_method("restore_ragnar_cards"):
				battle.restore_ragnar_cards(actor)
			actor["ragnar_form"] = false
			battle._log("%s voltou à forma humana." % actor.get("base_name", actor.get("name", "Ragnar")))
		if actor.has("summon_until") and int(actor["summon_until"]) < int(battle.turn):
			if int(actor.get("hp", 0)) > 0:
				actor["hp"] = 0
				if battle.has_method("dismiss_minion"):
					battle.dismiss_minion(actor, false)
				elif battle.has_method("purge_owner_cards"):
					battle.purge_owner_cards(int(actor["id"]))
				battle._log("%s (convocado) expirou." % actor.get("name", "?"))
	# Assinaturas removidas: aprimoramentos como Escuridão são passivos e não geram defesa no início do turno.
	for card in battle.hand:
		if catalog.definition(str(card.get("id", ""))).is_empty(): continue
		if card.has("cost_override_until") and int(card["cost_override_until"]) < int(battle.turn):
			card.erase("cost_override")
			card.erase("cost_override_until")
		if int(card.get("draw_turn", -1)) < int(battle.turn): _activate_next(battle, card)
		var def: Dictionary = catalog.definition(card["id"])
		if _has_action(def, "hand_cost_down"): card["cost_override"] = maxi(0, int(card.get("cost_override", def.get("cost", 0))) - 1)
		if _has_action(def, "hand_protecao"):
			var actor: Dictionary = battle.actor_by_id(int(card["owner"]))
			battle._add_status(actor, "protecao", 1, 1, int(actor["id"]))
		if _has_action(def, "hand_resist"):
			var holder: Dictionary = battle.actor_by_id(int(card["owner"]))
			battle._add_status(holder, "protecao", 1, 1, int(holder["id"]))

func on_draw(battle: Variant, card: Dictionary) -> void:
	# Required after a card enters the hand, so Roulette is fixed on draw.
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return
	card.erase("next_active")
	card["draw_turn"] = int(battle.turn)
	card["drawn_turn"] = int(battle.turn)
	if bool(def.get("ephemeral", false)) or _has_action(def, "ephemeral"): card["ephemeral"] = true
	if bool(def.get("instant", false)) or _has_action(def, "instant"): card["instant"] = true
	var wu: int = int(def.get("warmup", 0))
	if _has_action(def, "warmup"): wu = int(_action(def, "warmup")[1])
	if wu > 0: card["warmup"] = wu
	for a in def["actions"]:
		if a[0] == "roulette_status": card["roulette_status"] = str(a[battle.rng.randi_range(1, a.size() - 1)])
		if a[0] == "roulette_hit": card["roulette_factor"] = float(a[battle.rng.randi_range(1, a.size() - 1)])

func on_damage(battle: Variant, victim_id: int, actual_hp_loss: int) -> void:
	# Called after damage resolves; health loss is required for hand growth.
	if actual_hp_loss <= 0: return
	var actor: Dictionary = battle.actor_by_id(victim_id)
	if actor.is_empty(): return
	for card in battle.hand:
		if int(card.get("owner", -1)) != victim_id: continue
		var def: Dictionary = catalog.definition(str(card.get("id", "")))
		if _has_action(def, "hand_damage_growth"):
			card["bonus_attack"] = float(card.get("bonus_attack", 0)) + 0.5

func on_redraw(battle: Variant, card: Dictionary) -> void:
	var def: Dictionary = catalog.definition(str(card.get("id", "")))
	if def.is_empty(): return
	var actor: Dictionary = battle.actor_by_id(int(card["owner"]))
	if bool(def.get("ragnar_summon", false)):
		_set_ini(battle, mini(int(battle.rules["impulse_max"]), _get_ini(battle) + 1))
		battle._log("Recompra de invocação: +1 Iniciativa.")
	if _has_action(def, "redraw_force"): card["forceful"] = true
	if _has_action(def, "redraw_bonus"): card["bonus_attack"] = float(card.get("bonus_attack", 0.0)) + 0.5
	if _has_action(def, "redraw_strengthened"): battle._add_status(actor, "strengthened", 1, 1, int(actor["id"]))
	if _has_action(def, "redraw_actions"):
		var n: int = maxi(1, int(round(battle.resolve_amount(_action(def, "redraw_actions")[1] if _action(def, "redraw_actions").size() > 1 else 1, actor))))
		battle.grant_next_turn_plays(actor, n)

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
			"bonus_defense":
				if battle._has_status(victim, "protecao") or battle._has_status(victim, "barrier"): bonus += float(a[1])
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
		if typeof(a) == TYPE_ARRAY and not a.is_empty() and str(a[0]) in ["hit", "hit_per_impulse", "hit_per_hand", "hit_from_protecao", "hit_from_barrier", "roulette_hit"]:
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
		if source.get("statuses", {}).has("atento"):
			return 1.0
		return 0.75
	return 1.0

func _offense(actor: Dictionary, def: Dictionary) -> int:
	return int(actor.get(str(def.get("stat", "attack")), actor.get("attack", 1)))

func _counter(actor: Dictionary, name: String) -> int:
	var statuses: Variant = actor.get("statuses", {})
	if typeof(statuses) != TYPE_DICTIONARY:
		return 0
	var state: Variant = statuses.get(name, {})
	if typeof(state) != TYPE_DICTIONARY:
		return 0
	return int(state.get("stacks", 0))

func _stack(actor: Dictionary, name: String, count: int) -> void:
	if not actor.has("statuses") or typeof(actor["statuses"]) != TYPE_DICTIONARY:
		actor["statuses"] = {}
	var prior: Dictionary = actor["statuses"].get(name, {"stacks": 0, "duration": 99, "source": actor.get("id", 0)})
	if typeof(prior) != TYPE_DICTIONARY:
		prior = {"stacks": 0, "duration": 99, "source": actor.get("id", 0)}
	prior["stacks"] = int(prior.get("stacks", 0)) + count
	actor["statuses"][name] = prior

func _consume(actor: Dictionary, name: String) -> void:
	if not actor.has("statuses") or typeof(actor["statuses"]) != TYPE_DICTIONARY:
		return
	var stack := _counter(actor, name)
	if stack <= 1: actor["statuses"].erase(name)
	else:
		var st: Dictionary = actor["statuses"].get(name, {})
		if st.is_empty():
			actor["statuses"].erase(name)
		else:
			st["stacks"] = stack - 1
			actor["statuses"][name] = st

func _draw_filtered(battle: Variant, source: Dictionary, mode: String, amount: int) -> void:
	var hand := _acting_hand(battle)
	var deck := _acting_deck(battle)
	if mode == "draw_owner_to": amount = maxi(0, amount - hand.filter(func(c): return c.get("owner") == source["id"]).size())
	for i in range(amount):
		if mode == "draw": battle._draw(1); continue
		var found := -1
		for index in range(deck.size() - 1, -1, -1):
			var item: Dictionary = deck[index]
			if mode in ["draw_owner", "draw_owner_to"] and item.get("owner") == source["id"] or mode == "draw_heroic" and _card_costs_initiative(item) or mode == "draw_attack_heroic" and (_is_damage_card_id(str(item.get("id", ""))) or _card_costs_initiative(item)):
				found = index; break
		if found < 0 or hand.size() >= int(battle.rules["hand_max"]): break
		hand.append(deck.pop_at(found))

func _summon(battle: Variant, source: Dictionary, type: String, duration: int) -> void:
	_summon_on_side(battle, source, type, duration, str(source.get("side", "ALLY")))

func _summon_on_side(battle: Variant, source: Dictionary, type: String, duration: int, side: String, unique: bool = false) -> bool:
	# Invocação = personagem normal (minion): 1 HP típico, frente, deck próprio mesclado.
	var template_id := str(type)
	if unique:
		for actor in battle.living(side):
			if bool(actor.get("is_summon", false)) and int(actor.get("summoner_id", -1)) == int(source.get("id", -2)) and str(actor.get("archetype", "")) == template_id:
				return false
	var template: Dictionary = {}
	if Content.HEROES.has(template_id):
		template = Content.HEROES[template_id].duplicate(true)
	else:
		template = {
			"name": "Convocado",
			"hp": 1,
			"attack": maxi(1, int(source.get("attack", 4)) ),
			"power": maxi(1, int(source.get("power", 4)) ),
			"armor": 0,
			"escudo": 0,
			"type": str(source.get("type", "TECNICO")),
			"row": "front",
			"sprite": str(source.get("sprite", "")),
			"minion": true,
			"cards": [],
			"pool": [],
		}
	template["minion"] = true
	template["row"] = "front"
	# Lacaios tipados (ent_minion_*) mantêm HP do template; fallback genérico fica em 1.
	if not bool(template.get("keep_summon_hp", false)) and not str(template_id).begins_with("ent_minion_") and int(template.get("hp", 1)) > 3:
		template["hp"] = 1
	template["statuses"] = {}
	var ally: Dictionary = battle._create_actor(template, str(side), template_id if template_id != "" else "summon")
	if duration > 0:
		ally["summon_until"] = int(battle.turn) + duration
	ally["summoner_id"] = int(source.get("id", -1))
	ally["is_summon"] = true
	# Deck do conjurado: cartas do kit OU 1 ataque Grátis padrão.
	var card_ids: Array = template.get("cards", template.get("iniciais", []))
	if card_ids.is_empty():
		var free_id := "summon_free_strike"
		if not Content.CARDS.has(free_id):
			Content.CARDS[free_id] = {
				"id": free_id,
				"name": "Golpe Grátis",
				"class": "ATTACK",
				"target": "ENEMY",
				"actions": [["hit", "0"], ["free"]],
				"free": true,
				"stat": "attack",
				"gain": 0,
				"text": "Grátis. Impacto básico do convocado.",
				"tier": "inicial",
			}
		card_ids = [free_id]
	var pile = battle.deck if str(side) == "ALLY" else battle.enemy_deck
	for cid in card_ids:
		var card: Dictionary = battle._create_card(str(cid), int(ally["id"]))
		pile.append(card)
	battle._shuffle(pile)
	var side_label := "inimigo" if str(side) != str(source.get("side", "")) else "aliado"
	battle._log("%s convocou %s (%s; cartas mescladas no baralho)." % [source.get("name", "?"), ally.get("name", "?"), side_label])
	battle.changed.emit()
	return true
