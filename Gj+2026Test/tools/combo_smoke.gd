extends Node3D
## Headless smoke test for the 2.5D combat, combo, RCG2 reaction cycle, anim replay, and enemy AI.
## Run: flatpak run org.godotengine.Godot --headless --path <project> res://tools/combo_smoke.tscn

const PlayerScene := preload("res://scenes/player/player_3d.tscn")
const DummyScene := preload("res://scenes/enemies/training_dummy_3d.tscn")
const BrawlerScene := preload("res://scenes/enemies/melee_brawler_3d.tscn")


func _ready() -> void:
	await _run()


func _build_test_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 20)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	add_child(floor_body)
	return floor_body


func _run() -> void:
	var failures: Array[String] = []
	var floor_body := _build_test_floor()
	await _frames(2)

	# 1. Combo strings verification with updated damage balances
	await _check_combo(failures, [["H", 16], ["H", 16], ["K", 22]], "HHK", &"kick_finisher", 4 + 5 + 11)
	await _check_combo(failures, [["H", 16], ["H", 16], ["H", 16], ["K", 26]], "HHHK", &"kick_finisher_big", 4 + 5 + 7 + 15)
	await _check_combo(failures, [["J", 22]], "J", &"heavy", 10)
	await _check_combo(failures, [["K", 22]], "K", &"kick", 8)

	# 2. Reset timing & animation replay verification
	await _check_slow_reset(failures)
	await _check_animation_replay(failures)

	# 3. RCG2 reaction types: Grounded hitstun, Floor sweep knockdown, Airborne launcher
	await _check_rcg2_reaction_cycle(failures)
	await _check_air_juggle(failures)

	# 4. HUD signal verification
	await _check_hud_signals(failures)

	# 5. Enemy AI brawler chase & attack
	await _check_brawler_ai(failures)

	floor_body.queue_free()

	if failures.is_empty():
		print("COMBO_SMOKE_25D: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("COMBO_SMOKE_25D: FAIL - %s" % f)
		print("COMBO_SMOKE_25D: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _check_combo(failures: Array[String], presses: Array, expected_buffer: String, expected_move: StringName, expected_damage: int) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var dummy := DummyScene.instantiate() as EnemyBase3D
	add_child(player)
	add_child(dummy)
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(1.0, 0.0, 0.0)
	await _frames(4)

	var hp0: int = dummy.health
	var ac: AttackController3D = player.attack_controller
	var last_move: StringName = &""
	for step in presses:
		ac._press(step[0])
		await _frames(step[1])
		last_move = ac._current.id if ac._current != null else &"<none>"

	await _frames(35)

	var damage: int = hp0 - dummy.health
	if ac._buffer != expected_buffer:
		failures.append("combo %s: expected buffer '%s', got '%s'" % [expected_buffer, expected_buffer, ac._buffer])
	if last_move != expected_move:
		failures.append("combo %s: expected move %s, got %s" % [expected_buffer, expected_move, last_move])
	if damage != expected_damage:
		failures.append("combo %s: expected damage %d, got %d" % [expected_buffer, expected_damage, damage])
	print("COMBO_SMOKE_25D: %-4s -> move=%s buffer=%s damage=%d (expected %d)" % [expected_buffer, last_move, ac._buffer, damage, expected_damage])

	player.queue_free()
	dummy.queue_free()
	await _frames(3)


func _check_slow_reset(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var dummy := DummyScene.instantiate() as EnemyBase3D
	add_child(player)
	add_child(dummy)
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(1.0, 0.0, 0.0)
	await _frames(4)

	var ac: AttackController3D = player.attack_controller
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(2)
	var chained: StringName = ac._current.id if ac._current != null else &"<none>"
	await _frames(115)
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
	print("COMBO_SMOKE_25D: slow-reset -> chained=%s idle_buffer='%s' next_move=%s" % [chained, idle_buffer, next_move])

	player.queue_free()
	dummy.queue_free()
	await _frames(3)


func _check_animation_replay(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	add_child(player)
	player.global_position = Vector3.ZERO
	await _frames(4)

	var ac: AttackController3D = player.attack_controller
	ac._press("H")
	# Wait until jab animation advances past frame 0
	await _frames(6)
	var frame_during_jab: int = player.sprite.frame
	# Press H to buffer continuation into straight
	ac._press("H")
	# Wait for cancel_time (0.12s ~ 7 frames) to execute _advance into straight
	await _frames(3)
	var chained_move: StringName = ac._current.id if ac._current != null else &""
	var frame_on_chained_start: int = player.sprite.frame
	var is_playing: bool = player.sprite.is_playing()

	if chained_move != &"straight":
		failures.append("anim replay: did not chain to straight (current=%s)" % chained_move)
	if frame_on_chained_start > 1:
		failures.append("anim replay: chained hit did not reset frame to start (frame=%d)" % frame_on_chained_start)
	if not is_playing:
		failures.append("anim replay: sprite was not playing after chained hit")
	print("COMBO_SMOKE_25D: anim replay -> jab_frame=%d chained=%s start_frame=%d playing=%s" % [
		frame_during_jab, chained_move, frame_on_chained_start, is_playing
	])

	player.queue_free()
	await _frames(3)


func _check_rcg2_reaction_cycle(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var dummy := DummyScene.instantiate() as EnemyBase3D
	dummy.max_health = 100
	add_child(player)
	add_child(dummy)
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0.9, 0.0, 0.0)
	await _frames(4)

	var ac: AttackController3D = player.attack_controller
	# 1) Grounded hit -> Hurt -> Idle
	ac._press("H")
	await _frames(12)
	var saw_hurt := dummy.state_machine.is_in_state(&"Hurt")
	await _frames(25)
	var recovered_idle := dummy.state_machine.is_in_state(&"Idle")

	# 2) Sweep Kick (K): Grounded Knockdown (low height, slides onto floor) -> GetUp -> Idle
	dummy.global_position = Vector3(player.global_position.x + 0.9, 0.0, 0.0)
	await _frames(2)
	ac._press("K")
	var saw_sweep_knockdown := false
	var sweep_max_y := 0.0
	var saw_sweep_getup := false
	for i in 120:
		await _frames(1)
		sweep_max_y = maxf(sweep_max_y, dummy.global_position.y)
		if dummy.state_machine.is_in_state(&"Knockdown"):
			saw_sweep_knockdown = true
		elif dummy.state_machine.is_in_state(&"GetUp"):
			saw_sweep_getup = true
			break

	# 3) Mega Launcher (HHHK): Airborne Launched -> Knockdown -> GetUp -> Idle
	await _frames(40)
	dummy.global_position = Vector3(player.global_position.x + 0.9, 0.0, 0.0)
	await _frames(2)
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("K")

	var saw_launched := false
	var launch_max_y := 0.0
	var saw_launch_knockdown := false
	var saw_launch_getup := false
	for i in 180:
		await _frames(1)
		launch_max_y = maxf(launch_max_y, dummy.global_position.y)
		if dummy.state_machine.is_in_state(&"Launched"):
			saw_launched = true
		elif dummy.state_machine.is_in_state(&"Knockdown"):
			saw_launch_knockdown = true
		elif dummy.state_machine.is_in_state(&"GetUp"):
			saw_launch_getup = true
			break

	if not saw_hurt:
		failures.append("rcg2 cycle: jab did not trigger Hurt state")
	if not recovered_idle:
		failures.append("rcg2 cycle: dummy did not recover from Hurt to Idle")
	if not saw_sweep_knockdown:
		failures.append("rcg2 cycle: K sweep did not trigger Knockdown state")
	if sweep_max_y > 0.4:
		failures.append("rcg2 cycle: K sweep launched dummy too high (max_y=%.2f, should stay grounded)" % sweep_max_y)
	if not saw_launched or launch_max_y < 0.6:
		failures.append("rcg2 cycle: HHHK did not launch dummy airborne (saw=%s max_y=%.2f)" % [saw_launched, launch_max_y])
	if not saw_launch_knockdown:
		failures.append("rcg2 cycle: dummy did not enter Knockdown after HHHK launch")

	print("COMBO_SMOKE_25D: RCG2 cycle -> hurt=%s sweep_kd=%s(max_y=%.2f) launch=%s(max_y=%.2f)" % [
		saw_hurt, saw_sweep_knockdown, sweep_max_y, saw_launched, launch_max_y
	])

	player.queue_free()
	dummy.queue_free()
	await _frames(3)


func _check_air_juggle(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var dummy := DummyScene.instantiate() as EnemyBase3D
	dummy.max_health = 100
	add_child(player)
	add_child(dummy)
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0.95, 0.0, 0.0)
	await _frames(4)

	var ac: AttackController3D = player.attack_controller
	var hp0: int = dummy.health

	# Trigger launcher via full string
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(16)
	ac._press("K")
	await _frames(24)

	var in_air_before_juggle := dummy.state_machine.is_in_state(&"Launched") and dummy.global_position.y > 0.3
	# Re-position horizontally to ensure follow-up hit connects mid-air
	dummy.global_position.x = player.global_position.x + 0.85
	ac._press("H")
	await _frames(15)
	var damage: int = hp0 - dummy.health
	var still_airborne := dummy.state_machine.is_in_state(&"Launched")

	if not in_air_before_juggle:
		failures.append("air juggle: enemy was not airborne after launcher (state=%s y=%.2f)" % [
			dummy.state_machine.get_current_state_name(), dummy.global_position.y])
	if damage < 31:
		failures.append("air juggle: expected full string (31) + follow-up, got %d" % damage)
	if not still_airborne:
		failures.append("air juggle: enemy did not remain Launched after mid-air jab (state=%s)" % dummy.state_machine.get_current_state_name())
	print("COMBO_SMOKE_25D: juggle -> airborne=%s still_air=%s dmg=%d" % [in_air_before_juggle, still_airborne, damage])

	player.queue_free()
	dummy.queue_free()
	await _frames(3)


func _check_hud_signals(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var dummy := DummyScene.instantiate() as EnemyBase3D
	add_child(player)
	add_child(dummy)
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0.9, 0.0, 0.0)
	await _frames(4)

	var inputs_logged: Array[Dictionary] = []
	var buffer_updates: Array[String] = []
	var hits_scored: Array[int] = []

	var c_input = func(token: String, action: String, status: String):
		inputs_logged.append({"token": token, "action": action, "status": status})
	var c_buf = func(buffer: String, _att: StringName):
		buffer_updates.append(buffer)
	var c_hit = func(combo_hits: int, _dmg: int, _att: StringName):
		hits_scored.append(combo_hits)

	SignalHub.combo_input_logged.connect(c_input)
	SignalHub.combo_buffer_changed.connect(c_buf)
	SignalHub.combo_hit_scored.connect(c_hit)

	var ac: AttackController3D = player.attack_controller
	ac._press("H")
	await _frames(16)
	ac._press("H")
	await _frames(25)

	SignalHub.combo_input_logged.disconnect(c_input)
	SignalHub.combo_buffer_changed.disconnect(c_buf)
	SignalHub.combo_hit_scored.disconnect(c_hit)

	if inputs_logged.size() < 2:
		failures.append("hud signals: expected at least 2 input log events, got %d" % inputs_logged.size())
	if buffer_updates.is_empty():
		failures.append("hud signals: no buffer updates recorded")
	if hits_scored.is_empty():
		failures.append("hud signals: no hits scored recorded")

	print("COMBO_SMOKE_25D: hud signals -> inputs=%d buffers=%d hits=%d" % [
		inputs_logged.size(), buffer_updates.size(), hits_scored.size()
	])

	player.queue_free()
	dummy.queue_free()
	await _frames(3)


func _check_brawler_ai(failures: Array[String]) -> void:
	var player := PlayerScene.instantiate() as Player3D
	var brawler := BrawlerScene.instantiate() as EnemyBase3D
	player.pause_tree_on_death = false
	add_child(player)
	add_child(brawler)
	player.global_position = Vector3.ZERO
	brawler.global_position = Vector3(4.0, 0.0, 0.4)
	await _frames(4)

	var hp0: int = player.health
	var saw_chase := false
	var saw_attack := false
	var saw_player_hurt := false

	for i in 180:
		await _frames(1)
		if brawler.state_machine.is_in_state(&"Chase"):
			saw_chase = true
		if brawler.state_machine.is_in_state(&"Attack"):
			saw_attack = true
		if player.state_machine.is_in_state(&"Hurt"):
			saw_player_hurt = true
		if player.health < hp0 and saw_player_hurt:
			break

	if not saw_chase:
		failures.append("brawler AI: did not enter Chase state")
	if not saw_attack:
		failures.append("brawler AI: did not enter Attack state")
	if player.health >= hp0:
		failures.append("brawler AI: did not damage player (hp=%d/%d)" % [player.health, hp0])
	print("COMBO_SMOKE_25D: brawler AI -> chase=%s attack=%s player_hurt=%s player_hp=%d/%d" % [
		saw_chase, saw_attack, saw_player_hurt, player.health, hp0
	])

	player.queue_free()
	brawler.queue_free()
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
