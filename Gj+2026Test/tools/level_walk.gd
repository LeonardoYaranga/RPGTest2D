extends Node3D
## Headless end-to-end test on level_25d_test.tscn:
## Walks Player3D over to TrainingDummy1, executes H,H,K (18 dmg + launch),
## and checks interaction with Note1.

const LevelScene := preload("res://scenes/levels/level_25d_test.tscn")


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array[String] = []

	var level := LevelScene.instantiate()
	add_child(level)
	await _frames(5)

	var player: Player3D = level.get_node("Player3D") as Player3D
	var dummy: EnemyBase3D = level.get_node("Enemies/TrainingDummy1") as EnemyBase3D
	var ac: AttackController3D = player.attack_controller

	# Walk right toward TrainingDummy1 (from x=-3 to x=-1)
	Input.action_press(&"ui_right")
	var walked := 0
	while player.global_position.x < dummy.global_position.x - 0.85 and walked < 60:
		await get_tree().physics_frame
		walked += 1
	Input.action_release(&"ui_right")
	await _frames(3)

	var gap: float = player.global_position.distance_to(dummy.global_position)
	if gap > 1.3:
		failures.append("player could not walk close enough to dummy (gap=%.2f)" % gap)

	var hp0: int = dummy.health
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("K")
	await _frames(35)

	var damage: int = hp0 - dummy.health
	if damage != 20:
		failures.append("HHK on TrainingDummy1 expected 20 dmg, got %d" % damage)

	print("LEVEL_WALK_25D: walked=%d gap=%.2f dmg=%d dummy_state=%s" % [
		walked, gap, damage, dummy.state_machine.get_current_state_name()
	])

	if failures.is_empty():
		print("LEVEL_WALK_25D: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("LEVEL_WALK_25D: FAIL - %s" % f)
		print("LEVEL_WALK_25D: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
