class_name StateMachine
extends Node
## Node-based Finite State Machine.
## Discovers all child State nodes automatically and routes lifecycle callbacks
## to the active state. Reusable across Player, Enemies, and NPCs.

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: State = null
@export var debug_log: bool = false

var current_state: State = null
var previous_state_name: StringName = &""

var _states: Dictionary = {}
var _character: Character3D = null


func _ready() -> void:
	_character = get_parent() as Character3D
	_register_states()

	var start_state: State = initial_state
	if start_state == null and get_child_count() > 0:
		for child in get_children():
			if child is State:
				start_state = child
				break

	if start_state != null:
		call_deferred(&"transition_to", StringName(start_state.name))


func _process(delta: float) -> void:
	if current_state == null:
		return
	if _character and _character.is_hitstop_active():
		return
	current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	if _character and _character.is_hitstop_active():
		return
	current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state == null:
		return
	if _character and _character.is_hitstop_active():
		return
	current_state.handle_input(event)


func _register_states() -> void:
	_states.clear()
	for child in get_children():
		if child is State:
			var state_node: State = child as State
			state_node.state_machine = self
			state_node.character = _character
			_states[StringName(state_node.name.to_lower())] = state_node


func has_state(state_name: StringName) -> bool:
	return _states.has(StringName(String(state_name).to_lower()))


func get_state(state_name: StringName) -> State:
	return _states.get(StringName(String(state_name).to_lower()), null) as State


func get_current_state_name() -> StringName:
	return StringName(current_state.name) if current_state != null else &""


func is_in_state(state_name: StringName) -> bool:
	if current_state == null:
		return false
	return current_state.name.to_lower() == String(state_name).to_lower()


func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> bool:
	var target: State = get_state(target_state_name)
	if target == null:
		if debug_log:
			push_warning("StateMachine (%s): missing state '%s'" % [
				_character.name if _character else name, target_state_name
			])
		return false

	if not target.can_enter(msg):
		return false

	var from_name: StringName = get_current_state_name()
	if current_state != null:
		previous_state_name = from_name
		current_state.exit()

	current_state = target
	if debug_log:
		print("[FSM] %s: %s -> %s" % [
			_character.name if _character else name,
			from_name if from_name != &"" else &"<init>",
			current_state.name
		])
	current_state.enter(msg)
	state_changed.emit(from_name, StringName(current_state.name))
	return true
