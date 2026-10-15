extends Node2D
## Headless end-to-end test on the real test level: walks the player from its
## spawn down to the nearest dummy, drives H,H,K through the AttackController,
## and checks the dummy actually took damage.
## Run: godot --headless --path <project> res://tools/level_walk.tscn

const LevelScene := preload("res://scenes/level/test/test_level.tscn")


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array[String] = []

	var level := LevelScene.instantiate()
	add_child(level)
	await _frames(5)

	var player: CharacterBody2D = level.get_node("Player")
	var enemy: Node = level.get_node("Enemy3")  # directly below spawn (240,176)
	var ac: Node = player.get_node("AttackController")

	var spawn: Vector2 = player.global_position
	print("LEVEL_E2E: spawn=%s enemy3=%s face_right=%s" % [
		spawn, enemy.global_position, not player.sprite_2d.flip_h])

	# Walk straight down toward the dummy.
	Input.action_press("ui_down")
	var walked := 0
	while player.global_position.y < enemy.global_position.y - 8.0 and walked < 90:
		await get_tree().physics_frame
		walked += 1
		if walked % 10 == 0:
			print("LEVEL_E2E:   walk f%02d player=%s enemy=%s" % [walked, player.global_position, enemy.global_position])
	Input.action_release("ui_down")
	await _frames(2)

	var gap: float = player.global_position.distance_to(enemy.global_position)
	print("LEVEL_E2E: walked %d frames -> player=%s gap=%.1f" % [walked, player.global_position, gap])
	if gap > 40.0:
		failures.append("player could not get near the dummy (gap=%.1f)" % gap)

	var hp0: int = enemy.health

	# H, H, K fast enough to chain into kick_finisher (4 + 5 + 9 = 18).
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("K")
	await _frames(30)

	var damage: int = hp0 - enemy.health
	print("LEVEL_E2E: HHK -> damage=%d (expected 18) enemy_hp=%d/%d" % [damage, enemy.health, enemy.max_health])
	if damage != 18:
		failures.append("HHK expected 18 damage, got %d" % damage)

	if failures.is_empty():
		print("LEVEL_E2E: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("LEVEL_E2E: FAIL - %s" % f)
		print("LEVEL_E2E: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
