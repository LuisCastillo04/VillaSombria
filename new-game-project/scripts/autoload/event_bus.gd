extends Node
## Bus de señales globales. Los sistemas emiten aquí sus eventos para que la
## interfaz y el mundo reaccionen sin conocerse entre sí.
@warning_ignore_start("unused_signal")

signal interaction_focus_changed(prompt: String)
signal notification_requested(title: String, body: String, kind: String)
signal location_change_requested(location_id: String, spawn_id: String)
signal location_changed(location_id: String)

signal clue_discovered(clue_id: String)
signal testimony_recorded(testimony_id: String)
signal deduction_made(deduction_id: String)
signal flag_set(flag: String)

signal time_changed(day: int, minutes: int)
signal day_changed(day: int)
signal objectives_changed

## Acción narrativa pedida desde los datos, como abrir la acusación o cerrar el caso.
signal story_action(action: String)
signal clue_inspection_requested(clue_id: String)
signal rest_requested
