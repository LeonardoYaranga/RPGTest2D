class_name EnemyChaseState
extends State
## Pursues the player to a side-flank position on the same Z lane (RCG2 style)
## and transitions to Attack once inside attack_range_x / attack_range_z.

@export var disengage_multiplier: float = 1.5


func enter(_msg: Dictionary = {}) -> void:
	character.play_anim(&"walk")


func physics_update(delta: float) -> void:
	var enemy := character as EnemyBase3D
	if enemy == null:
		return

	var player: Node3D = enemy.acquire_player()
	if player == null:
		state_machine.transition_to(&"Idle")
		return

	var dist: float = enemy.global_position.distance_to(player.global_position)
	if dist > enemy.aggro_radius * disengage_multiplier:
		state_machine.transition_to(&"Idle")
		return

	var dx_to_player: float = player.global_position.x - enemy.global_position.x
	if absf(dx_to_player) > 0.05:
		enemy.set_facing(dx_to_player)

	if enemy.is_in_attack_band(player) and enemy.can_attack() and state_machine.has_state(&"Attack"):
		state_machine.transition_to(&"Attack")
		return

	var side: float = -1.0 if enemy.global_position.x < player.global_position.x else 1.0
	var flank_pos := Vector3(
		player.global_position.x + side * (enemy.attack_range_x * 0.72),
		player.global_position.y,
		player.global_position.z
	)

	var next_point: Vector3 = flank_pos
	if enemy.nav_agent:
		var nav_map: RID = enemy.nav_agent.get_navigation_map()
		if not NavigationServer3D.map_get_regions(nav_map).is_empty():
			enemy.nav_agent.target_position = flank_pos
			if not enemy.nav_agent.is_navigation_finished():
				next_point = enemy.nav_agent.get_next_path_position()

	var to_next := Vector3(next_point.x - enemy.global_position.x, 0.0, next_point.z - enemy.global_position.z)
	if to_next.length_squared() > 0.02:
		var dir: Vector3 = to_next.normalized()
		enemy.velocity.x = dir.x * enemy.move_speed
		enemy.velocity.z = dir.z * enemy.move_speed
		enemy.play_anim(&"walk")
	else:
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		enemy.play_anim(&"idle")

	enemy.apply_gravity(delta)
	enemy.move_and_slide()
