class_name DeadState
extends State
## Death state shared across characters. Disables hurtbox/body collisions and cleans up.

@export var free_delay: float = 0.45
@export var auto_free: bool = true

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = free_delay
	character.velocity = Vector3.ZERO
	character.set_hurtbox_enabled(false)
	character.set_body_collision_enabled(false)
	character.set_knockdown_pose(true)
	character.play_anim(&"dead")
	character.on_death_entered()


func physics_update(delta: float) -> void:
	if not auto_free:
		return
	_timer -= delta
	if character.sprite and free_delay > 0.0:
		var ratio: float = clampf(_timer / free_delay, 0.0, 1.0)
		character.sprite.modulate.a = ratio
	if _timer <= 0.0:
		character.queue_free()
