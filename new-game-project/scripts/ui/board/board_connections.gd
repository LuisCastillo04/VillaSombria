class_name BoardConnections
extends Control
## Hilos del corcho. Hay tres clases, y se distinguen a simple vista:
## - relaciones registradas: hilo rojo y tenso entre las chinchetas de dos fichas, una por cada
##   deducción que el jugador ya estableció (`BoardInfo.relations()`, que nunca incluye deducciones sin
##   descubrir). Con una ficha elegida, sus hilos se avivan y los demás se apagan;
## - la comparación en curso: un hilo a trazos, más claro, con un nudo de latón en medio, entre los dos
##   elementos elegidos. No afirma nada: sólo dice qué se está comparando;
## - decorativos: bramante pardo a trazos entre los huecos libres del corcho. No une ninguna ficha.
##
## Los hilos van por encima del corcho pero pasan por detrás del papel: donde cruzarían una ficha o un
## rótulo no se dibujan, salvo en la franja superior de sus propias fichas, donde nace el hilo junto a
## la chincheta y no hay texto. Así nunca tapan un texto, y este nodo no recibe el ratón.

const WIDTH := 2.6
const FOCUS_WIDTH := 3.4
## Alto de la franja superior de una ficha por la que puede pasar su propio hilo (el texto empieza
## más abajo).
const TOP_STRIP := 19.0
## Separación de las muestras con las que se decide qué tramos se ven.
const SAMPLE_STEP := 3.0
## Los hilos empiezan y terminan al borde de la chincheta, que queda por encima.
const PIN_GAP := 5.0
const TWINE := Color(0.42, 0.29, 0.17, 0.55)
## El nudo de la comparación sólo se ata en un tramo visible de al menos este largo.
const KNOT_MIN_RUN := 24.0

## Relaciones registradas: {id, from, to, kind}.
var _relations: Array[Dictionary] = []
## Elementos elegidos para comparar.
var _focus: Array[String] = []
## Pares de puntos del bramante decorativo, en coordenadas del contenido.
var _decorative: Array[PackedVector2Array] = []
var _animated := ""
var _progress := 1.0:
	set(value):
		_progress = value
		queue_redraw()
## Devuelve la chincheta de una ficha por su identificador (o `Vector2.INF` si no está).
var _pin_of: Callable
## Devuelve los controles bajo los que pasan los hilos (fichas y rótulos).
var _occluders: Callable
var _tween: Tween


func _init() -> void:
	name = "Connections"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(pin_of: Callable, occluders: Callable) -> void:
	_pin_of = pin_of
	_occluders = occluders


func set_relations(relations: Array[Dictionary]) -> void:
	_relations = relations
	queue_redraw()


## Elementos elegidos para comparar, en orden.
func set_focus(ids: Array[String]) -> void:
	_focus = ids.duplicate()
	queue_redraw()


func set_decorative(segments: Array[PackedVector2Array]) -> void:
	_decorative = segments
	queue_redraw()


## Tiende poco a poco el hilo de una relación recién registrada.
func animate_relation(deduction_id: String) -> void:
	_animated = deduction_id
	if _tween != null:
		_tween.kill()
	if not is_inside_tree():
		_progress = 1.0
		return
	_progress = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_progress", 1.0, BoardStyle.THREAD_SECONDS)


func get_relations() -> Array[Dictionary]:
	return _relations


## Los dos elementos unidos por el hilo de la comparación en curso, o vacío.
func get_pending() -> Array[String]:
	var pending: Array[String] = []
	if _focus.size() == 2:
		pending.assign(_focus)
	return pending


## Si el hilo de una relación está avivado porque toca un elemento elegido.
func is_highlighted(deduction_id: String) -> bool:
	for relation in _relations:
		if relation["id"] == deduction_id:
			return _touches_focus(relation)
	return false


func get_decorative_count() -> int:
	return _decorative.size()


func _touches_focus(relation: Dictionary) -> bool:
	return _focus.has(relation["from"]) or _focus.has(relation["to"])


func _draw() -> void:
	if not _pin_of.is_valid():
		return
	var occluders: Array = _occluders.call() if _occluders.is_valid() else []
	for segment in _decorative:
		var direction := segment[0].direction_to(segment[1])
		var twine := BoardOrnaments.thread_points(segment[0] + direction * PIN_GAP, segment[1] - direction * PIN_GAP, 0.06)
		_draw_hidden_behind(twine, occluders, [], TWINE, 1.6, true)
	# Primero los hilos apagados y después los de la ficha elegida, que quedan por encima.
	for highlighted: bool in [false, true]:
		for relation in _relations:
			if _touches_focus(relation) != highlighted:
				continue
			var color := BoardStyle.THREAD
			var width := WIDTH
			if highlighted:
				color = BoardStyle.THREAD.lightened(0.12)
				width = FOCUS_WIDTH
			elif not _focus.is_empty():
				color = Color(BoardStyle.THREAD, 0.4)
			var progress := _progress if relation["id"] == _animated else 1.0
			_draw_link(relation["from"], relation["to"], color, width, progress, false, occluders)
	if _focus.size() == 2:
		var from: Vector2 = _pin_of.call(_focus[0])
		var to: Vector2 = _pin_of.call(_focus[1])
		if from != Vector2.INF and to != Vector2.INF:
			var runs := _draw_link(_focus[0], _focus[1], Color(BoardStyle.THREAD.lightened(0.25), 0.8), 2.2, 1.0, true, occluders)
			# El nudo, en medio del tramo más largo que se ve: nunca sobre una ficha.
			var longest := PackedVector2Array()
			for run in runs:
				if run.size() > longest.size():
					longest = run
			if longest.size() * SAMPLE_STEP >= KNOT_MIN_RUN:
				BoardOrnaments.draw_knot(self, longest[longest.size() / 2], 6.0)


## Dibuja el hilo entre dos fichas y devuelve los tramos que se ven.
func _draw_link(from_id: String, to_id: String, color: Color, width: float, progress: float, dashed: bool, occluders: Array) -> Array[PackedVector2Array]:
	var from: Vector2 = _pin_of.call(from_id)
	var to: Vector2 = _pin_of.call(to_id)
	if from == Vector2.INF or to == Vector2.INF or from.distance_to(to) < PIN_GAP * 2.0:
		return []
	var direction := from.direction_to(to)
	var points := BoardOrnaments.thread_points(from + direction * PIN_GAP, to - direction * PIN_GAP)
	if progress < 1.0:
		points = BoardOrnaments.partial(points, progress)
	return _draw_hidden_behind(points, occluders, [from_id, to_id], color, width, dashed)


## Dibuja los tramos de una curva que no quedan detrás de un papel y los devuelve. Las fichas de
## `ends` dejan ver el hilo en su franja superior.
func _draw_hidden_behind(points: PackedVector2Array, occluders: Array, ends: Array, color: Color, width: float, dashed: bool) -> Array[PackedVector2Array]:
	var runs: Array[PackedVector2Array] = []
	if points.size() < 2:
		return runs
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	bounds = bounds.grow(BoardStyle.CARD_SIZE.length() * 0.6)
	var nearby: Array[Control] = []
	for item: Control in occluders:
		if is_instance_valid(item) and item.visible and bounds.intersects(item.get_rect()):
			nearby.append(item)
	var run := PackedVector2Array()
	for point in BoardOrnaments.resample(points, SAMPLE_STEP):
		if _is_hidden(point, nearby, ends):
			if run.size() >= 2:
				runs.append(run)
			run = PackedVector2Array()
		else:
			run.append(point)
	if run.size() >= 2:
		runs.append(run)
	for visible in runs:
		BoardOrnaments.draw_thread_path(self, visible, color, width, dashed)
	return runs


func _is_hidden(point: Vector2, nearby: Array[Control], ends: Array) -> bool:
	for item in nearby:
		var local := item.get_transform().affine_inverse() * point
		if not Rect2(Vector2.ZERO, item.size).grow(-0.5).has_point(local):
			continue
		var card := item as BoardEvidenceCard
		if card != null and ends.has(card.item_id) and local.y < TOP_STRIP:
			continue
		return true
	return false
