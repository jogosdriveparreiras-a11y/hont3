extends Node3D

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")
const SoundBus = preload("res://game/SoundBus.gd")
const Presentation = preload("res://game/CombatPresentation.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const CardFace = preload("res://game/CardFace.gd")

var battle
var packs = PackBridge.new()
var pack_mode := "default"
var camera: Camera3D
var stage: Node3D
var units: Node3D
var cards_3d: Node3D
var viewport_hosts: Node
var hud: Control
var team: Array[String] = ["ent_adam", "ent_madelyn", "ent_ashlee"]
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
var seen_hand: Dictionary = {}
var inspected_card := -1
var card_confirmed := false
var hovered_actor := -1
var target_cursor := 0
var visible_uids: Dictionary = {}
var portrait_left: TextureRect
var portrait_right: TextureRect
var portrait_sticky_until := 0
var suppress_inspect_cancel := false
var enemy_presenting := false
var enemy_steps := 0
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
	cards_3d.reparent(camera)
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
	portrait_left = _make_portrait(false)
	portrait_right = _make_portrait(true)
	fx_overlay.add_child(portrait_left)
	fx_overlay.add_child(portrait_right)
	_apply_accessibility()

func _on_viewport_resized() -> void:
	if battle != null and battle.phase in ["PLAYER", "ENEMY"]: _render_battle()

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
	if ResourceLoader.exists("res://assets/ui/button.png"):
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/ui/button.png")
		style.set_texture_margin_all(16)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", Color("f6edd8"))
		button.add_theme_color_override("font_hover_color", Color("fff6df"))
	return button

func _center_panel(title: String) -> VBoxContainer:
	_clear_ui()
	_clear_combat_visuals()
	var frame := CenterContainer.new()
	hud.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	if ResourceLoader.exists("res://assets/ui/panel.png"):
		var panel_style := StyleBoxTexture.new()
		panel_style.texture = load("res://assets/ui/panel.png")
		panel_style.set_texture_margin_all(28)
		panel.add_theme_stylebox_override("panel", panel_style)
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
	var menu_panel := menu.get_parent() as PanelContainer
	menu_panel.custom_minimum_size = Vector2(720, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, minf(520.0, get_viewport().get_visible_rect().size.y - 260.0))
	menu.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var playable_ids: Array[String] = []
	for id in Content.HEROES:
		if Content.HEROES[id].get("playable", true):
			playable_ids.append(str(id))
	playable_ids.sort()
	for id in playable_ids:
		var hero: Dictionary = Content.HEROES[id]
		var chosen := team.has(id)
		var identity: Dictionary = Content.HERO_LORE.get(id, {"role": "Anexo", "trait": "Herói expandido.", "history": ""})
		var button := _button(("✓ " if chosen else "+ ") + "%s · %s · %d PV" % [hero["name"], identity["role"], hero["hp"]], _toggle_hero.bind(id), identity["history"] + "\n" + identity["trait"])
		button.custom_minimum_size = Vector2(640, 44)
		list.add_child(button)
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
		var subtitle := "%s · %s" % [definition["class"], "%d Iniciativa" % cost if cost > 0 else "+%d Iniciativa" % int(definition.get("gain", 0))]
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
	var menu := _center_panel("ITENS NO DECK · %d/%d" % [loadout.values().reduce(func(total, n): return total + n, 0), Content.RULES["items_max"]])
	menu.add_child(_label("Cada item vira uma carta cinza, grátis e com Exaustão, embaralhada no deck.", 16))
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
	pack_mode = "default"
	_begin_battle_session()
	battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	_render_battle()

func _begin_battle_session() -> void:
	selected_card = -1
	selected_action = ""
	chain_targets.clear()
	event_history.clear()
	feedback = ""
	battle = Battle.new()
	battle.event.connect(_on_event)
	battle.visual.connect(_on_visual)
	battle.changed.connect(_render_battle)
	battle.finished.connect(_on_finished)



func _card_def(card_id: String) -> Dictionary:
	return packs.definition(str(card_id))

func _on_event(message: String) -> void:
	event_history.append(message)
	if event_history.size() > 8: event_history.pop_front()
	feedback = message

func _on_visual(kind: String, source_id: int, target_id: int, amount: int) -> void:
	if presentation != null: presentation.show_action(kind, source_id, target_id, amount)
	if kind in ["cast", "hit", "heal", "death", "status", "block", "guard"]:
		_show_actor_portrait(source_id, true)
		if target_id != source_id: _show_actor_portrait(target_id, true)

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
		var healthy: bool = survivors.size() == 3 and survivors.all(func(actor): return int(actor["hp"]) * 2 >= int(actor["max_hp"]))
		if battle.mission["objective"] == "PROTECT": healthy = healthy and battle.protect_hp >= int(battle.mission["protect_hp"]) / 2
		if healthy: stars += 1
	elif battle.turn <= int(goal["par"]):
		stars += 1
	return stars

func _render_battle() -> void:
	if battle == null or battle.phase == "FINISHED": return
	_clear_ui()
	_clear_hand_visuals()
	var viewport_size := get_viewport().get_visible_rect().size
	var hand_h := clampf(viewport_size.y * 0.28, 190.0, 320.0)
	var hand_band := hand_h * 1.34
	var hand_top := viewport_size.y - hand_band - 6.0
	var header := VBoxContainer.new()
	hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_child(_label("%s  ·  RODADA %d" % [battle.mission["name"], battle.turn], 23, Color("e9c891")))
	var ally_line := _label("JOGADORES  " + _resource_line("ALLY"), 18)
	ally_line.modulate = Color.WHITE if battle.phase == "PLAYER" else Color(1, 1, 1, 0.38)
	header.add_child(ally_line)
	var enemy_line := _label("ADVERSÁRIOS  " + _resource_line("ENEMY"), 18)
	enemy_line.modulate = Color("ffd0c4") if battle.phase == "ENEMY" else Color(1, 0.78, 0.72, 0.38)
	header.add_child(enemy_line)
	_chrome(Vector2(12, 8), Vector2(viewport_size.x - 24, 118), "res://assets/ui/header.png")
	var extra := ""
	if battle.mission["objective"] == "PROTECT": extra += "SENTINELA %d PV" % battle.protect_hp
	var next_turn: Array = battle.mission.get("reinforcements", {}).get(battle.turn + 1, [])
	if not next_turn.is_empty(): extra += ("  ·  " if extra != "" else "") + "REFORÇOS EM 1 TURNO"
	if extra != "":
		header.add_child(_label(extra, 17, Color("e9c891")))
	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LeftPanel"
	left_scroll.position = Vector2(20, 132)
	left_scroll.size = Vector2(290, maxf(120.0, hand_top - 144.0))
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
	left.add_child(_button("Trocar linha (1x/turno)", func(): selected_action = "move"; card_confirmed = false; inspected_card = -1; feedback = "Aponte o aliado e clique no sprite."; _render_battle()))
	left.add_child(_button("Redesenhar carta", func(): selected_action = "redraw"; card_confirmed = false; inspected_card = -1; feedback = "Clique na carta para redesenhar."; _render_battle()))
	left.add_child(_button("Encerrar turno", func(): _present_enemy_turn()))
	_chrome(Vector2(20, 132), Vector2(290, maxf(120.0, hand_top - 144.0)), "res://assets/ui/panel.png")
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightPanel"
	right_scroll.position = Vector2(viewport_size.x - 295, 132)
	right_scroll.size = Vector2(275, maxf(120.0, hand_top - 144.0))
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 260
	right_scroll.add_child(right)
	right.add_child(_label("CENÁRIO", 22))
	for index in range(battle.mission.get("environment", []).size()):
		var object: Dictionary = battle.mission["environment"][index]
		right.add_child(_button("%s · %d Iniciativa" % [object["name"], object["cost"]], func(): battle.use_environment(index)))
	right.add_child(_label("ITENS", 22))
	right.add_child(_label("Poção, bomba e antídoto estão no deck: grátis e com Exaustão.", 15))
	right.add_child(_label("LOG", 22))
	for entry in event_history.slice(max(0, event_history.size() - 5)):
		var line := _label(entry, 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 260
		right.add_child(line)
	var bottom := HBoxContainer.new()
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroller"
	hand_scroll.position = Vector2(16, hand_top)
	hand_scroll.size = Vector2(viewport_size.x - 32, hand_band)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.clip_contents = false
	hud.add_child(hand_scroll)
	bottom.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(bottom)
	for index in range(battle.hand.size()):
		var card: Dictionary = battle.hand[index]
		var definition: Dictionary = _card_def(str(card["id"]))
		_make_3d_card(index, card, definition)
	hover_hint = _label("Passe o mouse na carta para destacá-la. Clique para ampliar, clique de novo para confirmar. O alvo é o sprite.", 16, Color("c9d1dd"))
	hover_hint.position = Vector2(20, hand_top - 46)
	hover_hint.custom_minimum_size.x = viewport_size.x - 40
	hover_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hover_hint)
	var status := _label("%s%s" % [feedback, "  ·  ALVOS %d/%d" % [chain_targets.size(), _card_def(str(battle.hand[selected_card]["id"])).get("chain", 1)] if selected_card >= 0 and selected_card < battle.hand.size() and not chain_targets.is_empty() else ""], 19, Color("f7d499"))
	status.position = Vector2(20, hand_top - 24)
	status.custom_minimum_size.x = viewport_size.x - 40
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(status)
	_render_actors()
	if inspected_card >= 0 and inspected_card < battle.hand.size() and battle.phase == "PLAYER":
		_add_inspect_overlay(inspected_card, viewport_size)
	visible_uids.clear()
	for visible_card in battle.hand: visible_uids[visible_card["uid"]] = true

func _add_actor_button(parent: VBoxContainer, actor: Dictionary) -> void:
	var text_value := "%s [%s] %d/%d PV +%d" % [actor["name"], "F" if actor["row"] == "front" else "T", actor["hp"], actor["max_hp"], actor["block"] + actor["shield"]]
	var line := _label(text_value, 16)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(line)

func _select_card(index: int) -> void:
	if sound != null: sound.cue("select", "UI")
	if selected_action == "redraw":
		selected_action = ""
		_animate_card_depart(index)
		packs.redraw_card(battle, pack_mode, index)
		return
	selected_action = ""
	selected_card = index if selected_card != index else -1
	chain_targets.clear()
	if selected_card >= 0:
		var definition: Dictionary = _card_def(str(battle.hand[index]["id"]))
		if definition.get("target", "") == "SELF":
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
	var definition: Dictionary = _card_def(str(battle.hand[selected_card]["id"]))
	if definition.get("target", "") == "CHAIN":
		chain_targets.append(actor_id)
		if chain_targets.size() < int(definition.get("chain", 1)):
			feedback = "Escolha o próximo acerto (%d/%d)." % [chain_targets.size(), definition["chain"]]
			_render_battle()
			return
	var card_id: String = str(battle.hand[selected_card].get("id", ""))
	var successful: bool = false
	if packs.is_pack_card(card_id) or pack_mode != "default":
		_animate_card_depart(selected_card)
		successful = packs.play_card(battle, pack_mode, selected_card, actor_id, chain_targets)
	else:
		var preview: Dictionary = battle.preview(selected_card, actor_id, chain_targets)
		if preview.is_empty():
			feedback = "Alvo indisponível para esta carta."
			chain_targets.clear()
			_render_battle()
			return
		if preview.get("playable", false): _animate_card_depart(selected_card)
		successful = battle.play(selected_card, actor_id, chain_targets)
	chain_targets.clear()
	if successful:
		selected_card = -1
		card_confirmed = false
		inspected_card = -1
		selected_action = ""
	else:
		feedback = "Sem ação, Iniciativa, alcance ou alvo válido."
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
		var columns := 1
		var rows := 1
		var region := Rect2(Vector2.ZERO, sheet.get_size())
		var sheet_path := str(actor["sprite"])
		if sheet_path.ends_with("hero_wizard.png"):
			region = Rect2(0, 0, 420, 768)
		elif not sheet_path.contains("assets/cast") and not sheet_path.ends_with("hero_rogue.png"):
			columns = 9
			rows = 6
			region = Rect2(0, 0, sheet.get_width() / 9.0, sheet.get_height() / 6.0)
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
	var area := Area3D.new()
	area.set_meta("actor_id", int(actor["id"]))
	body.add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 2.3, 0.45)
	shape.shape = box
	shape.position.y = 1.15
	area.add_child(shape)
	return body

func _make_3d_card(index: int, card: Dictionary, definition: Dictionary) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(400, 620)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_hosts.add_child(view)
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var face = CardFace.new()
	face.size = Vector2(400, 620)
	face.setup(_card_spec(card, definition, owner))
	view.add_child(face)
	var mesh := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.05, 1.62)
	mesh.mesh = plane
	var material := _material(Color.WHITE, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = view.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	var pose: Dictionary = _arc_pose(index, battle.hand.size())
	var slot: Vector3 = pose["position"]
	var spin: Vector3 = pose["rotation"]
	var uid := int(card.get("uid", -1))
	var entering := not seen_hand.has(uid)
	mesh.position = slot
	mesh.rotation = spin
	if entering:
		mesh.position = slot + Vector3(2.8, 0.45, 0.0)
		mesh.rotation = spin + Vector3(0, 0, 0.95)
	cards_3d.add_child(mesh)
	if entering and not reduce_motion:
		var arrive := create_tween()
		arrive.set_parallel(true)
		arrive.tween_property(mesh, "position", slot, 0.34)
		arrive.tween_property(mesh, "rotation", spin, 0.34)
	seen_hand[uid] = true
	var area := Area3D.new()
	area.set_meta("card_index", index)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.55, 0.12)
	shape.shape = box
	area.add_child(shape)
	mesh.add_child(area)
	card_meshes.append(mesh)

func _animate_card_depart(index: int) -> void:
	if index < 0 or index >= card_meshes.size() or reduce_motion: return
	var original: MeshInstance3D = card_meshes[index]
	if not is_instance_valid(original): return
	var ghost := MeshInstance3D.new()
	ghost.mesh = original.mesh
	ghost.material_override = original.material_override
	ghost.transform = original.transform
	camera.add_child(ghost)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", original.position + Vector3(-3.4, 0.35, -0.15), 0.32 / animation_speed)
	tween.tween_property(ghost, "rotation:z", original.rotation.z - 1.15, 0.32 / animation_speed)
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


func _chrome(at: Vector2, box: Vector2, path: String) -> void:
	if not ResourceLoader.exists(path): return
	var plate := TextureRect.new()
	plate.texture = load(path)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = -1
	plate.position = at
	plate.size = box
	hud.add_child(plate)

func _set_orbit(target: float) -> void:
	if presentation == null: return
	var tw := create_tween()
	tw.tween_property(presentation, "orbit", target, 0.7 / maxf(animation_speed, 0.25))
	await tw.finished

func _arc_pose(index: int, count: int) -> Dictionary:
	var t := 0.5
	if count > 1:
		t = float(index) / float(count - 1)
	var spread := minf(0.95, 0.12 * float(maxi(count, 1)))
	var ang := lerpf(-spread, spread, t)
	return {
		"position": Vector3(sin(ang) * 1.75, -1.08 + cos(ang) * 0.26, -2.7),
		"rotation": Vector3(-0.05, 0.0, -ang * 0.92)
	}

func _type_color(kind: String) -> Color:
	match kind:
		"BRUTO": return Color("6e1c24")
		"TECNICO": return Color("e07a2f")
		"PSICOLOGICO": return Color("7a3ea1")
		"MENTAL": return Color("e56aa8")
		"PROJETIVO": return Color("3d4db8")
		"QUIMICO": return Color("2ec4b6")
		_: return Color("8d929a")

func _load_tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _stat_readout(owner: Dictionary, definition: Dictionary) -> Dictionary:
	var stat_name := "attack"
	var flat := 0
	if str(definition.get("stat", "")) == "power":
		stat_name = "power"
	for effect in definition.get("effects", []):
		if str(effect.get("kind", "")) != "DAMAGE":
			continue
		flat = int(effect.get("amount", 0))
		var named := str(effect.get("stat", "attack"))
		if named == "power":
			stat_name = "power"
		elif named == "attack":
			stat_name = "attack"
	var archetype := str(owner.get("archetype", ""))
	var base_attr := int(owner.get(stat_name, 0))
	if Content.HEROES.has(archetype):
		base_attr = int(Content.HEROES[archetype].get(stat_name, base_attr))
	var current_attr := int(owner.get(stat_name, base_attr))
	var baseline := maxi(0, flat + base_attr)
	var current := flat + current_attr
	if battle != null and battle._has_status(owner, "weak"):
		current = int(round(float(current) * 0.5))
	if battle != null and battle._has_status(owner, "strengthened"):
		current = int(round(float(current) * 1.5))
	if battle != null and (battle._has_status(owner, "binary") or battle._has_status(owner, "overpowered")):
		current = current * 2
	current = maxi(0, current)
	var tint := Color("f4f7fb")
	if current > baseline:
		tint = Color("7dE28a")
	elif current < baseline:
		tint = Color("e15b5b")
	var label := "PODER" if stat_name == "power" else "ATAQUE"
	return {"label": label, "value": current, "color": tint}

func _rules_bbcode(definition: Dictionary, card: Dictionary) -> String:
	var lines: Array[String] = []
	if definition.get("quick", false): lines.append("[b]Quick[/b]: devolve a ação no nocaute")
	if definition.get("free", false): lines.append("[b]Livre[/b]")
	if definition.get("final", false): lines.append("[b]Final[/b]")
	if definition.get("reach", false): lines.append("[b]Alcance[/b]")
	if int(definition.get("chain", 0)) > 0: lines.append("[b]Chain[/b] %d" % int(definition["chain"]))
	if definition.get("exhaust", false) or definition.get("item", false):
		lines.append("[color=#e15b5b][b]Exhaust[/b][/color]")
	var harmful := ["weak", "vulnerable", "bleed", "poison", "burn", "stun", "bind", "bound", "wound", "wounded"]
	for effect in definition.get("effects", []):
		var kind := str(effect.get("kind", ""))
		if kind == "DAMAGE":
			lines.append("Dano %d" % int(effect.get("amount", 0)))
		elif kind == "HEAL":
			lines.append("Cura %d" % int(effect.get("amount", 0)))
		elif kind == "BLOCK":
			lines.append("[b]Bloqueio[/b] %d" % int(effect.get("amount", 0)))
		elif kind == "CURE":
			lines.append("Remove veneno, sangramento e queimadura")
		elif kind == "STATUS":
			var status_id := str(effect.get("id", ""))
			var piece := "[b]%s[/b]" % status_id
			if status_id in harmful:
				piece = "[color=#e15b5b]%s[/color]" % piece
			lines.append(piece)
		elif kind == "DISCARD":
			lines.append("[color=#e15b5b]Descarte[/color]")
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		if op in ["hit", "hit_per_impulse", "hit_per_hand", "roulette_hit"]:
			lines.append("Dano escalado")
		elif op in ["self_damage", "self_damage_hp"]:
			lines.append("[color=#e15b5b]Dano a si[/color]")
		elif op in ["discard_hand", "discard_random"]:
			lines.append("[color=#e15b5b]Descarta cartas[/color]")
		elif op == "exhaust":
			lines.append("[color=#e15b5b][b]Exhaust[/b][/color]")
		elif op in ["heal", "heal_all", "full_heal"]:
			lines.append("Cura")
		elif op in ["block", "block_hp"]:
			lines.append("[b]Bloqueio[/b]")
		elif op in ["status", "self_status"]:
			var status_id := str(action[1]) if action.size() > 1 else ""
			var piece := "[b]%s[/b]" % status_id
			if status_id in harmful:
				piece = "[color=#e15b5b]%s[/color]" % piece
			lines.append(piece)
		elif op == "quick":
			lines.append("[b]Quick[/b]")
		elif op == "push":
			lines.append("Empurra")
		elif op == "pull":
			lines.append("Puxa")
	if card.get("infected", false):
		lines.append("[color=#e15b5b]Infectada[/color]")
	return "\n".join(lines)

func _card_spec(card: Dictionary, definition: Dictionary, owner: Dictionary) -> Dictionary:
	var item := bool(definition.get("item", false))
	var art_path := str(definition.get("art", ""))
	var art: Texture2D = _load_tex(art_path)
	if art == null:
		art = _load_tex(str(owner.get("portrait", "")))
	if art == null:
		art = _unit_portrait(owner)
	var icon: Texture2D = _load_tex("res://assets/items/item_icon.png") if item else _load_tex(str(owner.get("signature_icon", "")))
	var readout: Dictionary = _stat_readout(owner, definition)
	var border := Color("8d929a") if item else _type_color(str(owner.get("type", "")))
	return {
		"title": str(definition.get("name", "")),
		"chip": "Item" if item else str(owner.get("name", "")),
		"item": item,
		"art": art,
		"icon": icon,
		"border": border,
		"stat_label": str(readout["label"]),
		"stat_value": int(readout["value"]),
		"stat_color": readout["color"],
		"rules": _rules_bbcode(definition, card),
		"gain": int(definition.get("gain", 0)),
		"cost": int(definition.get("cost", 0))
	}

func _resource_line(side: String) -> String:
	var plays: int = battle.card_plays if side == "ALLY" else battle.enemy_card_plays
	var initiative: int = battle.impulse if side == "ALLY" else battle.enemy_impulse
	var redraw_left: int = battle.redraws if side == "ALLY" else battle.enemy_redraws
	var move_left: int = battle.moves if side == "ALLY" else battle.enemy_moves
	var deck_n: int = battle.deck.size() if side == "ALLY" else battle.enemy_deck.size()
	var discard_n: int = battle.discard.size() if side == "ALLY" else battle.enemy_discard.size()
	return "AÇÕES %d  ·  INICIATIVA %d/%d  ·  RECOMPRA %d  ·  MOVER %d  ·  DECK %d  ·  DESCARTE %d" % [plays, initiative, int(battle.rules["impulse_max"]), redraw_left, move_left, deck_n, discard_n]

func _make_portrait(flip: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "PortraitRight" if flip else "PortraitLeft"
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.flip_h = flip
	rect.hide()
	return rect

func _layout_portraits() -> void:
	if portrait_left == null or portrait_right == null: return
	var vp := get_viewport().get_visible_rect().size
	var height := vp.y * 0.62
	var width := height * 0.56
	portrait_left.size = Vector2(width, height)
	portrait_left.position = Vector2(12, (vp.y - height) * 0.42)
	portrait_right.size = Vector2(width, height)
	portrait_right.position = Vector2(vp.x - width - 12, (vp.y - height) * 0.42)

func _sprite_region(path: String, sheet: Texture2D) -> Rect2:
	if path.contains("assets/cast") or path.ends_with("hero_rogue.png") or path.ends_with("en_dog.png"):
		return Rect2(Vector2.ZERO, sheet.get_size())
	if path.ends_with("hero_wizard.png"):
		return Rect2(0, 0, minf(420.0, sheet.get_width()), minf(768.0, sheet.get_height()))
	return Rect2(0, 0, sheet.get_width() / 9.0, sheet.get_height() / 6.0)

func _unit_portrait(actor: Dictionary) -> Texture2D:
	var portrait_path := str(actor.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		return load(portrait_path)
	var sprite_path := str(actor.get("sprite", ""))
	var full := sprite_path.replace(".png", "_full.png")
	if full != sprite_path and ResourceLoader.exists(full):
		return load(full)
	if sprite_path == "" or not ResourceLoader.exists(sprite_path):
		return null
	var sheet: Texture2D = load(sprite_path)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = _sprite_region(sprite_path, sheet)
	return atlas

func _card_art(actor: Dictionary, definition: Dictionary, card_id: String) -> Texture2D:
	var configured := str(definition.get("art", ""))
	if configured != "" and ResourceLoader.exists(configured):
		return load(configured)
	var by_id := "res://" + str(actor.get("archetype", "")) + "_" + card_id + ".png"
	if ResourceLoader.exists(by_id):
		return load(by_id)
	var by_name := "res://" + str(actor.get("name", "")).replace(" ", "") + "_" + str(definition.get("name", "")).replace(" ", "") + ".png"
	if ResourceLoader.exists(by_name):
		return load(by_name)
	return _unit_portrait(actor)

func _show_actor_portrait(actor_id: int, sticky: bool) -> void:
	if battle == null or fx_overlay == null: return
	if not is_instance_valid(portrait_left) or not is_instance_valid(portrait_right):
		portrait_left = _make_portrait(false)
		portrait_right = _make_portrait(true)
		fx_overlay.add_child(portrait_left)
		fx_overlay.add_child(portrait_right)
	var actor: Dictionary = battle.actor_by_id(actor_id)
	if actor.is_empty(): return
	_layout_portraits()
	var widget := portrait_left if str(actor.get("side", "")) == "ALLY" else portrait_right
	widget.texture = _unit_portrait(actor)
	widget.show()
	if sticky:
		portrait_sticky_until = maxi(portrait_sticky_until, Time.get_ticks_msec() + int(1100.0 / maxf(animation_speed, 0.25)))

func _hide_idle_portraits() -> void:
	if Time.get_ticks_msec() < portrait_sticky_until: return
	if hovered_card >= 0 or hovered_actor >= 0: return
	if portrait_left != null: portrait_left.hide()
	if portrait_right != null: portrait_right.hide()

func _build_hand_card(index: int, card: Dictionary, definition: Dictionary, height: float) -> Panel:
	var width := height * 0.68
	var host := Panel.new()
	host.custom_minimum_size = Vector2(width, height)
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.clip_contents = true
	var style := StyleBoxFlat.new()
	var hot := hovered_card == index or inspected_card == index or selected_card == index
	style.bg_color = Color("1b2438")
	style.border_color = Color("f0c27a") if hot else Color("6d5838")
	style.set_border_width_all(6 if hot else 3)
	style.set_corner_radius_all(12)
	host.add_theme_stylebox_override("panel", style)
	var owner: Dictionary = battle.actor_by_id(int(card["owner"]))
	var art := TextureRect.new()
	art.texture = _card_art(owner, definition, str(card["id"]))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(8, 8)
	art.size = Vector2(width - 16, height - 44)
	host.add_child(art)
	var who := _label(str(owner.get("name", "")), 14, Color("f6e2b8"))
	who.position = Vector2(10, 10)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(who)
	var title := _label(definition["name"], 16 if height < 280.0 else 28, Color("f6e2b8"))
	title.position = Vector2(10, height - 34 if height < 280.0 else height - 42)
	title.size = Vector2(width - 20, 36)
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(title)
	if height >= 280.0:
		art.size = Vector2(width - 16, height * 0.62)
		var info := _label(_card_description(definition, card), 18, Color("d5deea"))
		info.position = Vector2(14, height * 0.66)
		info.size = Vector2(width - 28, height * 0.22)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(info)
	host.mouse_entered.connect(func() -> void:
		_note_card_hover(index, host, width, height)
	)
	host.mouse_exited.connect(func() -> void:
		if hovered_card == index and inspected_card != index:
			hovered_card = -1
			host.scale = Vector2.ONE
			host.z_index = 0
			_hide_idle_portraits()
	)
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	return host

func _note_card_hover(index: int, host: Control, width: float, height: float) -> void:
	if battle == null or battle.phase != "PLAYER": return
	var changed_hover := hovered_card != index
	hovered_card = index
	if changed_hover and sound != null: sound.cue("hover", "UI")
	if inspected_card != index:
		host.pivot_offset = Vector2(width * 0.5, height)
		host.scale = Vector2(1.28, 1.28)
		host.z_index = 4
	if index >= 0 and index < battle.hand.size():
		_show_actor_portrait(int(battle.hand[index]["owner"]), false)
		if is_instance_valid(hover_hint):
			hover_hint.text = _card_description(_card_def(str(battle.hand[index]["id"])), battle.hand[index])

func _on_card_gui(event: InputEvent, index: int) -> void:
	if battle == null or battle.phase != "PLAYER" or not event is InputEventMouseButton: return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed: return
	if selected_action == "redraw":
		selected_action = ""
		_animate_card_depart(index)
		packs.redraw_card(battle, pack_mode, index)
		get_viewport().set_input_as_handled()
		return
	if inspected_card == index:
		suppress_inspect_cancel = true
		call_deferred("_confirm_inspected")
	else:
		inspected_card = index
		selected_card = -1
		card_confirmed = false
		_show_actor_portrait(int(battle.hand[index]["owner"]), false)
		call_deferred("_render_battle")
	get_viewport().set_input_as_handled()

func _confirm_inspected() -> void:
	suppress_inspect_cancel = false
	var index := inspected_card
	if battle == null or index < 0 or index >= battle.hand.size(): return
	var definition: Dictionary = _card_def(str(battle.hand[index]["id"]))
	var kind := str(definition.get("target", "ENEMY"))
	inspected_card = -1
	selected_card = index
	card_confirmed = true
	selected_action = ""
	_show_actor_portrait(int(battle.hand[index]["owner"]), true)
	if kind == "SELF":
		_choose_target(int(battle.hand[index]["owner"]))
		return
	if kind == "ALL_ALLIES" or kind == "ALL_ENEMIES":
		var pool: Array = battle.living("ALLY" if kind == "ALL_ALLIES" else "ENEMY")
		if not pool.is_empty():
			_choose_target(int(pool[0]["id"]))
		return
	feedback = "Aponte o sprite do alvo e clique para confirmar."
	_render_battle()

func _cancel_inspect() -> void:
	if suppress_inspect_cancel:
		return
	inspected_card = -1
	if not card_confirmed:
		selected_card = -1
	feedback = ""
	_render_battle()

func _add_inspect_overlay(index: int, viewport_size: Vector2) -> void:
	var blocker := Button.new()
	blocker.flat = true
	blocker.focus_mode = Control.FOCUS_NONE
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.z_index = 8
	blocker.pressed.connect(_cancel_inspect)
	hud.add_child(blocker)
	var height := viewport_size.y * 0.5
	var width := height * 0.66
	var card: Dictionary = battle.hand[index]
	var definition: Dictionary = _card_def(str(card["id"]))
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var host = CardFace.new()
	host.size = Vector2(width, height)
	host.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	host.z_index = 9
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.setup(_card_spec(card, definition, owner))
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	hud.add_child(host)

func _present_enemy_turn() -> void:
	if enemy_presenting or battle == null or battle.phase != "PLAYER": return
	enemy_presenting = true
	enemy_steps = 0
	selected_card = -1
	inspected_card = -1
	card_confirmed = false
	selected_action = ""
	chain_targets.clear()
	battle.begin_enemy_phase()
	await _set_orbit(PI)
	if battle == null or battle.phase != "ENEMY":
		enemy_presenting = false
		return
	_step_enemy()

func _step_enemy() -> void:
	if battle == null or battle.phase != "ENEMY":
		enemy_presenting = false
		_set_orbit(0.0)
		return
	enemy_steps += 1
	if enemy_steps > 16:
		battle.finish_enemy_phase()
		packs.on_player_turn_resumed(battle, pack_mode)
		enemy_presenting = false
		_set_orbit(0.0)
		return
	await get_tree().create_timer(0.5 / maxf(animation_speed, 0.25)).timeout
	if battle == null or battle.phase != "ENEMY":
		enemy_presenting = false
		return
	if battle.enemy_step():
		_step_enemy()
	else:
		battle.finish_enemy_phase()
		packs.on_player_turn_resumed(battle, pack_mode)
		enemy_presenting = false
		_set_orbit(0.0)

func _input(event: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER" or enemy_presenting: return
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("hotn_next") or event.is_action_pressed("hotn_previous"):
		if battle.hand.is_empty(): return
		var step := 1 if event.is_action_pressed("hotn_next") else -1
		var base := inspected_card if inspected_card >= 0 else hovered_card
		hovered_card = posmod(base + step, battle.hand.size())
		inspected_card = hovered_card
		card_confirmed = false
		selected_card = -1
		_show_actor_portrait(int(battle.hand[hovered_card]["owner"]), false)
		_render_battle()
	elif event.is_action_pressed("hotn_target_next") or event.is_action_pressed("hotn_target_previous"):
		var ids := _target_ids()
		if ids.is_empty(): return
		target_cursor = posmod(target_cursor + (1 if event.is_action_pressed("hotn_target_next") else -1), ids.size())
		hovered_actor = ids[target_cursor]
		_show_actor_portrait(hovered_actor, false)
		_render_battle()
	elif event.is_action_pressed("hotn_confirm"):
		if inspected_card >= 0 and not card_confirmed:
			_confirm_inspected()
		elif card_confirmed or selected_action != "":
			var ids := _target_ids()
			if not ids.is_empty(): _activate_actor(ids[target_cursor % ids.size()])
		elif hovered_card >= 0:
			inspected_card = hovered_card
			_render_battle()
	elif event.is_action_pressed("hotn_redraw"):
		selected_action = "redraw"
		card_confirmed = false
		inspected_card = -1
		feedback = "Clique na carta para redesenhar."
		_render_battle()
	elif event.is_action_pressed("hotn_move"):
		selected_action = "move"
		card_confirmed = false
		inspected_card = -1
		feedback = "Aponte o aliado e clique no sprite."
		_render_battle()
	elif event.is_action_pressed("hotn_end"):
		_present_enemy_turn()
	elif event.is_action_pressed("hotn_cancel"):
		selected_card = -1
		inspected_card = -1
		card_confirmed = false
		selected_action = ""
		chain_targets.clear()
		feedback = ""
		_render_battle()
	else:
		return
	get_viewport().set_input_as_handled()

func _activate_actor(actor_id: int) -> void:
	if battle == null or battle.phase != "PLAYER": return
	hovered_actor = actor_id
	_show_actor_portrait(actor_id, true)
	if selected_action == "move" or selected_action.begins_with("item:") or (card_confirmed and selected_card >= 0):
		_choose_target(actor_id)

func _unhandled_input(input: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER" or enemy_presenting or not input is InputEventMouseButton:
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
		_on_card_gui(click, int(hit["collider"].get_meta("card_index")))
		get_viewport().set_input_as_handled()
		return
	if hit.has("collider") and hit["collider"].has_meta("actor_id"):
		_activate_actor(int(hit["collider"].get_meta("actor_id")))
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
	if definition.get("cost", 0) > 0: parts.append("−%d Iniciativa" % definition["cost"])
	if definition.get("gain", 0) > 0: parts.append("+%d Iniciativa" % definition["gain"])
	for action_line in packs.describe_actions(definition):
		parts.append(action_line)
	for effect in definition.get("effects", []):
		match effect["kind"]:
			"STATUS": parts.append("%s (%d turno(s), %d carga(s))" % [str(effect["id"]).replace("_", " ").capitalize(), effect.get("duration", 1), effect.get("stacks", 1)])
			"DAMAGE": parts.append("Dano base %d + atributo" % int(effect.get("amount", 0)))
			"HEAL": parts.append("Cura %d" % int(effect.get("amount", 0)))
			"BLOCK": parts.append("Bloqueio %d" % int(effect.get("amount", 0)))
			"SHIELD": parts.append("Escudo %d" % int(effect.get("amount", 0)))
			"DRAW": parts.append("Compra %d" % int(effect.get("amount", 1)))
			"GENERATE": parts.append("Cria %s (temporária)" % _card_def(str(effect.get("id", ""))).get("name", "carta"))
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
	if battle != null and battle.phase == "PLAYER" and camera != null:
		var pointer := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(pointer)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pointer) * 80.0)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var new_card := int(hit["collider"].get_meta("card_index")) if hit.has("collider") and hit["collider"].has_meta("card_index") else -1
		var new_actor := int(hit["collider"].get_meta("actor_id")) if new_card < 0 and hit.has("collider") and hit["collider"].has_meta("actor_id") else -1
		if new_card != hovered_card:
			hovered_card = new_card
			if hovered_card >= 0 and hovered_card < battle.hand.size():
				_show_actor_portrait(int(battle.hand[hovered_card]["owner"]), false)
				if is_instance_valid(hover_hint):
					hover_hint.text = _card_description(_card_def(str(battle.hand[hovered_card]["id"])), battle.hand[hovered_card])
		if new_actor != hovered_actor:
			hovered_actor = new_actor
			if hovered_actor >= 0:
				_show_actor_portrait(hovered_actor, false)
				if card_confirmed and selected_card >= 0 and selected_card < battle.hand.size() and is_instance_valid(hover_hint):
					var estimate: Dictionary = battle.preview(selected_card, hovered_actor, chain_targets)
					if not estimate.is_empty():
						hover_hint.text = "Alvo %s · dano previsto na prévia" % battle.actor_by_id(hovered_actor).get("name", "")
	for id in actor_nodes.keys():
		var body: Node3D = actor_nodes[id]
		if not is_instance_valid(body): continue
		var avatar: Sprite3D = body.get_node_or_null("Avatar")
		if avatar == null: continue
		var hot := int(id) == hovered_actor
		avatar.modulate = Color("ffe1a8") if hot else Color.WHITE
	for mesh_index in range(card_meshes.size()):
		var card_mesh: MeshInstance3D = card_meshes[mesh_index]
		if not is_instance_valid(card_mesh): continue
		var raised := mesh_index == hovered_card or mesh_index == inspected_card
		var target_scale := Vector3(1.48, 1.48, 1.48) if raised else Vector3.ONE
		card_mesh.scale = card_mesh.scale.lerp(target_scale, 0.35)
	if presentation != null and battle != null and battle.phase == "PLAYER":
		var focus := Vector3.ZERO
		if hovered_actor >= 0 and actor_nodes.has(hovered_actor):
			var actor: Dictionary = battle.actor_by_id(hovered_actor)
			if str(actor.get("side", "")) == "ALLY":
				var body: Node3D = actor_nodes[hovered_actor]
				focus = Vector3(body.position.x * 0.34, 0.18, 0.0)
		presentation.ally_focus = presentation.ally_focus.lerp(focus, 1.0 - exp(-delta * 5.0))
	if portrait_sticky_until > 0 and Time.get_ticks_msec() >= portrait_sticky_until:
		portrait_sticky_until = 0
		_hide_idle_portraits()

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
		if saved_team.size() == int(Content.RULES["team_size"]) and seen_heroes.size() == saved_team.size() and saved_team.all(func(id): return Content.HEROES.has(id) and Content.HEROES[id].get("playable", true)):
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
