class_name EnemyIdleState
extends State
## Enemy idle state. Automatically transitions to Chase if the enemy has a Chase
## state and a player enters aggro_radius; stays idle on TrainingDummy3D.


func enter(_msg: Dictionary = {}) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	character.play_anim(&"idle")


func physics_update(delta: float) -> void:
	character.apply_gravity(delta)
	character.move_and_slide()

	var enemy := character as EnemyBase3D
	if enemy == null or not state_machine.has_state(&"Chase"):
		return

	var player: Node3D = enemy.acquire_player()
	if player == null:
		return

	var dist: float = enemy.global_position.distance_to(player.global_position)
	if dist <= enemy.aggro_radius:
		state_machine.transition_to(&"Chase")
