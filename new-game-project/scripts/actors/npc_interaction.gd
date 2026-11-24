class_name NpcInteraction
extends Interactable
## Punto de interacción de un NPC. Inicia la conversación y avisa de cómo va su interrogatorio
## (`ConversationLog.npc_status`) sin saturar el escenario:
##
## - Con preguntas pendientes, su rombo se ve a distancia; si alguna es recién desbloqueada, el rombo
##   es más claro y late despacio.
## - Al acercarse, el aviso del HUD añade su situación: «Nuevas preguntas», «Preguntas pendientes»,
##   «Sin novedades por ahora» (todo hecho, pero la investigación aún puede abrir algo) o
##   «Interrogatorio completo».
## Se pone al día solo con la investigación (pistas, testimonios, deducciones, marcas, días y
## conversaciones).

var _npc: Npc


func setup(npc: Npc) -> void:
	_npc = npc
	prompt = "Hablar con %s" % GameData.characters[npc.npc_id].get("short", npc.display_name)
	set_marker_height(1.35)
	refresh_marker()
	for progress: Signal in [EventBus.clue_discovered, EventBus.testimony_recorded, EventBus.deduction_made, EventBus.flag_set, EventBus.conversation_recorded]:
		if not progress.is_connected(_on_progress):
			progress.connect(_on_progress)
	if not EventBus.day_changed.is_connected(_on_progress):
		EventBus.day_changed.connect(_on_progress)


## El detective lo enfoca o deja de enfocarlo: el NPC se detiene a mirarlo o sigue con lo suyo.
func set_focused(value: bool) -> void:
	super.set_focused(value)
	if _npc != null:
		_npc.notice_player(value)


## Avisa de que tiene preguntas pendientes, salvo si se está yendo del escenario.
func wants_attention() -> bool:
	return _npc != null and not _npc.is_leaving() and DialogueManager.has_new_topics(_npc.npc_id)


## Destaca si alguna de ellas es recién desbloqueada.
func wants_emphasis() -> bool:
	return wants_attention() and get_status_kind() == ConversationLog.STATUS_NEW


func get_status_kind() -> String:
	return ConversationLog.npc_status(_npc.npc_id) if _npc != null else ""


func get_status_text() -> String:
	return String(ConversationLog.STATUS_LABELS.get(get_status_kind(), ""))


## Algo ha cambiado en la investigación: el marcador y el aviso se ponen al día. Acepta cualquier
## argumento de las señales que lo llaman.
func _on_progress(_a: Variant = null, _b: Variant = null) -> void:
	refresh_marker()


func interact(actor: Node) -> void:
	super.interact(actor)
	_npc.begin_talk(actor as Node3D)
	if actor is PlayerController:
		(actor as PlayerController).look_towards(_npc.global_position)
	DialogueManager.start(_npc.npc_id)
