class_name AttackController3D
extends Node
## Turns H / J / K presses into 3D/2.5D melee combos using AttackDefinition resources.
## Integrates with Player3D's StateMachine (Attack state) and applies hitstop on impact.

signal combo_changed(count: int)

@export var debug_log: bool = true

const JAB: AttackDefinition = preload("res://resources/attacks/jab.tres")
const STRAIGHT: AttackDefinition = preload("res://resources/attacks/straight.tres")
const HOOK: AttackDefinition = preload("res://resources/attacks/hook.tres")
const KICK_FINISHER: AttackDefinition = preload("res://resources/attacks/kick_finisher.tres")
const KICK_FINISHER_BIG: AttackDefinition = preload("res://resources/attacks/kick_finisher_big.tres")
const HEAVY: AttackDefinition = preload("res://resources/attacks/heavy.tres")
const KICK: AttackDefinition = preload("res://resources/attacks/kick.tres")

const COMBO_TABLE := {
	"H": JAB,
	"HH": STRAIGHT,
	"HHK": KICK_FINISHER,
	"HHH": HOOK,
	"HHHK": KICK_FINISHER_BIG,
	"J": HEAVY,
	"K": KICK,
}

const TOKEN := {
	"attack_light": "H",
	"attack_medium": "J",
	"attack_heavy": "K",
}

const ACTION_NAMES := {
	"H": "Light",
	"J": "Heavy",
	"K": "Kick",
	"SPACE": "Jump",
}

@onready var player: Player3D = get_parent() as Player3D

var _buffer: String = ""
var _pending: String = ""
var _current: AttackDefinition = null
var _is_attacking: bool = false
var _elapsed: float = 0.0
var _end_time: float = 0.0
var _hit_targets: Array[Node] = []
var _hitbox: Area3D = null
var _hitbox_shape: CollisionShape3D = null
var _window_timer: Timer = null
var _combo_hits: int = 0
var _combo_damage: int = 0


func _ready() -> void:
	_create_hitbox()
	_window_timer = Timer.new()
	_window_timer.one_shot = true
	_window_timer.timeout.connect(_on_combo_window_timeout)
	add_child(_window_timer)


func is_attacking() -> bool:
	return _is_attacking


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.is_dead() or player.control_blocked:
		return
	if player.state_machine and player.state_machine.is_in_state(&"Hurt"):
		for action in TOKEN:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				var tok: String = TOKEN[action]
				SignalHub.emit_on_combo_input_logged(tok, ACTION_NAMES.get(tok, "Attack"), "DROPPED")
				return
		return
	if event.is_action_pressed(&"jump"):
		SignalHub.emit_on_combo_input_logged("SPACE", "Jump", "NEUTRAL")
		return
	for action in TOKEN:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_press(TOKEN[action])
			return


func _physics_process(delta: float) -> void:
	if not _is_attacking or player == null:
		return
	if player.is_hitstop_active():
		return
	if player.is_dead() or (player.state_machine and player.state_machine.is_in_state(&"Hurt")):
		cancel_attack()
		return

	_elapsed += delta

	var active_start: float = _current.hit_delay
	var active_end: float = _current.hit_delay + _current.hit_window
	if _elapsed >= active_start and _elapsed <= active_end:
		_check_hits()

	if _pending != "" and _elapsed >= _current.cancel_time:
		var next_token: String = _pending
		_pending = ""
		_advance(next_token)
		return

	if _elapsed >= _end_time:
		_finish()


func _press(token: String) -> void:
	_log("IN  press '%s'   buffer='%s'   attacking=%s" % [token, _buffer, _is_attacking])
	var action_name: String = ACTION_NAMES.get(token, "Attack")
	if _is_attacking:
		var candidate: String = _buffer + token
		var is_valid_chain: bool = COMBO_TABLE.has(candidate)
		var status: String = "CHAINED" if is_valid_chain else "DROPPED"
		SignalHub.emit_on_combo_input_logged(token, action_name, status)
		_pending = token
		var ct: float = _current.cancel_time if _current != null else 0.0
		_log("    buffered as _pending='%s' (will chain at cancel_time %.2fs)" % [token, ct])
	else:
		SignalHub.emit_on_combo_input_logged(token, action_name, "NEUTRAL")
		_advance(token)


func _advance(token: String) -> void:
	var candidate: String = _buffer + token
	if COMBO_TABLE.has(candidate):
		var next_attack: AttackDefinition = COMBO_TABLE[candidate]
		if not _can_afford_attack(next_attack):
			return
		_buffer = candidate
		SignalHub.emit_on_combo_buffer_changed(_buffer, next_attack.id)
		if _is_finisher(candidate):
			_log("MATCH '%s' -> %s   *** COMBO! ***" % [candidate, next_attack.id])
			SignalHub.emit_on_combo_completed(candidate, next_attack.id)
		else:
			_log("MATCH '%s' -> %s" % [candidate, next_attack.id])
		_play(next_attack)
		return

	_log("NO continuation for '%s'  -> chain reset" % candidate)
	SignalHub.emit_on_combo_dropped("INVALID")
	_combo_hits = 0
	_combo_damage = 0
	var fresh_token: String = token if COMBO_TABLE.has(token) else ""
	if fresh_token != "":
		var fresh_attack: AttackDefinition = COMBO_TABLE[fresh_token]
		if not _can_afford_attack(fresh_attack):
			_buffer = ""
			_set_combo(0)
			SignalHub.emit_on_combo_buffer_changed("", &"")
			return
		_buffer = fresh_token
		SignalHub.emit_on_combo_buffer_changed(_buffer, fresh_attack.id)
		_log("    restarted as '%s' -> %s (fresh)" % [_buffer, fresh_attack.id])
		_play(fresh_attack)
	else:
		_buffer = ""
		_set_combo(0)
		SignalHub.emit_on_combo_buffer_changed("", &"")


func _can_afford_attack(attack: AttackDefinition) -> bool:
	if attack.stamina_cost <= 0.0 or player == null:
		return true
	if player.stamina < attack.stamina_cost:
		return false
	player.consume_stamina(attack.stamina_cost)
	return true


func _is_finisher(seq: String) -> bool:
	for key in COMBO_TABLE:
		if key.length() > seq.length() and key.begins_with(seq):
			return false
	return true


func _play(attack: AttackDefinition) -> void:
	_current = attack
	_is_attacking = true
	_elapsed = 0.0
	_end_time = _attack_duration(attack)
	_hit_targets.clear()
	_window_timer.stop()
	_set_combo(_buffer.length())

	_log("    PLAY %s   (chain '%s', window %.2fs, cancel %.2fs)" % [
		attack.id, _buffer, attack.combo_window, attack.cancel_time
	])

	if player.state_machine and not player.state_machine.is_in_state(&"Attack"):
		player.state_machine.transition_to(&"Attack")

	var input_dir: Vector2 = player.get_move_input()
	if input_dir.x != 0.0:
		player.set_facing(input_dir.x)

	if attack.lunge != 0.0:
		player.velocity.x = player.facing * attack.lunge
		player.velocity.z = 0.0
	else:
		player.velocity.x = 0.0
		player.velocity.z = 0.0

	_place_hitbox(attack, player.facing)
	player.play_anim(attack.animation, attack.speed_scale, true)


func _finish() -> void:
	var combo_window: float = _current.combo_window
	_log("    END %s (buffer='%s', pending='%s')" % [_current.id, _buffer, _pending])
	_is_attacking = false
	_current = null
	if player.sprite:
		player.sprite.speed_scale = 1.0

	if _pending != "":
		var next_token: String = _pending
		_pending = ""
		_advance(next_token)
		return

	if combo_window > 0.0:
		_window_timer.start(combo_window)
	else:
		_buffer = ""
		_set_combo(0)

	if player.state_machine and player.state_machine.is_in_state(&"Attack"):
		if not player.is_on_floor():
			player.state_machine.transition_to(&"Jump")
		elif player.get_move_input() != Vector2.ZERO and not player.control_blocked:
			player.state_machine.transition_to(&"Move")
		else:
			player.state_machine.transition_to(&"Idle")


func cancel_attack() -> void:
	if not _is_attacking and _buffer == "" and _pending == "":
		return
	_is_attacking = false
	_current = null
	_pending = ""
	_buffer = ""
	_combo_hits = 0
	_combo_damage = 0
	if _window_timer:
		_window_timer.stop()
	if player and player.sprite:
		player.sprite.speed_scale = 1.0
	_set_combo(0)
	SignalHub.emit_on_combo_buffer_changed("", &"")


func _attack_duration(attack: AttackDefinition) -> float:
	if attack.duration > 0.0:
		return attack.duration / maxf(0.05, attack.speed_scale)
	if player:
		return player.get_anim_duration(attack.animation, attack.speed_scale)
	return 0.7 / maxf(0.05, attack.speed_scale)


func _create_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.name = "AttackHitbox"
	_hitbox.collision_layer = 1 << 6   # layer 7: player_attack
	_hitbox.collision_mask = 1 << 4    # layer 5: enemy_hitbox
	_hitbox.monitoring = true
	_hitbox.monitorable = false

	_hitbox_shape = CollisionShape3D.new()
	_hitbox_shape.name = "CollisionShape3D"
	_hitbox_shape.shape = BoxShape3D.new()
	_hitbox.add_child(_hitbox_shape)

	player.add_child.call_deferred(_hitbox)


func _place_hitbox(attack: AttackDefinition, direction: float) -> void:
	if _hitbox == null or _hitbox_shape == null:
		return
	_hitbox.position = Vector3(
		direction * absf(attack.hitbox_offset.x),
		attack.hitbox_offset.y,
		attack.hitbox_offset.z
	)
	var box := _hitbox_shape.shape as BoxShape3D
	if box:
		box.size = attack.hitbox_size
	_hitbox.force_update_transform()


func _check_hits() -> void:
	if _hitbox == null:
		return
	for area in _hitbox.get_overlapping_areas():
		var target: Node = area.get_parent()
		if target == null or target == player or _hit_targets.has(target):
			continue
		if target.has_method(&"take_hit"):
			_hit_targets.append(target)
			var bonus_dmg: int = 0
			if is_instance_valid(GameState) and GameState.is_flag(&"social_power_unlocked"):
				bonus_dmg = GameState.get_bond(&"amigo") + GameState.get_bond(&"chica") + GameState.get_bond(&"ser_misterioso")

			var applied_damage: int = _current.damage + bonus_dmg
			_combo_hits += 1
			_combo_damage += applied_damage
			SignalHub.emit_on_combo_hit_scored(_combo_hits, _combo_damage, _current.id)
			_log("    HIT %s with %s (dmg %d + bonus %d = %d) [%d hits, %d total dmg]" % [
				target.name, _current.id, _current.damage, bonus_dmg, applied_damage, _combo_hits, _combo_damage
			])

			var attack_data: AttackDefinition = _current
			if bonus_dmg > 0:
				attack_data = _current.duplicate() as AttackDefinition
				attack_data.damage = applied_damage

			target.take_hit(attack_data, player.global_position)
			if _current.hitstop > 0.0:
				player.apply_hitstop(_current.hitstop)
				if target.has_method(&"apply_hitstop"):
					target.apply_hitstop(_current.hitstop)


func _on_combo_window_timeout() -> void:
	if _buffer != "":
		_log("combo window EXPIRED -> buffer '%s' cleared (next press = fresh basic)" % _buffer)
		SignalHub.emit_on_combo_dropped("TIMEOUT")
	_buffer = ""
	_set_combo(0)
	SignalHub.emit_on_combo_buffer_changed("", &"")


func _set_combo(count: int) -> void:
	combo_changed.emit(count)


func _log(msg: String) -> void:
	if debug_log:
		print("[COMBO] " + msg)
