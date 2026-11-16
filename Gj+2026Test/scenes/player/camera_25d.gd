class_name Camera25D
extends Camera3D
## Smooth 2.5D follow camera with configurable pitch, deadzone, and look-ahead.

@export var target: Node3D = null

@export_group("Framing")
@export var distance: float = 11.0
@export_range(15.0, 75.0, 0.5) var pitch_angle: float = 36.0
@export var target_height: float = 0.8

@export_group("Smoothing")
@export var follow_speed: float = 7.0
@export var vertical_follow_speed: float = 4.5
@export var deadzone_radius: float = 0.1

@export_group("Look Ahead")
@export var look_ahead_enabled: bool = true
@export var look_ahead_distance: float = 1.4
@export var look_ahead_speed: float = 3.5

var _current_look_ahead: Vector3 = Vector3.ZERO
var _current_target_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	top_level = true
	if target == null:
		if get_parent() and get_parent().get_parent() is Node3D:
			target = get_parent().get_parent() as Node3D
		elif get_tree():
			target = get_tree().get_first_node_in_group(&"player") as Node3D

	if target:
		_current_target_pos = target.global_position
		_snap_to_target()


func _compute_camera_offset() -> Vector3:
	var pitch_rad: float = deg_to_rad(pitch_angle)
	return Vector3(
		0.0,
		distance * sin(pitch_rad),
		distance * cos(pitch_rad)
	)


func _snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	var focus_point: Vector3 = target.global_position + Vector3(0.0, target_height, 0.0)
	var cam_offset: Vector3 = _compute_camera_offset()
	global_position = focus_point + cam_offset
	if is_inside_tree() and not global_position.is_equal_approx(focus_point):
		look_at(focus_point, Vector3.UP)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		if get_tree():
			target = get_tree().get_first_node_in_group(&"player") as Node3D
		if not is_instance_valid(target):
			return

	var target_world_pos: Vector3 = target.global_position
	var diff: Vector3 = target_world_pos - _current_target_pos
	diff.y = 0.0
	if diff.length() > deadzone_radius:
		var offset_xz: Vector3 = diff.normalized() * deadzone_radius
		_current_target_pos.x = target_world_pos.x - offset_xz.x
		_current_target_pos.z = target_world_pos.z - offset_xz.z

	_current_target_pos.y = target_world_pos.y

	var target_look_ahead := Vector3.ZERO
	if look_ahead_enabled and "velocity" in target:
		var vel: Vector3 = target.velocity
		var horiz := Vector3(vel.x, 0.0, vel.z)
		if horiz.length_squared() > 0.4:
			target_look_ahead = horiz.normalized() * look_ahead_distance

	var la_weight: float = 1.0 - exp(-look_ahead_speed * delta)
	_current_look_ahead = _current_look_ahead.lerp(target_look_ahead, la_weight)

	var cam_offset: Vector3 = _compute_camera_offset()
	var focus_point: Vector3 = _current_target_pos + Vector3(0.0, target_height, 0.0) + _current_look_ahead
	var desired_pos: Vector3 = focus_point + cam_offset

	var h_weight: float = 1.0 - exp(-follow_speed * delta)
	var v_weight: float = 1.0 - exp(-vertical_follow_speed * delta)
	global_position.x = lerpf(global_position.x, desired_pos.x, h_weight)
	global_position.z = lerpf(global_position.z, desired_pos.z, h_weight)
	global_position.y = lerpf(global_position.y, desired_pos.y, v_weight)

	var current_focus: Vector3 = global_position - cam_offset
	if is_inside_tree() and not global_position.is_equal_approx(current_focus):
		look_at(current_focus, Vector3.UP)
