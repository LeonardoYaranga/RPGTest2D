class_name PlayerAttackState
extends State
## Player combo attack state. Movement/lunge and cancel timing are coordinated
## with AttackController3D.

@export var lunge_friction: float = 9.5


func enter(_msg: Dictionary = {}) -> void:
	var player := character as Player3D
	if player:
		player.set_sprinting(false)
		player.update_steps_sound(Vector2.ZERO)


func exit() -> void:
	if character and character.sprite:
		character.sprite.speed_scale = 1.0
	var player := character as Player3D
	if player and player.attack_controller and player.attack_controller.is_attacking():
		player.attack_controller.cancel_attack()


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.apply_ground_friction(lunge_friction, delta)
	character.move_and_slide()
