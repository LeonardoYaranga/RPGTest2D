class_name BullyBoss3D
extends EnemyBase3D
## Boss Marcus on the Rooftop with pre-fight and post-fight narrative integration.

signal confrontation_started()
signal resolution_triggered()

@export var is_hostile: bool = false
@export var pre_fight_timeline: String = "rooftop_confrontation"
@export var post_fight_timeline: String = "rooftop_resolution"

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea") as Area3D
@onready var quest_marker: Label3D = get_node_or_null("QuestIndicator") as Label3D

var _fight_started: bool = false
var _resolution_started: bool = false


func _on_character_ready() -> void:
	super._on_character_ready()
	base_tint = Color(1.0, 0.45, 0.45, 1.0)
	if sprite:
		sprite.modulate = base_tint

	if not is_hostile:
		if hurtbox:
			hurtbox.monitoring = false
			hurtbox.monitorable = false
		if not is_in_group(&"interactable"):
			add_to_group(&"interactable")

	if DialogicBridge:
		DialogicBridge.combat_requested.connect(_on_combat_requested)


func get_prompt_text() -> String:
	if not _fight_started:
		return "Confrontar a Marcus"
	return ""


func interact(_player: Node) -> void:
	if _fight_started or (DialogicBridge and DialogicBridge.is_dialog_active()):
		return
	if quest_marker:
		quest_marker.visible = false
	if DialogicBridge:
		DialogicBridge.start_timeline(pre_fight_timeline)


func _on_combat_requested(boss_id: StringName) -> void:
	if boss_id != &"bully" and boss_id != StringName(name.to_lower()):
		return
	start_boss_battle()


func start_boss_battle() -> void:
	_fight_started = true
	is_hostile = true
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
	if quest_marker:
		quest_marker.visible = false
	if state_machine:
		state_machine.transition_to(&"Chase")
	confrontation_started.emit()


func _on_character_died() -> void:
	if _resolution_started:
		return
	_resolution_started = true
	resolution_triggered.emit()

	if health_bar_sprite:
		health_bar_sprite.visible = false

	# Marcus stays knocked down on the floor for the resolution dialogue
	if state_machine:
		state_machine.transition_to(&"Knockdown")

	# Launch resolution dialog
	if DialogicBridge:
		DialogicBridge.start_timeline(post_fight_timeline)
