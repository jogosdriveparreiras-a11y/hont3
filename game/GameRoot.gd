extends Node3D

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")
const SoundBus = preload("res://game/SoundBus.gd")
const Presentation = preload("res://game/CombatPresentation.gd")

var battle
var camera: Camera3D
var stage: Node3D
var units: Node3D
var cards_3d: Node3D
var viewport_hosts: Node
var hud: Control
var team: Array[String] = ["guerreiro", "mago", "clerigo"]
var equipped: Dictionary = {}
var improvements: Dictionary = {}
var best_stars: Dictionary = {}
var essence := 0
var loadout: Dictionary = {"potion": 1, "bomb": 1, "antidote": 1}
var mission_id := "road"
var selected_card := -1
var selected_action := ""
var chain_targets: Array[int] = []
var feedback := ""
var event_history: Array[String] = []
var deck_hero := ""
var deck_filter := "TODAS"
var deck_selected := ""
var deck_slot := -1
var card_hit_areas: Array[Button] = []
var card_meshes: Array[MeshInstance3D] = []
var unit_sprites: Array[Sprite3D] = []
var actor_nodes: Dictionary = {}
var sound
var presentation
var fx_overlay: Control
var hover_hint: Label
var hovered_card := -1
var target_cursor := 0
var visible_uids: Dictionary = {}
var sound_levels: Dictionary = {"MASTER": 0.8, "MUSIC": 0.35, "SFX": 0.7, "UI": 0.55, "AMBIENCE": 0.18}
var shake_level := 0.5
var reduce_flashes := false
var reduce_motion := false
var animation_speed := 1.0

func _ready() -> void:
	_register_inputs()
	_load_config()
	_make_world()
	_show_menu()

func _make_world() -> void:
	stage = Node3D.new()
	stage.name = "Arena3D"
	add_child(stage)
	units = Node3D.new()
	units.name = "Personagens2D"
	add_child(units)
	cards_3d = Node3D.new()
	cards_3d.name = "Cartas3D"
	add_child(cards_3d)
	viewport_hosts = Node.new()
	viewport_hosts.name = "FacesDasCartas"
	add_child(viewport_hosts)
	camera = Camera3D.new()
	camera.position = Vector3(0, 11.5, 18)
	camera.fov = 51
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101527")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("72769a")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)
	_add_box(Vector3(0, -0.30, 0), Vector3(19, 0.5, 12), Color("353c47"))
	for z in [-3.3, -1.7, 1.7, 3.3]:
		_add_box(Vector3(0, -0.02, z), Vector3(17, 0.04, 0.035), Color("bea674"))
	for x in [-9.1, 9.1]:
		for z in [-5.5, 5.5]:
			_add_box(Vector3(x, 1.75, z), Vector3(0.75, 3.5, 0.75), Color("555169"))
			_add_box(Vector3(x, 3.5, z), Vector3(1.1, 0.3, 1.1), Color("c8ac76"))
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_viewport_resized)
	var effects_layer := CanvasLayer.new()
	effects_layer.layer = 2
	add_child(effects_layer)
	fx_overlay = Control.new()
	fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(fx_overlay)
	fx_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound = SoundBus.new()
	add_child(sound)
	for channel in sound_levels: sound.set_level(channel, float(sound_levels[channel]))
	presentation = Presentation.new()
	add_child(presentation)
	presentation.configure(camera, fx_overlay, sound)
	_apply_accessibility()

func _on_viewport_resized() -> void:
	if battle != null and battle.phase == "PLAYER": _render_battle()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _add_box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	if parent == null: parent = stage
	parent.add_child(mesh)
	return mesh

func _clear_ui() -> void:
	for child in hud.get_children():
		hud.remove_child(child)
		child.queue_free()
	card_hit_areas.clear()

func _clear_combat_visuals() -> void:
	for node in units.get_children():
		units.remove_child(node)
		node.queue_free()
	actor_nodes.clear()
	if presentation != null: presentation.clear_actors()
	_clear_hand_visuals()
	visible_uids.clear()

func _clear_hand_visuals() -> void:
	for node in cards_3d.get_children():
		cards_3d.remove_child(node)
		node.queue_free()
	for node in viewport_hosts.get_children():
		viewport_hosts.remove_child(node)
		node.queue_free()
	card_meshes.clear()

func _label(text_value: String, size: int = 23, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, on_click: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150, 45)
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = hint
	button.pressed.connect(on_click)
	return button

func _center_panel(title: String) -> VBoxContainer:
	_clear_ui()
	_clear_combat_visuals()
	var frame := CenterContainer.new()
	hud.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	frame.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	panel.add_child(contents)
	contents.add_child(_label(title, 38, Color("dcc28b")))
	return contents

func _show_menu() -> void:
	var menu := _center_panel("HEROES OF THE NIGHTMARE 3")
	menu.add_child(_label("Três heróis. Duas linhas. Um deck compartilhado.", 20))
	menu.add_child(_label("Missões concluídas: %d/%d · Essência: %d" % [best_stars.size(), Content.MISSIONS.size(), essence], 19))
	menu.add_child(_button("Selecionar missão", _show_missions))
	menu.add_child(_button("Escolher equipe", _show_team))
	menu.add_child(_button("Montar decks", _show_decks))
	menu.add_child(_button("Preparar itens", _show_items))
	menu.add_child(_button("Configurações", _show_settings))
	menu.add_child(_button("Iniciar missão: %s" % Content.MISSIONS[mission_id]["name"], _start_mission))

func _show_settings() -> void:
	var menu := _center_panel("CONFIGURAÇÕES")
	for channel in ["MASTER", "MUSIC", "SFX", "UI", "AMBIENCE"]:
		var names := {"MASTER": "Volume geral", "MUSIC": "Música", "SFX": "Combate", "UI": "Interface", "AMBIENCE": "Ambiente"}
		menu.add_child(_setting_slider(names[channel], float(sound_levels[channel]), _set_volume.bind(channel)))
	menu.add_child(_setting_slider("Intensidade do tremor", shake_level, _set_shake))
	menu.add_child(_setting_slider("Velocidade das animações", (animation_speed - 0.5) / 1.5, _set_animation_speed))
	menu.add_child(_button("Reduzir flashes: %s" % ("sim" if reduce_flashes else "não"), _toggle_flashes))
	menu.add_child(_button("Reduzir movimento da câmera: %s" % ("sim" if reduce_motion else "não"), _toggle_motion))
	menu.add_child(_button("Voltar", _show_menu))

func _setting_slider(title: String, level: float, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_label(title, 18))
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(260, 30)
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = roundf(level * 100.0)
	row.add_child(slider)
	slider.value_changed.connect(func(value): callback.call(float(value) / 100.0))
	return row

func _set_volume(level: float, channel: String) -> void:
	sound_levels[channel] = level
	if sound != null: sound.set_level(channel, level)
	_save_config()

func _set_shake(level: float) -> void:
	shake_level = level
	_apply_accessibility()
	_save_config()

func _set_animation_speed(level: float) -> void:
	animation_speed = 0.5 + level * 1.5
	_apply_accessibility()
	_save_config()

func _toggle_flashes() -> void:
	reduce_flashes = not reduce_flashes
	_apply_accessibility()
	_save_config()
	_show_settings()

func _toggle_motion() -> void:
	reduce_motion = not reduce_motion
	_apply_accessibility()
	_save_config()
	_show_settings()

func _apply_accessibility() -> void:
	if presentation == null: return
	presentation.shake_enabled = shake_level > 0.0 and not reduce_motion
	presentation.shake_scale = shake_level
	presentation.flash_enabled = not reduce_flashes
	presentation.animation_speed = animation_speed
	presentation.motion_scale = 0.15 if reduce_motion else 1.0

func _show_missions() -> void:
	var menu := _center_panel("MISSÕES")
	for id in Content.MISSIONS:
		var entry: Dictionary = Content.MISSIONS[id]
		var campaign: Dictionary = Content.CAMPAIGN[id]
		var accessible := _mission_unlocked(id)
		var button := _button("%s %s · %s" % ["✓" if best_stars.has(id) else "•", entry["name"], "★".repeat(int(best_stars.get(id, 0))) if accessible else "bloqueada"], _select_mission.bind(id), campaign["brief"])
		button.disabled = not accessible
		menu.add_child(button)
		if not accessible: menu.add_child(_label("Requer: %s" % ", ".join(PackedStringArray(campaign["requires"])), 15))
	menu.add_child(_label("Selecionada: %s" % Content.MISSIONS[mission_id]["name"], 19))
	menu.add_child(_label(Content.CAMPAIGN[mission_id]["brief"], 18))
	menu.add_child(_button("Voltar", _show_menu))

func _mission_unlocked(id: String) -> bool:
	for needed in Content.CAMPAIGN[id]["requires"]:
		if not best_stars.has(needed): return false
	return true

func _select_mission(id: String) -> void:
	if not _mission_unlocked(id): return
	mission_id = id
	_show_missions()

func _show_team() -> void:
	var menu := _center_panel("EQUIPE · %d/%d" % [team.size(), Content.RULES["team_size"]])
	for id in Content.HEROES:
		var hero: Dictionary = Content.HEROES[id]
		var chosen := team.has(id)
		var identity: Dictionary = Content.HERO_LORE[id]
		menu.add_child(_button(("✓ " if chosen else "+ ") + "%s · %s · %d PV" % [hero["name"], identity["role"], hero["hp"]], _toggle_hero.bind(id), identity["history"] + "\n" + identity["trait"]))
	menu.add_child(_button("Voltar", _show_menu))

func _toggle_hero(id: String) -> void:
	if team.has(id):
		if team.size() > 1: team.erase(id)
	elif team.size() < int(Content.RULES["team_size"]):
		team.append(id)
	_save_config()
	_show_team()

func _show_decks() -> void:
	if not team.has(deck_hero): deck_hero = team[0]
	var hero: Dictionary = Content.HEROES[deck_hero]
	var selected_cards: Array = equipped.get(deck_hero, hero["cards"])
	var pool: Array = hero.get("pool", hero["cards"])
	if not pool.has(deck_selected): deck_selected = pool[0]
	var menu := _center_panel("DECK · %s · %d/%d CARTAS" % [hero["name"], selected_cards.size(), Content.RULES["deck_size"]])
	menu.add_child(_label("Essência: %d · Melhorias: nível 1 custa 3; nível 2 custa 6; modificação custa 4." % essence, 16))
	var menu_panel := menu.get_parent() as PanelContainer
	menu_panel.custom_minimum_size.x = 1150
	var hero_bar := HBoxContainer.new()
	menu.add_child(hero_bar)
	for id in team:
		hero_bar.add_child(_button(("✓ " if id == deck_hero else "") + Content.HEROES[id]["name"], _select_deck_hero.bind(id)))
	var filter_bar := HBoxContainer.new()
	menu.add_child(filter_bar)
	for filter_name in ["TODAS", "ATAQUE", "TÉCNICA", "PODER", "ALCANCE", "MELHORADAS"]:
		filter_bar.add_child(_button(("● " if deck_filter == filter_name else "") + filter_name.capitalize(), _set_deck_filter.bind(filter_name)))
	var type_bar := HBoxContainer.new()
	menu.add_child(type_bar)
	for filter_name in ["FÍSICO", "MÁGICO", "SUPORTE", "RARAS"]:
		type_bar.add_child(_button(("● " if deck_filter == filter_name else "") + filter_name.capitalize(), _set_deck_filter.bind(filter_name)))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	menu.add_child(columns)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size.x = 275
	columns.add_child(slots)
	slots.add_child(_label("EQUIPADAS · SELECIONE UM SLOT", 19, Color("d9bd85")))
	for position in range(selected_cards.size()):
		var card_id: String = selected_cards[position]
		var definition: Dictionary = Content.CARDS[card_id]
		var selected_prefix := "▶ " if deck_slot == position else ""
		var button := _button("%s%d · %s" % [selected_prefix, position + 1, definition["name"]], _choose_deck_slot.bind(position, card_id), _card_description(definition))
		button.custom_minimum_size = Vector2(260, 48)
		slots.add_child(button)
	var catalogue := ScrollContainer.new()
	catalogue.custom_minimum_size = Vector2(360, maxf(210.0, get_viewport().get_visible_rect().size.y - 450.0))
	columns.add_child(catalogue)
	var available := VBoxContainer.new()
	catalogue.add_child(available)
	available.add_child(_label("CARTAS DISPONÍVEIS", 19, Color("d9bd85")))
	for entry in pool:
		var card_id: String = entry
		if not _matches_deck_filter(card_id, deck_hero): continue
		var definition: Dictionary = Content.CARDS[card_id]
		var key: String = str(deck_hero) + ":" + str(card_id)
		var level := int(improvements.get(key, {}).get("upgrade", 0))
		var cost := int(definition.get("cost", 0))
		var subtitle := "%s · %s" % [definition["class"], "%d Ímpeto" % cost if cost > 0 else "+%d Ímpeto" % int(definition.get("gain", 0))]
		var button := _button(("▶ " if deck_selected == card_id else "") + definition["name"] + " +%d\n" % level + subtitle, _choose_deck_card.bind(card_id), _card_description(definition))
		button.custom_minimum_size = Vector2(330, 62)
		available.add_child(button)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 390
	columns.add_child(details)
	details.add_child(_label("DETALHES", 19, Color("d9bd85")))
	var shown: Dictionary = Content.CARDS[deck_selected]
	details.add_child(_label(shown["name"], 24, Color("f2dcad")))
	details.add_child(_label("%s · %s · %s" % [shown["class"], _card_type(shown), shown.get("rarity", "Comum")], 18))
	details.add_child(_label("Tipo do herói: %s" % hero["type"], 17))
	details.add_child(_label("Custo %d · Gera %d · Alcance %s" % [shown.get("cost", 0), shown.get("gain", 0), "longo" if shown.get("reach", false) else "curto"], 18))
	var detail_text := _label(_card_description(shown), 18)
	detail_text.custom_minimum_size = Vector2(380, 95)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_text)
	var selected_key: String = str(deck_hero) + ":" + str(deck_selected)
	var changes: Dictionary = improvements.get(selected_key, {})
	var upgrade_level := int(changes.get("upgrade", 0))
	var upgrade_button := _button("Melhoria +%d · custo %d" % [upgrade_level, 3 if upgrade_level == 0 else 6], _upgrade_card.bind(selected_key))
	upgrade_button.disabled = upgrade_level >= 2 or essence < (3 if upgrade_level == 0 else 6)
	details.add_child(upgrade_button)
	var mod_button := _button("Modificação: %s · custo 4" % (changes.get("mod", "") if changes.get("mod", "") != "" else "nenhuma"), _cycle_mod.bind(selected_key))
	mod_button.disabled = essence < 4
	details.add_child(mod_button)
	details.add_child(_label("Selecione um slot e depois uma carta da lista.", 16))
	if feedback != "": details.add_child(_label(feedback, 16, Color("e7a777")))
	menu.add_child(_button("Voltar", _show_menu))

func _select_deck_hero(hero_id: String) -> void:
	deck_hero = hero_id
	deck_slot = -1
	deck_selected = ""
	feedback = ""
	_show_decks()

func _set_deck_filter(filter_name: String) -> void:
	deck_filter = filter_name
	_show_decks()

func _choose_deck_slot(slot: int, card_id: String) -> void:
	deck_slot = slot
	deck_selected = card_id
	feedback = ""
	_show_decks()

func _matches_deck_filter(card_id: String, hero_id: String) -> bool:
	var card: Dictionary = Content.CARDS[card_id]
	match deck_filter:
		"ATAQUE": return card.get("class", "") == "ATTACK"
		"TÉCNICA": return card.get("class", "") == "SKILL"
		"PODER": return card.get("class", "") == "POWER"
		"ALCANCE": return card.get("reach", false)
		"MELHORADAS": return int(improvements.get(hero_id + ":" + card_id, {}).get("upgrade", 0)) > 0
		"FÍSICO", "MÁGICO", "SUPORTE": return _card_type(card) == deck_filter
		"RARAS": return card.get("rarity", "Comum") == "Rara"
	return true

func _card_type(definition: Dictionary) -> String:
	for effect in definition.get("effects", []):
		if effect.get("kind", "") == "DAMAGE":
			return "MÁGICO" if effect.get("stat", "attack") == "power" else "FÍSICO"
	return "SUPORTE"

func _choose_deck_card(card_id: String) -> void:
	deck_selected = card_id
	if deck_slot >= 0:
		_equip_card(deck_hero, deck_slot, card_id)
	_show_decks()

func _equip_card(hero_id: String, slot: int, card_id: String) -> bool:
	var hero: Dictionary = Content.HEROES.get(hero_id, {})
	if hero.is_empty() or not hero.get("pool", []).has(card_id): return false
	var cards: Array = equipped.get(hero_id, hero["cards"]).duplicate()
	if slot < 0 or slot >= cards.size(): return false
	var limit := int(Content.CARDS[card_id].get("copy_limit", Content.RULES["copy_limit"]))
	if cards[slot] != card_id and cards.count(card_id) >= limit:
		feedback = "Limite de %d cópias de %s." % [limit, Content.CARDS[card_id]["name"]]
		return false
	cards[slot] = card_id
	equipped[hero_id] = cards
	feedback = "Carta equipada no slot %d." % (slot + 1)
	_save_config()
	return true

func _sanitize_decks() -> void:
	var valid := {}
	for hero_id in Content.HEROES:
		var hero: Dictionary = Content.HEROES[hero_id]
		var cards = equipped.get(hero_id, hero["cards"])
		if not (cards is Array) or cards.size() != int(Content.RULES["deck_size"]): continue
		var counts := {}
		var acceptable := true
		for card_id in cards:
			if not hero["pool"].has(card_id):
				acceptable = false
				break
			counts[card_id] = int(counts.get(card_id, 0)) + 1
			if counts[card_id] > int(Content.CARDS[card_id].get("copy_limit", Content.RULES["copy_limit"])):
				acceptable = false
				break
		if acceptable: valid[hero_id] = cards.duplicate()
	equipped = valid

func _upgrade_card(key: String) -> void:
	var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
	var level := int(change.get("upgrade", 0))
	var cost := 3 if level == 0 else 6
	if level >= 2 or essence < cost: return
	essence -= cost
	change["upgrade"] = level + 1
	improvements[key] = change
	_save_config()
	_show_decks()

func _cycle_mod(key: String) -> void:
	if essence < 4: return
	var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
	var options := ["", "damage", "impulse", "redraw"]
	var current := options.find(change.get("mod", ""))
	change["mod"] = options[(current + 1) % options.size()]
	essence -= 4
	improvements[key] = change
	_save_config()
	_show_decks()

func _show_items() -> void:
	var menu := _center_panel("ITENS · %d/%d" % [loadout.values().reduce(func(total, n): return total + n, 0), Content.RULES["items_max"]])
	for id in ["potion", "bomb", "antidote"]:
		menu.add_child(_button("%s ×%d" % [id.capitalize(), loadout.get(id, 0)], func(): _cycle_item(id)))
	menu.add_child(_button("Voltar", _show_menu))

func _cycle_item(id: String) -> void:
	var total := int(loadout.values().reduce(func(sum, n): return sum + n, 0))
	if total < int(Content.RULES["items_max"]): loadout[id] = int(loadout.get(id, 0)) + 1
	else: loadout[id] = 0
	_save_config()
	_show_items()

func _start_mission() -> void:
	if not _mission_unlocked(mission_id):
		_show_missions()
		return
	if team.size() != int(Content.RULES["team_size"]):
		feedback = "Escolha três heróis para entrar na missão."
		_show_team()
		return
	selected_card = -1
	selected_action = ""
	chain_targets.clear()
	event_history.clear()
	battle = Battle.new()
	battle.event.connect(_on_event)
	battle.visual.connect(_on_visual)
	battle.changed.connect(_render_battle)
	battle.finished.connect(_on_finished)
	battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	_render_battle()

func _on_event(message: String) -> void:
	event_history.append(message)
	if event_history.size() > 8: event_history.pop_front()
	feedback = message

func _on_visual(kind: String, source_id: int, target_id: int, amount: int) -> void:
	if presentation != null: presentation.show_action(kind, source_id, target_id, amount)

func _on_finished(won: bool) -> void:
	if won: sound.cue("victory")
	else: sound.cue("death")
	var reward := 0
	var stars := 0
	if won:
		stars = _mission_stars()
		reward = _award_victory(stars)
		_save_config()
	var title := "MISSÃO CONCLUÍDA" if won else "MISSÃO PERDIDA"
	var menu := _center_panel(title)
	menu.add_child(_label("%s · %d rodadas" % [battle.mission["name"], battle.turn], 22))
	if won: menu.add_child(_label("%s · +%d Essência · saldo %d" % ["★".repeat(stars), reward, essence], 20))
	for actor in battle.living("ALLY"):
		menu.add_child(_label("%s: %d/%d PV" % [actor["name"], actor["hp"], actor["max_hp"]], 18))
	menu.add_child(_button("Tentar novamente", _start_mission))
	menu.add_child(_button("Selecionar missão", _show_missions))
	menu.add_child(_button("Menu", _show_menu))

func _award_victory(stars: int) -> int:
	if stars < 1 or stars > 3: return 0
	var previous := int(best_stars.get(mission_id, 0))
	var reward := (3 if previous == 0 else 0) + 2 * maxi(0, stars - previous)
	best_stars[mission_id] = maxi(previous, stars)
	essence += reward
	return reward

func _mission_stars() -> int:
	var survivors: Array = battle.living("ALLY")
	var stars := 1 + (1 if survivors.size() >= 2 else 0)
	var goal: Dictionary = Content.CAMPAIGN[mission_id]
	if battle.mission["objective"] in ["SURVIVE", "PROTECT"]:
		var healthy := survivors.size() == 3 and survivors.all(func(actor): return int(actor["hp"]) * 2 >= int(actor["max_hp"]))
		if battle.mission["objective"] == "PROTECT": healthy = healthy and battle.protect_hp >= int(battle.mission["protect_hp"]) / 2
		if healthy: stars += 1
	elif battle.turn <= int(goal["par"]):
		stars += 1
	return stars

func _render_battle() -> void:
	if battle == null or battle.phase == "FINISHED": return
	_clear_ui()
	_clear_hand_visuals()
	hovered_card = -1
	var viewport_size := get_viewport().get_visible_rect().size
	var header := VBoxContainer.new()
	hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_child(_label("%s  ·  RODADA %d" % [battle.mission["name"], battle.turn], 23, Color("e9c891")))
	header.add_child(_label("AÇÕES %d  ·  ÍMPETO %d/%d  ·  INICIATIVA %d  ·  RECOMPRA %d  ·  MOVER %d" % [battle.card_plays, battle.impulse, battle.rules["impulse_max"], battle.initiative, battle.redraws, battle.moves], 18))
	var deck_line := "DECK %d · DESCARTE %d" % [battle.deck.size(), battle.discard.size()]
	if battle.mission["objective"] == "PROTECT": deck_line += "  ·  SENTINELA %d PV" % battle.protect_hp
	var next_turn: Array = battle.mission.get("reinforcements", {}).get(battle.turn + 1, [])
	if not next_turn.is_empty(): deck_line += "  ·  REFORÇOS EM 1 TURNO"
	header.add_child(_label(deck_line, 17, Color("e9c891") if not next_turn.is_empty() else Color.WHITE))
	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LeftPanel"
	left_scroll.position = Vector2(20, 115)
	left_scroll.size = Vector2(290, maxf(170.0, viewport_size.y - 310.0))
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 270
	left_scroll.add_child(left)
	var objective := _label("OBJETIVO: %s" % Content.CAMPAIGN[mission_id]["goal"], 17, Color("e9c891"))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(objective)
	left.add_child(_label("ALIADOS", 22))
	for actor in battle.living("ALLY"):
		_add_actor_button(left, actor)
	left.add_child(_label("INIMIGOS", 22))
	for actor in battle.living("ENEMY"):
		_add_actor_button(left, actor)
	left.add_child(_button("Trocar linha (1x/turno)", func(): selected_action = "move"; _render_battle()))
	left.add_child(_button("Encerrar turno", func(): selected_card = -1; battle.end_player_turn()))
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightPanel"
	right_scroll.position = Vector2(viewport_size.x - 295, 115)
	right_scroll.size = Vector2(275, maxf(170.0, viewport_size.y - 310.0))
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 260
	right_scroll.add_child(right)
	right.add_child(_label("CENÁRIO", 22))
	for index in range(battle.mission.get("environment", []).size()):
		var object: Dictionary = battle.mission["environment"][index]
		right.add_child(_button("%s · %d Ímpeto" % [object["name"], object["cost"]], func(): battle.use_environment(index)))
	right.add_child(_label("ITENS", 22))
	for id in battle.items:
		right.add_child(_button("%s ×%d" % [id.capitalize(), battle.items[id]], func(): selected_action = "item:" + id; selected_card = -1; _render_battle()))
	right.add_child(_label("LOG", 22))
	for entry in event_history.slice(max(0, event_history.size() - 5)):
		var line := _label(entry, 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 260
		right.add_child(line)
	var bottom := HBoxContainer.new()
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroller"
	hand_scroll.position = Vector2(20, viewport_size.y - 95)
	hand_scroll.size = Vector2(viewport_size.x - 40, 80)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(hand_scroll)
	bottom.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(bottom)
	for index in range(battle.hand.size()):
		var card: Dictionary = battle.hand[index]
		var definition: Dictionary = Content.CARDS[card["id"]]
		var owner: Dictionary = battle.actor_by_id(card["owner"])
		var button := _button("%s\n%s" % [definition["name"], owner["name"]], func(): _select_card(index), _card_description(definition, card))
		button.custom_minimum_size = Vector2(132, 68)
		bottom.add_child(button)
		card_hit_areas.append(button)
		_make_3d_card(index, card, definition)
		if selected_card == index: button.modulate = Color("ffd680")
	bottom.add_child(_button("Redesenhar carta", func(): selected_action = "redraw"; _render_battle()))
	hover_hint = _label("Q/E ou LB/RB: cartas · ↑/↓: alvo · Enter/A: confirmar · R/X: redesenhar · T/Y: turno · M: mover · Esc/B: cancelar", 16, Color("c9d1dd"))
	hover_hint.position = Vector2(20, viewport_size.y - 185)
	hover_hint.custom_minimum_size.x = viewport_size.x - 40
	hover_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hover_hint)
	var status := _label("%s%s" % [feedback, "  ·  ALVOS %d/%d" % [chain_targets.size(), Content.CARDS[battle.hand[selected_card]["id"]].get("chain", 1)] if selected_card >= 0 and selected_card < battle.hand.size() and not chain_targets.is_empty() else ""], 19, Color("f7d499"))
	status.position = Vector2(20, viewport_size.y - 145)
	status.custom_minimum_size.x = viewport_size.x - 40
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(status)
	_render_actors()
	visible_uids.clear()
	for visible_card in battle.hand: visible_uids[visible_card["uid"]] = true

func _add_actor_button(parent: VBoxContainer, actor: Dictionary) -> void:
	var status_names: Array = actor["statuses"].keys()
	var text_value := "%s [%s] %d/%d PV +%d" % [actor["name"], "F" if actor["row"] == "front" else "T", actor["hp"], actor["max_hp"], actor["block"] + actor["shield"]]
	var hint := ", ".join(PackedStringArray(status_names)).replace("_", " ")
	if selected_card >= 0 and selected_card < battle.hand.size():
		var preview_chain: Array = []
		if Content.CARDS[battle.hand[selected_card]["id"]].get("target", "") == "CHAIN":
			preview_chain = chain_targets.duplicate()
			preview_chain.append(actor["id"])
		var estimate: Dictionary = battle.preview(selected_card, actor["id"], preview_chain)
		if not estimate.is_empty():
			var owner: Dictionary = battle.actor_by_id(battle.hand[selected_card]["owner"])
			for id in estimate["targets"]:
				var line: Dictionary = estimate["targets"][id]
				var victim: Dictionary = battle.actor_by_id(id)
				var factor: float = Content.TYPES.get(owner.get("type", ""), {}).get(victim.get("type", ""), 1.0)
				var type_note := " · vantagem" if factor > 1.0 else " · resistência" if factor < 1.0 else ""
				var chance_note := "possível alvo · " if estimate.get("random", false) else ""
				hint += "\n%s%s: −%d PV, resta %d%s%s" % [chance_note, victim["name"], line["damage"], line["hp_after"], " · KO" if line["hp_after"] == 0 else "", type_note]
				if line["absorbed"] > 0: hint += " · %d absorvido" % line["absorbed"]
				if line["resist_used"] > 0: hint += " · %d Resistência consumida" % line["resist_used"]
				if line["row_after"] != victim["row"]: hint += " · move para %s" % ("frente" if line["row_after"] == "front" else "trás")
				if line["statuses"].size() > 0: hint += " · estados: %s" % ", ".join(PackedStringArray(line["statuses"]))
				if line["drop_chance"] > 0.0: hint += " · queda: %d%%" % roundi(line["drop_chance"] * 100.0)
			if estimate["self_effects"].size() > 0: hint += "\nEfeitos no usuário: %s" % ", ".join(PackedStringArray(estimate["self_effects"]))
			if estimate["other_effects"].size() > 0: hint += "\nOutros efeitos: %s" % ", ".join(PackedStringArray(estimate["other_effects"]))
			hint += "\nAções após jogar: %d · Ímpeto: %d" % [estimate["plays_after"], estimate["impulse_after"]]
			if not estimate["playable"]: hint += " · faltam ações, Ímpeto ou acertos"
	var button := _button(text_value, func(): _choose_target(actor["id"]), hint)
	button.custom_minimum_size = Vector2(260, 42)
	if _target_ids().size() > target_cursor and _target_ids()[target_cursor] == actor["id"]:
		button.modulate = Color("f9d18b")
	parent.add_child(button)

func _select_card(index: int) -> void:
	if sound != null: sound.cue("select", "UI")
	if selected_action == "redraw":
		selected_action = ""
		_animate_card_depart(index)
		battle.redraw(index)
		return
	selected_action = ""
	selected_card = index if selected_card != index else -1
	chain_targets.clear()
	if selected_card >= 0:
		var definition: Dictionary = Content.CARDS[battle.hand[index]["id"]]
		if definition["target"] == "SELF":
			_choose_target(battle.hand[index]["owner"])
			return
		feedback = "Escolha o alvo para %s." % definition["name"]
	_render_battle()

func _choose_target(actor_id: int) -> void:
	if selected_action == "move":
		selected_action = ""
		battle.move_actor(actor_id)
		return
	if selected_action.begins_with("item:"):
		var item_id := selected_action.trim_prefix("item:")
		selected_action = ""
		battle.use_item(item_id, actor_id)
		return
	if selected_card < 0 or selected_card >= battle.hand.size():
		feedback = "Selecione uma carta para mostrar a prévia."
		_render_battle()
		return
	var definition: Dictionary = Content.CARDS[battle.hand[selected_card]["id"]]
	if definition.get("target", "") == "CHAIN":
		chain_targets.append(actor_id)
		if chain_targets.size() < int(definition.get("chain", 1)):
			feedback = "Escolha o próximo acerto (%d/%d)." % [chain_targets.size(), definition["chain"]]
			_render_battle()
			return
	var preview: Dictionary = battle.preview(selected_card, actor_id, chain_targets)
	if preview.is_empty():
		feedback = "Alvo indisponível para esta carta."
		chain_targets.clear()
		_render_battle()
		return
	if preview.get("playable", false): _animate_card_depart(selected_card)
	var successful: bool = battle.play(selected_card, actor_id, chain_targets)
	chain_targets.clear()
	if successful:
		selected_card = -1
	else:
		feedback = "Sem ação, Ímpeto, alcance ou alvo válido."
	_render_battle()

func _render_actors() -> void:
	unit_sprites.clear()
	var present := {}
	var allies: Array = battle.living("ALLY")
	var enemies: Array = battle.living("ENEMY")
	for group in [allies, enemies]:
		for actor in group:
			var id: int = actor["id"]
			present[id] = true
			var side: String = actor["side"]
			var row: String = actor["row"]
			var row_count := 0
			var row_index := 0
			for other in group:
				if other["row"] == row:
					if other["id"] == actor["id"]: row_index = row_count
					row_count += 1
			var x := (row_index - (row_count - 1) / 2.0) * 2.2
			var z := (3.15 if row == "back" else 1.55) * (1 if side == "ALLY" else -1)
			var location := Vector3(x, 0, z)
			if not actor_nodes.has(id):
				actor_nodes[id] = _create_actor_visual(actor)
				actor_nodes[id].position = location
			else:
				var body: Node3D = actor_nodes[id]
				if body.position.distance_to(location) > 0.01:
					create_tween().tween_property(body, "position", location, 0.3 / animation_speed)
			var avatar: Sprite3D = actor_nodes[id].get_node_or_null("Avatar")
			if avatar != null:
				unit_sprites.append(avatar)
				presentation.bind_actor(id, avatar, location)
			var nameplate: Label3D = actor_nodes[id].get_node("Nameplate")
			nameplate.text = "%s · %d/%d" % [actor["name"], actor["hp"], actor["max_hp"]]
	for id in actor_nodes.keys():
		if not present.has(id):
			var departing: Node3D = actor_nodes[id]
			presentation.forget_actor(id)
			actor_nodes.erase(id)
			if is_instance_valid(departing):
				var fade := create_tween()
				fade.tween_property(departing, "scale", Vector3.ZERO, 0.24 / animation_speed)
				fade.tween_callback(departing.queue_free)

func _create_actor_visual(actor: Dictionary) -> Node3D:
	var body := Node3D.new()
	units.add_child(body)
	var shadow := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.53
	disk.bottom_radius = 0.53
	disk.height = 0.02
	shadow.mesh = disk
	shadow.material_override = _material(Color(0.02, 0.02, 0.04, 0.55), true)
	shadow.position.y = 0.01
	body.add_child(shadow)
	if ResourceLoader.exists(actor["sprite"]):
		var sheet: Texture2D = load(actor["sprite"])
		var columns := 9
		var rows := 6
		var region := Rect2(0, 0, sheet.get_width() / 9.0, sheet.get_height() / 6.0)
		if str(actor["sprite"]).ends_with("hero_rogue.png"):
			columns = 1
			rows = 1
			region = Rect2(Vector2.ZERO, sheet.get_size())
		elif str(actor["sprite"]).ends_with("hero_wizard.png"):
			columns = 1
			rows = 1
			region = Rect2(0, 0, 420, 768)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		var sprite := Sprite3D.new()
		sprite.name = "Avatar"
		sprite.texture = atlas
		sprite.set_meta("columns", columns)
		sprite.set_meta("rows", rows)
		sprite.pixel_size = 2.2 / region.size.y
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position.y = 1.1
		body.add_child(sprite)
	var plate := Label3D.new()
	plate.name = "Nameplate"
	plate.font_size = 36
	plate.pixel_size = 0.006
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position.y = 2.55
	body.add_child(plate)
	return body

func _make_3d_card(index: int, card: Dictionary, definition: Dictionary) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(320, 480)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_hosts.add_child(view)
	var panel := ColorRect.new()
	panel.color = Color("28314a")
	panel.size = Vector2(320, 480)
	view.add_child(panel)
	var trim := ColorRect.new()
	trim.color = Color("c49f60")
	trim.position = Vector2(12, 12)
	trim.size = Vector2(296, 456)
	panel.add_child(trim)
	var interior := ColorRect.new()
	interior.color = Color("202943")
	interior.position = Vector2(18, 18)
	interior.size = Vector2(284, 444)
	panel.add_child(interior)
	var owner: Dictionary = battle.actor_by_id(card["owner"])
	var title := _label(definition["name"], 26, Color("f2dcad"))
	title.position = Vector2(35, 30)
	title.size = Vector2(250, 75)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)
	var owner_label := _label(str(owner.get("name", "")) + " · " + str(definition.get("class", "")), 20)
	owner_label.position = Vector2(35, 105)
	panel.add_child(owner_label)
	var symbol := _label("✦", 90, Color("ad9273"))
	symbol.position = Vector2(122, 170)
	panel.add_child(symbol)
	var description := _label(_card_description(definition, card), 18)
	description.position = Vector2(35, 280)
	description.size = Vector2(250, 160)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	var face := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.14, 1.72)
	face.mesh = plane
	var material := _material(Color.WHITE, true)
	material.albedo_texture = view.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = material
	face.position = Vector3((index - (battle.hand.size() - 1) / 2.0) * 1.1, 0.92, 6.6)
	face.rotation_degrees.x = -18
	cards_3d.add_child(face)
	card_meshes.append(face)
	if not visible_uids.has(card["uid"]) and not reduce_motion:
		face.position.y = -1.4
		create_tween().tween_property(face, "position:y", 0.92, 0.32 / animation_speed)
	var hit_area := Area3D.new()
	hit_area.set_meta("card_index", index)
	face.add_child(hit_area)
	var hit_shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = Vector3(1.14, 1.72, 0.13)
	hit_shape.shape = solid
	hit_area.add_child(hit_shape)
	_add_box(Vector3(0, 0, -0.035), Vector3(1.18, 1.76, 0.055), Color("151b30"), face)

func _animate_card_depart(index: int) -> void:
	if index < 0 or index >= card_meshes.size() or reduce_motion: return
	var original: MeshInstance3D = card_meshes[index]
	if not is_instance_valid(original): return
	var ghost := MeshInstance3D.new()
	ghost.mesh = original.mesh
	ghost.material_override = _material(Color("d4ad73"), true)
	ghost.position = original.global_position
	add_child(ghost)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", Vector3(0, 2.0, 0), 0.3 / animation_speed)
	tween.tween_property(ghost, "scale", Vector3.ZERO, 0.3 / animation_speed)
	tween.chain().tween_callback(ghost.queue_free)

func _register_inputs() -> void:
	var bindings := {
		"hotn_previous": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
		"hotn_next": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
		"hotn_target_previous": [KEY_UP, JOY_BUTTON_DPAD_UP],
		"hotn_target_next": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
		"hotn_confirm": [KEY_ENTER, JOY_BUTTON_A],
		"hotn_cancel": [KEY_ESCAPE, JOY_BUTTON_B],
		"hotn_redraw": [KEY_R, JOY_BUTTON_X],
		"hotn_end": [KEY_T, JOY_BUTTON_Y],
		"hotn_move": [KEY_M, JOY_BUTTON_DPAD_LEFT]
	}
	for action in bindings:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action][0]
		InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.button_index = bindings[action][1]
		InputMap.action_add_event(action, button)

func _target_ids() -> Array[int]:
	var ids: Array[int] = []
	if battle == null: return ids
	for actor in battle.living("ALLY") + battle.living("ENEMY"):
		ids.append(actor["id"])
	return ids

func _input(event: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER": return
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("hotn_next") or event.is_action_pressed("hotn_previous"):
		if battle.hand.is_empty(): return
		var step := 1 if event.is_action_pressed("hotn_next") else -1
		_select_card(posmod(selected_card + step, battle.hand.size()))
	elif event.is_action_pressed("hotn_target_next") or event.is_action_pressed("hotn_target_previous"):
		var ids := _target_ids()
		if ids.is_empty(): return
		target_cursor = posmod(target_cursor + (1 if event.is_action_pressed("hotn_target_next") else -1), ids.size())
		_render_battle()
	elif event.is_action_pressed("hotn_confirm"):
		var ids := _target_ids()
		if not ids.is_empty(): _choose_target(ids[target_cursor % ids.size()])
	elif event.is_action_pressed("hotn_redraw"):
		selected_action = "redraw"
		feedback = "Selecione a carta para redesenhar."
		_render_battle()
	elif event.is_action_pressed("hotn_move"):
		selected_action = "move"
		feedback = "Selecione o aliado para trocar de linha."
		_render_battle()
	elif event.is_action_pressed("hotn_end"):
		selected_card = -1
		battle.end_player_turn()
	elif event.is_action_pressed("hotn_cancel"):
		selected_card = -1
		selected_action = ""
		chain_targets.clear()
		_render_battle()
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(input: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER" or not input is InputEventMouseButton:
		return
	var click := input as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var origin := camera.project_ray_origin(click.position)
	var end := origin + camera.project_ray_normal(click.position) * 80.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("collider") and hit["collider"].has_meta("card_index"):
		_select_card(int(hit["collider"].get_meta("card_index")))
		get_viewport().set_input_as_handled()

func _card_description(definition: Dictionary, card: Dictionary = {}) -> String:
	var parts: Array[String] = []
	var target_names := {"SELF": "em si", "ALLY": "aliado", "ALL_ALLIES": "todos os aliados", "ENEMY": "inimigo", "SINGLE": "inimigo", "ENEMY_ROW": "linha inimiga", "ROW": "linha inimiga", "FRONT_ROW": "frente inimiga", "BACK_ROW": "retaguarda inimiga", "ALL_ENEMIES": "todos os inimigos", "ADJACENT": "alvo e adjacentes", "RANDOM": "inimigo aleatório", "CHAIN": "sequência", "ANY_UNIT": "qualquer unidade"}
	parts.append("ALVO: " + target_names.get(definition.get("target", "ENEMY"), "inimigo"))
	if definition.get("quick", false): parts.append("RÁPIDA: devolve ação no KO")
	if definition.get("free", false): parts.append("LIVRE")
	if definition.get("final", false): parts.append("FINAL: herói encerra ações")
	if definition.get("exhaust", false): parts.append("EXAURE ao jogar")
	if definition.has("roulette"): parts.append("ROULETTE: sorteia efeito ao comprar")
	if definition.has("full_combo"): parts.append("COMBO COMPLETO: todos os acertos no mesmo alvo")
	if definition.get("reach", false): parts.append("ALCANCE")
	if definition.get("chain", 0) > 0: parts.append("CHAIN %d" % definition["chain"])
	if definition.get("cost", 0) > 0: parts.append("−%d Ímpeto" % definition["cost"])
	if definition.get("gain", 0) > 0: parts.append("+%d Ímpeto" % definition["gain"])
	for effect in definition.get("effects", []):
		match effect["kind"]:
			"STATUS": parts.append("%s (%d turno(s), %d carga(s))" % [str(effect["id"]).replace("_", " ").capitalize(), effect.get("duration", 1), effect.get("stacks", 1)])
			"DAMAGE": parts.append("Dano base %d + atributo" % int(effect.get("amount", 0)))
			"HEAL": parts.append("Cura %d" % int(effect.get("amount", 0)))
			"BLOCK": parts.append("Bloqueio %d" % int(effect.get("amount", 0)))
			"SHIELD": parts.append("Escudo %d" % int(effect.get("amount", 0)))
			"DRAW": parts.append("Compra %d" % int(effect.get("amount", 1)))
			"GENERATE": parts.append("Cria %s (temporária)" % Content.CARDS.get(effect.get("id", ""), {}).get("name", "carta"))
			"PUSH": parts.append("Empurra%s" % (" com força" if effect.get("forceful", false) else ""))
			"PULL": parts.append("Puxa")
			"CURE": parts.append("Remove estados negativos")
			"NEXT_TURN": parts.append("Efeito no próximo turno")
			"INFECT": parts.append("Infecta uma carta")
			_: parts.append("%s %s" % [effect["kind"], str(effect.get("amount", effect.get("id", "")))])
	if card.has("roulette_effect"):
		var chosen: Dictionary = card["roulette_effect"]
		parts.append("SORTEADO: %s %s" % [chosen.get("kind", ""), str(chosen.get("amount", chosen.get("id", "")))])
	if card.get("infected", false): parts.append("INFECTADA: recebe 1 Sangramento ao jogar")
	return " · ".join(PackedStringArray(parts))

func _process(delta: float) -> void:
	for i in range(unit_sprites.size()):
		if is_instance_valid(unit_sprites[i]):
			unit_sprites[i].position.y = 1.1 + (0.0 if reduce_motion else sin(Time.get_ticks_msec() * 0.002 + i) * 0.045)
	if battle != null and battle.phase == "PLAYER":
		var pointer := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(pointer)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pointer) * 80.0)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var new_hover := int(hit["collider"].get_meta("card_index")) if hit.has("collider") and hit["collider"].has_meta("card_index") else -1
		if new_hover != hovered_card:
			hovered_card = new_hover
			if hovered_card >= 0 and hovered_card < battle.hand.size():
				sound.cue("hover", "UI")
				var card: Dictionary = battle.hand[hovered_card]
				if is_instance_valid(hover_hint): hover_hint.text = _card_description(Content.CARDS[card["id"]], card)
			elif is_instance_valid(hover_hint): hover_hint.text = "Q/E ou LB/RB: cartas · ↑/↓: alvo · Enter/A: confirmar · R/X: redesenhar · T/Y: turno · M: mover · Esc/B: cancelar"
	for index in range(min(card_meshes.size(), card_hit_areas.size())):
		if not is_instance_valid(card_meshes[index]) or not is_instance_valid(card_hit_areas[index]): continue
		var active := selected_card == index or hovered_card == index
		var target_y := 1.18 if active else 0.92
		var blend := minf(1.0, delta * 8.0 * animation_speed) if not reduce_motion else 1.0
		card_meshes[index].position.y = lerpf(card_meshes[index].position.y, target_y, blend)
		card_meshes[index].rotation_degrees.y = lerpf(card_meshes[index].rotation_degrees.y, 0.0 if active else (index - (card_meshes.size() - 1) / 2.0) * 2.0, blend)
		card_meshes[index].scale = card_meshes[index].scale.lerp(Vector3.ONE * (1.14 if active else 1.0), blend)

func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "team", team)
	config.set_value("game", "equipped", equipped)
	config.set_value("game", "improvements", improvements)
	config.set_value("game", "best_stars", best_stars)
	config.set_value("game", "essence", essence)
	config.set_value("game", "loadout", loadout)
	config.set_value("settings", "sound_levels", sound_levels)
	config.set_value("settings", "shake_level", shake_level)
	config.set_value("settings", "reduce_flashes", reduce_flashes)
	config.set_value("settings", "reduce_motion", reduce_motion)
	config.set_value("settings", "animation_speed", animation_speed)
	config.save("user://hotn3.cfg")

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load("user://hotn3.cfg") == OK:
		var saved_team: Array = config.get_value("game", "team", team)
		var seen_heroes := {}
		for id in saved_team: seen_heroes[id] = true
		if saved_team.size() == int(Content.RULES["team_size"]) and seen_heroes.size() == saved_team.size() and saved_team.all(func(id): return Content.HEROES.has(id)):
			team.clear()
			for id in saved_team: team.append(id)
		equipped = config.get_value("game", "equipped", {})
		_sanitize_decks()
		improvements = config.get_value("game", "improvements", {})
		var stored_stars: Dictionary = config.get_value("game", "best_stars", {})
		best_stars.clear()
		for id in Content.MISSIONS:
			if stored_stars.has(id) and int(stored_stars[id]) > 0:
				best_stars[id] = clampi(int(stored_stars[id]), 1, 3)
		essence = clampi(int(config.get_value("game", "essence", 0)), 0, 999)
		loadout = config.get_value("game", "loadout", loadout)
		var saved_levels: Dictionary = config.get_value("settings", "sound_levels", {})
		for channel in sound_levels:
			if saved_levels.has(channel): sound_levels[channel] = clampf(float(saved_levels[channel]), 0.0, 1.0)
		if saved_levels.is_empty(): sound_levels["MUSIC"] = clampf(float(config.get_value("settings", "music_volume", sound_levels["MUSIC"])), 0.0, 1.0)
		shake_level = clampf(float(config.get_value("settings", "shake_level", 0.5 if config.get_value("settings", "shake_enabled", true) else 0.0)), 0.0, 1.0)
		reduce_flashes = bool(config.get_value("settings", "reduce_flashes", reduce_flashes))
		reduce_motion = bool(config.get_value("settings", "reduce_motion", reduce_motion))
		animation_speed = clampf(float(config.get_value("settings", "animation_speed", animation_speed)), 0.5, 2.0)
