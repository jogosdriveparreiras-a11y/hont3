extends Node
class_name HotNFxPlayer
## FX playback for card anim_self / anim_target.
## Maps logical ids (and Effekseer basenames) to frame-by-frame billboards + particles.
## .efkefc under res://assets/fx/effekseer/ indexed for future EffekseerForGodot.
## RPG Maker MZ Animations.json/PNG/SE sheets: not shipped in-repo — MVP uses particles2d
## frame strips + SoundBus SFX cues (hit/cast/heal/status).

const PRESETS_PATH := "res://assets/fx/presets.json"
const EFK_DIR := "res://assets/fx/effekseer/"
const TEX_DIR := "res://assets/fx/particles2d/"

var presets: Dictionary = {}
var aliases: Dictionary = {}
var host_3d: Node3D
var host_2d: Control
var animation_speed := 1.0
var flash_enabled := true
var rm_player = null
var sound = null

## Named frame sequences built from particles2d textures (RM-style sheet playback MVP).
const FRAME_SETS := {
	"hit": ["flare.png", "flare2.png", "asterisk1.png", "asterisk1g.png"],
	"slash": ["line_ray1.png", "line_ray1f.png", "line1.png", "line2.png", "line3.png"],
	"claw": ["asterisk_thick1.png", "asterisk1.png", "asterisk_thin1.png", "flare.png"],
	"heal": ["shine1.png", "shine2.png", "circle.png", "circle2.png"],
	"cast": ["circle2.png", "circle3.png", "shine1.png"],
	"guard": ["hexagon_line1.png", "ring1.png", "hexagon_line2.png"],
	"shield": ["ring1.png", "hexagon_line1.png", "circle.png"],
	"status": ["star1.png", "asterisk1g.png", "bubble1.png"],
	"stun": ["star1.png", "asterisk1.png", "asterisk1g.png"],
	"lightning": ["thunder1.png", "thunder2.png", "line_ray1.png", "flare2.png"],
	"thunder": ["thunder2.png", "thunder1.png", "line_ray1f.png"],
	"fire": ["flame1.png", "flame1g.png", "flare.png"],
	"ice": ["snow1.png", "snow2.png", "circle2.png"],
	"darkness": ["smog1.png", "smog2.png", "circle3.png"],
	"light": ["shine2.png", "shine1.png", "circle.png"],
	"bleed": ["flare.png", "asterisk_thin1.png", "line_drop1.png"],
}

const SFX_FOR := {
	"hit": "hit", "slash": "hit", "claw": "hit", "bleed": "hit",
	"heal": "heal", "light": "heal",
	"cast": "cast", "darkness": "cast", "fire": "cast", "ice": "cast",
	"lightning": "cast", "thunder": "cast",
	"guard": "block", "shield": "block",
	"status": "status", "stun": "status",
}

func configure(world: Node3D, overlay: Control, audio = null) -> void:
	host_3d = world
	host_2d = overlay
	sound = audio
	_load_presets()
	if rm_player == null:
		rm_player = HotNRmAnimPlayer.new()
		add_child(rm_player)
	rm_player.configure(world, audio)

func _load_presets() -> void:
	presets.clear()
	aliases.clear()
	if ResourceLoader.exists(PRESETS_PATH):
		var f := FileAccess.open(PRESETS_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				presets = parsed
				aliases = parsed.get("aliases", {}) as Dictionary

func resolve_spec(fx_id: String) -> Dictionary:
	var key := fx_id.strip_edges()
	if key == "":
		return {}
	if aliases.has(key):
		return aliases[key]
	var efk_path := EFK_DIR + key + ".efkefc"
	if ResourceLoader.exists(efk_path) or FileAccess.file_exists(efk_path):
		var tint := Color("e1d2ff")
		var tex := "particle1.png"
		var kind := "burst"
		var lower := key.to_lower()
		if "thunder" in lower or "light" in lower:
			tint = Color("a9d5f4"); tex = "thunder1.png"
		elif "fire" in lower or "explosion" in lower:
			tint = Color("ff8a4a"); tex = "flame1.png"
		elif "ice" in lower:
			tint = Color("b8e4ff"); tex = "snow1.png"
		elif "heal" in lower:
			tint = Color("82d9af"); tex = "shine1.png"
		elif "slash" in lower or "claw" in lower or "hit" in lower:
			tint = Color("ec755c"); tex = "flare.png"; kind = "slash"
		elif "dark" in lower:
			tint = Color("6a4a8a"); tex = "smog1.png"; kind = "rise"
		elif "protect" in lower or "shield" in lower:
			tint = Color("a9d5f4"); tex = "ring1.png"; kind = "ring"
		return {"efk": key, "tex": tex, "tint": tint.to_html(false), "kind": kind, "logic": key}
	return {}

func play_list(ids: Array, world_pos: Vector3, timing: String = "parallel") -> float:
	if not flash_enabled or ids.is_empty():
		return 0.0
	var total := 0.0
	var max_d := 0.0
	for item in ids:
		var fx_id := str(item)
		var dur := play_one(fx_id, world_pos)
		max_d = maxf(max_d, dur)
		if timing == "wait_last":
			total += dur
	if timing == "wait_last":
		return total / maxf(0.01, animation_speed)
	return max_d / maxf(0.01, animation_speed)

func play_one(fx_id: String, world_pos: Vector3) -> float:
	var logic := _logic_key(fx_id)
	var spec := resolve_spec(fx_id)
	if spec.is_empty() and not FRAME_SETS.has(logic):
		logic = "hit"
	var kind := str(spec.get("kind", "burst")) if not spec.is_empty() else "burst"
	var tint := Color(str(spec.get("tint", "ffffff"))) if not spec.is_empty() else Color("ffd49b")
	if FRAME_SETS.has(logic):
		match logic:
			"heal", "light": tint = Color("82d9af")
			"slash", "claw", "hit", "bleed": tint = Color("ec755c")
			"lightning", "thunder": tint = Color("a9d5f4")
			"darkness": tint = Color("6a4a8a")
			"fire": tint = Color("ff8a4a")
			"guard", "shield": tint = Color("a9d5f4")
			"status", "stun": tint = Color("ba9dea")
			"cast": tint = Color("e1d2ff")
	rm_player.animation_speed = animation_speed if rm_player != null else 1.0
	var rm_dur := 0.0
	if rm_player != null and rm_player.has_assets():
		rm_dur = float(rm_player.play_logic(logic, world_pos))
	if rm_dur <= 0.0:
		_play_sfx(logic)
	var frame_dur := _spawn_frame_anim(logic, world_pos, tint) if rm_dur <= 0.0 else 0.0
	if rm_dur > 0.0:
		frame_dur = rm_dur
	_spawn_3d(world_pos, tint, kind, _first_tex(logic, spec))
	_spawn_2d_overlay(world_pos, tint, kind, _first_tex(logic, spec))
	return maxf(frame_dur, 0.36 if kind == "burst" else 0.32)

func _logic_key(fx_id: String) -> String:
	var key := fx_id.strip_edges()
	if aliases.has(key):
		var a: Dictionary = aliases[key]
		# Prefer alias key itself as logic if it's a known set
		if FRAME_SETS.has(key):
			return key
		var efk := str(a.get("efk", key)).to_lower()
		for cand in FRAME_SETS.keys():
			if cand in efk or efk in cand:
				return str(cand)
		return key if FRAME_SETS.has(key) else str(a.get("kind", "hit"))
	var lower := key.to_lower()
	for cand in FRAME_SETS.keys():
		if cand == lower or cand in lower:
			return str(cand)
	if "hit" in lower or "slash" in lower or "claw" in lower:
		return "hit"
	if "heal" in lower:
		return "heal"
	if "thunder" in lower or "lightn" in lower:
		return "lightning"
	if "dark" in lower:
		return "darkness"
	if "fire" in lower or "explod" in lower:
		return "fire"
	if "guard" in lower or "shield" in lower or "protect" in lower:
		return "guard"
	return key if FRAME_SETS.has(key) else "hit"

func _first_tex(logic: String, spec: Dictionary) -> Texture2D:
	var name := ""
	if FRAME_SETS.has(logic) and not FRAME_SETS[logic].is_empty():
		name = str(FRAME_SETS[logic][0])
	elif not spec.is_empty():
		name = str(spec.get("tex", "particle1.png"))
	if name == "":
		return null
	var path := TEX_DIR + name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _play_sfx(logic: String) -> void:
	if sound == null:
		return
	var cue := str(SFX_FOR.get(logic, "hit"))
	if sound.has_method("cue"):
		sound.cue(cue, "SFX")

func _spawn_frame_anim(logic: String, world_pos: Vector3, tint: Color) -> float:
	if host_3d == null or not FRAME_SETS.has(logic):
		return 0.0
	var names: Array = FRAME_SETS[logic]
	var frames: Array[Texture2D] = []
	for n in names:
		var path := TEX_DIR + str(n)
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				frames.append(tex)
	if frames.is_empty():
		return 0.0
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = 0.012
	sprite.modulate = tint
	sprite.position = world_pos + Vector3(0, 1.25, 0.05)
	sprite.texture = frames[0]
	host_3d.add_child(sprite)
	var step := 0.055 / maxf(0.01, animation_speed)
	var tw := host_3d.create_tween()
	for i in range(frames.size()):
		var idx := i
		tw.tween_callback(func() -> void:
			if is_instance_valid(sprite):
				sprite.texture = frames[idx]
				sprite.scale = Vector3.ONE * (1.0 + 0.15 * float(idx) / float(maxi(frames.size() - 1, 1)))
		)
		tw.tween_interval(step)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.12 / maxf(0.01, animation_speed))
	tw.tween_callback(sprite.queue_free)
	return step * float(frames.size()) + 0.14

func _spawn_3d(world_pos: Vector3, tint: Color, kind: String, tex: Texture2D) -> void:
	if host_3d == null:
		return
	var particles := CPUParticles3D.new()
	particles.amount = 18 if kind != "slash" else 10
	particles.lifetime = (0.42 if kind == "rise" else 0.28) / maxf(0.01, animation_speed)
	particles.one_shot = true
	particles.explosiveness = 0.85 if kind != "rise" else 0.15
	particles.direction = Vector3.UP if kind != "slash" else Vector3(1, 0.2, 0)
	particles.spread = 25.0 if kind == "slash" else (360.0 if kind == "burst" else 70.0)
	particles.gravity = Vector3(0, -1.2 if kind == "rise" else -2.5, 0)
	particles.initial_velocity_min = 1.2 if kind != "slash" else 3.0
	particles.initial_velocity_max = 3.8 if kind != "slash" else 6.0
	particles.color = tint
	if tex != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.45, 0.45)
		particles.mesh = mesh
		particles.material_override = mat
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.1
		particles.mesh = mesh
	particles.position = world_pos + Vector3(0, 1.15, 0)
	host_3d.add_child(particles)
	particles.emitting = true
	var cleanup := host_3d.create_tween()
	cleanup.tween_interval(0.85 / maxf(0.01, animation_speed))
	cleanup.finished.connect(particles.queue_free)

func _spawn_2d_overlay(world_pos: Vector3, tint: Color, kind: String, tex: Texture2D) -> void:
	if host_2d == null or host_2d.get_viewport() == null:
		return
	var cam := host_2d.get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen: Vector2 = cam.unproject_position(world_pos + Vector3(0, 1.2, 0))
	var burst := GPUParticles2D.new()
	burst.amount = 14
	burst.lifetime = 0.35 / maxf(0.01, animation_speed)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.position = screen
	burst.z_index = 40
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0) if kind == "rise" else Vector3(1, 0, 0) if kind == "slash" else Vector3(0, 0, 0)
	mat.spread = 180.0 if kind == "burst" else 40.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 140.0
	mat.gravity = Vector3(0, 80, 0)
	mat.color = tint
	burst.process_material = mat
	if tex != null:
		burst.texture = tex
	host_2d.add_child(burst)
	burst.emitting = true
	var cleanup := host_2d.create_tween()
	cleanup.tween_interval(0.7 / maxf(0.01, animation_speed))
	cleanup.finished.connect(burst.queue_free)

func play_card_anims(definition: Dictionary, self_pos: Vector3, target_pos: Vector3) -> float:
	var timing := str(definition.get("anim_timing", definition.get("timing", "parallel")))
	var self_ids: Array = definition.get("anim_self", [])
	var target_ids: Array = definition.get("anim_target", [])
	if typeof(self_ids) != TYPE_ARRAY:
		self_ids = []
	if typeof(target_ids) != TYPE_ARRAY:
		target_ids = []
	if self_ids.is_empty():
		self_ids = ["cast"]
	if target_ids.is_empty():
		target_ids = ["hit"]
	if timing == "wait_last":
		var d1 := play_list(self_ids, self_pos, "parallel")
		var d2 := play_list(target_ids, target_pos, "parallel")
		return d1 + d2
	return maxf(play_list(self_ids, self_pos, "parallel"), play_list(target_ids, target_pos, "parallel"))

func list_available_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key in aliases.keys():
		out.append(str(key))
	for key in FRAME_SETS.keys():
		if not out.has(str(key)):
			out.append(str(key))
	var dir := DirAccess.open(EFK_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".efkefc"):
				out.append(fname.trim_suffix(".efkefc"))
			fname = dir.get_next()
	out.sort()
	return out
