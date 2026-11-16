class_name LaunchedState
extends State
## Airborne juggle / launch reaction (River City Girls 2 style).
## Keeps character airborne with gravity until landing, then transitions to Knockdown.

@export var landing_state: StringName = &"Knockdown"
@export var fallback_state: StringName = &"Idle"
@export var air_drag: float = 1.6
@export var gravity_multiplier: float = 1.0
@export var min_air_time: float = 0.08

var _air_time: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_air_time = 0.0
	var kb: Vector3 = msg.get("knockback", Vector3.ZERO)
	var launch_force: float = float(msg.get("launch", 6.5))
	character.velocity = Vector3(kb.x, launch_force, kb.z)
	character.set_knockdown_pose(false)
	character.play_anim(&"launched")
	character.trigger_hit_flash()


func physics_update(delta: float) -> void:
	_air_time += delta
	character.apply_gravity(delta, gravity_multiplier)
	character.apply_ground_friction(air_drag, delta)
	character.move_and_slide()

	if _air_time >= min_air_time and character.is_on_floor() and character.velocity.y <= 0.0:
		if not state_machine.transition_to(landing_state):
			state_machine.transition_to(fallback_state)
