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

## Logical FX id → animation name substring (pt or en).
const ALIAS := {
	"hit": ["Acerto Físico", "Hit", "Physical"],
	"slash": ["Corte Físico", "Slash"],
	"claw": ["Garra", "Claw"],
	"heal": ["Cura", "Recovery", "Heal"],
	"cast": ["Habilidade", "Skill"],
	"guard": ["Barreira", "Barrier", "Guard"],
	"shield": ["Barreira", "Barrier"],
	"status": ["Estado", "State"],
	"stun": ["Paralis", "Stun"],
	"lightning": ["Trovão", "Thunder"],
	"thunder": ["Trovão", "Thunder"],
	"fire": ["Fogo", "Fire"],
	"ice": ["Gelo", "Ice"],
	"darkness": ["Escuridão", "Darkness", "Dark"],
	"light": ["Luz", "Light", "Holy"],
	"bleed": ["Veneno", "Poison", "Damage"],
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

func _resolve(logic: String) -> Dictionary:
	var key := logic.strip_edges().to_lower()
	var names: Array = ALIAS.get(key, [key])
	for anim in animations:
		if typeof(anim) != TYPE_DICTIONARY:
			continue
		var n := str(anim.get("name", ""))
		for cand in names:
			if str(cand).to_lower() in n.to_lower() or n.to_lower() in str(cand).to_lower():
				return anim
	# Fallback: id 1 Hit
	if animations.size() > 1 and typeof(animations[1]) == TYPE_DICTIONARY:
		return animations[1]
	return {}

func _play_anim(anim: Dictionary, world_pos: Vector3) -> float:
	var sheet_name := str(anim.get("animation1Name", ""))
	if sheet_name == "":
		return 0.0
	var tex_path := SHEETS + sheet_name + ".png"
	if not ResourceLoader.exists(tex_path) and not FileAccess.file_exists(tex_path):
		# try without path case
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
	var tw := host_3d.create_tween()
	for fi in range(frames.size()):
		var frame_cells: Array = frames[fi] if typeof(frames[fi]) == TYPE_ARRAY else []
		var capture_fi := fi
		var capture_cells := frame_cells
		tw.tween_callback(func() -> void:
			_apply_frame(sprites, capture_cells, cell_w, cell_h, rows)
			_fire_timings(timings, capture_fi)
		)
		tw.tween_interval(step)
	tw.tween_callback(root.queue_free)
	return step * float(maxi(frames.size(), 1)) + 0.05

func _apply_frame(sprites: Array[Sprite3D], cells: Array, cell_w: float, cell_h: float, rows: int) -> void:
	for s in sprites:
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
		var se: Dictionary = t.get("se", {})
		var se_name := str(se.get("name", ""))
		if se_name == "" or sound == null:
			continue
		_play_se(se_name, float(se.get("volume", 90)) / 100.0)

func _play_se(name: String, vol: float) -> void:
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
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(vol, 0.05, 1.0))
	host_3d.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
