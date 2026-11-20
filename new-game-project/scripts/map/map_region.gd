class_name MapRegion
extends RefCounted
## Zona del mapa que representa un escenario exterior punto por punto: la plaza o la estación.
## Convierte la posición del detective (X y Z del mundo) en un punto del lienzo con la
## transformación calibrada, y la limita al área por la que se puede caminar para que el marcador
## nunca se salga de la zona dibujada.

var id := ""
var location_id := ""
## Área transitable del escenario en X y Z: los muros invisibles que lo cierran.
var bounds := Rect2()
var anchors: Array = []
var transform := Transform2D.IDENTITY
## Error de cada punto de referencia, en unidades del lienzo.
var residuals: Dictionary = {}
var error := ""


static func from_data(region_id: String, data: Dictionary) -> MapRegion:
	var region := MapRegion.new()
	region.id = region_id
	region.location_id = str(data.get("location", region_id))
	var limits: Variant = data.get("bounds")
	if limits is Array and (limits as Array).size() == 4:
		var low := Vector2(float(limits[0]), float(limits[1]))
		var high := Vector2(float(limits[2]), float(limits[3]))
		region.bounds = Rect2(low, high - low).abs()
	else:
		region.error = "La zona «%s» no indica su área transitable (bounds)." % region_id
		return region
	region.anchors = data.get("anchors", [])
	var calibration := MapCalibration.fit(region.anchors)
	region.transform = calibration["transform"]
	region.residuals = calibration.get("residuals", {})
	if not calibration["ok"]:
		region.error = "Zona «%s»: %s" % [region_id, calibration["error"]]
	return region


func is_valid() -> bool:
	return error.is_empty() and bounds.has_area()


func contains(world: Vector2) -> bool:
	return bounds.grow(0.001).has_point(world)


func clamp_to_bounds(world: Vector2) -> Vector2:
	return world.clamp(bounds.position, bounds.end)


func world_to_map(world: Vector2) -> Vector2:
	return transform * world


## Dirección del mundo vista en el lienzo, normalizada.
func map_direction(world_direction: Vector2) -> Vector2:
	return transform.basis_xform(world_direction).normalized()


## Unidades del lienzo por metro del escenario.
func map_units_per_meter() -> float:
	return sqrt(absf(transform.determinant()))


## Contorno del área transitable en el lienzo, para comprobar que cabe en él.
func map_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for corner: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		outline.append(world_to_map(corner))
	return outline
