extends "res://game/GameRoot.gd"

const StoryPath := "res://addons/hotn3_campaign/story.json"
const CampaignDirectory := "res://campaigns"
const SavePath := "user://hotn3_campaign.cfg"
const CampaignView = preload("res://addons/hotn3_campaign/CampaignView.gd")
const CampaignArenaBuilder = preload("res://addons/hotn3_campaign/ArenaBuilder.gd")
const Lead := "ent_alyssa_wine"

var campaign_story: Dictionary = {}
var campaign_sources: Dictionary = {}
var campaign_flags: Dictionary = {}
var campaign_id := ""
var campaign_unlocked: Dictionary = {}
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
var reward_return := "battle"
var pending_reward_bundle: Array = []
var pending_reward_draw := false
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
	# A entrada Campanha sempre começa na lista, inclusive após change_scene do título.
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
		_show_campaign_list()
		return
	_boot_open_campaign = false
	super._show_menu()

func _launch_campaign_module() -> void:
	# Mostra os roteiros instalados antes de entrar em uma campanha.
	if sound != null and original_music == null:
		original_music = sound.music.stream
	_teardown_title_screen()
	_show_campaign_list()

func _read_story() -> void:
	var file := FileAccess.open(StoryPath, FileAccess.READ)
	if file == null:
		push_error("Campanha sem roteiro: " + StoryPath)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("scenes"):
		campaign_story = _normalize_story(parsed)
		campaign_sources.clear()
		for definition in campaign_story.get("campaigns", []): campaign_sources[str(definition.get("id", ""))] = StoryPath.get_file()
		_append_campaign_files()
		campaign_id = str(campaign_story.get("start_campaign", campaign_story["campaigns"][0].get("id", "campanha_principal")))
	else:
		push_error("Roteiro da campanha inválido")

func _normalize_story(source: Dictionary) -> Dictionary:
	var normalized := source.duplicate(true)
	if normalized.get("adventures", {}).is_empty():
		normalized["adventures"] = {"aventura_principal": {"id": "aventura_principal", "title": str(normalized.get("title", "Aventura")), "scene_ids": normalized.get("scenes", {}).keys()}}
	if normalized.get("campaigns", []).is_empty():
		normalized["campaigns"] = [{"id": "campanha_principal", "title": str(normalized.get("title", "Campanha")), "required_party": [str(normalized.get("protagonist", Lead))], "party_size": 3, "adventures": normalized["adventures"].keys()}]
	if not normalized.get("campaigns", []).any(func(entry): return typeof(entry) == TYPE_DICTIONARY):
		normalized["campaigns"] = [{"id": "campanha_principal", "title": str(normalized.get("title", "Campanha")), "required_party": [], "party_size": 3, "adventures": normalized["adventures"].keys()}]
	if not normalized.get("start_campaign", "") in normalized["campaigns"].map(func(entry): return str(entry.get("id", ""))):
		normalized["start_campaign"] = str(normalized["campaigns"][0].get("id", "campanha_principal"))
	if not normalized.has("start_scene"):
		normalized["start_scene"] = str(normalized["scenes"].keys()[0]) if not normalized["scenes"].is_empty() else ""
	return normalized

func _append_campaign_files() -> void:
	var paths: Array[String] = []
	_collect_json_files("res://", paths)
	_collect_json_files(CampaignDirectory, paths)
	_collect_json_files("user://campaigns", paths)
	if not Engine.is_editor_hint():
		var executable_dir := OS.get_executable_path().get_base_dir()
		_collect_json_files(executable_dir, paths)
		_collect_json_files(executable_dir.path_join("campaigns"), paths)
	paths.sort()
	var seen: Dictionary = {}
	var contents_seen: Dictionary = {}
	for path in paths:
		if path == StoryPath or seen.has(path): continue
		seen[path] = true
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: continue
		var source_text := file.get_as_text()
		var fingerprint := source_text.sha256_text()
		if contents_seen.has(fingerprint): continue
		contents_seen[fingerprint] = true
		var parsed: Variant = JSON.parse_string(source_text)
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("scenes"): continue
		var prefix := path.get_file().get_basename().to_snake_case()
		if prefix == "": continue
		var suffix := 2
		while campaign_story["campaigns"].any(func(entry): return str(entry.get("id", "")).begins_with(prefix + "__")):
			prefix = path.get_file().get_basename().to_snake_case() + "_" + str(suffix)
			suffix += 1
		_append_campaign_package(_normalize_story(parsed), prefix, path.get_file())

func _collect_json_files(directory_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null: return
	for filename in directory.get_files():
		if filename.get_extension().to_lower() == "json": result.append(directory_path.path_join(filename))

func _append_campaign_package(package: Dictionary, prefix: String, source_name: String) -> void:
	var scene_ids: Dictionary = {}
	var adventure_ids: Dictionary = {}
	var campaign_ids: Dictionary = {}
	for id in package.get("scenes", {}).keys(): scene_ids[str(id)] = prefix + "__" + str(id)
	for id in package.get("adventures", {}).keys(): adventure_ids[str(id)] = prefix + "__" + str(id)
	for definition in package.get("campaigns", []):
		var local_id := str(definition.get("id", "campanha_principal"))
		campaign_ids[local_id] = prefix + "__" + local_id
	for local_id in package.get("scenes", {}):
		var scene: Dictionary = package["scenes"][local_id].duplicate(true)
		if scene.has("next"): scene["next"] = scene_ids.get(str(scene["next"]), str(scene["next"]))
		for step in scene.get("steps", []):
			if step.has("scene"): step["scene"] = scene_ids.get(str(step["scene"]), str(step["scene"]))
			if step.has("next"): step["next"] = scene_ids.get(str(step["next"]), str(step["next"]))
			for option in step.get("options", []):
				if option.has("goto"): option["goto"] = scene_ids.get(str(option["goto"]), str(option["goto"]))
		campaign_story["scenes"][scene_ids[str(local_id)]] = scene
	for local_id in package.get("adventures", {}):
		var adventure: Dictionary = package["adventures"][local_id].duplicate(true)
		adventure["id"] = adventure_ids[str(local_id)]
		adventure["scene_ids"] = adventure.get("scene_ids", []).map(func(id): return scene_ids.get(str(id), str(id)))
		campaign_story["adventures"][adventure_ids[str(local_id)]] = adventure
	for definition in package.get("campaigns", []):
		var campaign: Dictionary = definition.duplicate(true)
		var local_id := str(campaign.get("id", "campanha_principal"))
		var unique_id: String = campaign_ids[local_id]
		campaign["id"] = unique_id
		campaign["source_file"] = source_name
		campaign["adventures"] = campaign.get("adventures", []).map(func(id): return adventure_ids.get(str(id), str(id)))
		var package_start := str(campaign.get("start_scene", package.get("start_scene", "")))
		if package_start != "": campaign["start_scene"] = scene_ids.get(package_start, package_start)
		campaign_story["campaigns"].append(campaign)
		campaign_sources[unique_id] = source_name

func _add_campaign_menu_button(menu: VBoxContainer) -> void:
	# Cada entrada escolhe uma campanha do roteiro; o save da campanha em curso continua separado.
	for raw in campaign_story.get("campaigns", []):
		var definition: Dictionary = raw
		var id := str(definition.get("id", ""))
		var title := str(definition.get("title", id))
		var label := title + (" · continuar" if campaign_id == id and campaign_phase != "new" else "")
		menu.add_child(_button(label, _open_campaign.bind(id), "Iniciar ou continuar esta campanha"))
	if campaign_phase != "new":
		menu.add_child(_button("Reiniciar narrativa", _new_campaign.bind(campaign_id), "Recomeça as cenas; mantém cartas já conquistadas."))

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
	campaign_view.campaign_selected.connect(_campaign_selected)
	campaign_view.team_selected.connect(_confirm_team)
	campaign_view.card_selected.connect(_claim_card)
	campaign_view.reward_bundle_continue.connect(_claim_reward_bundle)
	campaign_view.load_campaign.connect(_load_campaign_from_defeat)
	campaign_view.retry_battle.connect(_prepare_team)
	campaign_view.exit_campaign.connect(_exit_campaign)
	return campaign_view

func _new_campaign(id: String = "") -> void:
	if id != "": campaign_id = id
	_reset_campaign_state()
	var configured_start := str(_campaign_definition().get("start_scene", campaign_story.get("start_scene", "")))
	campaign_scene = configured_start if _scene_belongs_to_campaign(configured_start) else _first_scene_in_campaign()
	campaign_phase = "story"
	campaign_active = true
	_save_campaign()
	_enter_scene()

func _open_campaign(id: String = "") -> void:
	if campaign_story.is_empty(): return
	if id != "" and id != campaign_id:
		_load_campaign(id)
	if campaign_phase == "new":
		_new_campaign(campaign_id)
		return
	campaign_active = true
	if campaign_phase == "reward" and not reward_offers.is_empty():
		_show_reward()
	elif campaign_phase in ["team", "battle", "defeat"]:
		_restore_active_battle()
		_prepare_team()
	else:
		_enter_scene()

func _campaign_definition() -> Dictionary:
	for raw in campaign_story.get("campaigns", []):
		var definition: Dictionary = raw
		if str(definition.get("id", "")) == campaign_id: return definition
	return {}

func _show_campaign_list() -> void:
	_clear_ui()
	_clear_combat_visuals()
	_view().show_campaign_list(campaign_story.get("campaigns", []))

func _campaign_selected(id: String) -> void:
	_open_campaign(id)

func _reset_campaign_state() -> void:
	campaign_flags.clear()
	campaign_unlocked.clear()
	for required_id in _campaign_definition().get("required_party", []): campaign_unlocked[str(required_id)] = true
	campaign_team = _default_campaign_team()
	battle_team.clear()
	reward_offers.clear()
	active_battle.clear()
	pending_reward_bundle.clear()
	pending_reward_draw = false
	reward_return = "battle"
	campaign_scene = _first_scene_in_campaign()
	scene_step = 0
	battle_index = 0
	campaign_phase = "new"

func _first_scene_in_campaign() -> String:
	var definition := _campaign_definition()
	for raw in definition.get("adventures", []):
		var adventure: Dictionary = campaign_story.get("adventures", {}).get(str(raw), {})
		for scene_id in adventure.get("scene_ids", []):
			if campaign_story.get("scenes", {}).has(str(scene_id)) and _condition_passes(adventure) and _condition_passes(campaign_story["scenes"][str(scene_id)]):
				return str(scene_id)
	return ""

func _scene_belongs_to_campaign(scene_id: String) -> bool:
	if scene_id == "" or not campaign_story.get("scenes", {}).has(scene_id): return false
	for adventure_id in _campaign_definition().get("adventures", []):
		var adventure: Dictionary = campaign_story.get("adventures", {}).get(str(adventure_id), {})
		if adventure.get("scene_ids", []).has(scene_id): return true
	return false

func _condition_passes(data: Dictionary) -> bool:
	var need := str(data.get("if", ""))
	var exclude := str(data.get("unless", ""))
	if need != "" and not _as_bool(campaign_flags.get(need, false)): return false
	if exclude != "" and _as_bool(campaign_flags.get(exclude, false)): return false
	return true

func _as_bool(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return str(value).to_lower() not in ["", "0", "false", "off", "no"]
	return bool(value)

func _scene_available(scene_id: String) -> bool:
	var data: Dictionary = campaign_story.get("scenes", {}).get(scene_id, {})
	if data.is_empty() or not _condition_passes(data): return false
	for raw in _campaign_definition().get("adventures", []):
		var adventure: Dictionary = campaign_story.get("adventures", {}).get(str(raw), {})
		if adventure.get("scene_ids", []).has(scene_id): return _condition_passes(adventure)
	return false

func _next_ordered_scene() -> String:
	var definition := _campaign_definition()
	var adventure_ids: Array = definition.get("adventures", [])
	var found := false
	for adventure_index in range(adventure_ids.size()):
		var adventure: Dictionary = campaign_story.get("adventures", {}).get(str(adventure_ids[adventure_index]), {})
		var scene_ids: Array = adventure.get("scene_ids", [])
		var start_at := 0
		if not found and scene_ids.has(campaign_scene):
			found = true
			start_at = scene_ids.find(campaign_scene) + 1
		elif not found:
			continue
		if not _condition_passes(adventure): continue
		for index in range(start_at, scene_ids.size()):
			var candidate := str(scene_ids[index])
			var scene_data: Dictionary = campaign_story.get("scenes", {}).get(candidate, {})
			if not scene_data.is_empty() and _scene_available(candidate): return candidate
	return ""

func _advance_scene(destination: String = "") -> void:
	var next := destination
	if next != "" and (not campaign_story.get("scenes", {}).has(next) or not _scene_available(next)):
		next = ""
	if next == "":
		var scene_data: Dictionary = campaign_story.get("scenes", {}).get(campaign_scene, {})
		var explicit := str(scene_data.get("next", ""))
		if explicit != "" and campaign_story.get("scenes", {}).has(explicit) and _scene_available(explicit):
			next = explicit
		else:
			next = _next_ordered_scene()
	if next == "":
		campaign_phase = "complete"
		_save_campaign()
		_view().show_ending()
		return
	campaign_scene = next
	scene_step = 0
	active_battle.clear()
	campaign_phase = "story"
	_save_campaign()
	_enter_scene()

func _enter_scene() -> void:
	if campaign_story.is_empty(): return
	var data: Dictionary = campaign_story["scenes"].get(campaign_scene, {})
	if data.is_empty() or not _scene_available(campaign_scene):
		_advance_scene()
		return
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
		if not _condition_passes(entry):
			scene_step += 1
			continue
		match str(entry.get("type", "line")):
			"line":
				if entry.has("right_portrait") or entry.has("right"):
					right_portrait_id = _resolve_portrait_id(str(entry.get("right_portrait", entry.get("right", ""))))
				var left_id := _resolve_portrait_id(str(entry.get("left_portrait", "")))
				if left_id == "": left_id = Lead
				var line := entry.duplicate(true)
				line["speaker"] = _format_text(str(entry.get("speaker", "NARRADOR")))
				line["display_name"] = _format_text(str(entry.get("display_name", line["speaker"])))
				campaign_view.show_line(str(data.get("title", "Campanha")), line, _format_text(str(entry.get("text", ""))), right_portrait_id, str(data.get("weather", "rain")), left_id)
				return
			"choice":
				var options := _available_choice_options(entry.get("options", []))
				if options.is_empty():
					scene_step += 1
					continue
				campaign_view.show_choices(options)
				return
			"battle":
				active_battle = _battle_config(entry, data)
				_prepare_team()
				return
			"jump":
				var destination := str(entry.get("scene", ""))
				if campaign_story["scenes"].has(destination) and _scene_available(destination):
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
			"reward":
				_begin_story_reward(entry)
				return
			_:
				scene_step += 1
	_advance_scene()

func _resolve_portrait_id(value: String) -> String:
	if value == "{ally1}": return campaign_team[1] if campaign_team.size() > 1 else Lead
	if value == "{ally2}": return campaign_team[2] if campaign_team.size() > 2 else Lead
	return value

func _available_choice_options(options: Array) -> Array:
	var result: Array = []
	for raw in options:
		if typeof(raw) != TYPE_DICTIONARY: continue
		var option: Dictionary = raw
		if _condition_passes(option): result.append(option)
	return result

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
	if not _available_choice_options(steps[scene_step].get("options", [])).has(option): return
	var flag := str(option.get("flag", ""))
	if flag != "": campaign_flags[flag] = _as_bool(option.get("value", true))
	var should_draw := _apply_story_effects(option.get("effects", []))
	var destination := str(option.get("goto", ""))
	if should_draw:
		scene_step += 1
		reward_return = "story"
		reward_offers = _reward_cards()
		campaign_phase = "reward"
		_save_campaign()
		_show_reward()
		return
	if destination != "" and campaign_story["scenes"].has(destination):
		_advance_scene(destination)
		return
	scene_step += 1
	_save_campaign()
	_show_step()

func _apply_story_effects(effects: Array) -> bool:
	var draw := false
	for raw in effects:
		if typeof(raw) != TYPE_DICTIONARY: continue
		var effect: Dictionary = raw
		var kind := str(effect.get("type", ""))
		var id := str(effect.get("id", ""))
		var amount := maxi(1, int(effect.get("amount", 1)))
		match kind:
			"set_flag":
				if id != "": campaign_flags[id] = _as_bool(effect.get("value", true))
			"add_hero":
				if Content.HEROES.has(id):
					campaign_unlocked[id] = true
					if not campaign_team.has(id) and campaign_team.size() < int(_campaign_definition().get("party_size", 3)): campaign_team.append(id)
			"remove_hero":
				if id not in _campaign_definition().get("required_party", []): campaign_team.erase(id)
			"give_item":
				if id != "": loadout[id] = int(loadout.get(id, 0)) + amount
			"give_card":
				var owner := str(effect.get("owner", Lead))
				if Content.CARDS.has(id) and Content.HEROES.has(owner): _grant_owned_card(owner, id)
			"draw_card":
				draw = true
	_save_config()
	_save_campaign()
	return draw

func _battle_config(entry: Dictionary, scene: Dictionary = {}) -> Dictionary:
	var mission := str(entry.get("mission", "campaign_custom"))
	var mission_data: Dictionary = Content.MISSIONS.get(mission, {"name": mission, "objective": "ELIMINATE", "enemies": []}).duplicate(true)
	mission_data["name"] = str(mission_data.get("name", mission))
	if entry.has("enemies") and not entry.get("enemies", []).is_empty(): mission_data["enemies"] = entry["enemies"].duplicate()
	if entry.has("reinforcements"): mission_data["reinforcements"] = entry["reinforcements"].duplicate(true)
	var criteria: Array = entry.get("criteria", []).duplicate(true)
	mission_data["campaign_criteria"] = criteria
	mission_data["extra_cards"] = entry.get("extra_cards", []).duplicate(true)
	if entry.has("protect_hp_start"):
		mission_data["protect_hp"] = maxi(0, int(entry["protect_hp_start"]))
		if int(mission_data["protect_hp"]) > 0: mission_data["objective"] = "PROTECT"
	var required: Array = _campaign_definition().get("required_party", [Lead]).duplicate()
	for required_id in entry.get("required_party", []):
		if not required.has(required_id): required.append(required_id)
	for criterion in criteria:
		if str(criterion.get("type", "")) == "protect_ally":
			var protected_id := str(criterion.get("target", ""))
			if protected_id != "" and not required.has(protected_id): required.append(protected_id)
	var party_size := clampi(int(entry.get("party_size", _campaign_definition().get("party_size", 3))), maxi(1, required.size()), 3)
	var ordered_next := str(entry.get("next", scene.get("next", _next_ordered_scene())))
	return {
		"mission": mission,
		"mission_data": mission_data,
		"required_party": required,
		"party_size": party_size,
		"enemies": mission_data.get("enemies", []),
		"enemy_pool": entry.get("enemy_pool", []),
		"extra_cards": entry.get("extra_cards", []),
		"criteria": criteria,
		"victory_flags": entry.get("victory_flags", []).duplicate(),
		"defeat_flags": entry.get("defeat_flags", []).duplicate(),
		"game_over": str(entry.get("game_over", "none")),
		"draw_reward": bool(entry.get("draw_reward", true)),
		"reward_type": str(entry.get("reward_type", "either")),
		"next": ordered_next,
		"arena": str(entry.get("arena", scene.get("arena", "campaign_road"))),
		"bgm": str(entry.get("battle_bgm", "")),
		"reward_count": maxi(1, int(entry.get("reward_count", 3)))
	}

func _enemy_roster() -> Dictionary:
	var banned := {}
	var campaign := _campaign_definition()
	for adventure_id in campaign.get("adventures", []):
		var adventure: Dictionary = campaign_story.get("adventures", {}).get(str(adventure_id), {})
		for scene_id in adventure.get("scene_ids", []):
			var data: Dictionary = campaign_story.get("scenes", {}).get(str(scene_id), {})
			for entry in data.get("steps", []):
				if str(entry.get("type", "")) != "battle": continue
				for enemy_id in entry.get("enemies", []): banned[str(enemy_id)] = true
				for enemy_id in entry.get("enemy_pool", []): banned[str(enemy_id)] = true
				var mission: Dictionary = Content.MISSIONS.get(str(entry.get("mission", "")), {})
				for enemy_id in mission.get("enemies", []): banned[str(enemy_id)] = true
				for wave in mission.get("reinforcements", {}).values():
					for enemy_id in wave: banned[str(enemy_id)] = true
	return banned

func _default_team() -> Array[String]:
	var result: Array[String] = []
	var required: Array = active_battle.get("required_party", _campaign_definition().get("required_party", [Lead]))
	for raw in required:
		var id := str(raw)
		if Content.HEROES.has(id) and not result.has(id):
			result.append(id)
			campaign_unlocked[id] = true
	var blocked := _enemy_roster()
	var need := int(active_battle.get("party_size", _campaign_definition().get("party_size", 3)))
	for id in campaign_team:
		if result.size() >= need: break
		if _hero_available(id) and not blocked.has(id) and not result.has(id): result.append(id)
	for id in Content.HEROES:
		if result.size() >= need: break
		var hero: Dictionary = Content.HEROES[id]
		if _hero_available(str(id)) and not blocked.has(str(id)) and not result.has(str(id)):
			result.append(str(id))
	return result

func _default_campaign_team() -> Array[String]:
	var result: Array[String] = []
	var definition := _campaign_definition()
	for raw in definition.get("required_party", []):
		var id := str(raw)
		if Content.HEROES.has(id) and not result.has(id):
			campaign_unlocked[id] = true
			result.append(id)
	var blocked := _enemy_roster()
	var size := clampi(int(definition.get("party_size", 3)), maxi(1, result.size()), maxi(1, Content.HEROES.size()))
	for raw in Content.HEROES.keys():
		var id := str(raw)
		if result.size() >= size: break
		if _hero_available(id) and not blocked.has(id) and not result.has(id): result.append(id)
	return result

func _campaign_team_is_valid(ids: Array[String]) -> bool:
	var definition := _campaign_definition()
	var required: Array = definition.get("required_party", [])
	var size := clampi(int(definition.get("party_size", 3)), maxi(1, required.size()), maxi(1, Content.HEROES.size()))
	if ids.size() != size: return false
	var banned := _enemy_roster()
	var seen: Dictionary = {}
	for id in ids:
		if seen.has(id) or banned.has(id) or not _hero_available(id): return false
		seen[id] = true
	for hero_id in required:
		if Content.HEROES.has(str(hero_id)) and not ids.has(str(hero_id)): return false
	return true

func _hero_available(id: String) -> bool:
	return Content.HEROES.has(id) and (bool(Content.HEROES[id].get("playable", true)) or bool(campaign_unlocked.get(id, false)))

func _available_hero_roster() -> Dictionary:
	var roster: Dictionary = Content.HEROES.duplicate(true)
	for id in campaign_unlocked:
		if roster.has(str(id)): roster[str(id)]["playable"] = true
	return roster

func _team_is_valid(ids: Array[String]) -> bool:
	if ids.size() != int(active_battle.get("party_size", 3)): return false
	var required: Array = active_battle.get("required_party", _campaign_definition().get("required_party", [Lead]))
	var banned := _enemy_roster()
	var seen := {}
	for id in ids:
		if seen.has(id) or banned.has(id) or not _hero_available(id): return false
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
	if not _campaign_team_is_valid(campaign_team): campaign_team = _default_campaign_team()
	var battle_selection: Array[String] = battle_team.duplicate() if _team_is_valid(battle_team) else _default_team()
	var mission: Dictionary = active_battle.get("mission_data", {})
	var name := str(mission.get("name", active_battle.get("mission", "Batalha")))
	var overlay := _view()
	overlay.set_meta("battle_name", name)
	overlay.show_team(_available_hero_roster(), battle_selection, _enemy_roster(), name, active_battle.get("required_party", _campaign_definition().get("required_party", [Lead])), int(active_battle.get("party_size", _campaign_definition().get("party_size", 3))))
	_save_campaign()

func _confirm_team(ids: Array) -> void:
	var selection: Array[String] = []
	for raw in ids: selection.append(str(raw))
	if not _team_is_valid(selection): return
	battle_team = selection.duplicate()
	team = selection.duplicate()
	_save_campaign()
	_start_campaign_battle()

func _start_campaign_battle() -> void:
	if not _team_is_valid(team) or active_battle.is_empty(): return
	campaign_phase = "battle"
	mission_id = str(active_battle.get("mission", ""))
	if mission_id == "": return
	var mission_override: Dictionary = active_battle.get("mission_data", {})
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
		if not packs.entities.deploy(battle, mission_id, ids, equipped, 0, {}, mission_override):
			pack_mode = "default"
			battle.begin(mission_id, team, equipped, 0, improvements, loadout, false, mission_override)
			_start_campaign_battle_turn()
	else:
		battle.begin(mission_id, team, equipped, 0, improvements, loadout, false, mission_override)
		_start_campaign_battle_turn()
	_apply_accessibility()
	_play_campaign_music(str(active_battle.get("bgm", "")))
	_save_campaign()
	_render_battle()

func _start_campaign_battle_turn() -> void:
	battle.add_campaign_extra_cards(active_battle.get("extra_cards", []))
	battle._shuffle(battle.deck)
	battle._draw_side("ALLY", int(battle.rules["opening_hand"]))
	battle._draw_side("ENEMY", int(battle.rules["opening_hand"]))
	battle._log("Missão: %s" % battle.mission.get("name", mission_id))
	battle.start_turn()

func _on_finished(won: bool) -> void:
	if not campaign_active or campaign_phase != "battle":
		super._on_finished(won)
		return
	if won:
		sound.cue("victory")
		_apply_campaign_flags(active_battle.get("victory_flags", []))
		if Content.MISSIONS.has(mission_id): _award_victory(_mission_stars())
		_save_config()
		if bool(active_battle.get("draw_reward", true)):
			reward_return = "battle"
			reward_offers = _reward_cards()
			campaign_phase = "reward"
			_save_campaign()
			_show_reward()
		else:
			_finalize_victory()
	else:
		sound.cue("death")
		_apply_campaign_flags(active_battle.get("defeat_flags", []))
		campaign_phase = "defeat"
		_save_campaign()
		_clear_ui()
		_view().show_defeat(str(active_battle.get("mission_data", {}).get("name", Content.MISSIONS.get(mission_id, {}).get("name", mission_id))), str(active_battle.get("game_over", "none")))

func _apply_campaign_flags(flags: Array) -> void:
	for raw in flags:
		var flag := str(raw)
		if flag != "": campaign_flags[flag] = true

func _reward_cards() -> Array:
	_ensure_owned_cards()
	var options: Array = []
	var eligible: Dictionary = {}
	var reward_type := str(active_battle.get("reward_type", "either"))
	var participants: Array = battle_team if not battle_team.is_empty() else campaign_team
	for hero_id in participants:
		var hero: Dictionary = Content.HEROES.get(hero_id, {})
		var list: Array = []
		if reward_type in ["either", "evolved"]:
			for raw in hero.get("evoluidas", []): list.append(str(raw))
		# Uma carta Melhorada só é elegível quando sua base já pertence ao jogador.
		if reward_type in ["either", "upgraded"]:
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
	for hero_id in participants:
		var cards: Array = eligible.get(hero_id, [])
		if not cards.is_empty():
			var chosen := str(cards[options.size() % cards.size()])
			options.append({"owner": hero_id, "card": chosen})
			cards.erase(chosen)
	# Em uma coleção parcialmente completa, as vagas restantes continuam
	# restritas às cartas dos três integrantes desta batalha.
	while options.size() < int(active_battle.get("reward_count", 3)):
		var grew := false
		for hero_id in participants:
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
		if reward_return == "battle": _finalize_victory()
		else:
			campaign_phase = "story"
			_save_campaign()
			_show_step()
	else:
		overlay.show_reward(reward_offers)

func _claim_card(option: Dictionary) -> void:
	if campaign_phase != "reward" or not reward_offers.has(option): return
	var owner_id := str(option.get("owner", ""))
	var cid := str(option.get("card", ""))
	if (not battle_team.has(owner_id) and not campaign_team.has(owner_id)) or not Content.CARDS.has(cid): return
	_grant_owned_card(owner_id, cid)
	_save_config()
	if reward_return == "battle":
		_finalize_victory()
	else:
		reward_offers.clear()
		campaign_phase = "story"
		_save_campaign()
		_show_step()

func _finalize_victory() -> void:
	reward_offers.clear()
	battle_index += 1
	var destination := str(active_battle.get("next", ""))
	_advance_scene(destination)

func _begin_story_reward(entry: Dictionary) -> void:
	var rewards: Array = entry.get("rewards", [])
	var static_rewards: Array = []
	var has_draw := false
	for raw in rewards:
		if typeof(raw) != TYPE_DICTIONARY: continue
		if str(raw.get("type", "")) == "draw": has_draw = true
		else: static_rewards.append(raw)
	scene_step += 1
	pending_reward_bundle = static_rewards
	pending_reward_draw = has_draw
	reward_return = "story"
	if bool(entry.get("window", true)) and not static_rewards.is_empty():
		campaign_phase = "reward_bundle"
		_save_campaign()
		_view().show_reward_bundle(str(entry.get("title", "Recompensas")), static_rewards)
		return
	_apply_reward_bundle(static_rewards)
	if has_draw:
		_open_story_card_draw()
	else:
		campaign_phase = "story"
		_save_campaign()
		_show_step()

func _claim_reward_bundle() -> void:
	if campaign_phase != "reward_bundle": return
	_apply_reward_bundle(pending_reward_bundle)
	pending_reward_bundle.clear()
	if pending_reward_draw:
		pending_reward_draw = false
		_open_story_card_draw()
	else:
		campaign_phase = "story"
		_save_campaign()
		_show_step()

func _apply_reward_bundle(rewards: Array) -> void:
	for raw in rewards:
		if typeof(raw) != TYPE_DICTIONARY: continue
		var reward: Dictionary = raw
		var id := str(reward.get("id", ""))
		var amount := maxi(1, int(reward.get("amount", 1)))
		match str(reward.get("type", "")):
			"character":
				if Content.HEROES.has(id): campaign_unlocked[id] = true
			"item":
				if id != "": loadout[id] = int(loadout.get(id, 0)) + amount
			"card":
				var owner := str(reward.get("owner", Lead))
				if Content.CARDS.has(id) and Content.HEROES.has(owner): _grant_owned_card(owner, id)
	_save_config()
	_save_campaign()

func _open_story_card_draw() -> void:
	reward_return = "story"
	active_battle["reward_count"] = 3
	active_battle["reward_type"] = "either"
	reward_offers = _reward_cards()
	campaign_phase = "reward"
	_save_campaign()
	_show_reward()

func _load_campaign_from_defeat() -> void:
	_load_campaign(campaign_id)
	_restore_active_battle()
	_prepare_team()

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
	config.load(SavePath)
	var section := "campaign_" + campaign_id if campaign_id != "" else "story"
	config.set_value("settings", "current_campaign", campaign_id)
	config.set_value(section, "scene", campaign_scene)
	config.set_value(section, "step", scene_step)
	config.set_value(section, "battle", battle_index)
	config.set_value(section, "phase", campaign_phase)
	config.set_value(section, "flags", campaign_flags)
	config.set_value(section, "unlocked", campaign_unlocked)
	config.set_value(section, "team", campaign_team)
	config.set_value(section, "battle_team", battle_team)
	config.set_value(section, "offers", reward_offers)
	config.set_value(section, "active_battle", active_battle)
	config.set_value(section, "reward_return", reward_return)
	config.set_value(section, "pending_reward_bundle", pending_reward_bundle)
	config.set_value(section, "pending_reward_draw", pending_reward_draw)
	config.save(SavePath)

func _load_campaign(id: String = "") -> void:
	if id != "": campaign_id = id
	var config := ConfigFile.new()
	if config.load(SavePath) != OK:
		_reset_campaign_state()
		return
	if id == "": campaign_id = str(config.get_value("settings", "current_campaign", campaign_story.get("start_campaign", campaign_id)))
	if _campaign_definition().is_empty(): campaign_id = str(campaign_story.get("start_campaign", campaign_id))
	var campaign_section := "campaign_" + campaign_id
	var legacy_section := campaign_id == str(campaign_story.get("start_campaign", "")) and config.has_section("story")
	if not config.has_section(campaign_section) and not legacy_section:
		_reset_campaign_state()
		return
	var section := campaign_section if config.has_section(campaign_section) else "story"
	var scene_id := str(config.get_value(section, "scene", _first_scene_in_campaign()))
	if _scene_belongs_to_campaign(scene_id): campaign_scene = scene_id
	else: campaign_scene = _first_scene_in_campaign()
	scene_step = maxi(0, int(config.get_value(section, "step", 0)))
	battle_index = maxi(0, int(config.get_value(section, "battle", 0)))
	campaign_phase = str(config.get_value(section, "phase", "new"))
	campaign_flags = config.get_value(section, "flags", {})
	campaign_unlocked = config.get_value(section, "unlocked", {})
	var stored_team: Array = config.get_value(section, "team", [])
	if not stored_team.is_empty():
		campaign_team.clear()
		for hero_id in stored_team: campaign_team.append(str(hero_id))
	var stored_battle_team: Array = config.get_value(section, "battle_team", [])
	battle_team.clear()
	for hero_id in stored_battle_team: battle_team.append(str(hero_id))
	reward_offers = config.get_value(section, "offers", [])
	active_battle = config.get_value(section, "active_battle", {})
	reward_return = str(config.get_value(section, "reward_return", "battle"))
	pending_reward_bundle = config.get_value(section, "pending_reward_bundle", [])
	pending_reward_draw = bool(config.get_value(section, "pending_reward_draw", false))
	if campaign_phase == "battle": campaign_phase = "team"
