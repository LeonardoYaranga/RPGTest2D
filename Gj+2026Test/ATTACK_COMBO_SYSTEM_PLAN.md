# Attack Combo System — Implementation Plan
## Gj+2026Test Project — River City Girls / Mortal Kombat style combos

---

## 🎯 Objective

Build a melee **combo combat system** where:

1. The player has **3 attack buttons**: `H`, `J`, `K`.
2. Pressing them in the right order **fast enough** chains a combo.
3. Pressing **slowly** gives only the **basic single attack** (combo resets).
4. Defined combos for v1: `H`, `H,H`, `H,H,K`, `H,H,H,K` (and standalone `J`, `K`).
5. The enemy reacts to hits: **hitstun → launch/float → fall to the floor → knockdown → stand up → fight again**.
6. The enemy can be used first as a **static training dummy** (to practice combos) and then toggled to **a real fighter** (chases and attacks).
7. Directional inputs (`Right + K, H, H, Down + K`) are **NOT** in scope now, but the design must allow adding them later.

> The name of each move does not matter. Only the input sequence, timing and reaction matter.

---

## 📋 Current State Analysis

### ✅ Already exists
| Component | Where | Notes |
|---|---|---|
| `Player` (CharacterBody2D) | `scenes/player/player.tscn` + `player.gd` | Movement, sprint/stamina, health, knockback, `take_damage()`, hurt state |
| Player animations | `player.tscn` → `AnimationPlayer`/`AnimationTree` | `idle`, `walk`, `run`, `jump`, `interact`, `hurt`, **`attack`** |
| `attack` animation | `AnimationPlayer` | 7 frames (`Sprite2D:frame` 217→223), **side facing only** |
| `Hitbox` Area2D | `player.tscn` | Exists but inert: `monitoring=false`, `collision_mask=0`, layer = `player_hitbox` (8) |
| Physics layer names | `project.godot` | `world, player_body, enemy_body, player_hitbox, enemy_hitbox, interactables, player_attack, enemy_attack` |
| `SignalHub` autoload | `globals/signal_hub.gd` | Global signal pattern (health, stamina, game_over, interactable) |
| Interact system | `scenes/interactables/`, `player.gd` | Reference for how a new subsystem was added (see `INTERACT_SYSTEM_PLAN.md`) |
| Sprite source | `assets/player/16x32/` | 5-direction character sheet (`Down`, `Down_Side`, `Side`, `Up_Side`, `Up`) |

### ❌ Missing / needs work
| Component | Notes |
|---|---|
| Attack input actions (`H`,`J`,`K`) | Not in `project.godot` [input] — keys are free |
| `attack` wired into `AnimationTree` | The `attack` animation is **not** referenced by the state machine at all |
| Player attack hitbox behavior | `Hitbox` is not configured to detect/apply damage |
| Enemy scene / script / art | **Does not exist** |
| Enemy hurtbox + hit reactions | Does not exist |
| Combo logic (buffer, window, chaining) | Does not exist |
| A **kick** animation | **Does not exist** — only `Punch_*` (5 dirs) and `Rotate` (8 frames) |

### ⚠️ Important asset gap: animations
The character sheet contains only:
- `Punch_Down`, `Punch_Down_Side`, `Punch_Side`, `Punch_Up_Side`, `Punch_Up` (7 frames each)
- `Idle` / `Walk` / `Run` / `Interact` / `Jump` (per direction)
- `Rotate` (single, 8 frames)

There is **no dedicated kick / hook / finisher animation**. The single `attack` animation used in `player.tscn` is the **side punch**.
See **Phase 6 / Decision D1** for how to handle this (MVP: reuse the punch with different timing; later: add real art).

---

## 🧠 Core Design

### 1. Input actions

Add 3 actions in **Project Settings → Input Map** (and to `project.godot`):

| Action | Key | Meaning |
|---|---|---|
| `attack_light` | **H** | light punch |
| `attack_medium` | **J** | heavy / medium |
| `attack_heavy` | **K** | kick / finisher |

Optional gamepad later (`X`, `Y`, `B`). No directional component yet.

### 2. Combo model — "input buffer + sequence table"

A small **trie** of valid sequences. Each node maps to an `AttackDefinition`.

```
H  ──► jab
│
├─ H ──► straight
│   │
│   ├─ H ──► hook
│   │   │
│   │   └─ K ──► kick_finisher_big      (H,H,H,K)
│   │
│   └─ K ──► kick_finisher              (H,H,K)
│
J  ──► heavy                              (standalone)
K  ──► kick                               (standalone)
```

Represented simply as a flat table keyed by the input string:

```gdscript
const COMBO_TABLE := {
    "H":    "jab",
    "HH":   "straight",
    "HHK":  "kick_finisher",
    "HHH":  "hook",
    "HHHK": "kick_finisher_big",
    "J":    "heavy",
    "K":    "kick",
}
```

**Matching rule (per attack press, token `T`):**
1. `candidate = _buffer + T`.
2. If `COMBO_TABLE` has `candidate` → play that attack, `_buffer = candidate`, restart combo window.
3. Else → it is not a valid continuation: `_buffer = ""`, then if `COMBO_TABLE` has `T` → play it and `_buffer = T`.
4. If `_buffer` window expires with no input → `_buffer = ""` → next press is a **fresh basic attack**.

This is exactly what gives the "**fast = combo, slow = basic punch**" behavior.

> Extensible later: use `"/"` separators for directional tokens, e.g. `"R_K/H/H/D_K"`. The matching algorithm never changes.

### 3. Combo window & canceling (the "feel")

Per attack we define:
- `hit_delay` — time before the hitbox turns on.
- `hit_window` — time the hitbox stays on.
- `cancel_time` — after this point the **recovery can be canceled** by the next input (makes chains snappy).
- `combo_window` — extra time **after the animation ends** during which an input still chains; after it, the buffer resets.

Timeline example:
```
press H ──► [ windup | ACTIVE | recovery ................ ]
                    │           │
                    │           └─ from here, next input CANCELS recovery → straight (HH)
                    │
                    └─ nothing pressed before anim end?
                          ├─ input within combo_window (0.35s) → straight (HH)
                          └─ no input → buffer clears → next H is a fresh JAB
```

Inputs pressed **during** an attack are **buffered** (`_pending_token`) and consumed the moment the attack becomes cancelable.

### 4. Hitboxes / hurtboxes / physics layers

**Convention (using the already-named layers):**

| Layer name | Value | Used by |
|---|---|---|
| `world` | 1 | tilemap walls/furniture |
| `player_body` | 2 | Player `CharacterBody2D` |
| `enemy_body` | 4 | Enemy `CharacterBody2D` |
| `player_hitbox` | 8 | **Player hurtbox** (the area enemies can hit) |
| `enemy_hitbox` | 16 | **Enemy hurtbox** (the area the player can hit) |
| `interactables` | 32 | `InteractZone`, notes |
| `player_attack` | 64 | **Player attack hitbox** |
| `enemy_attack` | 128 | **Enemy attack hitbox** |

**Detection runs from the attack hitbox** (it is only "alive" during active frames):

| Node | Type | layer | mask | monitoring |
|---|---|---|---|---|
| Player `AttackHitbox` | Area2D | `player_attack` | `enemy_hitbox` | ✅ (shape disabled by default) |
| Enemy `Hurtbox` | Area2D | `enemy_hitbox` | 0 | ❌ (passive) |
| Enemy `AttackHitbox` | Area2D | `enemy_attack` | `player_hitbox` | ✅ |
| Player `Hurtbox` | Area2D | `player_hitbox` | 0 | ❌ (passive) |

- The existing player `Hitbox` node will be **repurposed/renamed** as the `Hurtbox` (it is not referenced in `player.gd`, so renaming is safe).
- A **new** `AttackHitbox` Area2D is added to the player.
- Enable/disable the hitbox by toggling its `CollisionShape2D.disabled` (deferred), and keep a `_hit_this_swing` set so one swing can hit a target only once.

### 5. Attack data as Resources

Each move is a small `Resource` so designers can tune values without touching code.

```gdscript
class_name AttackDefinition
extends Resource

@export var id: StringName = &"jab"
@export var animation: StringName = &"attack"   # AnimationTree state / AnimationPlayer anim
@export var speed_scale: float = 1.0

@export_group("Damage")
@export var damage: int = 4
@export var hitstop: float = 0.05                # freeze frames on connect (juice)

@export_group("Hitbox")
@export var hit_delay: float = 0.10              # windup before active
@export var hit_window: float = 0.08             # active frames
@export var hitbox_offset: Vector2 = Vector2(14, -10)
@export var hitbox_size: Vector2 = Vector2(22, 20)

@export_group("Reaction")
@export var hitstun: float = 0.18                # enemy can't act
@export var knockback: Vector2 = Vector2(60, 0)  # horizontal push
@export var launch: float = 0.0                  # >0 = upward velocity (airborne)

@export_group("Combo")
@export var cancel_time: float = 0.16
@export var combo_window: float = 0.35
@export var lunge: float = 30.0                  # small forward step
@export var stamina_cost: float = 0.0
```

Store them in `res://resources/attacks/*.tres`.

### 6. Enemy hit reactions (float → fall → get up)

Enemy state machine (`enum State`):

```
IDLE / CHASE / ATTACK          (fighter behavior)
HURT        (hitstun, grounded small knockback)
LAUNCHED    (airborne, gravity applied, can be juggled)
KNOCKDOWN   (on the floor, timer)
GETUP       (stand-up animation, then back to IDLE/CHASE)
DEAD
```

`take_hit(attack, source_position)` logic:

```gdscript
func take_hit(attack: AttackDefinition, source_pos: Vector2) -> void:
    if _state == State.DEAD:
        return
    health = max(0, health - attack.damage)
    SignalHub.emit_on_enemy_health_changed(health, max_health)
    if health <= 0:
        _enter_dead(); return

    var dir: float = signf(global_position.x - source_pos.x)
    if dir == 0.0: dir = -1.0

    if attack.launch > 0.0:
        # PUNCHES still "float" the enemy briefly before the floor
        _state = State.LAUNCHED
        _velocity = Vector2(dir * attack.knockback.x, -attack.launch)
    else:
        _state = State.HURT
        _velocity = Vector2(dir * attack.knockback.x, 0.0)
        _hitstun_timer.start(attack.hitstun)
```

In `_physics_process`, when `LAUNCHED`:
- apply gravity to `_velocity.y`;
- `move_and_slide()`;
- if `is_on_floor()` and `_velocity.y >= 0` → `_state = KNOCKDOWN`, start `knockdown_timer` (~1.0s);
- on knockdown timeout → play `getup` → back to `IDLE` (dummy) or `CHASE` (fighter).

Optional: allow juggling (extra hits while `LAUNCHED` refresh the state).

### 7. Training dummy vs. fighter (single toggle)

```gdscript
enum Behavior { TRAINING_DUMMY, FIGHTER }
@export var behavior: Behavior = Behavior.TRAINING_DUMMY
```

- **TRAINING_DUMMY**: never moves, never attacks. Only reacts to being hit. Perfect for practicing combos.
- **FIGHTER**: chases the player (NavigationAgent2D) and attacks when in range.

You can place several enemies in the test level, some as dummies and some as fighters.

---

## 📊 Combo Table v1 (proposed tuning)

| Input | Move | Anim (speed) | Damage | Windup | Active | Cancel | Combo win. | Hitstun | Knockback.x | Launch | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `H` | Jab | attack (1.4×) | 4 | 0.10 | 0.08 | 0.14 | 0.35 | 0.18 | 60 | 0 | basic single punch |
| `H,H` | Straight | attack (1.2×) | 5 | 0.10 | 0.08 | 0.16 | 0.35 | 0.20 | 90 | 0 | |
| `H,H,H` | Hook | attack (1.0×) | 6 | 0.14 | 0.10 | 0.18 | 0.40 | 0.22 | 120 | 0 | |
| `H,H,K` | Kick finisher | attack (0.9×) | 9 | 0.16 | 0.12 | 0.20 | — | 0.35 | 160 | 380 | **launches → knockdown → getup** |
| `H,H,H,K` | Big finisher | attack (0.85×) | 14 | 0.18 | 0.14 | 0.22 | — | 0.50 | 220 | 470 | **launches higher** |
| `J` | Heavy | attack (0.7×) | 10 | 0.22 | 0.12 | 0.22 | 0.30 | 0.30 | 140 | 120 | slow, small pop |
| `K` | Kick | attack (0.9×) | 8 | 0.16 | 0.12 | 0.20 | 0.30 | 0.30 | 150 | 250 | standalone launcher |

> All values are first guesses — the point is they live in `.tres` resources and are easy to tune.
> `launch` is initial upward velocity (px/s). Gravity ≈ 980 px/s².

---

## 🏗️ Files to Add / Change

### New
| File | Purpose |
|---|---|
| `resources/attacks/attack_definition.gd` | `AttackDefinition` Resource class |
| `resources/attacks/jab.tres`, `straight.tres`, `hook.tres`, `kick_finisher.tres`, `kick_finisher_big.tres`, `heavy.tres`, `kick.tres` | Tuning data |
| `scenes/combat/hurtbox.gd` | Mark a collider as a hurtbox (holds owner ref) |
| `scenes/combat/hitbox.gd` | Attack hitbox: applies an `AttackDefinition` to hurtboxes it overlaps |
| `scenes/player/attack_controller.gd` | Combo buffer, matching, window, hitbox toggling, movement lock |
| `scenes/enemies/enemy.gd` | Enemy state machine, hit reactions, dummy/fighter AI |
| `scenes/enemies/enemy.tscn` | Enemy scene (placeholder art) |
| `scenes/enemies/enemy_hurtbox.gd` | Optional, or reuse `hurtbox.gd` |
| `scenes/level/test/training_level.tscn` | Test scene with dummies + 1 fighter toggle |

### Changed
| File | Change |
|---|---|
| `project.godot` | +3 input actions (`attack_light`, `attack_medium`, `attack_heavy`) |
| `scenes/player/player.tscn` | Rename/repurpose `Hitbox` → `Hurtbox`; add `AttackHitbox` Area2D; add `AttackController` node; add `attack` state to `AnimationTree` |
| `scenes/player/player.gd` | Expose `is_attacking` getter; block movement/interact while attacking; hook `AttackController` |
| `globals/signal_hub.gd` | +`enemy_health_changed`, `enemy_died`, optional `combo_changed(count)` |

---

## 💻 Code Sketches

### `scenes/player/attack_controller.gd`

```gdscript
class_name AttackController
extends Node

signal combo_changed(count: int)

const COMBO_TABLE := {
    "H": "jab", "HH": "straight", "HHK": "kick_finisher",
    "HHH": "hook", "HHHK": "kick_finisher_big",
    "J": "heavy", "K": "kick",
}

const TOKEN := {
    "attack_light": "H", "attack_medium": "J", "attack_heavy": "K",
}

@export var attacks: Dictionary = {}   # id -> AttackDefinition (set in _ready or inspector)

@onready var player: Player = owner
@onready var hitbox: Area2D = owner.get_node("AttackHitbox")

var _buffer: String = ""
var _pending: String = ""
var _is_attacking: bool = false
var _current: AttackDefinition = null
var _combo_count: int = 0
var _window_timer: Timer
var _hit_done: bool = false

func _ready() -> void:
    _window_timer = Timer.new(); _window_timer.one_shot = true
    _window_timer.timeout.connect(func(): _buffer = ""; _set_combo(0))
    add_child(_window_timer)
    hitbox.area_entered.connect(_on_hitbox_area_entered)
    _set_hitbox(false)

func _unhandled_input(event: InputEvent) -> void:
    if player.is_hurt or player.control_blocked:
        return
    for action in TOKEN:
        if event.is_action_pressed(action):
            get_viewport().set_input_as_handled()
            _press(TOKEN[action])
            return

func _press(token: String) -> void:
    if _is_attacking:
        if _current and _elapsed >= _current.cancel_time:
            _advance(token)          # cancel recovery into next combo step
        else:
            _pending = token          # too early: buffer it
        return
    _advance(token)

func _advance(token: String) -> void:
    var candidate: String = _buffer + token
    if COMBO_TABLE.has(candidate):
        _buffer = candidate
        _play(COMBO_TABLE[candidate])
    else:
        _buffer = token if COMBO_TABLE.has(token) else ""
        if _buffer != "":
            _play(COMBO_TABLE[_buffer])
        else:
            _set_combo(0)

func _play(id: String) -> void:
    _current = attacks[id]
    _is_attacking = true
    _hit_done = false
    _elapsed = 0.0
    _window_timer.stop()
    _set_combo(_buffer.length())
    player.play_attack(_current)      # AnimationTree.travel(...) + speed_scale

# ... _physics_process drives _elapsed, toggles the hitbox between
#     hit_delay and hit_delay+hit_window, applies lunge, ends the attack,
#     consumes _pending, and starts _window_timer on finish.

func _on_hitbox_area_entered(area: Area2D) -> void:
    if _hit_done or _current == null:
        return
    var target := area.get_parent()
    if target.has_method("take_hit"):
        _hit_done = true
        target.take_hit(_current, player.global_position)
```

### `scenes/enemies/enemy.gd` (core)

```gdscript
class_name Enemy
extends CharacterBody2D

enum Behavior { TRAINING_DUMMY, FIGHTER }
enum State { IDLE, CHASE, ATTACK, HURT, LAUNCHED, KNOCKDOWN, GETUP, DEAD }

@export var behavior: Behavior = Behavior.TRAINING_DUMMY
@export var max_health: int = 60
@export var gravity: float = 980.0
@export var move_speed: float = 90.0
@export var detection_range: float = 260.0
@export var attack_range: float = 34.0
@export var attack_damage: int = 8

var health: int
var _state: State = State.IDLE
var _velocity := Vector2.ZERO
# timers: _hitstun_timer, _knockdown_timer, _getup_timer, _attack_cd_timer
# @onready navigation_agent, hurtbox, attack_hitbox, anim tree, sprite

func _physics_process(delta: float) -> void:
    match _state:
        State.LAUNCHED:
            _velocity.y += gravity * delta
            velocity = _velocity
            move_and_slide()
            if is_on_floor() and _velocity.y >= 0.0:
                _enter_knockdown()
        State.HURT:
            velocity = _velocity
            _velocity = _velocity.move_toward(Vector2.ZERO, 600.0 * delta)
            move_and_slide()
        State.CHASE:
            # move toward player via NavigationAgent2D, flip sprite
            pass
        State.ATTACK:
            pass
        _:
            velocity = Vector2.ZERO
            if _state != State.KNOCKDOWN and _state != State.GETUP:
                move_and_slide()

func take_hit(attack, source_pos: Vector2) -> void:
    # see section 6 above
    pass
```

---

## 🚧 Implementation Phases

**Phase 0 — Inputs & scaffolding**
- Add `attack_light/medium/heavy` actions (H/J/K).
- Create `AttackDefinition` + the 7 `.tres` attack resources.
- Add `is_attacking` getter to `player.gd`.

**Phase 1 — Single attack actually hits (no combos yet)**
- Reconfigure player `Hitbox` → `Hurtbox`; add `AttackHitbox` on `player_attack`, mask `enemy_hitbox`.
- Create a minimal enemy with only a `Hurtbox` (no AI) placed in the test level.
- Press `H` → play `attack` anim → hitbox active → enemy takes damage + hitstun.
- **Goal:** prove damage pipeline before adding complexity.

**Phase 2 — Combo chaining + window**
- Implement `AttackController` buffer/table/window/cancel.
- Verify: `H` → jab; `H,H` → straight; `H,H,K` → finisher; slow presses → only jab.

**Phase 3 — Enemy reactions**
- Add `HURT`, `LAUNCHED`, `KNOCKDOWN`, `GETUP`, `DEAD` states + timers.
- Verify finisher launches → falls → gets up.

**Phase 4 — Training dummy**
- `behavior = TRAINING_DUMMY`: stands still, only reacts. Good for practice.

**Phase 5 — Fighter AI**
- `behavior = FIGHTER`: chase (NavigationAgent2D) + telegraph + attack.
- Enemy `AttackHitbox` damages the player (reuse `player.take_damage`).

**Phase 6 — Animation gap + polish**
- Add distinct `punch_1` / `punch_2` / `kick` animations (see D1).
- Hitstop, screen shake, hit sparks, SFX, optional combo counter UI.

**Phase 7 (future) — Directional combos**
- Tokens become `direction + attack` (e.g. `R_K/H/H/D_K`); the matcher is unchanged.
- Add directional attack animations (the sheet already has 5 facings).

---

## 🧪 Testing Checklist

**Combo logic**
- [ ] `H` alone → single jab (even if repeated slowly)
- [ ] `H,H` fast → jab → straight
- [ ] `H,H,K` fast → jab → straight → kick finisher
- [ ] `H,H,H,K` fast → jab → straight → hook → big finisher
- [ ] Slow presses → combo resets to basic jab
- [ ] Input during recovery is buffered and chains correctly
- [ ] Invalid continuation (e.g. `H,J`) starts `J` cleanly
- [ ] Combo window expiry clears the buffer

**Hit / reaction**
- [ ] One swing hits each enemy at most once
- [ ] Hitbox only active during `hit_delay..hit_delay+hit_window`
- [ ] Player can't hit hurtboxes of allies/itself
- [ ] Normal hits = hitstun + knockback (grounded)
- [ ] Finisher = launch → airborne → land → knockdown → getup → resume
- [ ] Enemy at 0 HP → dead state

**Training / fighter**
- [ ] Dummy never moves or attacks; only reacts
- [ ] Fighter chases, attacks in range, damages player
- [ ] Player hurt cancels combos and blocks attacks

**No regressions**
- [ ] Movement, sprint/stamina, interact still work
- [ ] Player health/game-over signals unchanged
- [ ] No errors on scene reload / enemy death

---

## ❓ Decisions to Confirm

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | Kick / finisher animation | (a) reuse `attack` with different `speed_scale`; (b) create new `punch_1/punch_2/kick` frames; (c) use the `Rotate` sheet as a stand-in kick | **(a) for MVP**, then (b). Keeps momentum; combat logic doesn't depend on art. |
| **D2** | Attack data storage | (a) `.tres` resources; (b) constants in `AttackController` | **(a)** — easier to tune, matches Godot idioms. |
| **D3** | Enemy art | (a) reuse player sheet tinted red as placeholder; (b) simple shapes; (c) commission/draw | **(a)** — gives idle/hurt/attack visuals for free. |
| **D4** | Enemy navigation | (a) NavigationAgent2D (nav mesh already set up); (b) simple `move_toward` | **(b) first** (jam speed), (a) if the level needs obstacles. |
| **D5** | Hitstop / screenshake | now or later | **Later** (Phase 6) — don't block core combos. |
| **D6** | Where combos are authored | constant table vs. resource | **Constant table** now; a `ComboDefinition` resource later if needed. |

---

## 📝 Implementation Order (short version)

1. Input actions (H/J/K) + `AttackDefinition` + `.tres` files.
2. Player `AttackHitbox` + enemy `Hurtbox` → **one attack lands**.
3. `AttackController`: buffer + combo table + window + cancel.
4. Enemy states: hurt / launch / knockdown / getup.
5. `TRAINING_DUMMY` toggle → practice mode.
6. Fighter AI (chase + attack).
7. Polish (animations, hitstop, UI).
8. Directional combos (future).

---

*Plan created for Gj+2026Test. Follows the same structure as `INTERACT_SYSTEM_PLAN.md`.*
