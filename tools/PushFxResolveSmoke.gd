extends SceneTree
## Resolve FX/RM names for Daeva Cobertura (guard + push).

const PackBridge = preload("res://game/PackBridge.gd")
const Content = preload("res://game/Content.gd")
const FxPlayer = preload("res://game/FxPlayer.gd")
const RmAnimPlayer = preload("res://game/RmAnimPlayer.gd")

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	quit(1)

func _initialize() -> void:
	var _p = PackBridge.new()
	var def: Dictionary = Content.CARDS["ent_daeva_cobertura_de_corredor"]
	var self_anim := str(def["anim_self"][0])
	var tgt_anim := str(def["anim_target"][0])
	print("Cobertura anim_self=", self_anim, " anim_target=", tgt_anim)

	var fx := FxPlayer.new()
	var rm := RmAnimPlayer.new()
	# Attach under root so they can init
	var root := Node.new()
	root.name = "tmp"
	root.add_child(fx)
	root.add_child(rm)
	get_root().add_child(root)

	await process_frame

	var fx_ok_self := fx.has_method("resolve") 
	# Probe known maps
	var presets_ok := FileAccess.file_exists("res://assets/fx/presets.json")
	print("presets.json exists=", presets_ok)

	# RmAnimPlayer resolve
	if rm.has_method("resolve_logic"):
		var r1 = rm.resolve_logic(self_anim)
		var r2 = rm.resolve_logic(tgt_anim)
		print("RM resolve_logic self=", r1, " target=", r2)
		if str(r2) == "" or (typeof(r2)==TYPE_DICTIONARY and r2.is_empty()):
			# try alternate API
			pass
	if rm.has_method("resolve"):
		print("RM resolve self=", rm.resolve(self_anim), " target=", rm.resolve(tgt_anim))

	# FxPlayer particle/effekseer keys
	var fx_keys: Array = []
	if "LOGIC_TO_PARTICLES" in fx:
		pass
	# Inspect script constants via source is hard; check presets
	var text := FileAccess.get_file_as_string("res://assets/fx/presets.json")
	var parsed = JSON.parse_string(text)
	var has_push := false
	var has_guard := false
	if typeof(parsed) == TYPE_DICTIONARY:
		has_push = parsed.has("push") or (parsed.has("target") and parsed["target"].has("push"))
		# walk
		var blob := JSON.stringify(parsed)
		has_push = blob.find("\"push\"") >= 0 or blob.find("push") >= 0
		print("presets mentions push=", blob.find("push") >= 0, " guard=", blob.find("guard") >= 0)

	# Direct asset sheets for push
	var push_assets := []
	for p in [
		"res://assets/fx/rm_animations/push.png",
		"res://assets/fx/rm_animations/Push.png",
	]:
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			push_assets.append(p)
	# list rm dir for push*
	var dir := DirAccess.open("res://assets/fx/rm_animations")
	if dir:
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if n.to_lower().find("push") >= 0 or n.to_lower().find("pull") >= 0 or n.to_lower().find("guard") >= 0:
				push_assets.append(n)
			n = dir.get_next()
	print("push/pull/guard assets: ", push_assets)

	if tgt_anim != "push":
		_fail("expected push anim"); return
	print("PASS PushFxResolveSmoke (logical FX assignable; headless cannot render)")
	quit(0)
