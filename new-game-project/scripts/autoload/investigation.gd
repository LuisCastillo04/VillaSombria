extends Node
## Reglas de la investigación: registro de pistas y testimonios, deducciones y
## evaluación de la acusación final.

enum LinkResult { NONE, NEW, ALREADY_KNOWN, MISSING_ITEM }

const CLUE_MINUTES := 5
## Valoraciones que el jugador puede dar a un sospechoso en el tablero, en el orden en que se
## ofrecen. La cadena vacía es «sin valorar»; los rótulos están en `JournalInfo.STATUS_LABELS`.
const HYPOTHESIS_STATUSES: Array[String] = ["", "sospechoso", "principal", "descartado"]
## Campos del formulario de acusación, en su orden: el sospechoso y las tres pruebas, que usan las
## claves de `EvidenceCategories` y de las reglas de `story.json`.
const SUSPECT_FIELD := "suspect"
const ACCUSATION_FIELDS: Array[String] = ["suspect", "motive", "opportunity", "means"]
## Marca que pone la historia al cerrar el caso: entonces el borrador de la acusación se descarta.
const CASE_SOLVED_FLAG := "caso_resuelto"


func _ready() -> void:
	EventBus.flag_set.connect(_on_flag_set)


## Registra una pista una sola vez. Devuelve si era nueva. Con `announce`, el HUD lo avisa
## («Pista registrada»); la inspección de evidencias pasa `false` porque muestra su propio aviso
## («Evidencia obtenida») y así no aparecen dos mensajes por el mismo hallazgo.
func discover_clue(clue_id: String, announce: bool = true) -> bool:
	if GameState.clues.has(clue_id):
		return false
	if not GameData.clues.has(clue_id):
		push_error("Pista desconocida: %s" % clue_id)
		return false
	GameState.clues.append(clue_id)
	EventBus.clue_discovered.emit(clue_id)
	EventBus.objectives_changed.emit()
	if announce:
		EventBus.notification_requested.emit("Pista registrada", GameData.clues[clue_id]["name"], "pista")
	return true


func record_testimony(testimony_id: String) -> bool:
	if GameState.testimonies.has(testimony_id):
		return false
	if not GameData.testimonies.has(testimony_id):
		push_error("Testimonio desconocido: %s" % testimony_id)
		return false
	GameState.testimonies.append(testimony_id)
	EventBus.testimony_recorded.emit(testimony_id)
	EventBus.objectives_changed.emit()
	return true


## Comprueba si dos elementos del expediente forman una deducción real.
func try_link(first_id: String, second_id: String) -> Dictionary:
	if not has_item(first_id) or not has_item(second_id):
		return {"result": LinkResult.MISSING_ITEM, "deduction": ""}
	var deduction_id := find_deduction(first_id, second_id)
	if deduction_id.is_empty():
		return {"result": LinkResult.NONE, "deduction": ""}
	if GameState.deductions.has(deduction_id):
		return {"result": LinkResult.ALREADY_KNOWN, "deduction": deduction_id}
	GameState.deductions.append(deduction_id)
	EventBus.deduction_made.emit(deduction_id)
	EventBus.objectives_changed.emit()
	Effects.apply(GameData.deductions[deduction_id].get("effects", {}))
	EventBus.notification_requested.emit("Deducción", GameData.deductions[deduction_id]["title"], "pista")
	return {"result": LinkResult.NEW, "deduction": deduction_id}


func find_deduction(first_id: String, second_id: String) -> String:
	for deduction_id: String in GameData.deductions:
		for pair: Array in GameData.deductions[deduction_id]["pairs"]:
			if (pair[0] == first_id and pair[1] == second_id) or (pair[0] == second_id and pair[1] == first_id):
				return deduction_id
	return ""


func has_item(item_id: String) -> bool:
	return (
		GameState.clues.has(item_id)
		or GameState.testimonies.has(item_id)
		or GameState.deductions.has(item_id)
	)


## Describe un elemento del expediente de forma uniforme para la interfaz.
func get_item(item_id: String) -> Dictionary:
	if GameData.clues.has(item_id):
		var clue: Dictionary = GameData.clues[item_id]
		return {"id": item_id, "kind": "pista", "title": clue["name"], "text": clue["description"], "tag": clue["category"]}
	if GameData.testimonies.has(item_id):
		var testimony: Dictionary = GameData.testimonies[item_id]
		var speaker := GameData.get_character_name(testimony["speaker"])
		return {"id": item_id, "kind": "testimonio", "title": "%s: %s" % [speaker, testimony["topic"]], "text": testimony["text"], "tag": testimony["speaker"]}
	if GameData.deductions.has(item_id):
		var deduction: Dictionary = GameData.deductions[item_id]
		return {"id": item_id, "kind": "deduccion", "title": deduction["title"], "text": deduction["text"], "tag": deduction["kind"]}
	return {}


## Elementos con los que el jugador puede trabajar en el tablero, en orden de hallazgo.
func get_board_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for collection: Array[String] in [GameState.clues, GameState.testimonies, GameState.deductions]:
		for item_id in collection:
			items.append(get_item(item_id))
	return items


## Lo que el jugador puede presentar en la acusación para una categoría ("motive", "opportunity" o
## "means", ver `EvidenceCategories`): las pistas, testimonios y deducciones ya hallados que
## pertenecen a ella, en el orden del tablero y sin repetir. Nunca incluye nada sin descubrir, y no
## depende del sospechoso elegido ni de cuál sea la respuesta correcta: sólo reduce la lista a lo
## que tiene que ver con la pregunta.
func get_accusation_options(category: String) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not EvidenceCategories.is_category(category):
		return options
	var seen := {}
	for item in get_board_items():
		var item_id: String = item.get("id", "")
		if item_id.is_empty() or seen.has(item_id) or not EvidenceCategories.belongs(item_id, category):
			continue
		seen[item_id] = true
		options.append(item)
	return options


# --- Borrador de la acusación ---

## Lo último que el jugador eligió en cada campo de la acusación, con todos los campos de
## `ACCUSATION_FIELDS` ("" si está vacío). Sólo devuelve elecciones que siguen siendo válidas.
func get_accusation_draft() -> Dictionary:
	return clean_accusation_draft(GameState.accusation_draft, _discovered_ids())


## Anota una elección del formulario en el borrador. `field` es uno de `ACCUSATION_FIELDS`; `value`,
## el sospechoso o el elemento elegido, o "" para dejar el campo vacío. Rechaza a quien no es
## sospechoso y los elementos sin descubrir o de otra categoría. Anotar no presenta nada ni cuenta
## como intento: sólo recuerda el formulario. Devuelve si el borrador quedó con ese valor.
func set_accusation_choice(field: String, value: String) -> bool:
	if not ACCUSATION_FIELDS.has(field):
		push_warning("Acusación: el campo «%s» no existe." % field)
		return false
	if not value.is_empty() and not _is_valid_choice(field, value, _discovered_ids()):
		push_warning("Acusación: «%s» no vale para el campo «%s»." % [value, field])
		return false
	if str(GameState.accusation_draft.get(field, "")) == value:
		return true
	if value.is_empty():
		GameState.accusation_draft.erase(field)
	else:
		GameState.accusation_draft[field] = value
	EventBus.accusation_draft_changed.emit(field)
	return true


## Vacía el borrador entero.
func clear_accusation_draft() -> void:
	if GameState.accusation_draft.is_empty():
		return
	GameState.accusation_draft.clear()
	EventBus.accusation_draft_changed.emit("")


## Si un borrador (como el de `get_accusation_draft`) tiene los cuatro campos elegidos.
func is_accusation_complete(draft: Dictionary) -> bool:
	for field in ACCUSATION_FIELDS:
		if str(draft.get(field, "")).is_empty():
			return false
	return true


## Borrador válido a partir de unos datos cualesquiera, como los de una partida guardada: los cuatro
## campos, con el valor sólo si es texto, el sospechoso lo es y cada prueba está entre `known_ids` (lo
## descubierto) y pertenece a su categoría. Todo lo demás queda vacío; nunca falla.
func clean_accusation_draft(raw: Variant, known_ids: Array) -> Dictionary:
	var result := {}
	for field in ACCUSATION_FIELDS:
		result[field] = ""
	if not raw is Dictionary:
		return result
	for field in ACCUSATION_FIELDS:
		var value: Variant = (raw as Dictionary).get(field, "")
		if value is String and not (value as String).is_empty() and _is_valid_choice(field, value, known_ids):
			result[field] = value
	return result


func _is_valid_choice(field: String, value: String, known_ids: Array) -> bool:
	if field == SUSPECT_FIELD:
		return GameData.get_suspects().has(value)
	return known_ids.has(value) and EvidenceCategories.belongs(value, field)


func _discovered_ids() -> Array:
	return GameState.clues + GameState.testimonies + GameState.deductions


## Al cerrar el caso, el borrador ya no sirve: se descarta.
func _on_flag_set(flag: String) -> void:
	if flag == CASE_SOLVED_FLAG:
		clear_accusation_draft()


## Hipótesis del jugador sobre un sospechoso: {"status", "note"}, vacías si aún no anotó nada.
func get_hypothesis(suspect_id: String) -> Dictionary:
	var saved: Dictionary = GameState.hypotheses.get(suspect_id, {})
	return {"status": str(saved.get("status", "")), "note": str(saved.get("note", ""))}


## Anota la valoración y la hipótesis del jugador sobre un sospechoso. Sólo admite sospechosos del
## caso y valoraciones de `HYPOTHESIS_STATUSES`, y recorta la nota al largo que aceptan las partidas
## guardadas. Devuelve si se anotó.
func set_hypothesis(suspect_id: String, status: String, note: String) -> bool:
	if not GameData.get_suspects().has(suspect_id):
		push_warning("Hipótesis rechazada: «%s» no es un sospechoso del caso." % suspect_id)
		return false
	if not HYPOTHESIS_STATUSES.has(status):
		push_warning("Hipótesis rechazada: la valoración «%s» no existe." % status)
		return false
	GameState.hypotheses[suspect_id] = {"status": status, "note": note.strip_edges().left(SaveFormat.MAX_NOTE_LENGTH)}
	EventBus.hypothesis_changed.emit(suspect_id)
	return true


## Valora la acusación. Devuelve {"ok": bool, "reason": String}.
func evaluate_accusation(suspect_id: String, motive_id: String, opportunity_id: String, means_id: String) -> Dictionary:
	var rules: Dictionary = GameData.story["accusation"]
	var rejections: Dictionary = rules["rejections"]
	if suspect_id != rules["culprit"]:
		return {"ok": false, "reason": rejections.get(suspect_id, "Esa acusación no se sostiene.")}
	var weak: Dictionary = rules["weak"]
	if not (rules["motive"] as Array).has(motive_id):
		return {"ok": false, "reason": weak["motive"]}
	if not (rules["opportunity"] as Array).has(opportunity_id):
		return {"ok": false, "reason": weak["opportunity"]}
	if not (rules["means"] as Array).has(means_id):
		return {"ok": false, "reason": weak["means"]}
	return {"ok": true, "reason": ""}
