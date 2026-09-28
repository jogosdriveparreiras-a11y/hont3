extends Node
class_name HotNFxPlayer
## Stub FX playback for card anim_self / anim_target.
## Maps logical ids (and raw Effekseer basenames) to GPUParticles2D / CPUParticles3D.
## .efkefc files under res://assets/fx/effekseer/ are indexed for a future EffekseerForGodot plugin.

const PRESETS_PATH := "res://assets/fx/presets.json"
const EFK_DIR := "res://assets/fx/effekseer/"
const TEX_DIR := "res://assets/fx/particles2d/"

var presets: Dictionary = {}
var aliases: Dictionary = {}
var host_3d: Node3D
var host_2d: Control
var animation_speed := 1.0
var flash_enabled := true

func configure(world: Node3D, overlay: Control) -> void:
	host_3d = world
	host_2d = overlay
	_load_presets()

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
	# Raw Effekseer basename (HitSP1, Thunder1, …)
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
		elif "heal" in lower or "light" in lower:
			tint = Color("82d9af"); tex = "shine1.png"
		elif "slash" in lower or "claw" in lower or "hit" in lower:
			tint = Color("ec755c"); tex = "flare.png"; kind = "slash"
		elif "dark" in lower:
			tint = Color("6a4a8a"); tex = "smog1.png"; kind = "rise"
		elif "protect" in lower or "shield" in lower:
			tint = Color("a9d5f4"); tex = "ring1.png"; kind = "ring"
		return {"efk": key, "tex": tex, "tint": tint.to_html(false), "kind": kind}
	return {}

## Play a list of FX on a world position. Returns approximate duration (seconds).
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
	var spec := resolve_spec(fx_id)
	if spec.is_empty():
		return 0.18
	var kind := str(spec.get("kind", "burst"))
	var tint := Color(str(spec.get("tint", "ffffff")))
	var tex_name := str(spec.get("tex", "particle1.png"))
	var tex: Texture2D = null
	var tex_path := TEX_DIR + tex_name
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	# Prefer 3D burst in the arena; overlay 2D flash if camera/overlay available.
	_spawn_3d(world_pos, tint, kind, tex)
	_spawn_2d_overlay(world_pos, tint, kind, tex)
	match kind:
		"rise":
			return 0.55
		"slash":
			return 0.32
		"ring":
			return 0.45
		_:
			return 0.36

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
		# Billboard quads with texture
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.35, 0.35)
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

## Convenience: play card anim fields on caster/target world positions.
func play_card_anims(definition: Dictionary, self_pos: Vector3, target_pos: Vector3) -> float:
	var timing := str(definition.get("anim_timing", definition.get("timing", "parallel")))
	var self_ids: Array = definition.get("anim_self", [])
	var target_ids: Array = definition.get("anim_target", [])
	if typeof(self_ids) != TYPE_ARRAY:
		self_ids = []
	if typeof(target_ids) != TYPE_ARRAY:
		target_ids = []
	# Toda carta precisa de FX no conjurador e no alvo.
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
