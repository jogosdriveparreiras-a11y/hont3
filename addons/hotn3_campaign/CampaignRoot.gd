extends "res://game/GameRoot.gd"

const StoryPath := "res://addons/hotn3_campaign/story.json"
const SavePath := "user://hotn3_campaign.cfg"
const CampaignView = preload("res://addons/hotn3_campaign/CampaignView.gd")
const CampaignArenaBuilder = preload("res://addons/hotn3_campaign/ArenaBuilder.gd")
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
var active_battle: Dictionary = {}
var campaign_view: CampaignView
var original_music: AudioStream
var _boot_open_campaign := true

func _ready() -> void:
	_read_story()
	_load_campaign()
	super._ready()
	if original_music == null and sound != null:
		original_music = sound.music.stream

func _show_menu() -> void:
	# Após change_scene a partir do título do GameRoot, não remontar o menu 3D —
	# isso fazia Campanha "voltar ao título". Entra direto na VN uma vez.
	if _boot_open_campaign and not campaign_story.is_empty():
		_boot_open_campaign = false
		battle_menu_open = false
		if battle != null:
			battle = null
		if presentation != null:
			presentation.drive_camera = false
			presentation.clear_actors()
		if sound != null and original_music == null:
			original_music = sound.music.stream
		_teardown_title_screen()
		_open_campaign()
		return
	_boot_open_campaign = false
	super._show_menu()

func _launch_campaign_module() -> void:
	# Já estamos no CampaignRoot: abre a narrativa no lugar (sem recarregar a cena).
	if sound != null and original_music == null:
		original_music = sound.music.stream
	_teardown_title_screen()
	_open_campaign()

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

func _add_campaign_menu_button(menu: VBoxContainer) -> void:
	# Não chama super: o botão base troca de cena; aqui a VN abre no próprio CampaignRoot.
	var title := "Campanha · rever final" if campaign_phase == "complete" else ("Campanha · continuar" if campaign_phase != "new" else "Campanha")
	menu.add_child(_button(title, _open_campaign, "A Fenda das Três Vigílias · três capítulos"))
	if campaign_phase != "new":
		menu.add_child(_button("Reiniciar narrativa", _new_campaign, "Recomeça as cenas; mantém cartas já conquistadas."))

func _build_arena(theme: String = "default") -> void:
	if not theme.begins_with("campaign_"):
		super._build_arena(theme)
		return
	# Limpa o stage e adiciona guias com a API atual do jogo (HotNArenaBuilder).
	HotNArenaBuilder.clear(stage)
	var arena := CampaignArenaBuilder.new()
	arena.name = theme
	stage.add_child(arena)
	arena.build(theme)
	HotNArenaBuilder._row_guides(stage, battle_view_mode)

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
	campaign_team = _default_team()
	battle_team.clear()
	reward_offers.clear()
	active_battle.clear()
	campaign_scene = str(campaign_story.get("start_scene", "prologue"))
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
	campaign_active = true
	if campaign_phase == "reward" and not reward_offers.is_empty():
		_show_reward()
	elif campaign_phase in ["team", "battle", "defeat"]:
		_restore_active_battle()
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
	_teardown_title_screen()
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
				active_battle = _battle_config(entry, data)
				_prepare_team()
				return
			"jump":
				var destination := str(entry.get("scene", ""))
				if campaign_story["scenes"].has(destination):
					campaign_scene = destination
					scene_step = 0
					_enter_scene()
					return
				scene_step += 1
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
	var flag := str(option.get("flag", ""))
	if flag != "": campaign_flags[flag] = option.get("value", true)
	var destination := str(option.get("goto", ""))
	if destination != "" and campaign_story["scenes"].has(destination):
		campaign_scene = destination
		scene_step = 0
		_save_campaign()
		_enter_scene()
		return
	scene_step += 1
	_save_campaign()
	_show_step()

func _battle_config(entry: Dictionary, scene: Dictionary = {}) -> Dictionary:
	var mission := str(entry.get("mission", ""))
	if mission == "":
		var legacy := ["road", "ritual", "eclipse"]
		mission = str(legacy[clampi(int(entry.get("index", 0)), 0, legacy.size() - 1)])
	var required: Array = entry.get("required_party", [Lead])
	if required.is_empty(): required = [Lead]
	var party_size := maxi(required.size(), int(entry.get("party_size", 3)))
	return {
		"mission": mission,
		"required_party": required,
		"party_size": party_size,
		"enemy_pool": entry.get("enemy_pool", []),
		"next": str(entry.get("next", scene.get("next", ""))),
		"arena": str(entry.get("arena", scene.get("arena", "campaign_road"))),
		"bgm": str(entry.get("battle_bgm", "")),
		"reward_count": maxi(1, int(entry.get("reward_count", 3)))
	}

func _enemy_roster() -> Dictionary:
	var banned := {}
	for raw in active_battle.get("enemy_pool", []): banned[str(raw)] = true
	if not banned.is_empty(): return banned
	var mission: Dictionary = Content.MISSIONS.get(str(active_battle.get("mission", "")), {})
	for enemy_id in mission.get("enemies", []): banned[str(enemy_id)] = true
	for wave in mission.get("reinforcements", {}).values():
		for enemy_id in wave: banned[str(enemy_id)] = true
	return banned

func _default_team() -> Array[String]:
	var result: Array[String] = []
	for raw in active_battle.get("required_party", [Lead]):
		var id := str(raw)
		if Content.HEROES.has(id) and not result.has(id): result.append(id)
	var blocked := _enemy_roster()
	var need := int(active_battle.get("party_size", 3))
	for id in Content.HEROES:
		if result.size() >= need: break
		var hero: Dictionary = Content.HEROES[id]
		if bool(hero.get("playable", true)) and not blocked.has(str(id)) and not result.has(str(id)):
			result.append(str(id))
	return result

func _team_is_valid(ids: Array[String]) -> bool:
	if ids.size() != int(active_battle.get("party_size", 3)): return false
	var required: Array = active_battle.get("required_party", [Lead])
	var banned := _enemy_roster()
	var seen := {}
	for id in ids:
		if seen.has(id) or banned.has(id) or not Content.HEROES.has(id): return false
		if not bool(Content.HEROES[id].get("playable", true)): return false
		seen[id] = true
	for raw in required:
		if not ids.has(str(raw)): return false
	return true

func _restore_active_battle() -> void:
	if not active_battle.is_empty(): return
	var data: Dictionary = campaign_story.get("scenes", {}).get(campaign_scene, {})
	for raw in data.get("steps", []):
		var entry: Dictionary = raw
		if str(entry.get("type", "")) == "battle":
			active_battle = _battle_config(entry, data)
			return

func _prepare_team() -> void:
	_restore_active_battle()
	if active_battle.is_empty(): return
	campaign_active = true
	campaign_phase = "team"
	_teardown_title_screen()
	_clear_ui()
	_clear_combat_visuals()
	_build_arena(str(active_battle.get("arena", "campaign_road")))
	var scene: Dictionary = campaign_story.get("scenes", {}).get(campaign_scene, {})
	_play_campaign_music(str(scene.get("bgm", "")))
	if not _team_is_valid(campaign_team): campaign_team = _default_team()
	var mission: Dictionary = Content.MISSIONS.get(str(active_battle.get("mission", "")), {})
	var name := str(mission.get("name", active_battle.get("mission", "Batalha")))
	var overlay := _view()
	overlay.set_meta("battle_name", name)
	overlay.show_team(Content.HEROES, campaign_team, _enemy_roster(), name, active_battle.get("required_party", [Lead]), int(active_battle.get("party_size", 3)))
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
	if not _team_is_valid(team) or active_battle.is_empty(): return
	campaign_phase = "battle"
	mission_id = str(active_battle.get("mission", ""))
	if not Content.MISSIONS.has(mission_id): return
	pack_mode = "default"
	_ensure_owned_cards()
	equipped = _build_equipped_from_owned()
	_view().hide()
	_begin_battle_session()
	_build_arena(str(active_battle.get("arena", "campaign_road")))
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
	_play_campaign_music(str(active_battle.get("bgm", "")))
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
		_view().show_defeat(str(Content.MISSIONS.get(mission_id, {}).get("name", mission_id)))

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
		# Uma carta Melhorada só é elegível quando sua base já pertence ao jogador.
		for raw in hero.get("melhoradas", []):
			var improved := str(raw)
			var base := str(Content.CARDS.get(improved, {}).get("melhorada_de", ""))
			if base != "" and owned_cards.get(hero_id, []).has(base): list.append(improved)
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
			var chosen := str(cards[options.size() % cards.size()])
			options.append({"owner": hero_id, "card": chosen})
			cards.erase(chosen)
	# Em uma coleção parcialmente completa, as vagas restantes continuam
	# restritas às cartas dos três integrantes desta batalha.
	while options.size() < int(active_battle.get("reward_count", 3)):
		var grew := false
		for hero_id in battle_team:
			var cards: Array = eligible.get(hero_id, [])
			if cards.is_empty(): continue
			options.append({"owner": hero_id, "card": cards.pop_front()})
			grew = true
			if options.size() == int(active_battle.get("reward_count", 3)): break
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
	var destination := str(active_battle.get("next", ""))
	if destination == "" or not campaign_story.get("scenes", {}).has(destination):
		campaign_phase = "complete"
		_save_campaign()
		_view().show_ending()
		return
	campaign_scene = destination
	scene_step = 0
	campaign_phase = "story"
	active_battle.clear()
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
	config.set_value("story", "active_battle", active_battle)
	config.save(SavePath)

func _load_campaign() -> void:
	var config := ConfigFile.new()
	if config.load(SavePath) != OK: return
	var scene_id := str(config.get_value("story", "scene", campaign_story.get("start_scene", "prologue")))
	if campaign_story.get("scenes", {}).has(scene_id): campaign_scene = scene_id
	scene_step = maxi(0, int(config.get_value("story", "step", 0)))
	battle_index = maxi(0, int(config.get_value("story", "battle", 0)))
	campaign_phase = str(config.get_value("story", "phase", "new"))
	campaign_flags = config.get_value("story", "flags", {})
	var stored_team: Array = config.get_value("story", "team", [])
	if not stored_team.is_empty():
		campaign_team.clear()
		for id in stored_team: campaign_team.append(str(id))
	var stored_battle_team: Array = config.get_value("story", "battle_team", [])
	for id in stored_battle_team: battle_team.append(str(id))
	reward_offers = config.get_value("story", "offers", [])
	active_battle = config.get_value("story", "active_battle", {})
	if campaign_phase == "battle": campaign_phase = "team"
