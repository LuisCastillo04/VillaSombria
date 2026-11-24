extends Node
## Bus de señales globales. Los sistemas emiten aquí sus eventos para que la
## interfaz y el mundo reaccionen sin conocerse entre sí.
@warning_ignore_start("unused_signal")

signal interaction_focus_changed(prompt: String)
signal notification_requested(title: String, body: String, kind: String)
signal location_change_requested(location_id: String, spawn_id: String)
signal location_changed(location_id: String)
## Cambian los bloqueos del control del jugador (conversación, transición, pantallas). Los motivos
## activos están en `GameState.get_player_lock_reasons()`.
signal player_locks_changed

signal clue_discovered(clue_id: String)
signal testimony_recorded(testimony_id: String)
signal deduction_made(deduction_id: String)
## El jugador ha terminado de oír la respuesta a una pregunta (la primera vez o al repetirla). El
## registro está en `ConversationLog`.
signal conversation_recorded(npc_id: String, topic_id: String)
## El jugador ha anotado o cambiado su valoración o su hipótesis sobre un sospechoso.
signal hypothesis_changed(suspect_id: String)
## Ha cambiado el borrador de la acusación: un campo del formulario, o "" si se vació entero.
signal accusation_draft_changed(field: String)
signal flag_set(flag: String)

signal time_changed(day: int, minutes: int)
signal day_changed(day: int)
signal objectives_changed

## Acción narrativa pedida desde los datos, como abrir la acusación o cerrar el caso.
signal story_action(action: String)
signal clue_inspection_requested(clue_id: String)
## Hay que mostrar un subtítulo: una voz o un sonido narrado, con quién habla y cuántos segundos.
## Lo muestra `SubtitleBar` si el jugador tiene activados los subtítulos.
signal subtitle_requested(speaker_id: String, text: String, seconds: float)
signal rest_requested
