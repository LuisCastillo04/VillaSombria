class_name AudioLoop
extends RefCounted
## Un bucle que entra y sale con fundidos: una pista de música o una capa de ambiente, plana o
## colocada en el mundo. Su volumen es la suma de tres partes independientes:
##
## - `base_db`: el de la capa (catálogo y lugar), fijo mientras suena.
## - `extra_db`: las atenuaciones del momento (diálogo, pausa, fragmento musical), que fija su dueño.
## - `gain` × `scale`: el fundido de entrada o salida y, para la música, los silencios intencionados.
##
## Separarlas permite, por ejemplo, atenuar la música por un diálogo mientras termina un fundido
## cruzado sin que un cambio pise al otro.

const SILENCE := 0.0001

var key := ""
var player: Node
var base_db := 0.0
var extra_db := 0.0
var gain := 0.0
var scale := 1.0
## Se está apagando para liberarse: ya no cuenta como capa activa.
var retiring := false

var _tween: Tween


func _init(loop_key: String, loop_player: Node, volume_db: float) -> void:
	key = loop_key
	player = loop_player
	base_db = volume_db


func apply() -> void:
	if not is_instance_valid(player):
		return
	player.set("volume_db", base_db + extra_db + linear_to_db(maxf(gain * scale, SILENCE)))


func set_gain(value: float) -> void:
	gain = value
	apply()


## Lleva el fundido a `target` en `seconds` con una curva suave (potencia casi constante en los
## fundidos cruzados). Con `release`, al terminar detiene el reproductor y lo libera.
func fade_to(owner: Node, target: float, seconds: float, release: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if release:
		retiring = true
	if seconds <= 0.0 or not owner.is_inside_tree():
		set_gain(target)
		if release:
			free_player()
		return
	_tween = owner.create_tween()
	_tween.tween_method(set_gain, gain, target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if release:
		_tween.tween_callback(free_player)


func is_fading() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func free_player() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(player):
		player.call("stop")
		player.set("stream", null)
		player.queue_free()
	player = null


func is_alive() -> bool:
	return is_instance_valid(player) and not retiring
