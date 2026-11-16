class_name CluePickup3D
extends Area3D
## Collectible item or narrative clue in 2.5D that stores in GameState.

@export var item_id: StringName = &"diario_roto"
@export var item_name: String = "Página del Diario"
@export var prompt_message: String = "Recoger Página del Diario"
@export var pickup_flag: StringName = &"bully_clue_found"

@onready var visual_mesh: MeshInstance3D = get_node_or_null("VisualMesh") as MeshInstance3D
@onready var label_indicator: Label3D = get_node_or_null("Indicator") as Label3D


func _ready() -> void:
	if not is_in_group(&"interactable"):
		add_to_group(&"interactable")
	# Collision layer 32 is layer 6 (interactables)
	collision_layer = 32
	collision_mask = 0
	monitoring = false

	# If already picked up, remove from scene
	if GameState and (GameState.has_item(item_id) or GameState.is_flag(pickup_flag)):
		queue_free()


func get_prompt_text() -> String:
	return prompt_message


func interact(_player: Node) -> void:
	if GameState:
		GameState.add_item(item_id, 1)
		if not pickup_flag.is_empty():
			GameState.set_flag(pickup_flag, true)

	# Gentle pickup animation and cleanup
	set_deferred("monitoring", false)
	collision_layer = 0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 0.6, 0.3)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tw.finished.connect(queue_free)
