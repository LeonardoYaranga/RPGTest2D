class_name EnemyMeleeAttackState
extends State
## Telegraphed melee attack state for brawler enemies.
## Uses an AttackDefinition resource and an Area3D hitbox targeting player_hitbox.

const DEFAULT_ATTACK: AttackDefinition = preload("res://resources/attacks/enemy_punch.tres")

@export var attack_def: AttackDefinition = DEFAULT_ATTACK
@export var cooldown_time: float = 0.95
@export var lunge_friction: float = 9.0

var _elapsed: float = 0.0
var _duration: float = 0.7
var _hit_applied: bool = false
var _lunge_applied: bool = false
var _hitbox: Area3D = null
var _hitbox_shape: CollisionShape3D = null


func _ready() -> void:
	call_deferred(&"_ensure_hitbox")


func enter(_msg: Dictionary = {}) -> void:
	_ensure_hitbox()
	_elapsed = 0.0
	_hit_applied = false
	_lunge_applied = false

	var move: AttackDefinition = attack_def if attack_def != null else DEFAULT_ATTACK
	_duration = move.duration if move.duration > 0.0 else character.get_anim_duration(move.animation, move.speed_scale)

	var enemy := character as EnemyBase3D
	if enemy:
		var player: Node3D = enemy.acquire_player()
		if player:
			var dx: float = player.global_position.x - enemy.global_position.x
			if absf(dx) > 0.02:
				enemy.set_facing(dx)

	character.velocity.x = 0.0
	character.velocity.z = 0.0
	_place_hitbox(move)
	character.play_anim(move.animation, move.speed_scale)


func exit() -> void:
	if character and character.sprite:
		character.sprite.speed_scale = 1.0
	var enemy := character as EnemyBase3D
	if enemy:
		enemy.start_attack_cooldown(cooldown_time)


func physics_update(delta: float) -> void:
	var move: AttackDefinition = attack_def if attack_def != null else DEFAULT_ATTACK
	_elapsed += delta

	if not _lunge_applied and _elapsed >= move.hit_delay * 0.7:
		_lunge_applied = true
		character.velocity.x = character.facing * move.lunge

	if not _hit_applied and _elapsed >= move.hit_delay and _elapsed <= move.hit_delay + move.hit_window:
		_check_hits(move)

	character.apply_gravity(delta)
	character.apply_ground_friction(lunge_friction, delta)
	character.move_and_slide()

	if _elapsed >= _duration:
		if state_machine.has_state(&"Chase"):
			state_machine.transition_to(&"Chase")
		else:
			state_machine.transition_to(&"Idle")


func _ensure_hitbox() -> void:
	if _hitbox != null or character == null:
		return
	_hitbox = character.get_node_or_null("EnemyAttackHitbox") as Area3D
	if _hitbox != null:
		_hitbox_shape = _hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
		return

	_hitbox = Area3D.new()
	_hitbox.name = "EnemyAttackHitbox"
	_hitbox.collision_layer = 1 << 7   # layer 8: enemy_attack
	_hitbox.collision_mask = 1 << 3    # layer 4: player_hitbox
	_hitbox.monitoring = true
	_hitbox.monitorable = false

	_hitbox_shape = CollisionShape3D.new()
	_hitbox_shape.name = "CollisionShape3D"
	_hitbox_shape.shape = BoxShape3D.new()
	_hitbox.add_child(_hitbox_shape)

	character.add_child(_hitbox)


func _place_hitbox(move: AttackDefinition) -> void:
	if _hitbox == null or _hitbox_shape == null:
		return
	_hitbox.position = Vector3(
		character.facing * absf(move.hitbox_offset.x),
		move.hitbox_offset.y,
		move.hitbox_offset.z
	)
	var box := _hitbox_shape.shape as BoxShape3D
	if box:
		box.size = move.hitbox_size
	_hitbox.force_update_transform()


func _check_hits(move: AttackDefinition) -> void:
	if _hitbox == null:
		return
	for area in _hitbox.get_overlapping_areas():
		var target: Node = area.get_parent()
		if target == null or target == character:
			continue
		if target.has_method(&"take_hit"):
			_hit_applied = true
			target.take_hit(move, character.global_position)
			if move.hitstop > 0.0:
				character.apply_hitstop(move.hitstop)
				if target.has_method(&"apply_hitstop"):
					target.apply_hitstop(move.hitstop)
			return
