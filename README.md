# Workout

A Godot 4.6 project.

## Getting started

1. Open this folder in VS Code.
2. Run the `Open Godot Editor` task from the Terminal > Run Task menu.
3. If `godot` is not on your PATH, configure the full path to the Godot executable in `.vscode/tasks.json`.

## Notes

A simple offline workout logging app for android made with Godot. 

This app's main page is a list of workouts, with the date of each workout shown. User can scroll through the list of workouts and click on a specific past workout to view the log of that workout.
On this page there is an "add workout" button which allows the user to create a new workout for either todays date or a custom date.
When in the adding workout mode, the user has a similar UI to the main page, but with a list of exercices they have logged. By default, there are no exercises in the list, and the user can add them.
When adding an exercise, there is a new screen which allows them to write 3 fields for each logged exercise.
1. The user can specify using free text the name of the exercise.
2. The user can specify reps/sets/weight (this can be free text as well, to simplify and allow notes like 3x5 30lbs, then 3x4 25lbs since I failed last rep).
3. The user can specify optionally some notes, for example "try 3x10 next time".

Users should be able to edit existing workout logs, for example editing the name of the exercise or reps.
When the user quits out of the app, these workouts should always be saved so they can be reviewed or edited later.

## Future Ideas

- A simple settings menu which allow different colors for text/background, such as dark mode.
- When adding dates, user can optionally pick from a calendar widget instead of typing date by hand.
- When adding an exercise name, there is auto-fill options for exercises added in past workouts.
- When adding an exercise that user has done before, UI should show reps/sets/weight of previous time they did that exercise.
