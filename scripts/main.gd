extends Control

enum DELETE_ACTION {WORKOUT, EXERCISE, GLOBAL_EXERCISE, NONE}

const WorkoutStorage = preload("res://scripts/workout_storage.gd")
const Version = "1.2.2"

var workouts: Array = []
var exercises: Array = []
var edit_workout: Dictionary = {}
var editing_workout_index: int = -1
var editing_exercise_index: int = -1
# Index of the exercise being edited, or -1 if adding a new exercise
var editing_global_exercise_index: int = -1

var pending_delete_action: DELETE_ACTION = DELETE_ACTION.NONE
var pending_delete_index: int = -1

enum EXERCISE_SORT {DEFAULT, CATEGORY, NAME}
var exercise_sort_mode: int = EXERCISE_SORT.DEFAULT

# Dirty flags to indicate unsaved changes
var workout_dirty: bool = false
var exercise_dirty: bool = false
var global_exercise_dirty: bool = false

func _persist_current_workout() -> void:
	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	if date_text != "":
		edit_workout["date"] = date_text
	_normalize_workout_data(edit_workout)

	if editing_workout_index >= 0 and editing_workout_index < workouts.size():
		workouts[editing_workout_index] = edit_workout.duplicate(true)
	else:
		workouts.append(edit_workout.duplicate(true))
		if editing_workout_index < 0:
			editing_workout_index = workouts.size() - 1

	save_workouts()
	workout_dirty = false

func _set_workout_dirty(dirty: bool) -> void:
	workout_dirty = dirty
	if dirty:
		_persist_current_workout()

func _set_exercise_dirty(dirty: bool) -> void:
	exercise_dirty = dirty
	var btn = $AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton
	if btn == null:
		return
	btn.text = "Save*" if exercise_dirty else "Save"

func _set_global_exercise_dirty(dirty: bool) -> void:
	global_exercise_dirty = dirty
	var btn = $AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton
	if btn == null:
		return
	btn.text = "Save*" if global_exercise_dirty else "Save"

func _ready() -> void:
	print("[DEBUG] _ready start")
	
	# Main panel buttons
	$AppPanel/MainPanel/TabContainer/WorkoutTab/Header/AddWorkoutButton.pressed.connect(Callable(self, "_on_AddWorkoutButton_pressed"))
	$AppPanel/MainPanel/TabContainer/ExerciseTab/ExerciseHeader/AddGlobalExerciseButton.pressed.connect(Callable(self, "_on_AddGlobalExerciseButton_pressed"))
	$AppPanel/MainPanel/TabContainer/ExerciseTab/SortHBox/SortDropdown.item_selected.connect(Callable(self, "_on_ExerciseSort_selected"))
	
	# Global exercise editor buttons
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton.pressed.connect(Callable(self, "_on_SaveGlobalExerciseButton_pressed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelGlobalExerciseButton_pressed"))
	
	# Exercise details buttons
	$AppPanel/GlobalExerciseDetails/VBoxContainer/ExerciseDetailsButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelExerciseDetailsButton_pressed"))

	# Workout editor buttons
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.pressed.connect(Callable(self, "_on_DateDoneButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.focus_entered.connect(Callable(self, "_on_DateEdit_focus_entered"))
	$AppPanel/WorkoutEditor/VBoxContainer/ExerciseHeader/AddExerciseButton.pressed.connect(Callable(self, "_on_AddExerciseButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/BackWorkoutButton.pressed.connect(Callable(self, "_on_BackWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/DeleteWorkoutButton.pressed.connect(Callable(self, "_on_DeleteWorkoutButton_pressed"))
	
	# Exercise editor buttons
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton.pressed.connect(Callable(self, "_on_SaveExerciseButton_pressed"))
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelExerciseButton_pressed"))
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/DeleteExerciseButton.pressed.connect(Callable(self, "_on_DeleteExerciseButton_pressed"))
	
	# Confirmation dialog popup
	$AppPanel/ConfirmDialog.confirmed.connect(Callable(self, "_on_ConfirmDialog_confirmed"))

	# Connect editor change signals to mark dirty state
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text_changed.connect(Callable(self, "_on_WorkoutEditor_field_changed"))
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.item_selected.connect(Callable(self, "_on_ExerciseDropdown_selected"))
	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text_changed.connect(Callable(self, "_on_ExerciseEditor_field_changed"))
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text_changed.connect(Callable(self, "_on_ExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text_changed.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text_changed.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown.item_selected.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))

	load_workouts()
	load_exercises()
	print("[DEBUG] loaded workouts", workouts.size(), "exercises", exercises.size())
	build_workout_list()
	build_global_exercise_list()
	set_version()
	print("[DEBUG] _ready complete")

func load_workouts() -> void:
	print("[DEBUG] load_workouts start")
	workouts = WorkoutStorage.load_workouts()
	print("[DEBUG] load_workouts finished", workouts.size())
	print("[DEBUG] sort_workouts finished")

func load_exercises() -> void:
	print("[DEBUG] load_exercises start")
	exercises = WorkoutStorage.load_exercises()
	print("[DEBUG] load_exercises finished", exercises.size())

func save_workouts() -> void:
	print("[DEBUG] save_workouts start", workouts.size())
	sort_workouts()
	if WorkoutStorage.save_workouts(workouts):
		workouts = WorkoutStorage.load_workouts()
		print("[DEBUG] save_workouts reload finished", workouts.size())
	build_workout_list()
	print("[DEBUG] save_workouts complete")

func save_exercises() -> void:
	print("[DEBUG] save_exercises start", exercises.size())
	if WorkoutStorage.save_exercises(exercises):
		exercises = WorkoutStorage.load_exercises()
		print("[DEBUG] save_exercises reload finished", exercises.size())
	build_global_exercise_list()
	print("[DEBUG] save_exercises complete")

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
	var exercises_list = edit_workout.get("exercises")
	if exercises_list is Array:
		print("[DEBUG] _get_workout_exercises returned existing", exercises_list.size(), exercises_list)
		return exercises_list

	exercises_list = []
	edit_workout["exercises"] = exercises_list
	print("[DEBUG] _get_workout_exercises created new", exercises_list)
	return exercises_list

func build_workout_list() -> void:
	var list = $AppPanel/MainPanel/TabContainer/WorkoutTab/WorkoutListContainer/ScrollWrapper/WorkoutList
	while list.get_child_count() > 0:
		list.get_child(0).free()

	if workouts.is_empty():
		var label = Label.new()
		label.text = "No workouts yet.\nTap Add Workout to begin."
		label.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(label)
		return

	for index in workouts.size():
		var workout = workouts[index]
		var item = Button.new()
		var exercises_num = workout.get("exercises", []).size()
		item.text = "%s — %d exercise%s" % [workout.get("date", ""), exercises_num, "s" if exercises_num != 1 else ""]
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.focus_mode = Control.FOCUS_NONE
		item.pressed.connect(Callable(self, "_on_WorkoutItem_pressed").bind(index))
		list.add_child(item)

func build_global_exercise_list() -> void:
	var list = $AppPanel/MainPanel/TabContainer/ExerciseTab/ExerciseListContainer/ExerciseScrollWrapper/ExerciseListMain
	while list.get_child_count() > 0:
		list.get_child(0).free()

	if exercises.is_empty():
		var label = Label.new()
		label.text = "No exercises yet.\nTap Add Exercise to create one."
		label.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(label)
		return

	var exercise_order = []
	for i in exercises.size():
		exercise_order.append(i)
	if exercise_sort_mode == EXERCISE_SORT.NAME:
		exercise_order.sort_custom(_compare_exercise_indices_by_name)
	elif exercise_sort_mode == EXERCISE_SORT.CATEGORY:
		exercise_order.sort_custom(_compare_exercise_indices_by_category)

	for sorted_index in exercise_order.size():
		var exercise_index = exercise_order[sorted_index]
		var exercise = exercises[exercise_index]
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var exercise_name = Label.new()
		exercise_name.text = exercise.get("name", "(no name)")
		# Allow long names to wrap onto multiple lines
		exercise_name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		# Keep the label filling available space so it wraps instead of expanding
		exercise_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		exercise_name.size_flags_stretch_ratio = 4.0
		row.add_child(exercise_name)

		var view_button = Button.new()
		view_button.text = "View"
		# view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# view_button.focus_mode = Control.FOCUS_NONE
		view_button.pressed.connect(Callable(self, "_on_ExerciseItem_pressed").bind(exercise_index))
		row.add_child(view_button)
		
		var edit_button = Button.new()
		edit_button.text = "Edit"
		# edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_button.pressed.connect(Callable(self, "_on_EditGlobalExerciseButton_pressed").bind(exercise_index))
		row.add_child(edit_button)

		var delete_button = Button.new()
		delete_button.text = "Del"
		# delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		delete_button.pressed.connect(Callable(self, "_on_DeleteGlobalExerciseButton_pressed").bind(exercise_index))
		row.add_child(delete_button)
		
		if not exercise.has("category") or exercise["category"] < 0 or exercise.get("name", "").strip_edges() == "":
			exercise_name.text = "⚠ " + exercise_name.text
		
		list.add_child(row)

func set_version() -> void:
	$AppPanel/MainPanel/TabContainer/SettingsTab/Version.text = "Version: %s" % Version

func _on_WorkoutEditor_field_changed(_arg: String) -> void:
	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	edit_workout["date"] = date_text
	_set_workout_dirty(true)

func _on_ExerciseEditor_field_changed(_arg = null) -> void:
	_set_exercise_dirty(true)

func _on_ExerciseDropdown_selected(_index: int) -> void:
	var exercise_name = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.text
	var previous_reps = _get_previous_exercise_reps(exercise_name)
	$AppPanel/ExerciseEditor/VBoxContainer/PreviousRepsRow/RepsEdit.text = previous_reps
	_set_exercise_dirty(true)

func _on_ExerciseSort_selected(index: int) -> void:
	exercise_sort_mode = index
	build_global_exercise_list()

func _get_previous_exercise_reps(exercise_name: String) -> String:
	# Search through workouts in order, starting on the current workout index - 1
	print("[DEBUG] _get_previous_exercise_reps ", exercise_name, " in workout ", editing_workout_index)
	for workout_idx in range(editing_workout_index + 1, workouts.size()):
		print("[DEBUG] _get_previous_exercise_reps checking workout index ", workout_idx)
		var workout = workouts[workout_idx]
		if workout is Dictionary:
			var workout_exercises = workout.get("exercises", [])
			if workout_exercises is Array:
				for exercise in workout_exercises:
					if exercise is Dictionary and exercise.get("name", "") == exercise_name:
						print("[DEBUG] _get_previous_exercise_reps found previous ", exercise.get("reps", ""), " in workout ", workout.get("date", ""))
						return workout.get("date") + ": " + exercise.get("reps", "")
	# No previous occurrence found
	return "First time!"

func _on_GlobalExerciseEditor_field_changed(_arg = null) -> void:
	_set_global_exercise_dirty(true)

func _on_AddWorkoutButton_pressed() -> void:
	open_workout_editor(-1)

func _on_AddGlobalExerciseButton_pressed() -> void:
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Global Exercise"
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown.select(-1)
	editing_global_exercise_index = -1
	_set_global_exercise_dirty(false)
	show_globalexercise_editor()

func _on_DateDoneButton_pressed() -> void:
	# Unfocus the date edit box to remove virtual keyboard on mobile devices
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.release_focus()
	# Disable date done button until the date edit box is focused again
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.disabled = true

func _on_DateEdit_focus_entered() -> void:
	# Enable date done button when the date edit box is focused
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.disabled = false

func _get_today_date() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]

func show_main_screen() -> void:
	$AppPanel/MainPanel.show()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()
	$AppPanel/GlobalExerciseDetails.hide()

func show_workout_screen() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.show()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()
	$AppPanel/GlobalExerciseDetails.hide()

func show_exercise_editor() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.show()
	$AppPanel/GlobalExerciseEditor.hide()
	$AppPanel/GlobalExerciseDetails.hide()

func show_globalexercise_editor() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.show()
	$AppPanel/GlobalExerciseDetails.hide()

func show_exercise_details(exercise_name: String) -> void:
	$AppPanel/GlobalExerciseDetails/VBoxContainer/ExerciseDetailsTitle.text = exercise_name
	build_exercise_history_list(exercise_name)
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()
	$AppPanel/GlobalExerciseDetails.show()

func _on_CancelExerciseDetailsButton_pressed() -> void:
	show_main_screen()

func open_workout_editor(index: int) -> void:
	print("[DEBUG] open_workout_editor", index)
	editing_workout_index = index

	# Reset dirty state when opening editor
	_set_workout_dirty(false)
	if index >= 0 and index < workouts.size():
		edit_workout = workouts[index].duplicate(true)
		_normalize_workout_data(edit_workout)
		$AppPanel/WorkoutEditor/VBoxContainer/WorkoutEditorTitle.text = "Edit Workout"
		$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/DeleteWorkoutButton.visible = true
	else:
		edit_workout = {"date": _get_today_date(), "exercises": []}
		$AppPanel/WorkoutEditor/VBoxContainer/WorkoutEditorTitle.text = "Add Workout"
		$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/DeleteWorkoutButton.visible = false

	print("[DEBUG] current edit_workout", edit_workout)
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text = edit_workout["date"]
	build_exercise_list()
	show_workout_screen()

func build_exercise_list() -> void:
	print("[DEBUG] build_exercise_list start")
	var list = $AppPanel/WorkoutEditor/VBoxContainer/ExerciseListContainer/ExerciseScroll/ExerciseList
	if list == null:
		print("[DEBUG] build_exercise_list list is null")
		return
	print("[DEBUG] build_exercise_list list", list)
	while list.get_child_count() > 0:
		list.get_child(0).free()

	var workout_exercises = _get_workout_exercises()
	if workout_exercises == null:
		print("[DEBUG] build_exercise_list exercises is null")
		return
	print("[DEBUG] build_exercise_list exercises", workout_exercises.size())
	for exercise_index in workout_exercises.size():
		var exercise = workout_exercises[exercise_index]
		print("[DEBUG] build_exercise_list item", exercise_index, exercise)
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var summary = Label.new()
		summary.text = "%s — %s" % [exercise.get("name", "(no name)"), exercise.get("reps", "")]
		# Allow long exercise names or reps to wrap onto multiple lines
		summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		# Keep the label filling available space so it wraps instead of expanding
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(summary)

		var edit_button = Button.new()
		edit_button.text = "Edit"
		edit_button.pressed.connect(Callable(self, "_on_EditExerciseButton_pressed").bind(exercise_index))
		row.add_child(edit_button)

		# Add warning symbol if exercise is not in global exercise list or has empty name
		var exercise_name = exercise.get("name", "").strip_edges()
		var exercise_found = false
		for global_exercise in exercises:
			if global_exercise.get("name", "").strip_edges() == exercise_name:
				exercise_found = true
				break
		if not exercise_found or exercise_name == "":
			summary.text = "⚠ " + summary.text

		list.add_child(row)

func _on_WorkoutItem_pressed(index: int) -> void:
	open_workout_editor(index)

func _on_ExerciseItem_pressed(index: int) -> void:
	if index < 0 or index >= exercises.size():
		return
	var exercise_name = exercises[index].get("name", "")
	print("[DEBUG] _on_ExerciseItem_pressed", index, exercise_name)
	show_exercise_details(exercise_name)

func build_exercise_history_list(exercise_name: String) -> void:
	var list = $AppPanel/GlobalExerciseDetails/VBoxContainer/ExerciseListContainer/ExerciseScroll/ExerciseList
	while list.get_child_count() > 0:
		list.get_child(0).free()

	var history: Array = []
	for workout_index in workouts.size():
		var workout = workouts[workout_index]
		if workout is Dictionary:
			var workout_date = workout.get("date", "")
			var workout_exercises = workout.get("exercises", [])
			if workout_exercises is Array:
				for exercise in workout_exercises:
					if exercise is Dictionary and exercise.get("name", "") == exercise_name:
						history.append({
						"date": workout_date,
						"reps": exercise.get("reps", ""),
						"workout_index": workout_index
					})

	history.sort_custom(_compare_exercise_history)

	if history.is_empty():
		var label = Label.new()
		label.text = "No history for %s." % exercise_name
		label.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(label)
		return

	for entry in history:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var date_button = Button.new()
		date_button.text = entry.get("date", "")
		date_button.focus_mode = Control.FOCUS_NONE
		date_button.size_flags_horizontal = Control.SIZE_FILL
		date_button.pressed.connect(Callable(self, "_on_HistoryWorkoutButton_pressed").bind(entry.get("workout_index")))
		row.add_child(date_button)

		var reps_label = Label.new()
		reps_label.text = entry.get("reps", "")
		reps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(reps_label)

		list.add_child(row)

func _compare_exercise_indices_by_name(a: int, b: int) -> bool:
	# The function should return true if the first element should be moved before the second one, otherwise it should return false
	var name_a = exercises[a].get("name", "").to_lower()
	var name_b = exercises[b].get("name", "").to_lower()
	return name_a < name_b 

func _compare_exercise_indices_by_category(a: int, b: int) -> bool:
	# The function should return true if the first element should be moved before the second one, otherwise it should return false
	var cat_a = exercises[a].get("category", -1)
	var cat_b = exercises[b].get("category", -1)
	if cat_a == cat_b:
		return _compare_exercise_indices_by_name(a, b)  
	if cat_a == -1:
		return true  
	if cat_b == -1:
		return false
	return cat_a < cat_b 

func _compare_exercise_history(a: Dictionary, b: Dictionary) -> bool:
	var date_a = a.get("date", "")
	var date_b = b.get("date", "")
	return false if date_a < date_b else true

func _on_HistoryWorkoutButton_pressed(workout_index: int) -> void:
	open_workout_editor(workout_index)

func _on_EditGlobalExerciseButton_pressed(index: int) -> void:
	print("[DEBUG] _on_EditGlobalExerciseButton_pressed", index)
	if index < 0 or index >= exercises.size():
		print("[DEBUG] invalid edit exercise index", index)
		return

	editing_global_exercise_index = index
	var exercise = exercises[index]
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Edit Global Exercise"
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text = exercise.get("name", "")
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = exercise.get("notes", "")
	var dropdown = $AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown
	dropdown.select(exercise.get("category", -1)) # TODO?
	_set_global_exercise_dirty(false)
	show_globalexercise_editor()

func _on_DeleteGlobalExerciseButton_pressed(index: int) -> void:
	pending_delete_action = DELETE_ACTION.GLOBAL_EXERCISE
	pending_delete_index = index
	show_confirmation("Delete exercise", "Delete this exercise? This cannot be undone.")

func _on_DeleteExerciseButton_pressed() -> void:
	pending_delete_action = DELETE_ACTION.EXERCISE
	pending_delete_index = editing_exercise_index
	show_confirmation("Delete exercise", "Delete this exercise from the workout?")

func _on_AddExerciseButton_pressed() -> void:
	var dropdown = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown
	# Add exercise list to dropdown
	dropdown.clear()
	for exercise in exercises:
		dropdown.add_item(exercise.get("name", "(no name)"))
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.select(-1)

	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/PreviousRepsRow/RepsEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Exercise"
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/DeleteExerciseButton.visible = false
	_set_exercise_dirty(false)
	show_exercise_editor()

func _on_EditExerciseButton_pressed(index: int) -> void:
	var workout_exercises = _get_workout_exercises()
	print("[DEBUG] _on_EditExerciseButton_pressed", index, workout_exercises.size())
	if index < 0 or index >= workout_exercises.size():
		print("[DEBUG] invalid edit exercise index", index)
		return

	editing_exercise_index = index
	var exercise = workout_exercises[index]
	var dropdown = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown
	# Populate dropdown with exercise names and select the current one
	dropdown.clear()
	var selected_index = -1
	for i in range(exercises.size()):
		var ex = exercises[i]
		dropdown.add_item(ex.get("name", "(no name)"))
		if ex.get("name", "") == exercise.get("name", ""):
			selected_index = i
	dropdown.select(selected_index)

	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = exercise.get("reps", "")
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = exercise.get("notes", "")
	var previous_reps = _get_previous_exercise_reps(exercise.get("name", ""))
	$AppPanel/ExerciseEditor/VBoxContainer/PreviousRepsRow/RepsEdit.text = previous_reps
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Edit Exercise"
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/DeleteExerciseButton.visible = true
	_set_exercise_dirty(false)
	show_exercise_editor()

func _on_SaveExerciseButton_pressed() -> void:
	var ename = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.text.strip_edges()
	var reps = $AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text.strip_edges()
	var notes = $AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text.strip_edges()

	if $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.get_selected() < 0:
		print("[DEBUG] no exercise selected from dropdown, abort save")
		# TODO: show error in the app
		return

	if ename == "":
		print("[DEBUG] empty exercise name, abort save")
		# TODO: show error in the app
		return

	var exercise = {
		"name": ename,
		"reps": reps,
		"notes": notes
	}

	print("[DEBUG] _on_SaveExerciseButton_pressed start", editing_exercise_index, edit_workout)
	var workout_exercises = _get_workout_exercises()
	if workout_exercises == null:
		print("[DEBUG] _on_SaveExerciseButton_pressed exercises returned null")
		return
	print("[DEBUG] _on_SaveExerciseButton_pressed exercises", workout_exercises.size(), workout_exercises)
	if editing_exercise_index >= 0 and editing_exercise_index < workout_exercises.size():
		workout_exercises[editing_exercise_index] = exercise
	else:
		workout_exercises.append(exercise)
	edit_workout["exercises"] = workout_exercises
	editing_exercise_index = -1

	print("[DEBUG] _on_SaveExerciseButton_pressed before refresh", edit_workout)
	build_exercise_list()
	print("[DEBUG] _on_SaveExerciseButton_pressed after refresh")
	# Saving an exercise edits the current workout; mark workout dirty until workout is saved
	_set_exercise_dirty(false)
	_set_workout_dirty(true)
	$AppPanel/ExerciseEditor.hide()
	print("[DEBUG] _on_SaveExerciseButton_pressed after ExerciseEditor.hide")
	show_workout_screen()
	print("[DEBUG] _on_SaveExerciseButton_pressed after show_workout_screen")

func _on_CancelExerciseButton_pressed() -> void:
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/DeleteExerciseButton.visible = false
	_set_exercise_dirty(false)
	show_workout_screen()

func _on_SaveGlobalExerciseButton_pressed() -> void:
	var ename = $AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text.strip_edges()
	var notes = $AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text.strip_edges()
	var category_index = $AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown.get_selected_id()

	var exercise = {
		"name": ename,
		"notes": notes,
		"category": category_index
	}

	if ename == "" or category_index < 0:
		print("[DEBUG] empty exercise name or invalid category, abort save")
		# TODO: show error in the app
		return

	# Ensure exercise does not already exist
	for i in range(exercises.size()):
		if i != editing_global_exercise_index and exercises[i]["name"] == ename:
			print("[DEBUG] Exercise with name '%s' already exists, cannot save." % ename)
			# TODO: show error in the app
			return

	var old_name = ""
	if editing_global_exercise_index >= 0 and editing_global_exercise_index < exercises.size():
		old_name = exercises[editing_global_exercise_index].get("name", "")

	if editing_global_exercise_index >= 0:
		if editing_global_exercise_index < exercises.size():
			exercises[editing_global_exercise_index] = exercise
		else:
			print("[DEBUG] invalid editing_global_exercise_index", editing_global_exercise_index)
	else:
		exercises.append(exercise)

	if old_name != "" and old_name != ename:
		for workout in workouts:
			if workout is Dictionary:
				var workout_exercises = workout.get("exercises", [])
				if workout_exercises is Array:
					for exercise_entry in workout_exercises:
						if exercise_entry is Dictionary and exercise_entry.get("name", "") == old_name:
							exercise_entry["name"] = ename
		save_workouts()

	save_exercises()
	_set_global_exercise_dirty(false)
	show_main_screen()
	$AppPanel/GlobalExerciseEditor.hide()

func _on_CancelGlobalExerciseButton_pressed() -> void:
	$AppPanel/GlobalExerciseEditor.hide()
	_set_global_exercise_dirty(false)
	show_main_screen()

func _on_BackWorkoutButton_pressed() -> void:
	show_main_screen()

func _on_DeleteWorkoutButton_pressed() -> void:
	if editing_workout_index >= 0 and editing_workout_index < workouts.size():
		pending_delete_action = DELETE_ACTION.WORKOUT
		pending_delete_index = editing_workout_index
		show_confirmation("Delete workout", "Delete this workout and all recorded exercises?")

func _on_ConfirmDialog_confirmed() -> void:
	print("[DEBUG] _on_ConfirmDialog_confirmed, action: ", pending_delete_action, " index:", pending_delete_index)

	match pending_delete_action:
		DELETE_ACTION.WORKOUT:
			if pending_delete_index >= 0 and pending_delete_index < workouts.size():
				workouts.remove_at(pending_delete_index)
				save_workouts()
				editing_workout_index = -1
				show_main_screen()
		DELETE_ACTION.EXERCISE:
			var workout_exercises = _get_workout_exercises()
			if pending_delete_index >= 0 and pending_delete_index < workout_exercises.size():
				workout_exercises.remove_at(pending_delete_index)
				edit_workout["exercises"] = workout_exercises
				build_exercise_list()
				# Mark workout dirty since exercises changed
				_set_workout_dirty(true)
				editing_exercise_index = -1
				show_workout_screen()
		DELETE_ACTION.GLOBAL_EXERCISE:
			if pending_delete_index >= 0 and pending_delete_index < exercises.size():
				exercises.remove_at(pending_delete_index)
				editing_global_exercise_index = -1
				save_exercises()
		DELETE_ACTION.NONE:
			print("[DEBUG] No delete action to perform.")

func show_confirmation(title: String, message: String) -> void:
	print("[DEBUG] show_confirmation", title, message)
	$AppPanel/ConfirmDialog.title = title
	$AppPanel/ConfirmDialog.dialog_text = message
	$AppPanel/ConfirmDialog.popup_centered()
