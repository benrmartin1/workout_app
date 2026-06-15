extends Control

const WorkoutStorage = preload("res://scripts/workout_storage.gd")

var workouts: Array = []
var edit_workout: Dictionary = {}
var editing_index: int = -1
var editing_exercise_index: int = -1
var pending_delete_action: String = ""
var pending_delete_index: int = -1

func _ready() -> void:
	print("[DEBUG] _ready start")
	$AppPanel/MainPanel/VBox/Header/AddWorkoutButton.pressed.connect(Callable(self, "_on_AddWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/TodayButton.pressed.connect(Callable(self, "_on_TodayButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/ExerciseHeader/AddExerciseButton.pressed.connect(Callable(self, "_on_AddExerciseButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/CancelWorkoutButton.pressed.connect(Callable(self, "_on_CancelWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/SaveWorkoutButton.pressed.connect(Callable(self, "_on_SaveWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/DeleteWorkoutButton.pressed.connect(Callable(self, "_on_DeleteWorkoutButton_pressed"))
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton.pressed.connect(Callable(self, "_on_SaveExerciseButton_pressed"))
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelExerciseButton_pressed"))
	$AppPanel/ConfirmDialog.confirmed.connect(Callable(self, "_on_ConfirmDialog_confirmed"))

	load_workouts()
	print("[DEBUG] loaded workouts", workouts.size())
	build_workout_list()
	print("[DEBUG] _ready complete")

func load_workouts() -> void:
	print("[DEBUG] load_workouts start")
	workouts = WorkoutStorage.load_workouts()
	print("[DEBUG] load_workouts finished", workouts.size())
	sort_workouts()
	print("[DEBUG] sort_workouts finished")

func save_workouts() -> void:
	print("[DEBUG] save_workouts start", workouts.size())
	if WorkoutStorage.save_workouts(workouts):
		workouts = WorkoutStorage.load_workouts()
		print("[DEBUG] save_workouts reload finished", workouts.size())
	sort_workouts()
	build_workout_list()
	print("[DEBUG] save_workouts complete")

func sort_workouts() -> void:
	workouts.sort_custom(_compare_workouts)

func _compare_workouts(a: Dictionary, b: Dictionary) -> bool:
	var date_a = a.get("date", "")
	var date_b = b.get("date", "")
	return false if date_a < date_b else true

func _normalize_workout_data(workout: Dictionary) -> void:
	if not workout.has("date"):
		workout["date"] = ""
	if not workout.has("exercises") or workout["exercises"] == null or workout["exercises"] is not Array:
		workout["exercises"] = []

func _get_workout_exercises() -> Array:
	print("[DEBUG] _get_workout_exercises start", edit_workout)
	var exercises = edit_workout.get("exercises")
	if exercises is Array:
		print("[DEBUG] _get_workout_exercises returned existing", exercises.size(), exercises)
		return exercises

	exercises = []
	edit_workout["exercises"] = exercises
	print("[DEBUG] _get_workout_exercises created new", exercises)
	return exercises

func build_workout_list() -> void:
	var list = $AppPanel/MainPanel/VBox/ScrollWrapper/WorkoutList
	while list.get_child_count() > 0:
		list.get_child(0).free()

	if workouts.is_empty():
		var label = Label.new()
		label.text = "No workouts yet. Tap Add Workout to begin."
		label.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(label)
		return

	for index in workouts.size():
		var workout = workouts[index]
		var item = Button.new()
		item.text = "%s — %d exercise(s)" % [workout.get("date", ""), workout.get("exercises", []).size()]
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.focus_mode = Control.FOCUS_NONE
		item.pressed.connect(Callable(self, "_on_WorkoutItem_pressed").bind(index))
		list.add_child(item)

func _on_AddWorkoutButton_pressed() -> void:
	open_workout_editor(-1)

func _on_TodayButton_pressed() -> void:
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text = _get_today_date()

func _get_today_date() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]

func show_main_screen() -> void:
	$AppPanel/MainPanel.show()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()

func show_workout_screen() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.show()
	$AppPanel/ExerciseEditor.hide()

func open_workout_editor(index: int) -> void:
	print("[DEBUG] open_workout_editor", index)
	$AppPanel/ExerciseEditor.hide()
	editing_index = index
	if index >= 0 and index < workouts.size():
		edit_workout = workouts[index].duplicate(true)
		_normalize_workout_data(edit_workout)
		$AppPanel/WorkoutEditor/VBoxContainer/WorkoutEditorTitle.text = "Edit Workout"
	else:
		edit_workout = {"date": _get_today_date(), "exercises": []}
		$AppPanel/WorkoutEditor/VBoxContainer/WorkoutEditorTitle.text = "Add Workout"

	print("[DEBUG] current edit_workout", edit_workout)
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text = edit_workout["date"]
	refresh_exercise_list()
	show_workout_screen()

func refresh_exercise_list() -> void:
	print("[DEBUG] refresh_exercise_list start")
	var list = $AppPanel/WorkoutEditor/VBoxContainer/ExerciseScroll/ExerciseList
	if list == null:
		print("[DEBUG] refresh_exercise_list list is null")
		return
	print("[DEBUG] refresh_exercise_list list", list)
	while list.get_child_count() > 0:
		print("[DEBUG] refresh_exercise_list freeing child", list.get_child(0))
		list.get_child(0).free()

	var exercises = _get_workout_exercises()
	if exercises == null:
		print("[DEBUG] refresh_exercise_list exercises is null")
		return
	print("[DEBUG] refresh_exercise_list exercises", exercises.size(), exercises)
	for exercise_index in exercises.size():
		var exercise = exercises[exercise_index]
		print("[DEBUG] refresh_exercise_list item", exercise_index, exercise)
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var summary = Label.new()
		summary.text = "%s — %s" % [exercise.get("name", "(no name)"), exercise.get("reps", "")]
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(summary)

		var edit_button = Button.new()
		edit_button.text = "Edit"
		edit_button.pressed.connect(Callable(self, "_on_EditExerciseButton_pressed").bind(exercise_index))
		row.add_child(edit_button)

		var delete_button = Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(Callable(self, "_on_DeleteExerciseButton_pressed").bind(exercise_index))
		row.add_child(delete_button)

		list.add_child(row)

func _on_WorkoutItem_pressed(index: int) -> void:
	open_workout_editor(index)

func _on_AddExerciseButton_pressed() -> void:
	editing_exercise_index = -1
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Exercise"
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.show()

func _on_EditExerciseButton_pressed(index: int) -> void:
	var exercises = _get_workout_exercises()
	print("[DEBUG] _on_EditExerciseButton_pressed", index, exercises.size())
	if index < 0 or index >= exercises.size():
		print("[DEBUG] invalid edit exercise index", index)
		return

	editing_exercise_index = index
	var exercise = exercises[index]
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameEdit.text = exercise.get("name", "")
	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = exercise.get("reps", "")
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = exercise.get("notes", "")
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Edit Exercise"
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.show()

func _on_DeleteExerciseButton_pressed(index: int) -> void:
	pending_delete_action = "exercise"
	pending_delete_index = index
	show_confirmation("Delete exercise", "Delete this exercise from the workout?")

func _on_SaveExerciseButton_pressed() -> void:
	var ename = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameEdit.text.strip_edges()
	var reps = $AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text.strip_edges()
	var notes = $AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text.strip_edges()

	var exercise = {
		"name": ename,
		"reps": reps,
		"notes": notes
	}

	print("[DEBUG] _on_SaveExerciseButton_pressed start", editing_exercise_index, edit_workout)
	var exercises = _get_workout_exercises()
	if exercises == null:
		print("[DEBUG] _on_SaveExerciseButton_pressed exercises returned null")
		return
	print("[DEBUG] _on_SaveExerciseButton_pressed exercises", exercises.size(), exercises)
	if editing_exercise_index >= 0 and editing_exercise_index < exercises.size():
		exercises[editing_exercise_index] = exercise
	else:
		exercises.append(exercise)
	edit_workout["exercises"] = exercises
	editing_exercise_index = -1

	print("[DEBUG] _on_SaveExerciseButton_pressed before refresh", edit_workout)
	refresh_exercise_list()
	print("[DEBUG] _on_SaveExerciseButton_pressed after refresh")
	$AppPanel/ExerciseEditor.hide()
	print("[DEBUG] _on_SaveExerciseButton_pressed after ExerciseEditor.hide")
	show_workout_screen()
	print("[DEBUG] _on_SaveExerciseButton_pressed after show_workout_screen")

func _on_CancelExerciseButton_pressed() -> void:
	$AppPanel/ExerciseEditor.hide()
	show_workout_screen()

func _on_SaveWorkoutButton_pressed() -> void:
	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	print("[DEBUG] _on_SaveWorkoutButton_pressed", date_text, editing_index, edit_workout)
	if date_text == "":
		print("[DEBUG] empty date_text, abort save")
		return

	edit_workout["date"] = date_text
	_normalize_workout_data(edit_workout)
	if editing_index >= 0 and editing_index < workouts.size():
		workouts[editing_index] = edit_workout.duplicate(true)
	else:
		workouts.append(edit_workout.duplicate(true))

	save_workouts()
	show_main_screen()

func _on_CancelWorkoutButton_pressed() -> void:
	show_main_screen()

func _on_DeleteWorkoutButton_pressed() -> void:
	if editing_index >= 0 and editing_index < workouts.size():
		pending_delete_action = "workout"
		show_confirmation("Delete workout", "Delete this workout and all recorded exercises?")

func _on_ConfirmDialog_confirmed() -> void:
	print("[DEBUG] _on_ConfirmDialog_confirmed", pending_delete_action, pending_delete_index)
	if pending_delete_action == "workout":
		if editing_index >= 0 and editing_index < workouts.size():
			workouts.remove_at(editing_index)
			save_workouts()
		show_main_screen()
	elif pending_delete_action == "exercise":
		var exercises = _get_workout_exercises()
		if pending_delete_index >= 0 and pending_delete_index < exercises.size():
			exercises.remove_at(pending_delete_index)
			edit_workout["exercises"] = exercises
			refresh_exercise_list()

	pending_delete_action = ""
	pending_delete_index = -1

func show_confirmation(title: String, message: String) -> void:
	print("[DEBUG] show_confirmation", title, message)
	$AppPanel/ConfirmDialog.title = title
	$AppPanel/ConfirmDialog.dialog_text = message
	$AppPanel/ConfirmDialog.popup_centered()
