extends RefCounted
class_name HotN3SessionReport
## Relatório append-only de sessão para debug (pt-BR).
## Arquivo: user://reports/hotn3_session_YYYYMMDD_HHMMSS.jsonl

var enabled := true
var path := ""
var started_at := ""
var _file: FileAccess = null
var _line_count := 0

func start(reason: String = "launch") -> String:
	if not enabled:
		return ""
	close()
	var stamp := _stamp_filename()
	started_at = Time.get_datetime_string_from_system(false, true)
	var dir_user := "user://reports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_user))
	path = "%s/hotn3_session_%s.jsonl" % [dir_user, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE_READ)
	if _file == null:
		# Fallback editor / sandbox
		var fallback_dir := "res://playtest_out/reports"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fallback_dir))
		path = "%s/hotn3_session_%s.jsonl" % [fallback_dir, stamp]
		_file = FileAccess.open(path, FileAccess.WRITE_READ)
	_line_count = 0
	log_event("session", {"event": "start", "reason": reason, "tz": "America/Sao_Paulo", "godot": Engine.get_version_info()})
	# Cópia espelho em playtest_out quando user:// funcionou (facilita achar no projeto).
	_maybe_mirror_header()
	return absolute_path()

func close() -> void:
	if _file != null:
		log_event("session", {"event": "end", "lines": _line_count})
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
	var row := {
		"t": Time.get_datetime_string_from_system(false, true),
		"cat": category,
		"data": payload,
	}
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

func _maybe_mirror_header() -> void:
	# Sem segundo arquivo contínuo: o caminho absoluto já basta.
	pass
