class_name EndingOverlay
extends Control
## Overlay displayed when a narrative branch ending is reached.

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton


func _ready() -> void:
	visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if SignalHub:
		SignalHub.ending_reached.connect(display_ending)


func display_ending(ending_id: StringName, summary: Dictionary = {}) -> void:
	visible = true
	get_tree().paused = true
	SignalHub.emit_on_player_control_blocked(true)

	if ending_id == &"redemption":
		title_label.text = "★ FINAL A: REDENCIÓN Y CONFIANZA"
		title_label.modulate = Color(0.2, 0.8, 1.0)
		subtitle_label.text = "\"El miedo no es la solución, la confianza sí.\""
		description_label.text = "Escuchaste el dolor de Marcus y le mostraste empatía en lugar de humillarlo.\nAl saberse comprendido, Marcus renuncia al acoso y Elena queda libre del miedo.\nLa escuela comienza a transformarse en una verdadera comunidad unida."
	else:
		title_label.text = "⚔ FINAL B: PAZ POR LA FUERZA"
		title_label.modulate = Color(1.0, 0.35, 0.35)
		subtitle_label.text = "\"El ciclo de la violencia continúa.\""
		description_label.text = "Sometiste a Marcus a golpes en la azotea. Aunque el acoso cesó por el momento,\nel resentimiento y el miedo siguen vivos entre las sombras del colegio."

	var bonds_info: String = ""
	if is_instance_valid(GameState):
		bonds_info = "Vínculos: Leo (Nvl %d) | Elena (Nvl %d) | Ser Misterioso (Nvl %d)\nPista investigada: %s" % [
			GameState.get_bond(&"amigo"),
			GameState.get_bond(&"chica"),
			GameState.get_bond(&"ser_misterioso"),
			"Sí (Página del Diario)" if GameState.has_item(&"diario_roto") else "No"
		]
	stats_label.text = bonds_info


func _on_restart_pressed() -> void:
	get_tree().paused = false
	if is_instance_valid(GameState):
		GameState.reset_state()
	if is_instance_valid(GameManager):
		GameManager.change_scene_to_room("res://scenes/levels/school_yard_3d.tscn", &"PlayerPos")
	else:
		get_tree().change_scene_to_file("res://scenes/levels/school_yard_3d.tscn")
