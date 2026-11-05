extends Node
## Bus de señales globales. Los sistemas emiten aquí sus eventos para que la
## interfaz y el mundo reaccionen sin conocerse entre sí.

signal interaction_focus_changed(prompt: String)
signal notification_requested(title: String, body: String, kind: String)
signal location_change_requested(location_id: String, spawn_id: String)
signal location_changed(location_id: String)
