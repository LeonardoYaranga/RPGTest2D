class_name NPC3D
extends Character3D
## NPC entity in 2.5D with Dialogic 2 integration, billboard quest indicator, and FSM.

signal spoken(npc: NPC3D)

@export_group("Narrative")
@export var npc_id: StringName = &"amigo"
@export var display_name: String = "Leo"
@export var default_timeline: String = "yard_amigo_intro"
@export var quest_indicator_text: String = "!"
@export var modulate_color: Color = Color.WHITE

@onready var quest_indicator: Label3D = $QuestIndicator
@onready var interaction_area: Area3D = $InteractionArea

var interacting_player: Node3D = null


func _on_character_ready() -> void:
	if not is_in_group(&"interactable"):
		add_to_group(&"interactable")

	if sprite:
		sprite.modulate = modulate_color

	_update_quest_indicator()

	if GameState:
		GameState.quest_changed.connect(func(_t, _o): _update_quest_indicator())
		GameState.story_flag_changed.connect(func(_f, _v): _update_quest_indicator())


func get_prompt_text() -> String:
	return "Hablar con %s" % display_name


func interact(player: Node) -> void:
	if DialogicBridge and DialogicBridge.is_dialog_active():
		return

	interacting_player = player as Node3D

	var timeline_to_play: String = _resolve_timeline()
	if timeline_to_play.is_empty():
		return

	if state_machine:
		state_machine.transition_to(&"Talk", {"player": player})

	spoken.emit(self)

	if DialogicBridge:
		DialogicBridge.start_timeline(timeline_to_play, func():
			_update_quest_indicator()
		)


func _resolve_timeline() -> String:
	# Resuelve dinámicamente según el estado de GameState
	match npc_id:
		&"amigo":
			if GameState and GameState.is_flag(&"social_power_unlocked"):
				return "yard_amigo_intro"
			return default_timeline
		&"ser_misterioso":
			if GameState and GameState.is_flag(&"social_power_unlocked"):
				return "yard_ser_misterioso"
			return default_timeline
		&"chica":
			return default_timeline
		&"bully":
			return default_timeline
		_:
			return default_timeline


func _update_quest_indicator() -> void:
	if quest_indicator == null:
		return

	var should_show: bool = true
	match npc_id:
		&"amigo":
			should_show = not (GameState and GameState.get_bond(&"amigo") > 1)
		&"ser_misterioso":
			should_show = not (GameState and GameState.is_flag(&"social_power_unlocked"))
		&"chica":
			should_show = not (GameState and (GameState.is_flag(&"confrontation_stance") or GameState.is_flag(&"promised_peaceful_path")))
		&"bully":
			should_show = not (GameState and GameState.is_flag(&"bully_defeated"))
		_:
			should_show = true

	quest_indicator.visible = should_show
	quest_indicator.text = quest_indicator_text
