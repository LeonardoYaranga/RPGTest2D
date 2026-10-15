# Interact System Implementation Plan
## Gj+2026Test Project - Simplified from SANDA_2026 Reference

---

## 🎯 Objective

Implement a simplified interaction system where:
1. **Player** detects nearby interactable objects via `InteractZone` (Area2D)
2. **SignalHub** emits `interactable_changed` signal when closest interactable changes
3. **GameHud** displays an `InteractLabel` (inside `MCClues`) that shows/hides based on signal
4. **No separate ClueUI scene** - everything in GameHud
5. Player presses "interact" action to trigger `interact()` on the current interactable

---

## 📋 Current State Analysis

### ✅ Already Exists (Current Project)
| Component | Status |
|-----------|--------|
| `Player` scene with `InteractZone` (Area2D + CircleShape2D radius ~42) | ✅ In `player.tscn` |
| `SignalHub` global autoload | ✅ `globals/signal_hub.gd` |
| `GameHud` scene with health/stamina/game_over | ✅ `scenes/game_hud/game_hud.gd` + `.tscn` |
| Player movement, stamina, health systems | ✅ `player.gd` |

### ❌ Missing (Need to Implement)
| Component | Location |
|-----------|----------|
| `interactable_changed` signal + emitter in SignalHub | `globals/signal_hub.gd` |
| Interactable detection logic in Player | `scenes/player/player.gd` |
| Input handling for "interact" action | `scenes/player/player.gd` |
| `InteractLabel` in GameHud (inside `MCClues`) | `scenes/game_hud/game_hud.gd` + `.tscn` |
| Signal connection in GameHud | `scenes/game_hud/game_hud.gd` |

---

## 🏗️ Implementation Plan

### Phase 1: SignalHub - Add Interaction Signal
**File:** `globals/signal_hub.gd`

```gdscript
# Add to existing signals:
signal interactable_changed(interactable: Node)

# Add emitter function:
func emit_on_interactable_changed(interactable: Node) -> void:
	interactable_changed.emit(interactable)
```

### Phase 2: Player - Interactable Detection Logic
**File:** `scenes/player/player.gd`

#### 2.1 Add State Variables (after line 29)
```gdscript
var _nearby_interactables: Array[Node] = []
var _current_interactable: Node = null
```

#### 2.2 Connect InteractZone Signals in `_ready()`
```gdscript
# After existing _ready() setup (around line 51)
if $InteractZone:
	$InteractZone.area_entered.connect(_on_interact_zone_area_entered)
	$InteractZone.area_exited.connect(_on_interact_zone_area_exited)
	$InteractZone.body_entered.connect(_on_interact_zone_body_entered)
	$InteractZone.body_exited.connect(_on_interact_zone_body_exited)
```

#### 2.3 Add Input Handling in `_unhandled_input()` (new method)
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if _control_blocked:
		return
	if event.is_action_pressed("interact") and _current_interactable != null:
		get_viewport().set_input_as_handled()
		try_interact()
```

#### 2.4 Add Interactable Management Methods
```gdscript
func try_interact() -> void:
	if _current_interactable == null:
		return
	if _current_interactable.has_method("interact"):
		_current_interactable.interact(self)
	else:
		print("Player: %s is in interactable group but has no interact()" % _current_interactable.name)

func _update_current_interactable() -> void:
	var closest: Node = null
	var closest_dist: float = INF

	for i in range(_nearby_interactables.size() - 1, -1, -1):
		var target: Node = _nearby_interactables[i]
		if not is_instance_valid(target):
			_nearby_interactables.remove_at(i)
			continue
		var dist: float = global_position.distance_squared_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = target

	if closest != _current_interactable:
		_current_interactable = closest
		SignalHub.emit_on_interactable_changed(_current_interactable)

func _add_interactable(node: Node) -> void:
	if node.is_in_group("interactable") and not _nearby_interactables.has(node):
		_nearby_interactables.append(node)

func _remove_interactable(node: Node) -> void:
	_nearby_interactables.erase(node)

func _on_interact_zone_area_entered(area: Area2D) -> void:
	_add_interactable(area)

func _on_interact_zone_area_exited(area: Area2D) -> void:
	_remove_interactable(area)

func _on_interact_zone_body_entered(body: Node2D) -> void:
	_add_interactable(body)

func _on_interact_zone_body_exited(body: Node2D) -> void:
	_remove_interactable(body)
```

#### 2.5 Call `_update_current_interactable()` in `_physics_process()`
```gdscript
# At end of _physics_process (after _update_steps_sound)
_update_current_interactable()
```

### Phase 3: GameHud - Add InteractLabel UI
**File:** `scenes/game_hud/game_hud.tscn`

Add `MCClues` container with `InteractLabel` as child of root `GameHud` (sibling to `MC` and `ColorRectGameOver`):

```gdscript
[node name="MCClues" type="MarginContainer" parent="." unique_id=...]
layout_mode = 1
anchors_preset = 9  # Bottom center
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -150.0
offset_top = -80.0
offset_right = 150.0
offset_bottom = -20.0
grow_horizontal = 1
grow_vertical = 1
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="InteractLabel" type="Label" parent="MCClues" unique_id=...]
visible = false
layout_mode = 2
theme_override_font_sizes/font_size = 24
horizontal_alignment = 1
vertical_alignment = 1
text = "[F] Interactuar"
```

**File:** `scenes/game_hud/game_hud.gd`

```gdscript
# Add @onready (after line 7)
@onready var interact_label: Label = $MCClues/InteractLabel

# In _ready() (after line 14)
SignalHub.interactable_changed.connect(_on_interactable_changed)

# Add handler methods:
func _on_interactable_changed(interactable: Node) -> void:
	if interactable == null or not is_instance_valid(interactable):
		interact_label.hide()
		return
	
	var label_text: String = "Interactuar"
	if interactable.has_method("get_prompt_text"):
		label_text = interactable.get_prompt_text()
	
	interact_label.text = "[F] %s" % label_text
	interact_label.show()
```

### Phase 4: Interactable Objects - Standard Interface
Any object that should be interactable must:
1. Be in the **"interactable"** group
2. Implement `interact(player: Player)` method
3. Optionally implement `get_prompt_text() -> String` for custom prompt text

Example interactable script template:
```gdscript
# res://scenes/interactables/some_object.gd
extends Area2D  # or Node2D/CharacterBody2D with Area2D child
class_name SomeInteractable

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Player) -> void:
	# Interaction logic here
	print("Interacted with %s" % name)

func get_prompt_text() -> String:
	return "Custom Action"  # Optional: changes "[F] Interactuar" to "[F] Custom Action"
```

---

## 🔧 Input Map Configuration
Ensure **"interact"** action is defined in Project → Project Settings → Input Map:
- Default: **F** key (or **E**, whatever preferred)
- Can be gamepad button too

---

## 📦 File Modification Summary

| File | Changes |
|------|---------|
| `globals/signal_hub.gd` | +1 signal, +1 emitter function |
| `scenes/player/player.gd` | +2 vars, +7 methods, +signal connections, +input handling, +physics update call |
| `scenes/game_hud/game_hud.tscn` | +MCClues MarginContainer + InteractLabel |
| `scenes/game_hud/game_hud.gd` | +1 @onready, +1 signal connection, +1 handler |

---

## 🧪 Testing Checklist

1. **InteractZone Detection**
   - [ ] Player enters InteractZone radius → interactable added to array
   - [ ] Player exits → interactable removed
   - [ ] Multiple interactables → closest one selected
   - [ ] Invalid/queue_freed interactables cleaned up

2. **SignalHub Emission**
   - [ ] `interactable_changed` emitted when closest changes
   - [ ] `null` emitted when no interactables nearby

3. **GameHud UI**
   - [ ] InteractLabel hidden by default
   - [ ] Shows "[F] Interactuar" when near interactable
   - [ ] Shows custom text if `get_prompt_text()` implemented
   - [ ] Hides when interactable becomes null/invalid

4. **Interaction Execution**
   - [ ] Pressing "interact" (F) calls `interact(player)` on current
   - [ ] Input consumed (handled) so doesn't propagate
   - [ ] Blocked when `_control_blocked = true`

5. **Integration**
   - [ ] Works with existing health/stamina/game_over signals
   - [ ] No regression in player movement/combat

---

## 🎨 Design Decisions & Rationale

| Decision | Rationale |
|----------|-----------|
| SignalHub for `interactable_changed` | Decouples Player from UI; follows existing pattern (health, stamina, game_over) |
| Array + closest-distance selection | Handles multiple overlapping interactables gracefully |
| Group-based detection ("interactable") | Flexible - any node type can be interactable |
| `get_prompt_text()` optional method | Allows custom prompts without requiring base class |
| InteractLabel in GameHud (not separate scene) | Simplifies scene hierarchy; user explicitly requested this |
| Cleanup of invalid instances in loop | Prevents errors when interactables are queue_freed |

---

## 🚀 Future Extensions (Not in Scope)

- [ ] Interaction cooldown / debounce
- [ ] Visual feedback on InteractZone (debug gizmo)
- [ ] Priority system for interactables (e.g., doors > items)
- [ ] Gamepad-specific prompt icons
- [ ] Interaction progress bar for hold-to-interact

---

## 📝 Implementation Order

1. **SignalHub** (simplest, enables rest)
2. **Player** detection logic (core functionality)
3. **GameHud.tscn** UI structure (visual)
4. **GameHud.gd** signal handling (connects UI to logic)
5. **Test** with a sample interactable object

---

*Plan created based on SANDA_2026 reference implementation, adapted for Gj+2026Test simplified requirements.*
