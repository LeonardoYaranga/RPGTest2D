class_name GameHud
extends Control

@onready var health_bar: TextureProgressBar = $MCStatus/BarsVBox/HealthBar
@onready var stamina_bar: TextureProgressBar = $MCStatus/BarsVBox/StaminaBar
@onready var color_rect_game_over: ColorRect = $ColorRectGameOver
@onready var label_game_over: Label = $ColorRectGameOver/LabelGameOver
@onready var interact_label: Label = $MCClues/InteractLabel

func _ready() -> void:
	if color_rect_game_over:
		color_rect_game_over.hide()
	SignalHub.player_health_changed.connect(_on_player_health_changed)
	SignalHub.player_stamina_changed.connect(_on_player_stamina_changed)
	SignalHub.game_over.connect(_on_game_over)
	SignalHub.interactable_changed.connect(_on_interactable_changed)

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _on_player_stamina_changed(current_stamina: float, max_stamina: float) -> void:
	if stamina_bar and max_stamina > 0.0:
		var ratio: float = clampf(current_stamina / max_stamina, 0.0, 1.0)
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
		stamina_bar.tint_progress = Color.RED.lerp(Color.LIME_GREEN, ratio)

func _on_game_over(won: bool) -> void:
	if color_rect_game_over and label_game_over:
		color_rect_game_over.show()
		if won:
			label_game_over.text = "¡Has ganado!"
		else:
			label_game_over.text = "¡Has perdido!"

func _on_interactable_changed(interactable: Node) -> void:
	if interact_label == null:
		return
	if interactable == null or not is_instance_valid(interactable):
		interact_label.hide()
		return
	var label_text: String = "Interactuar"
	if interactable.has_method("get_prompt_text"):
		label_text = interactable.get_prompt_text()

	interact_label.text = "[F] %s" % label_text
	interact_label.show()
