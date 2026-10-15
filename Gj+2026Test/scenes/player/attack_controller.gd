class_name AttackController
extends Node
## Turns H / J / K presses into combo moves.
##
## Presses build up a string buffer that is matched against COMBO_TABLE.
## Pressing fast chains the combo; waiting longer than the current move's
## combo_window clears the buffer, so the next press is a fresh basic attack.

signal combo_changed(count: int)

const JAB: AttackDefinition = preload("res://resources/attacks/jab.tres")
const STRAIGHT: AttackDefinition = preload("res://resources/attacks/straight.tres")
const HOOK: AttackDefinition = preload("res://resources/attacks/hook.tres")
const KICK_FINISHER: AttackDefinition = preload("res://resources/attacks/kick_finisher.tres")
const KICK_FINISHER_BIG: AttackDefinition = preload("res://resources/attacks/kick_finisher_big.tres")
const HEAVY: AttackDefinition = preload("res://resources/attacks/heavy.tres")
const KICK: AttackDefinition = preload("res://resources/attacks/kick.tres")

## Input sequence (as a string) -> AttackDefinition. Every prefix that the
## player can stand on must be present (H, HH, HHH ...).
const COMBO_TABLE := {
	"H": JAB,
	"HH": STRAIGHT,
	"HHK": KICK_FINISHER,
	"HHH": HOOK,
	"HHHK": KICK_FINISHER_BIG,
	"J": HEAVY,
	"K": KICK,
}

## Input action -> the token appended to the buffer.
const TOKEN := {
	"attack_light": "H",
	"attack_medium": "J",
	"attack_heavy": "K",
}

@onready var player: Player = get_parent() as Player

var _buffer: String = ""
var _pending: String = ""
var _current: AttackDefinition = null
var _is_attacking: bool = false
var _elapsed: float = 0.0
var _end_time: float = 0.0
var _hit_targets: Array[Node] = []
var _hitbox: Area2D
var _hitbox_shape: CollisionShape2D
var _window_timer: Timer


func _ready() -> void:
	_create_hitbox()
	_window_timer = Timer.new()
	_window_timer.one_shot = true
	_window_timer.timeout.connect(_on_combo_window_timeout)
	add_child(_window_timer)


func is_attacking() -> bool:
	return _is_attacking


#region Input
func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.is_hurt or player.control_blocked:
		return
	for action in TOKEN:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_press(TOKEN[action])
			return
#endregion


func _physics_process(delta: float) -> void:
	if not _is_attacking:
		return

	# Getting hit cancels the combo.
	if player.is_hurt:
		cancel_attack()
		return

	_elapsed += delta

	var active_start: float = _current.hit_delay
	var active_end: float = _current.hit_delay + _current.hit_window
	if _elapsed >= active_start and _elapsed <= active_end:
		_check_hits()

	# Buffered input can cancel the recovery once cancel_time is reached.
	if _pending != "" and _elapsed >= _current.cancel_time:
		var next_token: String = _pending
		_pending = ""
		_advance(next_token)
		return

	if _elapsed >= _end_time:
		_finish()


#region Combo resolution
func _press(token: String) -> void:
	if _is_attacking:
		_pending = token
	else:
		_advance(token)


func _advance(token: String) -> void:
	var candidate: String = _buffer + token
	if COMBO_TABLE.has(candidate):
		_buffer = candidate
		_play(COMBO_TABLE[candidate])
		return

	# Not a valid continuation: restart the chain from this token.
	_buffer = token if COMBO_TABLE.has(token) else ""
	if _buffer != "":
		_play(COMBO_TABLE[_buffer])
	else:
		_set_combo(0)
#endregion


#region Attack lifecycle
func _play(attack: AttackDefinition) -> void:
	_current = attack
	_is_attacking = true
	_elapsed = 0.0
	_end_time = _attack_duration(attack)
	_hit_targets.clear()
	_window_timer.stop()
	_set_combo(_buffer.length())

	var direction: float = -1.0 if player.sprite_2d.flip_h else 1.0
	if attack.lunge != 0.0:
		player.apply_attack_lunge(direction, attack.lunge)
	_place_hitbox(attack, direction)
	player.begin_attack(attack.animation, attack.speed_scale)


func _finish() -> void:
	var combo_window: float = _current.combo_window
	_is_attacking = false
	_current = null
	player.end_attack()

	if _pending != "":
		var next_token: String = _pending
		_pending = ""
		_advance(next_token)
		return

	# Keep the buffer alive briefly so a slightly late press still chains.
	if combo_window > 0.0:
		_window_timer.start(combo_window)
	else:
		_buffer = ""
		_set_combo(0)


func cancel_attack() -> void:
	if not _is_attacking:
		return
	_is_attacking = false
	_current = null
	_pending = ""
	_buffer = ""
	_window_timer.stop()
	player.end_attack()
	_set_combo(0)


func _attack_duration(attack: AttackDefinition) -> float:
	var length: float = 0.9
	if player.animation_player and player.animation_player.has_animation(attack.animation):
		length = player.animation_player.get_animation(attack.animation).length
	return length / maxf(0.05, attack.speed_scale)
#endregion


#region Hitbox
## The hitbox is created in code so the player scene stays untouched.
func _create_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.name = "AttackHitbox"
	_hitbox.collision_layer = 1 << 6   # player_attack
	_hitbox.collision_mask = 1 << 4    # enemy_hitbox
	_hitbox.monitoring = true
	_hitbox.monitorable = true

	_hitbox_shape = CollisionShape2D.new()
	_hitbox_shape.name = "CollisionShape2D"
	_hitbox_shape.shape = RectangleShape2D.new()
	_hitbox.add_child(_hitbox_shape)

	# Deferred: AttackController._ready() runs while Player is still setting up
	# its children, so a direct add_child() would fail.
	player.add_child.call_deferred(_hitbox)


func _place_hitbox(attack: AttackDefinition, direction: float) -> void:
	_hitbox.position = Vector2(direction * absf(attack.hitbox_offset.x), attack.hitbox_offset.y)
	var rect := _hitbox_shape.shape as RectangleShape2D
	if rect:
		rect.size = attack.hitbox_size


func _check_hits() -> void:
	for area in _hitbox.get_overlapping_areas():
		var target: Node = area.get_parent()
		if target == null or target == player or _hit_targets.has(target):
			continue
		if target.has_method("take_hit"):
			_hit_targets.append(target)
			target.take_hit(_current, player.global_position)
#endregion


func _on_combo_window_timeout() -> void:
	_buffer = ""
	_set_combo(0)


func _set_combo(count: int) -> void:
	combo_changed.emit(count)
