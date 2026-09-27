extends RefCounted
class_name HotN3EntityCatalog

# This file never changes Content.gd or BattleState.gd. All cards are namespaced.
const CATALOG_PATH := "res://addons/hotn3_entities/entities.json"
var cards: Dictionary = {}
var heroes: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Card pack missing: " + CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("cards") or not parsed.has("heroes"):
		push_error("Invalid card pack JSON")
		return
	cards = parsed["cards"]
	heroes = parsed["heroes"]

func hero(id: String) -> Dictionary:
	return heroes.get(id, {})

func all_hero_ids() -> Array[String]:
	var result: Array[String] = []
	for id in heroes: result.append(id)
	result.sort()
	return result

func definition(id: String) -> Dictionary:
	return cards.get(id, {})

func ids_for(owner: String) -> Array[String]:
	var result: Array[String] = []
	for id in cards:
		if cards[id].get("owner", "") == owner:
			result.append(id)
	result.sort()
	return result

func by_source_name(owner: String, name: String) -> String:
	for id in ids_for(owner):
		if cards[id].get("source_name", "") == name:
			return id
	return ""

func validate() -> Array[String]:
	var problems: Array[String] = []
	var recognized := ["hit", "push", "pull", "choice", "heal", "heal_all", "full_heal", "cure", "status", "self_status", "block", "block_hp", "draw", "draw_owner", "draw_owner_to", "draw_heroic", "draw_attack_heroic", "quick", "free", "exhaust", "final", "chain", "chain_hand_owner", "random_chain", "full_combo", "taunt", "taunt_attackers", "ko", "ko_chain", "ko_recast", "consume_bleed", "mark_bleeding", "heal_per_bleed", "lifesteal", "bonus_status", "bonus_damaged", "bonus_block", "bonus_targeting_self", "bonus_full_hp", "bonus_en_fuego", "hit_per_impulse", "hit_per_hand", "consume_all", "hit_from_block", "hit_from_protecao", "hit_from_barrier", "spend_all_block", "spend_block", "spend_protecao", "spend_all_protecao", "spend_barrier", "spend_all_barrier", "block_from_hit", "barrier_from_hit", "barreira_hp", "protecao", "barreira", "barrier", "resistente", "fragil", "invulneravel", "force_if_damaged", "grow", "grow_chain", "hand_block", "hand_cost_down", "hand_damage_growth", "hand_resist", "discard_hand", "discard_random", "upgrade_hand", "buff_hand", "buff_returned", "critical_hand", "zero_random_heroic", "zero_heroics", "copy_hand_type", "return_attacks", "self_damage", "self_damage_hp", "rage", "rage_per_targeting", "consume_rage_heal", "overheal_max", "ravenous", "next_ravenous", "gain_en_fuego", "draw_en_fuego", "resist_en_fuego", "cost_down_en_fuego", "area_en_fuego", "roulette_status", "roulette_hit", "chance_status", "requires_status", "enhanced", "enhanced_resist", "next_chain", "next_damage", "next_cost", "next_quick", "next_area", "next_draw", "activate_next_turn", "redraw_force", "redraw_bonus", "redraw_strengthened", "redraws", "moves", "double_impulse", "restore_items", "summon", "hazard", "mind_attack", "move_target", "detonate", "splash", "play_while_disabled", "enemy_infighting", "revive_self", "revive_ally"]
	for id in cards:
		var c: Dictionary = cards[id]
		if c.get("actions", []).is_empty(): problems.append(id + " has no actions")
		for action in c.get("actions", []):
			if action.is_empty() or not recognized.has(action[0]):
				problems.append(id + " unsupported: " + str(action))
	return problems
