extends Control

const WorkoutStorage = preload("res://scripts/workout_storage.gd")

var workouts: Array = []
var exercises: Array = []
var edit_workout: Dictionary = {}
var editing_workout_index: int = -1
var editing_exercise_index: int = -1
# Index of the exercise being edited, or -1 if adding a new exercise
var editing_global_exercise_index: int = -1
var pending_delete_action: String = ""
var pending_delete_index: int = -1
var current_tab: int = 0

func _ready() -> void:
	print("[DEBUG] _ready start")
	
	# Tab switching
	$AppPanel/MainPanel/MainVBox/TabBar.tab_changed.connect(Callable(self, "_on_TabBar_changed"))
	
	# Main panel buttons
	$AppPanel/MainPanel/MainVBox/TabContainer/WorkoutTab/Header/AddWorkoutButton.pressed.connect(Callable(self, "_on_AddWorkoutButton_pressed"))
	$AppPanel/MainPanel/MainVBox/TabContainer/ExerciseTab/ExerciseHeader/AddGlobalExerciseButton.pressed.connect(Callable(self, "_on_AddGlobalExerciseButton_pressed"))
	
	# Global exercise editor buttons
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton.pressed.connect(Callable(self, "_on_SaveGlobalExerciseButton_pressed"))

	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelGlobalExerciseButton_pressed"))

	# Workout editor buttons
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/TodayButton.pressed.connect(Callable(self, "_on_TodayButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/ExerciseHeader/AddExerciseButton.pressed.connect(Callable(self, "_on_AddExerciseButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/CancelWorkoutButton.pressed.connect(Callable(self, "_on_CancelWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/SaveWorkoutButton.pressed.connect(Callable(self, "_on_SaveWorkoutButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/EditorButtonBar/DeleteWorkoutButton.pressed.connect(Callable(self, "_on_DeleteWorkoutButton_pressed"))
	
	# Exercise editor buttons
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/SaveExerciseButton.pressed.connect(Callable(self, "_on_SaveExerciseButton_pressed"))
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseButtonBar/CancelExerciseButton.pressed.connect(Callable(self, "_on_CancelExerciseButton_pressed"))
	
	$AppPanel/ConfirmDialog.confirmed.connect(Callable(self, "_on_ConfirmDialog_confirmed"))

	load_workouts()
	load_exercises()
	print("[DEBUG] loaded workouts", workouts.size(), "exercises", exercises.size())
	build_workout_list()
	build_exercise_list()
	print("[DEBUG] _ready complete")

func load_workouts() -> void:
	print("[DEBUG] load_workouts start")
	workouts = WorkoutStorage.load_workouts()
	print("[DEBUG] load_workouts finished", workouts.size())
	sort_workouts()
	print("[DEBUG] sort_workouts finished")

func load_exercises() -> void:
	print("[DEBUG] load_exercises start")
	exercises = WorkoutStorage.load_exercises()
	print("[DEBUG] load_exercises finished", exercises.size())

func save_workouts() -> void:
	print("[DEBUG] save_workouts start", workouts.size())
	if WorkoutStorage.save_workouts(workouts):
		workouts = WorkoutStorage.load_workouts()
		print("[DEBUG] save_workouts reload finished", workouts.size())
	sort_workouts()
	build_workout_list()
	print("[DEBUG] save_workouts complete")

func save_exercises() -> void:
	print("[DEBUG] save_exercises start", exercises.size())
	if WorkoutStorage.save_exercises(exercises):
		exercises = WorkoutStorage.load_exercises()
		print("[DEBUG] save_exercises reload finished", exercises.size())
	build_exercise_list()
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

func _on_TabBar_changed(tab_index: int) -> void:
	print("[DEBUG] Tab changed to", tab_index)
	current_tab = tab_index
	
	if tab_index == 0:
		$AppPanel/MainPanel/MainVBox/TabContainer/WorkoutTab.show()
		$AppPanel/MainPanel/MainVBox/TabContainer/ExerciseTab.hide()
	elif tab_index == 1:
		$AppPanel/MainPanel/MainVBox/TabContainer/WorkoutTab.hide()
		$AppPanel/MainPanel/MainVBox/TabContainer/ExerciseTab.show()

func build_workout_list() -> void:
	var list = $AppPanel/MainPanel/MainVBox/TabContainer/WorkoutTab/ScrollWrapper/WorkoutList
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

func build_exercise_list() -> void:
	var list = $AppPanel/MainPanel/MainVBox/TabContainer/ExerciseTab/ExerciseScrollWrapper/ExerciseListMain
	while list.get_child_count() > 0:
		list.get_child(0).free()

	if exercises.is_empty():
		var label = Label.new()
		label.text = "No exercises yet.\nTap Add Exercise to create one."
		label.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(label)
		return

	for index in exercises.size():
		var exercise = exercises[index]
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_button = Button.new()
		name_button.text = exercise.get("name", "(no name)")
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.focus_mode = Control.FOCUS_NONE
		name_button.pressed.connect(Callable(self, "_on_ExerciseItem_pressed").bind(index))
		row.add_child(name_button)
		
		var edit_button = Button.new()
		edit_button.text = "Edit"
		edit_button.pressed.connect(Callable(self, "_on_EditGlobalExerciseButton_pressed").bind(index))
		row.add_child(edit_button)
		
		var delete_button = Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(Callable(self, "_on_DeleteGlobalExerciseButton_pressed").bind(index))
		row.add_child(delete_button)
		
		list.add_child(row)

func _on_AddWorkoutButton_pressed() -> void:
	open_workout_editor(-1)

func _on_AddGlobalExerciseButton_pressed() -> void:
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Exercise"
	show_globalexercise_editor()

func _on_TodayButton_pressed() -> void:
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text = _get_today_date()

func _get_today_date() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]

func show_main_screen() -> void:
	$AppPanel/MainPanel.show()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()

func show_workout_screen() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.show()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()

func show_exercise_editor() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.show()
	$AppPanel/GlobalExerciseEditor.hide()

func show_globalexercise_editor() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.show()

func open_workout_editor(index: int) -> void:
	print("[DEBUG] open_workout_editor", index)
	editing_workout_index = index
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

	var workout_exercises = _get_workout_exercises()
	if workout_exercises == null:
		print("[DEBUG] refresh_exercise_list exercises is null")
		return
	print("[DEBUG] refresh_exercise_list exercises", workout_exercises.size(), workout_exercises)
	for exercise_index in workout_exercises.size():
		var exercise = workout_exercises[exercise_index]
		print("[DEBUG] refresh_exercise_list item", exercise_index, exercise)
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var summary = Label.new()
		summary.text = "%s — %s" % [exercise.get("name", "(no name)"), exercise.get("reps", "")]
		# Allow long exercise names or reps to wrap onto multiple lines
		summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		# Prevent it from wrapping at a single character by enforcing a minimum width
		summary.custom_minimum_size = Vector2(400, 0)
		# Keep the label filling available space so it wraps instead of expanding
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

func _on_ExerciseItem_pressed(index: int) -> void:
	# TODO: Open exercise detail view with history
	print("[DEBUG] Clicked exercise:", index, exercises[index])

func _on_AddExerciseButton_pressed() -> void:
	var dropdown = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown
	# Add exercise list to dropdown
	dropdown.clear()
	for exercise in exercises:
		dropdown.add_item(exercise.get("name", "(no name)"))
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.select(-1)

	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Exercise"
	show_exercise_editor()

func _on_EditGlobalExerciseButton_pressed(index: int) -> void:
	print("[DEBUG] _on_EditGlobalExerciseButton_pressed", index)
	if index < 0 or index >= exercises.size():
		print("[DEBUG] invalid edit exercise index", index)
		return

	editing_global_exercise_index = index
	var exercise = exercises[index]
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text = exercise.get("name", "")
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = exercise.get("notes", "")
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Edit Exercise"
	show_globalexercise_editor()

func _on_DeleteGlobalExerciseButton_pressed(index: int) -> void:
	pending_delete_action = "global_exercise"
	pending_delete_index = index
	show_confirmation("Delete exercise", "Delete this exercise? This cannot be undone.")

func _on_DeleteExerciseButton_pressed(index: int) -> void:
	pending_delete_action = "exercise"
	pending_delete_index = index
	show_confirmation("Delete exercise", "Delete this exercise from the workout?")

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
	if selected_index >= 0:
		dropdown.select(selected_index)

	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text = exercise.get("reps", "")
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = exercise.get("notes", "")
	$AppPanel/ExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Edit Exercise"
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/ExerciseEditor.show()

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
	refresh_exercise_list()
	print("[DEBUG] _on_SaveExerciseButton_pressed after refresh")
	$AppPanel/ExerciseEditor.hide()
	print("[DEBUG] _on_SaveExerciseButton_pressed after ExerciseEditor.hide")
	show_workout_screen()
	print("[DEBUG] _on_SaveExerciseButton_pressed after show_workout_screen")

func _on_CancelExerciseButton_pressed() -> void:
	$AppPanel/ExerciseEditor.hide()
	show_workout_screen()

func _on_SaveGlobalExerciseButton_pressed() -> void:
	var ename = $AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text.strip_edges()
	var notes = $AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text.strip_edges()

	var exercise = {
		"name": ename,
		"notes": notes
	}

	# Ensure exercise does not already exist
	for i in range(exercises.size()):
		if i != editing_global_exercise_index and exercises[i]["name"] == ename:
			print("[DEBUG] Exercise with name '%s' already exists, cannot save." % ename)
			# TODO: show error in the app
			return

	if editing_global_exercise_index >= 0:
		if editing_global_exercise_index < exercises.size():
			exercises[editing_global_exercise_index] = exercise
		else:
			print("[DEBUG] invalid editing_global_exercise_index", editing_global_exercise_index)
	else:
		exercises.append(exercise)

	save_exercises()
	show_main_screen()
	$AppPanel/GlobalExerciseEditor.hide()

func _on_CancelGlobalExerciseButton_pressed() -> void:
	$AppPanel/GlobalExerciseEditor.hide()
	show_main_screen()
	#$AppPanel/MainPanel/MainVBox/TabBar.set_tab(-1)
	_on_TabBar_changed(1)  # Show exercises tab

func _on_SaveWorkoutButton_pressed() -> void:
	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	print("[DEBUG] _on_SaveWorkoutButton_pressed", date_text, editing_workout_index, edit_workout)
	if date_text == "":
		print("[DEBUG] empty date_text, abort save")
		return

	edit_workout["date"] = date_text
	_normalize_workout_data(edit_workout)
	if editing_workout_index >= 0 and editing_workout_index < workouts.size():
		workouts[editing_workout_index] = edit_workout.duplicate(true)
	else:
		workouts.append(edit_workout.duplicate(true))

	save_workouts()
	show_main_screen()

func _on_CancelWorkoutButton_pressed() -> void:
	show_main_screen()

func _on_DeleteWorkoutButton_pressed() -> void:
	if editing_workout_index >= 0 and editing_workout_index < workouts.size():
		pending_delete_action = "workout"
		show_confirmation("Delete workout", "Delete this workout and all recorded exercises?")

func _on_ConfirmDialog_confirmed() -> void:
	print("[DEBUG] _on_ConfirmDialog_confirmed", pending_delete_action, pending_delete_index)
	if pending_delete_action == "workout":
		if editing_workout_index >= 0 and editing_workout_index < workouts.size():
			workouts.remove_at(editing_workout_index)
			save_workouts()
		show_main_screen()
	elif pending_delete_action == "exercise":
		var workout_exercises = _get_workout_exercises()
		if pending_delete_index >= 0 and pending_delete_index < workout_exercises.size():
			workout_exercises.remove_at(pending_delete_index)
			edit_workout["exercises"] = workout_exercises
			refresh_exercise_list()
	elif pending_delete_action == "global_exercise":
		if pending_delete_index >= 0 and pending_delete_index < exercises.size():
			exercises.remove_at(pending_delete_index)
			save_exercises()

	pending_delete_action = ""
	pending_delete_index = -1

func show_confirmation(title: String, message: String) -> void:
	print("[DEBUG] show_confirmation", title, message)
	$AppPanel/ConfirmDialog.title = title
	$AppPanel/ConfirmDialog.dialog_text = message
	$AppPanel/ConfirmDialog.popup_centered()
