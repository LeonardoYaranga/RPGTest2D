class_name KnockdownState
extends State
## Floor knockdown state after landing from a launch.
## Grants temporary floor invulnerability unless disabled, then transitions to GetUp.

@export var getup_state: StringName = &"GetUp"
@export var fallback_state: StringName = &"Idle"
@export var knockdown_duration: float = 0.85
@export var slide_friction: float = 9.0
@export var invulnerable_while_down: bool = true

var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_timer = float(msg.get("duration", knockdown_duration))
	character.set_knockdown_pose(true)
	character.play_anim(&"knockdown")
	if msg.has("knockback"):
		var kb: Vector3 = msg.get("knockback", Vector3.ZERO)
		character.velocity.x = kb.x
		character.velocity.z = kb.z
	if invulnerable_while_down:
		character.set_hurtbox_enabled(false)


func exit() -> void:
	character.set_knockdown_pose(false)
	if invulnerable_while_down:
		character.set_hurtbox_enabled(true)


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.apply_ground_friction(slide_friction, delta)
	character.move_and_slide()

	_timer -= delta
	if _timer <= 0.0:
		if not state_machine.transition_to(getup_state):
			state_machine.transition_to(fallback_state)
