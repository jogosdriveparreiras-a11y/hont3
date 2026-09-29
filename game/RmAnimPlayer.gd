extends Node
class_name HotNRmAnimPlayer
## Plays RPG Maker MV/MZ Animations.json sheets frame-by-frame with SE.
## Assets: res://assets/fx/rm_animations/{Animations.json,sheets/,se/}

const ROOT := "res://assets/fx/rm_animations/"
const SHEETS := ROOT + "sheets/"
const SE_DIR := ROOT + "se/"
const JSON_PATH := ROOT + "Animations.json"
## RM classic: 5 columns per sheet row.
const COLS := 5
const FRAME_SEC := 1.0 / 15.0

var animations: Array = []
var host_3d: Node3D
var sound = null
var animation_speed := 1.0
var ready_ok := false

## Logical FX id → preferred animation name substrings (pt or en).
## Order matters for tie-breaks; _resolve also prefers existing sheets + longer matches.
const ALIAS := {
	"hit": ["Acerto Físico", "Acerto Especial 1", "Hit", "Physical"],
	"HitSP1": ["Acerto Especial 1", "Acerto Físico", "Hit"],
	"HitSP2": ["Acerto Especial 2", "Acerto com Efeito", "Hit"],
	"slash": ["Corte Físico", "Corte Especial 1", "Slash"],
	"SlashSP1": ["Corte Especial 1", "Corte Físico", "Slash"],
	"SlashSP2": ["Corte Especial 2", "Corte com Efeito", "Slash"],
	"SlashSP3": ["Corte Especial 3", "Corte Especial 1", "Slash"],
	"CrossSlash": ["Corte Especial 2", "Corte Especial 1", "Slash"],
	"CrossHit": ["Acerto Especial 1", "Acerto com Efeito", "Hit"],
	"claw": ["Garra Físico", "Garra Especial", "Garra", "Claw"],
	"ClawSP1": ["Garra Especial", "Garra Físico", "Claw"],
	"ClawSP2": ["Garra Especial", "Garra com Efeito", "Claw"],
	"CrossClaw": ["Garra Especial", "Garra de Fogo", "Claw"],
	"pierce": ["Perfuração Física", "Perfuração Especial 1", "Pierce"],
	"PierceSP1": ["Perfuração Especial 1", "Perfuração Física"],
	"PierceSP2": ["Perfuração Especial 2", "Perfuração com Efeito"],
	"arrow": ["Flecha Especial", "Perfuração Física", "Arrow"],
	"Arrow": ["Flecha Especial", "Perfuração Física"],
	"Shoot1": ["Flecha Especial", "Acerto Especial 2"],
	"heal": ["Cura Única 1", "Cura Única 2", "Cura", "Recovery", "Heal"],
	"Light1": ["Cura Única 1", "Recovery", "Light"],
	"Light2": ["Cura Única 2", "Cura Única 1", "Recovery"],
	"Light3": ["Cura Múltipla 1", "Cura Única 2"],
	"Light4": ["Cura Múltipla 2", "Cura Única 1"],
	"cast": ["Especial Geral 1", "Especial Geral 2", "Special1", "Habilidade", "Skill"],
	"Neutral1": ["Especial Geral 1", "Special1"],
	"Neutral2": ["Especial Geral 2", "Special2"],
	"Special1": ["Especial Geral 1", "Special1", "Flash"],
	"Special2": ["Especial Geral 2", "Special2"],
	"Special3": ["Flash", "Especial Geral 2", "Special3"],
	"guard": ["Fortalecer 2", "Fortalecer 3", "Fortalecer", "Barreira", "Barrier", "Guard"],
	"shield": ["Fortalecer 2", "Fortalecer 3", "Fortalecer", "Barreira", "Barrier"],
	"Protection": ["Fortalecer 3", "Fortalecer 2", "Barreira"],
	"Shield": ["Fortalecer 2", "Barreira", "Fortalecer"],
	"Reflection": ["Fortalecer 3", "Fortalecer 1", "Barreira"],
	"status": ["Enfraquecer 1", "Enfraquecer 2", "Estado", "State"],
	"stun": ["Paralisia", "Paralis", "Stun"],
	"StarsHit": ["Paralisia", "Confusão", "Acerto Especial 2"],
	"lightning": ["Relâmpago Único 1", "Relâmpago Único 2", "Relâmpago", "Trovão", "Thunder"],
	"thunder": ["Relâmpago Único 2", "Relâmpago Único 1", "Relâmpago", "Trovão", "Thunder"],
	"Thunder1": ["Relâmpago Único 1", "Thunder"],
	"Thunder2": ["Relâmpago Único 2", "Thunder"],
	"Thunder3": ["Relâmpago Múltiplo 1", "Relâmpago Único 1"],
	"BreathThunder": ["Relâmpago Múltiplo 2", "Relâmpago Único 2", "Sopro"],
	"fire": ["Incendiar Único 1", "Incendiar Único 2", "Fogo", "Fire"],
	"Fire1": ["Incendiar Único 1", "Fire"],
	"Fire2": ["Incendiar Único 2", "Incendiar Múltiplo 1"],
	"BreathFire": ["Incendiar Múltiplo 2", "Incendiar Único 1", "Sopro"],
	"ice": ["Congelar Único 1", "Congelar Único 2", "Gelo", "Ice"],
	"Ice1": ["Congelar Único 1", "Ice"],
	"Ice2": ["Congelar Único 2", "Congelar Múltiplo 1"],
	"darkness": ["Escuridão Único 1", "Escuridão Único 2", "Escuridão", "Darkness", "Dark"],
	"Darkness1": ["Escuridão Único 1", "Darkness"],
	"Darkness2": ["Escuridão Único 2", "Escuridão"],
	"Darkness3": ["Escuridão Múltiplo 1", "Escuridão Único 1"],
	"Darkness4": ["Escuridão Múltiplo 2", "Escuridão Único 2"],
	"BreathDarkness": ["Escuridão Múltiplo 1", "Escuridão Único 1", "Sopro"],
	"light": ["Cura Única 2", "Cura Única 1", "Recovery", "Luz", "Light", "Holy"],
	"BreathLight": ["Cura Múltipla 1", "Cura Única 2", "Sopro"],
	"bleed": ["Veneno", "Poison", "Damage"],
	"poison": ["Veneno", "Poison"],
	"PoisonAll": ["Veneno", "Poison"],
	"bind": ["Paralisia", "Enfraquecer 2", "Enfraquecer", "Vincular", "Curse", "Bind"],
	"absorb": ["Cura Única 1", "Recovery", "Absorver", "Absorb"],
	"blow": ["Varredura", "Impacto", "Blow"],
	"explosion": ["Incendiar Múltiplo 3", "Impacto", "Explosion"],
	"Explosion1": ["Incendiar Múltiplo 2", "Impacto"],
	"Explosion2": ["Incendiar Múltiplo 3", "Impacto"],
	"slow": ["Enfraquecer 2", "Enfraquecer 1", "Enfraquecer", "Sonolência"],
	"buff": ["Fortalecer 3", "Fortalecer 2", "Fortalecer"],
	"debuff": ["Enfraquecer 2", "Enfraquecer 1", "Enfraquecer"],
	"summon": ["Especial Geral 2", "Especial Geral 1", "Special3", "Flash"],
	"confusion": ["Confusão", "Chaos"],
	"banish": ["Escuridão Único 2", "Escuridão Único 1", "Morte", "Darkness"],
	"pull": ["Varredura", "Impacto", "Blow", "Hit", "Absorver", "Absorb"],
	"push": ["Varredura", "Impacto", "Blow"],
	"wind": ["Varredura", "Onda Sônica", "Wind"],
	"Wind1": ["Varredura", "Onda Sônica"],
	"Wind2": ["Onda Sônica", "Varredura"],
	"Song1": ["Canção", "Onda Sônica", "Grito"],
	"Smokescreen": ["Nevoeiro", "Escuridão Único 1"],
	"HeartMark1": ["Cura Única 1", "Flash", "Recovery"],
}

func configure(world: Node3D, audio = null) -> void:
	host_3d = world
	sound = audio
	_load()

func _load() -> void:
	animations.clear()
	ready_ok = false
	if not FileAccess.file_exists(JSON_PATH) and not ResourceLoader.exists(JSON_PATH):
		return
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return
	animations = parsed
	ready_ok = true

func has_assets() -> bool:
	return ready_ok and not animations.is_empty()

func play_logic(logic: String, world_pos: Vector3) -> float:
	if not has_assets() or host_3d == null:
		return 0.0
	var anim := _resolve(logic)
	if anim.is_empty():
		return 0.0
	return _play_anim(anim, world_pos)

func _sheet_exists(anim: Dictionary) -> bool:
	var sheet_name := str(anim.get("animation1Name", ""))
	if sheet_name == "":
		return false
	var tex_path := SHEETS + sheet_name + ".png"
	return ResourceLoader.exists(tex_path) or FileAccess.file_exists(tex_path)

func _resolve(logic: String) -> Dictionary:
	var key := logic.strip_edges().to_lower()
	var names: Array = ALIAS.get(key, [key])
	var best: Dictionary = {}
	var best_score := -1
	for anim in animations:
		if typeof(anim) != TYPE_DICTIONARY:
			continue
		var n := str(anim.get("name", ""))
		if n == "":
			continue
		var n_l := n.to_lower()
		var sheet_name := str(anim.get("animation1Name", ""))
		var sheet_l := sheet_name.to_lower()
		for ci in range(names.size()):
			var cand := str(names[ci])
			var c_l := cand.to_lower()
			var matched := false
			var score := 0
			if n_l == c_l:
				matched = true
				score = 1000 - ci
			elif c_l != "" and c_l in n_l:
				matched = true
				score = 500 + c_l.length() * 10 - ci
			elif n_l != "" and n_l in c_l:
				matched = true
				score = 300 + n_l.length() * 5 - ci
			elif sheet_l != "" and (c_l == sheet_l or c_l in sheet_l or sheet_l in c_l):
				matched = true
				score = 200 + mini(c_l.length(), sheet_l.length()) * 5 - ci
			if not matched:
				continue
			if _sheet_exists(anim):
				score += 5000
			if score > best_score:
				best_score = score
				best = anim
	if not best.is_empty():
		return best
	# Fallback: first anim with an existing sheet, else id 1 Hit
	for anim in animations:
		if typeof(anim) == TYPE_DICTIONARY and _sheet_exists(anim):
			return anim
	if animations.size() > 1 and typeof(animations[1]) == TYPE_DICTIONARY:
		return animations[1]
	return {}

func _play_anim(anim: Dictionary, world_pos: Vector3) -> float:
	var sheet_name := str(anim.get("animation1Name", ""))
	if sheet_name == "":
		return 0.0
	var tex_path := SHEETS + sheet_name + ".png"
	if not ResourceLoader.exists(tex_path) and not FileAccess.file_exists(tex_path):
		return 0.0
	var sheet: Texture2D = load(tex_path) as Texture2D
	if sheet == null:
		return 0.0
	var cell_w := sheet.get_width() / float(COLS)
	var cell_h := cell_w  # RM sheets are square cells typically
	var rows := maxi(1, int(round(sheet.get_height() / cell_h)))
	var frames: Array = anim.get("frames", [])
	var timings: Array = anim.get("timings", [])
	var root := Node3D.new()
	root.name = "RmAnim"
	root.position = world_pos + Vector3(0, 1.2, 0.02)
	host_3d.add_child(root)
	var sprites: Array[Sprite3D] = []
	for _i in range(8):
		var spr := Sprite3D.new()
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.transparent = true
		spr.shaded = false
		spr.double_sided = true
		spr.pixel_size = 0.01
		spr.visible = false
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		spr.texture = atlas
		root.add_child(spr)
		sprites.append(spr)
	var step := FRAME_SEC / maxf(0.01, animation_speed)
	# Tween bound to root: clear_actors()/queue_free kills playback instead of
	# leaving host_3d callbacks touching previously-freed sprites.
	var tw := root.create_tween()
	for fi in range(frames.size()):
		var frame_cells: Array = frames[fi] if typeof(frames[fi]) == TYPE_ARRAY else []
		var capture_fi := fi
		var capture_cells := frame_cells
		tw.tween_callback(func() -> void:
			if not is_instance_valid(root):
				return
			_apply_frame(sprites, capture_cells, cell_w, cell_h, rows)
			_fire_timings(timings, capture_fi)
		)
		tw.tween_interval(step)
	tw.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
	)
	return step * float(maxi(frames.size(), 1)) + 0.05

func stop_all() -> void:
	if host_3d == null or not is_instance_valid(host_3d):
		return
	for child in host_3d.get_children():
		if str(child.name).begins_with("RmAnim") and is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()

func _apply_frame(sprites: Array[Sprite3D], cells: Array, cell_w: float, cell_h: float, rows: int) -> void:
	for s in sprites:
		if not is_instance_valid(s):
			continue
		s.visible = false
	var used := 0
	for cell in cells:
		if typeof(cell) != TYPE_ARRAY or cell.size() < 8:
			continue
		if used >= sprites.size():
			break
		var pattern := int(cell[0])
		if pattern < 0:
			continue
		var spr: Sprite3D = sprites[used]
		used += 1
		if not is_instance_valid(spr):
			continue
		var col := pattern % COLS
		var row := mini(rows - 1, int(pattern / COLS))
		var atlas := spr.texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		spr.position = Vector3(float(cell[1]) * 0.01, -float(cell[2]) * 0.01, 0.0)
		var sc := float(cell[3]) / 100.0
		spr.scale = Vector3(sc, sc, 1.0)
		spr.modulate = Color(1, 1, 1, float(cell[6]) / 255.0)
		spr.flip_h = int(cell[5]) != 0
		spr.visible = true

func _fire_timings(timings: Array, frame_index: int) -> void:
	for t in timings:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if int(t.get("frame", -1)) != frame_index:
			continue
		# RM JSON often has "se": null — Dictionary.get default is NOT used when key exists.
		var se_raw = t.get("se", null)
		if typeof(se_raw) != TYPE_DICTIONARY:
			continue
		var se: Dictionary = se_raw
		var se_name := str(se.get("name", "")).strip_edges()
		if se_name == "" or se_name.to_lower() == "null" or sound == null:
			continue
		_play_se(se_name, float(se.get("volume", 90)) / 100.0)

func _play_se(name: String, vol: float) -> void:
	if name == "" or sound == null:
		return
	var path_ogg := SE_DIR + name + ".ogg"
	var path_wav := SE_DIR + name + ".wav"
	var path := path_ogg if FileAccess.file_exists(path_ogg) or ResourceLoader.exists(path_ogg) else path_wav
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		# Fall back to synthesized cue
		if sound.has_method("cue"):
			sound.cue("hit", "SFX")
		return
	var stream: AudioStream = null
	if path.ends_with(".ogg"):
		stream = AudioStreamOggVorbis.load_from_file(path)
	elif ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		return
	if host_3d == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(vol, 0.05, 1.0))
	host_3d.add_child(player)
	player.play()
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
