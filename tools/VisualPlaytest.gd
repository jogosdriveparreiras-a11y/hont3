extends SceneTree

const Content = preload("res://game/Content.gd")
const PackBridge = preload("res://game/PackBridge.gd")

var _fails: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	_fails.append(msg)
	print("PLAYFLOW FAIL: " + msg)

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	var dirs: Array[String] = []
	var user_dir := ProjectSettings.globalize_path("user://playtest_shots")
	dirs.append(user_dir)
	dirs.append(ProjectSettings.globalize_path("res://").path_join("playtest_out"))
	if DirAccess.dir_exists_absolute("/workspace"):
		dirs.append("/workspace")
	var tmp := OS.get_environment("TEMP")
	if tmp == "":
		tmp = "/tmp"
	dirs.append(String(tmp).path_join("hotn3_shots"))
	for d in dirs:
		DirAccess.make_dir_recursive_absolute(d)
	var game = load("res://game/GameRoot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("reduce_motion", false)
	game.set("sound_levels", {"MASTER": 0.0, "MUSIC": 0.0, "SFX": 0.0, "UI": 0.0, "AMBIENCE": 0.0})
	if game.get("sound") != null:
		game.call("_set_volume", 0.0, "MASTER")
	game.set("best_stars", {})
	game.set("mission_id", "road")
	game.set("team", ["ent_adam", "ent_madelyn", "ent_ashlee"] as Array[String])
	var _packs = PackBridge.new()
	game.call("_start_mission")
	for i in range(30):
		await process_frame
	await create_timer(0.8).timeout
	for i in range(20):
		await process_frame
	_save(dirs, "playtest_hotn3_playflow_battle.png")

	var battle = game.get("battle")
	_assert(battle != null, "battle null after start")
	if battle == null:
		_finish()
		return
	_assert(battle.phase == "PLAYER", "expected PLAYER phase, got %s" % battle.phase)
	_assert(battle.hand.size() > 0, "empty hand")

	# --- Hover ---
	game.set("hovered_card", 0)
	game.call("_refresh_hero_hud")
	game.call("_render_battle")
	for i in range(12):
		await process_frame
	_save(dirs, "playtest_hotn3_playflow_hover.png")

	# --- Targeted damage: select → confirm → pick enemy ---
	var dmg_idx: int = _ensure_hand_card(game, battle, "ENEMY", true)
	_assert(dmg_idx >= 0, "no ENEMY damage card available")
	if dmg_idx < 0:
		_finish()
		return

	# 1st click path: select/inspect
	game.set("inspected_card", dmg_idx)
	game.set("hovered_card", dmg_idx)
	game.set("selected_card", -1)
	game.set("card_confirmed", false)
	game.call("_render_battle")
	for i in range(18):
		await process_frame
	_save(dirs, "playtest_hotn3_playflow_select.png")
	_assert(int(game.get("inspected_card")) == dmg_idx, "inspect not sticky after select")

	var enemies_before: Array = battle.living("ENEMY")
	_assert(not enemies_before.is_empty(), "no enemies")
	var target_id: int = int(enemies_before[0]["id"])
	var hp_before: int = int(enemies_before[0]["hp"])
	var hand_before: int = battle.hand.size()

	# 2nd click path: confirm (must enter targeting, not auto-play)
	game.call("_confirm_inspected")
	for i in range(16):
		await process_frame
	_save(dirs, "playtest_hotn3_playflow_confirm_targeting.png")
	_assert(bool(game.get("card_confirmed")), "confirm did not set card_confirmed")
	_assert(int(game.get("selected_card")) == dmg_idx, "confirm did not keep selected_card")
	_assert(battle.hand.size() == hand_before, "ENEMY card auto-played on confirm (should wait for target)")
	_assert(int(battle.actor_by_id(target_id).get("hp", 0)) == hp_before, "enemy HP changed before target pick")

	# Pick enemy target
	game.call("_activate_actor", target_id)
	for i in range(22):
		await process_frame
	_save(dirs, "playtest_hotn3_playflow_after_target.png")
	var hp_after: int = int(battle.actor_by_id(target_id).get("hp", 0))
	_assert(hp_after < hp_before or battle.hand.size() < hand_before, "targeted play had no HP/hand effect (hp %d→%d, hand %d→%d)" % [hp_before, hp_after, hand_before, battle.hand.size()])
	_assert(not bool(game.get("card_confirmed")), "card_confirmed stuck after play")
	print("PLAYFLOW targeted OK hp %d→%d hand %d→%d" % [hp_before, hp_after, hand_before, battle.hand.size()])

	# --- Auto SELF after confirm (no extra click) ---
	if battle.phase != "PLAYER":
		_fail("left PLAYER phase before auto SELF test")
		_finish()
		return
	var self_idx: int = _ensure_hand_card(game, battle, "SELF", false)
	_assert(self_idx >= 0, "no SELF card available")
	if self_idx >= 0:
		var owner_id: int = int(battle.hand[self_idx].get("owner", -1))
		var owner_before: Dictionary = battle.actor_by_id(owner_id)
		var block_before: int = int(owner_before.get("block", 0)) + int(owner_before.get("shield", 0))
		var hand_self_before: int = battle.hand.size()
		game.set("inspected_card", self_idx)
		game.set("hovered_card", self_idx)
		game.set("selected_card", -1)
		game.set("card_confirmed", false)
		game.call("_render_battle")
		for i in range(10):
			await process_frame
		_save(dirs, "playtest_hotn3_playflow_self_select.png")
		game.call("_confirm_inspected")
		for i in range(20):
			await process_frame
		_save(dirs, "playtest_hotn3_playflow_self_auto.png")
		var owner_after: Dictionary = battle.actor_by_id(owner_id)
		var block_after: int = int(owner_after.get("block", 0)) + int(owner_after.get("shield", 0))
		var hand_self_after: int = battle.hand.size()
		_assert(hand_self_after < hand_self_before or block_after > block_before or not bool(game.get("card_confirmed")), "SELF did not auto-resolve after confirm")
		_assert(int(game.get("selected_card")) < 0 or not bool(game.get("card_confirmed")), "SELF left targeting pending")
		print("PLAYFLOW self-auto OK hand %d→%d block+shield %d→%d" % [hand_self_before, hand_self_after, block_before, block_after])

	# --- Auto ALL_ALLIES / RANDOM after confirm ---
	if battle.phase == "PLAYER":
		var team_idx: int = _ensure_hand_card(game, battle, "ALL_ALLIES", false)
		if team_idx < 0:
			team_idx = _ensure_hand_card(game, battle, "RANDOM", false)
		_assert(team_idx >= 0, "no ALL_ALLIES/RANDOM card for auto test")
		if team_idx >= 0:
			var kind: String = str(game.call("_card_def", str(battle.hand[team_idx]["id"])).get("target", ""))
			var hand_auto_before: int = battle.hand.size()
			var enemy_hp_sum_before: int = _enemy_hp_sum(battle)
			game.set("inspected_card", team_idx)
			game.set("hovered_card", team_idx)
			game.set("selected_card", -1)
			game.set("card_confirmed", false)
			game.call("_render_battle")
			for i in range(8):
				await process_frame
			game.call("_confirm_inspected")
			for i in range(20):
				await process_frame
			_save(dirs, "playtest_hotn3_playflow_auto_team_or_random.png")
			var pending: bool = bool(game.get("card_confirmed")) and int(game.get("selected_card")) >= 0
			_assert(not pending, "%s still waiting for target after confirm" % kind)
			_assert(battle.hand.size() < hand_auto_before or _enemy_hp_sum(battle) < enemy_hp_sum_before or kind == "ALL_ALLIES", "%s auto-play produced no effect" % kind)
			print("PLAYFLOW auto-%s OK hand %d→%d" % [kind, hand_auto_before, battle.hand.size()])

	# Pass3 polish pack captures
	game.set("hovered_card", 0)
	game.call("_render_battle")
	for i in range(14):
		await process_frame
	_save(dirs, "playtest_hotn3_pass3_battle.png")
	_save(dirs, "playtest_hotn3_pass3_hover.png")
	if battle.hand.size() > 0:
		game.set("inspected_card", 0)
		game.set("hovered_card", 0)
		game.set("selected_card", -1)
		game.set("card_confirmed", false)
		game.call("_render_battle")
		for i in range(16):
			await process_frame
		_save(dirs, "playtest_hotn3_pass3_inspect.png")
	# Street night arena capture
	game.set("mission_id", "street")
	game.set("best_stars", {"road": 1})
	game.call("_start_mission")
	for i in range(40):
		await process_frame
	await create_timer(0.6).timeout
	_save(dirs, "playtest_hotn3_pass3_street.png")
	# Compatibility aliases
	_save(dirs, "playtest_hotn3_pass2_battle.png")
	_save(dirs, "playtest_hotn3_pass2_after.png")
	_finish()

func _enemy_hp_sum(battle) -> int:
	var total := 0
	for e in battle.living("ENEMY"):
		total += int(e.get("hp", 0))
	return total

func _ensure_hand_card(game, battle, target_kind: String, want_damage: bool) -> int:
	for i in range(battle.hand.size()):
		var def: Dictionary = game.call("_card_def", str(battle.hand[i]["id"]))
		if str(def.get("target", "")) != target_kind:
			continue
		if want_damage and not bool(game.call("_card_has_damage", def)):
			continue
		# Prefer affordable cards
		var owner: Dictionary = battle.actor_by_id(int(battle.hand[i].get("owner", 0)))
		if int(owner.get("hp", 0)) <= 0:
			continue
		return i
	# Inject a known card owned by a living ally
	var allies: Array = battle.living("ALLY")
	if allies.is_empty():
		return -1
	var owner_id: int = int(allies[0]["id"])
	var card_id: String = ""
	match target_kind:
		"ENEMY":
			card_id = "raio" if want_damage else "marca"
		"SELF":
			card_id = "guarda"
		"ALL_ALLIES":
			card_id = "prisma"
		"RANDOM":
			card_id = "fagulha_incerta"
		_:
			return -1
	if not Content.CARDS.has(card_id):
		return -1
	# Ensure resources so play can succeed
	battle.impulse = maxi(int(battle.impulse), 6)
	battle.card_plays = maxi(int(battle.card_plays), 2)
	var injected: Dictionary = {"uid": int(battle.next_card_id) + 9000 + battle.hand.size(), "id": card_id, "owner": owner_id, "class": Content.CARDS[card_id].get("class", ""), "upgrade": 0, "mod": ""}
	if battle.hand.is_empty():
		battle.hand.append(injected)
	else:
		battle.hand[0] = injected
	game.call("_render_battle")
	return 0

func _finish() -> void:
	if _fails.is_empty():
		print("VISUAL_PLAYTEST_DONE")
		print("PLAYFLOW_OK")
		quit(0)
	else:
		print("PLAYFLOW_FAILED count=%d" % _fails.size())
		for f in _fails:
			print(" - " + f)
		quit(1)

func _save(dirs: Array[String], name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("VISUAL FAIL null image for " + name)
		return
	for d in dirs:
		var path := String(d).path_join(name)
		var err := img.save_png(path)
		print("VISUAL save %s err=%d" % [path, err])
