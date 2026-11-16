class_name RoomPortal3D
extends Area3D
## 3D Door / portal connecting micro-scenes in 2.5D with state checks and spawn targeting.

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_id: StringName = &"PlayerPos"
@export var prompt_message: String = "Entrar"
@export var required_flag: StringName = &""
@export var locked_message: String = "La puerta está cerrada con llave."

@onready var visual_indicator: Label3D = $Indicator


func _ready() -> void:
	if not is_in_group(&"interactable"):
		add_to_group(&"interactable")
	# Collision layer 32 corresponds to layer 6 (interactables)
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	_update_visuals()


func is_locked() -> bool:
	if required_flag.is_empty():
		return false
	if GameState:
		return not GameState.is_flag(required_flag)
	return false


func get_prompt_text() -> String:
	if is_locked():
		return locked_message
	return prompt_message


func interact(_player: Node) -> void:
	if is_locked():
		if visual_indicator:
			visual_indicator.text = "Cerrado"
			var tw := create_tween()
			tw.tween_property(visual_indicator, "modulate:a", 0.3, 0.4)
			tw.tween_property(visual_indicator, "modulate:a", 1.0, 0.4)
		return

	if target_scene_path.is_empty():
		push_warning("[RoomPortal3D] No target scene specified on %s" % name)
		return

	if GameManager:
		GameManager.change_scene_to_room(target_scene_path, target_spawn_id)


func _update_visuals() -> void:
	if visual_indicator:
		visual_indicator.text = "Puerta" if not is_locked() else "Cerrada"
		visual_indicator.modulate = Color(0.4, 0.9, 1.0) if not is_locked() else Color(1.0, 0.4, 0.4)
