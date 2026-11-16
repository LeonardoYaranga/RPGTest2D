class_name GetUpState
extends State
## Wakeup recovery state after knockdown, with optional wakeup i-frames.

@export var next_state: StringName = &"Idle"
@export var getup_duration: float = 0.35
@export var invulnerable_on_wakeup: bool = true

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = getup_duration
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	character.set_knockdown_pose(false)
	character.play_anim(&"getup")
	if invulnerable_on_wakeup:
		character.set_hurtbox_enabled(false)


func exit() -> void:
	if invulnerable_on_wakeup:
		character.set_hurtbox_enabled(true)


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.move_and_slide()

	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(next_state)
