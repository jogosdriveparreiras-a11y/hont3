extends RefCounted
# Ponte opcional para os pacotes em addons/. Não altera Content.gd nem BattleState.gd.

const Content = preload("res://game/Content.gd")
const ExternalRuntime = preload("res://addons/hotn3_external_cards/CardRuntime.gd")
const EntityRuntime = preload("res://addons/hotn3_entities/EntityRuntime.gd")
const OWNER_MAP_PATH := "res://addons/hotn3_external_cards/owner_mapping.json"

var external = ExternalRuntime.new()
var entities = EntityRuntime.new()
var archetype_owners: Dictionary = {} # arquétipo HotN3 -> lista de donos ms_

func _init() -> void:
	_load_owner_mapping()

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
	var card_id := str(battle.hand[hand_index].get("id", ""))
	if mode == "entities" or card_id.begins_with("ent_"):
		return entities.play(battle, hand_index, target_id, chain_ids)
	if mode == "external" or card_id.begins_with("ms_"):
		return external.play(battle, hand_index, target_id, chain_ids)
	return battle.play(hand_index, target_id, chain_ids)

func redraw_card(battle: Variant, mode: String, hand_index: int) -> bool:
	if battle == null:
		return false
	if mode == "entities":
		return entities.redraw_card(battle, hand_index)
	if mode == "external":
		if hand_index < 0 or hand_index >= battle.hand.size():
			return false
		var old: Dictionary = battle.hand[hand_index]
		external.on_redraw(battle, old)
		return battle.redraw(hand_index)
	return battle.redraw(hand_index)

func on_player_turn_resumed(battle: Variant, mode: String) -> void:
	if battle == null or mode == "default" or battle.phase != "PLAYER":
		return
	var runtime = entities if mode == "entities" else external
	for card in battle.hand:
		runtime.on_draw(battle, card)
	runtime.on_turn_start(battle)

func deploy_entities(battle: Variant, mission_id: String, entity_ids: Array[String] = []) -> bool:
	var ids: Array[String] = entity_ids
	if ids.is_empty():
		ids = ["ent_akuji", "ent_adam", "ent_techna"]
	return entities.deploy(battle, mission_id, ids)

func install_external_demo(battle: Variant) -> int:
	# Substitui o baralho aliado por cartas ms_ mapeadas aos arquétipos da equipe.
	if battle == null:
		return 0
	var owner_map: Dictionary = {}
	var selected: Dictionary = {}
	var used_owners: Dictionary = {}
	for ally in battle.living("ALLY"):
		var archetype := str(ally.get("archetype", ""))
		var candidates: Array = archetype_owners.get(archetype, [])
		var chosen := ""
		for candidate in candidates:
			if not used_owners.has(candidate):
				chosen = str(candidate)
				break
		if chosen == "" and not candidates.is_empty():
			chosen = str(candidates[0])
		if chosen == "":
			continue
		used_owners[chosen] = true
		owner_map[chosen] = int(ally["id"])
		var pool: Array = external.catalog.ids_for(chosen)
		var deck: Array = []
		for card_id in pool:
			if deck.size() >= 8:
				break
			deck.append(card_id)
			if deck.size() < 8 and deck.count(card_id) < 2:
				deck.append(card_id)
		while deck.size() < 8 and not pool.is_empty():
			deck.append(pool[deck.size() % pool.size()])
		selected[chosen] = deck.slice(0, 8)
	battle.deck.clear()
	battle.hand.clear()
	battle.discard.clear()
	battle.exhausted.clear()
	battle.next_card_id = 0
	var installed: int = external.install(battle, owner_map, selected)
	battle._draw(int(battle.rules["opening_hand"]))
	for card in battle.hand:
		external.on_draw(battle, card)
	external.on_turn_start(battle)
	battle.changed.emit()
	return installed

func describe_actions(definition: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		match op:
			"hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "roulette_hit":
				parts.append("Dano ×%s" % str(action[1] if action.size() > 1 else "1"))
			"heal", "heal_all", "full_heal":
				parts.append("Cura")
			"block", "block_hp":
				parts.append("Bloqueio")
			"status", "self_status", "chance_status", "roulette_status":
				parts.append("Estado %s" % str(action[1] if action.size() > 1 else ""))
			"draw", "draw_owner", "draw_heroic":
				parts.append("Compra")
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
