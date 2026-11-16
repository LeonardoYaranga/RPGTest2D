class_name PlayerIdleState
extends State
## Player idle state on ground. Listens for movement or jump transitions.


func enter(_msg: Dictionary = {}) -> void:
	var player := character as Player3D
	if player:
		player.set_sprinting(false)
		player.update_steps_sound(Vector2.ZERO)
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	character.play_anim(&"idle")


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.move_and_slide()

	var player := character as Player3D
	if player == null or player.control_blocked:
		return

	if Input.is_action_just_pressed(&"jump") and character.is_on_floor():
		state_machine.transition_to(&"Jump")
		return

	if player.get_move_input() != Vector2.ZERO:
		state_machine.transition_to(&"Move")
