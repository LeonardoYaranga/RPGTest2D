class_name EnemyBase3D
extends Character3D
## Base 2.5D enemy inheriting Character3D.
## Provides NavigationAgent3D, floating 3D HealthBar, targeting helpers, and
## full RCG2 hit reactions (Hurt -> Launched -> Knockdown -> GetUp -> Dead).

@export_group("AI")
@export var aggro_radius: float = 9.0
@export var attack_range_x: float = 1.15
@export var attack_range_z: float = 0.55

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite") as Sprite3D
@onready var health_viewport: SubViewport = get_node_or_null("HealthViewport") as SubViewport
@onready var health_bar: ProgressBar = get_node_or_null("HealthViewport/HealthBar") as ProgressBar

var target_player: Node3D = null
var _attack_cooldown_until_msec: int = 0


func _on_character_ready() -> void:
	if not is_in_group(&"enemy"):
		add_to_group(&"enemy")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if health_bar_sprite and health_viewport:
		health_bar_sprite.texture = health_viewport.get_texture()


func acquire_player() -> Node3D:
	if is_instance_valid(target_player) and not _is_target_dead(target_player):
		return target_player
	target_player = null
	if not get_tree():
		return null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D and is_instance_valid(node) and not _is_target_dead(node):
			var d: float = global_position.distance_squared_to((node as Node3D).global_position)
			if d < best_dist:
				best_dist = d
				target_player = node as Node3D
	return target_player


func _is_target_dead(node: Node) -> bool:
	if node.has_method(&"is_dead"):
		return bool(node.call(&"is_dead"))
	return "health" in node and node.health <= 0


func can_attack() -> bool:
	return Time.get_ticks_msec() >= _attack_cooldown_until_msec


func start_attack_cooldown(seconds: float) -> void:
	_attack_cooldown_until_msec = Time.get_ticks_msec() + int(round(seconds * 1000.0))


func is_in_attack_band(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	var dx: float = absf(target.global_position.x - global_position.x)
	var dz: float = absf(target.global_position.z - global_position.z)
	var dy: float = absf(target.global_position.y - global_position.y)
	return dx <= attack_range_x and dz <= attack_range_z and dy <= 1.2


func _on_health_changed() -> void:
	if health_bar:
		health_bar.value = health
	SignalHub.emit_on_enemy_health_changed(health, max_health)


func _on_hit_received(attack: AttackDefinition, _source_position: Vector3) -> void:
	if debug_log:
		print("[ENEMY] %s took %d (%s) -> hp %d/%d" % [name, attack.damage, attack.id, health, max_health])


func _on_character_died() -> void:
	if debug_log:
		print("[ENEMY] %s died" % name)
	if health_bar_sprite:
		health_bar_sprite.visible = false
	SignalHub.emit_on_enemy_died(self)
