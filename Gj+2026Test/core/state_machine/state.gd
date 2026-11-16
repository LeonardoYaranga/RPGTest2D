class_name State
extends Node
## Base class for all node-based FSM states.
## Attach scripts extending State as children of a StateMachine node.

var state_machine: StateMachine = null
var character: Character3D = null


## Called when the StateMachine enters this state.
func enter(_msg: Dictionary = {}) -> void:
	pass


## Called right before leaving this state.
func exit() -> void:
	pass


## Called every visual frame (_process) while active (paused during hitstop).
func update(_delta: float) -> void:
	pass


## Called every physics tick (_physics_process) while active (paused during hitstop).
func physics_update(_delta: float) -> void:
	pass


## Called on _unhandled_input while active.
func handle_input(_event: InputEvent) -> void:
	pass


## Return false to block transitions into this state (e.g. super armor).
func can_enter(_msg: Dictionary = {}) -> bool:
	return true
