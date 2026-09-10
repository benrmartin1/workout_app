extends Control


const WorkoutStorage = preload("res://scripts/workout_storage.gd")
const Version = "1.3.7"

var workouts: Array = []
var exercises: Array = []

# TODO: Make obj to store current edit state for workout and exercise editor, instead of using global vars
var edit_workout: Dictionary = {}
var editing_workout_index: int = -1
var editing_exercise_index: int = -1
# Index of the exercise being edited, or -1 if adding a new exercise
var editing_global_exercise_index: int = -1

enum DELETE_ACTION {WORKOUT, EXERCISE, GLOBAL_EXERCISE, NONE, EXIT_APP}
var pending_delete_action: DELETE_ACTION = DELETE_ACTION.NONE
var pending_delete_index: int = -1

enum EXERCISE_SORT {DEFAULT, CATEGORY, NAME}
var exercise_sort_mode: int = EXERCISE_SORT.DEFAULT

# Dirty flags to indicate unsaved changes
var workout_dirty: bool = false
var exercise_dirty: bool = false
var global_exercise_dirty: bool = false
var export_dialog: FileDialog

func _commit_new_workout() -> bool:
	# Commit the new workout to the workouts list and save it
	var date_text = $AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	if date_text == "":
		print("[ERROR] _commit_new_workout: Date cannot be empty")
		return false

	var new_workout = {
		"date": date_text,
		"exercises": []
	}
	workouts.append(new_workout)

	WorkoutStorage.save_workouts(workouts)
	workout_dirty = false
	return true

func _commit_workout_changes() -> bool:
	print("[DEBUG] _commit_workout_changes start, editing_workout_index: ", editing_workout_index)

	if editing_workout_index < 0 or editing_workout_index >= workouts.size():
		print("[ERROR] _commit_workout_changes: Invalid editing_workout_index: ", editing_workout_index)
		return false

	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	if date_text == "":
		print("[ERROR] _commit_workout_changes: Date cannot be empty")
		return false
	edit_workout["date"] = date_text
	_normalize_workout_data(edit_workout)
	workouts[editing_workout_index] = edit_workout.duplicate(true)

	# Keep the current edit index stable while the workout editor is open.
	# Re-sorting will happen when returning to the main screen.
	WorkoutStorage.save_workouts(workouts)
	workout_dirty = false
	return true

func _set_workout_dirty(dirty: bool) -> void:
	workout_dirty = dirty

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

	# Settings buttons
	$AppPanel/MainPanel/TabContainer/SettingsTab/ExportWorkoutsButton.pressed.connect(Callable(self, "_on_ExportWorkoutsButton_pressed"))
	$AppPanel/MainPanel/TabContainer/SettingsTab/ExportExercisesButton.pressed.connect(Callable(self, "_on_ExportExercisesButton_pressed"))
	$AppPanel/MainPanel/TabContainer/SettingsTab/AutoBackupButton.pressed.connect(Callable(self, "_on_AutoBackupButton_pressed"))

	# New Workout panel buttons
	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateDoneButton.pressed.connect(Callable(self, "_on_NewWorkoutDateDoneButton_pressed"))
	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateEdit.focus_entered.connect(Callable(self, "_on_NewWorkoutDateEdit_focus_entered"))
	$AppPanel/NewWorkoutPanel/VBoxContainer/EditorButtonBar/BackWorkoutButton.pressed.connect(Callable(self, "_on_BackWorkoutButton_pressed"))
	$AppPanel/NewWorkoutPanel/VBoxContainer/EditorButtonBar/SaveNewWorkoutButton.pressed.connect(Callable(self, "_on_SaveNewWorkoutButton_pressed"))

	# Workout editor buttons
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.pressed.connect(Callable(self, "_on_WorkoutEditorDateDoneButton_pressed"))
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.focus_entered.connect(Callable(self, "_on_WorkoutEditorDateEdit_focus_entered"))
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.focus_exited.connect(Callable(self, "_on_WorkoutEditorDateEdit_focus_exited"))
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
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text_changed.connect(Callable(self, "_on_WorkoutEditor_date_changed")) 
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.item_selected.connect(Callable(self, "_on_ExerciseDropdown_selected"))
	$AppPanel/ExerciseEditor/VBoxContainer/RepsRow/RepsEdit.text_changed.connect(Callable(self, "_on_ExerciseEditor_field_changed"))
	$AppPanel/ExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text_changed.connect(Callable(self, "_on_ExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text_changed.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text_changed.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))
	$AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown.item_selected.connect(Callable(self, "_on_GlobalExerciseEditor_field_changed"))

	# Set max length for text field global exercise dropdown
	$AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.get_popup().max_size = Vector2(600, 1000)

	_create_export_dialog()

	load_workouts()
	load_exercises()
	print("[DEBUG] loaded workouts", workouts.size(), "exercises", exercises.size())
	build_workout_list()
	build_global_exercise_list()
	_update_backup_status_label()
	set_version()
	print("[DEBUG] _ready complete")

func _create_export_dialog() -> void:
	export_dialog = FileDialog.new()
	export_dialog.title = "Export backup"
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.use_native_dialog = true
	export_dialog.add_filter("*.json ; JSON Files")
	export_dialog.file_selected.connect(Callable(self, "_on_export_dialog_file_selected"))
	add_child(export_dialog)

func _on_ExportWorkoutsButton_pressed() -> void:
	export_dialog.title = "Export workouts backup"
	export_dialog.current_file = "workouts_backup.json"
	export_dialog.popup_centered_ratio(0.8)

func _on_ExportExercisesButton_pressed() -> void:
	export_dialog.title = "Export exercises backup"
	export_dialog.current_file = "exercises_backup.json"
	export_dialog.popup_centered_ratio(0.8)

func _on_AutoBackupButton_pressed() -> void:
	if WorkoutStorage.create_auto_backup(workouts, exercises):
		print("[DEBUG] Created automatic backups in user data folder")
		_update_backup_status_label()
	else:
		print("[DEBUG] Failed to create automatic backups")
		_update_backup_status_label("Failed")

func _on_export_dialog_file_selected(path: String) -> void:
	if export_dialog.title.contains("workouts"):
		if WorkoutStorage.export_workouts(workouts, path):
			print("[DEBUG] Exported workouts backup to ", path)
		else:
			print("[DEBUG] Failed to export workouts backup to ", path)
		return

	if WorkoutStorage.export_exercises(exercises, path):
		print("[DEBUG] Exported exercises backup to ", path)
	else:
		print("[DEBUG] Failed to export exercises backup to ", path)

func _update_backup_status_label(status_text: String = "") -> void:
	var backup_status = $AppPanel/MainPanel/TabContainer/SettingsTab/BackupStatus
	if backup_status == null:
		return

	if status_text != "":
		backup_status.text = "Last backup: " + status_text
		return

	var latest_backup = WorkoutStorage.get_latest_backup_filename()
	if latest_backup != "":
		backup_status.text = "Last backup: " + latest_backup
	else:
		backup_status.text = "Last backup not found"

func load_workouts() -> void:
	print("[DEBUG] load_workouts start")
	workouts = WorkoutStorage.load_workouts()
	print("[DEBUG] load_workouts finished, workouts size: ", workouts.size())

func load_exercises() -> void:
	print("[DEBUG] load_exercises start")
	exercises = WorkoutStorage.load_exercises()
	print("[DEBUG] load_exercises finished, exercises size: ", exercises.size())

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
	print("[DEBUG] _get_workout_exercises start, edit_workout: ", edit_workout)
	var exercises_list = edit_workout.get("exercises")
	if exercises_list is Array:
		print("[DEBUG] _get_workout_exercises returned existing, exercises_list: ", exercises_list.size(), ", list: ", exercises_list)
		return exercises_list

	exercises_list = []
	edit_workout["exercises"] = exercises_list
	print("[DEBUG] _get_workout_exercises created new, exercises_list: ", exercises_list.size(), ", list: ", exercises_list)
	return exercises_list

func _get_workout_category_counts(workout: Dictionary) -> String:
	var workout_exercises = workout.get("exercises", [])
	if workout_exercises is not Array:
		return "Error: Invalid exercises data"

	# Dictionary of category_id to count of exercises in that category
	var category_counts_dict: Dictionary = {}
	for exercise in workout_exercises:
		if exercise is not Dictionary:
			continue

		var exercise_name = exercise.get("name", "").strip_edges()
		var category_id = -1
		for global_exercise in exercises:
			if global_exercise is Dictionary and global_exercise.get("name", "").strip_edges() == exercise_name:
				category_id = global_exercise.get("category", -1)
				break

		if not category_counts_dict.has(category_id):
			category_counts_dict[category_id] = 0
		category_counts_dict[category_id] += 1

	var category_entries: Array = []
	for category_id in category_counts_dict.keys():
		category_entries.append([category_id, category_counts_dict[category_id]])
	# Ensure that the category entries are sorted by category ID for consistent display
	category_entries.sort_custom(_compare_category_count_entries)

	var category_counts_str = ""
	for entry in category_entries:
		var category_id = entry[0]
		var category_count = entry[1]
		if category_counts_str != "":
			category_counts_str += ", "
		category_counts_str += "%d %s" % [category_count, _get_category_name(category_id)]

	return category_counts_str

func _compare_category_count_entries(a: Array, b: Array) -> bool:
	return a[0] < b[0]

func _get_category_name(category_id: int) -> String:
	var dropdown = $AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown
	if dropdown != null and category_id >= 0 and category_id < dropdown.get_item_count():
		return dropdown.get_item_text(category_id)
	return "Unknown"

func build_workout_list() -> void:
	var list = $AppPanel/MainPanel/TabContainer/WorkoutTab/ScrollWrapper/WorkoutList
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

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var summary_container = VBoxContainer.new()
		summary_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(summary_container)

		var summary = Label.new()
		summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_container.add_child(summary)

		var workout_exercises = workout.get("exercises", [])
		var exercises_num = workout_exercises.size() if workout_exercises is Array else 0

		var summary_text = "%s — %d exercise%s" % [workout.get("date", ""), exercises_num, "s" if exercises_num != 1 else ""]
		summary.text = summary_text

		var category_summary = _get_workout_category_counts(workout)
		if category_summary != "":
			var category_label = Label.new()
			category_label.text = category_summary
			category_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			category_label.max_lines_visible = 1
			category_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			category_label.add_theme_color_override("font_color", Color.GRAY)
			category_label.add_theme_font_size_override("font_size", 22)
			summary_container.add_child(category_label)

		var edit_button = Button.new()
		edit_button.text = " ✏️ "
		edit_button.pressed.connect(Callable(self, "_on_WorkoutItem_pressed").bind(index))
		row.add_child(edit_button)

		list.add_child(row)
		# Add separator line between workout items
		var separator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(separator)

func build_global_exercise_list() -> void:
	var list = $AppPanel/MainPanel/TabContainer/ExerciseTab/ExerciseScrollWrapper/ExerciseListMain
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
		view_button.text = " 📜 "
		view_button.pressed.connect(Callable(self, "_on_GlobalExerciseItem_pressed").bind(exercise_index))
		row.add_child(view_button)
		
		var edit_button = Button.new()
		edit_button.text = " ✏️ "
		edit_button.pressed.connect(Callable(self, "_on_EditGlobalExerciseButton_pressed").bind(exercise_index))
		row.add_child(edit_button)

		var delete_button = Button.new()
		delete_button.text = " 🗑️ "
		delete_button.pressed.connect(Callable(self, "_on_DeleteGlobalExerciseButton_pressed").bind(exercise_index))
		row.add_child(delete_button)
		
		if not exercise.has("category") or exercise["category"] < 0 or exercise.get("name", "").strip_edges() == "":
			exercise_name.text = "⚠ " + exercise_name.text
		
		list.add_child(row)

		# Add separator line between exercise items
		var separator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(separator)

func set_version() -> void:
	$AppPanel/MainPanel/TabContainer/SettingsTab/Version.text = "Version: %s" % Version

func _on_WorkoutEditor_date_changed(_arg: String) -> void:
	var date_text = $AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text.strip_edges()
	edit_workout["date"] = date_text
	_set_workout_dirty(true)

func _on_ExerciseEditor_field_changed(_arg = null) -> void:
	_set_exercise_dirty(true)

func _on_ExerciseDropdown_selected(_index: int) -> void:
	print("[DEBUG] _on_ExerciseDropdown_selected index: ", _index)
	var exercise_name = $AppPanel/ExerciseEditor/VBoxContainer/NameRow/NameDropdown.text
	var previous_reps = _get_previous_exercise_reps(exercise_name)
	$AppPanel/ExerciseEditor/VBoxContainer/PreviousRepsRow/RepsEdit.text = previous_reps
	_set_exercise_dirty(true)

func _on_ExerciseSort_selected(index: int) -> void:
	exercise_sort_mode = index
	build_global_exercise_list()

func _get_previous_exercise_reps(exercise_name: String) -> String:
	# Search through workouts in order, starting on the current workout index + 1
	print("[DEBUG] _get_previous_exercise_reps ", exercise_name, " in workout ", editing_workout_index)
	for workout_idx in range(editing_workout_index + 1, workouts.size()):
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
	open_new_workout_panel()

func _on_AddGlobalExerciseButton_pressed() -> void:
	$AppPanel/GlobalExerciseEditor/VBoxContainer/ExerciseEditorTitle.text = "Add Global Exercise"
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NameRow/NameEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/NotesRow/NotesEdit.text = ""
	$AppPanel/GlobalExerciseEditor/VBoxContainer/CategoryRow/CategoryDropdown.select(-1)
	editing_global_exercise_index = -1
	_set_global_exercise_dirty(false)
	show_globalexercise_editor()

func _on_NewWorkoutDateDoneButton_pressed() -> void:
	# Unfocus the date edit box to remove virtual keyboard on mobile devices
	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateEdit.release_focus()
	# Disable date done button until the date edit box is focused again
	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateDoneButton.disabled = true

func _on_NewWorkoutDateEdit_focus_entered() -> void:
	# Enable date done button when the date edit box is focused
	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateDoneButton.disabled = false

func _on_WorkoutEditorDateDoneButton_pressed() -> void:
	# Unfocus the date edit box to remove virtual keyboard on mobile devices
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.release_focus()
	# Disable date done button until the date edit box is focused again
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.disabled = true
	if workout_dirty:
		_commit_workout_changes()

func _on_WorkoutEditorDateEdit_focus_entered() -> void:
	# Enable date done button when the date edit box is focused
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateDoneButton.disabled = false

func _on_WorkoutEditorDateEdit_focus_exited() -> void:
	if workout_dirty:
		_commit_workout_changes()

func _get_today_date() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]

func hide_panels() -> void:
	$AppPanel/MainPanel.hide()
	$AppPanel/WorkoutEditor.hide()
	$AppPanel/NewWorkoutPanel.hide()
	$AppPanel/ExerciseEditor.hide()
	$AppPanel/GlobalExerciseEditor.hide()
	$AppPanel/GlobalExerciseDetails.hide()

func show_main_screen() -> void:
	if workout_dirty:
		_commit_workout_changes()
	sort_workouts()
	build_workout_list()
	build_global_exercise_list()
	hide_panels()
	$AppPanel/MainPanel.show()

func show_add_workout_screen() -> void:
	hide_panels()
	$AppPanel/NewWorkoutPanel.show()

func show_edit_workout_screen() -> void:
	build_exercise_list()
	hide_panels()
	$AppPanel/WorkoutEditor.show()

func show_exercise_editor() -> void:
	hide_panels()
	$AppPanel/ExerciseEditor.show()

func show_globalexercise_editor() -> void:
	hide_panels()
	$AppPanel/GlobalExerciseEditor.show()

func show_exercise_details(exercise_name: String) -> void:
	$AppPanel/GlobalExerciseDetails/VBoxContainer/ExerciseDetailsTitle.text = exercise_name
	build_exercise_history_list(exercise_name)
	hide_panels()
	$AppPanel/GlobalExerciseDetails.show()

func _on_CancelExerciseDetailsButton_pressed() -> void:
	show_main_screen()

func open_workout_editor(index: int) -> void:
	print("[DEBUG] open_workout_editor with index: ", index)
	if index < 0 or index >= workouts.size():
		print("[ERROR] Invalid workout index")
		return
	editing_workout_index = index

	# Reset dirty state when opening editor
	_set_workout_dirty(false)
	edit_workout = workouts[index].duplicate(true)
	_normalize_workout_data(edit_workout)

	print("[DEBUG] current edit_workout", edit_workout)
	$AppPanel/WorkoutEditor/VBoxContainer/DateRow/DateEdit.text = edit_workout["date"]
	show_edit_workout_screen()

func open_new_workout_panel() -> void:
	print("[DEBUG] open_new_workout_panel")
	editing_workout_index = -1
	_set_workout_dirty(false)
	edit_workout = {}

	$AppPanel/NewWorkoutPanel/VBoxContainer/DateRow/DateEdit.text = _get_today_date()
	show_add_workout_screen()

func build_exercise_list() -> void:
	print("[DEBUG] build_exercise_list start")
	var list = $AppPanel/WorkoutEditor/VBoxContainer/ExerciseScroll/ExerciseList
	if list == null:
		print("[DEBUG] build_exercise_list list is null")
		return
	while list.get_child_count() > 0:
		list.get_child(0).free()

	var workout_exercises = _get_workout_exercises()
	if workout_exercises == null:
		print("[DEBUG] build_exercise_list exercises is null")
		return
	print("[DEBUG] build_exercise_list exercises size: ", workout_exercises.size())
	for exercise_index in workout_exercises.size():
		var exercise = workout_exercises[exercise_index]
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var summary_container = VBoxContainer.new()
		summary_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(summary_container)

		var summary = Label.new()
		summary.text = "%s — %s" % [exercise.get("name", "(no name)"), exercise.get("reps", "")]
		summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_container.add_child(summary)

		var edit_button = Button.new()
		edit_button.text = " ✏️ "
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

		var notes = exercise.get("notes", "")
		if notes.strip_edges() != "":
			var notes_label = Label.new()
			notes_label.text = notes
			notes_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			notes_label.clip_text = true
			notes_label.max_lines_visible = 1
			notes_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			notes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			notes_label.add_theme_color_override("font_color", Color.GRAY)
			notes_label.add_theme_font_size_override("font_size", 22)
			summary_container.add_child(notes_label)

		list.add_child(row)

		# Add separator line between exercise items
		var separator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(separator)

func _on_WorkoutItem_pressed(index: int) -> void:
	open_workout_editor(index)

func _on_GlobalExerciseItem_pressed(index: int) -> void:
	if index < 0 or index >= exercises.size():
		print("[DEBUG] invalid exercise index", index)
		return
	var exercise_name = exercises[index].get("name", "")
	print("[DEBUG] _on_GlobalExerciseItem_pressed", index, exercise_name)
	show_exercise_details(exercise_name)

func build_exercise_history_list(exercise_name: String) -> void:
	var list = $AppPanel/GlobalExerciseDetails/VBoxContainer/ExerciseScroll/ExerciseList
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
		reps_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		row.add_child(reps_label)

		list.add_child(row)

		# Add separator line between history items
		var separator = HSeparator.new()
		separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(separator)

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
	editing_exercise_index = -1 # Reset editing index to indicate adding a new exercise
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
	print("[DEBUG] _on_EditExerciseButton_pressed, index: ", index, ", size: ", workout_exercises.size())
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
		print("[ERROR] no exercise selected from dropdown, abort save")
		# TODO: show error in the app
		return

	if ename == "":
		print("[ERROR] empty exercise name, abort save")
		# TODO: show error in the app
		return

	var exercise = {
		"name": ename,
		"reps": reps,
		"notes": notes
	}

	print("[DEBUG] _on_SaveExerciseButton_pressed start: ", editing_exercise_index, ", edit_workout: ", edit_workout)
	var workout_exercises = _get_workout_exercises()
	if workout_exercises == null:
		print("[DEBUG] _on_SaveExerciseButton_pressed exercises returned null")
		return
	print("[DEBUG] _on_SaveExerciseButton_pressed exercises: ", workout_exercises.size(), ", list: ", workout_exercises)
	if editing_exercise_index >= 0 and editing_exercise_index < workout_exercises.size():
		workout_exercises[editing_exercise_index] = exercise
	else:
		workout_exercises.append(exercise)
	editing_exercise_index = -1

	# Saving an exercise edits the current workout; persist it immediately once the edit is complete
	_set_exercise_dirty(false)
	edit_workout["exercises"] = workout_exercises
	_commit_workout_changes()
	show_edit_workout_screen()

func _on_CancelExerciseButton_pressed() -> void:
	_set_exercise_dirty(false)
	show_edit_workout_screen()

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
		print("[ERROR] empty exercise name or invalid category, abort save")
		# TODO: show error in the app
		return

	# Ensure exercise does not already exist
	for i in range(exercises.size()):
		if i != editing_global_exercise_index and exercises[i]["name"] == ename:
			print("[ERROR] Exercise with name '%s' already exists, cannot save." % ename)
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
		# Save workouts after updating exercise names
		WorkoutStorage.save_workouts(workouts)

	WorkoutStorage.save_exercises(exercises)
	_set_global_exercise_dirty(false)
	show_main_screen()

func _on_CancelGlobalExerciseButton_pressed() -> void:
	_set_global_exercise_dirty(false)
	show_main_screen()

func _on_BackWorkoutButton_pressed() -> void:
	show_main_screen()

func _on_SaveNewWorkoutButton_pressed() -> void:
	if _commit_new_workout():
		show_main_screen()

func _on_SaveWorkoutButton_pressed() -> void:
	# If commit fails, stay on the workout editor screen for user to correct issues
	if _commit_workout_changes():
		show_main_screen()

func _on_DeleteWorkoutButton_pressed() -> void:
	if editing_workout_index >= 0 and editing_workout_index < workouts.size():
		pending_delete_action = DELETE_ACTION.WORKOUT
		pending_delete_index = editing_workout_index
		show_confirmation("Delete workout", "Delete this workout and all recorded exercises?")

func _on_ConfirmDialog_confirmed() -> void:
	print("[DEBUG] _on_ConfirmDialog_confirmed, action: ", pending_delete_action, " index: ", pending_delete_index)

	match pending_delete_action:
		DELETE_ACTION.WORKOUT:
			if pending_delete_index >= 0 and pending_delete_index < workouts.size():
				workouts.remove_at(pending_delete_index)
				WorkoutStorage.save_workouts(workouts)
				editing_workout_index = -1
				show_main_screen()
		DELETE_ACTION.EXERCISE:
			var workout_exercises = _get_workout_exercises()
			if pending_delete_index >= 0 and pending_delete_index < workout_exercises.size():
				workout_exercises.remove_at(pending_delete_index)
				edit_workout["exercises"] = workout_exercises
				# Persist the workout immediately after removing an exercise
				_commit_workout_changes()
				editing_exercise_index = -1
				show_edit_workout_screen()
		DELETE_ACTION.GLOBAL_EXERCISE:
			if pending_delete_index >= 0 and pending_delete_index < exercises.size():
				exercises.remove_at(pending_delete_index)
				editing_global_exercise_index = -1
				WorkoutStorage.save_exercises(exercises)
				build_global_exercise_list() # Rebuild the list to reflect the deletion
		DELETE_ACTION.EXIT_APP:
			get_tree().quit()
		DELETE_ACTION.NONE:
			print("[DEBUG] No delete action to perform.")

func show_confirmation(title: String, message: String) -> void:
	print("[DEBUG] show_confirmation: ", title, ", message: ", message)
	$AppPanel/ConfirmDialog.title = title
	$AppPanel/ConfirmDialog.dialog_text = message
	$AppPanel/ConfirmDialog.popup_centered()

func _notification(what):
	# Handle back button press on Android
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("[DEBUG] Back button pressed")
		if $AppPanel/ConfirmDialog.visible:
			$AppPanel/ConfirmDialog.hide()
			return
		if $AppPanel/MainPanel.visible:
			pending_delete_action = DELETE_ACTION.EXIT_APP
			show_confirmation("Exit app", "Close the app?   	 :(")
			return
		if $AppPanel/ExerciseEditor.visible:
			_on_CancelExerciseButton_pressed()
			return
		if $AppPanel/GlobalExerciseEditor.visible:
			_on_CancelGlobalExerciseButton_pressed()
			return
		if $AppPanel/GlobalExerciseDetails.visible:
			_on_CancelExerciseDetailsButton_pressed()
			return
		if $AppPanel/WorkoutEditor.visible:
			_on_BackWorkoutButton_pressed()
			return
