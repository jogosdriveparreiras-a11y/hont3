extends "res://game/GameRoot.gd"

const StoryPath := "res://addons/hotn3_campaign/story.json"
const SavePath := "user://hotn3_campaign.cfg"
const CampaignView = preload("res://addons/hotn3_campaign/CampaignView.gd")
const ArenaBuilder = preload("res://addons/hotn3_campaign/ArenaBuilder.gd")
const Battles = ["road", "ritual", "eclipse"]
const SceneOrder = ["prologue", "after_road", "after_ritual", "ending"]
const BattleMusic = ["res://assets/audio/bgm/Battle2.ogg", "res://assets/audio/bgm/Battle5.ogg", "res://assets/audio/bgm/Battle8.ogg"]
const Lead := "ent_alyssa_wine"

var campaign_story: Dictionary = {}
var campaign_flags: Dictionary = {}
var campaign_team: Array[String] = [Lead, "ent_madelyn", "ent_ashlee"]
var battle_team: Array[String] = []
var campaign_scene := "prologue"
var scene_step := 0
var battle_index := 0
var campaign_phase := "new"
var campaign_active := false
var right_portrait_id := ""
var reward_offers: Array = []
var campaign_view: CampaignView
var original_music: AudioStream

func _ready() -> void:
	_read_story()
	_load_campaign()
	super._ready()
	original_music = sound.music.stream

func _read_story() -> void:
	var file := FileAccess.open(StoryPath, FileAccess.READ)
	if file == null:
		push_error("Campanha sem roteiro: " + StoryPath)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("scenes"):
		campaign_story = parsed
	else:
		push_error("Roteiro da campanha inválido")

func _show_menu() -> void:
	super._show_menu()
	var menu: VBoxContainer = null
	for candidate in hud.find_children("*", "VBoxContainer", true, false):
		for node in candidate.get_children():
			if node is Button and str(node.text).begins_with("Selecionar missão"):
				menu = candidate as VBoxContainer
				break
		if menu != null: break
	if menu == null: return
	var title := "Campanha · rever final" if campaign_phase == "complete" else ("Campanha · continuar" if campaign_phase != "new" else "Campanha")
	var button := _button(title, _open_campaign, "A Fenda das Três Vigílias · três capítulos")
	menu.add_child(button)
	menu.move_child(button, 2)
	if campaign_phase != "new":
		menu.add_child(_button("Reiniciar narrativa", _new_campaign, "Recomeça as cenas; mantém cartas já conquistadas."))

func _build_arena(theme: String = "default") -> void:
	if not theme.begins_with("campaign_"):
		super._build_arena(theme)
		return
	_clear_arena()
	var arena := ArenaBuilder.new()
	arena.name = theme
	stage.add_child(arena)
	arena.build(theme)
	_add_row_guide_lines()

func _view() -> CampaignView:
	if is_instance_valid(campaign_view): return campaign_view
	campaign_view = CampaignView.new()
	add_child(campaign_view)
	campaign_view.next_line.connect(_next_line)
	campaign_view.option_selected.connect(_choose_option)
	campaign_view.team_selected.connect(_confirm_team)
	campaign_view.card_selected.connect(_claim_card)
	campaign_view.retry_battle.connect(_prepare_team)
	campaign_view.exit_campaign.connect(_exit_campaign)
	return campaign_view

func _new_campaign() -> void:
	campaign_flags.clear()
	campaign_team = [Lead, "ent_madelyn", "ent_ashlee"]
	battle_team.clear()
	reward_offers.clear()
	campaign_scene = "prologue"
	scene_step = 0
	battle_index = 0
	campaign_phase = "story"
	campaign_active = true
	_save_campaign()
	_enter_scene()

func _open_campaign() -> void:
	if campaign_story.is_empty(): return
	if campaign_phase == "new":
		_new_campaign()
		return
	if campaign_phase == "complete":
		campaign_scene = "ending"
		scene_step = 0
		campaign_phase = "story"
	if not _team_is_valid(campaign_team):
		campaign_team = [Lead, "ent_madelyn", "ent_ashlee"]
	campaign_active = true
	if campaign_phase == "reward" and not reward_offers.is_empty():
		_show_reward()
	elif campaign_phase in ["team", "battle", "defeat"]:
		_prepare_team()
	else:
		_enter_scene()

func _enter_scene() -> void:
	if campaign_story.is_empty(): return
	var data: Dictionary = campaign_story["scenes"].get(campaign_scene, {})
	if data.is_empty(): return
	campaign_active = true
	campaign_phase = "story"
	right_portrait_id = ""
	_clear_ui()
	_clear_combat_visuals()
	_build_arena(str(data.get("arena", "campaign_road")))
	if portrait_left != null: portrait_left.hide()
	if portrait_right != null: portrait_right.hide()
	_play_campaign_music(str(data.get("bgm", "")))
	_view().show()
	_save_campaign()
	_show_step()

func _show_step() -> void:
	var data: Dictionary = campaign_story["scenes"].get(campaign_scene, {})
	var steps: Array = data.get("steps", [])
	while scene_step < steps.size():
		var entry: Dictionary = steps[scene_step]
		if entry.has("if") and not bool(campaign_flags.get(str(entry["if"]), false)):
			scene_step += 1
			continue
		if entry.has("unless") and bool(campaign_flags.get(str(entry["unless"]), false)):
			scene_step += 1
			continue
		match str(entry.get("type", "line")):
			"line":
				if entry.has("right"):
					right_portrait_id = str(entry["right"])
				campaign_view.show_line(str(data.get("title", "Campanha")), entry, _format_text(str(entry.get("text", ""))), right_portrait_id, str(data.get("weather", "rain")))
				return
			"choice":
				campaign_view.show_choices(entry.get("options", []))
				return
			"battle":
				battle_index = int(entry.get("index", battle_index))
				_prepare_team()
				return
			"end":
				campaign_phase = "complete"
				_save_campaign()
				campaign_view.show_ending()
				return
			_:
				scene_step += 1
	# Um roteiro sem encerramento explícito não inicia outra luta por acidente.
	push_error("Fim inesperado da cena de campanha: " + campaign_scene)

func _format_text(value: String) -> String:
	var result := value
	for offset in [1, 2]:
		var id := campaign_team[offset] if campaign_team.size() > offset else Lead
		result = result.replace("{ally%d}" % offset, str(Content.HEROES.get(id, {}).get("name", id)))
	return result

func _next_line() -> void:
	if campaign_phase != "story": return
	scene_step += 1
	_save_campaign()
	_show_step()

func _choose_option(option: Dictionary) -> void:
	if campaign_phase != "story": return
	var data: Dictionary = campaign_story["scenes"].get(campaign_scene, {})
	var steps: Array = data.get("steps", [])
	if scene_step >= steps.size() or str(steps[scene_step].get("type", "")) != "choice": return
	if not steps[scene_step].get("options", []).has(option): return
	campaign_flags[str(option.get("flag", ""))] = bool(option.get("value", false))
	scene_step += 1
	_save_campaign()
	_show_step()

func _enemy_roster() -> Dictionary:
	var banned := {}
	for mid in Battles:
		var mission: Dictionary = Content.MISSIONS[mid]
		for enemy_id in mission.get("enemies", []): banned[str(enemy_id)] = true
		for wave in mission.get("reinforcements", {}).values():
			for enemy_id in wave: banned[str(enemy_id)] = true
	return banned

func _team_is_valid(ids: Array[String]) -> bool:
	if ids.size() != 3 or ids[0] != Lead: return false
	var banned := _enemy_roster()
	var seen := {}
	for id in ids:
		if seen.has(id) or banned.has(id) or not Content.HEROES.has(id): return false
		if not bool(Content.HEROES[id].get("playable", true)): return false
		seen[id] = true
	return true

func _prepare_team() -> void:
	campaign_active = true
	campaign_phase = "team"
	_clear_ui()
	_clear_combat_visuals()
	var chapter := clampi(battle_index, 0, Battles.size() - 1)
	var data: Dictionary = campaign_story["scenes"].get(SceneOrder[chapter], {})
	_build_arena(str(data.get("arena", "campaign_road")))
	_play_campaign_music(str(data.get("bgm", "")))
	if not _team_is_valid(campaign_team): campaign_team = [Lead, "ent_madelyn", "ent_ashlee"]
	var overlay := _view()
	overlay.set_meta("battle_name", str(Content.MISSIONS[Battles[chapter]]["name"]))
	overlay.show_team(Content.HEROES, campaign_team, _enemy_roster(), str(Content.MISSIONS[Battles[chapter]]["name"]))
	_save_campaign()

func _confirm_team(ids: Array) -> void:
	var selection: Array[String] = []
	for raw in ids: selection.append(str(raw))
	if not _team_is_valid(selection): return
	campaign_team = selection.duplicate()
	battle_team = selection.duplicate()
	team = selection.duplicate()
	_save_campaign()
	_start_campaign_battle()

func _start_campaign_battle() -> void:
	if not _team_is_valid(team) or battle_index < 0 or battle_index >= Battles.size(): return
	campaign_phase = "battle"
	mission_id = Battles[battle_index]
	pack_mode = "default"
	_ensure_owned_cards()
	equipped = _build_equipped_from_owned()
	_view().hide()
	_begin_battle_session()
	_build_arena("campaign_" + ("road" if battle_index == 0 else ("ritual" if battle_index == 1 else "eclipse")))
	var all_entities := team.all(func(id): return str(id).begins_with("ent_"))
	if all_entities:
		pack_mode = "entities"
		var ids: Array[String] = []
		for id in team: ids.append(str(id))
		if not packs.entities.deploy(battle, mission_id, ids, equipped, 0):
			pack_mode = "default"
			battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	else:
		battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	_apply_accessibility()
	_play_campaign_music(BattleMusic[battle_index])
	_save_campaign()
	_render_battle()

func _on_finished(won: bool) -> void:
	if not campaign_active or campaign_phase != "battle":
		super._on_finished(won)
		return
	if won:
		sound.cue("victory")
		_award_victory(_mission_stars())
		_save_config()
		reward_offers = _reward_cards()
		campaign_phase = "reward"
		_save_campaign()
		_show_reward()
	else:
		sound.cue("death")
		campaign_phase = "defeat"
		_save_campaign()
		_clear_ui()
		_view().show_defeat(str(Content.MISSIONS[Battles[battle_index]]["name"]))

func _reward_cards() -> Array:
	_ensure_owned_cards()
	var options: Array = []
	var eligible: Dictionary = {}
	for hero_id in battle_team:
		var hero: Dictionary = Content.HEROES.get(hero_id, {})
		var list: Array = []
		for raw in hero.get("evoluidas", []): list.append(str(raw))
		for raw in hero.get("pool", hero.get("cards", [])):
			if not list.has(str(raw)): list.append(str(raw))
		var available: Array = []
		var already: Array = owned_cards.get(hero_id, [])
		for raw in list:
			var cid := str(raw)
			var definition: Dictionary = Content.CARDS.get(cid, {})
			if definition.is_empty() or str(definition.get("class", "")) == "DESVANTAGEM" or already.has(cid): continue
			available.append(cid)
		eligible[hero_id] = available
	# Primeiro oferece uma carta nova de cada combatente.
	for hero_id in battle_team:
		var cards: Array = eligible.get(hero_id, [])
		if not cards.is_empty():
			var chosen := str(cards[battle_index % cards.size()])
			options.append({"owner": hero_id, "card": chosen})
			cards.erase(chosen)
	# Em uma coleção parcialmente completa, as vagas restantes continuam
	# restritas às cartas dos três integrantes desta batalha.
	while options.size() < 3:
		var grew := false
		for hero_id in battle_team:
			var cards: Array = eligible.get(hero_id, [])
			if cards.is_empty(): continue
			options.append({"owner": hero_id, "card": cards.pop_front()})
			grew = true
			if options.size() == 3: break
		if not grew: break
	return options

func _show_reward() -> void:
	_clear_ui()
	_clear_combat_visuals()
	var overlay := _view()
	if reward_offers.is_empty():
		# Só ocorre se todas as cartas elegíveis dos combatentes já estão na coleção.
		overlay.show_reward([])
		_finalize_victory()
	else:
		overlay.show_reward(reward_offers)

func _claim_card(option: Dictionary) -> void:
	if campaign_phase != "reward" or not reward_offers.has(option): return
	var owner_id := str(option.get("owner", ""))
	var cid := str(option.get("card", ""))
	if not battle_team.has(owner_id) or not Content.CARDS.has(cid): return
	_grant_owned_card(owner_id, cid)
	_save_config()
	_finalize_victory()

func _finalize_victory() -> void:
	reward_offers.clear()
	battle_index += 1
	campaign_scene = SceneOrder[mini(battle_index, SceneOrder.size() - 1)]
	scene_step = 0
	campaign_phase = "story"
	_save_campaign()
	_enter_scene()

func _play_campaign_music(path: String) -> void:
	if sound == null or sound.music == null or not ResourceLoader.exists(path): return
	var track := load(path) as AudioStream
	if track == null: return
	if sound.music.stream == track and sound.music.playing: return
	sound.music.stop()
	sound.music.stream = track
	sound.set_level("MUSIC", float(sound_levels.get("MUSIC", 0.35)))
	sound.music.play()

func _exit_campaign() -> void:
	campaign_active = false
	if is_instance_valid(campaign_view): campaign_view.hide()
	if sound != null and original_music != null:
		sound.music.stop()
		sound.music.stream = original_music
		sound.music.play()
	_show_menu()

func _save_campaign() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "scene", campaign_scene)
	config.set_value("story", "step", scene_step)
	config.set_value("story", "battle", battle_index)
	config.set_value("story", "phase", campaign_phase)
	config.set_value("story", "flags", campaign_flags)
	config.set_value("story", "team", campaign_team)
	config.set_value("story", "battle_team", battle_team)
	config.set_value("story", "offers", reward_offers)
	config.save(SavePath)

func _load_campaign() -> void:
	var config := ConfigFile.new()
	if config.load(SavePath) != OK: return
	var scene_id := str(config.get_value("story", "scene", "prologue"))
	if campaign_story.get("scenes", {}).has(scene_id): campaign_scene = scene_id
	scene_step = maxi(0, int(config.get_value("story", "step", 0)))
	battle_index = clampi(int(config.get_value("story", "battle", 0)), 0, Battles.size())
	campaign_phase = str(config.get_value("story", "phase", "new"))
	campaign_flags = config.get_value("story", "flags", {})
	var stored_team: Array = config.get_value("story", "team", [])
	if stored_team.size() == 3:
		campaign_team.clear()
		for id in stored_team: campaign_team.append(str(id))
	var stored_battle_team: Array = config.get_value("story", "battle_team", [])
	for id in stored_battle_team: battle_team.append(str(id))
	reward_offers = config.get_value("story", "offers", [])
	if campaign_phase == "battle": campaign_phase = "team"
