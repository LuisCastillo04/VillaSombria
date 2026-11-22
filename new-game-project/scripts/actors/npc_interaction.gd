class_name NpcInteraction
extends Interactable
## Punto de interacción de un NPC. Inicia la conversación y avisa de si hay preguntas
## nuevas mostrando su marcador a distancia.

var _npc: Npc


func setup(npc: Npc) -> void:
	_npc = npc
	prompt = "Hablar con %s" % GameData.characters[npc.npc_id].get("short", npc.display_name)
	set_marker_height(1.35)
	refresh_marker()


## El detective lo enfoca o deja de enfocarlo: el NPC se detiene a mirarlo o sigue con lo suyo.
func set_focused(value: bool) -> void:
	super.set_focused(value)
	if _npc != null:
		_npc.notice_player(value)


## Avisa de que tiene preguntas nuevas, salvo si se está yendo del escenario.
func wants_attention() -> bool:
	return _npc != null and not _npc.is_leaving() and DialogueManager.has_new_topics(_npc.npc_id)


func interact(actor: Node) -> void:
	super.interact(actor)
	_npc.begin_talk(actor as Node3D)
	if actor is PlayerController:
		(actor as PlayerController).look_towards(_npc.global_position)
	DialogueManager.start(_npc.npc_id)
