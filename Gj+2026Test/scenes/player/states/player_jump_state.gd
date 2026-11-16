class_name PlayerJumpState
extends State
## Player 3D jump/airborne state with air steering.

var _left_ground: bool = false


func enter(msg: Dictionary = {}) -> void:
	_left_ground = false
	var player := character as Player3D
	var apply_jump: bool = bool(msg.get("apply_jump", true))
	if apply_jump and player and character.is_on_floor():
		character.velocity.y = player.jump_force
	character.play_anim(&"jump")


func physics_update(delta: float) -> void:
	var player := character as Player3D
	if player:
		var input: Vector2 = Vector2.ZERO if player.control_blocked else player.get_move_input()
		if input.x != 0.0:
			player.set_facing(input.x)
		var speed_now: float = player.resolve_move_speed(delta, false)
		character.velocity.x = input.x * speed_now
		character.velocity.z = input.y * speed_now

	character.apply_gravity(delta)
	character.move_and_slide()

	if not character.is_on_floor():
		_left_ground = true
	elif _left_ground or character.velocity.y <= 0.0:
		if player and player.get_move_input() != Vector2.ZERO and not player.control_blocked:
			state_machine.transition_to(&"Move")
		else:
			state_machine.transition_to(&"Idle")
