extends RefCounted
class_name HotNCollectionRules

## Regras puras da coleção. A interface apenas apresenta estes resultados.

static func default_owned(hero: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for entry in hero.get("iniciais", hero.get("cards", [])):
		var card_id := str(entry)
		if seen.has(card_id):
			continue
		seen[card_id] = true
		result.append(card_id)
	var disadvantage := str(hero.get("desvantagem", ""))
	if disadvantage != "" and not seen.has(disadvantage):
		result.append(disadvantage)
	return result

static func replace_base_with_upgrades(card_ids: Array, definitions: Dictionary) -> Array:
	var upgraded_bases: Dictionary = {}
	for entry in card_ids:
		var definition: Dictionary = definitions.get(str(entry), {})
		var base_id := str(definition.get("melhorada_de", ""))
		if base_id != "":
			upgraded_bases[base_id] = true
	var result: Array = []
	var seen: Dictionary = {}
	for entry in card_ids:
		var card_id := str(entry)
		if seen.has(card_id) or upgraded_bases.has(card_id):
			continue
		seen[card_id] = true
		result.append(card_id)
	return result

static func ensure_owned(heroes: Dictionary, definitions: Dictionary, current: Dictionary) -> Dictionary:
	var result := current.duplicate(true)
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		if not hero.get("playable", true):
			continue
		var saved = result.get(hero_id, [])
		if saved is Array and not saved.is_empty():
			result[hero_id] = replace_base_with_upgrades(saved, definitions)
		else:
			result[hero_id] = default_owned(hero)
	return result

static func grant(hero_id: String, card_id: String, heroes: Dictionary, definitions: Dictionary, current: Dictionary) -> Dictionary:
	var result := ensure_owned(heroes, definitions, current)
	if not heroes.has(hero_id) or not definitions.has(card_id):
		return result
	var cards: Array = result.get(hero_id, []).duplicate()
	var definition: Dictionary = definitions[card_id]
	var base_id := str(definition.get("melhorada_de", ""))
	if base_id != "":
		while cards.has(base_id):
			cards.erase(base_id)
	if not cards.has(card_id):
		var already_upgraded := false
		for owned_id in cards:
			if str(definitions.get(str(owned_id), {}).get("melhorada_de", "")) == card_id:
				already_upgraded = true
				break
		if not already_upgraded:
			cards.append(card_id)
	result[hero_id] = replace_base_with_upgrades(cards, definitions)
	return result

static func combat_deck(hero_id: String, heroes: Dictionary, definitions: Dictionary, current: Dictionary) -> Array:
	if not heroes.has(hero_id):
		return []
	var cards: Array = current.get(hero_id, default_owned(heroes[hero_id])).duplicate()
	return replace_base_with_upgrades(cards, definitions)

static func build_team_decks(team: Array[String], heroes: Dictionary, definitions: Dictionary, current: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for hero_id in team:
		result[hero_id] = combat_deck(hero_id, heroes, definitions, current)
	return result
