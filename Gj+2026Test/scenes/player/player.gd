class_name Player
extends CharacterBody2D

#General
@export var speed: float = 200.0
@export var health: int = 100
@export var max_health: int = 100
@export var hurt_duration: float = 0.4
@export var knockback_friction: float = 10.0
#Stamina
@export_group("Stamina")
@export var stamina: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 20.0
@export var stamina_regen_delay: float = 1.0
@export var sprint_cost: float = 25.0
@export var sprint_speed_multiplier: float = 1.6
#-----
#Timers
@onready var hurt_timer: Timer = $HurtTimer
@onready var stamina_regen_timer: Timer = $StaminaRegenTimer
#Interact
@onready var interact_zone: Area2D = $InteractZone
#Animation
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var steps_sound: AudioStreamPlayer = $StepsSound
#-----
#Sprint
var _is_sprinting: bool = false
var _is_regenerating_stamina: bool = false
var _is_hurt: bool = false
var _is_attacking: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
#Interaction
var _control_blocked: bool = false
var _nearby_interactables: Array[Node] = []
var _current_interactable: Node = null
#ForStateMachine
var is_hurt: bool:
	get: return _is_hurt
var is_sprinting: bool:
	get: return _is_sprinting
var is_attacking: bool:
	get: return _is_attacking
var control_blocked: bool:
	get: return _control_blocked
var is_still: bool:
	get: return is_zero_approx(velocity.length())

func _ready() -> void:
	_setup_spawn_position()
	if hurt_timer:
		hurt_timer.wait_time = hurt_duration
	if stamina_regen_timer:
		stamina_regen_timer.wait_time = stamina_regen_delay

	SignalHub.emit_on_player_health_changed(health, max_health)
	SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)
	if SignalHub.has_signal("player_control_blocked"):
		SignalHub.player_control_blocked.connect(_on_control_blocked)

	if steps_sound and steps_sound.stream:
		_make_loopable(steps_sound.stream)

	# Activate AnimationTree
	if animation_tree:
		animation_tree.active = true

	# Connect InteractZone signals
	if interact_zone:
		interact_zone.area_entered.connect(_on_interact_zone_area_entered)
		interact_zone.area_exited.connect(_on_interact_zone_area_exited)
		interact_zone.body_entered.connect(_on_interact_zone_body_entered)
		interact_zone.body_exited.connect(_on_interact_zone_body_exited)
		
func _physics_process(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, knockback_friction * delta)

	var input: Vector2 = Vector2.ZERO
	if not _is_hurt and not _control_blocked and not _is_attacking:
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var current_speed: float = _handle_stamina(delta)

	# Update flip_h based on horizontal input
	if input.x != 0:
		sprite_2d.flip_h = input.x < 0

	velocity = (input * current_speed) + _knockback_velocity
	move_and_slide()
	_update_steps_sound(input)
	_update_current_interactable()
	
func _unhandled_input(event: InputEvent) -> void:
	if _control_blocked:
		return
	if event.is_action_pressed("interact") and _current_interactable != null:
		get_viewport().set_input_as_handled()
		try_interact()
#Sounds
func _make_loopable(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		
func _update_steps_sound(input: Vector2) -> void:
	if steps_sound == null or steps_sound.stream == null:
		return
	var should_play: bool = input != Vector2.ZERO and health > 0
	if should_play:
		steps_sound.pitch_scale = 1.25 if _is_sprinting else 1.0
		if not steps_sound.playing:
			steps_sound.play()
	elif steps_sound.playing:
		steps_sound.stop()

#Position
func _setup_spawn_position() -> void:
	var spawn: Node2D = get_parent().get_node_or_null("PlayerPos") if get_parent() else null
	if spawn == null and get_tree().current_scene:
		spawn = get_tree().current_scene.find_child("PlayerPos", true, false) as Node2D
	if spawn:
		global_position = spawn.global_position

func _on_control_blocked(blocked: bool) -> void:
	_control_blocked = blocked

#Stamina
func _handle_stamina(delta: float) -> float:
	var wants_to_sprint: bool = not _control_blocked and Input.is_action_pressed("sprint") and not is_still and not _is_hurt

	if wants_to_sprint and stamina > 0.0:
		_is_sprinting = true
		stamina = max(0.0, stamina - sprint_cost * delta)
		_is_regenerating_stamina = false
		if stamina_regen_timer:
			stamina_regen_timer.stop()
		SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)
		return speed * sprint_speed_multiplier
	else:
		_is_sprinting = false
		if stamina < max_stamina and not _is_regenerating_stamina and stamina_regen_timer and stamina_regen_timer.is_stopped():
			stamina_regen_timer.start()
		if _is_regenerating_stamina and stamina < max_stamina:
			stamina = min(max_stamina, stamina + stamina_regen_rate * delta)
			SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)
		return speed

func _on_stamina_regen_timer_timeout() -> void:
	_is_regenerating_stamina = true

#Combat
func begin_attack(anim_name: StringName, anim_speed: float) -> void:
	_is_attacking = true
	_is_sprinting = false
	if animation_tree:
		animation_tree.active = false
	if animation_player:
		animation_player.speed_scale = anim_speed
		animation_player.play(anim_name)

func end_attack() -> void:
	_is_attacking = false
	if animation_player:
		animation_player.speed_scale = 1.0
	if animation_tree:
		animation_tree.active = true

func apply_attack_lunge(direction: float, amount: float) -> void:
	_knockback_velocity += Vector2(direction * amount, 0.0)

#Health
func take_damage(amount: int, knockback_force: float = 0.0, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_hurt or health <= 0:
		return

	health = max(0, health - amount)
	SignalHub.emit_on_player_health_changed(health, max_health)

	if health <= 0:
		die()
		return

	_is_hurt = true
	var knockback_direction: Vector2 = (global_position - source_position).normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.LEFT

	_knockback_velocity = knockback_direction * knockback_force
	if hurt_timer:
		hurt_timer.start(hurt_duration)

func die() -> void:
	if steps_sound:
		steps_sound.stop()
	hide()
	get_tree().paused = true
	SignalHub.emit_on_game_over(false)

func _on_hurt_timer_timeout() -> void:
	_is_hurt = false
#Interact
func try_interact() -> void:
	if _current_interactable == null:
		return
	if _current_interactable.has_method("interact"):
		_current_interactable.interact(self)
	else:
		print("Player: %s is in interactable group but has no interact()" % _current_interactable.name)

func _update_current_interactable() -> void:
	var closest: Node = null
	var closest_dist: float = INF

	for i in range(_nearby_interactables.size() - 1, -1, -1):
		var target: Node = _nearby_interactables[i]
		if not is_instance_valid(target):
			_nearby_interactables.remove_at(i)
			continue
		var dist: float = global_position.distance_squared_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = target

	if closest != _current_interactable:
		_current_interactable = closest
		SignalHub.emit_on_interactable_changed(_current_interactable)

func _add_interactable(node: Node) -> void:
	if node.is_in_group("interactable") and not _nearby_interactables.has(node):
		_nearby_interactables.append(node)

func _remove_interactable(node: Node) -> void:
	_nearby_interactables.erase(node)

func _on_interact_zone_area_entered(area: Area2D) -> void:
	_add_interactable(area)

func _on_interact_zone_area_exited(area: Area2D) -> void:
	_remove_interactable(area)

func _on_interact_zone_body_entered(body: Node2D) -> void:
	_add_interactable(body)

func _on_interact_zone_body_exited(body: Node2D) -> void:
	_remove_interactable(body)
