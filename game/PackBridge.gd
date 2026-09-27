extends RefCounted
# Ponte para pacotes em addons/. Injeta heróis/cartas no Content jogável na inicialização.

const Content = preload("res://game/Content.gd")
const ExternalRuntime = preload("res://addons/hotn3_external_cards/CardRuntime.gd")
const EntityRuntime = preload("res://addons/hotn3_entities/EntityRuntime.gd")
const OWNER_MAP_PATH := "res://addons/hotn3_external_cards/owner_mapping.json"

static var packs_merged := false

var external = ExternalRuntime.new()
var entities = EntityRuntime.new()
var archetype_owners: Dictionary = {} # arquétipo HotN3 -> lista de donos ms_

func _init() -> void:
	_load_owner_mapping()
	merge_into_content()

func _load_owner_mapping() -> void:
	archetype_owners.clear()
	if not FileAccess.file_exists(OWNER_MAP_PATH):
		return
	var file := FileAccess.open(OWNER_MAP_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for owner_id in parsed.keys():
		var archetype: String = str(parsed[owner_id])
		if not archetype_owners.has(archetype):
			archetype_owners[archetype] = []
		archetype_owners[archetype].append(str(owner_id))

func _aprimoramento_id(src: Dictionary) -> String:
	var apr = src.get("aprimoramento", src.get("passive", "oportunista"))
	if typeof(apr) == TYPE_DICTIONARY:
		return str(apr.get("id", src.get("passive", "oportunista")))
	return str(apr)

func merge_into_content() -> void:
	# Idempotente: heróis ent_ e cartas ms_/ent_ entram no caminho principal uma vez.
	if packs_merged:
		return
	packs_merged = true
	_merge_entity_heroes()
	_merge_entity_cards()
	_merge_external_cards()
	_expand_archetype_pools()

func _merge_entity_heroes() -> void:
	for hero_id in entities.catalog.heroes:
		var id := str(hero_id)
		if Content.HEROES.has(id):
			continue
		var src: Dictionary = entities.catalog.heroes[id]
		var pool: Array = []
		for card_id in src.get("pool", []):
			pool.append(str(card_id))
		var cards: Array = []
		for card_id in src.get("cards", []):
			cards.append(str(card_id))
		Content.HEROES[id] = {
			"name": str(src.get("name", id)),
			"hp": int(src.get("hp", 20)),
			"attack": int(src.get("attack", 4)),
			"power": int(src.get("power", 4)),
			"armor": int(src.get("armor", 0)),
			"escudo": int(src.get("escudo", src.get("armor", 0))),
			"type": str(src.get("type", "TECNICO")),
			"archetype_stat": str(src.get("archetype", "Nenhum")),
			"species": str(src.get("species", "Humano")),
			"level_reference": int(src.get("level_reference", 1)),
			"sprite": str(src.get("sprite", "res://hero_rogue.png")),
			"sprite_scale": float(src.get("sprite_scale", src.get("scale_factor", 1.0))),
			"portrait": str(src.get("portrait", "")),
			"signature_icon": str(src.get("signature_icon", "")),
			"row": str(src.get("row", "front")),
			"passive": _aprimoramento_id(src),
			"aprimoramento": src.get("aprimoramento", src.get("passive", "oportunista")),
			"grupos": src.get("grupos", []),
			"biografia": str(src.get("biografia", "")),
			"iniciais": src.get("iniciais", cards),
			"evoluidas": src.get("evoluidas", []),
			"melhoradas": src.get("melhoradas", []),
			"desvantagem": str(src.get("desvantagem", "")),
			"playable": true,
			"minion": bool(src.get("minion", false)),
			"repeatable": bool(src.get("repeatable", src.get("minion", false))),
			"pool": pool,
			"cards": cards,
		}
		if not Content.HERO_LORE.has(id):
			Content.HERO_LORE[id] = {
				"role": str(src.get("archetype", "Anexo")),
				"trait": "Herói do elenco expandido (pacote ent_).",
				"history": "%s · %s" % [str(src.get("species", "Desconhecido")), str(src.get("source_page", "anexo"))],
			}

func _merge_entity_cards() -> void:
	for card_id in entities.catalog.cards:
		var id := str(card_id)
		if Content.CARDS.has(id):
			continue
		Content.CARDS[id] = entities.catalog.cards[id].duplicate(true)

func _merge_external_cards() -> void:
	for card_id in external.catalog.cards:
		var id := str(card_id)
		if Content.CARDS.has(id):
			continue
		Content.CARDS[id] = external.catalog.cards[id].duplicate(true)

func _expand_archetype_pools() -> void:
	# Cartas ms_ entram no pool dos arquétipos HotN (guerreiro/mago/…) via owner_mapping.
	for archetype in archetype_owners.keys():
		var hero_id := str(archetype)
		if not Content.HEROES.has(hero_id):
			continue
		var hero: Dictionary = Content.HEROES[hero_id]
		var pool: Array = []
		for entry in hero.get("pool", []):
			pool.append(str(entry))
		var seen: Dictionary = {}
		for entry in pool:
			seen[entry] = true
		for owner_id in archetype_owners[archetype]:
			for card_id in external.catalog.ids_for(str(owner_id)):
				var cid := str(card_id)
				if seen.has(cid):
					continue
				seen[cid] = true
				pool.append(cid)
		hero["pool"] = pool

func definition(card_id: String) -> Dictionary:
	if Content.CARDS.has(card_id):
		return Content.CARDS[card_id]
	var from_entities: Dictionary = entities.catalog.definition(card_id)
	if not from_entities.is_empty():
		return from_entities
	return external.catalog.definition(card_id)

func is_pack_card(card_id: String) -> bool:
	var id := str(card_id)
	return id.begins_with("ms_") or id.begins_with("ent_")

func play_card(battle: Variant, mode: String, hand_index: int, target_id: int, chain_ids: Array = []) -> bool:
	if battle == null:
		return false
	if hand_index < 0 or hand_index >= battle.hand.size():
		return false
	var card_id: String = str(battle.hand[hand_index].get("id", ""))
	if mode == "entities" or card_id.begins_with("ent_"):
		return entities.play(battle, hand_index, target_id, chain_ids)
	if mode == "external" or card_id.begins_with("ms_"):
		return external.play(battle, hand_index, target_id, chain_ids)
	return battle.play(hand_index, target_id, chain_ids)

func redraw_card(battle: Variant, mode: String, hand_index: int) -> bool:
	if battle == null:
		return false
	if hand_index < 0 or hand_index >= battle.hand.size():
		return false
	var card_id: String = str(battle.hand[hand_index].get("id", ""))
	if mode == "entities" or card_id.begins_with("ent_"):
		return entities.redraw_card(battle, hand_index)
	if mode == "external" or card_id.begins_with("ms_"):
		var old: Dictionary = battle.hand[hand_index]
		var old_def: Dictionary = external.catalog.definition(card_id)
		if battle.is_instant_card(old, old_def):
			return false
		external.on_redraw(battle, old)
		return battle.redraw(hand_index)
	var peek: Dictionary = battle.hand[hand_index]
	var peek_def: Dictionary = definition(card_id)
	if battle.is_instant_card(peek, peek_def):
		return false
	return battle.redraw(hand_index)

func on_player_turn_resumed(battle: Variant, mode: String) -> void:
	if battle == null or battle.phase != "PLAYER":
		return
	var run_entities := mode == "entities"
	var run_external := mode == "external"
	for card in battle.hand:
		var card_id := str(card.get("id", ""))
		if card_id.begins_with("ent_"):
			run_entities = true
		elif card_id.begins_with("ms_"):
			run_external = true
	if run_entities:
		for card in battle.hand:
			if str(card.get("id", "")).begins_with("ent_"):
				entities.on_draw(battle, card)
		entities.on_turn_start(battle)
	if run_external:
		for card in battle.hand:
			if str(card.get("id", "")).begins_with("ms_"):
				external.on_draw(battle, card)
		external.on_turn_start(battle)

func deploy_entities(battle: Variant, mission_id: String, entity_ids: Array[String] = []) -> bool:
	var ids: Array[String] = []
	if entity_ids.is_empty():
		ids.assign(["ent_akuji", "ent_adam", "ent_techna"])
	else:
		ids.assign(entity_ids)
	return entities.deploy(battle, mission_id, ids)

func describe_actions(definition: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		match op:
			"hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "hit_from_protecao", "hit_from_barrier", "roulette_hit":
				if op == "hit_from_protecao":
					parts.append("Dano = stacks de Proteção")
				elif op == "hit_from_barrier":
					parts.append("Dano = HP da Barreira")
				elif op == "hit_from_block":
					parts.append("Dano = Bloqueio legado")
				else:
					parts.append("Dano base %s (+Impacto−Armadura / +Poder−Escudo)" % str(action[1] if action.size() > 1 else "0"))
			"heal", "heal_all", "full_heal":
				parts.append("Cura %s Vida" % str(action[1] if action.size() > 1 else ""))
			"block", "block_hp":
				parts.append("Barreira (via bloqueio legado)")
			"barreira_hp":
				parts.append("Barreira %s rodadas / %% Vida" % str(action[1] if action.size() > 1 else "1"))
			"protecao", "protection":
				parts.append("Proteção %s" % str(action[1] if action.size() > 1 else "1"))
			"spend_protecao":
				parts.append("Gasta %s%% da Proteção" % str(round(float(action[1]) * 100) if action.size() > 1 else 25))
			"spend_all_protecao":
				parts.append("Gasta toda a Proteção")
			"spend_all_barrier", "spend_barrier":
				parts.append("Gasta Barreira")
			"barrier_from_hit":
				parts.append("Ganha Barreira = dano causado")
			"barreira", "barrier":
				if action.size() >= 3:
					parts.append("Barreira %s rodadas / %s HP" % [str(action[1]), str(action[2])])
				else:
					parts.append("Barreira %s HP" % str(action[1] if action.size() > 1 else ""))
			"resistente":
				parts.append("Resistente %s" % str(action[1] if action.size() > 1 else "1"))
			"fragil":
				parts.append("Frágil %s" % str(action[1] if action.size() > 1 else "1"))
			"invulneravel", "invulnerable":
				parts.append("Invulnerável %s" % str(action[1] if action.size() > 1 else "1"))
			"status", "self_status", "chance_status", "roulette_status":
				parts.append("Estado %s" % str(action[1] if action.size() > 1 else ""))
			"draw", "draw_owner", "draw_heroic", "draw_own":
				parts.append("Compra" if op != "draw_own" else "Comprar próprio")
			"recover", "recover_own":
				parts.append("Recuperar própria" if op == "recover_own" else "Recuperar")
			"actions":
				parts.append("+%s ações no próximo turno" % str(action[1] if action.size() > 1 else 1))
			"requires_self_status":
				parts.append("Requer %s ≥ %s" % [str(action[1] if action.size() > 1 else "?"), str(action[2] if action.size() > 2 else 1)])
			"when_stacks":
				parts.append("Se %s ≥ %s: %s" % [str(action[1]), str(action[2]), str(action[3] if action.size() > 3 else "")])
			"draw_items":
				parts.append("Compra todos os itens do baralho")
			"redraw_actions":
				parts.append("Ao recomprar: +%s ações" % str(action[1] if action.size() > 1 else 1))
			"discard":
				parts.append("Descarta %s" % str(action[1] if action.size() > 1 else 1))
			"penetrating":
				parts.append("Penetrante")
			"lethargic":
				parts.append("Letárgico")
			"recoil":
				parts.append("Recuo (1/3)")
			"drain":
				parts.append("Dreno (1/4)")
			"instant":
				parts.append("Instantâneo (obrigatória nesta rodada)")
			"ephemeral":
				parts.append("Efêmero")
			"warmup":
				parts.append("Aquecimento %s" % str(action[1] if action.size() > 1 else ""))
			"push", "pull":
				parts.append("Empurra" if op == "push" else "Puxa")
			"quick":
				parts.append("Rápida")
			"free":
				parts.append("Livre")
			"exhaust":
				parts.append("Exaure")
			"final":
				parts.append("Final")
			"summon":
				parts.append("Invoca")
			_:
				parts.append(op.replace("_", " "))
	return parts
