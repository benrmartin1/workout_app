extends Node

const WORKOUTS_PATH := "user://workouts.json"

static func load_workouts() -> Array:
	var workouts: Array = []
	if not FileAccess.file_exists(WORKOUTS_PATH):
		return workouts

	var file: FileAccess = FileAccess.open(WORKOUTS_PATH, FileAccess.READ)
	if file == null:
		return workouts

	var text: String = file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		return workouts

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", text, " at line ", json.get_error_line())
		return workouts

	var result = json.data
	if typeof(result) != TYPE_ARRAY:
		return workouts

	workouts = result
	for workout in workouts:
		if workout is Dictionary:
			if not workout.has("exercises") or workout["exercises"] == null or workout["exercises"] is not Array:
				workout["exercises"] = []
	return workouts

static func save_workouts(workouts: Array) -> bool:
	# var data = JSON.print(workouts, "    ")
	var data = JSON.stringify(workouts, "    ")
	var file: FileAccess = FileAccess.open(WORKOUTS_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(data)
	file.close()
	return true
