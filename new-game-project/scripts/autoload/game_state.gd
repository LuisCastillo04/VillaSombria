extends Node
## Estado de la partida en curso.

var _player_locks: Dictionary = {}


## Bloquea el control del jugador. Cada sistema usa su propio motivo, de modo que
## cerrar un panel no libera el control si otro sigue abierto.
func lock_player(reason: String) -> void:
	_player_locks[reason] = true


func unlock_player(reason: String) -> void:
	_player_locks.erase(reason)


func is_player_locked() -> bool:
	return not _player_locks.is_empty()


func clear_player_locks() -> void:
	_player_locks.clear()
