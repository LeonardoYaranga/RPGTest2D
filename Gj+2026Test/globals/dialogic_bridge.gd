extends Node

## Puente entre Dialogic 2, el sistema de juego y GameState.
## Autoload accesible como `DialogicBridge`.

signal dialog_started(timeline_name: String)
signal dialog_ended(timeline_name: String)
signal combat_requested(boss_id: StringName)

var _is_dialog_active: bool = false
var _current_timeline: String = ""
var _pending_callbacks: Array[Callable] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_dialogic.call_deferred()


func _connect_dialogic() -> void:
	if is_instance_valid(Dialogic):
		if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
			Dialogic.signal_event.connect(_on_dialogic_signal)
		if not Dialogic.timeline_ended.is_connected(_on_dialogic_timeline_ended):
			Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	else:
		push_warning("[DialogicBridge] Autoload Dialogic no encontrado.")


func is_dialog_active() -> bool:
	return _is_dialog_active


## Inicia una línea de tiempo de Dialogic y bloquea el control del jugador.
func start_timeline(timeline_name: String, on_finished: Callable = Callable()) -> bool:
	if not is_instance_valid(Dialogic):
		push_warning("[DialogicBridge] Dialogic no está disponible para iniciar: %s" % timeline_name)
		return false

	if on_finished.is_valid():
		_pending_callbacks.append(on_finished)

	_is_dialog_active = true
	_current_timeline = timeline_name
	SignalHub.emit_on_player_control_blocked(true)
	dialog_started.emit(timeline_name)

	Dialogic.start(timeline_name)
	return true


func _on_dialogic_timeline_ended() -> void:
	var ended_timeline := _current_timeline
	_current_timeline = ""
	_is_dialog_active = false
	SignalHub.emit_on_player_control_blocked(false)
	dialog_ended.emit(ended_timeline)

	while not _pending_callbacks.is_empty():
		var cb: Callable = _pending_callbacks.pop_front()
		if cb.is_valid():
			cb.call()


## Procesa eventos [signal arg="..."] emitidos por timelines de Dialogic
func _on_dialogic_signal(argument: String) -> void:
	if argument.is_empty():
		return

	var parts: PackedStringArray = argument.split(":", true, 1)
	var command: String = parts[0].strip_edges()
	var payload: String = parts[1].strip_edges() if parts.size() > 1 else ""

	match command:
		"give_item":
			var item_parts := payload.split(":")
			var item_id := StringName(item_parts[0].strip_edges())
			var count := int(item_parts[1].strip_edges()) if item_parts.size() > 1 else 1
			GameState.add_item(item_id, count)

		"take_item":
			var item_parts := payload.split(":")
			var item_id := StringName(item_parts[0].strip_edges())
			var count := int(item_parts[1].strip_edges()) if item_parts.size() > 1 else 1
			GameState.consume_item(item_id, count)

		"set_flag":
			var eq_parts := payload.split("=")
			if eq_parts.size() >= 2:
				var flag_name := StringName(eq_parts[0].strip_edges())
				var raw_val := eq_parts[1].strip_edges()
				var val: Variant = raw_val
				if raw_val.to_lower() == "true":
					val = true
				elif raw_val.to_lower() == "false":
					val = false
				elif raw_val.is_valid_int():
					val = raw_val.to_int()
				GameState.set_flag(flag_name, val)

		"add_bond":
			var bond_parts := payload.split(":")
			var npc_id := StringName(bond_parts[0].strip_edges())
			var amount := int(bond_parts[1].strip_edges()) if bond_parts.size() > 1 else 1
			GameState.add_bond(npc_id, amount)

		"quest":
			var q_parts := payload.split("|")
			var title := q_parts[0].strip_edges()
			var objective := q_parts[1].strip_edges() if q_parts.size() > 1 else ""
			GameState.set_quest(title, objective)

		"start_combat", "start_boss_fight":
			var boss_id := StringName(payload) if not payload.is_empty() else &"bully"
			combat_requested.emit(boss_id)

		"ending":
			var ending_id := StringName(payload) if not payload.is_empty() else &"default"
			GameState.set_flag(&"ending_id", ending_id)
			if GameManager and GameManager.has_method(&"trigger_ending"):
				GameManager.trigger_ending(ending_id)

		"change_scene":
			var room_parts := payload.split(":")
			var path := room_parts[0].strip_edges()
			var spawn_id := StringName(room_parts[1].strip_edges()) if room_parts.size() > 1 else &"PlayerPos"
			if GameManager and GameManager.has_method(&"change_scene_to_room"):
				GameManager.change_scene_to_room(path, spawn_id)
			elif GameManager and GameManager.has_method(&"change_scene_to_file"):
				GameManager.change_scene_to_file(path)
