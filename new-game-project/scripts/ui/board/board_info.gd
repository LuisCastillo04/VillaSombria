class_name BoardInfo
extends RefCounted
## Todo lo que muestra el tablero de deducción, leído de los sistemas del juego: los sospechosos y sus
## valoraciones (`GameState.hypotheses`, a través de `Investigation`), los elementos que el jugador ha
## descubierto (`Investigation.get_board_items()`), las deducciones que ya estableció y las teclas del
## InputMap. Sólo consulta: no cambia nada ni guarda estado propio.
##
## Como `JournalInfo`, nunca rellena huecos con datos inventados y nunca enseña algo que el jugador
## no haya descubierto: las relaciones que se dibujan son siempre deducciones ya registradas.

## Rótulo de cada tipo de elemento en su ficha.
const KIND_LABELS := {"pista": "PRUEBA", "testimonio": "DECLARACIÓN", "deduccion": "DEDUCCIÓN"}
## Grupos del tablero, en el orden en que aparecen: pruebas, declaraciones y deducciones.
const GROUPS: Array[Dictionary] = [
	{"kind": "pista", "title": "PRUEBAS"},
	{"kind": "testimonio", "title": "DECLARACIONES"},
	{"kind": "deduccion", "title": "DEDUCCIONES"},
]
const STATUS_LABELS := JournalInfo.STATUS_LABELS


# --- Sospechosos ---

## Sospechosos del caso, en el orden de `characters.json`, con su valoración y su hipótesis. Además
## de lo que lee el expediente, el nombre corto de las fichas del tablero.
static func suspects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for suspect in JournalInfo.suspects():
		var entry := suspect.duplicate()
		var character: Dictionary = GameData.characters.get(suspect["id"], {})
		entry["short"] = character.get("short", suspect["name"])
		result.append(entry)
	return result


static func status_label(status: String) -> String:
	return STATUS_LABELS.get(status, status)


static func status_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for status in Investigation.HYPOTHESIS_STATUSES:
		labels.append(status_label(status))
	return labels


# --- Elementos del tablero ---

## Elementos con los que el jugador puede trabajar, en orden de hallazgo dentro de cada tipo, con
## lo que necesita su ficha: rótulo del tipo, título y una línea breve (categoría, declarante o tipo
## de deducción).
static func items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in Investigation.get_board_items():
		var entry := item.duplicate()
		entry["kind_label"] = KIND_LABELS.get(item["kind"], "")
		entry["subtitle"] = _subtitle(item)
		result.append(entry)
	return result


## Ficha de comparación de un elemento: su tipo, título, texto completo y los datos que el jugador ya
## conoce de él (dónde se halló, quién lo declaró, en qué deducciones se usó). Vacía si no existe.
static func describe(item_id: String) -> Dictionary:
	var item := Investigation.get_item(item_id)
	if item.is_empty():
		return {}
	var facts: Array[Dictionary] = []
	match item["kind"]:
		"pista":
			var clue: Dictionary = GameData.clues.get(item_id, {})
			var where: String = clue.get("where", "")
			if not where.is_empty():
				facts.append({"icon": "ubicacion", "label": "Hallada en", "text": where})
		"testimonio":
			var speaker: String = item.get("tag", "")
			var character: Dictionary = GameData.characters.get(speaker, {})
			var who: String = character.get("name", "")
			var role: String = character.get("role", "")
			if not role.is_empty():
				who = "%s, %s" % [who, role.to_lower()]
			facts.append({"icon": "microfono", "label": "Declara", "text": who})
	var related := JournalInfo.related_deductions(item_id)
	if not related.is_empty():
		facts.append({"icon": "conexion", "label": "Ya relacionada en", "text": ", ".join(related)})
	return {
		"id": item_id,
		"kind": item["kind"],
		"kind_label": KIND_LABELS.get(item["kind"], ""),
		"subtitle": _subtitle(item),
		"title": item["title"],
		"text": item["text"],
		"facts": facts,
	}


static func _subtitle(item: Dictionary) -> String:
	match item["kind"]:
		"pista":
			return JournalInfo.CATEGORY_NAMES.get(item.get("tag", ""), "Prueba")
		"testimonio":
			return GameData.characters.get(item.get("tag", ""), {}).get("role", "")
		"deduccion":
			return JournalInfo.KIND_LABELS.get(item.get("tag", ""), "Deducción")
	return ""


# --- Relaciones ---

## Deducciones ya registradas que se pueden dibujar como un hilo entre dos fichas del tablero: cada
## una une la primera de sus parejas cuyos dos elementos están a la vista. Nada que el jugador no haya
## deducido aparece aquí.
static func relations(visible_ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deduction_id in GameState.deductions:
		var deduction: Dictionary = GameData.deductions.get(deduction_id, {})
		for pair: Array in deduction.get("pairs", []):
			if visible_ids.has(pair[0]) and visible_ids.has(pair[1]):
				result.append({"id": deduction_id, "from": pair[0], "to": pair[1], "kind": deduction.get("kind", "")})
				break
	return result


## Si dos elementos se pueden comparar: dos distintos y los dos en el expediente del jugador.
static func can_link(selection: Array) -> bool:
	return (
		selection.size() == 2
		and selection[0] != selection[1]
		and Investigation.has_item(selection[0])
		and Investigation.has_item(selection[1])
	)


# --- Teclas ---

## Primera tecla de una acción del InputMap, o vacío si no tiene.
static func key_name(action: String) -> String:
	return JournalInfo.key_name(action)
