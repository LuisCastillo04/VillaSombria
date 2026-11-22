class_name DialogueCast
extends Control
## Las siluetas de una conversación: el detective a la izquierda y su interlocutor a la derecha, con
## la ventana esmerilada a contraluz detrás de este.
##
## Es el mismo sistema de siempre, reunido en una pieza: quien tiene la palabra se ve con su color y
## el otro queda atenuado; la narración apaga a los dos; en las escenas sin interlocutor fijo la
## silueta de la derecha cambia con cada voz; las dos respiran y la de la derecha se balancea
## mientras habla. Las siluetas salen del campo `portrait` de `characters.json` (SVG o PNG), así que
## sirve para cualquier personaje. Quién habla lo dice `DialogueManager` a través de la interfaz:
## esta pieza no decide nada por su cuenta.
##
## Las figuras se colocan respecto a una zona 16:9 centrada y apoyada en el pie de la pantalla: a
## cualquier tamaño y proporción quedan a los lados de la ventana y por detrás de ella.

const FALLBACK_PORTRAIT := "res://assets/siluetas/detective.svg"
const DETECTIVE := "detective"
const NARRATOR := "narrador"
const ACTIVE_TINT := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_TINT := Color(0.5, 0.5, 0.56, 1.0)
## Zona de referencia: el ancho de una pantalla 16:9 en el lienzo lógico.
const STAGE_WIDTH := 1920.0
## Rectángulos de las figuras en esa zona, medidos desde el pie (y negativa): el del detective desde
## su borde izquierdo y el del interlocutor desde el derecho, para que cada uno siga a su lado.
const DETECTIVE_RECT := Rect2(30.0, -980.0, 500.0, 690.0)
const PORTRAIT_RECT := Rect2(-670.0, -1090.0, 690.0, 950.0)
## Contraluz detrás del interlocutor, en proporción de la zona.
const BACKLIGHT_LEFT := 0.52
const BACKLIGHT_TOP := 0.02
## Intensidad del contraluz según quién tenga la palabra: el interlocutor, el detective o nadie.
const BACKLIGHT_SPEAKING := 1.0
const BACKLIGHT_LISTENING := 0.7
## Recorrido de la entrada desde los lados.
const PORTRAIT_SLIDE := 120.0
const DETECTIVE_SLIDE := 90.0
## Respiración de las dos figuras y balanceo de la que habla.
const BREATH_SPEED := 1.6
const BREATH_HEIGHT := 5.0
const TALK_SPEED := 11.0
const TALK_HEIGHT := 2.5

## Si la voz que tiene la palabra está hablando ahora (su texto se escribe): se balancea.
var talking := false

var _npc_id := ""
var _speaker := ""
var _portrait_cache: Dictionary = {}
var _clock := 0.0
## 1 fuera de escena, 0 en su sitio.
var _slide := 1.0
var _tween: Tween
var _backlight_tween: Tween

@onready var _backlight: ColorRect = $Backlight
@onready var _detective: TextureRect = $Detective
@onready var _portrait: TextureRect = $Portrait


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detective.texture = _load_portrait(DETECTIVE)
	resized.connect(_apply_layout)
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	_apply_layout()


## Empieza una conversación: con un interlocutor fijo, su silueta a la derecha; sin él (una escena),
## la derecha queda vacía hasta que hable alguien que no sea el detective.
func begin(npc_id: String) -> void:
	_npc_id = npc_id
	_speaker = ""
	talking = false
	if not npc_id.is_empty():
		_portrait.texture = _load_portrait(npc_id)
	_portrait.visible = not npc_id.is_empty()
	_backlight.visible = _portrait.visible
	_detective.modulate = Color(IDLE_TINT, _detective.modulate.a)
	_portrait.modulate = Color(IDLE_TINT, _portrait.modulate.a)
	_set_backlight(BACKLIGHT_LISTENING, false)


## Da protagonismo a quien habla. La narración apaga ambas siluetas.
func set_speaker(speaker_id: String) -> void:
	_speaker = speaker_id
	var is_narrator := speaker_id == NARRATOR
	var is_detective := speaker_id == DETECTIVE
	if not is_narrator and not is_detective and speaker_id != _npc_id:
		# Escenas sin interlocutor fijo: la silueta cambia con cada voz.
		_portrait.texture = _load_portrait(speaker_id)
		_portrait.show()
		_backlight.show()
	var portrait_active := not is_narrator and not is_detective
	_tint(_portrait, ACTIVE_TINT if portrait_active else IDLE_TINT)
	_tint(_detective, ACTIVE_TINT if is_detective else IDLE_TINT)
	_set_backlight(BACKLIGHT_SPEAKING if portrait_active else BACKLIGHT_LISTENING, true)


## Entrada: las figuras llegan desde los lados mientras aparecen. Con `continuing` (una
## conversación que sigue a otra sin pausa) parten de donde estaban.
func play_entrance(continuing: bool = false) -> void:
	_restart_tween()
	if not continuing:
		_slide = 1.0
		modulate.a = 0.0
	_apply_layout()
	set_process(true)
	_tween.set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_slide", 0.0, DialogueStyle.OPEN_SECONDS)
	_tween.tween_property(self, "modulate:a", 1.0, 0.4)


## Salida: se desvanecen en su sitio.
func play_exit() -> void:
	_restart_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(set_process.bind(false))


func get_speaker() -> String:
	return _speaker


func get_portrait() -> TextureRect:
	return _portrait


func get_detective() -> TextureRect:
	return _detective


func get_backlight() -> ColorRect:
	return _backlight


## Silueta iluminada ahora: la de quien habla, o ninguna en la narración.
func get_lit_figure() -> TextureRect:
	if _speaker == DETECTIVE:
		return _detective
	if _speaker.is_empty() or _speaker == NARRATOR:
		return null
	return _portrait


## Zona 16:9 centrada en la que se colocan las figuras.
func get_stage_rect() -> Rect2:
	var width := minf(size.x, STAGE_WIDTH)
	return Rect2((size.x - width) * 0.5, 0.0, width, size.y)


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()


func _tint(target: CanvasItem, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", color, DialogueStyle.TINT_SECONDS)


## El contraluz se aviva cuando habla el interlocutor y se templa mientras escucha.
func _set_backlight(intensity: float, animate: bool) -> void:
	var material := _backlight.material as ShaderMaterial
	if material == null:
		return
	if _backlight_tween != null:
		_backlight_tween.kill()
		_backlight_tween = null
	if not animate:
		material.set_shader_parameter("intensity", intensity)
		return
	var current: float = material.get_shader_parameter("intensity")
	_backlight_tween = create_tween()
	_backlight_tween.tween_method(func(value: float) -> void:
		material.set_shader_parameter("intensity", value)
	, current, intensity, DialogueStyle.TINT_SECONDS * 1.5)


## Coloca las figuras con la entrada, la respiración y el leve balanceo de la que habla.
func _apply_layout() -> void:
	var stage := get_stage_rect()
	# Con el movimiento reducido, las siluetas no respiran, no se balancean ni entran deslizándose:
	# sólo se funden.
	var motion := UiAccessibility.motion()
	var breath := sin(_clock * BREATH_SPEED) * BREATH_HEIGHT * motion
	var speaking := talking and _speaker != DETECTIVE and _speaker != NARRATOR and not _speaker.is_empty()
	var talk := sin(_clock * TALK_SPEED) * TALK_HEIGHT * motion if speaking else 0.0
	# Las siluetas son decorado, no texto: con una letra más grande conservan su tamaño en pantalla
	# en lugar de crecer con la interfaz y salirse por arriba.
	var unscale := 1.0 / UiAccessibility.text_scale()
	_place(_detective, Vector2(stage.position.x, stage.end.y), _scaled(DETECTIVE_RECT, unscale), Vector2(-_slide * DETECTIVE_SLIDE * motion, breath))
	_place(_portrait, stage.end, _scaled(PORTRAIT_RECT, unscale), Vector2(_slide * PORTRAIT_SLIDE * motion, breath + talk))
	_backlight.position = Vector2(stage.position.x + stage.size.x * BACKLIGHT_LEFT, stage.size.y * BACKLIGHT_TOP)
	_backlight.size = Vector2(stage.end.x - _backlight.position.x, stage.size.y * (1.0 - BACKLIGHT_TOP))


static func _scaled(rect: Rect2, factor: float) -> Rect2:
	return Rect2(rect.position * factor, rect.size * factor)


func _place(figure: TextureRect, origin: Vector2, rect: Rect2, offset: Vector2) -> void:
	figure.position = origin + rect.position + offset
	figure.size = rect.size


func _load_portrait(character_id: String) -> Texture2D:
	if _portrait_cache.has(character_id):
		return _portrait_cache[character_id]
	var data: Dictionary = GameData.characters.get(character_id, {})
	var path: String = data.get("portrait", FALLBACK_PORTRAIT)
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture == null:
		texture = load(FALLBACK_PORTRAIT)
	_portrait_cache[character_id] = texture
	return texture
