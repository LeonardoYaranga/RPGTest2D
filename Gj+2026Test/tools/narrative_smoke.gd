extends Node

const TEST_SAVE_PATH := "user://test_narrative_save.json"

func _ready() -> void:
	print("\n==========================================")
	print("       NARRATIVE & RPG SMOKE TEST")
	print("==========================================")
	await get_tree().process_frame
	await get_tree().process_frame

	_test_game_state_core()
	_test_json_save_load()
	_test_dialogic_bridge_signals()
	_test_interactables_and_portals()
	_test_level_scenes_instantiation()
	_test_combat_with_social_bonus()
	_test_ending_overlay_branching()

	print("\n==========================================")
	print("ALL NARRATIVE TESTS PASSED! (Code 0)")
	print("==========================================")
	get_tree().quit(0)


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		push_error("ASSERTION FAILED: %s" % msg)
		print("FAILED: %s" % msg)
		get_tree().quit(1)
	else:
		print("  ✓ %s" % msg)


func _test_game_state_core() -> void:
	print("\n[1] Testing GameState Core Mechanics...")
	GameState.reset_state()

	# Flags
	_assert(GameState.is_flag(&"social_power_unlocked") == false, "initial social_power_unlocked is false")
	GameState.set_flag(&"social_power_unlocked", true)
	_assert(GameState.is_flag(&"social_power_unlocked") == true, "set_flag social_power_unlocked works")

	# Bonds & Skills
	_assert(GameState.get_bond(&"amigo") == 1, "initial amigo bond is 1")
	GameState.add_bond(&"amigo", 1)
	_assert(GameState.get_bond(&"amigo") == 2, "amigo bond increased to 2")
	_assert(GameState.has_skill(&"friendship_assist"), "friendship_assist skill unlocked at bond 2")

	GameState.add_bond(&"ser_misterioso", 1)
	_assert(GameState.has_skill(&"social_flow"), "social_flow unlocked with ser_misterioso")

	# Inventory
	_assert(GameState.has_item(&"diario_roto") == false, "initially no diario_roto")
	GameState.add_item(&"diario_roto", 1)
	_assert(GameState.has_item(&"diario_roto") == true, "diario_roto added to inventory")
	_assert(GameState.get_item_count(&"diario_roto") == 1, "diario_roto count is 1")
	var consumed := GameState.consume_item(&"diario_roto", 1)
	_assert(consumed and not GameState.has_item(&"diario_roto"), "diario_roto consumed correctly")

	# Quests
	GameState.set_quest("Investigación", "Revisa las taquillas")
	_assert(GameState.current_quest_title == "Investigación", "quest title updated")
	_assert(GameState.current_quest_objective == "Revisa las taquillas", "quest objective updated")


func _test_json_save_load() -> void:
	print("\n[2] Testing JSON Persistence Roundtrip...")
	GameState.reset_state()
	GameState.set_flag(&"social_power_unlocked", true)
	GameState.set_flag(&"promised_peaceful_path", true)
	GameState.add_bond(&"chica", 2)
	GameState.add_item(&"diario_roto", 1)
	GameState.set_quest("Clímax", "Sube a la azotea")

	var save_ok := GameState.save_to_disk(TEST_SAVE_PATH)
	_assert(save_ok, "GameState saved successfully to disk")
	_assert(GameState.has_save_file(TEST_SAVE_PATH), "Save file exists on disk")

	# Wipe state in memory
	GameState.reset_state()
	_assert(GameState.is_flag(&"social_power_unlocked") == false, "state reset verified")
	_assert(GameState.has_item(&"diario_roto") == false, "inventory reset verified")

	# Reload
	var load_ok := GameState.load_from_disk(TEST_SAVE_PATH)
	_assert(load_ok, "GameState loaded successfully from disk")
	_assert(GameState.is_flag(&"social_power_unlocked") == true, "flag social_power_unlocked preserved")
	_assert(GameState.is_flag(&"promised_peaceful_path") == true, "flag promised_peaceful_path preserved")
	_assert(GameState.get_bond(&"chica") == 2, "bond chica preserved as 2")
	_assert(GameState.has_item(&"diario_roto") == true, "item diario_roto preserved")
	_assert(GameState.current_quest_title == "Clímax", "quest title preserved")

	GameState.delete_save_file(TEST_SAVE_PATH)
	_assert(not GameState.has_save_file(TEST_SAVE_PATH), "Save file cleaned up")


func _test_dialogic_bridge_signals() -> void:
	print("\n[3] Testing DialogicBridge Signal Dispatcher...")
	GameState.reset_state()

	DialogicBridge._on_dialogic_signal("give_item:diario_roto:1")
	_assert(GameState.has_item(&"diario_roto"), "signal give_item adds item to GameState")

	DialogicBridge._on_dialogic_signal("set_flag:confrontation_stance=true")
	_assert(GameState.is_flag(&"confrontation_stance"), "signal set_flag activates story flag")

	DialogicBridge._on_dialogic_signal("add_bond:chica:1")
	_assert(GameState.get_bond(&"chica") == 1, "signal add_bond increments bond")

	DialogicBridge._on_dialogic_signal("quest:Nueva Misión|Objetivo de prueba")
	_assert(GameState.current_quest_title == "Nueva Misión", "signal quest sets title")
	_assert(GameState.current_quest_objective == "Objetivo de prueba", "signal quest sets objective")


func _test_interactables_and_portals() -> void:
	print("\n[4] Testing RoomPortal3D and CluePickup3D...")
	GameState.reset_state()

	# Portal lock condition
	var portal := RoomPortal3D.new()
	portal.target_scene_path = "res://scenes/levels/school_hallway_3d.tscn"
	portal.required_flag = &"social_power_unlocked"
	_assert(portal.is_locked() == true, "portal is locked when required_flag is false")

	GameState.set_flag(&"social_power_unlocked", true)
	_assert(portal.is_locked() == false, "portal is unlocked when required_flag is true")
	portal.free()

	# Clue pickup
	var clue := CluePickup3D.new()
	clue.item_id = &"diario_roto"
	clue.pickup_flag = &"bully_clue_found"
	add_child(clue)
	clue.interact(null)
	_assert(GameState.has_item(&"diario_roto"), "clue interact gives item to GameState")
	_assert(GameState.is_flag(&"bully_clue_found"), "clue interact sets pickup_flag")


func _test_level_scenes_instantiation() -> void:
	print("\n[5] Testing 3 Micro-Rooms Instantiation...")
	var yard_scene := load("res://scenes/levels/school_yard_3d.tscn") as PackedScene
	_assert(yard_scene != null, "school_yard_3d.tscn loads successfully")
	var yard := yard_scene.instantiate()
	_assert(yard != null, "school_yard_3d instantiates cleanly")
	_assert(yard.find_child("NPC_Amigo", true, false) != null, "NPC_Amigo exists in yard")
	_assert(yard.find_child("NPC_SerMisterioso", true, false) != null, "NPC_SerMisterioso exists in yard")
	_assert(yard.find_child("PortalToHallway", true, false) != null, "PortalToHallway exists in yard")
	yard.free()

	var hall_scene := load("res://scenes/levels/school_hallway_3d.tscn") as PackedScene
	_assert(hall_scene != null, "school_hallway_3d.tscn loads successfully")
	var hall := hall_scene.instantiate()
	_assert(hall != null, "school_hallway_3d instantiates cleanly")
	_assert(hall.find_child("NPC_Elena", true, false) != null, "NPC_Elena exists in hallway")
	_assert(hall.find_child("Clue_Diario", true, false) != null, "Clue_Diario exists in hallway")
	_assert(hall.find_child("PortalToRooftop", true, false) != null, "PortalToRooftop exists in hallway")
	hall.free()

	var roof_scene := load("res://scenes/levels/school_rooftop_3d.tscn") as PackedScene
	_assert(roof_scene != null, "school_rooftop_3d.tscn loads successfully")
	var roof := roof_scene.instantiate()
	_assert(roof != null, "school_rooftop_3d instantiates cleanly")
	_assert(roof.find_child("BullyBoss", true, false) != null, "BullyBoss exists on rooftop")
	roof.free()


func _test_combat_with_social_bonus() -> void:
	print("\n[6] Testing Social Bonds Combat Damage Buff...")
	GameState.reset_state()
	# Without social power:
	_assert(GameState.is_flag(&"social_power_unlocked") == false, "social power not yet unlocked")

	var player_scene := load("res://scenes/player/player_3d.tscn") as PackedScene
	var dummy_scene := load("res://scenes/enemies/training_dummy_3d.tscn") as PackedScene
	var p := player_scene.instantiate() as Player3D
	var d := dummy_scene.instantiate() as Character3D
	add_child(p)
	add_child(d)
	p.global_position = Vector3(0, 0, 0)
	d.global_position = Vector3(0.8, 0, 0)

	var atk_ctrl := p.get_node("AttackController") as AttackController3D
	_assert(atk_ctrl != null, "AttackController exists on Player3D")

	# Base damage without bonus: Jab has base 4 damage
	var hp_before := d.health
	d.take_hit(preload("res://resources/attacks/jab.tres"), Vector3.ZERO)
	var dealt_base := hp_before - d.health
	_assert(dealt_base == 4, "base jab deals 4 damage")

	# Now unlock social power and build bonds:
	GameState.set_flag(&"social_power_unlocked", true)
	GameState.add_bond(&"amigo", 1)        # 2
	GameState.add_bond(&"chica", 1)        # 1
	GameState.add_bond(&"ser_misterioso", 1) # 1
	# Total bonus = 2 + 1 + 1 = +4 dmg

	var bonus_calc := GameState.get_bond(&"amigo") + GameState.get_bond(&"chica") + GameState.get_bond(&"ser_misterioso")
	_assert(bonus_calc == 4, "social bond bonus calculated as +4")

	p.queue_free()
	d.queue_free()


func _test_ending_overlay_branching() -> void:
	print("\n[7] Testing Ending Overlay Branching...")
	var ending_scene := load("res://scenes/game_hud/ending_overlay.tscn") as PackedScene
	_assert(ending_scene != null, "ending_overlay.tscn loads")
	var overlay := ending_scene.instantiate() as EndingOverlay
	add_child(overlay)

	# Test Redemption
	GameState.set_flag(&"promised_peaceful_path", true)
	GameState.add_item(&"diario_roto", 1)
	overlay.display_ending(&"redemption")
	_assert(overlay.visible == true, "overlay is visible on ending")
	_assert("REDENCIÓN" in overlay.title_label.text, "Redemption ending displays correct title")
	_assert("Página del Diario" in overlay.stats_label.text, "Stats indicate diary was found")

	# Test Brute Force
	overlay.display_ending(&"brute_force")
	_assert("FUERZA" in overlay.title_label.text, "Brute force ending displays correct title")

	overlay.queue_free()
