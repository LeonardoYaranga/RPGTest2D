class_name Note3D
extends Area3D
## 3D interactable note compatible with Player3D's InteractZone and GameHud.


func _ready() -> void:
	if not is_in_group(&"interactable"):
		add_to_group(&"interactable")


func interact(_player: Node) -> void:
	print("¡Interactuaste con %s!" % name)


func get_prompt_text() -> String:
	return "Examinar"
