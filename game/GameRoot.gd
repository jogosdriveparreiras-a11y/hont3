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
var recover_pick_active := false
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
var redraw_hold_index := -1
var redraw_hold_time := 0.0
const REDRAW_HOLD_SECONDS := 2.0
var hero_hud: Control = null
var economy_hud: Control = null
var recompra_ring: Control = null

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
	cards_3d.reparent(camera, false)
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
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.95
	environment.glow_strength = 1.25
	environment.glow_bloom = 0.45
	environment.glow_hdr_threshold = 0.55
	environment.glow_hdr_scale = 1.4
	environment.set("glow_levels/1", 0.0)
	environment.set("glow_levels/2", 0.9)
	environment.set("glow_levels/3", 0.7)
	environment.set("glow_levels/4", 0.5)
	environment.set("glow_levels/5", 0.25)
	world.environment = environment
	add_child(world)
	_build_arena("default")
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

func _clear_arena() -> void:
	if stage == null:
		return
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()

func _build_arena(theme: String = "default") -> void:
	_clear_arena()
	if theme == "street_night":
		_build_street_night_arena()
	else:
		_build_default_arena()

func _build_default_arena() -> void:
	_add_box(Vector3(0, -0.30, 0), Vector3(19, 0.5, 12), Color("353c47"))
	for z in [-3.3, -1.7, 1.7, 3.3]:
		_add_box(Vector3(0, -0.02, z), Vector3(17, 0.04, 0.035), Color("bea674"))
	for x in [-9.1, 9.1]:
		for z in [-5.5, 5.5]:
			_add_box(Vector3(x, 1.75, z), Vector3(0.75, 3.5, 0.75), Color("555169"))
			_add_box(Vector3(x, 3.5, z), Vector3(1.1, 0.3, 1.1), Color("c8ac76"))

func _build_street_night_arena() -> void:
	# Asphalt street + sidewalks matching the procedural box style of the default arena
	_add_box(Vector3(0, -0.32, 0), Vector3(22, 0.45, 14), Color("1a1d28"))
	_add_box(Vector3(0, -0.06, 0), Vector3(7.2, 0.08, 13.5), Color("2a2e38"))  # road
	for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_add_box(Vector3(0, -0.01, z), Vector3(0.35, 0.02, 0.9), Color("c9b56a"))  # dashed center
	_add_box(Vector3(-5.1, -0.04, 0), Vector3(2.6, 0.08, 13.5), Color("3a3f4d"))  # sidewalk L
	_add_box(Vector3(5.1, -0.04, 0), Vector3(2.6, 0.08, 13.5), Color("3a3f4d"))  # sidewalk R
	# Building facades (left / right)
	for i in range(4):
		var z := -5.2 + i * 3.4
		var h := 3.2 + (i % 2) * 1.4
		_add_box(Vector3(-8.6, h * 0.5, z), Vector3(2.4, h, 3.0), Color("3d3552") if i % 2 == 0 else Color("2f3548"))
		_add_box(Vector3(8.6, h * 0.5 + 0.2, z), Vector3(2.4, h + 0.4, 3.0), Color("45355a") if i % 2 == 0 else Color("32384a"))
		# Lit windows
		for wy in [0.9, 1.9, 2.9]:
			if wy > h - 0.3:
				continue
			_add_box(Vector3(-7.35, wy, z - 0.7), Vector3(0.08, 0.45, 0.55), Color("ffd27a"))
			_add_box(Vector3(-7.35, wy, z + 0.7), Vector3(0.08, 0.45, 0.55), Color("ffb86b"))
			_add_box(Vector3(7.35, wy, z - 0.7), Vector3(0.08, 0.45, 0.55), Color("9ad7ff"))
			_add_box(Vector3(7.35, wy, z + 0.7), Vector3(0.08, 0.45, 0.55), Color("ff9ad0"))
	# Street lamps
	for x in [-4.0, 4.0]:
		for z in [-4.5, 0.0, 4.5]:
			_add_box(Vector3(x, 1.1, z), Vector3(0.12, 2.2, 0.12), Color("4a4e5c"))
			_add_box(Vector3(x, 2.25, z), Vector3(0.55, 0.12, 0.55), Color("c8ac76"))
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.15, z)
			lamp.light_color = Color("ffd2a0")
			lamp.light_energy = 1.6
			lamp.omni_range = 6.5
			stage.add_child(lamp)
	# Neon sign block across far end
	_add_box(Vector3(0, 3.4, -6.4), Vector3(6.5, 0.7, 0.35), Color("6b1f4a"))
	_add_box(Vector3(0, 3.4, -6.2), Vector3(5.8, 0.45, 0.12), Color("ff4f9a"))

func _arena_theme_for_mission(mid: String) -> String:
	var mission: Dictionary = Content.MISSIONS.get(mid, {})
	return str(mission.get("arena", "default"))

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
		var conflict: bool = _hero_conflicts_with_mission(id) and not chosen
		var prefix: String = "✓ " if chosen else ("⊘ " if conflict else "+ ")
		var hint: String = str(identity.get("history", "")) + "\n" + str(identity.get("trait", ""))
		if conflict:
			hint = "Indisponível: já aparece como inimigo em %s." % Content.MISSIONS[mission_id]["name"]
		var button := _button(prefix + "%s · %s · %d Vida" % [hero["name"], identity["role"], hero["hp"]], _toggle_hero.bind(id), hint)
		button.custom_minimum_size = Vector2(640, 44)
		button.disabled = conflict
		if conflict:
			button.modulate = Color(0.7, 0.55, 0.55, 0.85)
		list.add_child(button)
	if feedback != "":
		menu.add_child(_label(feedback, 16, Color("e9c891")))
		feedback = ""
	var conflicts: Array[String] = _team_mission_conflicts()
	if not conflicts.is_empty():
		var cnames: Array[String] = []
		for cid in conflicts:
			cnames.append(str(Content.HEROES.get(cid, {}).get("name", cid)))
		menu.add_child(_label("Conflito na equipe atual: %s" % ", ".join(PackedStringArray(cnames)), 16, Color("e15b5b")))
	menu.add_child(_button("Voltar", _show_menu))

func _toggle_hero(id: String) -> void:
	if team.has(id):
		if team.size() > 1: team.erase(id)
	elif team.size() < int(Content.RULES["team_size"]):
		if _hero_conflicts_with_mission(id):
			feedback = "%s já aparece como inimigo nesta missão (personagem único)." % Content.HEROES[id]["name"]
			_show_team()
			return
		team.append(id)
	_save_config()
	_show_team()

func _hero_is_repeatable(id: String) -> bool:
	if not Content.HEROES.has(id):
		return false
	var hero: Dictionary = Content.HEROES[id]
	return bool(hero.get("repeatable", false)) or bool(hero.get("minion", false))

func _mission_enemy_ids(mid: String = "") -> Array[String]:
	var key := mid if mid != "" else mission_id
	var result: Array[String] = []
	if not Content.MISSIONS.has(key):
		return result
	var mission: Dictionary = Content.MISSIONS[key]
	for enemy_id in mission.get("enemies", []):
		result.append(str(enemy_id))
	var waves: Dictionary = mission.get("reinforcements", {})
	for turn_key in waves.keys():
		for enemy_id in waves[turn_key]:
			result.append(str(enemy_id))
	return result

func _hero_conflicts_with_mission(id: String, mid: String = "") -> bool:
	if _hero_is_repeatable(id):
		return false
	return id in _mission_enemy_ids(mid)

func _team_mission_conflicts(mid: String = "") -> Array[String]:
	var conflicts: Array[String] = []
	for id in team:
		if _hero_conflicts_with_mission(str(id), mid):
			conflicts.append(str(id))
	return conflicts

func _show_team_conflict_popup(conflicts: Array[String]) -> void:
	var names: Array[String] = []
	for id in conflicts:
		names.append(str(Content.HEROES.get(id, {}).get("name", id)))
	var menu := _center_panel("EQUIPE EM CONFLITO")
	menu.add_child(_label("Estes heróis únicos já aparecem como inimigos na missão selecionada:", 18))
	menu.add_child(_label(", ".join(PackedStringArray(names)), 20, Color("e9c891")))
	menu.add_child(_label("Edite a equipe antes de iniciar.", 17))
	menu.add_child(_button("Editar equipe", _show_team))
	menu.add_child(_button("Voltar ao menu", _show_menu))

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
	for filter_name in ["TODAS", "IMPACTO", "PODER", "ESTADO", "ALCANCE", "MELHORADAS"]:
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
		var subtitle := "%s · %s" % [_card_scale_label(definition), "%d Iniciativa" % cost if cost > 0 else "+%d Iniciativa" % int(definition.get("gain", 0))]
		var button := _button(("▶ " if deck_selected == card_id else "") + definition["name"] + " +%d\n" % level + subtitle, _choose_deck_card.bind(card_id), _card_description(definition))
		button.custom_minimum_size = Vector2(330, 62)
		available.add_child(button)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 390
	columns.add_child(details)
	details.add_child(_label("DETALHES", 19, Color("d9bd85")))
	var shown: Dictionary = Content.CARDS[deck_selected]
	details.add_child(_label(shown["name"], 24, Color("f2dcad")))
	details.add_child(_label("%s · %s" % [_card_scale_label(shown), _card_type(shown)], 18))
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
		"IMPACTO": return _card_has_damage(card) and str(card.get("stat", "attack")) != "power"
		"PODER": return _card_has_damage(card) and str(card.get("stat", "")) == "power"
		"ESTADO": return not _card_has_damage(card)
		"ALCANCE": return card.get("reach", false)
		"MELHORADAS": return int(improvements.get(hero_id + ":" + card_id, {}).get("upgrade", 0)) > 0
		"FÍSICO", "MÁGICO", "SUPORTE": return _card_type(card) == deck_filter
		"RARAS": return false
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
	var conflicts: Array[String] = _team_mission_conflicts()
	if not conflicts.is_empty():
		_show_team_conflict_popup(conflicts)
		return
	pack_mode = "default"
	_begin_battle_session()
	_build_arena(_arena_theme_for_mission(mission_id))
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
		menu.add_child(_label("%s: %d/%d Vida" % [actor["name"], actor["hp"], actor["max_hp"]], 18))
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
	hero_hud = null
	economy_hud = null
	recompra_ring = null
	var viewport_size := get_viewport().get_visible_rect().size
	# Slim top chrome (MS-like: battlefield stays clear)
	var header := VBoxContainer.new()
	hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_child(_label("%s  ·  RODADA %d" % [battle.mission["name"], battle.turn], 22, Color("e9c891")))
	var phase_tint := Color.WHITE if battle.phase == "PLAYER" else Color(1, 1, 1, 0.45)
	var phase_line := _label("FASE DO JOGADOR" if battle.phase == "PLAYER" else "FASE INIMIGA", 16, Color("c9d1dd"))
	phase_line.modulate = phase_tint
	header.add_child(phase_line)
	_chrome(Vector2(12, 8), Vector2(viewport_size.x - 24, 72), "res://assets/ui/header.png")
	var extra := ""
	if battle.mission["objective"] == "PROTECT":
		extra += "SENTINELA %d Vida" % battle.protect_hp
	var next_turn: Array = battle.mission.get("reinforcements", {}).get(battle.turn + 1, [])
	if not next_turn.is_empty():
		extra += ("  ·  " if extra != "" else "") + "REFORÇOS EM 1 TURNO"
	if extra != "":
		header.add_child(_label(extra, 15, Color("e9c891")))
	# Compact right tools (cenário / itens / log) — no exploding left lists
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightPanel"
	right_scroll.position = Vector2(viewport_size.x - 280, 90)
	right_scroll.size = Vector2(260, maxf(100.0, viewport_size.y * 0.38))
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 240
	right_scroll.add_child(right)
	var objective := _label("OBJETIVO: %s" % Content.CAMPAIGN[mission_id]["goal"], 15, Color("e9c891"))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size.x = 230
	right.add_child(objective)
	right.add_child(_label("CENÁRIO", 18))
	for index in range(battle.mission.get("environment", []).size()):
		var object: Dictionary = battle.mission["environment"][index]
		var env_btn := _button("%s · %d Ini" % [object["name"], object["cost"]], func(): battle.use_environment(index))
		env_btn.custom_minimum_size = Vector2(230, 36)
		right.add_child(env_btn)
	right.add_child(_label("LOG", 18))
	for entry in event_history.slice(max(0, event_history.size() - 4)):
		var line := _label(entry, 13)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 230
		right.add_child(line)
	_chrome(Vector2(viewport_size.x - 280, 90), Vector2(260, maxf(100.0, viewport_size.y * 0.38)), "res://assets/ui/panel.png")
	# 3D hand arc (kept)
	for index in range(battle.hand.size()):
		var card: Dictionary = battle.hand[index]
		var definition: Dictionary = _card_def(str(card["id"]))
		_make_3d_card(index, card, definition)
	# Bottom-left hero focus HUD
	_build_hero_hud(viewport_size)
	# Bottom-right action economy + end turn
	_build_economy_hud(viewport_size)
	# Hold-to-recompra progress ring host
	recompra_ring = Control.new()
	recompra_ring.name = "RecompraRing"
	recompra_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recompra_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(recompra_ring)
	hover_hint = _label("Passe o mouse na carta (HUD atualiza). Clique para selecionar; clique de novo para confirmar. Se precisar de alvo, clique no sprite; auto (si/equipe/aleatório) resolve na hora. Segure ~2s para Recompra. Botão MOVER (ou tecla M) + clique no aliado troca Frente/Retaguarda.", 15, Color("c9d1dd"))
	hover_hint.position = Vector2(20, viewport_size.y - 210)
	hover_hint.custom_minimum_size.x = viewport_size.x * 0.42
	hover_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hover_hint)
	var status := _label("%s%s" % [feedback, "  ·  ALVOS %d/%d" % [chain_targets.size(), _card_def(str(battle.hand[selected_card]["id"])).get("chain", 1)] if selected_card >= 0 and selected_card < battle.hand.size() and not chain_targets.is_empty() else ""], 17, Color("f7d499"))
	status.position = Vector2(20, viewport_size.y - 186)
	status.custom_minimum_size.x = viewport_size.x * 0.42
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(status)
	if recover_pick_active and not battle.pending_recover.is_empty():
		_build_recover_pick_panel(viewport_size)
	_render_actors()
	if inspected_card >= 0 and inspected_card < battle.hand.size() and battle.phase == "PLAYER":
		_add_inspect_overlay(inspected_card, viewport_size)
	visible_uids.clear()
	for visible_card in battle.hand:
		visible_uids[visible_card["uid"]] = true

func _build_hero_hud(viewport_size: Vector2) -> void:
	hero_hud = Control.new()
	hero_hud.name = "HeroHud"
	hero_hud.position = Vector2(18, viewport_size.y - 168)
	hero_hud.size = Vector2(420, 140)
	hero_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hero_hud)
	_chrome(hero_hud.position, hero_hud.size, "res://assets/ui/panel.png")
	var actor_id := _focus_hero_id()
	if actor_id < 0:
		var empty := _label("Passe o mouse numa carta ou herói", 15, Color("aab2c0"))
		empty.position = Vector2(16, 50)
		hero_hud.add_child(empty)
		return
	var actor: Dictionary = battle.actor_by_id(actor_id)
	if actor.is_empty():
		return
	var portrait := TextureRect.new()
	portrait.texture = _unit_portrait(actor)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.position = Vector2(12, 14)
	portrait.size = Vector2(96, 112)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_hud.add_child(portrait)
	var name_lbl := _label(str(actor.get("name", "")).to_upper(), 22, Color("f4f1ea"))
	name_lbl.position = Vector2(122, 18)
	name_lbl.size = Vector2(280, 30)
	name_lbl.clip_text = true
	hero_hud.add_child(name_lbl)
	var type_lbl := _label(str(actor.get("type", "")), 14, _type_color(str(actor.get("type", ""))))
	type_lbl.position = Vector2(122, 48)
	hero_hud.add_child(type_lbl)
	var hp := int(actor.get("hp", 0))
	var max_hp := maxi(1, int(actor.get("max_hp", 1)))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.07, 0.1, 0.85)
	bar_bg.position = Vector2(122, 78)
	bar_bg.size = Vector2(220, 14)
	hero_hud.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = Color("3ecf7a")
	fill.position = bar_bg.position
	fill.size = Vector2(220.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), 14)
	hero_hud.add_child(fill)
	# Visible glow behind HP fill (additive feel via bright translucent layers)
	var glow_outer := ColorRect.new()
	glow_outer.color = Color(0.24, 0.95, 0.55, 0.35)
	glow_outer.position = Vector2(118, 72)
	glow_outer.size = Vector2(fill.size.x + 10, 26)
	hero_hud.add_child(glow_outer)
	hero_hud.move_child(glow_outer, fill.get_index())
	var glow := ColorRect.new()
	glow.color = Color(0.55, 1.0, 0.75, 0.55)
	glow.position = Vector2(120, 74)
	glow.size = Vector2(fill.size.x + 6, 22)
	hero_hud.add_child(glow)
	hero_hud.move_child(glow, fill.get_index())
	fill.color = Color(0.45, 1.0, 0.7, 1.0)
	var hp_lbl := _label("%d/%d" % [hp, max_hp], 16, Color("f4f1ea"))
	hp_lbl.position = Vector2(350, 72)
	hero_hud.add_child(hp_lbl)
	var defend := int(actor.get("block", 0)) + int(actor.get("shield", 0))
	var state_y := 100.0
	if defend > 0:
		var def_lbl := _label("DEF +%d" % defend, 14, Color("8fd6ff"))
		def_lbl.position = Vector2(122, state_y)
		hero_hud.add_child(def_lbl)
		state_y += 18.0
	# Active states on this hero (Iniciativa is team resource → right HUD)
	var statuses: Dictionary = actor.get("statuses", {})
	var state_bits: Array[String] = []
	for sid in statuses.keys():
		var st: Dictionary = statuses[sid]
		if int(st.get("duration", 0)) <= 0:
			continue
		var stacks := int(st.get("stacks", 1))
		var bit := _status_label(str(sid))
		if stacks > 1:
			bit += " x%d" % stacks
		bit += " (%d)" % int(st.get("duration", 0))
		state_bits.append(bit)
		if state_bits.size() >= 4:
			break
	if not state_bits.is_empty():
		var states_lbl := _label(" · ".join(PackedStringArray(state_bits)), 13, Color("d7c6ff"))
		states_lbl.position = Vector2(122, state_y)
		states_lbl.size = Vector2(280, 36)
		states_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		states_lbl.clip_text = true
		hero_hud.add_child(states_lbl)

func _refresh_hero_hud() -> void:
	if hero_hud == null or not is_instance_valid(hero_hud) or battle == null:
		return
	var keep_pos := hero_hud.position
	var keep_size := hero_hud.size
	for child in hero_hud.get_children():
		hero_hud.remove_child(child)
		child.queue_free()
	# Rebuild contents in place (panel chrome lives on hud, not as child)
	var actor_id := _focus_hero_id()
	if actor_id < 0:
		var empty := _label("Passe o mouse numa carta ou herói", 15, Color("aab2c0"))
		empty.position = Vector2(16, 50)
		hero_hud.add_child(empty)
		return
	var actor: Dictionary = battle.actor_by_id(actor_id)
	if actor.is_empty():
		return
	var portrait := TextureRect.new()
	portrait.texture = _unit_portrait(actor)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.position = Vector2(12, 14)
	portrait.size = Vector2(96, 112)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_hud.add_child(portrait)
	var name_lbl := _label(str(actor.get("name", "")).to_upper(), 22, Color("f4f1ea"))
	name_lbl.position = Vector2(122, 18)
	name_lbl.size = Vector2(280, 30)
	name_lbl.clip_text = true
	hero_hud.add_child(name_lbl)
	var type_lbl := _label(str(actor.get("type", "")), 14, _type_color(str(actor.get("type", ""))))
	type_lbl.position = Vector2(122, 48)
	hero_hud.add_child(type_lbl)
	var hp := int(actor.get("hp", 0))
	var max_hp := maxi(1, int(actor.get("max_hp", 1)))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.07, 0.1, 0.85)
	bar_bg.position = Vector2(122, 78)
	bar_bg.size = Vector2(220, 14)
	hero_hud.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = Color(0.45, 1.0, 0.7, 1.0)
	fill.position = bar_bg.position
	fill.size = Vector2(220.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), 14)
	hero_hud.add_child(fill)
	var glow_outer := ColorRect.new()
	glow_outer.color = Color(0.24, 0.95, 0.55, 0.35)
	glow_outer.position = Vector2(118, 72)
	glow_outer.size = Vector2(fill.size.x + 10, 26)
	hero_hud.add_child(glow_outer)
	hero_hud.move_child(glow_outer, fill.get_index())
	var glow := ColorRect.new()
	glow.color = Color(0.55, 1.0, 0.75, 0.55)
	glow.position = Vector2(120, 74)
	glow.size = Vector2(fill.size.x + 6, 22)
	hero_hud.add_child(glow)
	hero_hud.move_child(glow, fill.get_index())
	var hp_lbl := _label("%d/%d" % [hp, max_hp], 16, Color("f4f1ea"))
	hp_lbl.position = Vector2(350, 72)
	hero_hud.add_child(hp_lbl)
	var defend := int(actor.get("block", 0)) + int(actor.get("shield", 0))
	var state_y := 100.0
	if defend > 0:
		var def_lbl := _label("DEF +%d" % defend, 14, Color("8fd6ff"))
		def_lbl.position = Vector2(122, state_y)
		hero_hud.add_child(def_lbl)
		state_y += 18.0
	var statuses: Dictionary = actor.get("statuses", {})
	var state_bits: Array[String] = []
	for sid in statuses.keys():
		var st: Dictionary = statuses[sid]
		if int(st.get("duration", 0)) <= 0:
			continue
		var stacks := int(st.get("stacks", 1))
		var bit := _status_label(str(sid))
		if stacks > 1:
			bit += " x%d" % stacks
		bit += " (%d)" % int(st.get("duration", 0))
		state_bits.append(bit)
		if state_bits.size() >= 4:
			break
	if not state_bits.is_empty():
		var states_lbl := _label(" · ".join(PackedStringArray(state_bits)), 13, Color("d7c6ff"))
		states_lbl.position = Vector2(122, state_y)
		states_lbl.size = Vector2(280, 36)
		states_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		states_lbl.clip_text = true
		hero_hud.add_child(states_lbl)
	hero_hud.position = keep_pos
	hero_hud.size = keep_size

func _focus_hero_id() -> int:
	if inspected_card >= 0 and inspected_card < battle.hand.size():
		return int(battle.hand[inspected_card].get("owner", -1))
	if hovered_card >= 0 and hovered_card < battle.hand.size():
		return int(battle.hand[hovered_card].get("owner", -1))
	if selected_card >= 0 and selected_card < battle.hand.size():
		return int(battle.hand[selected_card].get("owner", -1))
	if hovered_actor >= 0:
		return hovered_actor
	var allies: Array = battle.living("ALLY")
	if not allies.is_empty():
		return int(allies[0]["id"])
	return -1

func _build_recover_pick_panel(viewport_size: Vector2) -> void:
	var panel := Control.new()
	panel.name = "RecoverPick"
	panel.position = Vector2(viewport_size.x * 0.22, 48)
	panel.size = Vector2(viewport_size.x * 0.56, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)
	_chrome(panel.position, panel.size, "res://assets/ui/panel.png")
	var title := _label("Recuperar do descarte (clique na carta)", 18, Color("f7d499"))
	title.position = Vector2(16, 10)
	panel.add_child(title)
	var indices: Array[int] = _recover_pick_indices()
	if indices.is_empty():
		var empty := _label("Nenhuma carta elegível no descarte.", 15, Color("c9d1dd"))
		empty.position = Vector2(16, 48)
		panel.add_child(empty)
		var auto_btn := _button("Auto (mais recente)", func():
			var left: int = int(battle.pending_recover.get("count", 1))
			var owner_filter: int = int(battle.pending_recover.get("owner_id", -1))
			battle.pending_recover = {}
			recover_pick_active = false
			battle.recover_from_discard(owner_filter, left, true)
			_after_card_resolved()
		)
		auto_btn.position = Vector2(16, 90)
		panel.add_child(auto_btn)
		return
	var x := 16.0
	for discard_index in indices:
		var card: Dictionary = battle.discard[discard_index]
		var definition: Dictionary = _card_def(str(card.get("id", "")))
		var label_txt := str(definition.get("name", card.get("id", "?")))
		var idx := int(discard_index)
		var btn := _button(label_txt, func(): _pick_recover_card(idx))
		btn.position = Vector2(x, 56)
		btn.custom_minimum_size = Vector2(140, 48)
		panel.add_child(btn)
		x += 150.0
		if x > panel.size.x - 150:
			break

func _build_economy_hud(viewport_size: Vector2) -> void:
	economy_hud = Control.new()
	economy_hud.name = "EconomyHud"
	economy_hud.position = Vector2(viewport_size.x - 310, viewport_size.y - 268)
	economy_hud.size = Vector2(290, 260)
	economy_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(economy_hud)
	_chrome(economy_hud.position, Vector2(290, 260), "res://assets/ui/panel.png")
	var plays: int = battle.card_plays
	var redraws_left: int = battle.redraws
	var moves_left: int = battle.moves
	var ini_now: int = battle.impulse
	var ini_max: int = int(battle.rules["impulse_max"])
	var lines: Array = [
		["INICIATIVA %d/%d" % [ini_now, ini_max], ini_now, ini_max, Color("e9c891")],
		["%d JOGADAS DE CARTA" % plays, plays, int(battle.rules["card_plays"]), Color("6eb6ff")],
		["%d RECOMPRAS" % redraws_left, redraws_left, int(battle.rules["redraws"]), Color("6eb6ff")],
		["%d MOVIMENTOS" % moves_left, moves_left, int(battle.rules["moves"]), Color("6eb6ff")],
	]
	var y := 8.0
	for entry in lines:
		var lbl := _label(str(entry[0]), 15, Color("f4f1ea"))
		lbl.position = Vector2(16, y)
		lbl.size = Vector2(250, 20)
		economy_hud.add_child(lbl)
		var track := ColorRect.new()
		track.color = Color(0.08, 0.1, 0.14, 0.9)
		track.position = Vector2(16, y + 20)
		track.size = Vector2(200, 6)
		economy_hud.add_child(track)
		var max_v := maxi(1, int(entry[2]))
		var fill := ColorRect.new()
		fill.color = entry[3]
		fill.position = track.position
		fill.size = Vector2(200.0 * clampf(float(entry[1]) / float(max_v), 0.0, 1.0), 6)
		economy_hud.add_child(fill)
		y += 32.0
	var move_btn := _button("MOVER (%d)" % moves_left, func(): _start_move_action())
	move_btn.disabled = battle.phase != "PLAYER" or enemy_presenting or (moves_left <= 0 and not _any_ally_has_momentum())
	move_btn.position = Vector2(16, 148)
	move_btn.custom_minimum_size = Vector2(258, 40)
	if selected_action == "move":
		move_btn.modulate = Color("6eb6ff")
	economy_hud.add_child(move_btn)
	var end_btn := _button("ENCERRAR TURNO", func(): _present_enemy_turn())
	end_btn.disabled = battle.phase != "PLAYER" or enemy_presenting or recover_pick_active
	end_btn.position = Vector2(16, 196)
	end_btn.custom_minimum_size = Vector2(258, 40)
	economy_hud.add_child(end_btn)
	
func _any_ally_has_momentum() -> bool:
	if battle == null:
		return false
	for ally in battle.living("ALLY"):
		if battle._has_status(ally, "momentum"):
			return true
	return false

func _start_move_action() -> void:
	if battle == null or battle.phase != "PLAYER" or enemy_presenting:
		return
	if battle.moves <= 0 and not _any_ally_has_momentum():
		feedback = "Sem movimentos restantes neste turno."
		_render_battle()
		return
	selected_action = "move"
	card_confirmed = false
	inspected_card = -1
	selected_card = -1
	chain_targets.clear()
	feedback = "MOVER: clique no aliado para trocar Frente/Retaguarda (tecla M também)."
	_render_battle()

func _add_actor_button(parent: VBoxContainer, actor: Dictionary) -> void:
	var text_value := "%s [%s] %d/%d Vida +%d" % [actor["name"], "F" if actor["row"] == "front" else "T", actor["hp"], actor["max_hp"], actor["block"] + actor["shield"]]
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
	# First click selects/inspects; second click on same card enters targeting (never deselects here)
	if selected_card == index and card_confirmed:
		feedback = "Alvo: clique no sprite do personagem."
		_render_battle()
		return
	if selected_card == index or inspected_card == index:
		inspected_card = index
		_confirm_inspected()
		return
	inspected_card = index
	selected_card = -1
	card_confirmed = false
	chain_targets.clear()
	feedback = "Carta selecionada. Clique de novo para confirmar a jogada."
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
		_after_card_resolved()
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
			nameplate.text = "%d/%d" % [actor["hp"], actor["max_hp"]]
			_update_world_hp_bar(actor_nodes[id], actor)
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
	var ring := MeshInstance3D.new()
	ring.name = "FloorRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.40
	torus.outer_radius = 0.62
	torus.rings = 24
	torus.ring_segments = 48
	ring.mesh = torus
	var type_tint: Color = _type_color(str(actor.get("type", "")))
	var bright := type_tint.lightened(0.35)
	var mat := _material(Color(bright.r, bright.g, bright.b, 1.0), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = bright
	mat.emission_energy_multiplier = 8.0
	mat.albedo_color = Color(bright.r, bright.g, bright.b, 1.0)
	ring.material_override = mat
	ring.position.y = 0.04
	ring.rotation_degrees.x = 0
	body.add_child(ring)
	# Soft outer glow disc (hollow feel via transparent center cylinder rim)
	var glow := MeshInstance3D.new()
	glow.name = "FloorGlow"
	var glow_disk := CylinderMesh.new()
	glow_disk.top_radius = 0.58
	glow_disk.bottom_radius = 0.58
	glow_disk.height = 0.01
	glow.mesh = glow_disk
	var glow_mat := _material(Color(type_tint.r, type_tint.g, type_tint.b, 0.35), true)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.emission_enabled = true
	glow_mat.emission = type_tint.lightened(0.25)
	glow_mat.emission_energy_multiplier = 4.5
	glow.material_override = glow_mat
	glow_disk.top_radius = 0.72
	glow_disk.bottom_radius = 0.72
	glow.position.y = 0.015
	body.add_child(glow)
	# Extra soft halo (Compatibility has no Environment bloom)
	var halo := MeshInstance3D.new()
	halo.name = "FloorHalo"
	var halo_disk := CylinderMesh.new()
	halo_disk.top_radius = 0.95
	halo_disk.bottom_radius = 0.95
	halo_disk.height = 0.008
	halo.mesh = halo_disk
	var halo_mat := _material(Color(type_tint.r, type_tint.g, type_tint.b, 0.22), true)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.emission_enabled = true
	halo_mat.emission = type_tint.lightened(0.4)
	halo_mat.emission_energy_multiplier = 3.0
	halo.material_override = halo_mat
	halo.position.y = 0.01
	body.add_child(halo)
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
	plate.font_size = 32
	plate.pixel_size = 0.006
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position.y = 2.62
	body.add_child(plate)
	var hp_root := Node3D.new()
	hp_root.name = "WorldHp"
	hp_root.position.y = 2.38
	body.add_child(hp_root)
	var hp_bg := MeshInstance3D.new()
	hp_bg.name = "HpBg"
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.9, 0.06, 0.02)
	hp_bg.mesh = bg_box
	var bg_mat := _material(Color(0.05, 0.06, 0.08, 0.85), true)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hp_bg.material_override = bg_mat
	hp_root.add_child(hp_bg)
	var hp_glow := MeshInstance3D.new()
	hp_glow.name = "HpGlow"
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(0.96, 0.10, 0.04)
	hp_glow.mesh = glow_box
	var gmat := _material(Color(0.35, 1.0, 0.6, 0.45), true)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.emission_enabled = true
	gmat.emission = Color(0.45, 1.0, 0.7)
	gmat.emission_energy_multiplier = 4.0
	hp_glow.material_override = gmat
	hp_root.add_child(hp_glow)
	var hp_fill := MeshInstance3D.new()
	hp_fill.name = "HpFill"
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.88, 0.045, 0.025)
	hp_fill.mesh = fill_box
	var fill_mat := _material(Color(0.55, 1.0, 0.75), true)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.55, 1.0, 0.75)
	fill_mat.emission_energy_multiplier = 5.5
	hp_fill.material_override = fill_mat
	hp_root.add_child(hp_fill)
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

func _update_world_hp_bar(body: Node3D, actor: Dictionary) -> void:
	var hp_root: Node3D = body.get_node_or_null("WorldHp")
	if hp_root == null:
		return
	var fill: MeshInstance3D = hp_root.get_node_or_null("HpFill")
	if fill == null or fill.mesh == null:
		return
	var hp := float(actor.get("hp", 0))
	var max_hp := maxf(1.0, float(actor.get("max_hp", 1)))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var box: BoxMesh = fill.mesh
	box.size = Vector3(0.88 * ratio, 0.045, 0.025)
	fill.position.x = -0.44 * (1.0 - ratio)
	var tint := Color(0.55, 1.0, 0.75) if ratio > 0.45 else (Color(1.0, 0.85, 0.35) if ratio > 0.2 else Color(1.0, 0.4, 0.4))
	var mat: StandardMaterial3D = fill.material_override
	if mat != null:
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = 5.5
	var hp_glow: MeshInstance3D = hp_root.get_node_or_null("HpGlow")
	if hp_glow != null and hp_glow.mesh != null:
		var gbox: BoxMesh = hp_glow.mesh
		gbox.size = Vector3(maxf(0.08, 0.96 * ratio), 0.10, 0.04)
		hp_glow.position.x = -0.48 * (1.0 - ratio)
		var gmat: StandardMaterial3D = hp_glow.material_override
		if gmat != null:
			gmat.albedo_color = Color(tint.r, tint.g, tint.b, 0.45)
			gmat.emission = tint

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
	plane.size = Vector2(0.525, 0.81)
	mesh.mesh = plane
	var shader: Shader = load("res://game/card_round.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo_tex", view.get_texture())
	material.set_shader_parameter("corner_radius", 0.055)
	material.set_shader_parameter("modulate_color", Color.WHITE)
	mesh.material_override = material
	var pose: Dictionary = _arc_pose(index, battle.hand.size())
	var slot: Vector3 = pose["position"]
	var spin: Vector3 = pose["rotation"]
	var uid := int(card.get("uid", -1))
	var entering := not seen_hand.has(uid)
	mesh.position = slot
	mesh.rotation = spin
	mesh.set_meta("base_pos", slot)
	mesh.set_meta("base_rot", spin)
	if entering:
		mesh.position = slot + Vector3(2.8, 0.45, 0.0)
		mesh.rotation = spin + Vector3(0, 0, 0.95)
	cards_3d.add_child(mesh)
	if int(owner.get("hp", 0)) <= 0:
		var dead_mat: ShaderMaterial = mesh.material_override
		if dead_mat != null:
			dead_mat.set_shader_parameter("modulate_color", Color(0.55, 0.55, 0.58, 0.75))
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
	box.size = Vector3(0.52, 0.78, 0.12)
	shape.shape = box
	area.add_child(shape)
	mesh.add_child(area)
	# Electric / soft glow outline via second slightly larger quad
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.name = "HoverGlow"
	var glow_plane := QuadMesh.new()
	glow_plane.size = Vector2(0.58, 0.88)
	glow_mesh.mesh = glow_plane
	var glow_mat := _material(Color(0.45, 0.78, 1.0, 0.0), true)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.45, 0.85, 1.0)
	glow_mat.emission_energy_multiplier = 0.0
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mesh.material_override = glow_mat
	glow_mesh.position.z = -0.01
	mesh.add_child(glow_mesh)
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
	# Cards closer horizontally (~3.2° step) on a shared arc; hover pushes z toward camera.
	var n := maxi(count, 1)
	var step := deg_to_rad(3.2)
	var total := step * float(maxi(n - 1, 0))
	total = maxf(total, deg_to_rad(12.0)) if n > 1 else 0.0
	var half := total * 0.5
	var t := 0.5 if n <= 1 else float(index) / float(n - 1)
	var ang := lerpf(-half, half, t)
	var target_half_width := 0.22 + 0.11 * float(mini(n, 8))
	var radius := 2.55
	var max_half := asin(clampf(target_half_width / radius, 0.05, 0.92))
	if half > max_half:
		radius = target_half_width / maxf(sin(half), 0.05)
	elif n > 1:
		half = max_half
		ang = lerpf(-half, half, t)
	var cy := -1.05 - radius
	var pos := Vector3(sin(ang) * radius, cy + cos(ang) * radius, -2.55)
	var rot := Vector3(-0.05, 0.0, -ang)
	return {"position": pos, "rotation": rot}

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
	# Pack ent_/ms_: hit amount is dano base da carta (aditivo com Impacto/Poder).
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		if str(action[0]) in ["hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "roulette_hit"]:
			flat = int(round(float(action[1]))) if action.size() > 1 else flat
			break
	var archetype := str(owner.get("archetype", ""))
	var base_attr := int(owner.get(stat_name, 0))
	if Content.HEROES.has(archetype):
		base_attr = int(Content.HEROES[archetype].get(stat_name, base_attr))
	var current_attr := int(owner.get(stat_name, base_attr))
	var baseline := flat + base_attr
	var current := flat + current_attr
	if battle != null and battle._has_status(owner, "weak"):
		current = int(round(float(current) * 0.5))
	if battle != null and battle._has_status(owner, "strengthened"):
		current = int(round(float(current) * 1.5))
	if battle != null and (battle._has_status(owner, "binary") or battle._has_status(owner, "overpowered")):
		current = current * 2
	# Armadura do alvo não entra na prévia da carta (é do combatente).
	current = maxi(0, current)
	var tint := Color("f4f7fb")
	if current > baseline:
		tint = Color("7dE28a")
	elif current < baseline:
		tint = Color("e15b5b")
	var label := "PODER" if stat_name == "power" else "IMPACTO"
	return {"label": label, "value": current, "color": tint}

func _card_scale_label(definition: Dictionary) -> String:
	if not _card_has_damage(definition):
		return "Suporte"
	if str(definition.get("stat", "")) == "power":
		return "Poder"
	return "Impacto"

func _card_has_damage(definition: Dictionary) -> bool:
	for effect in definition.get("effects", []):
		if str(effect.get("kind", "")) == "DAMAGE":
			return true
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		if str(action[0]) in ["hit", "hit_per_impulse", "hit_per_hand", "hit_from_block", "roulette_hit"]:
			return true
	return false

func _status_label(status_id: String) -> String:
	return str(status_id).replace("_", " ")

func _rules_bbcode(definition: Dictionary, card: Dictionary) -> String:
	var lines: Array[String] = []
	var target_names := {"SELF": "si mesmo", "ALLY": "aliado", "ALL_ALLIES": "todos os aliados", "ENEMY": "inimigo", "SINGLE": "inimigo", "ENEMY_ROW": "linha inimiga", "ROW": "linha inimiga", "FRONT_ROW": "frente inimiga", "BACK_ROW": "retaguarda inimiga", "ALL_ENEMIES": "todos os inimigos", "ADJACENT": "alvo e adjacentes", "RANDOM": "inimigo aleatório", "CHAIN": "sequência", "ANY_UNIT": "qualquer unidade"}
	lines.append("[b]Alvo:[/b] %s" % target_names.get(str(definition.get("target", "ENEMY")), "inimigo"))
	var keywords: Array[String] = []
	if definition.get("quick", false): keywords.append("[b]Rápida[/b]")
	if definition.get("free", false): keywords.append("[b]Livre[/b]")
	if definition.get("final", false): keywords.append("[b]Final[/b]")
	if definition.get("reach", false): keywords.append("[b]Alcance[/b]")
	if definition.get("penetrating", false): keywords.append("[b]Penetrante[/b]")
	if definition.get("lethargic", false): keywords.append("[b]Letárgico[/b]")
	if definition.get("recoil", false): keywords.append("[b]Recuo[/b]")
	if definition.get("drain", false): keywords.append("[b]Dreno[/b]")
	if definition.get("instant", false): keywords.append("[b]Instantâneo[/b]")
	if definition.get("ephemeral", false): keywords.append("[b]Efêmero[/b]")
	if int(definition.get("warmup", 0)) > 0: keywords.append("[b]Aquecimento[/b] %d" % int(definition["warmup"]))
	if int(definition.get("chain", 0)) > 0: keywords.append("[b]Chain[/b] %d" % int(definition["chain"]))
	if definition.get("exhaust", false) or definition.get("item", false):
		keywords.append("[color=#e15b5b][b]Exaustão[/b][/color]")
	if not keywords.is_empty():
		lines.append(" · ".join(PackedStringArray(keywords)))
	var harmful := ["weak", "vulnerable", "bleed", "poison", "burn", "stun", "bind", "bound", "wound", "wounded", "blind", "silence", "dazed", "confused", "corrupted", "drop"]
	var effect_lines: Array[String] = []
	for effect in definition.get("effects", []):
		var kind := str(effect.get("kind", ""))
		if kind == "DAMAGE":
			continue  # damage lives on the shield readout
		elif kind == "HEAL":
			effect_lines.append("Cura %d" % int(effect.get("amount", 0)))
		elif kind == "BLOCK":
			effect_lines.append("[b]Bloqueio[/b] %d" % int(effect.get("amount", 0)))
		elif kind == "SHIELD":
			effect_lines.append("[b]Escudo[/b] %d" % int(effect.get("amount", 0)))
		elif kind == "DRAW":
			effect_lines.append("Compra %d" % int(effect.get("amount", 1)))
		elif kind == "CURE" or kind == "CLEANSE":
			effect_lines.append("Remove estados negativos")
		elif kind == "PUSH":
			effect_lines.append("Empurra")
		elif kind == "PULL":
			effect_lines.append("Puxa")
		elif kind == "MOVE":
			effect_lines.append("Troca de linha")
		elif kind == "GENERATE":
			effect_lines.append("Cria carta temporária")
		elif kind == "STATUS":
			var status_id := str(effect.get("id", ""))
			var turns := int(effect.get("duration", 1))
			var piece := "Adiciona o State [b]%s[/b] por %d turno(s)" % [_status_label(status_id), turns]
			if status_id in harmful:
				piece = "[color=#e15b5b]%s[/color]" % piece
			effect_lines.append(piece)
		elif kind == "DISCARD":
			effect_lines.append("[color=#e15b5b]Descarte[/color]")
		elif kind != "":
			effect_lines.append("%s" % kind.capitalize())
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		if op in ["hit", "hit_per_impulse", "hit_per_hand", "roulette_hit", "hit_from_block"]:
			continue
		elif op in ["self_damage", "self_damage_hp"]:
			effect_lines.append("[color=#e15b5b]Dano a si[/color]")
		elif op in ["discard_hand", "discard_random"]:
			effect_lines.append("[color=#e15b5b]Descarta cartas[/color]")
		elif op == "exhaust":
			effect_lines.append("[color=#e15b5b][b]Exaustão[/b][/color]")
		elif op in ["heal", "heal_all", "full_heal"]:
			effect_lines.append("Cura")
		elif op in ["block", "block_hp"]:
			effect_lines.append("[b]Bloqueio[/b]")
		elif op in ["status", "self_status", "chance_status", "roulette_status"]:
			var status_id := str(action[1]) if action.size() > 1 else ""
			var turns := int(action[2]) if action.size() > 2 else 1
			var piece := "Adiciona o State [b]%s[/b] por %d turno(s)" % [_status_label(status_id), turns]
			if status_id in harmful:
				piece = "[color=#e15b5b]%s[/color]" % piece
			effect_lines.append(piece)
		elif op == "quick":
			effect_lines.append("[b]Rápida[/b]")
		elif op == "push":
			effect_lines.append("Empurra")
		elif op == "pull":
			effect_lines.append("Puxa")
	if card.get("infected", false):
		effect_lines.append("[color=#e15b5b]Infectada[/color]")
	if not effect_lines.is_empty():
		lines.append("")
		for piece in effect_lines:
			lines.append("• %s" % piece)
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
	var show_damage := (not item) and _card_has_damage(definition)
	var dead := int(owner.get("hp", 0)) <= 0
	return {
		"title": str(definition.get("name", "")),
		"chip": "Item" if item else str(owner.get("name", "")),
		"item": item,
		"art": art,
		"icon": icon,
		"border": border,
		"show_damage": show_damage,
		"stat_label": str(readout["label"]),
		"stat_value": int(readout["value"]),
		"stat_color": readout["color"],
		"rules": _rules_bbcode(definition, card),
		"gain": int(definition.get("gain", 0)),
		"cost": int(definition.get("cost", 0)),
		"dead": dead,
		"shield_icon": _load_tex("res://assets/ui/impact_shield_sword.png")
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
		host.scale = Vector2(1.38, 1.38)
		host.z_index = 20
	if index >= 0 and index < battle.hand.size():
		_show_actor_portrait(int(battle.hand[index]["owner"]), false)
		if is_instance_valid(hover_hint):
			hover_hint.text = _card_description(_card_def(str(battle.hand[index]["id"])), battle.hand[index])

func _on_card_gui(event: InputEvent, index: int) -> void:
	if battle == null or battle.phase != "PLAYER" or not event is InputEventMouseButton: return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT: return
	if click.pressed:
		redraw_hold_index = index
		redraw_hold_time = 0.0
		hovered_card = index
		get_viewport().set_input_as_handled()
		return
	# Release: short tap = inspect/confirm; long hold already fired recompra
	var held := redraw_hold_time
	var was_index := redraw_hold_index
	redraw_hold_index = -1
	redraw_hold_time = 0.0
	_clear_recompra_meter()
	if was_index != index:
		return
	if held >= REDRAW_HOLD_SECONDS:
		get_viewport().set_input_as_handled()
		return
	if selected_action == "redraw":
		selected_action = ""
		_try_recompra(index)
		get_viewport().set_input_as_handled()
		return
	if selected_card == index and card_confirmed:
		# Already in targeting — keep targeting; do not deselect
		feedback = "Alvo: clique no sprite do personagem."
		call_deferred("_render_battle")
	elif inspected_card == index or (selected_card == index and not card_confirmed):
		suppress_inspect_cancel = true
		call_deferred("_confirm_inspected")
	else:
		# First click: select / inspect
		inspected_card = index
		selected_card = -1
		card_confirmed = false
		chain_targets.clear()
		feedback = "Carta selecionada. Clique de novo para confirmar a jogada."
		_show_actor_portrait(int(battle.hand[index]["owner"]), false)
		call_deferred("_render_battle")
	get_viewport().set_input_as_handled()

func _try_recompra(index: int) -> bool:
	if battle == null or battle.phase != "PLAYER":
		return false
	if index < 0 or index >= battle.hand.size():
		return false
	if battle.redraws <= 0:
		feedback = "Sem recompras"
		_render_battle()
		return false
	_animate_card_depart(index)
	var ok: bool = packs.redraw_card(battle, pack_mode, index)
	if ok:
		feedback = "Recompra realizada."
		if sound != null:
			sound.cue("redraw", "UI")
	inspected_card = -1
	selected_card = -1
	card_confirmed = false
	return ok

func _clear_recompra_meter() -> void:
	if recompra_ring == null or not is_instance_valid(recompra_ring):
		return
	for child in recompra_ring.get_children():
		child.queue_free()

func _update_recompra_meter(progress: float, label_text: String) -> void:
	if recompra_ring == null or not is_instance_valid(recompra_ring):
		return
	_clear_recompra_meter()
	var vp := get_viewport().get_visible_rect().size
	var wrap := Control.new()
	wrap.position = Vector2(vp.x * 0.5 - 70, vp.y * 0.52)
	wrap.size = Vector2(140, 160)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recompra_ring.add_child(wrap)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.position = Vector2(10, 10)
	dim.size = Vector2(120, 120)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dim)
	var meter := HotNCircularMeter.new()
	meter.position = Vector2(20, 20)
	meter.size = Vector2(100, 100)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.set_progress(progress)
	wrap.add_child(meter)
	var lbl := _label(label_text, 16, Color("9dffb0") if progress < 1.0 else Color("3ecf7a"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(10, 130)
	lbl.size = Vector2(120, 24)
	wrap.add_child(lbl)

func _target_needs_player_choice(kind: String) -> bool:
	# Auto after confirm: no unit pick required (self / whole side / fixed row / random).
	match kind:
		"SELF", "ALL_ALLIES", "ALL_ENEMIES", "RANDOM", "FRONT_ROW", "BACK_ROW":
			return false
		_:
			return true

func _auto_primary_target_id(definition: Dictionary, owner_id: int) -> int:
	var kind := str(definition.get("target", "ENEMY"))
	match kind:
		"SELF":
			return owner_id
		"ALL_ALLIES":
			var allies: Array = battle.living("ALLY")
			return int(allies[0]["id"]) if not allies.is_empty() else -1
		"ALL_ENEMIES", "RANDOM":
			var enemies: Array = battle.living("ENEMY")
			return int(enemies[0]["id"]) if not enemies.is_empty() else -1
		"FRONT_ROW", "BACK_ROW":
			var row := "front" if kind == "FRONT_ROW" else "back"
			for actor in battle.living("ENEMY"):
				if str(actor.get("row", "")) == row:
					return int(actor["id"])
			var fallback: Array = battle.living("ENEMY")
			return int(fallback[0]["id"]) if not fallback.is_empty() else -1
		_:
			return -1

func _ray_card_index_at(screen_pos: Vector2) -> int:
	if camera == null:
		return -1
	var origin := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_pos) * 80.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("collider") and hit["collider"].has_meta("card_index"):
		return int(hit["collider"].get_meta("card_index"))
	return -1

func _on_inspect_blocker_gui(event: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER":
		return
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or click.pressed:
		return
	# Release on dimmed area: 2nd click on the same 3D card confirms; empty space cancels.
	var card_idx := _ray_card_index_at(click.position)
	if card_idx >= 0 and card_idx == inspected_card:
		suppress_inspect_cancel = true
		_confirm_inspected()
	else:
		_cancel_inspect()
	get_viewport().set_input_as_handled()

func _confirm_inspected() -> void:
	suppress_inspect_cancel = false
	var index := inspected_card
	if battle == null or index < 0 or index >= battle.hand.size():
		return
	var owner: Dictionary = battle.actor_by_id(int(battle.hand[index].get("owner", 0)))
	if int(owner.get("hp", 0)) <= 0:
		feedback = "Herói fora de combate — carta indisponível."
		_render_battle()
		return
	var definition: Dictionary = _card_def(str(battle.hand[index]["id"]))
	var kind := str(definition.get("target", "ENEMY"))
	inspected_card = -1
	selected_card = index
	card_confirmed = true
	selected_action = ""
	_show_actor_portrait(int(battle.hand[index]["owner"]), true)
	if not _target_needs_player_choice(kind):
		var auto_id := _auto_primary_target_id(definition, int(battle.hand[index]["owner"]))
		if auto_id >= 0:
			_choose_target(auto_id)
		else:
			feedback = "Sem alvo automático disponível."
			card_confirmed = false
			_render_battle()
		return
	feedback = "Alvo: clique no sprite do personagem."
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
	var blocker := Control.new()
	blocker.focus_mode = Control.FOCUS_NONE
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.z_index = 8
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.gui_input.connect(_on_inspect_blocker_gui)
	hud.add_child(blocker)
	var height := viewport_size.y * 0.6
	var width := height * 0.66
	var card: Dictionary = battle.hand[index]
	var definition: Dictionary = _card_def(str(card["id"]))
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var host = CardFace.new()
	host.size = Vector2(width, height)
	host.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	host.z_index = 9
	# setup() forces IGNORE for SubViewport faces — restore STOP so 2nd click confirms.
	host.setup(_card_spec(card, definition, owner))
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	hud.add_child(host)

func _after_card_resolved() -> void:
	if battle == null:
		return
	if not battle.pending_recover.is_empty():
		recover_pick_active = true
		feedback = "Recuperar: escolha uma carta do descarte."
		_render_battle()
		return
	if bool(battle.request_end_turn):
		battle.request_end_turn = false
		_render_battle()
		call_deferred("_present_enemy_turn")
		return
	_render_battle()

func _recover_pick_indices() -> Array[int]:
	var result: Array[int] = []
	if battle == null or battle.pending_recover.is_empty():
		return result
	var owner_filter: int = int(battle.pending_recover.get("owner_id", -1))
	for index in range(battle.discard.size()):
		var card: Dictionary = battle.discard[index]
		if owner_filter < 0 or int(card.get("owner", -1)) == owner_filter:
			result.append(index)
	return result

func _pick_recover_card(discard_index: int) -> void:
	if battle == null or not battle.finish_recover_pick(discard_index):
		feedback = "Carta inválida no descarte."
		_render_battle()
		return
	if battle.pending_recover.is_empty():
		recover_pick_active = false
		feedback = "Carta recuperada."
		if bool(battle.request_end_turn):
			battle.request_end_turn = false
			_render_battle()
			call_deferred("_present_enemy_turn")
			return
	else:
		feedback = "Recuperar: escolha mais uma carta do descarte."
	_render_battle()

func _present_enemy_turn() -> void:
	if enemy_presenting or battle == null or battle.phase != "PLAYER": return
	# Auto-resolve pending recover before ending turn.
	if not battle.pending_recover.is_empty():
		var left: int = int(battle.pending_recover.get("count", 1))
		var owner_filter: int = int(battle.pending_recover.get("owner_id", -1))
		battle.pending_recover = {}
		recover_pick_active = false
		battle.recover_from_discard(owner_filter, left, true)
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
		_clear_enemy_card_overlay()
		_set_orbit(0.0)
		return
	enemy_steps += 1
	if enemy_steps > 16:
		battle.finish_enemy_phase()
		packs.on_player_turn_resumed(battle, pack_mode)
		enemy_presenting = false
		_clear_enemy_card_overlay()
		_set_orbit(0.0)
		return
	var pace := 2.0 / maxf(animation_speed, 0.25)
	var choice: Dictionary = battle.peek_enemy_play()
	if choice.is_empty():
		battle.finish_enemy_phase()
		packs.on_player_turn_resumed(battle, pack_mode)
		enemy_presenting = false
		_clear_enemy_card_overlay()
		_set_orbit(0.0)
		return
	if str(choice.get("kind", "")) == "play":
		var card: Dictionary = choice.get("card", {})
		var definition: Dictionary = _card_def(str(card.get("id", "")))
		var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
		feedback = "Adversário joga: %s" % str(definition.get("name", ""))
		_show_actor_portrait(int(card.get("owner", 0)), true)
		_show_enemy_card_overlay(card, definition, owner)
		await get_tree().create_timer(pace).timeout
		if battle == null or battle.phase != "ENEMY":
			enemy_presenting = false
			_clear_enemy_card_overlay()
			return
		var target_id := int(choice.get("target", -1))
		if target_id >= 0:
			_show_actor_portrait(target_id, true)
			if actor_nodes.has(target_id):
				var body: Node3D = actor_nodes[target_id]
				if is_instance_valid(body):
					body.scale = Vector3(1.18, 1.18, 1.18)
		_clear_enemy_card_overlay()
		battle.play(int(choice["index"]), target_id, choice.get("chain", []))
		await get_tree().create_timer(pace).timeout
		if actor_nodes.has(target_id):
			var reset_body: Node3D = actor_nodes[target_id]
			if is_instance_valid(reset_body):
				reset_body.scale = Vector3.ONE
	elif str(choice.get("kind", "")) == "redraw":
		feedback = "Adversário recompra."
		_render_battle()
		await get_tree().create_timer(pace * 0.5).timeout
		battle.enemy_step()
		_render_battle()
		await get_tree().create_timer(pace * 0.5).timeout
	else:
		battle.enemy_step()
	if battle == null or battle.phase != "ENEMY":
		enemy_presenting = false
		_clear_enemy_card_overlay()
		return
	_step_enemy()

func _show_enemy_card_overlay(card: Dictionary, definition: Dictionary, owner: Dictionary) -> void:
	_clear_enemy_card_overlay()
	if fx_overlay == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var host = CardFace.new()
	host.name = "EnemyCardOverlay"
	var height := viewport_size.y * 0.6
	var width := height * 0.66
	host.size = Vector2(width, height)
	host.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	host.z_index = 12
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.setup(_card_spec(card, definition, owner))
	fx_overlay.add_child(host)

func _clear_enemy_card_overlay() -> void:
	if fx_overlay == null:
		return
	var existing := fx_overlay.get_node_or_null("EnemyCardOverlay")
	if existing != null:
		existing.queue_free()

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
		var idx := inspected_card if inspected_card >= 0 else hovered_card
		if idx >= 0:
			_try_recompra(idx)
		else:
			feedback = "Segure ~2s numa carta (ou selecione e pressione de novo) para Recompra."
			_render_battle()
	elif event.is_action_pressed("hotn_move"):
		_start_move_action()
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
	if click.button_index != MOUSE_BUTTON_LEFT:
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
	if click.pressed and hit.has("collider") and hit["collider"].has_meta("actor_id"):
		_activate_actor(int(hit["collider"].get_meta("actor_id")))
		get_viewport().set_input_as_handled()
	elif not click.pressed and redraw_hold_index >= 0:
		# Released off-card: cancel hold without playing click
		redraw_hold_index = -1
		redraw_hold_time = 0.0
		_clear_recompra_meter()

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
	if definition.get("penetrating", false): parts.append("PENETRANTE")
	if definition.get("lethargic", false): parts.append("LETÁRGICO")
	if definition.get("recoil", false): parts.append("RECUO")
	if definition.get("drain", false): parts.append("DRENO")
	if definition.get("instant", false): parts.append("INSTANTÂNEO")
	if definition.get("ephemeral", false): parts.append("EFÊMERO")
	if int(definition.get("warmup", 0)) > 0: parts.append("AQUECIMENTO %d" % int(definition["warmup"]))
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

func _tick_recompra_hold(delta: float) -> void:
	var focus := inspected_card if inspected_card >= 0 else hovered_card
	if redraw_hold_index < 0:
		# Allow hold on already-selected/inspected without new press if LMB down on same focus
		if focus >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not card_confirmed:
			# only continue if press started on a card (avoid steal from UI buttons)
			pass
		_clear_recompra_meter()
		return
	if battle.redraws <= 0:
		_update_recompra_meter(0.0, "Sem recompras")
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	redraw_hold_time += delta
	var progress := clampf(redraw_hold_time / REDRAW_HOLD_SECONDS, 0.0, 1.0)
	_update_recompra_meter(progress, "Recompra")
	# Soft green glow on the held card
	if redraw_hold_index >= 0 and redraw_hold_index < card_meshes.size():
		var held_mesh: MeshInstance3D = card_meshes[redraw_hold_index]
		if is_instance_valid(held_mesh):
			var glow_node: MeshInstance3D = held_mesh.get_node_or_null("HoverGlow")
			if glow_node != null and glow_node.material_override != null:
				var gmat: StandardMaterial3D = glow_node.material_override
				gmat.albedo_color = Color(0.35, 0.95, 0.55, 0.35 + 0.45 * progress)
				gmat.emission = Color(0.35, 0.95, 0.55)
				gmat.emission_energy_multiplier = 2.0 + 3.0 * progress
	if redraw_hold_time >= REDRAW_HOLD_SECONDS:
		var idx := redraw_hold_index
		redraw_hold_index = -1
		redraw_hold_time = 0.0
		_clear_recompra_meter()
		_try_recompra(idx)

func _process(delta: float) -> void:
	for i in range(unit_sprites.size()):
		if not is_instance_valid(unit_sprites[i]):
			continue
		unit_sprites[i].position.y = 1.1
		if reduce_motion:
			unit_sprites[i].scale = Vector3.ONE
		else:
			# Classic idle breath: vertical stretch + slight horizontal squash
			var wave := sin(Time.get_ticks_msec() * 0.0024 + float(i) * 1.7)
			var sy := 1.0 + wave * 0.028
			var sx := 1.0 - wave * 0.016
			unit_sprites[i].scale = Vector3(sx, sy, 1.0)
	if battle != null and battle.phase == "PLAYER":
		_tick_recompra_hold(delta)
	if battle != null and battle.phase == "PLAYER" and camera != null:
		var pointer := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(pointer)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pointer) * 80.0)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var new_card := int(hit["collider"].get_meta("card_index")) if hit.has("collider") and hit["collider"].has_meta("card_index") else -1
		var new_actor := int(hit["collider"].get_meta("actor_id")) if new_card < 0 and hit.has("collider") and hit["collider"].has_meta("actor_id") else -1
		var hover_dirty := false
		if new_card != hovered_card:
			hovered_card = new_card
			hover_dirty = true
			if hovered_card >= 0 and hovered_card < battle.hand.size():
				_show_actor_portrait(int(battle.hand[hovered_card]["owner"]), false)
				if is_instance_valid(hover_hint):
					hover_hint.text = _card_description(_card_def(str(battle.hand[hovered_card]["id"])), battle.hand[hovered_card])
		if new_actor != hovered_actor:
			hovered_actor = new_actor
			hover_dirty = true
			if hovered_actor >= 0:
				_show_actor_portrait(hovered_actor, false)
				if card_confirmed and selected_card >= 0 and selected_card < battle.hand.size() and is_instance_valid(hover_hint):
					var estimate: Dictionary = battle.preview(selected_card, hovered_actor, chain_targets)
					if not estimate.is_empty():
						hover_hint.text = "Alvo %s · dano previsto na prévia" % battle.actor_by_id(hovered_actor).get("name", "")
		if hover_dirty:
			_refresh_hero_hud()
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
		var target_scale := Vector3(1.42, 1.42, 1.42) if raised else Vector3.ONE
		card_mesh.scale = card_mesh.scale.lerp(target_scale, 0.35)
		var base_pos: Vector3 = card_mesh.get_meta("base_pos", card_mesh.position)
		var lift := Vector3(0, 0.12, 0.42) if raised else Vector3.ZERO
		var want_pos := base_pos + lift
		# Preserve deal-in animation until near the slot
		if card_mesh.position.distance_to(base_pos) < 1.25 or raised:
			card_mesh.position = card_mesh.position.lerp(want_pos, 0.35)
		card_mesh.sorting_offset = 24.0 if raised else float(mesh_index) * 0.01
		var glow_node: MeshInstance3D = card_mesh.get_node_or_null("HoverGlow")
		if glow_node != null and glow_node.material_override != null:
			var gmat: StandardMaterial3D = glow_node.material_override
			var glow_on := mesh_index == hovered_card or mesh_index == inspected_card or mesh_index == selected_card
			var target_a := 0.55 if glow_on else 0.0
			var target_e := 3.2 if glow_on else 0.0
			gmat.albedo_color.a = lerpf(gmat.albedo_color.a, target_a, 0.35)
			gmat.emission_energy_multiplier = lerpf(gmat.emission_energy_multiplier, target_e, 0.35)
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
