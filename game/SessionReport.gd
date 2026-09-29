extends RefCounted
class_name HotN3SessionReport
## Relatório append-only de sessão para debug (pt-BR).
## Arquivo: user://reports/hotn3_session_YYYYMMDD_HHMMSS.jsonl
## Eventos estruturados ricos: fases, compras, jogadas, alvos, dano/cura,
## status, posturas, mortes, purge, IA, Instantâneo, recompras, INI, mão.

var enabled := true
var path := ""
var started_at := ""
var _file: FileAccess = null
var _line_count := 0
var _seq := 0

func start(reason: String = "launch") -> String:
	# Nunca deve bloquear o boot do jogo: falhas de IO só desligam o report.
	if not enabled:
		return ""
	close()
	var stamp := _stamp_filename()
	started_at = Time.get_datetime_string_from_system(false, true)
	path = ""
	_file = null
	_line_count = 0
	_seq = 0
	var candidates: Array[String] = ["user://reports", "res://playtest_out/reports"]
	for dir_user in candidates:
		var abs_dir := ProjectSettings.globalize_path(dir_user)
		if abs_dir == "" or abs_dir.begins_with("user://") or abs_dir.begins_with("res://"):
			DirAccess.make_dir_recursive_absolute(dir_user)
		else:
			DirAccess.make_dir_recursive_absolute(abs_dir)
		var try_path := "%s/hotn3_session_%s.jsonl" % [dir_user, stamp]
		var f := FileAccess.open(try_path, FileAccess.WRITE)
		if f != null:
			_file = f
			path = try_path
			break
		push_warning("HotN3SessionReport: falha ao abrir %s (err=%s)" % [try_path, FileAccess.get_open_error()])
	if _file == null:
		path = ""
		push_warning("HotN3SessionReport: sem arquivo gravável nesta tentativa.")
		return ""
	log_event("session", {"event": "start", "reason": reason, "tz": "America/Sao_Paulo", "godot": Engine.get_version_info()})
	return absolute_path()

func close() -> void:
	if _file != null:
		log_event("session", {"event": "end", "lines": _line_count, "seq": _seq})
		_file.flush()
		_file = null

func absolute_path() -> String:
	if path == "":
		return ""
	return ProjectSettings.globalize_path(path)

func is_active() -> bool:
	return enabled and _file != null

func log_event(category: String, payload: Dictionary = {}) -> void:
	if not enabled or _file == null:
		return
	_seq += 1
	var row := {
		"t": Time.get_datetime_string_from_system(false, true),
		"seq": _seq,
		"cat": category,
		"data": payload,
	}
	if not is_instance_valid(_file):
		_file = null
		return
	_file.seek_end()
	_file.store_line(JSON.stringify(row))
	_file.flush()
	_line_count += 1

func log_ui(action: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["action"] = action
	log_event("ui", data)

func log_card(action: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["action"] = action
	log_event("card", data)

func log_battle(action: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["action"] = action
	log_event("battle", data)

func log_ai(action: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["action"] = action
	log_event("ai", data)

func log_error(message: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["message"] = message
	log_event("error", data)

## Atalho genérico usado por BattleState.report_cb.
func emit_structured(category: String, action: String, detail: Dictionary = {}) -> void:
	var data := detail.duplicate(true)
	data["action"] = action
	log_event(category, data)

func snapshot_hand(side: String, cards: Array, label: String = "") -> void:
	var rows: Array = []
	for c in cards:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		rows.append({
			"uid": int(c.get("uid", -1)),
			"id": str(c.get("id", "")),
			"owner": int(c.get("owner", -1)),
			"class": str(c.get("class", "")),
			"instant": bool(c.get("instant", false)),
			"ephemeral": bool(c.get("ephemeral", false)),
		})
	log_battle("hand_snapshot", {"side": side, "label": label, "count": rows.size(), "cards": rows})

func snapshot_piles(side: String, deck_n: int, discard_n: int, exhausted_n: int, hand_n: int, label: String = "") -> void:
	log_battle("pile_counts", {
		"side": side, "label": label,
		"deck": deck_n, "discard": discard_n, "exhausted": exhausted_n, "hand": hand_n,
	})

func snapshot_actors(actors: Array, label: String = "") -> void:
	var rows: Array = []
	for a in actors:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var st: Dictionary = a.get("statuses", {})
		var st_ids: Array = []
		if typeof(st) == TYPE_DICTIONARY:
			for k in st.keys():
				st_ids.append(str(k))
		rows.append({
			"id": int(a.get("id", -1)),
			"name": str(a.get("name", "")),
			"archetype": str(a.get("archetype", "")),
			"side": str(a.get("side", "")),
			"hp": int(a.get("hp", 0)),
			"max_hp": int(a.get("max_hp", 0)),
			"row": str(a.get("row", "")),
			"is_summon": bool(a.get("is_summon", false)),
			"summoner_id": int(a.get("summoner_id", -1)),
			"transformed": bool(a.get("transformed", false)),
			"statuses": st_ids,
		})
	log_battle("actors_snapshot", {"label": label, "count": rows.size(), "actors": rows})

func copy_path_to_clipboard() -> String:
	var abs_path := absolute_path()
	if abs_path != "":
		DisplayServer.clipboard_set(abs_path)
	return abs_path

func _stamp_filename() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]
