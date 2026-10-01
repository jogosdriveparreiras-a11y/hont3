extends Node3D

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")
const SoundBus = preload("res://game/SoundBus.gd")
const Presentation = preload("res://game/CombatPresentation.gd")
const FxPlayer = preload("res://game/FxPlayer.gd")
const PackBridge = preload("res://game/PackBridge.gd")
const CardFace = preload("res://game/CardFace.gd")
const CollectionRules = preload("res://game/CollectionRules.gd")
const CampaignRules = preload("res://game/CampaignRules.gd")
const ArenaBuilder = preload("res://game/ArenaBuilder.gd")
const SessionReport = preload("res://game/SessionReport.gd")

var battle
var packs = PackBridge.new()
var session_report = SessionReport.new()
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
var collection_hero := ""
var collection_filter := "TODAS"
var collection_selected := ""
var card_hit_areas: Array[Button] = []
var card_meshes: Array[MeshInstance3D] = []
var unit_sprites: Array[Sprite3D] = []
var corpse_textures: Dictionary = {}
var actor_nodes: Dictionary = {}
var sound
var presentation
var fx_overlay: Control
var hover_hint: Label
var hovered_card := -1
var seen_hand: Dictionary = {}
var inspected_card := -1
var damage_preview_by_actor: Dictionary = {}  # actor_id -> damage forecast
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
## Vista de combate: "normal" (padrão) | "lateral" (aliados à esquerda).
var battle_view_mode := "normal"
## Conteúdo sensível: ON=cast/ original; OFF=cast_sensitive/ (generics se não houver ent_*).
var sensitive_content := false
const MENU_BGM_DEFAULT := "title"
const BATTLE_BGM_DEFAULT := "Battle1"
var bgm_track := MENU_BGM_DEFAULT
## Última faixa real do seletor (Tocar/ciclos); sobrevive a Parar BGM.
var bgm_pick := MENU_BGM_DEFAULT
var fx_player = null
var _sprite_mouse_lock_id := -1
var _sprite_mouse_lock_until := 0
## Cartas possuídas por herói (deck = todas; Melhoradas substituem a base).
var owned_cards: Dictionary = {}
## Overlay Inspecionar só abre pelo botão (não no clique da carta).
var inspect_open := false
var redraw_hold_index := -1
var redraw_hold_time := 0.0
const REDRAW_HOLD_SECONDS := 1.0
var hero_hud: Control = null
var economy_hud: Control = null
var recompra_ring: Control = null
var pending_target_id := -1
var status_hover_actor := -1
var arena_allies: Array[String] = []
var arena_enemies: Array[String] = []
var battle_menu_open := false
var weather_mode := "none"  # none | rain | fog | heat | night | leaves | snow
var free_camera := false
var free_cam_yaw := 0.0
var free_cam_pitch := 0.0
var free_cam_dragging := false
var free_cam_last := Vector2.ZERO
var hover_retarget_freeze_until := 0
## Foco/zoom cinematográfico (ex.: Nero→Naomi); segura contra o lerp de hover.
var cinematic_until_msec := 0
var cinematic_actor_id := -1
var cinematic_zoom := 1.85
var weather_fx_root: Node3D = null
var anim_test_caster := "ent_alyssa_wine"
var anim_test_target := "ent_akuji"
var anim_test_card := ""
var anim_test_filter_owner := ""
var anim_test_filter_class := ""
var anim_test_filter_name := ""
var anim_test_playing := false
var title_root: Node3D = null
var title_video_player: VideoStreamPlayer = null
var title_video_plane: MeshInstance3D = null
var title_menu_section := ""  # "" | "jogar" | "testes"
var title_float_t := 0.0
var title_menu_3d: Node3D = null
var title_menu_btn_nodes: Array = []  # Node3D buttons for bob/hover
var title_hover_btn: Node3D = null

func _ready() -> void:
	_register_inputs()
	_load_config()
	_make_world()
	# Menu ANTES do SessionReport: no Windows FileAccess em user:// pode falhar/atrasar
	# e deixava a arena vazia sem HUD (boot em branco).
	_show_menu()
	call_deferred("_boot_session_report")

func _boot_session_report() -> void:
	if session_report == null:
		return
	var report_path := session_report.start("launch")
	if report_path != "":
		print("HotN3 session report: ", report_path)

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
	_safe_look_at(camera, Vector3(0, 0.5, 0))
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
	fx_player = FxPlayer.new()
	add_child(fx_player)
	presentation.configure(camera, fx_overlay, sound, fx_player)
	if presentation != null:
		presentation.drive_camera = false
	_sync_bgm_pick_from_track()
	_ensure_bgm_for("menu")
	portrait_left = _make_portrait(false)
	portrait_right = _make_portrait(true)
	fx_overlay.add_child(portrait_left)
	fx_overlay.add_child(portrait_right)
	_apply_accessibility()

func _on_viewport_resized() -> void:
	if title_video_plane != null and is_instance_valid(title_video_plane):
		_layout_title_video_plane()
	if battle != null and battle.phase in ["PLAYER", "ENEMY"]: _render_battle()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _build_arena(theme: String = "default") -> void:
	ArenaBuilder.build(stage, theme, battle_view_mode)
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
		if is_instance_valid(node):
			units.remove_child(node)
			node.queue_free()
	actor_nodes.clear()
	unit_sprites.clear()
	if presentation != null: presentation.clear_actors()
	_clear_hand_visuals()
	visible_uids.clear()
	_reset_battle_world_xform()

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

func _button(text_value: String, on_click: Callable = Callable(), hint: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150, 45)
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = hint
	if on_click.is_valid():
		var label := text_value
		var cb := on_click
		button.pressed.connect(func() -> void:
			if session_report != null:
				session_report.log_ui("button", {"label": label, "hint": hint})
			cb.call()
		)
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
	_teardown_title_screen()
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
	battle_menu_open = false
	if battle != null:
		battle = null
	if presentation != null:
		presentation.drive_camera = false
		presentation.clear_actors()
	_reset_menu_camera()
	_ensure_bgm_for("menu")
	_clear_ui()
	_clear_combat_visuals()
	_ensure_title_screen()
	_populate_title_menu()

func _launch_campaign_module() -> void:
	_teardown_title_screen()
	get_tree().change_scene_to_file("res://addons/hotn3_campaign/CampaignRoot.tscn")

func _ensure_title_screen() -> void:
	# Title = ONLY looping video backdrop + floating 3D menu. Hide arena/world.
	if stage != null and is_instance_valid(stage):
		stage.visible = false
	if units != null and is_instance_valid(units):
		units.visible = false
	if title_root != null and is_instance_valid(title_root):
		title_root.visible = true
		if title_video_plane != null and is_instance_valid(title_video_plane):
			title_video_plane.visible = true
		if title_menu_3d != null and is_instance_valid(title_menu_3d):
			title_menu_3d.visible = true
		if title_video_player != null and is_instance_valid(title_video_player) and not title_video_player.is_playing():
			title_video_player.play()
		_layout_title_video_plane()
		return
	title_root = Node3D.new()
	title_root.name = "TitleScreen3D"
	add_child(title_root)
	# Full-viewport video via SubViewport → camera-locked cover plane (not a tiny world quad).
	var vp := SubViewport.new()
	vp.name = "TitleVideoVP"
	var vs := get_viewport().get_visible_rect().size
	vp.size = Vector2i(maxi(int(vs.x), 1280), maxi(int(vs.y), 720))
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	title_root.add_child(vp)
	var vplayer := VideoStreamPlayer.new()
	vplayer.name = "TitleVideo"
	vplayer.expand = true
	vplayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vplayer.size = Vector2(vp.size)
	vplayer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stream_path := ""
	if ResourceLoader.exists("res://assets/video/Title.ogv") or FileAccess.file_exists("res://assets/video/Title.ogv"):
		stream_path = "res://assets/video/Title.ogv"
	elif ResourceLoader.exists("res://assets/video/Title.mp4") or FileAccess.file_exists("res://assets/video/Title.mp4"):
		stream_path = "res://assets/video/Title.mp4"
	if stream_path != "":
		var stream = load(stream_path)
		if stream != null:
			vplayer.stream = stream
	vplayer.finished.connect(func() -> void:
		if is_instance_valid(vplayer):
			vplayer.play()
	)
	vp.add_child(vplayer)
	title_video_player = vplayer
	var plane := MeshInstance3D.new()
	plane.name = "TitleVideoPlane"
	var quad := QuadMesh.new()
	quad.size = Vector2(16.0, 9.0)
	plane.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	plane.material_override = mat
	# Locked to camera: always fills the lens (cover), never a small world plane.
	if camera != null:
		camera.add_child(plane)
	else:
		title_root.add_child(plane)
	title_video_plane = plane
	_layout_title_video_plane()
	# Floating 3D menu host (camera-local, in front of video).
	var menu := Node3D.new()
	menu.name = "TitleMenu3D"
	menu.position = Vector3(0.0, 0.15, -4.2)
	if camera != null:
		camera.add_child(menu)
	else:
		title_root.add_child(menu)
	title_menu_3d = menu
	if stream_path != "" and title_video_player != null:
		title_video_player.play()

func _layout_title_video_plane() -> void:
	if title_video_plane == null or not is_instance_valid(title_video_plane) or camera == null:
		return
	var dist := 14.0
	title_video_plane.position = Vector3(0.0, 0.0, -dist)
	# Camera-local: plane at -Z, QuadMesh +Z faces the lens with identity UV/scale (matches source).
	title_video_plane.rotation = Vector3.ZERO
	title_video_plane.scale = Vector3.ONE
	var aspect := 16.0 / 9.0
	var vis := get_viewport().get_visible_rect().size
	var view_aspect := vis.x / maxf(vis.y, 1.0)
	var v_fov := deg_to_rad(camera.fov)
	var view_h := 2.0 * dist * tan(v_fov * 0.5)
	var view_w := view_h * view_aspect
	# Cover: plane large enough to fill the entire lens (crop edges if needed).
	var plane_h := maxf(view_h, view_w / aspect) * 1.02
	var plane_w := plane_h * aspect
	var quad: QuadMesh = title_video_plane.mesh as QuadMesh
	if quad == null:
		quad = QuadMesh.new()
		title_video_plane.mesh = quad
	quad.size = Vector2(plane_w, plane_h)
	# Keep SubViewport resolution near screen for sharp video.
	if title_root != null and is_instance_valid(title_root):
		var vp := title_root.get_node_or_null("TitleVideoVP") as SubViewport
		if vp != null:
			vp.size = Vector2i(maxi(int(vis.x), 1280), maxi(int(vis.y), 720))
			if title_video_player != null and is_instance_valid(title_video_player):
				title_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				title_video_player.offset_left = 0.0
				title_video_player.offset_top = 0.0
				title_video_player.offset_right = 0.0
				title_video_player.offset_bottom = 0.0

func _teardown_title_screen() -> void:
	if title_video_player != null and is_instance_valid(title_video_player):
		title_video_player.stop()
	title_video_player = null
	title_menu_btn_nodes.clear()
	title_hover_btn = null
	if title_video_plane != null and is_instance_valid(title_video_plane):
		title_video_plane.queue_free()
	title_video_plane = null
	if title_menu_3d != null and is_instance_valid(title_menu_3d):
		title_menu_3d.queue_free()
	title_menu_3d = null
	if title_root != null and is_instance_valid(title_root):
		title_root.queue_free()
	title_root = null
	if stage != null and is_instance_valid(stage):
		stage.visible = true
	if units != null and is_instance_valid(units):
		units.visible = true

func _title_menu_font() -> Font:
	if ResourceLoader.exists("res://assets/fonts/CardTitle.ttf"):
		return load("res://assets/fonts/CardTitle.ttf")
	return null

func _title_button(text_value: String, on_click: Callable = Callable(), hint: String = "", big: bool = false) -> Button:
	# Kept for non-title screens that may reuse styling helpers.
	var b := _button(text_value, on_click, hint)
	b.custom_minimum_size = Vector2(420 if big else 380, 52 if big else 44)
	b.add_theme_font_size_override("font_size", 22 if big else 18)
	var f := _title_menu_font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_color_override("font_color", Color("f6edd8"))
	b.add_theme_color_override("font_hover_color", Color("ffe6a0"))
	return b

func _make_title_menu_button_3d(text_value: String, on_click: Callable, hint: String = "", big: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "TitleBtn_%s" % text_value.replace(" ", "_")
	root.set_meta("title_label", text_value)
	root.set_meta("title_hint", hint)
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	var box := BoxMesh.new()
	box.size = Vector3(3.6 if big else 2.85, 0.62 if big else 0.44, 0.12)
	plate.mesh = box
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.07, 0.09, 0.16, 0.82)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.emission_enabled = true
	pmat.emission = Color(0.55, 0.38, 0.14)
	pmat.emission_energy_multiplier = 0.4
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plate.material_override = pmat
	root.add_child(plate)
	var lab := Label3D.new()
	lab.name = "Label"
	lab.text = text_value
	lab.font_size = 42 if big else 28
	lab.modulate = Color("f6edd8")
	lab.outline_size = 10
	lab.outline_modulate = Color(0.05, 0.02, 0.08, 0.95)
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.position = Vector3(0.0, 0.0, 0.09)
	# Camera-local host: Label3D +Z already faces the lens; do not Y-flip (that mirrors glyphs).
	lab.rotation_degrees.y = 0.0
	var f := _title_menu_font()
	if f != null:
		lab.font = f
	root.add_child(lab)
	var area := Area3D.new()
	area.name = "Hit"
	area.input_ray_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	area.set_meta("title_action", on_click)
	area.set_meta("title_btn_root", root)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.7 if big else 2.95, 0.7 if big else 0.50, 0.35)
	col.shape = shape
	area.add_child(col)
	root.add_child(area)
	return root

func _make_title_menu_label_3d(text_value: String, font_size: int, color: Color) -> Label3D:
	var lab := Label3D.new()
	lab.text = text_value
	lab.font_size = font_size
	lab.modulate = color
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lab.rotation_degrees.y = 0.0
	var f := _title_menu_font()
	if f != null:
		lab.font = f
	return lab

func _clear_title_menu_3d_children() -> void:
	title_menu_btn_nodes.clear()
	title_hover_btn = null
	if title_menu_3d == null or not is_instance_valid(title_menu_3d):
		return
	for child in title_menu_3d.get_children():
		title_menu_3d.remove_child(child)
		child.queue_free()

func _populate_title_menu() -> void:
	# Floating 3D buttons (Mesh + Label3D) — árvore trancada. No flat Control list.
	if title_menu_3d == null or not is_instance_valid(title_menu_3d):
		return
	_clear_title_menu_3d_children()
	var rows: Array = []
	if title_menu_section == "":
		rows.append({"kind": "title", "text": "HEROES OF THE NIGHTMARE 3", "size": 52, "color": Color("f0c27a")})
		rows.append({"kind": "label", "text": "Missões %d/%d · Essência %d" % [best_stars.size(), Content.MISSIONS.size(), essence], "size": 22, "color": Color("9aa6bf")})
	else:
		# Submenus: compact header so Campanha…Escolher itens + Voltar stay fully on-screen.
		rows.append({"kind": "title", "text": "HEROES OF THE NIGHTMARE 3", "size": 34, "color": Color("f0c27a")})
		rows.append({"kind": "label", "text": "Missões %d/%d · Essência %d" % [best_stars.size(), Content.MISSIONS.size(), essence], "size": 18, "color": Color("9aa6bf")})
	if feedback != "":
		rows.append({"kind": "label", "text": feedback, "size": 20, "color": Color("a3eec4")})
		feedback = ""
	match title_menu_section:
		"jogar":
			if ResourceLoader.exists("res://addons/hotn3_campaign/CampaignRoot.tscn"):
				rows.append({"kind": "btn", "text": "Campanha", "hint": "A Fenda das Três Vigílias · três capítulos", "cb": _launch_campaign_module})
			else:
				rows.append({"kind": "label", "text": "(Campanha indisponível)", "size": 20, "color": Color("9aa6bf")})
			rows.append({"kind": "btn", "text": "Missões", "hint": "Selecionar missão", "cb": func() -> void:
				_teardown_title_screen()
				_show_missions()
			})
			rows.append({"kind": "btn", "text": "Arena", "hint": "3 aliados + 3 inimigos", "cb": func() -> void:
				_teardown_title_screen()
				_show_arena()
			})
			rows.append({"kind": "btn", "text": "Escolher equipe", "hint": "", "cb": func() -> void:
				_teardown_title_screen()
				_show_team()
			})
			rows.append({"kind": "btn", "text": "Escolher itens", "hint": "", "cb": func() -> void:
				_teardown_title_screen()
				_show_items()
			})
			rows.append({"kind": "btn", "text": "← Voltar", "hint": "", "big": false, "cb": func() -> void:
				title_menu_section = ""
				_show_menu()
			})
		"testes":
			rows.append({"kind": "btn", "text": "Copiar caminho do report", "hint": "Relatório JSONL desta sessão", "cb": func() -> void:
				_copy_session_report_path()
				_show_menu()
			})
			rows.append({"kind": "btn", "text": "Coleção de cartas", "hint": "", "cb": func() -> void:
				_teardown_title_screen()
				_show_collection()
			})
			rows.append({"kind": "btn", "text": "Testar Animações", "hint": "Pré-visualiza RM/FX sem combate", "cb": func() -> void:
				_teardown_title_screen()
				_show_anim_test()
			})
			rows.append({"kind": "btn", "text": "← Voltar", "hint": "", "big": false, "cb": func() -> void:
				title_menu_section = ""
				_show_menu()
			})
		_:
			rows.append({"kind": "btn", "text": "Jogar", "hint": "Campanha, missões, arena, equipe e itens", "cb": func() -> void:
				title_menu_section = "jogar"
				_show_menu()
			})
			rows.append({"kind": "btn", "text": "Testes", "hint": "Report, coleção e animações", "cb": func() -> void:
				title_menu_section = "testes"
				_show_menu()
			})
			rows.append({"kind": "btn", "text": "Configurações", "hint": "", "cb": func() -> void:
				_teardown_title_screen()
				_show_settings()
			})
	# Fit stack into camera frustum at menu Z (compact + scale when dense, e.g. Jogar).
	var btn_count := 0
	for row0 in rows:
		if str(row0.get("kind", "")) == "btn":
			btn_count += 1
	var force_compact := btn_count >= 4 or title_menu_section in ["jogar", "testes"]
	var step_title := 0.42 if force_compact else 0.55
	var step_label := 0.30 if force_compact else 0.44
	var step_btn_big := 0.66 if force_compact else 0.78
	var step_btn_sm := 0.50 if force_compact else 0.64
	var est_h := 0.0
	for row in rows:
		var kind0 := str(row.get("kind", ""))
		if kind0 == "title":
			est_h += step_title
		elif kind0 == "label":
			est_h += step_label
		elif kind0 == "btn":
			var big0 := bool(row.get("big", true)) and not force_compact
			est_h += step_btn_big if big0 else step_btn_sm
	var menu_z := absf(title_menu_3d.position.z)
	var v_fov := deg_to_rad(camera.fov if camera != null else 51.0)
	var view_h := 2.0 * menu_z * tan(v_fov * 0.5)
	var max_h := view_h * 0.84  # leave margin top/bottom
	var pack := 1.0
	if est_h > max_h and est_h > 0.001:
		pack = max_h / est_h
	pack = clampf(pack, 0.52, 1.0)
	var root_scale := 1.0
	if force_compact:
		root_scale = minf(root_scale, 0.92)
	if pack < 0.70:
		root_scale *= pack / 0.70
		pack = 0.70
	title_menu_3d.scale = Vector3(root_scale, root_scale, root_scale)
	step_title *= pack
	step_label *= pack
	step_btn_big *= pack
	step_btn_sm *= pack
	var total_h := est_h * pack
	# Center; slight downward bias when dense so the top title is not clipped by the lens.
	var y := total_h * 0.5 - (0.12 if force_compact else 0.0)
	for row in rows:
		var kind := str(row.get("kind", ""))
		if kind == "title" or kind == "label":
			var fs := int(row.get("size", 22))
			if pack < 0.95 or force_compact:
				fs = maxi(16, int(round(float(fs) * lerpf(0.80, 1.0, pack))))
			var lab := _make_title_menu_label_3d(str(row["text"]), fs, row.get("color", Color.WHITE))
			lab.position = Vector3(0.0, y, 0.0)
			title_menu_3d.add_child(lab)
			y -= step_label if kind == "label" else step_title
		elif kind == "btn":
			var big := bool(row.get("big", true)) and not force_compact
			var btn := _make_title_menu_button_3d(str(row["text"]), row["cb"], str(row.get("hint", "")), big)
			btn.position = Vector3(0.0, y, 0.0)
			title_menu_3d.add_child(btn)
			title_menu_btn_nodes.append(btn)
			y -= step_btn_big if big else step_btn_sm

func _handle_title_menu_input(input: InputEvent) -> bool:
	if title_menu_3d == null or not is_instance_valid(title_menu_3d):
		return false
	if battle != null:
		return false
	if not (input is InputEventMouseButton):
		return false
	var click := input as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return false
	if camera == null:
		return false
	var origin := camera.project_ray_origin(click.position)
	var end := origin + camera.project_ray_normal(click.position) * 80.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.has("collider"):
		return false
	var collider: Object = hit["collider"]
	if not collider.has_meta("title_action"):
		return false
	var cb: Callable = collider.get_meta("title_action")
	var label := ""
	if collider.has_meta("title_btn_root"):
		var br: Node = collider.get_meta("title_btn_root")
		if br != null and is_instance_valid(br) and br.has_meta("title_label"):
			label = str(br.get_meta("title_label"))
	if session_report != null:
		session_report.log_ui("title_button", {"label": label})
	if sound != null:
		sound.cue("confirm", "UI")
	# Marca o input ANTES do callback: Campanha faz change_scene e invalida o viewport.
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	if cb.is_valid():
		cb.call()
	return true

func _tick_title_menu_hover() -> void:
	if title_menu_3d == null or not is_instance_valid(title_menu_3d) or camera == null or battle != null:
		return
	var pointer := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pointer) * 80.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var new_hover: Node3D = null
	if hit.has("collider") and hit["collider"].has_meta("title_btn_root"):
		var br = hit["collider"].get_meta("title_btn_root")
		if br is Node3D and is_instance_valid(br):
			new_hover = br
	if new_hover == title_hover_btn:
		return
	if title_hover_btn != null and is_instance_valid(title_hover_btn):
		var old_lab: Label3D = title_hover_btn.get_node_or_null("Label")
		var old_plate: MeshInstance3D = title_hover_btn.get_node_or_null("Plate")
		if old_lab != null:
			old_lab.modulate = Color("f6edd8")
		if old_plate != null and old_plate.material_override != null:
			old_plate.material_override.emission_energy_multiplier = 0.4
			old_plate.material_override.albedo_color = Color(0.07, 0.09, 0.16, 0.82)
		title_hover_btn.scale = Vector3.ONE
	title_hover_btn = new_hover
	if title_hover_btn != null:
		var lab: Label3D = title_hover_btn.get_node_or_null("Label")
		var plate: MeshInstance3D = title_hover_btn.get_node_or_null("Plate")
		if lab != null:
			lab.modulate = Color("ffe6a0")
		if plate != null and plate.material_override != null:
			plate.material_override.emission_energy_multiplier = 1.1
			plate.material_override.albedo_color = Color(0.12, 0.14, 0.22, 0.9)
		title_hover_btn.scale = Vector3(1.06, 1.06, 1.06)

func _show_anim_test() -> void:
	battle = null
	battle_menu_open = false
	if presentation != null:
		presentation.drive_camera = false
		presentation.clear_actors()
	_reset_menu_camera()
	_ensure_bgm_for("menu")
	_clear_ui()
	_clear_combat_visuals()
	if anim_test_card == "" or not Content.CARDS.has(anim_test_card):
		var keys: Array = Content.CARDS.keys()
		keys.sort()
		if not keys.is_empty():
			anim_test_card = str(keys[0])
	_spawn_anim_test_actors()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(520, 640)
	if ResourceLoader.exists("res://assets/ui/panel.png"):
		var ps := StyleBoxTexture.new()
		ps.texture = load("res://assets/ui/panel.png")
		ps.set_texture_margin_all(28)
		panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_label("TESTE DE ANIMAÇÃO", 28, Color("dcc28b")))
	col.add_child(_label("Só FX/RM — sem Iniciativa, dano ou status.", 15, Color("9aa6bf")))
	var caster_name := str(Content.HEROES.get(anim_test_caster, {}).get("name", anim_test_caster))
	var target_name := str(Content.HEROES.get(anim_test_target, {}).get("name", anim_test_target))
	col.add_child(_button("Usuário (caster): %s" % caster_name, _anim_test_pick_actor.bind("caster")))
	col.add_child(_button("Alvo: %s" % target_name, _anim_test_pick_actor.bind("target")))
	# Filtros
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	col.add_child(filter_row)
	var owner_btn := _button("Personagem: %s" % ("Todos" if anim_test_filter_owner == "" else str(Content.HEROES.get(anim_test_filter_owner, {}).get("name", anim_test_filter_owner))), _anim_test_pick_filter_owner)
	owner_btn.custom_minimum_size = Vector2(240, 40)
	filter_row.add_child(owner_btn)
	var class_btn := _button("Tipo: %s" % ("Todos" if anim_test_filter_class == "" else anim_test_filter_class), _anim_test_cycle_filter_class)
	class_btn.custom_minimum_size = Vector2(160, 40)
	filter_row.add_child(class_btn)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	col.add_child(name_row)
	name_row.add_child(_label("Nome:", 16, Color("c9d1dd")))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "filtrar por nome…"
	name_edit.text = anim_test_filter_name
	name_edit.custom_minimum_size = Vector2(280, 34)
	name_edit.text_changed.connect(func(t: String) -> void:
		anim_test_filter_name = t
	)
	name_edit.text_submitted.connect(func(_t: String) -> void: _show_anim_test())
	name_row.add_child(name_edit)
	name_row.add_child(_button("Filtrar", _show_anim_test))
	var card_name := str(Content.CARDS.get(anim_test_card, {}).get("name", anim_test_card))
	var cdef: Dictionary = Content.CARDS.get(anim_test_card, {})
	col.add_child(_label("Carta: %s" % card_name, 18, Color("f0c27a")))
	col.add_child(_label("anim_self: %s  ·  anim_target: %s" % [str(cdef.get("anim_self", [])), str(cdef.get("anim_target", []))], 13, Color("9aa6bf")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 280)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for cid in _anim_test_filtered_cards():
		var defn: Dictionary = Content.CARDS[cid]
		var owner_id := str(defn.get("owner", ""))
		var oname := str(Content.HEROES.get(owner_id, {}).get("name", owner_id))
		var label := "%s%s · %s · %s" % ["▶ " if cid == anim_test_card else "", defn.get("name", cid), oname, defn.get("class", "?")]
		var b := _button(label, _anim_test_set_card.bind(str(cid)))
		b.custom_minimum_size = Vector2(450, 36)
		b.add_theme_font_size_override("font_size", 14)
		list.add_child(b)
	var play := _button("▶ Reproduzir animação", _anim_test_play)
	play.custom_minimum_size = Vector2(280, 48)
	col.add_child(play)
	col.add_child(_button("Voltar", _show_menu))


func _anim_test_filtered_cards() -> Array[String]:
	var out: Array[String] = []
	var needle := anim_test_filter_name.strip_edges().to_lower()
	var ids: Array = Content.CARDS.keys()
	ids.sort()
	for cid0 in ids:
		var cid := str(cid0)
		var defn: Dictionary = Content.CARDS[cid]
		if anim_test_filter_owner != "" and str(defn.get("owner", "")) != anim_test_filter_owner:
			continue
		if anim_test_filter_class != "" and str(defn.get("class", "")) != anim_test_filter_class:
			continue
		if needle != "":
			var hay := ("%s %s" % [defn.get("name", ""), cid]).to_lower()
			if needle not in hay:
				continue
		out.append(cid)
	return out


func _anim_test_set_card(card_id: String) -> void:
	anim_test_card = card_id
	_show_anim_test()


func _anim_test_cycle_filter_class() -> void:
	var order := ["", "ATTACK", "ESTADO", "POSTURA", "DESVANTAGEM", "SKILL", "ITEM"]
	var idx := order.find(anim_test_filter_class)
	if idx < 0:
		idx = 0
	anim_test_filter_class = order[(idx + 1) % order.size()]
	_show_anim_test()


func _anim_test_pick_filter_owner() -> void:
	_clear_ui()
	var menu := _center_panel("FILTRO · PERSONAGEM")
	menu.add_child(_button("Todos", func() -> void:
		anim_test_filter_owner = ""
		_show_anim_test()
	))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 420)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	menu.add_child(scroll)
	var ids: Array = Content.HEROES.keys()
	ids.sort()
	for hid in ids:
		var id := str(hid)
		var hero: Dictionary = Content.HEROES[id]
		if not bool(hero.get("playable", true)):
			continue
		list.add_child(_button("%s · %s" % [hero.get("name", id), hero.get("type", "?")], func() -> void:
			anim_test_filter_owner = id
			_show_anim_test()
		))
	menu.add_child(_button("Voltar", _show_anim_test))


func _anim_test_pick_actor(role: String) -> void:
	_clear_ui()
	var title := "USUÁRIO (CASTER)" if role == "caster" else "ALVO"
	var menu := _center_panel("TESTE ANIM · %s" % title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 460)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	menu.add_child(scroll)
	var ids: Array = Content.HEROES.keys()
	ids.sort()
	for hid in ids:
		var id := str(hid)
		var hero: Dictionary = Content.HEROES[id]
		if str(hero.get("sprite", "")) == "":
			continue
		var label := "%s · %s" % [hero.get("name", id), hero.get("type", "?")]
		list.add_child(_button(label, _anim_test_set_actor.bind(role, id)))
	menu.add_child(_button("Voltar", _show_anim_test))


func _anim_test_set_actor(role: String, hero_id: String) -> void:
	if role == "caster":
		anim_test_caster = hero_id
	else:
		anim_test_target = hero_id
	_show_anim_test()


func _spawn_anim_test_actors() -> void:
	_clear_combat_visuals()
	if presentation != null:
		presentation.drive_camera = false
		presentation.clear_actors()
	var caster_hero: Dictionary = Content.HEROES.get(anim_test_caster, {})
	var target_hero: Dictionary = Content.HEROES.get(anim_test_target, {})
	if caster_hero.is_empty() or target_hero.is_empty():
		return
	var caster_actor := {
		"id": 1, "name": caster_hero.get("name", anim_test_caster), "side": "ALLY", "row": "front",
		"hp": int(caster_hero.get("hp", 20)), "max_hp": int(caster_hero.get("hp", 20)),
		"sprite": caster_hero.get("sprite", ""), "portrait": caster_hero.get("portrait", ""),
		"type": caster_hero.get("type", ""), "block": 0, "shield": 0, "statuses": {},
	}
	var target_actor := {
		"id": 2, "name": target_hero.get("name", anim_test_target), "side": "ENEMY", "row": "front",
		"hp": int(target_hero.get("hp", 20)), "max_hp": int(target_hero.get("hp", 20)),
		"sprite": target_hero.get("sprite", ""), "portrait": target_hero.get("portrait", ""),
		"type": target_hero.get("type", ""), "block": 0, "shield": 0, "statuses": {},
	}
	var cpos := Vector3(-2.4, 0, 0)
	var tpos := Vector3(2.4, 0, 0)
	if battle_view_mode == "lateral":
		cpos = Vector3(-2.2, 0, 1.2)
		tpos = Vector3(2.2, 0, 1.2)
	actor_nodes[1] = _create_actor_visual(caster_actor)
	actor_nodes[1].position = cpos
	actor_nodes[2] = _create_actor_visual(target_actor)
	actor_nodes[2].position = tpos
	var c_av: Sprite3D = actor_nodes[1].get_node_or_null("Avatar")
	var t_av: Sprite3D = actor_nodes[2].get_node_or_null("Avatar")
	if c_av != null:
		unit_sprites.append(c_av)
		if presentation != null:
			presentation.bind_actor(1, c_av, cpos)
	if t_av != null:
		unit_sprites.append(t_av)
		if presentation != null:
			presentation.bind_actor(2, t_av, tpos)
	# Sem barras de combate no modo teste
	for nid in [1, 2]:
		var body: Node3D = actor_nodes[nid]
		var hp := body.get_node_or_null("WorldHp")
		if hp != null:
			hp.visible = false
		var np := body.get_node_or_null("Nameplate")
		if np != null:
			np.text = str(caster_hero.get("name", "") if nid == 1 else target_hero.get("name", ""))
	if camera != null:
		camera.position = Vector3(0, 3.2, 9.5)
		camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _anim_test_play() -> void:
	if anim_test_playing:
		return
	if not Content.CARDS.has(anim_test_card):
		feedback = "Selecione uma carta."
		return
	if fx_player == null or presentation == null:
		return
	var definition: Dictionary = Content.CARDS[anim_test_card].duplicate(true)
	# Garante listas de anim mesmo se vazias
	if not definition.has("anim_self") or definition["anim_self"] == null:
		definition["anim_self"] = ["cast"]
	if not definition.has("anim_target") or definition["anim_target"] == null:
		definition["anim_target"] = ["hit"]
	anim_test_playing = true
	if sound != null:
		sound.cue("cast", "UI")
	if presentation != null:
		presentation.show_action("cast", 1, 2, 0)
	var dur := float(presentation.play_card_fx(definition, 1, 2))
	var wait := maxf(0.45, dur)
	get_tree().create_timer(wait / maxf(animation_speed, 0.25)).timeout.connect(func() -> void:
		anim_test_playing = false
		if presentation != null:
			presentation.show_action("hit", 1, 2, 0)
	)
	if session_report != null:
		session_report.log_ui("anim_test_play", {"card": anim_test_card, "caster": anim_test_caster, "target": anim_test_target, "dur": dur})


func _show_arena() -> void:
	if arena_allies.is_empty():
		arena_allies = team.duplicate() if team.size() == 3 else (["ent_alyssa_wine", "ent_adam", "ent_madelyn"] as Array[String])
	if arena_enemies.is_empty():
		arena_enemies = ["ent_akuji", "ent_fate", "ent_evelyn_graves"] as Array[String]
	_clear_ui()
	var menu := _center_panel("ARENA")
	menu.add_child(_label("Escolha 3 aliados e 3 inimigos. Combate livre (sem missões).", 17, Color("9aa6bf")))
	menu.add_child(_label("Aliados", 20, Color("6dffa3")))
	for i in range(3):
		var cur := arena_allies[i] if i < arena_allies.size() else ""
		var name := str(Content.HEROES.get(cur, {}).get("name", cur if cur != "" else "(vazio)"))
		menu.add_child(_button("Aliado %d: %s" % [i + 1, name], _arena_pick_slot.bind("ally", i)))
	menu.add_child(_label("Inimigos", 20, Color("ff8a8a")))
	for i in range(3):
		var cur2 := arena_enemies[i] if i < arena_enemies.size() else ""
		var name2 := str(Content.HEROES.get(cur2, {}).get("name", cur2 if cur2 != "" else "(vazio)"))
		menu.add_child(_button("Inimigo %d: %s" % [i + 1, name2], _arena_pick_slot.bind("enemy", i)))
	var ready := arena_allies.size() == 3 and arena_enemies.size() == 3
	ready = ready and arena_allies[0] != "" and arena_enemies[0] != ""
	var fight := _button("Iniciar combate", _start_arena_battle)
	fight.disabled = not ready
	menu.add_child(fight)
	menu.add_child(_button("Voltar", _show_menu))

func _arena_pick_slot(side: String, slot: int) -> void:
	_clear_ui()
	var menu := _center_panel("ARENA · escolher %s %d" % ["aliado" if side == "ally" else "inimigo", slot + 1])
	var ids: Array = Content.HEROES.keys()
	ids.sort()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 420)
	scroll.add_child(list)
	menu.add_child(scroll)
	for hid in ids:
		var id := str(hid)
		var hero: Dictionary = Content.HEROES[id]
		if not bool(hero.get("playable", true)):
			continue
		if bool(hero.get("minion", false)) and side == "ally":
			continue
		var label := "%s · %s" % [hero.get("name", id), hero.get("type", "?")]
		list.add_child(_button(label, _arena_set_slot.bind(side, slot, id)))
	menu.add_child(_button("Voltar", _show_arena))

func _arena_set_slot(side: String, slot: int, hero_id: String) -> void:
	if side == "ally":
		while arena_allies.size() <= slot:
			arena_allies.append("")
		# Evita duplicar aliados
		for i in range(arena_allies.size()):
			if i != slot and arena_allies[i] == hero_id:
				arena_allies[i] = ""
		arena_allies[slot] = hero_id
	else:
		while arena_enemies.size() <= slot:
			arena_enemies.append("")
		arena_enemies[slot] = hero_id
	_show_arena()

func _start_arena_battle() -> void:
	if arena_allies.size() != 3 or arena_enemies.size() != 3:
		return
	for id in arena_allies:
		if id == "" or not Content.HEROES.has(id):
			return
	for id in arena_enemies:
		if id == "" or not Content.HEROES.has(id):
			return
	team = arena_allies.duplicate()
	mission_id = "arena"
	# Missão sintética temporária
	if not Content.MISSIONS.has("arena"):
		Content.MISSIONS["arena"] = {
			"name": "Arena",
			"objective": "ELIMINATE",
			"arena": "street_night",
			"enemies": arena_enemies.duplicate(),
			"reinforcements": {},
			"environment": [],
		}
	else:
		Content.MISSIONS["arena"]["enemies"] = arena_enemies.duplicate()
	if not Content.CAMPAIGN.has("arena"):
		Content.CAMPAIGN["arena"] = {"requires": [], "par": 3, "brief": "Combate livre na Arena.", "goal": "Elimine os adversários."}
	_start_mission()


func _show_settings() -> void:
	var menu := _center_panel("CONFIGURAÇÕES")
	for channel in ["MASTER", "MUSIC", "SFX", "UI", "AMBIENCE"]:
		var names := {"MASTER": "Volume geral", "MUSIC": "Música", "SFX": "Combate", "UI": "Interface", "AMBIENCE": "Ambiente"}
		menu.add_child(_setting_slider(names[channel], float(sound_levels[channel]), _set_volume.bind(channel)))
	menu.add_child(_setting_slider("Intensidade do tremor", shake_level, _set_shake))
	menu.add_child(_setting_slider("Velocidade das animações", (animation_speed - 0.5) / 1.5, _set_animation_speed))
	menu.add_child(_button("Reduzir flashes: %s" % ("sim" if reduce_flashes else "não"), _toggle_flashes))
	menu.add_child(_button("Reduzir movimento da câmera: %s" % ("sim" if reduce_motion else "não"), _toggle_motion))
	menu.add_child(_button("Vista de batalha: %s" % ("Lateral" if battle_view_mode == "lateral" else "Normal"), _toggle_battle_view))
	menu.add_child(_button("Conteúdo sensível: %s" % ("sim" if sensitive_content else "não"), _toggle_sensitive_content))
	menu.add_child(_label("BGM (música de fundo)", 18))
	menu.add_child(_bgm_picker_row())
	menu.add_child(_button("Parar BGM", _stop_bgm_setting))
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

func _toggle_battle_view() -> void:
	battle_view_mode = "lateral" if battle_view_mode == "normal" else "normal"
	_apply_battle_view()
	_save_config()
	if battle != null and battle.phase in ["PLAYER", "ENEMY"]:
		_build_arena(_arena_theme_for_mission(mission_id))
		_render_battle()
	else:
		_show_settings()

func _toggle_sensitive_content() -> void:
	sensitive_content = not sensitive_content
	_save_config()
	if battle != null and battle.phase in ["PLAYER", "ENEMY"]:
		_clear_combat_visuals()
		_render_battle()
	else:
		_show_settings()

func _is_real_bgm(track_id: String) -> bool:
	return track_id != "" and track_id != "__stop__" and track_id != "__synth__"

func _sync_bgm_pick_from_track() -> void:
	if _is_real_bgm(bgm_track):
		bgm_pick = bgm_track
	elif not _is_real_bgm(bgm_pick):
		bgm_pick = MENU_BGM_DEFAULT

func _bgm_resolve_pick() -> String:
	if _is_real_bgm(bgm_pick):
		return bgm_pick
	if _is_real_bgm(bgm_track):
		return bgm_track
	if sound != null and _is_real_bgm(str(sound.current_bgm)):
		return str(sound.current_bgm)
	return MENU_BGM_DEFAULT

func _bgm_default_for(context: String) -> String:
	return BATTLE_BGM_DEFAULT if context == "battle" else MENU_BGM_DEFAULT

func _ensure_bgm_for(context: String) -> void:
	if bgm_track == "__stop__":
		if sound != null:
			sound.stop_bgm()
		return
	var track := bgm_track
	if not _is_real_bgm(track):
		track = _bgm_default_for(context)
	elif context == "menu" and track == BATTLE_BGM_DEFAULT:
		# Primeira abertura / padrão de combate: tema de menu no título.
		track = MENU_BGM_DEFAULT
	elif context == "battle" and track == MENU_BGM_DEFAULT:
		track = BATTLE_BGM_DEFAULT
	bgm_pick = track
	if sound != null:
		sound.play_bgm(track)

func _bgm_picker_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var pick := _bgm_resolve_pick()
	var stopped := bgm_track == "__stop__" or (sound != null and str(sound.current_bgm) == "__stop__")
	var label_text := ("%s (parada)" % pick) if stopped else pick
	var name_lbl := _label(label_text if label_text != "" else "(nenhuma)", 16, Color("f4f1ea"))
	name_lbl.custom_minimum_size = Vector2(220, 28)
	name_lbl.clip_text = true
	row.add_child(name_lbl)
	row.add_child(_button("◀", func(): _cycle_bgm(-1)))
	row.add_child(_button("▶", func(): _cycle_bgm(1)))
	# Tocar usa a faixa do seletor (bgm_pick), nunca o "__stop__" salvo.
	row.add_child(_button("Tocar", func(): _apply_bgm_track(_bgm_resolve_pick())))
	return row

func _cycle_bgm(step: int) -> void:
	var tracks: PackedStringArray = sound.list_bgm() if sound != null else PackedStringArray()
	if tracks.is_empty():
		return
	var current_pick := _bgm_resolve_pick()
	var idx := 0
	for i in range(tracks.size()):
		if str(tracks[i]) == current_pick:
			idx = i
			break
	idx = (idx + step) % tracks.size()
	_apply_bgm_track(str(tracks[idx]))
	if battle != null and battle_menu_open:
		_render_battle()
	elif battle == null:
		_show_settings()

func _apply_bgm_track(track_id: String) -> void:
	if track_id == "__stop__" or track_id == "":
		_stop_bgm_setting()
		return
	bgm_track = track_id
	bgm_pick = track_id
	if sound != null:
		sound.play_bgm(bgm_track)
	_save_config()

func _stop_bgm_setting() -> void:
	# Preferir a faixa que está tocando (ex.: Battle1 no combate com preferência title).
	if sound != null and _is_real_bgm(str(sound.current_bgm)):
		bgm_pick = str(sound.current_bgm)
	elif _is_real_bgm(bgm_track):
		bgm_pick = bgm_track
	elif not _is_real_bgm(bgm_pick):
		bgm_pick = MENU_BGM_DEFAULT
	bgm_track = "__stop__"
	if sound != null:
		sound.stop_bgm()
	_save_config()
	if battle != null and battle_menu_open:
		_render_battle()
	elif battle == null:
		_show_settings()

func _reset_menu_camera() -> void:
	# Vista estável no título (evita look_at singular / debugger pause no editor).
	if camera == null:
		return
	camera.position = Vector3(0, 11.5, 18)
	camera.fov = 51.0
	_safe_look_at(camera, Vector3(0, 0.5, 0))
	if presentation != null:
		presentation.camera_position = camera.position
		presentation.orbit = 0.0
		presentation.ally_focus = Vector3.ZERO
		presentation.focus_target = Vector3.ZERO
		presentation.zoom = 1.0
		presentation.punch = Vector3.ZERO

func _safe_look_at(node: Node3D, target: Vector3, up: Vector3 = Vector3.UP) -> void:
	if node == null:
		return
	var origin := node.global_position if node.is_inside_tree() else node.position
	var dir := target - origin
	if dir.length_squared() < 1e-6:
		return
	var up_n := up.normalized()
	if absf(dir.normalized().dot(up_n)) > 0.998:
		target += Vector3(0.05, 0.0, 0.05)
	node.look_at(target, up)

func _apply_battle_view() -> void:
	if presentation == null:
		return
	presentation.view_mode = battle_view_mode
	if battle_view_mode != "lateral":
		presentation.zoom = 1.0
		presentation.focus_target = Vector3.ZERO
		presentation.orbit = 0.0
		if camera != null:
			camera.fov = 51.0
		_reset_battle_world_xform()
	else:
		if camera != null:
			camera.fov = 42.0

func _apply_accessibility() -> void:
	if presentation == null: return
	presentation.shake_enabled = shake_level > 0.0 and not reduce_motion
	presentation.shake_scale = shake_level
	presentation.flash_enabled = not reduce_flashes
	presentation.animation_speed = animation_speed
	presentation.motion_scale = 0.15 if reduce_motion else 1.0
	_apply_battle_view()

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
	menu.add_child(_button("Jogar Missão: %s" % Content.MISSIONS[mission_id]["name"], _start_mission))
	menu.add_child(_button("Voltar", _show_menu))

func _mission_unlocked(id: String) -> bool:
	return CampaignRules.mission_unlocked(id, Content.CAMPAIGN, best_stars)

func _select_mission(id: String) -> void:
	if not _mission_unlocked(id): return
	mission_id = id
	_show_missions()


func _refresh_actor_hp_bars() -> void:
	if battle == null: return
	for id in actor_nodes.keys():
		var body: Node3D = actor_nodes[id]
		if not is_instance_valid(body): continue
		var actor: Dictionary = battle.actor_by_id(int(id))
		if actor.is_empty(): continue
		_update_world_hp_bar(body, actor)


func _status_icon_glyph(status_id: String) -> String:
	match str(status_id).to_lower():
		"bleed", "sangrando", "sangramento": return "🩸"
		"burn", "queimadura": return "🔥"
		"poison", "veneno": return "☠️"
		"stun", "atordoado": return "💫"
		"slow", "lento": return "🐢"
		"weak", "fraco": return "⬇️"
		"vulnerable", "vulneravel": return "💥"
		"protecao", "protection", "protegido": return "🛡️"
		"barreira", "barrier": return "🧱"
		"resistente": return "🪨"
		"fragil", "frágil": return "💔"
		"escuridao", "escuro", "darkness": return "🌑"
		"strengthened", "forte", "fortalecido": return "💪"
		"fast", "rapido", "rápido": return "⚡"
		"atento": return "👁️"
		"wounded", "ferido": return "🩹"
		"regen": return "💚"
		"blind", "cego": return "🙈"
		"invulneravel", "invulnerável", "invulnerable": return "✨"
		"marked", "marcado": return "🎯"
		_: return "◆"

func _update_status_icons(body: Node3D, actor: Dictionary, expanded: bool) -> void:
	if body == null or not is_instance_valid(body):
		return
	var root: Node3D = body.get_node_or_null("StatusIcons")
	if root == null:
		root = Node3D.new()
		root.name = "StatusIcons"
		root.position = Vector3(0, 2.05, 0)
		body.add_child(root)
	for c in root.get_children():
		c.queue_free()
	var statuses: Dictionary = actor.get("statuses", {})
	var keys: Array = []
	for sid in statuses.keys():
		var st: Dictionary = statuses[sid]
		if int(st.get("duration", 0)) <= 0 and int(st.get("stacks", 0)) <= 0:
			continue
		# Escuridão may have duration 99
		keys.append(str(sid))
	if keys.is_empty():
		return
	keys.sort()
	if camera != null:
		var cam_pos := camera.global_position
		var look := Vector3(cam_pos.x, root.global_position.y, cam_pos.z)
		if look.distance_to(root.global_position) > 0.05:
			root.look_at(look, Vector3.UP)
			root.rotate_object_local(Vector3.UP, PI)
	if not expanded:
		# Compact row of glyphs under HP
		var i := 0
		for sid in keys:
			if i >= 6:
				break
			var lab := Label3D.new()
			lab.text = _status_icon_glyph(sid)
			lab.font_size = 28
			lab.pixel_size = 0.0055
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.position = Vector3((-0.35 + 0.14 * float(i)), 0.0, 0.0)
			root.add_child(lab)
			i += 1
	else:
		# Vertical list: icon + name
		var row := 0
		for sid in keys:
			if row >= 8:
				break
			var st: Dictionary = statuses[sid]
			var stacks := int(st.get("stacks", 1))
			var line := "%s %s" % [_status_icon_glyph(sid), _status_label(sid)]
			if stacks > 1:
				line += " x%d" % stacks
			var lab := Label3D.new()
			lab.text = line
			lab.font_size = 22
			lab.pixel_size = 0.005
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.modulate = Color("ffe6b0")
			lab.position = Vector3(0.0, -0.16 * float(row), 0.0)
			lab.outline_size = 4
			lab.outline_modulate = Color(0, 0, 0, 0.85)
			root.add_child(lab)
			row += 1

func _portrait_status_lines(actor: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var statuses: Dictionary = actor.get("statuses", {})
	for sid in statuses.keys():
		var st: Dictionary = statuses[sid]
		if int(st.get("duration", 0)) <= 0 and int(st.get("stacks", 0)) <= 0:
			continue
		var stacks := int(st.get("stacks", 1))
		var line := "%s %s" % [_status_icon_glyph(str(sid)), _status_label(str(sid))]
		if stacks > 1:
			line += " x%d" % stacks
		out.append(line)
		if out.size() >= 6:
			break
	return out


func _show_character_sheet(hero_id: String) -> void:
	# Ficha: retrato, attrs, tipo, biografia e cartas (clique amplia + glossário).
	_clear_ui()
	if not Content.HEROES.has(hero_id):
		_show_team()
		return
	var hero: Dictionary = Content.HEROES[hero_id]
	var menu := _center_panel("FICHA · %s" % hero.get("name", hero_id))
	var panel := menu.get_parent() as PanelContainer
	panel.custom_minimum_size = Vector2(820, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	menu.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	row.add_child(left)
	var portrait_path := str(hero.get("portrait", hero.get("sprite", "")))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(portrait_path)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(220, 280)
		left.add_child(tex_rect)
	left.add_child(_label(str(hero.get("name", "")), 24, Color("f0c27a")))
	left.add_child(_label("Tipo %s · %s · %s" % [hero.get("type", "?"), hero.get("archetype_stat", hero.get("archetype", "?")), hero.get("species", "")], 15, Color("9aa6bf")))
	left.add_child(_label("Vida %d · Impacto %d · Poder %d · Armadura %d · Escudo %d" % [hero.get("hp", 0), hero.get("attack", 0), hero.get("power", 0), hero.get("armor", 0), hero.get("escudo", 0)], 15))
	var apr = hero.get("aprimoramento", hero.get("passive", ""))
	var apr_label: String = str(apr)
	if typeof(apr) == TYPE_DICTIONARY:
		apr_label = str(apr.get("name", apr.get("id", "")))
	left.add_child(_label("Aprimoramento: %s" % apr_label, 16, Color("6dffa3")))
	var grupos: Array = hero.get("grupos", [])
	if not grupos.is_empty():
		var grupo_bits: PackedStringArray = []
		for g in grupos:
			grupo_bits.append(str(g))
		left.add_child(_label("Grupos: %s" % ", ".join(grupo_bits), 15, Color("7eb6ff")))
	var bio := str(hero.get("biografia", ""))
	if bio == "" and Content.HERO_LORE.has(hero_id):
		bio = str(Content.HERO_LORE[hero_id].get("history", ""))
	var bio_lab := _label(bio if bio != "" else "(Sem biografia)", 14, Color("c9d1dd"))
	bio_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio_lab.custom_minimum_size = Vector2(240, 0)
	left.add_child(bio_lab)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("Manobras", 18, Color("f0c27a")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 420)
	right.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var sections := [
		["Iniciais", hero.get("iniciais", hero.get("cards", []))],
		["Evoluídas", hero.get("evoluidas", [])],
		["Melhoradas", hero.get("melhoradas", [])],
		["Desvantagem", [hero.get("desvantagem", "")] if str(hero.get("desvantagem", "")) != "" else []],
	]
	for sec in sections:
		var title: String = sec[0]
		var ids: Array = sec[1]
		if ids.is_empty(): continue
		list.add_child(_label(title, 16, Color("7eb6ff")))
		for cid in ids:
			var cdef: Dictionary = Content.CARDS.get(str(cid), {})
			if cdef.is_empty(): continue
			var btn := _button("%s · %s" % [cdef.get("name", cid), cdef.get("class", "")], _show_card_enlarge.bind(str(cid), hero_id), _card_description(cdef))
			list.add_child(btn)
	menu.add_child(_button("Voltar à equipe", _show_team))

func _show_card_enlarge(card_id: String, hero_id: String) -> void:
	_clear_ui()
	var definition: Dictionary = Content.CARDS.get(card_id, {})
	var menu := _center_panel(str(definition.get("name", card_id)))
	var panel := menu.get_parent() as PanelContainer
	panel.custom_minimum_size = Vector2(720, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	menu.add_child(row)
	var face = CardFace.new()
	face.custom_minimum_size = Vector2(240, 370)
	var fake_card := {"id": card_id, "owner": -1, "upgrade": 0}
	var fake_owner: Dictionary = Content.HEROES.get(hero_id, {"name": hero_id}).duplicate(true)
	if not fake_owner.has("hp"):
		fake_owner["hp"] = int(fake_owner.get("max_hp", 1))
	face.setup(_card_spec(fake_card, definition, fake_owner))
	row.add_child(face)
	var gloss := VBoxContainer.new()
	gloss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gloss)
	gloss.add_child(_label("Efeitos", 18, Color("f0c27a")))
	for line in _effect_glossary_lines(definition):
		var lab := _label("• " + line, 15, Color("d5deea"))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = 360
		gloss.add_child(lab)
	menu.add_child(_button("Voltar à ficha", _show_character_sheet.bind(hero_id)))

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
		var row_h := HBoxContainer.new()
		row_h.add_theme_constant_override("separation", 6)
		var button := _button(prefix + "%s · %s · %d Vida" % [hero["name"], identity["role"], hero["hp"]], _toggle_hero.bind(id), hint)
		button.custom_minimum_size = Vector2(520, 44)
		button.disabled = conflict
		if conflict:
			button.modulate = Color(0.7, 0.55, 0.55, 0.85)
		row_h.add_child(button)
		var ficha := _button("Ficha", _show_character_sheet.bind(id), "Abre a ficha do personagem")
		ficha.custom_minimum_size = Vector2(100, 44)
		row_h.add_child(ficha)
		list.add_child(row_h)
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

func _show_collection() -> void:
	_show_collection_screen()

func _ensure_owned_cards() -> void:
	owned_cards = CollectionRules.ensure_owned(Content.HEROES, Content.CARDS, owned_cards)

func _grant_owned_card(hero_id: String, card_id: String) -> void:
	owned_cards = CollectionRules.grant(hero_id, card_id, Content.HEROES, Content.CARDS, owned_cards)

func _combat_deck_for_hero(hero_id: String) -> Array:
	_ensure_owned_cards()
	return CollectionRules.combat_deck(hero_id, Content.HEROES, Content.CARDS, owned_cards)

func _build_equipped_from_owned() -> Dictionary:
	_ensure_owned_cards()
	return CollectionRules.build_team_decks(team, Content.HEROES, Content.CARDS, owned_cards)

func _show_collection_screen() -> void:
	_ensure_owned_cards()
	if not team.has(collection_hero): collection_hero = team[0]
	var hero: Dictionary = Content.HEROES[collection_hero]
	var selected_cards: Array = _combat_deck_for_hero(collection_hero)
	var pool: Array = hero.get("pool", hero["cards"])
	if not pool.has(collection_selected) and not selected_cards.is_empty():
		collection_selected = selected_cards[0]
	elif not pool.has(collection_selected):
		collection_selected = pool[0] if not pool.is_empty() else ""
	var menu := _center_panel("COLEÇÃO · %s · %d CARTAS NO DECK" % [hero["name"], selected_cards.size()])
	menu.add_child(_label("Sem editor de deck: todas as cartas possuídas entram no baralho. Melhoradas substituem a base. Baralho maior = menos reshuffles.", 15))
	var menu_panel := menu.get_parent() as PanelContainer
	menu_panel.custom_minimum_size.x = 1150
	var hero_bar := HBoxContainer.new()
	menu.add_child(hero_bar)
	for id in team:
		hero_bar.add_child(_button(("✓ " if id == collection_hero else "") + Content.HEROES[id]["name"], _select_collection_hero.bind(id)))
	var filter_bar := HBoxContainer.new()
	menu.add_child(filter_bar)
	for filter_name in ["TODAS", "IMPACTO", "PODER", "ESTADO", "POSTURA", "ALCANCE", "MELHORADAS"]:
		filter_bar.add_child(_button(("● " if collection_filter == filter_name else "") + filter_name.capitalize(), _set_collection_filter.bind(filter_name)))
	var type_bar := HBoxContainer.new()
	menu.add_child(type_bar)
	for filter_name in ["FÍSICO", "MÁGICO", "SUPORTE", "RARAS"]:
		type_bar.add_child(_button(("● " if collection_filter == filter_name else "") + filter_name.capitalize(), _set_collection_filter.bind(filter_name)))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	menu.add_child(columns)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size.x = 275
	columns.add_child(slots)
	slots.add_child(_label("NO DECK DE COMBATE (somente leitura)", 19, Color("d9bd85")))
	for position in range(selected_cards.size()):
		var card_id: String = selected_cards[position]
		var definition: Dictionary = Content.CARDS[card_id]
		var selected_prefix := "▶ " if collection_selected == card_id else ""
		var button := _button("%s%d · %s" % [selected_prefix, position + 1, definition["name"]], _choose_collection_card.bind(card_id), _card_description(definition))
		button.custom_minimum_size = Vector2(260, 48)
		slots.add_child(button)
	var catalogue := ScrollContainer.new()
	catalogue.custom_minimum_size = Vector2(360, maxf(210.0, get_viewport().get_visible_rect().size.y - 450.0))
	columns.add_child(catalogue)
	var available := VBoxContainer.new()
	catalogue.add_child(available)
	available.add_child(_label("POOL DO PERSONAGEM (posse cresce após missões)", 19, Color("d9bd85")))
	for entry in pool:
		var card_id: String = entry
		if not _matches_collection_filter(card_id, collection_hero): continue
		var definition: Dictionary = Content.CARDS[card_id]
		var key: String = str(collection_hero) + ":" + str(card_id)
		var level := int(improvements.get(key, {}).get("upgrade", 0))
		var cost := int(definition.get("cost", 0))
		var subtitle := "%s · %s" % [_card_scale_label(definition), "%d Iniciativa" % cost if cost > 0 else "+%d Iniciativa" % int(definition.get("gain", 0))]
		var button := _button(("▶ " if collection_selected == card_id else "") + definition["name"] + " +%d\n" % level + subtitle, _choose_collection_card.bind(card_id), _card_description(definition))
		button.custom_minimum_size = Vector2(330, 62)
		available.add_child(button)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 390
	columns.add_child(details)
	details.add_child(_label("DETALHES", 19, Color("d9bd85")))
	var shown: Dictionary = Content.CARDS[collection_selected]
	details.add_child(_label(shown["name"], 24, Color("f2dcad")))
	details.add_child(_label("%s · %s" % [_card_scale_label(shown), _card_type(shown)], 18))
	details.add_child(_label("Tipo do herói: %s" % hero["type"], 17))
	details.add_child(_label("Custo %d · Gera %d · Alcance %s" % [shown.get("cost", 0), shown.get("gain", 0), "longo" if shown.get("reach", false) else "curto"], 18))
	var detail_text := _label(_card_description(shown), 18)
	detail_text.custom_minimum_size = Vector2(380, 95)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(detail_text)
	var selected_key: String = str(collection_hero) + ":" + str(collection_selected)
	var changes: Dictionary = improvements.get(selected_key, {})
	var upgrade_level := int(changes.get("upgrade", 0))
	var upgrade_button := _button("Melhoria +%d · custo %d" % [upgrade_level, 3 if upgrade_level == 0 else 6], _upgrade_card.bind(selected_key))
	upgrade_button.disabled = upgrade_level >= 2 or essence < (3 if upgrade_level == 0 else 6)
	details.add_child(upgrade_button)
	var mod_button := _button("Modificação: %s · custo 4" % (changes.get("mod", "") if changes.get("mod", "") != "" else "nenhuma"), _cycle_mod.bind(selected_key))
	mod_button.disabled = essence < 4
	details.add_child(mod_button)
	details.add_child(_label("Não há montagem manual de deck. Melhoradas substituem a versão mais fraca automaticamente.", 16))
	if feedback != "": details.add_child(_label(feedback, 16, Color("e7a777")))
	menu.add_child(_button("Voltar", _show_menu))

func _select_collection_hero(hero_id: String) -> void:
	collection_hero = hero_id
	collection_selected = ""
	feedback = ""
	_show_collection_screen()

func _set_collection_filter(filter_name: String) -> void:
	collection_filter = filter_name
	_show_collection_screen()

func _matches_collection_filter(card_id: String, hero_id: String) -> bool:
	var card: Dictionary = Content.CARDS[card_id]
	match collection_filter:
		"IMPACTO": return _card_has_damage(card) and str(card.get("stat", "attack")) != "power"
		"PODER": return _card_has_damage(card) and str(card.get("stat", "")) == "power"
		"ESTADO": return not _card_has_damage(card)
		"POSTURA": return str(card.get("class", "")) == "POSTURA"
		"ALCANCE": return card.get("reach", false)
		"MELHORADAS": return int(improvements.get(hero_id + ":" + card_id, {}).get("upgrade", 0)) > 0
		"FÍSICO", "MÁGICO", "SUPORTE": return _card_type(card) == collection_filter
		"RARAS": return false
	return true

func _card_type(definition: Dictionary) -> String:
	for effect in definition.get("effects", []):
		if effect.get("kind", "") == "DAMAGE":
			return "MÁGICO" if effect.get("stat", "attack") == "power" else "FÍSICO"
	return "SUPORTE"

func _choose_collection_card(card_id: String) -> void:
	collection_selected = card_id
	feedback = "Coleção automática — todas as cartas possuídas entram no baralho."
	_show_collection_screen()

func _upgrade_card(key: String) -> void:
	var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
	var level := int(change.get("upgrade", 0))
	var cost := 3 if level == 0 else 6
	if level >= 2 or essence < cost: return
	essence -= cost
	change["upgrade"] = level + 1
	improvements[key] = change
	_save_config()
	_show_collection_screen()

func _cycle_mod(key: String) -> void:
	if essence < 4: return
	var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
	var options := ["", "damage", "impulse", "redraw"]
	var current := options.find(change.get("mod", ""))
	change["mod"] = options[(current + 1) % options.size()]
	essence -= 4
	improvements[key] = change
	_save_config()
	_show_collection_screen()

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
	if session_report != null:
		session_report.log_battle("start_mission", {"mission": mission_id, "team": team.duplicate()})
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
	_ensure_owned_cards()
	equipped = _build_equipped_from_owned()
	_begin_battle_session()
	_build_arena(_arena_theme_for_mission(mission_id))
	# Equipes ent_: usa deploy de entidades (Iniciais+Desvantagem+Combos + cartas possuídas).
	var all_entities := team.all(func(id): return str(id).begins_with("ent_"))
	if all_entities:
		pack_mode = "entities"
		var ids: Array[String] = []
		for id in team: ids.append(str(id))
		if not packs.entities.deploy(battle, mission_id, ids, equipped, 0):
			battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	else:
		battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	_apply_accessibility()
	_ensure_bgm_for("battle")
	_log_mission_deck_snapshot()
	_render_battle()


func _log_mission_deck_snapshot() -> void:
	if session_report == null or battle == null:
		return
	var deck_by_owner: Dictionary = {}
	for c in battle.deck:
		var oid := int(c.get("owner", -1))
		var arr: Array = deck_by_owner.get(oid, [])
		arr.append(str(c.get("id", "")))
		deck_by_owner[oid] = arr
	session_report.log_battle("deck_snapshot", {
		"mission": mission_id,
		"team": team.duplicate(),
		"equipped": equipped.duplicate(true),
		"deck_by_owner": deck_by_owner,
		"deck_total": battle.deck.size(),
		"hand_total": battle.hand.size(),
	})
	session_report.snapshot_hand("ALLY", battle.hand, "opening")
	session_report.snapshot_actors(battle.actors, "mission_start")
	session_report.snapshot_piles("ALLY", battle.deck.size(), battle.discard.size(), battle.exhausted.size(), battle.hand.size(), "mission_start")

func _begin_battle_session() -> void:
	# IDs de atores e cartas reiniciam em cada missão; descarte os nós ligados à
	# sessão anterior para não reutilizar texturas de outro personagem.
	_teardown_title_screen()
	_clear_combat_visuals()
	seen_hand.clear()
	selected_card = -1
	selected_action = ""
	chain_targets.clear()
	event_history.clear()
	feedback = ""
	inspect_open = false
	inspected_card = -1
	card_confirmed = false
	pending_target_id = -1
	battle_menu_open = false
	free_camera = false
	hover_retarget_freeze_until = 0
	battle = Battle.new()
	battle.event.connect(_on_event)
	battle.visual.connect(_on_visual)
	battle.changed.connect(_render_battle)
	battle.finished.connect(_on_finished)
	battle.report_cb = func(category: String, action: String, detail: Dictionary = {}) -> void:
		if session_report != null:
			session_report.emit_structured(category, action, detail)



func _card_def(card_id: String) -> Dictionary:
	return packs.definition(str(card_id))

func _card_def_for(card: Dictionary) -> Dictionary:
	var def: Dictionary = packs.definition(str(card.get("id", "")))
	if def.is_empty() or battle == null:
		return def
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", -1)))
	if owner.is_empty() or not bool(owner.get("transformed", false)):
		return def
	if not def.has("naomi_actions"):
		return def
	var out: Dictionary = def.duplicate(true)
	out["actions"] = def["naomi_actions"].duplicate(true)
	if def.has("naomi_name"):
		out["name"] = str(def["naomi_name"])
	return out

func _on_event(message: String) -> void:
	# Log de combate vai só para a janela de log (esquerda) — nada flutuando sobre as cartas.
	event_history.append(message)
	if event_history.size() > 24:
		event_history.pop_front()
	if session_report != null:
		session_report.log_battle("log", {"text": message})

func _on_visual(kind: String, source_id: int, target_id: int, amount: int) -> void:
	if session_report != null and kind in ["cast", "hit", "heal", "death", "status", "block", "guard", "immune", "resist", "transform", "ini_gain", "draw", "redraw", "move", "counter"]:
		session_report.log_battle("visual", {"kind": kind, "source": source_id, "target": target_id, "amount": amount})
	if presentation != null: presentation.show_action(kind, source_id, target_id, amount)
	if kind == "transform":
		cinematic_actor_id = source_id
		cinematic_zoom = 1.9
		cinematic_until_msec = Time.get_ticks_msec() + int(1400.0 / maxf(animation_speed, 0.25))
		_show_actor_portrait(source_id, true)
		if battle_view_mode == "lateral":
			_lateral_focus_actor(source_id, cinematic_zoom)
	elif kind == "ini_gain":
		cinematic_actor_id = target_id
		cinematic_zoom = 1.55
		cinematic_until_msec = Time.get_ticks_msec() + int(700.0 / maxf(animation_speed, 0.25))
		_show_actor_portrait(target_id, true)
		if battle_view_mode == "lateral":
			_lateral_focus_actor(target_id, cinematic_zoom)
	elif kind == "climate":
		var climate_ids := ["none", "rain", "snow", "leaves", "fog", "heat", "night"]
		var mode: String = climate_ids[clampi(amount, 0, climate_ids.size() - 1)]
		_set_weather(mode)
	elif kind in ["cast", "hit", "heal", "death", "status", "block", "guard"]:
		_show_actor_portrait(source_id, true)
		if target_id != source_id: _show_actor_portrait(target_id, true)

func _on_finished(won: bool) -> void:
	# Restaura clima de configuração (clima de combate é temporário).
	var cfg := ConfigFile.new()
	if cfg.load("user://hotn3.cfg") == OK:
		var wm := str(cfg.get_value("settings", "weather_mode", "none"))
		if wm in ["none", "rain", "snow", "leaves", "fog", "heat", "night"]:
			_set_weather(wm)
	if session_report != null:
		session_report.log_battle("finished", {"won": won, "mission": mission_id, "turn": int(battle.turn) if battle != null else -1})
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
	var result: Dictionary = CampaignRules.award_victory(mission_id, stars, best_stars, essence)
	best_stars = result["best_stars"]
	essence = int(result["essence"])
	return int(result["reward"])

func _mission_stars() -> int:
	return CampaignRules.mission_stars(battle, mission_id, Content.CAMPAIGN, int(Content.RULES["team_size"]))

func _render_battle() -> void:
	if battle == null or battle.phase == "FINISHED": return
	if presentation != null:
		presentation.drive_camera = true
	_clear_ui()
	_clear_hand_visuals()
	hero_hud = null
	economy_hud = null
	recompra_ring = null
	var viewport_size := get_viewport().get_visible_rect().size
	# Top mission chrome + centered phase prompt (small text box)
	var header := VBoxContainer.new()
	hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 34.0
	header.offset_top = 14.0
	header.offset_right = -34.0
	header.offset_bottom = 46.0
	header.add_child(_label("%s  ·  RODADA %d" % [battle.mission["name"], battle.turn], 18, Color("e9c891")))
	_chrome(Vector2(12, 8), Vector2(viewport_size.x - 24, 48), "res://assets/ui/header.png")
	# Caixa de fase central (também no fim do render para ficar acima do chrome).
	var extra := ""
	if battle.mission["objective"] == "PROTECT":
		extra += "SENTINELA %d Vida" % battle.protect_hp
	var next_turn: Array = battle.mission.get("reinforcements", {}).get(battle.turn + 1, [])
	if not next_turn.is_empty():
		extra += ("  ·  " if extra != "" else "") + "REFORÇOS EM 1 TURNO"
	# Left log window — only place for game log text
	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LeftLogPanel"
	var side_panel_height := maxf(120.0, viewport_size.y * 0.42)
	left_scroll.position = Vector2(26, 120)
	left_scroll.size = Vector2(232, side_panel_height - 38.0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	left_scroll.add_child(left)
	left.add_child(_label("LOG", 18, Color("e9c891")))
	var log_slice: Array = event_history.slice(max(0, event_history.size() - 12))
	for entry in log_slice:
		var line := _label(str(entry), 13, Color("d5deea"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 218
		left.add_child(line)
	if extra != "":
		left.add_child(_label(extra, 13, Color("e9c891")))
	_chrome(Vector2(12, 90), Vector2(260, side_panel_height), "res://assets/ui/panel.png")
	# Right tools: objective + environment only
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightPanel"
	var right_panel_height := maxf(100.0, viewport_size.y * 0.30)
	right_scroll.position = Vector2(viewport_size.x - 266, 120)
	right_scroll.size = Vector2(232, right_panel_height - 38.0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 220
	right_scroll.add_child(right)
	var objective := _label("OBJETIVO: %s" % Content.CAMPAIGN[mission_id]["goal"], 15, Color("e9c891"))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size.x = 218
	right.add_child(objective)
	right.add_child(_label("CENÁRIO", 18))
	for index in range(battle.mission.get("environment", []).size()):
		var object: Dictionary = battle.mission["environment"][index]
		var env_btn := _button("%s · %d Ini" % [object["name"], object["cost"]], func(): battle.use_environment(index))
		env_btn.custom_minimum_size = Vector2(218, 36)
		right.add_child(env_btn)
	_chrome(Vector2(viewport_size.x - 280, 90), Vector2(260, right_panel_height), "res://assets/ui/panel.png")
	# 3D hand arc (kept)
	for index in range(battle.hand.size()):
		var card: Dictionary = battle.hand[index]
		var definition: Dictionary = _card_def_for(card)
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
	hover_hint = _label("", 14, Color("c9d1dd"))
	hover_hint.visible = false
	hud.add_child(hover_hint)
	if selected_card >= 0 and selected_card < battle.hand.size() and battle.phase == "PLAYER" and not card_confirmed and not inspect_open:
		_add_selected_card_overlay(selected_card, viewport_size)
		_add_selected_card_actions(selected_card, viewport_size)
	if recover_pick_active and not battle.pending_recover.is_empty():
		_build_recover_pick_panel(viewport_size)
	_render_actors()
	if inspect_open and inspected_card >= 0 and inspected_card < battle.hand.size() and battle.phase == "PLAYER":
		_add_inspect_overlay(inspected_card, viewport_size)
	_add_phase_prompt(viewport_size)
	_add_battle_menu_button(viewport_size)
	if pending_target_id >= 0 and card_confirmed and battle.phase == "PLAYER":
		_apply_target_preview(pending_target_id)
		_add_pending_target_actions(viewport_size)
	if battle_menu_open and battle.phase == "PLAYER":
		_add_battle_menu_overlay(viewport_size)
	_apply_weather_fx()
	visible_uids.clear()
	for visible_card in battle.hand:
		visible_uids[visible_card["uid"]] = true

func _build_hero_hud(viewport_size: Vector2) -> void:
	hero_hud = Control.new()
	hero_hud.name = "HeroHud"
	hero_hud.position = Vector2(18, viewport_size.y - 196)
	hero_hud.size = Vector2(420, 168)
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
	var type_lbl := _label("%s %s" % [_type_icon(str(actor.get("type", ""))), str(actor.get("type", ""))], 14, _type_color(str(actor.get("type", ""))))
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
	var hp_lbl := _label("%s %d/%d" % [_type_icon(str(actor.get("type", ""))), hp, max_hp], 16, Color("f4f1ea"))
	hp_lbl.position = Vector2(350, 72)
	hero_hud.add_child(hp_lbl)
	var defend := int(actor.get("block", 0)) + int(actor.get("shield", 0))
	var bar_hp := 0
	if battle != null and battle.has_method("_barrier_hp"):
		bar_hp = int(battle._barrier_hp(actor))
	elif actor.get("statuses", {}).has("barrier"):
		var bs: Dictionary = actor["statuses"]["barrier"]
		bar_hp = int(bs.get("barrier_hp", bs.get("stacks", 0)))
	var state_y := 100.0
	if defend > 0 or bar_hp > 0:
		var def_txt := "DEF +%d" % defend if defend > 0 else ""
		if bar_hp > 0:
			def_txt = (def_txt + " · " if def_txt != "" else "") + "Barreira %d" % bar_hp
		var def_lbl := _label(def_txt, 14, Color("8fd6ff"))
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
	var type_lbl := _label("%s %s" % [_type_icon(str(actor.get("type", ""))), str(actor.get("type", ""))], 14, _type_color(str(actor.get("type", ""))))
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
	var hp_lbl := _label("%s %d/%d" % [_type_icon(str(actor.get("type", ""))), hp, max_hp], 16, Color("f4f1ea"))
	hp_lbl.position = Vector2(340, 72)
	hero_hud.add_child(hp_lbl)
	var defend := int(actor.get("block", 0)) + int(actor.get("shield", 0))
	var bar_hp := 0
	if battle != null and battle.has_method("_barrier_hp"):
		bar_hp = int(battle._barrier_hp(actor))
	elif actor.get("statuses", {}).has("barrier"):
		var bs: Dictionary = actor["statuses"]["barrier"]
		bar_hp = int(bs.get("barrier_hp", bs.get("stacks", 0)))
	var state_y := 100.0
	if defend > 0 or bar_hp > 0:
		var def_txt := "DEF +%d" % defend if defend > 0 else ""
		if bar_hp > 0:
			def_txt = (def_txt + " · " if def_txt != "" else "") + "Barreira %d" % bar_hp
		var def_lbl := _label(def_txt, 14, Color("8fd6ff"))
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
	economy_hud.position = Vector2(viewport_size.x - 310, viewport_size.y - 316)
	economy_hud.size = Vector2(290, 308)
	economy_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(economy_hud)
	_chrome(economy_hud.position, Vector2(290, 308), "res://assets/ui/panel.png")
	var plays: int = battle.card_plays
	var redraws_left: int = battle.redraws
	var moves_left: int = battle.moves
	var ini_now: int = battle.impulse
	var ini_max: int = int(battle.rules["impulse_max"])
	var y := 14.0
	# Iniciativa: barra segmentada em 10 partes
	var ini_lbl := _label("INICIATIVA %d/%d" % [ini_now, ini_max], 15, Color("f4f1ea"))
	ini_lbl.position = Vector2(16, y)
	ini_lbl.size = Vector2(250, 18)
	economy_hud.add_child(ini_lbl)
	y += 20.0
	var seg_n := 10
	var seg_w := 200.0
	var gap := 2.0
	var cell := (seg_w - gap * float(seg_n - 1)) / float(seg_n)
	var filled := int(round(clampf(float(ini_now) / float(maxi(1, ini_max)), 0.0, 1.0) * float(seg_n)))
	for i in range(seg_n):
		var cell_r := ColorRect.new()
		cell_r.position = Vector2(16.0 + float(i) * (cell + gap), y)
		cell_r.size = Vector2(cell, 10)
		cell_r.color = Color("e9c891") if i < filled else Color(0.08, 0.1, 0.14, 0.9)
		economy_hud.add_child(cell_r)
	y += 18.0
	y = _economy_icon_row(y, "Ações:", plays, int(battle.rules["card_plays"]), Color("6eb6ff"), "⚔")
	y = _economy_icon_row(y, "Recompras:", redraws_left, int(battle.rules["redraws"]), Color("7ad0ff"), "↺")
	y = _economy_icon_row(y, "Movimentos:", moves_left, int(battle.rules["moves"]), Color("9dffb0"), "⇢")
	var move_btn := _button("MOVER (%d)" % moves_left, func(): _start_move_action())
	move_btn.disabled = battle.phase != "PLAYER" or enemy_presenting or (moves_left <= 0 and not _any_ally_has_momentum())
	move_btn.position = Vector2(16, 154)
	move_btn.custom_minimum_size = Vector2(258, 40)
	if selected_action == "move":
		move_btn.modulate = Color("6eb6ff")
	economy_hud.add_child(move_btn)
	var vista_label := "Lateral" if battle_view_mode == "lateral" else "Normal"
	var view_btn := _button("Vista: %s" % vista_label, _toggle_battle_view)
	view_btn.position = Vector2(16, 202)
	view_btn.custom_minimum_size = Vector2(258, 36)
	view_btn.tooltip_text = "Alterna vista Normal (atual) e Lateral (aliados à esquerda)."
	economy_hud.add_child(view_btn)
	var instant_blocks: bool = battle != null and battle.has_method("hand_has_playable_instantaneo") and battle.hand_has_playable_instantaneo("ALLY")
	var end_btn := _button("ENCERRAR TURNO", func():
		if battle != null and battle.has_method("hand_has_playable_instantaneo") and battle.hand_has_playable_instantaneo("ALLY"):
			feedback = "Instantâneo jogável na mão — jogue-o antes de encerrar."
			_render_battle()
			return
		_present_enemy_turn()
	)
	# Não desabilita por Instantâneo: clique mostra toast curto (sem modal). Tooltip explica.
	end_btn.disabled = battle.phase != "PLAYER" or enemy_presenting or recover_pick_active
	if instant_blocks:
		end_btn.tooltip_text = "Há Instantâneo jogável: jogue-o antes de outras cartas ou de encerrar."
	else:
		end_btn.tooltip_text = "Encerrar o turno do jogador."
	end_btn.position = Vector2(16, 246)
	end_btn.custom_minimum_size = Vector2(258, 40)
	economy_hud.add_child(end_btn)
	
func _economy_icon_row(y: float, title: String, left: int, maximum: int, color: Color, glyph: String) -> float:
	var lbl := _label(title, 14, Color("f4f1ea"))
	lbl.position = Vector2(16, y)
	lbl.size = Vector2(110, 18)
	economy_hud.add_child(lbl)
	var max_v := maxi(1, maximum)
	var x := 120.0
	for i in range(max_v):
		var icon := Label.new()
		icon.text = glyph
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.position = Vector2(x, y - 2)
		icon.size = Vector2(22, 22)
		icon.add_theme_font_size_override("font_size", 16)
		icon.add_theme_color_override("font_color", color)
		# Gastos: esconde/esmaece ícones da direita para a esquerda
		var spent := i >= left
		icon.modulate = Color(1, 1, 1, 0.22) if spent else Color.WHITE
		icon.visible = true
		economy_hud.add_child(icon)
		x += 24.0
	return y + 26.0

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
	inspect_open = false
	selected_card = -1
	chain_targets.clear()
	_render_battle()

func _add_actor_button(parent: VBoxContainer, actor: Dictionary) -> void:
	var text_value := "%s [%s] %d/%d Vida +%d" % [actor["name"], "F" if actor["row"] == "front" else "T", actor["hp"], actor["max_hp"], actor["block"] + actor["shield"]]
	var line := _label(text_value, 16)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(line)

func _select_card(index: int) -> void:
	if sound != null: sound.cue("select", "UI")
	if session_report != null and battle != null and index >= 0 and index < battle.hand.size():
		var c: Dictionary = battle.hand[index]
		session_report.log_card("select", {"index": index, "id": str(c.get("id", "")), "owner": int(c.get("owner", -1))})
	if selected_action == "redraw":
		selected_action = ""
		_animate_card_depart(index)
		if session_report != null:
			session_report.log_card("redraw", {"index": index})
		packs.redraw_card(battle, pack_mode, index)
		return
	selected_action = ""
	if inspect_open:
		if inspected_card == index or selected_card == index:
			_confirm_selected_card(index)
			return
		_close_inspect_keep_selection()
	if selected_card == index and card_confirmed:
		_render_battle()
		return
	if selected_card == index and not card_confirmed:
		_confirm_selected_card(index)
		return
	var require_msg := _card_select_block_reason(index)
	if require_msg != "":
		_show_block_popup(require_msg)
		return
	selected_card = index
	inspected_card = -1
	inspect_open = false
	card_confirmed = false
	chain_targets.clear()
	damage_preview_by_actor.clear()
	if index >= 0 and index < battle.hand.size():
		_show_actor_portrait(int(battle.hand[index].get("owner", -1)), true)
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
	var definition: Dictionary = _card_def_for(battle.hand[selected_card])
	if definition.get("target", "") == "CHAIN":
		chain_targets.append(actor_id)
		if chain_targets.size() < int(definition.get("chain", 1)):
			feedback = "Escolha o próximo acerto (%d/%d)." % [chain_targets.size(), definition["chain"]]
			_render_battle()
			return
	var card_id: String = str(battle.hand[selected_card].get("id", ""))
	var caster_id: int = int(battle.hand[selected_card].get("owner", -1))
	var successful: bool = false
	if session_report != null:
		session_report.log_card("target_confirm", {"card": card_id, "target": actor_id, "chain": chain_targets.duplicate()})
	if packs.is_pack_card(card_id) or pack_mode != "default":
		_animate_card_depart(selected_card)
		successful = packs.play_card(battle, pack_mode, selected_card, actor_id, chain_targets)
	else:
		var preview: Dictionary = battle.preview(selected_card, actor_id, chain_targets)
		if preview.is_empty():
			feedback = "Alvo indisponível para esta carta."
			if session_report != null:
				session_report.log_card("target_blocked", {"card": card_id, "target": actor_id, "reason": "preview_empty"})
			chain_targets.clear()
			_render_battle()
			return
		if preview.get("playable", false): _animate_card_depart(selected_card)
		successful = battle.play(selected_card, actor_id, chain_targets)
	chain_targets.clear()
	pending_target_id = -1
	if session_report != null:
		session_report.log_card("play_result", {"card": card_id, "target": actor_id, "ok": successful})
	if successful:
		if presentation != null:
			presentation.play_card_fx(definition, caster_id, actor_id)
		selected_card = -1
		card_confirmed = false
		inspected_card = -1
		inspect_open = false
		selected_action = ""
		portrait_sticky_until = 0
		_hide_idle_portraits()
		_after_card_resolved()
	else:
		var why := _card_unusable_reason(selected_card, actor_id)
		if why == "":
			why = "Sem ação, Iniciativa, alcance ou alvo válido."
		_show_block_popup(why)
		_render_battle()

func _render_actors() -> void:
	unit_sprites.clear()
	var present := {}
	var allies: Array = battle.units_on_field("ALLY")
	var enemies: Array = battle.units_on_field("ENEMY")
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
			var location := _actor_world_pos(side, row, row_index, row_count)
			var expected_sprite := _sensitive_path(str(actor.get("sprite", "")), "sprite")
			if actor_nodes.has(id):
				var existing: Node3D = actor_nodes[id]
				if str(existing.get_meta("sprite_resource", "")) != expected_sprite:
					if presentation != null:
						presentation.forget_actor(id)
					actor_nodes.erase(id)
					if is_instance_valid(existing):
						units.remove_child(existing)
						existing.queue_free()
			if not actor_nodes.has(id):
				actor_nodes[id] = _create_actor_visual(actor)
				actor_nodes[id].position = location
			else:
				var body: Node3D = actor_nodes[id]
				if body.position.distance_to(location) > 0.01:
					create_tween().tween_property(body, "position", location, 0.3 / animation_speed)
			var avatar: Sprite3D = actor_nodes[id].get_node_or_null("Avatar")
			if avatar != null:
				avatar.set_meta("actor_id", id)
				unit_sprites.append(avatar)
				presentation.bind_actor(id, avatar, location)
			var nameplate: Label3D = actor_nodes[id].get_node("Nameplate")
			nameplate.text = "%s %d/%d" % [_type_icon(str(actor.get("type", ""))), actor["hp"], actor["max_hp"]]
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

func _actor_world_pos(side: String, row: String, row_index: int, row_count: int) -> Vector3:
	# Espaçamento dentro da fileira (mesmo índice relativo).
	var lane := (row_index - (row_count - 1) / 2.0) * 2.2
	if battle_view_mode == "lateral":
		# Esquerda → direita: retaguarda aliada → frente aliada → frente inimiga → retaguarda inimiga.
		var depth_x: float
		if side == "ALLY":
			depth_x = -4.35 if row == "back" else -1.65
		else:
			depth_x = 1.65 if row == "front" else 4.35
		return Vector3(depth_x, 0.0, lane)
	var x := lane
	var z := (3.15 if row == "back" else 1.55) * (1 if side == "ALLY" else -1)
	return Vector3(x, 0.0, z)

func _create_actor_visual(actor: Dictionary) -> Node3D:
	var body := Node3D.new()
	body.set_meta("sprite_resource", _sensitive_path(str(actor.get("sprite", "")), "sprite"))
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
	var sprite_res := _sensitive_path(str(actor.get("sprite", "")), "sprite")
	if ResourceLoader.exists(sprite_res):
		var sheet: Texture2D = load(sprite_res)
		var columns := 1
		var rows := 1
		var region := Rect2(Vector2.ZERO, sheet.get_size())
		var sheet_path := sprite_res
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
		var spr_scale := float(actor.get("sprite_scale", actor.get("scale_factor", 1.0)))
		if spr_scale <= 0.0:
			spr_scale = 1.0
		sprite.set_meta("sprite_scale", spr_scale)
		# Multiplica a transformação base existente (pixel_size / animações), nos dois eixos.
		sprite.scale = Vector3(spr_scale, spr_scale, 1.0)
		# Inimigos olham para o jogador (espelhados horizontalmente).
		sprite.flip_h = str(actor.get("side", "")) == "ENEMY"
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
	var forecast := float(damage_preview_by_actor.get(int(actor.get("id", -1)), 0))
	var lost_ratio := clampf(forecast / max_hp, 0.0, ratio)
	var remain_ratio := clampf(ratio - lost_ratio, 0.0, 1.0)
	var box: BoxMesh = fill.mesh
	box.size = Vector3(0.88 * remain_ratio, 0.045, 0.025)
	fill.position.x = -0.44 + 0.44 * remain_ratio
	var tint := Color(0.55, 1.0, 0.75) if remain_ratio > 0.45 else (Color(1.0, 0.85, 0.35) if remain_ratio > 0.2 else Color(1.0, 0.4, 0.4))
	var mat: StandardMaterial3D = fill.material_override
	if mat != null:
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = 5.5
	# Prévia de dano (porção vermelha)
	var forecast_mesh: MeshInstance3D = hp_root.get_node_or_null("HpForecast")
	if lost_ratio > 0.001:
		if forecast_mesh == null:
			forecast_mesh = MeshInstance3D.new()
			forecast_mesh.name = "HpForecast"
			var fbox := BoxMesh.new()
			forecast_mesh.mesh = fbox
			var fmat := _material(Color(1.0, 0.22, 0.28), true)
			fmat.emission_enabled = true
			fmat.emission = Color(1.0, 0.25, 0.3)
			fmat.emission_energy_multiplier = 6.0
			forecast_mesh.material_override = fmat
			hp_root.add_child(forecast_mesh)
		var fbox2: BoxMesh = forecast_mesh.mesh
		fbox2.size = Vector3(maxf(0.06, 0.88 * lost_ratio), 0.07, 0.04)
		# Coloca a faixa vermelha imediatamente à direita do HP restante
		forecast_mesh.position = Vector3(-0.44 + 0.88 * remain_ratio + 0.44 * lost_ratio, fill.position.y, fill.position.z + 0.002)
		var fmat2: StandardMaterial3D = forecast_mesh.material_override
		if fmat2 != null:
			fmat2.albedo_color = Color(1.0, 0.18, 0.22)
			fmat2.emission = Color(1.0, 0.35, 0.25)
			fmat2.emission_energy_multiplier = 8.5
		forecast_mesh.visible = true
	elif forecast_mesh != null:
		forecast_mesh.visible = false
	var hp_glow: MeshInstance3D = hp_root.get_node_or_null("HpGlow")
	if hp_glow != null and hp_glow.mesh != null:
		var gbox: BoxMesh = hp_glow.mesh
		gbox.size = Vector3(maxf(0.08, 0.96 * ratio), 0.10, 0.04)
		hp_glow.position.x = -0.48 * (1.0 - ratio)
		var gmat: StandardMaterial3D = hp_glow.material_override
		if gmat != null:
			gmat.albedo_color = Color(tint.r, tint.g, tint.b, 0.45)
			gmat.emission = tint
	# Sempre de frente para a câmera (vista lateral +Z deixava a barra de lado).
	if camera != null:
		var cam_pos := camera.global_position
		var look := Vector3(cam_pos.x, hp_root.global_position.y, cam_pos.z)
		if look.distance_to(hp_root.global_position) > 0.05:
			hp_root.look_at(look, Vector3.UP)
			hp_root.rotate_object_local(Vector3.UP, PI)
	var aid := int(actor.get("id", -1))
	var expand := aid == status_hover_actor or aid == hovered_actor or aid == pending_target_id
	_update_status_icons(body, actor, expand)

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
	plane.size = Vector2(0.45, 0.70)
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
		# Compra/recompra: entra da direita (deck) no arco da mão.
		mesh.position = slot + Vector3(3.15, 0.22, 0.12)
		mesh.rotation = spin + Vector3(0.12, -0.28, 0.72)
		mesh.scale = Vector3(0.82, 0.82, 0.82)
		mesh.set_meta("dealing", true)
	cards_3d.add_child(mesh)
	if int(owner.get("hp", 0)) <= 0:
		var dead_mat: ShaderMaterial = mesh.material_override
		if dead_mat != null:
			dead_mat.set_shader_parameter("modulate_color", Color(0.55, 0.55, 0.58, 0.75))
	elif _card_select_block_reason(index) != "":
		var lock_mat: ShaderMaterial = mesh.material_override
		if lock_mat != null:
			lock_mat.set_shader_parameter("modulate_color", Color(0.55, 0.52, 0.58, 0.55))
	if entering and not reduce_motion:
		var dur := 0.28 / maxf(animation_speed, 0.25)
		var arrive := create_tween()
		arrive.set_ease(Tween.EASE_OUT)
		arrive.set_trans(Tween.TRANS_CUBIC)
		arrive.set_parallel(true)
		arrive.tween_property(mesh, "position", slot, dur)
		arrive.tween_property(mesh, "rotation", spin, dur)
		arrive.tween_property(mesh, "scale", Vector3.ONE, dur)
		arrive.chain().tween_callback(func() -> void:
			if is_instance_valid(mesh) and mesh.has_meta("dealing"):
				mesh.remove_meta("dealing")
		)
	elif entering:
		if mesh.has_meta("dealing"):
			mesh.remove_meta("dealing")
	seen_hand[uid] = true
	var area := Area3D.new()
	area.set_meta("card_index", index)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.69, 0.12)
	shape.shape = box
	area.add_child(shape)
	mesh.add_child(area)
	# Electric / soft glow outline via second slightly larger quad
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.name = "HoverGlow"
	var glow_plane := QuadMesh.new()
	glow_plane.size = Vector2(0.51, 0.78)
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
	if original.material_override != null:
		ghost.material_override = original.material_override.duplicate()
	else:
		ghost.material_override = original.material_override
	ghost.transform = original.global_transform
	# Sai para a esquerda (fora da mão); parent câmera para acompanhar o HUD 3D.
	if camera != null:
		var inv := camera.global_transform.affine_inverse()
		camera.add_child(ghost)
		ghost.transform = inv * original.global_transform
	else:
		add_child(ghost)
	var dur := 0.26 / maxf(animation_speed, 0.25)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", ghost.position + Vector3(-3.55, 0.28, -0.18), dur)
	tween.tween_property(ghost, "rotation", ghost.rotation + Vector3(0.18, 0.35, -1.05), dur)
	tween.tween_property(ghost, "scale", ghost.scale * 0.72, dur)
	var gmat: ShaderMaterial = ghost.material_override as ShaderMaterial
	if gmat != null:
		var from_c := Color.WHITE
		var raw = gmat.get_shader_parameter("modulate_color")
		if raw is Color:
			from_c = raw
		tween.tween_method(func(a: float) -> void:
			if is_instance_valid(ghost) and ghost.material_override != null:
				(ghost.material_override as ShaderMaterial).set_shader_parameter("modulate_color", Color(from_c.r, from_c.g, from_c.b, a))
		, from_c.a, 0.0, dur)
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
	if _selected_targets_dead_allies():
		var card: Dictionary = battle.hand[selected_card]
		var owner: Dictionary = battle.actor_by_id(int(card.get("owner", -1)))
		var side := str(owner.get("side", "ALLY"))
		for actor in battle.dead_on_side(side):
			ids.append(int(actor["id"]))
		return ids
	for actor in battle.living("ALLY") + battle.living("ENEMY"):
		ids.append(actor["id"])
	return ids

func _selected_targets_dead_allies() -> bool:
	if battle == null or not card_confirmed:
		return false
	if selected_card < 0 or selected_card >= battle.hand.size():
		return false
	var definition: Dictionary = _card_def(str(battle.hand[selected_card].get("id", "")))
	return str(definition.get("target", "")) == "DEAD_ALLY"


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

func _lateral_focus_actor(actor_id: int, zoom_amount: float = 1.65) -> void:
	if presentation == null or battle_view_mode != "lateral":
		return
	presentation.orbit = 0.0
	# Zoom no mundo de batalha (stage+units). Câmera/mão 3D ficam estáticas.
	if actor_id >= 0 and actor_nodes.has(actor_id):
		var body: Node3D = actor_nodes[actor_id]
		if is_instance_valid(body):
			presentation.focus_target = body.position
			presentation.zoom = zoom_amount
			return
	presentation.focus_target = Vector3.ZERO
	presentation.zoom = 1.0

func _set_orbit(target: float) -> void:
	if presentation == null: return
	# Vista lateral: não gira a câmera 180° na fase inimiga.
	if battle_view_mode == "lateral":
		presentation.orbit = 0.0
		return
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
	var cy := -0.62 - radius
	var pos := Vector3(sin(ang) * radius, cy + cos(ang) * radius, -2.62)
	var rot := Vector3(-0.05, 0.0, -ang)
	return {"position": pos, "rotation": rot}

func _type_icon(kind: String) -> String:
	match str(kind).to_upper():
		"BRUTO": return "💥"
		"TECNICO": return "⚔️"
		"MENTAL": return "👁️"
		"PSICOLOGICO": return "🎭"
		"PROJETIVO": return "⚡"
		"QUIMICO": return "🧪"
		_: return "◆"

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
	var key := str(status_id)
	var labels := {
		"protecao": "Proteção",
		"protection": "Proteção",
		"barrier": "Barreira",
		"barreira": "Barreira",
		"resistente": "Resistente",
		"fragil": "Frágil",
		"invulnerable": "Invulnerável",
		"invulneravel": "Invulnerável",
		"stun": "Atordoado",
		"dazed": "Atordoado",
		"resist": "Proteção",
		"protected": "Proteção",
		"protecting": "Proteção",
		"bleed": "Sangrando",
		"sangrando": "Sangrando",
		"sangramento": "Sangrando",
		"burn": "Queimadura",
		"weak": "Fraco",
		"vulnerable": "Vulnerável",
		"marked": "Marcado",
		"conceal": "Oculto",
		"counter": "Contra-ataque",
		"vitima": "Tanque",
		"tanque": "Tanque",
		"furioso": "Furioso",
		"curador": "Curador",
		"empatico": "Empático",
		"atirador": "Atirador",
		"drenador": "Drenador",
		"controlador": "Controlador",
		"garra": "Garra",
		"vingador": "Vingador",
		"executor": "Executor",
		"indomavel": "Indomável",
		"sobrevivente": "Sobrevivente",
		"intocavel": "Intocável",
		"preparo": "Preparo",
		"strengthened": "Fortalecido",
		"forte": "Forte",
		"fortalecido": "Fortalecido",
		"fast": "Rápido",
		"rapido": "Rápido",
		"rápido": "Rápido",
		"slow": "Lento",
		"bind": "Prisão",
		"bound": "Preso",
		"poison": "Veneno",
		"block": "Bloqueio",
		"shield": "Escudo",
		"escuridao": "Escuridão",
		"atento": "Atento",
		"wounded": "Ferido",
		"wound": "Ferido",
		"confused": "Confuso",
		"confuso": "Confuso",
		"blind": "Cego",
		"silence": "Silêncio",
		"taunt": "Provocação",
		"taunted": "Provocado",
		"regen": "Regen",
		"berserk_enemy": "Fúria",
	}
	return labels.get(key, key.replace("_", " ").capitalize())

func _amp_num(value: String, amplify: bool) -> String:
	return "[color=#6dffa3]%s[/color]" % value if amplify else value

func _effect_short_bbcode(definition: Dictionary, card: Dictionary = {}) -> String:
	# Resumos curtos na face (BBCode). Glossário completo só no Inspecionar.
	var bits: Array[String] = []
	var owner: Dictionary = {}
	if battle != null and not card.is_empty():
		owner = battle.actor_by_id(int(card.get("owner", -1)))
	var e_stacks := 0
	if not owner.is_empty() and battle != null:
		e_stacks = battle._status_stacks(owner, "escuridao")
	var amplify := e_stacks > 0
	var target_names := {"SELF": "Si", "ALLY": "Aliado", "ALL_ALLIES": "Aliados", "ENEMY": "Inimigo", "SINGLE": "Inimigo", "ENEMY_ROW": "Linha", "ROW": "Linha", "FRONT_ROW": "Frente", "BACK_ROW": "Retaguarda", "ALL_ENEMIES": "Inimigos", "ALL_OTHERS": "Outros", "OWN_MINION": "Lacaio", "ADJACENT": "Adjacentes", "RANDOM": "Aleatório", "CHAIN": "Cadeia", "ANY_UNIT": "Qualquer"}
	var tgt := str(definition.get("target", "ENEMY"))
	if tgt != "ENEMY" and tgt != "SINGLE":
		bits.append(target_names.get(tgt, tgt))
	if definition.get("quick", false): bits.append("Rápida")
	if definition.get("free", false): bits.append("Livre")
	if definition.get("reach", false): bits.append("Alcance")
	if definition.get("exhaust", false) or definition.get("item", false): bits.append("[color=#e15b5b]Exaustão[/color]")
	# Requisitos de Escuridão / status próprio
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		if str(action[0]) == "requires_self_status":
			var need_st := str(action[1]) if action.size() > 1 else "?"
			var need_n := 1
			if action.size() > 2 and battle != null and not owner.is_empty():
				need_n = int(round(battle.resolve_amount(action[2], owner)))
			elif action.size() > 2 and str(action[2]).is_valid_int():
				need_n = int(action[2])
			var pretty := _status_label(need_st)
			bits.append("Requer [b]%s[/b] %d" % [pretty, need_n])
	# Efeitos STATUS legados
	for effect in definition.get("effects", []):
		var kind := str(effect.get("kind", ""))
		if kind == "DAMAGE":
			continue
		elif kind == "HEAL":
			bits.append("Cura %d" % int(effect.get("amount", 0)))
		elif kind == "STATUS":
			var sid := str(effect.get("id", ""))
			var n := maxi(1, int(effect.get("stacks", effect.get("duration", 1))))
			bits.append("Adiciona [b]%s[/b] %s" % [_status_label(sid), _amp_num(str(n), amplify)])
		elif kind == "PUSH":
			bits.append("Empurra")
		elif kind == "PULL":
			bits.append("Puxa")
		elif kind == "MOVE":
			bits.append("Troca linha")
		elif kind in ["CURE", "CLEANSE"]:
			bits.append("Limpa")
		elif kind == "DRAW":
			bits.append("Compra %d" % int(effect.get("amount", 1)))
		elif kind == "BLOCK" or kind == "SHIELD":
			bits.append("Barreira %d" % int(effect.get("amount", 0)))
	# Actions pack: status/heal/protecao com escala E
	var status_bits: Array[String] = []
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		if op in ["hit", "hit_per_impulse", "hit_per_hand", "roulette_hit", "hit_from_block", "hit_from_protecao", "hit_from_barrier", "requires_self_status", "requires_status", "when_stacks"]:
			continue
		elif op == "status":
			var sid2 := str(action[1]) if action.size() > 1 else "?"
			var stacks_raw = action[2] if action.size() > 2 else 1
			var stacks := 0
			if battle != null and not owner.is_empty():
				stacks = int(round(battle.resolve_amount(stacks_raw, owner)))
			elif str(stacks_raw).is_valid_int():
				stacks = int(stacks_raw)
			elif str(stacks_raw).strip_edges() in ["E", "e", "escuridao"]:
				stacks = 0
			status_bits.append("[b]%s[/b] %s" % [_status_label(sid2), _amp_num(str(stacks), amplify)])
		elif op in ["protecao", "protection"]:
			var pn := 1
			if action.size() > 1 and battle != null and not owner.is_empty():
				pn = maxi(1, int(round(battle.resolve_amount(action[1], owner))))
			elif action.size() > 1 and str(action[1]).is_valid_int():
				pn = maxi(1, int(action[1]))
			bits.append("[b]Proteção[/b] %s" % _amp_num(str(pn), amplify))
		elif op in ["barreira", "barrier", "barreira_hp"]:
			var bn := 1
			if action.size() > 1 and battle != null and not owner.is_empty():
				bn = maxi(1, int(round(battle.resolve_amount(action[1], owner))))
			bits.append("[b]Barreira[/b] %s" % _amp_num(str(bn), amplify))
		elif op == "resistente":
			var rn := 0
			if action.size() > 1 and battle != null and not owner.is_empty():
				rn = int(round(battle.resolve_amount(action[1], owner)))
			elif action.size() > 1 and str(action[1]).is_valid_int():
				rn = int(action[1])
			bits.append("[b]Resistente[/b] %s" % _amp_num(str(rn), amplify))
		elif op in ["heal", "heal_all", "full_heal"]:
			var hn := 0
			if action.size() > 1 and battle != null and not owner.is_empty():
				hn = int(round(battle.resolve_amount(action[1], owner)))
			bits.append("Cura %s" % _amp_num(str(hn), amplify) if hn > 0 else "")
		elif op in ["push"]:
			bits.append("Empurra")
		elif op in ["pull"]:
			bits.append("Puxa")
		elif op == "self_status":
			var sid3 := str(action[1]) if action.size() > 1 else "?"
			var sn := 1
			if action.size() > 2 and battle != null and not owner.is_empty():
				sn = maxi(1, int(round(battle.resolve_amount(action[2], owner))))
			bits.append("[b]%s[/b] %s" % [_status_label(sid3), _amp_num(str(sn), amplify)])
	if not status_bits.is_empty():
		if status_bits.size() == 1:
			bits.append("Adiciona %s" % status_bits[0])
		elif status_bits.size() == 2:
			bits.append("Adiciona %s e %s" % [status_bits[0], status_bits[1]])
		else:
			bits.append("Adiciona " + ", ".join(PackedStringArray(status_bits.slice(0, status_bits.size() - 1))) + " e " + status_bits[-1])
	if bits.is_empty() and _card_has_damage(definition):
		bits.append("Dano")
	return " · ".join(PackedStringArray(bits))

func _rules_bbcode(definition: Dictionary, card: Dictionary) -> String:
	var lines: Array[String] = []
	var target_names := {"SELF": "si mesmo", "ALLY": "aliado", "DEAD_ALLY": "aliado caído", "ALL_ALLIES": "todos os aliados", "ENEMY": "inimigo", "SINGLE": "inimigo", "ENEMY_ROW": "linha inimiga", "ROW": "linha inimiga", "FRONT_ROW": "frente inimiga", "BACK_ROW": "retaguarda inimiga", "ALL_ENEMIES": "todos os inimigos", "ALL_OTHERS": "todos os outros (exceto você)", "OWN_MINION": "seu lacaio", "ADJACENT": "alvo e adjacentes", "RANDOM": "inimigo aleatório", "CHAIN": "sequência", "ANY_UNIT": "qualquer unidade"}
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
	var harmful := ["weak", "vulnerable", "bleed", "poison", "burn", "stun", "bind", "bound", "wound", "wounded", "blind", "silence", "fragil", "confused", "corrupted", "drop"]
	var effect_lines: Array[String] = []
	for effect in definition.get("effects", []):
		var kind := str(effect.get("kind", ""))
		if kind == "DAMAGE":
			continue  # damage lives on the shield readout
		elif kind == "HEAL":
			effect_lines.append("Cura %d" % int(effect.get("amount", 0)))
		elif kind == "BLOCK":
			effect_lines.append("[b]Barreira[/b] %d" % int(effect.get("amount", 0)))
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
		if op in ["hit", "hit_per_impulse", "hit_per_hand", "roulette_hit", "hit_from_block", "hit_from_protecao", "hit_from_barrier"]:
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
			effect_lines.append("[b]Barreira[/b] (legado)")
		elif op in ["protecao", "protection"]:
			effect_lines.append("[b]Proteção[/b]")
		elif op in ["barreira", "barrier", "barreira_hp"]:
			effect_lines.append("[b]Barreira[/b]")
		elif op in ["spend_protecao", "spend_all_protecao"]:
			effect_lines.append("Gasta Proteção")
		elif op in ["spend_barrier", "spend_all_barrier"]:
			effect_lines.append("Gasta Barreira")
		elif op == "barrier_from_hit":
			effect_lines.append("Barreira = dano causado")
		elif op == "resistente":
			effect_lines.append("[b]Resistente[/b]")
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
	var custom := str(definition.get("text", "")).strip_edges()
	if custom != "":
		lines.append("")
		lines.append(custom)
	elif not effect_lines.is_empty():
		lines.append("")
		for piece in effect_lines:
			lines.append("• %s" % piece)
	return "\n".join(lines)

func _card_spec(card: Dictionary, definition: Dictionary, owner: Dictionary) -> Dictionary:
	var item := bool(definition.get("item", false))
	var art_path := str(definition.get("art", ""))
	var art: Texture2D = _load_tex(_sensitive_path(art_path, "portrait") if art_path != "" else "")
	if art == null:
		art = _load_tex(_sensitive_path(str(owner.get("portrait", "")), "portrait"))
	if art == null:
		art = _unit_portrait(owner)
	var icon: Texture2D = _load_tex("res://assets/items/item_icon.png") if item else _load_tex(_sensitive_path(str(owner.get("signature_icon", "")), "icon"))
	var readout: Dictionary = _stat_readout(owner, definition)
	var border := Color("8d929a") if item else _type_color(str(owner.get("type", "")))
	var show_damage := (not item) and _card_has_damage(definition)
	var dead := int(owner.get("hp", 0)) <= 0
	return {
		"title": str(definition.get("name", "")),
		"chip": "Item" if item else str(owner.get("name", "")),
		"item": item,
		"desvantagem": str(definition.get("class", "")) == "DESVANTAGEM",
		"art": art,
		"icon": icon,
		"border": border,
		"show_damage": show_damage and str(definition.get("class", "")) != "DESVANTAGEM",
		"stat_label": str(readout["label"]),
		"stat_value": int(readout["value"]),
		"stat_color": readout["color"],
		"rules": _effect_short_bbcode(definition, card),
		"gain": int(definition.get("gain", 0)),
		"cost": _card_ini_cost(definition, card, owner),
		"dead": dead,
		"shield_icon": _load_tex("res://assets/ui/impact_shield_sword.png")
	}


func _card_ini_cost(definition: Dictionary, card: Dictionary = {}, source: Dictionary = {}) -> int:
	if definition.has("cost_by_stacks"):
		var cbs: Dictionary = definition["cost_by_stacks"]
		var st := str(cbs.get("status", "escuridao"))
		var stacks := 0
		if not source.is_empty() and battle != null and battle.has_method("_status_stacks"):
			stacks = battle._status_stacks(source, st)
		var cap: int = int(cbs.get("max", cbs.get("cap", stacks)))
		return maxi(0, mini(stacks, cap)) if not source.is_empty() else maxi(0, cap)
	if card.has("cost_override"):
		return maxi(0, int(card.get("cost_override", 0)))
	var raw: Variant = definition.get("cost", 0)
	if typeof(raw) == TYPE_STRING:
		if not source.is_empty() and battle != null and battle.has_method("resolve_amount"):
			return maxi(0, int(round(battle.resolve_amount(raw, source))))
		return 0
	return maxi(0, int(raw))

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

func _sensitive_path(path: String, kind: String = "sprite") -> String:
	# Sensível ON (Sim) = arte original em assets/cast/.
	# OFF (Não) = assets/cast_sensitive/; se não houver ent_* correspondente, usa generics.
	if sensitive_content or path == "":
		return path
	var fname := path.get_file()
	var sens := "res://assets/cast_sensitive/" + fname
	if ResourceLoader.exists(sens) or FileAccess.file_exists(sens):
		return sens
	match kind:
		"portrait":
			if ResourceLoader.exists("res://assets/cast_sensitive/generic_portrait.png"):
				return "res://assets/cast_sensitive/generic_portrait.png"
		"icon":
			if ResourceLoader.exists("res://assets/cast_sensitive/generic_icon.png"):
				return "res://assets/cast_sensitive/generic_icon.png"
		_:
			if ResourceLoader.exists("res://assets/cast_sensitive/generic_sprite.png"):
				return "res://assets/cast_sensitive/generic_sprite.png"
	return path

func _unit_portrait(actor: Dictionary) -> Texture2D:
	var portrait_path := _sensitive_path(str(actor.get("portrait", "")), "portrait")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		return load(portrait_path)
	var sprite_path := _sensitive_path(str(actor.get("sprite", "")), "sprite")
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
	_attach_portrait_statuses(widget, actor)
	# Prévia de alvo: mostra estados nos dois retratos (ator + alvo).
	if pending_target_id >= 0 and not damage_preview_by_actor.is_empty():
		var other_id := pending_target_id if actor_id != pending_target_id else int(battle.hand[selected_card].get("owner", -1)) if selected_card >= 0 and selected_card < battle.hand.size() else -1
		if other_id >= 0 and other_id != actor_id:
			var other: Dictionary = battle.actor_by_id(other_id)
			if not other.is_empty():
				var other_w := portrait_left if str(other.get("side", "")) == "ALLY" else portrait_right
				other_w.texture = _unit_portrait(other)
				other_w.show()
				_attach_portrait_statuses(other_w, other)
	if sticky:
		portrait_sticky_until = maxi(portrait_sticky_until, Time.get_ticks_msec() + int(1100.0 / maxf(animation_speed, 0.25)))

func _attach_portrait_statuses(widget: Control, actor: Dictionary) -> void:
	if widget == null or not is_instance_valid(widget):
		return
	var old = widget.get_node_or_null("StatusList")
	if old != null:
		old.queue_free()
	var lines := _portrait_status_lines(actor)
	if lines.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "StatusList"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(12, widget.size.y * 0.72 if widget.size.y > 10 else 420)
	for line in lines:
		var lab := Label.new()
		lab.text = line
		lab.add_theme_font_size_override("font_size", 15)
		lab.add_theme_color_override("font_color", Color("ffe6b0"))
		lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lab.add_theme_constant_override("shadow_offset_x", 1)
		lab.add_theme_constant_override("shadow_offset_y", 1)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
	widget.add_child(box)

func _hide_idle_portraits() -> void:
	# Hover curto não sticky: limpa já. Sticky de ação ainda respeita o timer.
	if Time.get_ticks_msec() < portrait_sticky_until:
		return
	_refresh_portraits_for_focus()

func _refresh_portraits_for_focus() -> void:
	# Retrato só permanece se houver foco válido (hover / seleção / inspeção / prévia).
	if battle == null:
		if portrait_left != null: portrait_left.hide()
		if portrait_right != null: portrait_right.hide()
		return
	var keep_id := -1
	if hovered_actor >= 0:
		keep_id = hovered_actor
	elif hovered_card >= 0 and hovered_card < battle.hand.size():
		keep_id = int(battle.hand[hovered_card].get("owner", -1))
	elif inspect_open and inspected_card >= 0 and inspected_card < battle.hand.size():
		keep_id = int(battle.hand[inspected_card].get("owner", -1))
	elif selected_card >= 0 and selected_card < battle.hand.size():
		keep_id = int(battle.hand[selected_card].get("owner", -1))
	elif pending_target_id >= 0:
		keep_id = pending_target_id
	if keep_id < 0:
		if portrait_left != null: portrait_left.hide()
		if portrait_right != null: portrait_right.hide()
		return
	_show_actor_portrait(keep_id, false)
	# Esconde o lado oposto se não houver motivo (prévia de alvo mantém ambos).
	if pending_target_id < 0 or damage_preview_by_actor.is_empty():
		var actor: Dictionary = battle.actor_by_id(keep_id)
		var side := str(actor.get("side", ""))
		if side == "ALLY" and portrait_right != null and pending_target_id < 0:
			# Mantém só o retrato do foco, a menos que haja alvo pendente.
			pass


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
		if hovered_card == index and inspected_card != index and selected_card != index:
			hovered_card = -1
			host.scale = Vector2.ONE
			host.z_index = 0
			portrait_sticky_until = 0
			_refresh_portraits_for_focus()
		elif hovered_card == index and selected_card == index:
			# Saiu do hover mas carta segue selecionada → retrato do dono selecionado.
			host.scale = Vector2.ONE
			host.z_index = 0
			_refresh_portraits_for_focus()
	)
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	return host

func _note_card_hover(index: int, host: Control, width: float, height: float) -> void:
	if session_report != null and hovered_card != index and index >= 0:
		session_report.log_card("hover", {"index": index})
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
			hover_hint.text = _card_description(_card_def_for(battle.hand[index]), battle.hand[index])

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
		call_deferred("_render_battle")
	elif selected_card == index and not card_confirmed:
		call_deferred("_confirm_selected_card", index)
	elif inspect_open and inspected_card == index:
		call_deferred("_confirm_selected_card", index)
	else:
		var require_msg2 := _card_select_block_reason(index)
		if require_msg2 != "":
			_show_block_popup(require_msg2)
			get_viewport().set_input_as_handled()
			return
		selected_card = index
		inspected_card = -1
		inspect_open = false
		card_confirmed = false
		chain_targets.clear()
		damage_preview_by_actor.clear()
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
	pending_target_id = -1
	hovered_card = -1
	# Sempre reconstrói a mão imediatamente (changed pode ter rodado antes do depart limpar).
	_render_battle()
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
	wrap.position = Vector2(vp.x * 0.5 - 88, vp.y * 0.48)
	wrap.size = Vector2(176, 200)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 35
	recompra_ring.add_child(wrap)
	# Painel escuro com borda dourada (não ProgressBar)
	var panel := PanelContainer.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(176, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.78)
	style.set_border_width_all(2)
	style.border_color = Color(0.94, 0.76, 0.42, 0.55 + 0.35 * progress)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.24, 0.85, 0.50, 0.25 + 0.35 * progress)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	wrap.add_child(panel)
	var meter := HotNCircularMeter.new()
	meter.position = Vector2(28, 22)
	meter.size = Vector2(120, 120)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.fill_color = Color("3ecf7a").lerp(Color("f0c27a"), progress * 0.45)
	meter.accent_color = Color("f0c27a")
	meter.set_progress(progress)
	wrap.add_child(meter)
	var title := _label("RECOMPRA", 15, Color("f0c27a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(8, 148)
	title.size = Vector2(160, 20)
	wrap.add_child(title)
	var pct := int(round(progress * 100.0))
	var lbl := _label("%s · %d%%" % [label_text, pct] if progress < 1.0 else "PRONTO", 14, Color("9dffb0") if progress < 1.0 else Color("fff6df"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(8, 168)
	lbl.size = Vector2(160, 22)
	wrap.add_child(lbl)

func _target_needs_player_choice(kind: String) -> bool:
	# Auto after confirm: no unit pick required (self / whole side / fixed row / random).
	match kind:
		"SELF", "ALL_ALLIES", "ALL_ENEMIES", "ALL_OTHERS", "RANDOM", "FRONT_ROW", "BACK_ROW":
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
		"ALL_ENEMIES", "ALL_OTHERS", "RANDOM":
			var enemies: Array = battle.living("ENEMY")
			return int(enemies[0]["id"]) if not enemies.is_empty() else owner_id
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

func _confirm_selected_card(index: int = -1) -> void:
	if session_report != null:
		session_report.log_card("confirm", {"index": index if index >= 0 else selected_card})
	suppress_inspect_cancel = false
	if index < 0:
		index = selected_card if selected_card >= 0 else inspected_card
	if battle == null or index < 0 or index >= battle.hand.size():
		return
	inspect_open = false
	inspected_card = -1
	var reason := _card_unusable_reason(index)
	if reason != "":
		_show_block_popup(reason)
		selected_card = index
		card_confirmed = false
		_render_battle()
		return
	var owner: Dictionary = battle.actor_by_id(int(battle.hand[index].get("owner", 0)))
	if int(owner.get("hp", 0)) <= 0:
		_show_block_popup("Herói fora de combate — carta indisponível.")
		_render_battle()
		return
	var definition: Dictionary = _card_def_for(battle.hand[index])
	var kind := str(definition.get("target", "ENEMY"))
	selected_card = index
	card_confirmed = true
	pending_target_id = -1
	selected_action = ""
	if sound != null: sound.cue("confirm", "UI")
	_show_actor_portrait(int(battle.hand[index]["owner"]), true)
	if not _target_needs_player_choice(kind):
		var auto_id := _auto_primary_target_id(definition, int(battle.hand[index]["owner"]))
		if auto_id >= 0:
			_choose_target(auto_id)
		else:
			_show_block_popup("Sem alvo automático disponível.")
			card_confirmed = false
			_render_battle()
		return
	_render_battle()

func _confirm_inspected() -> void:
	_confirm_selected_card(inspected_card if inspected_card >= 0 else selected_card)

func _open_inspect(index: int) -> void:
	if battle == null or index < 0 or index >= battle.hand.size():
		return
	selected_card = index
	inspected_card = index
	inspect_open = true
	card_confirmed = false
	_render_battle()

func _close_inspect_keep_selection() -> void:
	inspect_open = false
	inspected_card = -1
	_render_battle()

func _cancel_inspect() -> void:
	damage_preview_by_actor.clear()
	if suppress_inspect_cancel:
		return
	inspect_open = false
	inspected_card = -1
	_render_battle()

func _status_plain(id: String, stacks: int = 1) -> String:
	var n := maxi(1, stacks)
	match str(id).to_lower():
		"slow", "lento":
			return "Lento %d — a próxima Manobra deste personagem custa +1 de Iniciativa." % n
		"weak", "fraco":
			return "Fraco %d — causa menos dano com Impacto/Poder por %d turno(s)." % [n, n]
		"vulnerable", "vulneravel", "vulnerável":
			return "Vulnerável %d — sofre dano extra ao ser atingido." % n
		"stun", "atordoado":
			return "Atordoado — não pode jogar Manobras enquanto durar."
		"bleed", "sangramento", "sangrando":
			return "[b]Sangrando[/b]: Causa dano no fim da rodada. Diminui com o tempo."
		"poison", "veneno":
			return "Veneno %d — dano contínuo de veneno a cada turno." % n
		"burn", "queimadura":
			return "Queimadura %d — dano de fogo no início do turno." % n
		"blind", "cego":
			return "Cego — erra ou reduz a precisão das próximas ações."
		"marked", "marcado":
			return "Marcado — inimigos priorizam este alvo / recebe efeitos extras."
		"bind", "bound", "preso":
			return "Preso — não pode se mover de fileira."
		"atento":
			return "Atento — reage melhor / bônus defensivo temporário."
		"wounded", "ferido":
			return "[b]Ferido[/b]: Causa dano quando o personagem usa uma Manobra. Diminui com o tempo."
		"escuridao", "escuro", "darkness":
			return "[b]Escuridão[/b]: Quando o portador (Alyssa/Marcell Wine) recebe dano, [b]Escuridão[/b] (E) aumenta em 1. Manobras escalam com E."
		"protecao", "protegido":
			return "Proteção %d — funciona como Escudo: absorve dano de Impacto." % n
		"barreira", "barrier":
			return "Barreira %d — HP extra que absorve dano antes da Vida." % n
		"resistente":
			return "Resistente %d — reduz o dano recebido." % n
		"fragil", "frágil":
			return "Frágil — sofre mais dano até o efeito acabar."
		"invulneravel", "invulnerável":
			return "Invulnerável — ignora dano até jogar uma Manobra."
		_:
			return "%s %d" % [str(id).capitalize(), n]

func _effect_glossary_lines(definition: Dictionary, card: Dictionary = {}) -> PackedStringArray:
	var lines: PackedStringArray = []
	var seen: Dictionary = {}
	var blurb := str(definition.get("text", ""))
	if blurb != "":
		lines.append(blurb)
		seen[blurb] = true
	for effect in definition.get("effects", []):
		var kind := str(effect.get("kind", ""))
		var line := ""
		match kind:
			"DAMAGE":
				var stat := str(effect.get("stat", "attack"))
				var stat_pt := "Poder" if stat == "power" else "Impacto"
				line = "Causa %s de dano (%s − defesa do alvo)." % [effect.get("amount", "?"), stat_pt]
			"STATUS":
				line = _status_plain(str(effect.get("id", "?")), int(effect.get("stacks", 1)))
			"HEAL":
				line = "Recupera %s de Vida." % effect.get("amount", "?")
			"REVIVE":
				line = "Revive um aliado caído com 25% da Vida máxima."
			"PUSH":
				line = "Empurra o alvo %s fileira(s) para trás." % effect.get("force", 1)
			"PULL":
				line = "Puxa o alvo para a fileira da frente."
			_:
				if kind != "":
					line = kind
		if line != "" and not seen.has(line):
			lines.append(line)
			seen[line] = true
	for action in definition.get("actions", []):
		if typeof(action) != TYPE_ARRAY or action.is_empty():
			continue
		var op := str(action[0])
		var line2 := ""
		match op:
			"hit":
				var bonus = action[1] if action.size() > 1 else "0"
				line2 = "Golpe de Impacto (modificador %s sobre o Impacto do herói)." % bonus
			"hit_power", "power_hit":
				line2 = "Golpe de Poder (modificador %s)." % (action[1] if action.size() > 1 else "0")
			"status":
				var sid := str(action[1]) if action.size() > 1 else "?"
				var stacks := int(action[2]) if action.size() > 2 else 1
				line2 = _status_plain(sid, stacks)
			"protecao":
				line2 = _status_plain("protecao", int(action[1]) if action.size() > 1 else 1)
			"barreira", "barrier":
				line2 = _status_plain("barreira", int(action[1]) if action.size() > 1 else 1)
			"resistente":
				line2 = _status_plain("resistente", int(action[1]) if action.size() > 1 else 1)
			"forte", "fortalecido":
				line2 = "Forte %s (Fortalecido)." % (action[1] if action.size() > 1 else "1")
			"rapido", "rápido":
				line2 = "Rápido %s (cartas custam −1 INI)." % (action[1] if action.size() > 1 else "1")
			"heal_pct":
				line2 = "Cura %s da Vida máxima." % (action[1] if action.size() > 1 else "?")
			"heal_missing_pct":
				line2 = "Cura %s da Vida faltante." % (action[1] if action.size() > 1 else "?")
			"climate", "set_climate", "weather":
				line2 = "Clima: %s." % (action[1] if action.size() > 1 else "chuva")
			"summon_foe", "reinforce_enemy":
				var foe_lbl = str(action[1]) if action.size() > 1 else "zumbi"
				if foe_lbl in ["random", "RANDOM", "*"]:
					foe_lbl = "tipo aleatório"
				line2 = "Reforços inimigos (%s) ×%s." % [foe_lbl, (action[2] if action.size() > 2 else "1")]
			"heal":
				line2 = "Recupera %s de Vida." % (action[1] if action.size() > 1 else "?")
			"push":
				line2 = "Empurra o alvo %s fileira(s)." % (action[1] if action.size() > 1 else "1")
			"draw", "draw_items":
				line2 = "Compra carta(s) para a mão."
			"slow", "lento":
				line2 = _status_plain("slow", int(action[1]) if action.size() > 1 else 1)
			"when_stacks":
				var stn := _status_label(str(action[1]) if action.size() > 1 else "?")
				var need := str(action[2]) if action.size() > 2 else "?"
				var extra := str(action[3]) if action.size() > 3 else ""
				line2 = "Se [b]%s[/b] ≥ %s: efeito extra (%s)." % [stn, need, extra]
			"requires_self_status", "requires_status":
				line2 = ""  # já coberto pelo texto / glossário Escuridão
			_:
				if op.begins_with("_") or op in ["quick", "free", "exhaust", "final", "reach"]:
					line2 = ""
				else:
					line2 = op
		if line2 != "" and not seen.has(line2):
			lines.append(line2)
			seen[line2] = true
	# Glossário fixo para efeitos Alyssa / status recorrentes citados na carta.
	var blob := (str(definition.get("text", "")) + " " + " ".join(PackedStringArray(lines))).to_lower()
	var actions_blob := str(definition.get("actions", [])).to_lower()
	if ("escuridao" in actions_blob or "escuridão" in blob or "escuridao" in blob) and not seen.has("__esc__"):
		lines.append(_status_plain("escuridao"))
		seen["__esc__"] = true
	if ("bleed" in actions_blob or "sangr" in blob) and not seen.has("__bleed__"):
		lines.append(_status_plain("bleed"))
		seen["__bleed__"] = true
	if ("wounded" in actions_blob or "ferido" in blob) and not seen.has("__wound__"):
		lines.append(_status_plain("wounded"))
		seen["__wound__"] = true
	if lines.is_empty():
		lines.append(_card_description(definition, card))
	return lines

func _add_inspect_overlay(index: int, viewport_size: Vector2) -> void:
	var blocker := Control.new()
	blocker.focus_mode = Control.FOCUS_NONE
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.z_index = 8
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.gui_input.connect(_on_inspect_blocker_gui)
	hud.add_child(blocker)
	var height := viewport_size.y * 0.55
	var width := height * 0.66
	var card: Dictionary = battle.hand[index]
	var definition: Dictionary = _card_def(str(card["id"]))
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var left_x := (viewport_size.x - width) * 0.32
	var host = CardFace.new()
	host.size = Vector2(width, height)
	host.position = Vector2(left_x, (viewport_size.y - height) * 0.42)
	host.z_index = 9
	host.setup(_card_spec(card, definition, owner))
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	hud.add_child(host)
	# Painel de glossário + botão Inspecionar / Confirmar
	var panel := PanelContainer.new()
	panel.z_index = 10
	panel.position = Vector2(left_x + width + 18, (viewport_size.y - height) * 0.42)
	panel.custom_minimum_size = Vector2(minf(360.0, viewport_size.x * 0.34), height * 0.85)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.42, 0.55, 0.78, 0.9)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_label("INSPECIONAR", 20, Color("f0c27a")))
	col.add_child(_label(str(definition.get("name", card.get("id", "?"))), 22, Color.WHITE))
	var tier := str(definition.get("tier", card.get("tier", "")))
	if tier != "":
		col.add_child(_label("Tier: %s" % tier, 15, Color("9aa6bf")))
	for line in _effect_glossary_lines(definition, card):
		var lab := RichTextLabel.new()
		lab.bbcode_enabled = true
		lab.fit_content = true
		lab.scroll_active = false
		lab.text = "• " + line
		lab.add_theme_font_size_override("normal_font_size", 15)
		lab.add_theme_color_override("default_color", Color("d5deea"))
		lab.custom_minimum_size.x = panel.custom_minimum_size.x - 28
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lab)
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 8)
	col.add_child(btn_col)
	var back := _button("Voltar", Callable(), "Fecha a inspeção e volta à carta selecionada")
	back.pressed.connect(func() -> void: _close_inspect_keep_selection())
	btn_col.add_child(back)
	var cancel2 := _button("Cancelar", Callable(), "Desmarca a carta")
	cancel2.pressed.connect(func() -> void:
		_cancel_inspect()
		_deselect_card()
	)
	btn_col.add_child(cancel2)
	hud.add_child(panel)

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
	if battle.has_method("can_end_turn") and not battle.can_end_turn():
		feedback = "Há Instantâneo jogável — jogue-o antes de encerrar."
		if session_report != null:
			session_report.log_ai("end_turn_blocked", {"reason": "instantaneo"})
		_render_battle()
		return
	if session_report != null:
		session_report.log_ai("enemy_phase_begin", {"turn": int(battle.turn)})
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
	inspect_open = false
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
		if session_report != null:
			var skip_payload := {
				"reason": "no_legal_play",
				"plays_left": int(battle.enemy_card_plays),
				"hand": battle.enemy_hand.size(),
				"impulse": int(battle.enemy_impulse),
				"redraws": int(battle.enemy_redraws),
			}
			if battle.has_method("diagnose_enemy_hand"):
				skip_payload["cards"] = battle.diagnose_enemy_hand()
			session_report.log_ai("enemy_skip", skip_payload)
		battle.finish_enemy_phase()
		packs.on_player_turn_resumed(battle, pack_mode)
		enemy_presenting = false
		_clear_enemy_card_overlay()
		_set_orbit(0.0)
		return
	if session_report != null:
		var ai_card: Dictionary = choice.get("card", {})
		var ai_def: Dictionary = _card_def(str(ai_card.get("id", "")))
		session_report.log_ai("enemy_choice", {
			"kind": str(choice.get("kind", "")),
			"card": str(ai_card.get("id", "")),
			"owner": int(ai_card.get("owner", -1)),
			"target": int(choice.get("target", -1)),
			"index": int(choice.get("index", -1)),
			"target_kind": str(ai_def.get("target", "")),
			"card_class": str(ai_def.get("class", "")),
		})
	if str(choice.get("kind", "")) == "play":
		var card: Dictionary = choice.get("card", {})
		var definition: Dictionary = _card_def(str(card.get("id", "")))
		var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
		feedback = "Adversário joga: %s" % str(definition.get("name", ""))
		_show_actor_portrait(int(card.get("owner", 0)), true)
		_lateral_focus_actor(int(card.get("owner", 0)), 1.7)
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
		var card_id := str(card.get("id", ""))
		var ok := false
		if packs.is_pack_card(card_id) or pack_mode == "entities":
			ok = packs.play_card(battle, pack_mode if pack_mode != "default" else ("entities" if card_id.begins_with("ent_") else "external"), int(choice["index"]), target_id, choice.get("chain", []))
		else:
			ok = battle.play(int(choice["index"]), target_id, choice.get("chain", []))
		if not ok:
			feedback = "Adversário não pôde jogar %s." % str(definition.get("name", card_id))
			# Evita loop: força fim se a IA escolheu jogada inválida.
			battle.enemy_card_plays = 0
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

func _add_selected_card_overlay(index: int, viewport_size: Vector2) -> void:
	var card: Dictionary = battle.hand[index]
	var definition: Dictionary = _card_def(str(card["id"]))
	var owner: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var host = CardFace.new()
	host.name = "SelectedCardOverlay"
	var height := viewport_size.y * 0.60
	var width := height * 0.66
	host.size = Vector2(width, height)
	host.position = Vector2((viewport_size.x - width) * 0.5, (viewport_size.y - height) * 0.5)
	host.z_index = 12
	host.setup(_card_spec(card, definition, owner))
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.gui_input.connect(func(event: InputEvent) -> void: _on_card_gui(event, index))
	hud.add_child(host)

func _clear_enemy_card_overlay() -> void:
	if fx_overlay == null:
		return
	var existing := fx_overlay.get_node_or_null("EnemyCardOverlay")
	if existing != null:
		existing.queue_free()

func _input(event: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER" or enemy_presenting: return
	if battle_menu_open and not (event.is_action_pressed("hotn_cancel") or event.is_action_pressed("hotn_confirm")):
		return
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
		if battle_menu_open:
			_close_battle_menu()
		elif pending_target_id >= 0:
			_confirm_pending_target()
		elif selected_card >= 0 and not card_confirmed:
			_confirm_selected_card(selected_card)
		elif inspected_card >= 0 and not card_confirmed:
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
			feedback = "Segure ~1s numa carta (ou selecione e pressione de novo) para Recompra."
			_render_battle()
	elif event.is_action_pressed("hotn_move"):
		_start_move_action()
	elif event.is_action_pressed("hotn_end"):
		_present_enemy_turn()
	elif event.is_action_pressed("hotn_cancel"):
		_handle_battle_cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func _activate_actor(actor_id: int) -> void:
	if battle == null or battle.phase != "PLAYER" or battle_menu_open: return
	hovered_actor = actor_id
	_show_actor_portrait(actor_id, true)
	if selected_action == "move" or selected_action.begins_with("item:"):
		if sound != null: sound.cue("confirm", "UI")
		_choose_target(actor_id)
		return
	if card_confirmed and selected_card >= 0:
		# Prévia + confirmação antes de resolver (não aplica no primeiro clique no alvo).
		pending_target_id = actor_id
		_apply_target_preview(actor_id)
		if sound != null: sound.cue("select", "UI")
		_render_battle()
		return

func _unhandled_input(input: InputEvent) -> void:
	if _handle_title_menu_input(input):
		return
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
	if battle_menu_open:
		return
	if click.pressed and hit.has("collider") and hit["collider"].has_meta("actor_id"):
		_activate_actor(int(hit["collider"].get_meta("actor_id")))
		get_viewport().set_input_as_handled()
	elif click.pressed and not hit.has("collider"):
		# Clique fora: cancela carta selecionada (pré-confirmação) ou alvo pendente.
		if pending_target_id >= 0:
			_cancel_pending_target()
			get_viewport().set_input_as_handled()
		elif selected_card >= 0 and not card_confirmed:
			_deselect_card()
			get_viewport().set_input_as_handled()
	elif not click.pressed and redraw_hold_index >= 0:
		# Released off-card: cancel hold without playing click
		redraw_hold_index = -1
		redraw_hold_time = 0.0
		_clear_recompra_meter()

func _card_description(definition: Dictionary, card: Dictionary = {}) -> String:
	var parts: Array[String] = []
	var target_names := {"SELF": "em si", "ALLY": "aliado", "DEAD_ALLY": "aliado caído", "ALL_ALLIES": "todos os aliados", "ENEMY": "inimigo", "SINGLE": "inimigo", "ENEMY_ROW": "linha inimiga", "ROW": "linha inimiga", "FRONT_ROW": "frente inimiga", "BACK_ROW": "retaguarda inimiga", "ALL_ENEMIES": "todos os inimigos", "ALL_OTHERS": "todos os outros", "OWN_MINION": "seu lacaio", "ADJACENT": "alvo e adjacentes", "RANDOM": "inimigo aleatório", "CHAIN": "sequência", "ANY_UNIT": "qualquer unidade"}
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
	if definition.get("instant", false): parts.append("INSTANTÂNEO (se jogável, deve ser jogado antes de outras cartas)")
	if definition.get("ephemeral", false): parts.append("EFÊMERO")
	if int(definition.get("warmup", 0)) > 0: parts.append("AQUECIMENTO %d" % int(definition["warmup"]))
	if definition.get("chain", 0) > 0: parts.append("CHAIN %d" % definition["chain"])
	if definition.has("cost_by_stacks"):
		var cbs2: Dictionary = definition["cost_by_stacks"]
		parts.append("−min(%s, %d) Iniciativa" % [str(cbs2.get("status", "E")), int(cbs2.get("max", cbs2.get("cap", 5)))])
	elif int(definition.get("cost", 0)) > 0:
		parts.append("−%d Iniciativa" % int(definition["cost"]))
	if definition.get("gain", 0) > 0: parts.append("+%d Iniciativa" % definition["gain"])
	for action_line in packs.describe_actions(definition):
		parts.append(action_line)
	for effect in definition.get("effects", []):
		match effect["kind"]:
			"STATUS": parts.append("%s (%d turno(s), %d carga(s))" % [str(effect["id"]).replace("_", " ").capitalize(), effect.get("duration", 1), effect.get("stacks", 1)])
			"DAMAGE": parts.append("Dano base %d + atributo" % int(effect.get("amount", 0)))
			"HEAL": parts.append("Cura %d" % int(effect.get("amount", 0)))
			"BLOCK", "SHIELD": parts.append("Barreira %d" % int(effect.get("amount", 0)))
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

func _apply_corpse_look(sprite: Sprite3D, dead: bool) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var already := bool(sprite.get_meta("corpse_gray", false))
	if dead == already:
		return
	if dead:
		var live: Texture2D = sprite.texture
		if live != null:
			sprite.set_meta("live_texture", live)
			var gray := _grayscale_texture(live)
			if gray != null and gray != live:
				sprite.texture = gray
				sprite.set_meta("corpse_tex", true)
			else:
				sprite.set_meta("corpse_tex", false)
		sprite.set_meta("corpse_gray", true)
	else:
		if sprite.has_meta("live_texture"):
			var restored: Texture2D = sprite.get_meta("live_texture")
			if restored != null:
				sprite.texture = restored
			sprite.remove_meta("live_texture")
		sprite.set_meta("corpse_gray", false)
		sprite.set_meta("corpse_tex", false)

func _grayscale_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key := tex.resource_path
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var base := ""
		if at.atlas != null:
			base = str(at.atlas.resource_path)
		key = "%s|%s" % [base, str(at.region)]
	if key == "":
		key = "id:%d" % tex.get_instance_id()
	if corpse_textures.has(key):
		return corpse_textures[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var px := img.get_pixel(x, y)
			var g := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
			img.set_pixel(x, y, Color(g, g, g, px.a))
	var gray := ImageTexture.create_from_image(img)
	corpse_textures[key] = gray
	return gray

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
	if title_menu_3d != null and is_instance_valid(title_menu_3d) and title_menu_3d.visible:
		title_float_t += delta
		# Bob / gentle sway for the floating 3D menu cluster.
		title_menu_3d.position.y = 0.15 + sin(title_float_t * 1.15) * 0.08
		title_menu_3d.rotation_degrees.y = sin(title_float_t * 0.55) * 4.0
		title_menu_3d.rotation_degrees.x = sin(title_float_t * 0.7) * 1.5
		var bi := 0
		for btn in title_menu_btn_nodes:
			if btn != null and is_instance_valid(btn):
				btn.position.z = sin(title_float_t * 1.4 + float(bi) * 0.7) * 0.04
				bi += 1
		_tick_title_menu_hover()
	for i in range(unit_sprites.size()):
		if not is_instance_valid(unit_sprites[i]):
			continue
		var spr := unit_sprites[i]
		var spr_s := float(spr.get_meta("sprite_scale", 1.0))
		# Breath fica ligado mesmo com "Reduzir movimento da câmera" — só pausa durante ação.
		var busy := Time.get_ticks_msec() < int(spr.get_meta("action_until", 0))
		if busy:
			continue
		var aid := int(spr.get_meta("actor_id", -1))
		var dead := false
		if battle != null and aid >= 0:
			var body_actor: Dictionary = battle.actor_by_id(aid)
			dead = (not body_actor.is_empty()) and int(body_actor.get("hp", 0)) <= 0
		if dead:
			# Cadáver: sem respiração; sprite em escala de cinza.
			spr.scale = Vector3(spr_s, spr_s, 1.0)
			spr.position.y = 1.1
			_apply_corpse_look(spr, true)
			continue
		_apply_corpse_look(spr, false)
		# Idle breath: pin feet (bottom), stretch only the upper portion gently.
		var wave := sin(Time.get_ticks_msec() * 0.0022 + float(i) * 1.7)
		var sy := 1.0 + wave * 0.038
		var sx := 1.0 - wave * 0.018
		spr.scale = Vector3(sx * spr_s, sy * spr_s, 1.0)
		# Base center y=1.1 with height ≈ 2.2*spr_s; lift center so bottom stays fixed.
		spr.position.y = 1.1 + 1.1 * spr_s * (sy - 1.0)
	if battle != null and battle.phase == "PLAYER":
		_tick_recompra_hold(delta)
	if battle != null and battle.phase == "PLAYER" and camera != null and not battle_menu_open:
		var selection_lock := selected_card >= 0 and not card_confirmed and not inspect_open
		var now_ms := Time.get_ticks_msec()
		var freeze_hover := now_ms < hover_retarget_freeze_until
		var pointer := get_viewport().get_mouse_position()
		var origin := camera.project_ray_origin(pointer)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pointer) * 80.0)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var new_card := int(hit["collider"].get_meta("card_index")) if hit.has("collider") and hit["collider"].has_meta("card_index") else -1
		var new_actor := int(hit["collider"].get_meta("actor_id")) if new_card < 0 and hit.has("collider") and hit["collider"].has_meta("actor_id") else -1
		# Modo carta selecionada (pré-confirmação): sem hover/zoom em outras cartas/sprites.
		if selection_lock:
			new_card = selected_card
			new_actor = -1
		elif pending_target_id >= 0:
			new_actor = pending_target_id
		elif freeze_hover and hovered_actor >= 0:
			# Mantém o sprite atual enquanto o zoom assenta (sem warp do mouse).
			if new_actor != hovered_actor:
				new_actor = hovered_actor
				new_card = -1
		var hover_dirty := false
		if new_card != hovered_card:
			hovered_card = new_card
			hover_dirty = true
			if hovered_card >= 0 and hovered_card < battle.hand.size() and not selection_lock:
				_show_actor_portrait(int(battle.hand[hovered_card]["owner"]), false)
				if is_instance_valid(hover_hint):
					hover_hint.text = _card_description(_card_def_for(battle.hand[hovered_card]), battle.hand[hovered_card])
		if new_actor != hovered_actor:
			hovered_actor = new_actor
			status_hover_actor = new_actor
			hover_dirty = true
			if hovered_actor >= 0:
				_show_actor_portrait(hovered_actor, false)
				_refresh_actor_hp_bars()
				if card_confirmed and selected_card >= 0 and selected_card < battle.hand.size():
					_apply_target_preview(hovered_actor)
				elif not damage_preview_by_actor.is_empty():
					damage_preview_by_actor.clear()
					_refresh_actor_hp_bars()
		if hover_dirty:
			_refresh_hero_hud()
			# Sem hover e sem seleção/inspeção → limpa retrato imediatamente.
			if hovered_card < 0 and hovered_actor < 0:
				portrait_sticky_until = 0
				_refresh_portraits_for_focus()
	for id in actor_nodes.keys():
		var body: Node3D = actor_nodes[id]
		if not is_instance_valid(body): continue
		var avatar: Sprite3D = body.get_node_or_null("Avatar")
		if avatar == null: continue
		var hot := int(id) == hovered_actor or int(id) == pending_target_id
		var actor_now: Dictionary = battle.actor_by_id(int(id)) if battle != null else {}
		var is_dead := (not actor_now.is_empty()) and int(actor_now.get("hp", 0)) <= 0
		if is_dead:
			if bool(avatar.get_meta("corpse_tex", false)):
				avatar.modulate = Color(1.12, 1.12, 1.12) if hot else Color.WHITE
			else:
				avatar.modulate = Color(0.45, 0.45, 0.48) if not hot else Color(0.62, 0.62, 0.66)
		else:
			avatar.modulate = Color("ffe1a8") if hot else Color.WHITE
	_update_hand_card_visuals()
	_compensate_hand_for_camera_fov()
	if presentation != null and battle != null and battle.phase == "PLAYER" and not battle_menu_open:
		var selection_lock2 := selected_card >= 0 and not card_confirmed and not inspect_open
		# Em modo selecionado (pré-confirmação): câmera normal, sem zoom de hover.
		var focus_id := -1
		if not selection_lock2:
			focus_id = hovered_actor
			if focus_id < 0 and hovered_card >= 0 and hovered_card < battle.hand.size():
				focus_id = int(battle.hand[hovered_card].get("owner", -1))
			if focus_id < 0 and card_confirmed and selected_card >= 0 and selected_card < battle.hand.size():
				focus_id = pending_target_id if pending_target_id >= 0 else -1
		if focus_id >= 0:
			var focus_actor: Dictionary = battle.actor_by_id(focus_id)
			if focus_actor.is_empty():
				focus_id = -1
		if free_camera:
			_tick_free_camera(delta)
		elif battle_view_mode == "lateral":
			var want_focus := Vector3.ZERO
			# Zoom só no hover de SPRITE: escala o mundo (stage+units). Hover de carta
			# foca o dono sem zoom — câmera/mão 3D permanecem estáticas na tela.
			var want_zoom := 1.0
			var cinema_active := Time.get_ticks_msec() < cinematic_until_msec and cinematic_actor_id >= 0
			if cinema_active and actor_nodes.has(cinematic_actor_id):
				var cbody: Node3D = actor_nodes[cinematic_actor_id]
				if is_instance_valid(cbody):
					want_focus = cbody.position
					want_zoom = cinematic_zoom
			elif focus_id >= 0 and actor_nodes.has(focus_id):
				var body: Node3D = actor_nodes[focus_id]
				if is_instance_valid(body):
					want_focus = body.position
					if hovered_actor >= 0 and hovered_actor == focus_id:
						want_zoom = 1.55
						_maybe_center_mouse_on_sprite(focus_id, body)
			presentation.focus_target = presentation.focus_target.lerp(want_focus, 1.0 - exp(-delta * 5.0))
			presentation.zoom = lerpf(presentation.zoom, want_zoom, 1.0 - exp(-delta * 5.0))
			presentation.orbit = 0.0
		else:
			var focus := Vector3.ZERO
			var cinema_active2 := Time.get_ticks_msec() < cinematic_until_msec and cinematic_actor_id >= 0
			if cinema_active2 and actor_nodes.has(cinematic_actor_id):
				var cbody2: Node3D = actor_nodes[cinematic_actor_id]
				if is_instance_valid(cbody2):
					focus = Vector3(cbody2.position.x * 0.42, 0.28, 0.0)
			elif focus_id >= 0 and actor_nodes.has(focus_id):
				var actor: Dictionary = battle.actor_by_id(focus_id)
				if str(actor.get("side", "")) == "ALLY":
					var body: Node3D = actor_nodes[focus_id]
					focus = Vector3(body.position.x * 0.34, 0.18, 0.0)
					_maybe_center_mouse_on_sprite(focus_id, body)
			presentation.ally_focus = presentation.ally_focus.lerp(focus, 1.0 - exp(-delta * 5.0))
	_apply_battle_world_zoom()
	if portrait_sticky_until > 0 and Time.get_ticks_msec() >= portrait_sticky_until:
		portrait_sticky_until = 0
		_hide_idle_portraits()

func _maybe_center_mouse_on_sprite(actor_id: int, body: Node3D) -> void:
	# Sem warp_mouse: congela retarget de hover ~0.5s enquanto o zoom assenta,
	# para personagens vizinhos permanecerem selecionáveis sem salto do cursor.
	if camera == null or body == null or not is_instance_valid(body):
		return
	if hovered_actor != actor_id:
		return
	var now := Time.get_ticks_msec()
	if actor_id == _sprite_mouse_lock_id and now < _sprite_mouse_lock_until:
		return
	_sprite_mouse_lock_id = actor_id
	_sprite_mouse_lock_until = now + 500
	hover_retarget_freeze_until = now + 500

func _compensate_hand_for_camera_fov() -> void:
	# Compat: mão é filha da câmera com FOV fixo na lateral — escala HUD sempre 1.
	if cards_3d == null or not is_instance_valid(cards_3d):
		return
	cards_3d.scale = Vector3.ONE

func _reset_battle_world_xform() -> void:
	if stage != null and is_instance_valid(stage):
		stage.position = Vector3.ZERO
		stage.scale = Vector3.ONE
	if units != null and is_instance_valid(units):
		units.position = Vector3.ZERO
		units.scale = Vector3.ONE

func _apply_battle_world_zoom() -> void:
	# Zoom lateral: mundo (arena+unidades) escala/desloca; câmera e mão 3D ficam estáticas.
	if battle_view_mode != "lateral" or presentation == null or free_camera or battle == null:
		_reset_battle_world_xform()
		return
	var z := clampf(float(presentation.zoom), 1.0, 2.4)
	var focus: Vector3 = presentation.focus_target
	# Escala em torno do foco + leve pan para centralizar o ator.
	var pan_k := 0.20 + (z - 1.0) * 0.28
	var pos := focus * (1.0 - z) - Vector3(focus.x, 0.0, focus.z) * pan_k
	var scl := Vector3(z, z, z)
	if stage != null and is_instance_valid(stage):
		stage.scale = scl
		stage.position = pos
	if units != null and is_instance_valid(units):
		units.scale = scl
		units.position = pos

func _apply_target_preview(actor_id: int) -> void:
	if battle == null or selected_card < 0 or selected_card >= battle.hand.size() or actor_id < 0:
		return
	var estimate: Dictionary = battle.preview(selected_card, actor_id, chain_targets)
	damage_preview_by_actor.clear()
	if estimate.is_empty():
		if is_instance_valid(hover_hint):
			hover_hint.text = "Alvo inválido"
		_refresh_actor_hp_bars()
		return
	var dmg_total := 0
	var status_bits: PackedStringArray = []
	var est_map: Dictionary = estimate.get("targets", {})
	for vid in est_map.keys():
		var row: Dictionary = est_map[vid]
		var dmg := int(row.get("damage", 0))
		if dmg > 0:
			damage_preview_by_actor[int(vid)] = dmg
			dmg_total += dmg
		for st in row.get("statuses", []):
			if not status_bits.has(str(st)):
				status_bits.append(str(st))
	var extra := ""
	if not status_bits.is_empty():
		extra = " · " + ", ".join(status_bits)
	for se in estimate.get("self_effects", []):
		extra += " · self:" + str(se)
	if is_instance_valid(hover_hint):
		var vp := get_viewport().get_visible_rect().size
		hover_hint.visible = true
		hover_hint.z_index = 25
		hover_hint.add_theme_font_size_override("font_size", 18)
		hover_hint.add_theme_color_override("font_color", Color("ffd49b"))
		hover_hint.text = "Prévia: %s perde ~%d HP%s — confirme o alvo" % [battle.actor_by_id(actor_id).get("name", ""), dmg_total, extra]
		hover_hint.position = Vector2(vp.x * 0.5 - 280, vp.y * 0.12)
		hover_hint.size = Vector2(560, 48)
		hover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_actor_hp_bars()

func _tick_free_camera(delta: float) -> void:
	if presentation == null or camera == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var cur := get_viewport().get_mouse_position()
		if not free_cam_dragging:
			free_cam_dragging = true
			free_cam_last = cur
		else:
			var dxy := cur - free_cam_last
			free_cam_last = cur
			free_cam_yaw -= dxy.x * 0.004
			free_cam_pitch = clampf(free_cam_pitch - dxy.y * 0.003, -0.45, 0.55)
	else:
		free_cam_dragging = false
	var radius := 16.8
	var base := Vector3(sin(free_cam_yaw) * radius, 11.15 + free_cam_pitch * 6.0, cos(free_cam_yaw) * radius)
	presentation.camera_position = base
	presentation.orbit = free_cam_yaw
	presentation.ally_focus = Vector3.ZERO
	presentation.focus_target = Vector3.ZERO
	presentation.zoom = 1.0
	if battle_view_mode == "lateral":
		camera.position = Vector3(sin(free_cam_yaw) * 4.0, 8.4 + free_cam_pitch * 4.0, 15.2)
		camera.look_at(Vector3(free_cam_yaw * 2.0, 1.0, 0.0), Vector3.UP)
	else:
		camera.position = base
		camera.look_at(Vector3(0, 0.75, 0), Vector3.UP)

func _update_hand_card_visuals() -> void:
	for mesh_index in range(card_meshes.size()):
		var card_mesh: MeshInstance3D = card_meshes[mesh_index]
		if not is_instance_valid(card_mesh): continue
		if card_mesh.has_meta("dealing"):
			continue
		# Com uma carta selecionada, as demais somem (só a escolhida permanece).
		var hide_others := false
		if battle != null and selected_card >= 0 and selected_card < battle.hand.size():
			hide_others = true
		if hide_others:
			card_mesh.visible = mesh_index == selected_card
		else:
			card_mesh.visible = true
		# Evita raycast/clique em cartas invisíveis.
		for child in card_mesh.get_children():
			if child is Area3D:
				child.monitoring = card_mesh.visible
				child.monitorable = card_mesh.visible
				child.input_ray_pickable = card_mesh.visible
		if not card_mesh.visible:
			continue
		var selection_lock := selected_card >= 0 and not card_confirmed and not inspect_open
		var raised := false
		if selection_lock:
			raised = mesh_index == selected_card
		else:
			raised = (mesh_index == hovered_card and mesh_index != selected_card) or mesh_index == inspected_card or (mesh_index == selected_card and card_confirmed)
		var target_scale := Vector3(1.14, 1.14, 1.14) if raised else Vector3.ONE
		card_mesh.scale = card_mesh.scale.lerp(target_scale, 0.35)
		var base_pos: Vector3 = card_mesh.get_meta("base_pos", card_mesh.position)
		var lift := Vector3(0, 0.24, 0.30) if raised else Vector3.ZERO
		var want_pos := base_pos + lift
		var base_rot: Vector3 = card_mesh.get_meta("base_rot", card_mesh.rotation)
		var want_rot := Vector3(-0.02, 0.0, 0.0) if raised else base_rot
		# Preserve deal-in animation until near the slot
		if card_mesh.position.distance_to(base_pos) < 1.25 or raised:
			card_mesh.position = card_mesh.position.lerp(want_pos, 0.35)
		card_mesh.rotation = card_mesh.rotation.lerp(want_rot, 0.35)
		card_mesh.sorting_offset = 100.0 if raised else float(mesh_index) * 0.01
		if card_mesh.material_override != null:
			card_mesh.material_override.render_priority = 20 if raised else 0
		var glow_node: MeshInstance3D = card_mesh.get_node_or_null("HoverGlow")
		if glow_node != null and glow_node.material_override != null:
			var gmat: StandardMaterial3D = glow_node.material_override
			var glow_on := mesh_index == hovered_card or mesh_index == inspected_card or mesh_index == selected_card
			var target_a := 0.22 if glow_on else 0.0
			var target_e := 4.0 if glow_on else 0.0
			gmat.albedo_color.a = lerpf(gmat.albedo_color.a, target_a, 0.35)
			gmat.emission_energy_multiplier = lerpf(gmat.emission_energy_multiplier, target_e, 0.35)


func _phase_prompt_text() -> String:
	if battle == null:
		return ""
	if battle.phase == "ENEMY" or enemy_presenting:
		return "Fase dos adversários"
	if inspect_open:
		return "Volte quando terminar de Inspecionar"
	if battle_menu_open:
		return "Menu de combate"
	if pending_target_id >= 0 and card_confirmed:
		return "Confirme o alvo"
	if card_confirmed and selected_card >= 0:
		return "Selecione um alvo — prévia ao passar o mouse"
	if selected_card >= 0 and not card_confirmed:
		return "Confirme a Manobra (ou Cancelar / clique fora)"
	return "Selecione uma Manobra ou encerre o turno"

func _add_phase_prompt(viewport_size: Vector2) -> void:
	var w := minf(560.0, viewport_size.x * 0.6)
	var h := 42.0
	var box := Control.new()
	box.name = "PhasePrompt"
	box.z_index = 30
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Âncoras no topo-centro — independente do tamanho do viewport/screenshot.
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -w * 0.5
	box.offset_right = w * 0.5
	box.offset_top = 52.0
	box.offset_bottom = 52.0 + h
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.14, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var border := ColorRect.new()
	border.color = Color(0.72, 0.58, 0.32, 0.95)
	border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	border.offset_top = -2.0
	border.offset_bottom = 0.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(border)
	var lab := _label(_phase_prompt_text(), 17, Color("f0e6d0"))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.offset_left = 8
	lab.offset_right = -8
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	hud.add_child(box)

func _add_selected_card_actions(index: int, viewport_size: Vector2) -> void:
	# A carta central confirma no segundo clique; Inspecionar + Cancelar ao lado.
	var col := VBoxContainer.new()
	col.name = "SelectedCardActions"
	col.add_theme_constant_override("separation", 8)
	var card_height := viewport_size.y * 0.60
	var card_width := card_height * 0.66
	col.position = Vector2(viewport_size.x * 0.5 + card_width * 0.5 + 18.0, viewport_size.y * 0.5 - 40.0)
	col.z_index = 13
	var inspect_btn := _button("Inspecionar", Callable(), "Abre o glossário da Manobra selecionada")
	inspect_btn.custom_minimum_size = Vector2(160, 40)
	inspect_btn.pressed.connect(func() -> void: _open_inspect(index))
	col.add_child(inspect_btn)
	var cancel_btn := _button("Cancelar", Callable(), "Desmarca a carta selecionada")
	cancel_btn.custom_minimum_size = Vector2(160, 40)
	cancel_btn.pressed.connect(func() -> void: _deselect_card())
	col.add_child(cancel_btn)
	hud.add_child(col)

func _deselect_card() -> void:
	if session_report != null:
		session_report.log_card("cancel", {"index": selected_card})
	if sound != null: sound.cue("cancel", "UI")
	selected_card = -1
	card_confirmed = false
	inspected_card = -1
	inspect_open = false
	pending_target_id = -1
	chain_targets.clear()
	damage_preview_by_actor.clear()
	portrait_sticky_until = 0
	_hide_idle_portraits()
	_render_battle()

func _confirm_pending_target() -> void:
	if session_report != null:
		session_report.log_card("pending_confirm", {"target": pending_target_id, "card": selected_card})
	if pending_target_id < 0 or not card_confirmed or selected_card < 0:
		return
	var tid := pending_target_id
	pending_target_id = -1
	if sound != null: sound.cue("confirm", "UI")
	_choose_target(tid)

func _cancel_pending_target() -> void:
	if session_report != null:
		session_report.log_card("pending_cancel", {"target": pending_target_id})
	if sound != null: sound.cue("cancel", "UI")
	pending_target_id = -1
	damage_preview_by_actor.clear()
	_refresh_actor_hp_bars()
	_render_battle()

func _handle_battle_cancel() -> void:
	if battle_menu_open:
		_close_battle_menu()
		return
	if pending_target_id >= 0:
		_cancel_pending_target()
		return
	if inspect_open:
		if sound != null: sound.cue("cancel", "UI")
		_cancel_inspect()
		return
	if selected_card >= 0 or card_confirmed or selected_action != "":
		_deselect_card()
		selected_action = ""
		feedback = ""
		return
	_open_battle_menu()

func _open_battle_menu() -> void:
	if battle == null:
		return
	battle_menu_open = true
	if sound != null: sound.cue("select", "UI")
	_render_battle()

func _close_battle_menu() -> void:
	battle_menu_open = false
	if sound != null: sound.cue("cancel", "UI")
	_render_battle()

func _return_to_main_menu() -> void:
	battle_menu_open = false
	free_camera = false
	if sound != null: sound.cue("cancel", "UI")
	battle = null
	_clear_combat_visuals()
	_show_menu()

func _set_weather(mode: String) -> void:
	weather_mode = mode
	_apply_weather_fx()
	_save_config()
	if battle_menu_open:
		_render_battle()

func _toggle_free_camera() -> void:
	free_camera = not free_camera
	if free_camera:
		free_cam_yaw = presentation.orbit if presentation != null else 0.0
		free_cam_pitch = 0.0
	else:
		if presentation != null:
			presentation.orbit = 0.0
			presentation.zoom = 1.0
			presentation.focus_target = Vector3.ZERO
			presentation.ally_focus = Vector3.ZERO
		_apply_battle_view()
	_save_config()
	if battle_menu_open:
		_render_battle()

func _weather_tex(names: Array) -> Texture2D:
	for n in names:
		var path := "res://assets/fx/particles2d/%s" % str(n)
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _make_weather_particles(amount: int, lifetime: float, box: Vector3, pos: Vector3, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3, tint: Color, tex: Texture2D, quad_size: float = 0.35) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = box
	particles.position = pos
	particles.direction = dir
	particles.spread = spread
	particles.initial_velocity_min = vmin
	particles.initial_velocity_max = vmax
	particles.gravity = grav
	particles.color = tint
	if tex != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = tint
		var q := QuadMesh.new()
		q.size = Vector2(quad_size, quad_size)
		particles.mesh = q
		particles.material_override = mat
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.04
		mesh.height = 0.08
		particles.mesh = mesh
	particles.emitting = true
	return particles

func _apply_weather_fx() -> void:
	if stage == null:
		return
	if weather_fx_root != null and is_instance_valid(weather_fx_root):
		weather_fx_root.queue_free()
	weather_fx_root = null
	if weather_mode == "none":
		return
	var root := Node3D.new()
	root.name = "WeatherFx"
	stage.add_child(root)
	weather_fx_root = root
	match weather_mode:
		"rain":
			var rain_tex := _weather_tex(["line_rain1.png", "line_rain2.png", "line_drop1.png"])
			root.add_child(_make_weather_particles(140, 1.35, Vector3(12, 0.3, 10), Vector3(0, 9.0, 0), Vector3(0.2, -1, 0.05), 8.0, 7.0, 11.0, Vector3(0, -10, 0), Color(0.7, 0.82, 1.0, 0.75), rain_tex, 0.28))
			var splash := _make_weather_particles(40, 0.55, Vector3(10, 0.05, 8), Vector3(0, 0.15, 0), Vector3(0, 1, 0), 180.0, 0.4, 1.2, Vector3(0, -2, 0), Color(0.75, 0.85, 1.0, 0.35), _weather_tex(["particle1.png", "circle.png"]), 0.18)
			root.add_child(splash)
		"snow":
			var snow_tex := _weather_tex(["snow_particle1.png", "snow_particle2.png", "snow1.png", "snow2.png", "snow4.png"])
			root.add_child(_make_weather_particles(90, 4.5, Vector3(12, 0.4, 10), Vector3(0, 9.5, 0), Vector3(0.08, -0.35, 0.05), 35.0, 0.35, 0.9, Vector3(0, -0.35, 0), Color(0.95, 0.97, 1.0, 0.85), snow_tex, 0.32))
			root.add_child(_make_weather_particles(40, 5.5, Vector3(10, 0.3, 8), Vector3(0, 8.5, 0), Vector3(-0.05, -0.25, 0.08), 50.0, 0.2, 0.55, Vector3(0, -0.2, 0), Color(0.9, 0.94, 1.0, 0.55), _weather_tex(["snow3.png", "snow5.png", "snow1g.png"]), 0.22))
		"leaves":
			var leaf_tex := _weather_tex(["leaf1.png", "leaf1g.png"])
			root.add_child(_make_weather_particles(55, 3.8, Vector3(11, 0.5, 9), Vector3(0, 8.0, 0), Vector3(0.55, -0.35, 0.1), 55.0, 0.8, 2.0, Vector3(0, -0.8, 0), Color(0.95, 0.72, 0.35, 0.9), leaf_tex, 0.42))
			root.add_child(_make_weather_particles(25, 4.2, Vector3(9, 0.4, 7), Vector3(0, 7.2, 0), Vector3(0.35, -0.25, -0.1), 40.0, 0.5, 1.4, Vector3(0, -0.55, 0), Color(0.75, 0.45, 0.2, 0.75), leaf_tex, 0.35))
		"fog":
			var fog_tex := _weather_tex(["cloud1.png", "cloud2.png", "cloud3.png", "smog1.png", "smog2.png"])
			root.add_child(_make_weather_particles(35, 6.0, Vector3(12, 1.2, 10), Vector3(0, 2.2, 0), Vector3(0.25, 0.02, 0.1), 20.0, 0.15, 0.45, Vector3(0, 0.02, 0), Color(0.78, 0.82, 0.9, 0.28), fog_tex, 1.4))
			root.add_child(_make_weather_particles(20, 7.0, Vector3(10, 0.8, 8), Vector3(0, 1.4, 0), Vector3(-0.15, 0.0, 0.08), 25.0, 0.1, 0.3, Vector3(0, 0.01, 0), Color(0.7, 0.74, 0.82, 0.22), _weather_tex(["cloud1s.png", "cloud2s.png", "smog2.png"]), 1.1))
		"heat":
			var heat_tex := _weather_tex(["flame1.png", "flame1g.png", "particle2.png", "flare.png"])
			root.add_child(_make_weather_particles(50, 2.2, Vector3(10, 0.2, 8), Vector3(0, 0.3, 0), Vector3(0.05, 1, 0.05), 30.0, 0.6, 1.8, Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.22, 0.45), heat_tex, 0.4))
			root.add_child(_make_weather_particles(30, 1.8, Vector3(8, 0.15, 6), Vector3(0, 0.2, 0), Vector3(0, 1, 0), 40.0, 0.4, 1.2, Vector3(0, 0.9, 0), Color(1.0, 0.75, 0.35, 0.3), _weather_tex(["particle3.png", "flare2.png"]), 0.28))
		"night":
			var star_tex := _weather_tex(["star1.png", "particle1.png", "shine1.png", "asterisk_thin1.png"])
			root.add_child(_make_weather_particles(60, 3.5, Vector3(12, 2.0, 10), Vector3(0, 6.5, 0), Vector3(0, 0.05, 0), 180.0, 0.05, 0.2, Vector3(0, 0.02, 0), Color(0.55, 0.65, 1.0, 0.55), star_tex, 0.2))
			root.add_child(_make_weather_particles(25, 4.0, Vector3(10, 1.5, 8), Vector3(0, 3.0, 0), Vector3(0.1, 0.02, 0.05), 40.0, 0.05, 0.15, Vector3(0, 0.01, 0), Color(0.35, 0.4, 0.7, 0.35), _weather_tex(["smog1.png", "cloud3s.png"]), 0.9))
		_:
			root.add_child(_make_weather_particles(40, 1.6, Vector3(10, 0.2, 8), Vector3(0, 7.5, 0), Vector3(0, -0.2, 0.1), 40.0, 0.4, 1.2, Vector3(0, -0.4, 0), Color(1, 1, 1, 0.3), null))

func _add_battle_menu_button(viewport_size: Vector2) -> void:
	var btn := _button("Menu", Callable(), "Abre o menu de combate (ESC)")
	btn.name = "BattleMenuButton"
	btn.custom_minimum_size = Vector2(110, 40)
	btn.position = Vector2(viewport_size.x - 128, 14)
	btn.z_index = 35
	btn.pressed.connect(func() -> void:
		if battle_menu_open: _close_battle_menu()
		else: _open_battle_menu()
	)
	hud.add_child(btn)

func _add_battle_menu_overlay(viewport_size: Vector2) -> void:
	var wrap := Control.new()
	wrap.name = "BattleMenuOverlay"
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.z_index = 50
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(wrap)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(dim)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.17, 0.97)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.68, 0.35, 0.95)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2(viewport_size.x * 0.5 - 210, 80)
	wrap.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_label("MENU DE COMBATE", 26, Color("f0c27a")))
	col.add_child(_label("BGM", 16, Color("d5deea")))
	col.add_child(_bgm_picker_row())
	col.add_child(_button("Parar BGM", _stop_bgm_setting))
	col.add_child(_label("Clima / efeitos", 16, Color("d5deea")))
	var climate_ids := ["none", "rain", "snow", "leaves", "fog", "heat", "night"]
	var climate_names := ["Limpo", "Chuva", "Neve", "Folhas", "Névoa", "Calor", "Noite"]
	for i in range(climate_ids.size()):
		var mode: String = climate_ids[i]
		var mark := "● " if weather_mode == mode else "○ "
		col.add_child(_button(mark + climate_names[i], _set_weather.bind(mode)))
	var cam_lbl := "Câmera livre: sim (arraste botão direito)" if free_camera else "Câmera livre: não"
	col.add_child(_button(cam_lbl, _toggle_free_camera))
	col.add_child(_button("Vista: %s" % ("Lateral" if battle_view_mode == "lateral" else "Normal"), func() -> void:
		_toggle_battle_view()
		battle_menu_open = true
		_render_battle()
	))
	col.add_child(_button("Copiar caminho do report", _copy_session_report_path, "Copia o caminho do relatório JSONL desta sessão"))
	var report_hint := "Report: (ainda não iniciado)"
	if session_report != null and session_report.absolute_path() != "":
		report_hint = "Report: .../%s" % session_report.path.get_file()
	col.add_child(_label(report_hint, 14, Color("9aa7b8")))
	col.add_child(_button("Voltar ao menu principal", _return_to_main_menu, "Abandona o combate e volta ao título"))
	col.add_child(_button("Fechar (ESC)", _close_battle_menu))

func _add_pending_target_actions(viewport_size: Vector2) -> void:
	var col := VBoxContainer.new()
	col.name = "PendingTargetActions"
	col.add_theme_constant_override("separation", 8)
	col.z_index = 20
	# Posiciona perto da barra de HP / prévia do alvo (não no rodapé genérico).
	var anchor := Vector2(viewport_size.x * 0.5 - 110, viewport_size.y * 0.28)
	if camera != null and actor_nodes.has(pending_target_id):
		var body: Node3D = actor_nodes[pending_target_id]
		if is_instance_valid(body):
			var hp_root: Node3D = body.get_node_or_null("WorldHp")
			var world_pt := (hp_root.global_position if hp_root != null else body.global_position + Vector3(0, 2.4, 0))
			var screen: Vector2 = camera.unproject_position(world_pt)
			anchor = Vector2(clampf(screen.x - 110.0, 12.0, viewport_size.x - 240.0), clampf(screen.y + 18.0, 64.0, viewport_size.y - 180.0))
	col.position = anchor
	var actor: Dictionary = battle.actor_by_id(pending_target_id)
	var dmg := int(damage_preview_by_actor.get(pending_target_id, 0))
	var title := "Alvo: %s" % actor.get("name", "?")
	if dmg > 0:
		title += "  (−%d HP)" % dmg
	col.add_child(_label(title, 18, Color("f0e6d0")))
	# Barra 2D de prévia (HP atual + faixa vermelha) — legível na vista lateral.
	var hp := float(actor.get("hp", 0))
	var max_hp := maxf(1.0, float(actor.get("max_hp", 1)))
	var bar_w := 200.0
	var bar_h := 16.0
	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(bar_w, bar_h + 4)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.09, 0.12, 0.95)
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_wrap.add_child(bar_bg)
	var remain := clampf((hp - float(dmg)) / max_hp, 0.0, 1.0)
	var lost := clampf(float(dmg) / max_hp, 0.0, hp / max_hp)
	var fill_g := ColorRect.new()
	fill_g.color = Color(0.35, 0.95, 0.55, 1.0)
	fill_g.position = Vector2(0, 0)
	fill_g.size = Vector2(bar_w * remain, bar_h)
	bar_wrap.add_child(fill_g)
	if lost > 0.001:
		var fill_r := ColorRect.new()
		fill_r.color = Color(1.0, 0.22, 0.28, 1.0)
		fill_r.position = Vector2(bar_w * remain, 0)
		fill_r.size = Vector2(bar_w * lost, bar_h)
		bar_wrap.add_child(fill_r)
	col.add_child(bar_wrap)
	var conf := _button("Confirmar", Callable(), "Aplica a Manobra neste alvo")
	conf.custom_minimum_size = Vector2(200, 42)
	conf.pressed.connect(_confirm_pending_target)
	col.add_child(conf)
	var canc := _button("Cancelar", Callable(), "Volta à escolha de alvo")
	canc.custom_minimum_size = Vector2(200, 42)
	canc.pressed.connect(_cancel_pending_target)
	col.add_child(canc)
	hud.add_child(col)

func _show_block_popup(message: String) -> void:
	if session_report != null:
		session_report.log_ui("block_popup", {"message": message})
	# Toast curto: só o motivo, sem botão OK; fade-in → ~1s → fade-out.
	if hud == null:
		return
	var old := hud.get_node_or_null("BlockPopup")
	if old != null:
		old.queue_free()
	var blocker := Control.new()
	blocker.name = "BlockPopup"
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.z_index = 50
	blocker.modulate = Color(1, 1, 1, 0)
	hud.add_child(blocker)
	var vp := get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.94)
	style.set_border_width_all(2)
	style.border_color = Color(0.90, 0.58, 0.35, 0.95)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(minf(460.0, vp.x * 0.7), 0)
	var body := _label(message, 18, Color("f4f1ea"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size.x = mini(420.0, vp.x * 0.64)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	blocker.add_child(panel)
	# Posição aproximada; ajusta após layout
	panel.position = Vector2((vp.x - panel.custom_minimum_size.x) * 0.5, vp.y * 0.28)
	var tw := blocker.create_tween()
	tw.tween_property(blocker, "modulate:a", 1.0, 0.14)
	tw.tween_interval(1.0)
	tw.tween_property(blocker, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		if is_instance_valid(blocker):
			blocker.queue_free()
	)
	var recenter := func() -> void:
		if not is_instance_valid(panel):
			return
		var sz := panel.get_combined_minimum_size()
		if sz.x < 10.0:
			sz = panel.size
		panel.position = Vector2((vp.x - sz.x) * 0.5, vp.y * 0.28)
	get_tree().create_timer(0.02).timeout.connect(recenter)


func _card_require_status_reason(hand_index: int) -> String:
	# Bloqueia seleção quando falta Escuridão (ou outro requires_self_status).
	if battle == null or hand_index < 0 or hand_index >= battle.hand.size():
		return ""
	var card: Dictionary = battle.hand[hand_index]
	var definition: Dictionary = _card_def(str(card.get("id", "")))
	var source: Dictionary = battle.actor_by_id(int(card.get("owner", -1)))
	if source.is_empty():
		return ""
	for a in definition.get("actions", []):
		if typeof(a) != TYPE_ARRAY or a.is_empty():
			continue
		if str(a[0]) != "requires_self_status":
			continue
		var need_st := str(a[1] if a.size() > 1 else "?")
		var need_n: int = int(round(battle.resolve_amount(a[2] if a.size() > 2 else 1, source)))
		var have: int = battle._status_stacks(source, need_st)
		if have < need_n:
			var pretty := _status_label(need_st)
			return "Requer: %s %d" % [pretty, need_n]
	return ""

func _card_select_block_reason(hand_index: int) -> String:
	# Motivo que impede SELECIONAR a carta (Iniciativa, fileira, requisitos, jogadas…).
	if battle == null or hand_index < 0 or hand_index >= battle.hand.size():
		return "Carta inválida."
	var req := _card_require_status_reason(hand_index)
	if req != "":
		return req
	var reason := _card_unusable_reason(hand_index, -1)
	if reason != "":
		return reason
	# Fileira/posição: ataques sem Alcance da retaguarda (mesmo sem alvo escolhido).
	var card: Dictionary = battle.hand[hand_index]
	var definition: Dictionary = _card_def(str(card.get("id", "")))
	var source: Dictionary = battle.actor_by_id(int(card.get("owner", -1)))
	if source.is_empty():
		return ""
	var kind := str(definition.get("target", "ENEMY"))
	var enemy_kinds := ["ENEMY", "ALL_ENEMIES", "ALL_OTHERS", "RANDOM", "FRONT_ROW", "BACK_ROW", "CHAIN"]
	if kind in enemy_kinds and not bool(definition.get("reach", false)):
		if str(source.get("row", "")) == "back" and battle.living("ALLY").any(func(a): return a["row"] == "front"):
			return "Você não pode atacar sem Alcance da linha de trás."
	return ""

func _card_unusable_reason(hand_index: int, target_id: int = -1) -> String:
	if battle == null or hand_index < 0 or hand_index >= battle.hand.size():
		return "Carta inválida."
	var card: Dictionary = battle.hand[hand_index]
	var card_id := str(card.get("id", ""))
	# ent_ e combo_ (Manobras Combo de grupo) passam pelo EntityRuntime.
	if card_id.begins_with("ent_") or card_id.begins_with("combo_"):
		var reason: String = packs.entities.play_block_reason(battle, hand_index, target_id, chain_targets)
		if reason != "":
			return reason
	var source: Dictionary = battle.actor_by_id(int(card.get("owner", 0)))
	var definition: Dictionary = _card_def(card_id)
	var is_combo := str(definition.get("tier", card.get("tier", ""))) == "combo" or str(definition.get("class", "")) == "COMBO" or card_id.begins_with("combo_")
	if source.is_empty() or int(source.get("hp", 0)) <= 0:
		return "O herói desta carta está fora de combate."
	if battle.phase != "PLAYER":
		return "Não é a fase do jogador."
	for locked in ["stun", "bind", "bound", "banished", "finalized"]:
		if battle._has_status(source, locked):
			return "Você não pode usar Manobras enquanto estiver incapacitado."
	var combo_members: Array = definition.get("combo_members", card.get("combo_members", []))
	if is_combo or not combo_members.is_empty():
		for mid in combo_members:
			var alive := false
			for ally in battle.living("ALLY"):
				if str(ally.get("archetype", "")) == str(mid):
					alive = true
					break
			if not alive:
				return "Combo exige que todos os membros estejam vivos."
	# Instantâneo jogável: alinha com BattleState (só bloqueia outras cartas).
	if battle.has_method("must_play_instantaneo_first") and battle.must_play_instantaneo_first(card, definition, "ALLY"):
		return "Há Instantâneo jogável — jogue um Instantâneo antes de outras cartas."
	# Slow/Fast só modificam custo base > 0 (custo 0 / Instantâneo free permanece 0).
	var cost := _card_ini_cost(definition, card, source)
	if (not is_combo) and str(definition.get("class", "")) != "DESVANTAGEM":
		if int(battle.combo_zero_owners.get(int(source.get("id", -1)), 0)) > 0:
			cost = 0
	if cost > 0:
		if battle._has_status(source, "fast"): cost -= 1
		if battle._has_status(source, "slow"): cost += 1
	cost = maxi(0, cost)
	if int(battle.impulse) < cost:
		return "Você precisa de %d Iniciativa para usar esta Manobra." % cost
	var plays := 0 if bool(definition.get("free", false)) or is_combo else int(definition.get("plays", 1))
	if int(battle.card_plays) < plays:
		return "Você não tem jogadas de carta restantes neste turno."
	if not bool(definition.get("reach", false)) and str(source.get("row", "")) == "back":
		# Só bloqueia se ainda houver aliado na frente (mesma regra de can_reach)
		if battle.living("ALLY").any(func(a): return a["row"] == "front"):
			# Se o alvo for inimigo sem alcance — mensagem exemplar pedida
			if target_id >= 0:
				var tgt: Dictionary = battle.actor_by_id(target_id)
				if not tgt.is_empty() and tgt.get("side", "") == "ENEMY" and not battle.can_reach(source, tgt, definition):
					return "Você não pode atacar sem Alcance da linha de trás."
	if target_id >= 0:
		var target: Dictionary = battle.actor_by_id(target_id)
		if not target.is_empty() and target.get("side", "") != source.get("side", ""):
			if not battle.can_reach(source, target, definition):
				if not bool(definition.get("reach", false)) and str(source.get("row", "")) == "back":
					return "Você não pode atacar sem Alcance da linha de trás."
				if not bool(definition.get("reach", false)) and str(target.get("row", "")) == "back":
					return "Você não pode atingir a retaguarda sem Alcance."
				return "Alvo fora de alcance."
	return ""

func _copy_session_report_path() -> void:
	if session_report == null:
		feedback = "Report indisponível."
		return
	if not session_report.is_active():
		session_report.start("manual")
	var abs_path := session_report.copy_path_to_clipboard()
	if abs_path == "":
		feedback = "Não foi possível criar o report."
	else:
		feedback = "Caminho do report copiado:\n%s" % abs_path
		if session_report != null:
			session_report.log_ui("copy_report_path", {"path": abs_path})
	if battle != null:
		_render_battle()
	elif hud != null:
		# Menu: mostra o caminho num label temporário
		pass

func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "team", team)
	config.set_value("game", "owned_cards", owned_cards)
	config.set_value("game", "improvements", improvements)
	config.set_value("game", "best_stars", best_stars)
	config.set_value("game", "essence", essence)
	config.set_value("game", "loadout", loadout)
	config.set_value("settings", "sound_levels", sound_levels)
	config.set_value("settings", "shake_level", shake_level)
	config.set_value("settings", "reduce_flashes", reduce_flashes)
	config.set_value("settings", "reduce_motion", reduce_motion)
	config.set_value("settings", "animation_speed", animation_speed)
	config.set_value("settings", "battle_view_mode", battle_view_mode)
	config.set_value("settings", "sensitive_content", sensitive_content)
	config.set_value("settings", "bgm_track", bgm_track)
	config.set_value("settings", "weather_mode", weather_mode)
	config.set_value("settings", "free_camera", free_camera)
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
		owned_cards = config.get_value("game", "owned_cards", {})
		_ensure_owned_cards()
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
		battle_view_mode = str(config.get_value("settings", "battle_view_mode", battle_view_mode))
		if battle_view_mode not in ["normal", "lateral"]:
			battle_view_mode = "normal"
		sensitive_content = bool(config.get_value("settings", "sensitive_content", sensitive_content))
		bgm_track = str(config.get_value("settings", "bgm_track", bgm_track))
		_sync_bgm_pick_from_track()
		weather_mode = str(config.get_value("settings", "weather_mode", weather_mode))
		if weather_mode not in ["none", "rain", "snow", "leaves", "fog", "heat", "night"]:
			weather_mode = "none"
		free_camera = bool(config.get_value("settings", "free_camera", free_camera))
		animation_speed = clampf(float(config.get_value("settings", "animation_speed", animation_speed)), 0.5, 2.0)
