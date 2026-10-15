extends Area2D

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Player) -> void:
	print("¡Interactuaste con %s!" % name)
	# Interaction logic...

func get_prompt_text() -> String:
	return "Examinar"
