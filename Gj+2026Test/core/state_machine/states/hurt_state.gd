class_name HurtState
extends State
## Grounded hitstun reaction shared by Player3D and EnemyBase3D.

@export var recovery_state: StringName = &"Idle"
@export var default_hitstun: float = 0.2
@export var knockback_friction: float = 10.0

var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_timer = float(msg.get("hitstun", default_hitstun))
	var kb: Vector3 = msg.get("knockback", Vector3.ZERO)
	character.velocity.x = kb.x
	character.velocity.z = kb.z
	character.play_anim(&"hurt")
	character.trigger_hit_flash()


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.apply_ground_friction(knockback_friction, delta)
	character.move_and_slide()

	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(recovery_state)
