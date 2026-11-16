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

#Combat / Training HUD (RCG2 / MK11 style)
signal combo_input_logged(token: String, action_name: String, status: String)
signal combo_buffer_changed(buffer: String, attack_id: StringName)
signal combo_hit_scored(combo_hits: int, total_damage: int, attack_id: StringName)
signal combo_completed(buffer: String, attack_id: StringName)
signal combo_dropped(reason: String)
#---
func emit_on_combo_input_logged(token: String, action_name: String, status: String) -> void:
	combo_input_logged.emit(token, action_name, status)
func emit_on_combo_buffer_changed(buffer: String, attack_id: StringName) -> void:
	combo_buffer_changed.emit(buffer, attack_id)
func emit_on_combo_hit_scored(combo_hits: int, total_damage: int, attack_id: StringName) -> void:
	combo_hit_scored.emit(combo_hits, total_damage, attack_id)
func emit_on_combo_completed(buffer: String, attack_id: StringName) -> void:
	combo_completed.emit(buffer, attack_id)
func emit_on_combo_dropped(reason: String) -> void:
	combo_dropped.emit(reason)
#Combat
