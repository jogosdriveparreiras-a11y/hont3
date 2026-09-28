extends SceneTree
## Smoke: RmAnimPlayer must not crash on timings with se=null; Filha Dele logics resolve.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok := true
	var player: HotNRmAnimPlayer = HotNRmAnimPlayer.new()
	var host := Node3D.new()
	root.add_child(host)
	root.add_child(player)
	player.configure(host, null)
	if not player.has_assets():
		push_error("RmAnimPlayer has no assets")
		ok = false
	var timings: Array = [
		{"frame": 0, "se": null},
		{"frame": 0, "se": {"name": "", "volume": 90}},
		{"frame": 0, "se": {"name": "Attack1", "volume": 50}},
	]
	player._fire_timings(timings, 0)
	for logic in ["darkness", "cast", "slow", "debuff", "stun"]:
		var anim: Dictionary = player._resolve(str(logic))
		if anim.is_empty():
			push_error("resolve empty for %s" % logic)
			ok = false
		else:
			print("OK resolve %s -> %s / %s" % [logic, anim.get("name", ""), anim.get("animation1Name", "")])
	var d1: float = player.play_logic("darkness", Vector3.ZERO)
	var d2: float = player.play_logic("slow", Vector3(1, 0, 0))
	print("play darkness=%.3f slow=%.3f" % [d1, d2])
	# Let a few frames of tween callbacks run (would crash on null se before the fix)
	await create_timer(0.35).timeout
	if ok:
		print("RmSeNilSmoke PASS")
		quit(0)
	else:
		print("RmSeNilSmoke FAIL")
		quit(1)
