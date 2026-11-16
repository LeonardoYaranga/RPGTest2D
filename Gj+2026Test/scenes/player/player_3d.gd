class_name Player3D
extends Character3D
## 2.5D Player inheriting Character3D with StateMachine, stamina, interaction, and AttackController3D.

@export_group("Jump")
@export var jump_force: float = 7.6

@export_group("Stamina")
@export var stamina: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 20.0
@export var stamina_regen_delay: float = 1.0
@export var sprint_cost: float = 25.0
@export var sprint_speed_multiplier: float = 1.6

@export_group("Death")
@export var pause_tree_on_death: bool = true

@onready var stamina_regen_timer: Timer = $StaminaRegenTimer
@onready var interact_zone: Area3D = $InteractZone
@onready var steps_sound: AudioStreamPlayer = $StepsSound
@onready var attack_controller: AttackController3D = $AttackController

var is_sprinting: bool = false
var control_blocked: bool:
	get: return _control_blocked

var _is_regenerating_stamina: bool = false
var _nearby_interactables: Array[Node] = []
var _current_interactable: Node = null


func _on_character_ready() -> void:
	if not is_in_group(&"player"):
		add_to_group(&"player")
	_setup_spawn_position()

	if stamina_regen_timer:
		stamina_regen_timer.wait_time = stamina_regen_delay
		if not stamina_regen_timer.timeout.is_connected(_on_stamina_regen_timer_timeout):
			stamina_regen_timer.timeout.connect(_on_stamina_regen_timer_timeout)

	SignalHub.emit_on_player_health_changed(health, max_health)
	SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)
	if SignalHub.has_signal(&"player_control_blocked"):
		SignalHub.player_control_blocked.connect(_on_control_blocked)

	if steps_sound and steps_sound.stream:
		_make_loopable(steps_sound.stream)

	if interact_zone:
		interact_zone.area_entered.connect(_on_interact_zone_area_entered)
		interact_zone.area_exited.connect(_on_interact_zone_area_exited)
		interact_zone.body_entered.connect(_on_interact_zone_body_entered)
		interact_zone.body_exited.connect(_on_interact_zone_body_exited)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_regenerate_stamina(delta)
	_update_current_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if _control_blocked or is_dead():
		return
	if event.is_action_pressed(&"interact") and _current_interactable != null:
		get_viewport().set_input_as_handled()
		try_interact()


func get_move_input() -> Vector2:
	if _control_blocked:
		return Vector2.ZERO
	return Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")


func set_sprinting(active: bool) -> void:
	is_sprinting = active


func resolve_move_speed(delta: float, allow_sprint: bool) -> float:
	var wants_sprint: bool = allow_sprint and not _control_blocked and Input.is_action_pressed(&"sprint")
	if wants_sprint and stamina > 0.0:
		is_sprinting = true
		consume_stamina(sprint_cost * delta)
		return move_speed * sprint_speed_multiplier
	is_sprinting = false
	return move_speed


func consume_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_is_regenerating_stamina = false
	if stamina_regen_timer:
		stamina_regen_timer.stop()
	SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)


func _regenerate_stamina(delta: float) -> void:
	if is_sprinting:
		return
	if stamina < max_stamina and not _is_regenerating_stamina and stamina_regen_timer and stamina_regen_timer.is_stopped():
		stamina_regen_timer.start()
	if _is_regenerating_stamina and stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
		SignalHub.emit_on_player_stamina_changed(stamina, max_stamina)


func _on_stamina_regen_timer_timeout() -> void:
	_is_regenerating_stamina = true


func _on_control_blocked(blocked: bool) -> void:
	_control_blocked = blocked


func _on_health_changed() -> void:
	SignalHub.emit_on_player_health_changed(health, max_health)


func _on_character_died() -> void:
	if steps_sound:
		steps_sound.stop()
	if attack_controller:
		attack_controller.cancel_attack()
	if sprite:
		sprite.hide()
	if pause_tree_on_death and get_tree():
		get_tree().paused = true
	SignalHub.emit_on_game_over(false)


func _setup_spawn_position() -> void:
	var spawn: Node3D = get_parent().get_node_or_null("PlayerPos") as Node3D if get_parent() else null
	if spawn == null and get_tree() and get_tree().current_scene:
		spawn = get_tree().current_scene.find_child("PlayerPos", true, false) as Node3D
	if spawn:
		global_position = spawn.global_position


func _make_loopable(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func update_steps_sound(input: Vector2) -> void:
	if steps_sound == null or steps_sound.stream == null:
		return
	var should_play: bool = input != Vector2.ZERO and health > 0 and is_on_floor()
	if should_play:
		steps_sound.pitch_scale = 1.25 if is_sprinting else 1.0
		if not steps_sound.playing:
			steps_sound.play()
	elif steps_sound.playing:
		steps_sound.stop()


#region Interaction
func try_interact() -> void:
	if _current_interactable == null:
		return
	if _current_interactable.has_method(&"interact"):
		_current_interactable.interact(self)


func _update_current_interactable() -> void:
	var closest: Node = null
	var closest_dist: float = INF

	for i in range(_nearby_interactables.size() - 1, -1, -1):
		var target: Node = _nearby_interactables[i]
		if not is_instance_valid(target) or not (target is Node3D):
			_nearby_interactables.remove_at(i)
			continue
		var dist: float = global_position.distance_squared_to((target as Node3D).global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = target

	if closest != _current_interactable:
		_current_interactable = closest
		SignalHub.emit_on_interactable_changed(_current_interactable)


func _add_interactable(node: Node) -> void:
	if node.is_in_group(&"interactable") and not _nearby_interactables.has(node):
		_nearby_interactables.append(node)


func _remove_interactable(node: Node) -> void:
	_nearby_interactables.erase(node)


func _on_interact_zone_area_entered(area: Area3D) -> void:
	_add_interactable(area)


func _on_interact_zone_area_exited(area: Area3D) -> void:
	_remove_interactable(area)


func _on_interact_zone_body_entered(body: Node3D) -> void:
	_add_interactable(body)


func _on_interact_zone_body_exited(body: Node3D) -> void:
	_remove_interactable(body)
#endregion
