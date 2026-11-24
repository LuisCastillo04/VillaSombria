class_name JournalInfo
extends RefCounted
## Todo lo que muestra el expediente, leído de los sistemas del juego: objetivos de `StoryDirector`,
## hallazgos de `GameState`, textos de `GameData`, paraderos de las rutinas, el reloj y las teclas
## del InputMap. Sólo consulta: no cambia nada ni guarda estado propio, de modo que el expediente
## enseña siempre lo mismo que el resto del juego, también después de cargar una partida.
##
## Cada función devuelve diccionarios sencillos que las secciones del expediente pintan. Los campos
## opcionales (una fecha, un lugar, una imagen) sólo aparecen si los datos los traen: el
## expediente nunca rellena huecos con datos inventados.

enum ObjectiveState { PENDING, ACTIVE, DONE }

const CASE_TITLE := "EXPEDIENTE 1948/17 · CASO VALDÉS"

const STATUS_LABELS := {
	"": "Sin valorar",
	"sospechoso": "Sospechoso",
	"descartado": "Descartado",
	"principal": "Principal sospechoso",
}

const CATEGORY_ICONS := {
	"documentos": "documento",
	"fotografias": "fotografia",
	"relojes": "reloj",
	"cartas": "carta",
	"objetos": "etiqueta",
	"huellas": "huella",
}
const CATEGORY_NAMES := {
	"documentos": "Documento",
	"fotografias": "Fotografía",
	"relojes": "Reloj",
	"cartas": "Carta",
	"objetos": "Objeto personal",
	"huellas": "Huella",
}

const KIND_LABELS := {"contradiccion": "Contradicción", "conexion": "Conexión"}
const KIND_ICONS := {"contradiccion": "contradiccion", "conexion": "conexion"}

## Parte de las siluetas que se ve en las miniaturas de las listas: cabeza y hombros.
const PORTRAIT_FACE := Rect2(110.0, 120.0, 580.0, 580.0)
## Parte que se ve en la fotografía de una ficha: de la cabeza al pecho.
const PORTRAIT_BUST := Rect2(40.0, 120.0, 720.0, 900.0)


# --- Calendario ---

static func day_title() -> String:
	return StoryDirector.get_day_title()


static func time_text() -> String:
	return GameClock.format_time()


# --- Objetivos ---

## Objetivos visibles del día con su estado: el primero pendiente es el activo (el mismo que
## enseña el HUD), los demás pendientes esperan y los cumplidos van al final.
static func objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active_found := false
	for objective: Dictionary in StoryDirector.get_objectives():
		var state := ObjectiveState.DONE
		if not bool(objective["done"]):
			state = ObjectiveState.PENDING if active_found else ObjectiveState.ACTIVE
			active_found = true
		result.append({"id": objective.get("id", ""), "text": objective["text"], "state": state})
	return result


## Recuento de la investigación. Los testimonios no muestran el total para no adelantar cuántas
## declaraciones quedan por oír.
static func stats() -> Dictionary:
	return {
		"clues": GameState.clues.size(),
		"clues_total": GameData.clues.size(),
		"testimonies": GameState.testimonies.size(),
		"deductions": GameState.deductions.size(),
		"deductions_total": GameData.deductions.size(),
	}


## Reglas del tiempo, con las cifras y las teclas reales del juego. Cada regla trae su icono.
static func time_rules() -> Array[Dictionary]:
	var rest_place: String = GameData.locations.get(Game.REST_LOCATION, {}).get("name", "la pensión")
	var limit := "%02d:%02d" % [GameClock.DAY_LIMIT / 60, GameClock.DAY_LIMIT % 60]
	return [
		{"icon": "reloj", "text": "El reloj sólo avanza con tus acciones, nunca mientras lees el expediente."},
		{"icon": "testigos", "text": "Cada pregunta nueva lleva %d minutos; examinar una pista, %d; relacionar dos pruebas en el tablero, %d. Ir de un lugar a otro también lleva su tiempo." % [DialogueManager.TOPIC_MINUTES, Investigation.CLUE_MINUTES, BoardUi.LINK_MINUTES]},
		{"icon": "cronometro", "key": key_name("wait_time"), "text": "deja pasar una hora. A las %s el reloj se detiene hasta que descanses en %s." % [limit, rest_place]},
		{"icon": "antifaz", "text": "Ninguna prueba se pierde por llegar tarde. Cada personaje sigue su rutina: su paradero está en Sospechosos."},
	]


# --- Pistas ---

static func clues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clue_id in GameState.clues:
		var clue: Dictionary = GameData.clues.get(clue_id, {})
		if clue.is_empty():
			continue
		var category: String = clue.get("category", "")
		result.append({
			"id": clue_id,
			"title": clue["name"],
			"category": CATEGORY_NAMES.get(category, "Prueba"),
			"icon": CATEGORY_ICONS.get(category, "lupa"),
			"where": clue.get("where", ""),
			"text": clue.get("description", ""),
			# Imagen propia de la pista, si los datos la traen; si no, la ficha ilustra su categoría.
			"image": clue.get("image", ""),
		})
	return result


# --- Testimonios ---

## Declaraciones registradas, agrupadas por personaje en el orden de `characters.json` y, dentro de
## cada uno, en el orden en que se oyeron.
static func testimonies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for character_id: String in GameData.characters:
		for testimony_id in GameState.testimonies:
			var testimony: Dictionary = GameData.testimonies.get(testimony_id, {})
			if testimony.get("speaker", "") != character_id:
				continue
			var character: Dictionary = GameData.characters[character_id]
			result.append({
				"id": testimony_id,
				"speaker": character_id,
				"name": character.get("name", ""),
				"role": character.get("role", ""),
				"portrait": character.get("portrait", ""),
				"topic": testimony.get("topic", ""),
				"text": testimony.get("text", ""),
				# Campos opcionales: sólo si `testimonies.json` los trae.
				"day": testimony.get("day", ""),
				"where": testimony.get("where", ""),
				"related": related_deductions(testimony_id),
			})
	return result


# --- Sospechosos ---

static func suspects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for suspect_id in GameData.get_suspects():
		var character: Dictionary = GameData.characters[suspect_id]
		var hypothesis: Dictionary = GameState.hypotheses.get(suspect_id, {})
		var status: String = hypothesis.get("status", "")
		result.append({
			"id": suspect_id,
			"name": character.get("name", ""),
			"role": character.get("role", ""),
			"bio": character.get("bio", ""),
			"portrait": character.get("portrait", ""),
			"whereabouts": StoryDirector.describe_whereabouts(suspect_id),
			"status": status,
			"status_label": STATUS_LABELS.get(status, status),
			"note": hypothesis.get("note", ""),
			"testimonies": testimony_count(suspect_id),
			# Cómo va su interrogatorio: lo mismo que se anuncia al acercarse a él.
			"interrogation": ConversationLog.STATUS_LABELS.get(ConversationLog.npc_status(suspect_id), ""),
		})
	return result


static func testimony_count(character_id: String) -> int:
	var count := 0
	for testimony_id in GameState.testimonies:
		if GameData.testimonies.get(testimony_id, {}).get("speaker", "") == character_id:
			count += 1
	return count


# --- Deducciones ---

## Deducciones halladas con las pruebas y declaraciones que las sostienen. Sólo cuentan las parejas
## que el jugador tiene completas: una pieza que aún no conoce nunca aparece aquí.
static func deductions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deduction_id in GameState.deductions:
		var deduction: Dictionary = GameData.deductions.get(deduction_id, {})
		if deduction.is_empty():
			continue
		var kind: String = deduction.get("kind", "")
		var evidence: Array[Dictionary] = []
		var seen := PackedStringArray()
		for pair: Array in deduction.get("pairs", []):
			if not (Investigation.has_item(pair[0]) and Investigation.has_item(pair[1])):
				continue
			for item_id: String in pair:
				if seen.has(item_id):
					continue
				seen.append(item_id)
				evidence.append(_evidence_entry(item_id))
		result.append({
			"id": deduction_id,
			"title": deduction.get("title", ""),
			"kind": kind,
			"kind_label": KIND_LABELS.get(kind, "Deducción"),
			"icon": KIND_ICONS.get(kind, "cerebro"),
			"text": deduction.get("text", ""),
			"evidence": evidence,
		})
	return result


## Deducciones ya halladas en las que interviene un elemento del expediente.
static func related_deductions(item_id: String) -> PackedStringArray:
	var titles := PackedStringArray()
	for deduction_id in GameState.deductions:
		for pair: Array in GameData.deductions.get(deduction_id, {}).get("pairs", []):
			if pair.has(item_id) and Investigation.has_item(pair[0]) and Investigation.has_item(pair[1]):
				titles.append(GameData.deductions[deduction_id]["title"])
				break
	return titles


static func _evidence_entry(item_id: String) -> Dictionary:
	var item := Investigation.get_item(item_id)
	var icon := "cerebro"
	match item.get("kind", ""):
		"pista":
			icon = CATEGORY_ICONS.get(item.get("tag", ""), "lupa")
		"testimonio":
			icon = "testigos"
	return {"id": item_id, "kind": item.get("kind", ""), "title": item.get("title", ""), "icon": icon}


# --- Retratos y teclas ---

## Recorte de una silueta de personaje. Devuelve null si el archivo no existe.
static func portrait(path: String, region: Rect2) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = region
	return atlas


## Primera tecla asignada a una acción (o su botón, si se juega con mando), o vacío si no tiene.
static func key_name(action: String) -> String:
	var keys := InputLabels.keys_of(action, InputLabels.Device.CURRENT)
	return keys[0] if not keys.is_empty() else ""
