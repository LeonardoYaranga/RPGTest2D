class_name InteractionForwarder3D
extends Area3D
## Forwards interaction events and prompt text to parent character (e.g. NPC3D or BullyBoss3D).


func get_prompt_text() -> String:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_method(&"get_prompt_text"):
		return parent_node.get_prompt_text()
	return "Interactuar"


func interact(player: Node) -> void:
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_method(&"interact"):
		parent_node.interact(player)
