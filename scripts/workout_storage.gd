extends Node

const WORKOUTS_PATH := "user://workouts.json"
const EXERCISES_PATH := "user://exercises.json"

static func load_workouts() -> Array:
	return _load_json_file(WORKOUTS_PATH)

static func load_exercises() -> Array:
	return _load_json_file(EXERCISES_PATH)

static func _load_json_file(path: String) -> Array:
	var data: Array = []
	if not FileAccess.file_exists(path):
		return data

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return data

	var text: String = file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		return data

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", text, " at line ", json.get_error_line())
		return data

	var result = json.data
	if typeof(result) != TYPE_ARRAY:
		return data

	data = result
	return data

static func save_workouts(workouts: Array) -> bool:
	return _write_json_file(WORKOUTS_PATH, workouts, false)

static func save_exercises(exercises: Array) -> bool:
	return _write_json_file(EXERCISES_PATH, exercises, false)

static func export_workouts(workouts: Array, target_path: String) -> bool:
	return _write_json_file(target_path, workouts, true)

static func export_exercises(exercises: Array, target_path: String) -> bool:
	return _write_json_file(target_path, exercises, true)

static func _write_json_file(target_path: String, data: Array, create_dirs: bool) -> bool:
	if create_dirs:
		var dir_path = target_path.get_base_dir()
		if dir_path != "" and not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	var file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "    "))
	file.close()
	return true

static func create_auto_backup(workouts: Array, exercises: Array) -> bool:
	var datetime = Time.get_datetime_dict_from_system()
	var date_stamp = "%04d%02d%02d" % [datetime.year, datetime.month, datetime.day]
	var workouts_backup_path = "%s.%s.bak" % [WORKOUTS_PATH, date_stamp]
	var exercises_backup_path = "%s.%s.bak" % [EXERCISES_PATH, date_stamp]

	var workouts_ok = _write_json_file(workouts_backup_path, workouts, false)
	var exercises_ok = _write_json_file(exercises_backup_path, exercises, false)
	return workouts_ok and exercises_ok

static func get_latest_backup_filename() -> String:
	var dir = DirAccess.open("user://")
	if dir == null:
		return ""

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var latest_name = ""
	while file_name != "":
		if not dir.current_is_dir() and _is_backup_filename(file_name):
			if latest_name == "" or file_name > latest_name:
				latest_name = file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	return latest_name

static func _is_backup_filename(file_name: String) -> bool:
	var lower_name = file_name.to_lower()
	return lower_name.contains(".bak") and (lower_name.contains("workouts") or lower_name.contains("exercises"))
