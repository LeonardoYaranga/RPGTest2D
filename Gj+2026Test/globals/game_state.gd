extends Node

## Estado Global Persistente del Juego (Narrativa, RPG, Inventario y Guardado JSON)
## Accesible globalmente como `GameState`.

const SAVE_PATH: String = "user://save_game.json"

# --- Señales del Estado ---
signal story_flag_changed(flag_name: StringName, value: Variant)
signal bond_changed(npc_id: StringName, level: int)
signal inventory_changed(inventory: Dictionary)
signal quest_changed(title: String, objective: String)
signal skill_unlocked(skill_id: StringName)
signal state_loaded()
signal state_reset()

# --- Flags de Historia y Decisiones ---
var story_flags: Dictionary = {
	&"social_power_unlocked": false,
	&"promised_peaceful_path": false,
	&"confrontation_stance": false,
	&"bully_clue_found": false,
	&"ally_recruited": false,
	&"bully_defeated": false,
	&"ending_id": &""
}

# --- Vínculos Sociales (NPC ID -> Nivel de Afecto/Confianza) ---
var bonds: Dictionary = {
	&"amigo": 1,
	&"ser_misterioso": 0,
	&"chica": 0,
	&"bully": 0
}

# --- Inventario (Item ID -> Cantidad) ---
var inventory: Dictionary = {}

# --- Habilidades Desbloqueadas ---
var unlocked_skills: Array[StringName] = []

# --- Misión Actual ---
var current_quest_title: String = "Primer Día"
var current_quest_objective: String = "Habla con tu amigo Leo en el patio escolar."

# --- Posicionamiento entre salas ---
var pending_spawn_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


#region Manejo de Flags de Historia
func set_flag(flag_name: StringName, value: Variant) -> void:
	story_flags[flag_name] = value
	story_flag_changed.emit(flag_name, value)


func get_flag(flag_name: StringName, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)


func is_flag(flag_name: StringName) -> bool:
	return bool(get_flag(flag_name, false))
#endregion


#region Sistema de Vínculos y Habilidades
func add_bond(npc_id: StringName, amount: int = 1) -> int:
	var current: int = bonds.get(npc_id, 0)
	var new_level: int = current + amount
	bonds[npc_id] = new_level
	bond_changed.emit(npc_id, new_level)
	SignalHub.emit_on_bond_updated(npc_id, new_level)

	# Vínculos desbloquean habilidades y empoderan al protagonista
	_check_bond_unlocks(npc_id, new_level)
	return new_level


func get_bond(npc_id: StringName) -> int:
	return bonds.get(npc_id, 0)


func _check_bond_unlocks(npc_id: StringName, level: int) -> void:
	match npc_id:
		&"ser_misterioso":
			if level >= 1:
				unlock_skill(&"social_flow")
		&"amigo":
			if level >= 2:
				unlock_skill(&"friendship_assist")
		&"chica":
			if level >= 1:
				unlock_skill(&"empathy_strike")


func unlock_skill(skill_id: StringName) -> bool:
	if unlocked_skills.has(skill_id):
		return false
	unlocked_skills.append(skill_id)
	skill_unlocked.emit(skill_id)
	SignalHub.emit_on_skill_unlocked(skill_id)
	return true


func has_skill(skill_id: StringName) -> bool:
	return unlocked_skills.has(skill_id)
#endregion


#region Inventario
func add_item(item_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var current: int = inventory.get(item_id, 0)
	inventory[item_id] = current + amount
	inventory_changed.emit(inventory)
	SignalHub.emit_on_inventory_changed(inventory)


func has_item(item_id: StringName, amount: int = 1) -> bool:
	return inventory.get(item_id, 0) >= amount


func consume_item(item_id: StringName, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	inventory[item_id] = inventory[item_id] - amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit(inventory)
	SignalHub.emit_on_inventory_changed(inventory)
	return true


func get_item_count(item_id: StringName) -> int:
	return inventory.get(item_id, 0)
#endregion


#region Misiones
func set_quest(title: String, objective: String) -> void:
	current_quest_title = title
	current_quest_objective = objective
	quest_changed.emit(title, objective)
	SignalHub.emit_on_quest_updated(title, objective)
#endregion


#region Persistencia JSON (user://save_game.json)
func save_to_disk(path: String = SAVE_PATH) -> bool:
	var flags_dict: Dictionary = {}
	for k in story_flags.keys():
		flags_dict[str(k)] = story_flags[k]

	var bonds_dict: Dictionary = {}
	for k in bonds.keys():
		bonds_dict[str(k)] = bonds[k]

	var inv_dict: Dictionary = {}
	for k in inventory.keys():
		inv_dict[str(k)] = inventory[k]

	var skills_arr: Array = []
	for s in unlocked_skills:
		skills_arr.append(str(s))

	var data: Dictionary = {
		"version": 1,
		"story_flags": flags_dict,
		"bonds": bonds_dict,
		"inventory": inv_dict,
		"unlocked_skills": skills_arr,
		"current_quest_title": current_quest_title,
		"current_quest_objective": current_quest_objective,
		"pending_spawn_id": str(pending_spawn_id)
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[GameState] Fallo al abrir %s para escritura: %d" % [path, FileAccess.get_open_error()])
		return false

	var json_str := JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()
	return true


func load_from_disk(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[GameState] Fallo al abrir %s para lectura: %d" % [path, FileAccess.get_open_error()])
		return false

	var content: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		push_error("[GameState] Error al parsear JSON de %s: %s" % [path, json.get_error_message()])
		return false

	var data: Variant = json.data
	if not (data is Dictionary):
		push_error("[GameState] Datos inválidos en %s" % path)
		return false

	var raw_dict: Dictionary = data

	if raw_dict.has("story_flags") and raw_dict["story_flags"] is Dictionary:
		story_flags.clear()
		for k in raw_dict["story_flags"].keys():
			story_flags[StringName(k)] = raw_dict["story_flags"][k]

	if raw_dict.has("bonds") and raw_dict["bonds"] is Dictionary:
		bonds.clear()
		for k in raw_dict["bonds"].keys():
			bonds[StringName(k)] = int(raw_dict["bonds"][k])

	if raw_dict.has("inventory") and raw_dict["inventory"] is Dictionary:
		inventory.clear()
		for k in raw_dict["inventory"].keys():
			inventory[StringName(k)] = int(raw_dict["inventory"][k])

	if raw_dict.has("unlocked_skills") and raw_dict["unlocked_skills"] is Array:
		unlocked_skills.clear()
		for s in raw_dict["unlocked_skills"]:
			unlocked_skills.append(StringName(str(s)))

	current_quest_title = raw_dict.get("current_quest_title", "")
	current_quest_objective = raw_dict.get("current_quest_objective", "")
	pending_spawn_id = StringName(raw_dict.get("pending_spawn_id", ""))

	state_loaded.emit()
	inventory_changed.emit(inventory)
	SignalHub.emit_on_inventory_changed(inventory)
	SignalHub.emit_on_quest_updated(current_quest_title, current_quest_objective)
	return true


func has_save_file(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func delete_save_file(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func reset_state() -> void:
	story_flags = {
		&"social_power_unlocked": false,
		&"promised_peaceful_path": false,
		&"confrontation_stance": false,
		&"bully_clue_found": false,
		&"ally_recruited": false,
		&"bully_defeated": false,
		&"ending_id": &""
	}
	bonds = {
		&"amigo": 1,
		&"ser_misterioso": 0,
		&"chica": 0,
		&"bully": 0
	}
	inventory.clear()
	unlocked_skills.clear()
	current_quest_title = "Primer Día"
	current_quest_objective = "Habla con tu amigo Leo en el patio escolar."
	pending_spawn_id = &""
	state_reset.emit()
	inventory_changed.emit(inventory)
	SignalHub.emit_on_inventory_changed(inventory)
	SignalHub.emit_on_quest_updated(current_quest_title, current_quest_objective)
#endregion
