extends SceneTree
const Content = preload("res://game/Content.gd")
const PackBridge = preload("res://game/PackBridge.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packs = PackBridge.new()
	packs.merge_into_content()
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set("reduce_motion", false)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	game.set("team", ["ent_alyssa_wine", "ent_adam", "ent_madelyn"] as Array[String])
	game.set("mission_id", "road")
	game.set("sensitive_content", true)
	game.set("battle_view_mode", "lateral")
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	var alyssa_id: int = -1
	for a in game.battle.living("ALLY"):
		if str(a.get("archetype", "")) == "ent_alyssa_wine":
			alyssa_id = int(a["id"])
			game.battle._add_status(a, "escuridao", 99, 3, alyssa_id)
			break
	var def: Dictionary = Content.CARDS["ent_alyssa_wine_garras_e_presas"]
	var card := {"id": "ent_alyssa_wine_garras_e_presas", "owner": alyssa_id, "uid": 999}
	var short: String = game.call("_effect_short_bbcode", def, card)
	print("SHORT=", short)
	print("LABEL_bleed=", game.call("_status_label", "bleed"))
	var reason: String = ""
	# clear escuridao
	var a2: Dictionary = game.battle.actor_by_id(alyssa_id)
	a2["statuses"].erase("escuridao")
	game.battle.hand.append(game.battle._create_card("ent_alyssa_wine_garras_e_presas", alyssa_id))
	var idx: int = game.battle.hand.size() - 1
	reason = game.call("_card_require_status_reason", idx)
	print("REQUIRE=", reason)
	# preview
	game.battle._add_status(a2, "escuridao", 99, 2, alyssa_id)
	var enemy_id: int = -1
	for e in game.battle.living("ENEMY"):
		enemy_id = int(e["id"]); break
	game.set("selected_card", idx)
	var est: Dictionary = game.battle.preview(idx, enemy_id, [])
	print("PREVIEW=", est)
	quit(0)
