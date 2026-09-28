extends RefCounted
class_name HotNCampaignRules

## Regras puras de desbloqueio e pontuação da campanha.

static func mission_unlocked(mission_id: String, campaign: Dictionary, best_stars: Dictionary) -> bool:
	if not campaign.has(mission_id):
		return false
	for requirement in campaign[mission_id].get("requires", []):
		if not best_stars.has(requirement):
			return false
	return true

static func award_victory(mission_id: String, stars: int, best_stars: Dictionary, essence: int) -> Dictionary:
	if stars < 1 or stars > 3:
		return {"reward": 0, "best_stars": best_stars.duplicate(true), "essence": essence}
	var updated := best_stars.duplicate(true)
	var previous := int(updated.get(mission_id, 0))
	var reward := (3 if previous == 0 else 0) + 2 * maxi(0, stars - previous)
	updated[mission_id] = maxi(previous, stars)
	return {"reward": reward, "best_stars": updated, "essence": essence + reward}

static func mission_stars(battle, mission_id: String, campaign: Dictionary, team_size: int) -> int:
	if battle == null or not campaign.has(mission_id):
		return 0
	var survivors: Array = battle.living("ALLY")
	var stars := 1 + (1 if survivors.size() >= 2 else 0)
	var goal: Dictionary = campaign[mission_id]
	if battle.mission["objective"] in ["SURVIVE", "PROTECT"]:
		var healthy: bool = survivors.size() == team_size and survivors.all(func(actor): return int(actor["hp"]) * 2 >= int(actor["max_hp"]))
		if battle.mission["objective"] == "PROTECT":
			healthy = healthy and battle.protect_hp >= int(battle.mission["protect_hp"]) / 2
		if healthy:
			stars += 1
	elif battle.turn <= int(goal["par"]):
		stars += 1
	return stars
