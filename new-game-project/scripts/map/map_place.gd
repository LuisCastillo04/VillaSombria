class_name MapPlace
extends RefCounted
## Lugar del pueblo que aparece en el mapa: un escenario exterior o el edificio de un interior.
## Sus datos vienen de `data/map.json`; el nombre, si no se indica, es el del escenario en
## `data/locations.json`.

var id := ""
## Escenarios que pertenecen al lugar. Estar en cualquiera de ellos es estar en el lugar.
var location_ids: PackedStringArray = []
## Zona del mapa donde está su chincheta, y su posición en los metros de esa zona.
var region_id := ""
var anchor := Vector2.ZERO
var label := ""
## Objetivos de `story.json` que se cumplen en este lugar.
var objective_ids: PackedStringArray = []
## Condiciones con el formato de `Conditions`. Vacías, el lugar es conocido y está abierto.
var discovered_if: Dictionary = {}
var available_if: Dictionary = {}
## Si muestra chincheta de punto de interés.
var interest := true
## Lado de la chincheta donde va el rótulo: "below" o "above".
var label_side := "below"
var error := ""


static func from_data(data: Dictionary) -> MapPlace:
	var place := MapPlace.new()
	place.id = str(data.get("id", ""))
	if place.id.is_empty():
		place.error = "Hay un lugar sin identificador."
		return place
	place.location_ids = PackedStringArray(data.get("locations", []))
	place.region_id = str(data.get("region", ""))
	var where: Variant = data.get("anchor")
	if where is Array and (where as Array).size() == 2:
		place.anchor = Vector2(float(where[0]), float(where[1]))
	else:
		place.error = "El lugar «%s» no indica dónde está (anchor)." % place.id
	place.label = str(data.get("label", ""))
	place.objective_ids = PackedStringArray(data.get("objectives", []))
	place.discovered_if = data.get("discovered_if", {})
	place.available_if = data.get("available_if", {})
	place.interest = bool(data.get("interest", true))
	place.label_side = str(data.get("label_side", "below"))
	if place.location_ids.is_empty():
		place.error = "El lugar «%s» no pertenece a ningún escenario." % place.id
	return place


func is_valid() -> bool:
	return error.is_empty()
