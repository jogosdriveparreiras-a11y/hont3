extends SceneTree

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const CampaignRoot = preload("res://addons/hotn3_campaign/CampaignRoot.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var _packs = PackBridge.new()
	var team: Array[String] = ["guerreiro", "mago", "clerigo"]
	for mission_id in Content.MISSIONS:
		var battle: HotNBattle = Battle.new()
		battle.begin(mission_id, team, {}, 20260926)
		assert(battle.phase == "PLAYER" and battle.turn == 1, "Mission must start: " + mission_id)
		assert(battle.living("ALLY").size() == 3, "Three allies required: " + mission_id)
		assert(not battle.living("ENEMY").is_empty(), "Enemy wave required: " + mission_id)
		match battle.mission["objective"]:
			"ELIMINATE":
				for enemy in battle.living("ENEMY"): enemy["hp"] = 0
				var rein: Dictionary = battle.mission.get("reinforcements", {})
				var first_wave := 999
				var last_wave := 1
				for t in rein.keys():
					first_wave = mini(first_wave, int(t))
					last_wave = maxi(last_wave, int(t))
				if first_wave < 999:
					battle.turn = maxi(1, first_wave - 1)
					battle._check_end()
					assert(battle.phase != "FINISHED", "Expected reinforcements cannot be skipped: " + mission_id)
				battle.turn = last_wave
				battle._check_end()
			"BOSS":
				for enemy in battle.living("ENEMY"):
					if enemy.get("boss", false): enemy["hp"] = 0
				battle._check_end()
			"SURVIVE", "PROTECT":
				battle.turn = int(battle.mission["turns"])
				battle.phase = "ENEMY"
				battle._check_end()
		assert(battle.phase == "FINISHED", "Mission must complete according to its objective: " + mission_id)
	# O schema do editor deve ser carregável pelo runtime e seus critérios
	# substituem o objetivo genérico da missão.
	var mission_id := str(Content.MISSIONS.keys()[0])
	var custom_mission: Dictionary = Content.MISSIONS[mission_id].duplicate(true)
	custom_mission["campaign_criteria"] = [{"type": "survive_rounds", "value": 2}]
	var scripted: HotNBattle = Battle.new()
	scripted.begin(mission_id, team, {}, 20261004, {}, {}, false, custom_mission)
	var extra_card := str(Content.CARDS.keys()[0])
	scripted.add_campaign_extra_cards([{"side": "enemy", "card_id": extra_card, "count": 2}])
	assert(scripted.enemy_deck.filter(func(card): return str(card.get("id", "")) == extra_card).size() == 2, "Campaign enemy cards must enter the enemy deck")
	scripted.turn = 2
	scripted._check_end()
	assert(scripted.phase == "FINISHED", "Campaign survive criterion must finish the battle")
	var campaign: Node = CampaignRoot.new()
	campaign._read_story()
	assert(not campaign.campaign_story.is_empty(), "Campaign story must load in the game runtime")
	var battle_config: Dictionary = campaign._battle_config({"mission": mission_id, "party_size": 3, "criteria": [{"type": "survive_rounds", "value": 2}], "extra_cards": [{"side": "enemy", "card_id": extra_card}]})
	assert(battle_config["mission_data"]["campaign_criteria"].size() == 1, "Editor criteria must reach the runtime mission")
	assert(battle_config["extra_cards"].size() == 1, "Editor extra cards must reach the runtime battle")
	if FileAccess.file_exists("res://av1.json"):
		var imported: Dictionary = campaign.campaign_story["campaigns"].filter(func(item): return str(item.get("source_file", "")) == "av1.json")[0]
		assert(imported["party_size"] == 4, "Campaign roster size must be independent from battle size")
		assert(campaign.campaign_story["scenes"].has("av_1__s01_quarto_nolan"), "External scene IDs must be isolated by source file")
		var battle_step: Dictionary = campaign.campaign_story["scenes"]["av_1__s03_batalha_amona"]["steps"].filter(func(item): return item.get("type", "") == "battle")[0]
		assert(campaign._battle_config(battle_step)["party_size"] == 3, "The campaign's 4-person roster must still allow 3-person battles")
	campaign.free()
	print("OK: %d missions, custom criteria, campaign script loading and extra battle cards" % Content.MISSIONS.size())
	quit(0)
