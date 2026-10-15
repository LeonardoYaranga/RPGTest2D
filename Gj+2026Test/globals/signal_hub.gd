extends Node

#Player
signal player_health_changed(current_health: int, max_health: int)
signal player_stamina_changed(current_stamina: float, max_stamina: float)
signal game_over(won: bool)
signal player_control_blocked(blocked: bool)
#---
func emit_on_player_health_changed(current_health: int, max_health: int) -> void:
	player_health_changed.emit(current_health, max_health)
func emit_on_player_stamina_changed(current_stamina: float, max_stamina: float) -> void:
	player_stamina_changed.emit(current_stamina, max_stamina)
func emit_on_game_over(won: bool) -> void:
	game_over.emit(won)
func emit_on_player_control_blocked(blocked: bool) -> void:
	player_control_blocked.emit(blocked)
#Player

#Interaction
signal interactable_changed(interactable: Node)
#---
func emit_on_interactable_changed(interactable: Node) -> void:
	interactable_changed.emit(interactable)
#Interaction

#Enemy
signal enemy_health_changed(current_health: int, max_health: int)
signal enemy_died(enemy: Node)
#---
func emit_on_enemy_health_changed(current_health: int, max_health: int) -> void:
	enemy_health_changed.emit(current_health, max_health)
func emit_on_enemy_died(enemy: Node) -> void:
	enemy_died.emit(enemy)
#Enemy
