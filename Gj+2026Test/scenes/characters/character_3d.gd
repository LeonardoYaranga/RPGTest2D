class_name Character3D
extends CharacterBody3D
## Base 2.5D character class (inherited by Player3D, EnemyBase3D, NPCs).
## Owns common physics, health, hit flash, hitstop, ground shadow, hurtbox, and FSM wiring.

signal health_changed(current_health: int, max_health: int)
signal died(character: Character3D)

@export_group("Stats")
@export var max_health: int = 100
@export var move_speed: float = 5.5
@export var gravity: float = 22.0

@export_group("Combat Reaction")
@export var hit_flash_time: float = 0.12
@export var base_tint: Color = Color.WHITE
@export var hit_flash_color: Color = Color(2.5, 2.5, 2.5, 1.0)
@export var juggle_pop_velocity: float = 4.2
@export var debug_log: bool = false

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var ground_shadow: MeshInstance3D = get_node_or_null("GroundShadow") as MeshInstance3D
@onready var shadow_ray: RayCast3D = get_node_or_null("ShadowRay") as RayCast3D
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var hurtbox: Area3D = $Hurtbox
@onready var hurtbox_shape: CollisionShape3D = $Hurtbox/CollisionShape3D
@onready var state_machine: StateMachine = $StateMachine

var health: int = 0
var facing: float = 1.0
var _control_blocked: bool = false
var _hitstop_timer: float = 0.0
var _flash_timer: float = 0.0
var _base_sprite_y: float = 0.0
var _base_sprite_rot_x: float = -20.0


func _ready() -> void:
	health = max_health
	if sprite:
		sprite.modulate = base_tint
		_base_sprite_y = sprite.position.y
		_base_sprite_rot_x = sprite.rotation_degrees.x
	_on_character_ready()


func _on_character_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - delta)
		if _hitstop_timer == 0.0 and sprite:
			sprite.play()

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer == 0.0 and sprite:
			sprite.modulate = base_tint

	_update_ground_shadow()


func is_hitstop_active() -> bool:
	return _hitstop_timer > 0.0


func apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	_hitstop_timer = maxf(_hitstop_timer, duration)
	if sprite:
		sprite.pause()


func trigger_hit_flash(duration: float = -1.0) -> void:
	var t: float = hit_flash_time if duration < 0.0 else duration
	if t <= 0.0 or sprite == null:
		return
	_flash_timer = t
	sprite.modulate = hit_flash_color


func set_facing(dir_x: float) -> void:
	if is_zero_approx(dir_x):
		return
	facing = -1.0 if dir_x < 0.0 else 1.0
	if sprite:
		sprite.flip_h = facing < 0.0


func apply_gravity(delta: float, multiplier: float = 1.0) -> void:
	if not is_on_floor():
		velocity.y -= gravity * multiplier * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func apply_ground_friction(friction: float, delta: float) -> void:
	var weight: float = clampf(friction * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, 0.0, weight)
	velocity.z = lerpf(velocity.z, 0.0, weight)


func play_anim(anim_name: StringName, speed_scale: float = 1.0, force_restart: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var resolved: StringName = _resolve_anim_name(anim_name)
	if resolved == &"":
		return
	sprite.speed_scale = speed_scale
	if force_restart:
		sprite.stop()
		sprite.frame = 0
		sprite.play(resolved)
	elif sprite.animation != resolved or not sprite.is_playing():
		sprite.play(resolved)


func get_anim_duration(anim_name: StringName, speed_scale: float = 1.0) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 0.6
	var sf: SpriteFrames = sprite.sprite_frames
	var resolved: StringName = _resolve_anim_name(anim_name)
	if resolved == &"":
		return 0.6
	var count: int = sf.get_frame_count(resolved)
	var fps: float = sf.get_animation_speed(resolved)
	var base_len: float = (count / fps) if (count > 0 and fps > 0.0) else 0.7
	return base_len / maxf(0.05, speed_scale)


func _resolve_anim_name(anim_name: StringName) -> StringName:
	if sprite == null or sprite.sprite_frames == null:
		return &""
	var sf: SpriteFrames = sprite.sprite_frames
	if sf.has_animation(anim_name):
		return anim_name
	match anim_name:
		&"launched":
			if sf.has_animation(&"jump"):
				return &"jump"
		&"getup":
			if sf.has_animation(&"interact"):
				return &"interact"
		&"dead", &"knockdown", &"hurt":
			if sf.has_animation(&"hurt"):
				return &"hurt"
	if sf.has_animation(&"idle"):
		return &"idle"
	return &""


func set_knockdown_pose(down: bool) -> void:
	if sprite == null:
		return
	if down:
		sprite.position.y = _base_sprite_y + 0.25
		sprite.rotation_degrees = Vector3(_base_sprite_rot_x, 0.0, -90.0 * facing)
	else:
		sprite.position.y = _base_sprite_y
		sprite.rotation_degrees = Vector3(_base_sprite_rot_x, 0.0, 0.0)


func set_hurtbox_enabled(enabled: bool) -> void:
	if hurtbox_shape:
		hurtbox_shape.set_deferred(&"disabled", not enabled)
	if hurtbox:
		hurtbox.set_deferred(&"monitorable", enabled)


func set_body_collision_enabled(enabled: bool) -> void:
	if body_shape:
		body_shape.set_deferred(&"disabled", not enabled)


func is_hurtbox_enabled() -> bool:
	return hurtbox_shape != null and not hurtbox_shape.disabled


func is_dead() -> bool:
	return health <= 0 or (state_machine != null and state_machine.is_in_state(&"Dead"))


func take_hit(attack: AttackDefinition, source_position: Vector3) -> void:
	if attack == null or is_dead():
		return
	if not is_hurtbox_enabled() and not attack.can_hit_knockdown:
		return

	health = maxi(0, health - attack.damage)
	health_changed.emit(health, max_health)
	_on_health_changed()
	_on_hit_received(attack, source_position)

	var dir_xz := Vector3(global_position.x - source_position.x, 0.0, global_position.z - source_position.z)
	if dir_xz.length_squared() < 0.0001:
		dir_xz = Vector3.RIGHT
	else:
		dir_xz = dir_xz.normalized()

	if absf(dir_xz.x) > 0.05:
		set_facing(-dir_xz.x)

	var kb := Vector3(dir_xz.x * attack.knockback.x, 0.0, dir_xz.z * attack.knockback.x + attack.knockback.z)

	if health <= 0:
		if state_machine:
			state_machine.transition_to(&"Dead")
		return

	var airborne: bool = (state_machine != null and state_machine.is_in_state(&"Launched")) or not is_on_floor()

	# 1. LAUNCH reaction or mid-air juggle (unless explicit sweep knockdown)
	if (attack.reaction_type == AttackDefinition.HitReaction.LAUNCH or airborne) and attack.reaction_type != AttackDefinition.HitReaction.KNOCKDOWN:
		if state_machine != null and state_machine.has_state(&"Launched"):
			var launch_y: float = attack.launch if attack.launch > 0.0 else juggle_pop_velocity
			state_machine.transition_to(&"Launched", {
				"knockback": kb,
				"launch": launch_y,
			})
			return

	# 2. Direct KNOCKDOWN reaction (sweep or grounded takedown to floor)
	if attack.reaction_type == AttackDefinition.HitReaction.KNOCKDOWN:
		if state_machine != null and state_machine.has_state(&"Knockdown"):
			velocity.x = kb.x
			velocity.z = kb.z
			state_machine.transition_to(&"Knockdown", {
				"duration": 0.85,
				"knockback": kb,
			})
			return
		elif state_machine != null and state_machine.has_state(&"Launched"):
			state_machine.transition_to(&"Launched", {
				"knockback": kb,
				"launch": 1.2,
			})
			return

	# 3. Grounded hitstun / stagger (keeps enemy standing in place for continuous combos)
	if state_machine != null and state_machine.has_state(&"Hurt"):
		state_machine.transition_to(&"Hurt", {
			"knockback": kb,
			"hitstun": attack.hitstun,
		})


func on_death_entered() -> void:
	died.emit(self)
	_on_character_died()


func _on_health_changed() -> void:
	pass


func _on_hit_received(_attack: AttackDefinition, _source_position: Vector3) -> void:
	pass


func _on_character_died() -> void:
	pass


func _update_ground_shadow() -> void:
	if ground_shadow == null or shadow_ray == null:
		return
	shadow_ray.force_raycast_update()
	if shadow_ray.is_colliding():
		var hit_point: Vector3 = shadow_ray.get_collision_point()
		var height: float = maxf(0.0, global_position.y - hit_point.y)
		ground_shadow.visible = true
		ground_shadow.global_position = Vector3(global_position.x, hit_point.y + 0.02, global_position.z)
		var s: float = clampf(1.0 - height * 0.16, 0.4, 1.0)
		ground_shadow.scale = Vector3(s, 1.0, s)
	else:
		ground_shadow.visible = false
