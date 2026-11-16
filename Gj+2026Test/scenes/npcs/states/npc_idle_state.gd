class_name NpcIdleState
extends State
## Idle state for NPC3D characters.


func enter(_msg: Dictionary = {}) -> void:
	if character and character.sprite:
		character.sprite.play(&"idle")
	if character:
		character.velocity.x = 0.0
		character.velocity.z = 0.0


func physics_update(delta: float) -> void:
	if character == null:
		return
	if not character.is_on_floor():
		character.velocity.y -= character.gravity * delta
	character.move_and_slide()
