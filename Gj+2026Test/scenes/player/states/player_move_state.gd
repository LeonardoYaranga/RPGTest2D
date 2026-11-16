class_name PlayerMoveState
extends State
## Player 2.5D locomotion on the XZ plane (walk + sprint with stamina).


func enter(_msg: Dictionary = {}) -> void:
	_update_anim()


func exit() -> void:
	var player := character as Player3D
	if player:
		player.set_sprinting(false)
		player.update_steps_sound(Vector2.ZERO)


func physics_update(delta: float) -> void:
	var player := character as Player3D
	if player == null:
		return

	if player.control_blocked:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		state_machine.transition_to(&"Idle")
		return

	if Input.is_action_just_pressed(&"jump") and character.is_on_floor():
		state_machine.transition_to(&"Jump")
		return

	var input: Vector2 = player.get_move_input()
	if input == Vector2.ZERO:
		state_machine.transition_to(&"Idle")
		return

	if input.x != 0.0:
		player.set_facing(input.x)

	var current_speed: float = player.resolve_move_speed(delta, true)
	player.velocity.x = input.x * current_speed
	player.velocity.z = input.y * current_speed
	player.apply_gravity(delta)
	player.move_and_slide()

	player.update_steps_sound(input)
	_update_anim()


func _update_anim() -> void:
	var player := character as Player3D
	if player and player.is_sprinting:
		character.play_anim(&"run")
	else:
		character.play_anim(&"walk")
