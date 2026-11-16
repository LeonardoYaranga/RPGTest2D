class_name NpcTalkState
extends State
## Conversation state for NPC3D characters.


func enter(msg: Dictionary = {}) -> void:
	if character and character.sprite:
		character.sprite.play(&"idle")
	if character:
		character.velocity = Vector3.ZERO

	var player_node: Node3D = msg.get("player") as Node3D
	if player_node and character:
		var dx: float = player_node.global_position.x - character.global_position.x
		if absf(dx) > 0.05:
			character.set_facing(1 if dx > 0 else -1)

	if DialogicBridge and not DialogicBridge.dialog_ended.is_connected(_on_dialog_ended):
		DialogicBridge.dialog_ended.connect(_on_dialog_ended, CONNECT_ONE_SHOT)


func _on_dialog_ended(_timeline: String) -> void:
	if state_machine and state_machine.current_state == self:
		state_machine.transition_to(&"Idle")


func physics_update(delta: float) -> void:
	if character == null:
		return
	if not character.is_on_floor():
		character.velocity.y -= character.gravity * delta
	character.move_and_slide()
