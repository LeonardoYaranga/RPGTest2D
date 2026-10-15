extends Node

const FADER = preload("res://scenes/fader/fader.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const GAME_HUD_SCENE: PackedScene = preload("res://scenes/game_hud/game_hud.tscn")

const MAIN = null
const GAME = null

var fader: Fader = null
## Scene to load when the screen goes black. Can be a PackedScene or a String path.
var next_scene: Variant = null
## Optional work done while the screen is black (before the new scene is loaded).
var _action_during_black: Callable = Callable()


func _ready() -> void:
	#The fader keeps running while the tree is paused, so a transition can
	#always finish and give the control back to the player.
	process_mode = Node.PROCESS_MODE_ALWAYS

	fader = FADER.instantiate()
	add_child(fader)


## Starts a transition: blocks the player control and plays the fade.
func start_transition(to_scene: Variant) -> void:
	next_scene = to_scene
	SignalHub.emit_on_player_control_blocked(true)
	fader.fade()


## Lists every public way to ask for a scene change.
func change_scene(scene: Variant) -> void:
	start_transition(scene)


func change_scene_to_packed(scene: PackedScene) -> void:
	start_transition(scene)


func change_scene_to_file(path: String) -> void:
	if path.is_empty():
		push_warning("GameManager: empty scene path.")
		return
	start_transition(path)


func change_to_main_scene() -> void:
	if MAIN == null:
		push_warning("GameManager: MAIN scene is not set yet.")
		return
	start_transition(MAIN)


func change_to_game_scene() -> void:
	if GAME == null:
		push_warning("GameManager: GAME scene is not set yet.")
		return
	start_transition(GAME)


## Fade out and back in, running action_during_black while the screen is black.
## Use it when you need everything hidden to swap something (rooms, dialogic, etc).
func fade_in_out(action_during_black: Callable = Callable()) -> void:
	_action_during_black = action_during_black
	start_transition(null)


## Called by the fader when the screen is already fully black.
func change_to_next_scene() -> void:
	if _action_during_black.is_valid():
		_action_during_black.call()
		_action_during_black = Callable()

	if next_scene == null:
		get_tree().paused = false
		SignalHub.emit_on_player_control_blocked(false)
		return

	var scene_to_change: Variant = next_scene
	next_scene = null

	if scene_to_change is PackedScene:
		get_tree().change_scene_to_packed(scene_to_change)
	elif scene_to_change is String:
		get_tree().change_scene_to_file(scene_to_change)
	else:
		push_error("GameManager: scene '%s' is not valid." % str(scene_to_change))
		SignalHub.emit_on_player_control_blocked(false)
		return

	#The actual scene swap is deferred, wait for the new scene to be in the tree.
	await get_tree().process_frame
	await get_tree().process_frame

	_setup_scene_entities(get_tree().current_scene)
	get_tree().paused = false
	SignalHub.emit_on_player_control_blocked(false)


## Leaves the scene ready to play: GameHud created if missing, player spawned
## and placed on its "PlayerPos" marker.
func _setup_scene_entities(scene: Node) -> void:
	if scene == null or scene is Control:
		return

	var existing_hud: Node = scene.find_child("GameHud", true, false)
	if existing_hud == null:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "HudCanvasLayer"
		hud_layer.layer = 1
		hud_layer.add_child(GAME_HUD_SCENE.instantiate())
		scene.add_child(hud_layer)

	var existing_player: Player = scene.find_child("Player", true, false) as Player
	if existing_player == null:
		existing_player = get_tree().get_first_node_in_group("player") as Player

	var spawn_pos: Marker2D = scene.find_child("PlayerPos", true, false) as Marker2D
	if spawn_pos == null:
		spawn_pos = scene.get_node_or_null("PlayerPos") as Marker2D

	if existing_player == null:
		var new_player := PLAYER_SCENE.instantiate() as Player
		if spawn_pos:
			new_player.global_position = spawn_pos.global_position
		scene.add_child(new_player)
	elif spawn_pos:
		existing_player.global_position = spawn_pos.global_position
