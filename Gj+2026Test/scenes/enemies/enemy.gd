class_name Enemy
extends CharacterBody2D
## Melee enemy. For now it works as a training dummy: it only reacts to hits.
## Launch / knockdown / getup (phase 3) and the fighter AI (phase 5) come later.

enum Behavior { TRAINING_DUMMY, FIGHTER }

@export var behavior: Behavior = Behavior.TRAINING_DUMMY
@export var max_health: int = 60
@export var knockback_friction: float = 8.0
@export var hit_flash_time: float = 0.12

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar

var health: int = 0
var _knockback: Vector2 = Vector2.ZERO
var _hitstun: float = 0.0
var _flash: float = 0.0
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	if sprite:
		_base_modulate = sprite.modulate
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health


func _physics_process(delta: float) -> void:
	if _hitstun > 0.0:
		_hitstun = maxf(0.0, _hitstun - delta)

	_knockback = _knockback.lerp(Vector2.ZERO, knockback_friction * delta)
	velocity = _knockback

	# Only move while there is actual knockback. Calling move_and_slide() every
	# frame makes the idle body depenetrate away from the player standing on it,
	# so the "static" dummy would slowly get shoved around.
	if _knockback.length_squared() > 1.0:
		move_and_slide()
	else:
		_knockback = Vector2.ZERO
		velocity = Vector2.ZERO

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash == 0.0 and sprite:
			sprite.modulate = _base_modulate


## Called by the player's attack hitbox.
func take_hit(attack: AttackDefinition, source_position: Vector2) -> void:
	if health <= 0:
		return

	health = maxi(0, health - attack.damage)
	if health_bar:
		health_bar.value = health
	SignalHub.emit_on_enemy_health_changed(health, max_health)

	var dir: float = signf(global_position.x - source_position.x)
	if is_zero_approx(dir):
		dir = -1.0

	# Launchers push harder for now; real airborne/knockdown is phase 3.
	var force: float = attack.knockback.x
	if attack.launch > 0.0:
		force = maxf(force, attack.launch * 0.35)

	_knockback = Vector2(dir * force, attack.knockback.y)
	_hitstun = maxf(_hitstun, attack.hitstun)

	_flash = hit_flash_time
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.flip_h = dir < 0.0

	if health <= 0:
		_die()


func _die() -> void:
	SignalHub.emit_on_enemy_died(self)
	queue_free()
