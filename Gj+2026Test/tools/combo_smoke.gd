extends Node2D
## Headless smoke test for the attack/combo system.
## Run:  godot --headless --path <project> res://tools/combo_smoke.tscn
## Spawns a Player + a training-dummy Enemy side by side, drives H/H/K
## combinations through AttackController, and prints the resolved move per
## press plus the damage the dummy took. Exits with code 0 when all checks
## pass, 1 otherwise.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemies/enemy.tscn")


func _ready() -> void:
	await _run()


func _run() -> void:
	var failures: Array[String] = []

	await _check_combo(failures, [["H", 16], ["H", 16], ["K", 20]], "HHK", &"kick_finisher", 4 + 5 + 9)
	await _check_combo(failures, [["H", 16], ["H", 16], ["H", 16], ["K", 24]], "HHHK", &"kick_finisher_big", 4 + 5 + 6 + 14)
	await _check_combo(failures, [["J", 20]], "J", &"heavy", 10)
	await _check_combo(failures, [["K", 20]], "K", &"kick", 8)
	await _check_slow_reset(failures)

	if failures.is_empty():
		print("COMBO_SMOKE: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("COMBO_SMOKE: FAIL - %s" % f)
		print("COMBO_SMOKE: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _check_combo(failures: Array[String], presses: Array, expected_buffer: String, expected_move: StringName, expected_damage: int) -> void:
	var player := PlayerScene.instantiate()
	var enemy := EnemyScene.instantiate()
	add_child(player)
	add_child(enemy)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(24, 0)
	await _frames(3)

	var hp0: int = enemy.health
	var ac: Node = player.get_node("AttackController")
	var last_move: StringName = &""
	for step in presses:
		ac._press(step[0])
		await _frames(step[1])
		last_move = ac._current.id if ac._current != null else &"<none>"

	# Let the last move's active window play out and land.
	await _frames(30)

	var damage: int = hp0 - enemy.health
	if ac._buffer != expected_buffer:
		failures.append("combo %s: expected buffer '%s', got '%s'" % [expected_buffer, expected_buffer, ac._buffer])
	if last_move != expected_move:
		failures.append("combo %s: expected move %s, got %s" % [expected_buffer, expected_move, last_move])
	if damage != expected_damage:
		failures.append("combo %s: expected damage %d, got %d" % [expected_buffer, expected_damage, damage])
	print("COMBO_SMOKE: %-4s -> move=%s buffer=%s damage=%d (expected %d)" % [expected_buffer, last_move, ac._buffer, damage, expected_damage])

	player.queue_free()
	enemy.queue_free()
	await _frames(2)


## Presses H, H (chains to "straight"), then idles until the combo window
## expires and presses H again. The buffer must be empty and the new move a
## fresh "jab" — i.e. slow presses reset the combo.
func _check_slow_reset(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate()
	var enemy := EnemyScene.instantiate()
	add_child(player)
	add_child(enemy)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(24, 0)
	await _frames(3)

	var ac: Node = player.get_node("AttackController")
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(2)
	var chained: StringName = ac._current.id if ac._current != null else &"<none>"
	# Idle well past the move end + combo_window so the buffer must clear.
	await _frames(110)
	var idle_buffer: String = ac._buffer
	ac._press("H")
	await _frames(4)
	var next_move: StringName = ac._current.id if ac._current != null else &"<none>"

	if chained != &"straight":
		failures.append("slow reset: expected 'straight' while chaining, got %s" % chained)
	if idle_buffer != "":
		failures.append("slow reset: buffer should clear while idle, got '%s'" % idle_buffer)
	if next_move != &"jab":
		failures.append("slow reset: expected fresh 'jab' after pause, got %s" % next_move)
	print("COMBO_SMOKE: slow-reset -> chained=%s idle_buffer='%s' next_move=%s" % [chained, idle_buffer, next_move])

	player.queue_free()
	enemy.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame