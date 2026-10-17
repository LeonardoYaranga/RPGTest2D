# Animation Pipeline Plan — per-animation spritesheets

> **Project:** `Gj+2026Test` (Godot 4.7.2)
> **Goal:** replace the single `16x32 All Animations-Sheet.png` with **one spritesheet per animation** (idle.png, walk.png, punch_hook.png, …), so new hand-drawn animations at higher resolution can be added one clip at a time.
> **Status:** plan only — **nothing in the project has been changed.**
> **Companions:** `COMBAT_SYSTEM_HANDOFF.md` (combat/debug), `COMBOS_RESEARCH.md` (combo theory).
> **Last updated:** 2026-10-16

---

## 1. Current state (verified, not assumed)

### 1.1 The sprite
| Property | Value |
|---|---|
| Node | `Player/Sprite2D` (`Sprite2D`) |
| Texture | `res://assets/player/16x32/16x32 All Animations-Sheet.png` |
| Size | 1120 × 224 |
| `hframes` × `vframes` | 35 × 7 → **245 cells of 32×32** |
| `region_enabled` | `true`, `region_rect = Rect2(0, 1, 1120, 224)` |
| `frame` (default) | `39` |
| `position` | `(0, -6)` |
| Node `Player` scale | none (1:1 → 1 cell = 32 world px on screen) |

Atlas rows are unevenly filled (measured by decoding the PNG): `r0=8, r1=20, r2=20, r3=30, r4=20, r5=25, r6=35` cells.

### 1.2 The clips (`AnimationPlayer` → library `player`)
Extracted directly from `scenes/player/player.tscn`:

| Clip | Length | Loop | Tracks | Frame indices |
|---|---|---|---|---|
| `RESET` | 0.001 | – | `modulate` + `frame` | 39 |
| `attack` | 0.90 | no | `frame` | 217–223 (7) |
| `hurt` | 0.40 | no | `modulate` **only** (red flash, no pose) | — |
| `idle` | 0.70 | **yes** | `frame` | 39–42 (4) |
| `interact` | 0.60 | no | `frame` | 144–147 (4) |
| `jump` | 0.80 | no | `frame` | 180–184 (5) |
| `run` | 1.00 *(default)* | **yes** | `frame` | 111–116 (6) |
| `walk` | 0.70 | **yes** | `frame` | 74–77 (4) |

> Only `RESET` and `hurt` touch `modulate`. Every other clip is a pure `frame` index animation into the shared atlas.

### 1.3 The `AnimationTree`
- Root: `AnimationNodeStateMachine` with states **idle**, **walk**, **run**, **hurt** (+ `Start → idle`).
- Transitions are selected by **advance-expressions** evaluated on the Player node:
  `is_still`, `is_sprinting`, `is_hurt` (these are real getters in `player.gd`).
- `jump` and `interact` are **not** in the tree (they're played directly, or currently unused).

### 1.4 Who touches the sprite/animation (the only coupling points)
`scenes/player/player.gd`
```
25: @onready var sprite_2d: Sprite2D = $Sprite2D
26: @onready var animation_tree: AnimationTree = $AnimationTree
27: @onready var animation_player: AnimationPlayer = $AnimationPlayer
68-69:  animation_tree.active = true
87-89:  sprite_2d.flip_h = input.x < 0
158-165: begin_attack(anim_name, anim_speed) → tree.active=false; player.speed_scale=anim_speed; player.play(anim_name)
167-172: end_attack() → speed_scale=1.0; tree.active=true
```
`scenes/player/attack_controller.gd`
```
161: direction = -1 if player.sprite_2d.flip_h else 1     # hitbox facing
165: player.begin_attack(attack.animation, attack.speed_scale)
202-205: _attack_duration() = animation_player.get_animation(anim).length / attack.speed_scale
```

**Everything else in the game is indifferent to how the sprite is animated.** That's why this change is contained.

---

## 2. Plan A — keep `Sprite2D` + `AnimationPlayer` (zero code changes)

Each clip keeps its existing `frame` track, but gains three extra constant tracks keyed once at `t = 0`:

```
Sprite2D:texture   → res://assets/player/<...>/idle.png     (Texture2D)
Sprite2D:hframes   → <frames in that strip>                 (int)
Sprite2D:vframes   → 1                                      (int)
Sprite2D:frame     → 0, 1, 2, … (LOCAL indices, not atlas indices)
```

### Steps
1. Import the new PNGs into `assets/player/<res>/`.
2. Open `player.tscn` → select `AnimationPlayer` → for each clip:
   - Add a **Property Track** for `Sprite2D:texture`, key the PNG at `t = 0`.
   - Add **Property Tracks** for `Sprite2D:hframes` and `Sprite2D:vframes`, key the values at `t = 0`.
   - Re-key the existing `frame` track using **local** indices starting at 0.
   - Set the clip's `length` to the real duration (and `speed_scale = 1.0` on the matching `.tres`).
3. Add the new attack clips (`punch_jab`, …) to the library and point each `.tres` `animation` at them.
4. Update `RESET` to reset `texture`/`hframes`/`vframes` too (or leave the atlas as the default texture and only override per clip).

### Pros / cons
- ✅ **No GDScript changes.** `AnimationTree`, advance-expressions, the attack bypass, and the `.tres` duration lookup all keep working.
- ✅ Fully editable in the GUI.
- ❌ 3–4 tracks × ~13 clips hand-edited.
- ❌ You must keep `hframes` in sync manually whenever a sheet's frame count changes.
- ❌ Texture property tracks are **not blendable** (they snap) — fine for frames, but worth knowing.

---

## 3. Plan B — `AnimatedSprite2D` + `SpriteFrames` (recommended for many separate PNGs)

`AnimatedSprite2D` owns its own `SpriteFrames`: one named animation per clip, each holding that clip's own PNG with its own frame count/size. Editing is drag-and-drop.

### Steps
1. Add an `AnimatedSprite2D` node (replace `Sprite2D`), create a `SpriteFrames` resource.
2. For every clip add an animation with the **exact name** (`idle`, `walk`, `run`, `hurt`, `jump`, `interact`, `punch_jab`, `punch_straight`, `punch_hook`, `punch_heavy`, `kick_round`, `kick_front`, `kick_big`), drag its PNG in ("Add frames from sprite sheet" if it's a strip), set **fps** and **loop** per clip.
3. `player.gd`:
   - `sprite_2d: Sprite2D` → `AnimatedSprite2D` (`flip_h` exists on both — line 89 unchanged).
   - Delete the `AnimationTree` dependency and drive playback from code:
     ```gdscript
     func _update_anim() -> void:
         if _is_hurt:                            animated_sprite.play("hurt")
         elif _is_attacking:                     pass          # controller owns it
         elif is_sprinting and not is_still:     animated_sprite.play("run")
         elif not is_still:                      animated_sprite.play("walk")
         else:                                   animated_sprite.play("idle")
     ```
   - `begin_attack(anim_name, anim_speed)` → `animated_sprite.speed_scale = anim_speed; animated_sprite.play(anim_name)`
   - `end_attack()` → `animated_sprite.speed_scale = 1.0` (and let `_update_anim()` resume)
   - Hurt flash: do it in code on a short `Timer` (exactly like `enemy.gd`'s `hit_flash_time`), instead of the `modulate` track.
4. `attack_controller.gd`:
   - line 161 → `player.animated_sprite.flip_h` (or expose `player.facing`).
   - `_attack_duration()` → read from `SpriteFrames`:
     ```gdscript
     var sf := player.animated_sprite.sprite_frames
     var count := sf.get_frame_count(attack.animation)
     var fps := sf.get_animation_speed(attack.animation)   # frames per second
     var base := (count / fps) if fps > 0.0 else 0.9
     return base / maxf(0.05, attack.speed_scale)
     ```
     *(Alternative, cleaner: add `@export var duration: float` to `AttackDefinition` and stop inferring it.)*
5. Optionally remove the `AnimationPlayer`/`AnimationTree` nodes entirely once nothing else uses them.

### Pros / cons
- ✅ One PNG per animation, any frame count, any cell size — exactly what you want.
- ✅ GUI drag-and-drop; no track bookkeeping.
- ✅ Standard Godot workflow; scales to 20+ clips.
- ❌ Needs the ~4 code edits above (small, contained).
- ❌ Loses the AnimationTree's expression-driven transitions (replaced by ~6 lines — arguably clearer).

### ⚠️ Can you use `AnimatedSprite2D` **and** keep the `AnimationTree`?
**No, not cleanly.** `AnimationTree` only drives an `AnimationPlayer` (it animates node *properties*). `AnimatedSprite2D` advances its own frames from `SpriteFrames`. Driving `AnimatedSprite2D:animation`/`frame` from an `AnimationPlayer` while it also self-advances makes the two fight over `frame`. So it's **Plan A or Plan B** — not both.

---

## 4. Comparison

| | Plan A (Sprite2D + tracks) | Plan B (AnimatedSprite2D) |
|---|---|---|
| Code changes | **none** | `player.gd` (~4 spots), `attack_controller.gd` (~2 spots) |
| Editor workflow | add 3 tracks per clip | drag PNG per animation |
| Per-clip frame count/size | must sync `hframes`/`vframes` | free |
| Keeps `AnimationTree` | yes | no (replaced by ~6 lines) |
| Hurt flash | `modulate` track | code (like enemy) |
| Risk | very low | low |
| Best when | few clips, want zero risk | many clips / hand-drawn art ← **your case** |

**Recommendation: Plan B.** You're redrawing 13+ clips at a new resolution; SpriteFrames is the natural home for that and removes the atlas-index bookkeeping.

---

## 5. New art export convention (works with either plan)

1. **One PNG per animation**, exported as a **single horizontal strip**: `width = frames × cell_width`, `height = cell_height`.
2. **Same cell size** for all frames of one clip (e.g. 512×512), transparent background, **feet centered horizontally**, character bottom-aligned.
3. **File name = clip name** (`punch_hook.png`). Godot/we can then wire it automatically.
4. Keep each strip **under ~8000 px** total width (GPU texture limit) — at 512 px that's ~15 frames.
5. Decide the **on-screen size** first (e.g. 96 or 128 px tall), then the source resolution is just a multiple of it; we scale the sprite and retune the hitboxes.

### ⚠️ The per-animation PNGs you already have are not clean strips
Verified by decoding them, e.g. `Idle-Sheet.png` is a **4×5 grid (20 cells)** whose contents equal **atlas row 1 re-wrapped 4-wide**; the 4 idle frames the game uses are only its **second row**. Same pattern for Walk/Run/Jump/Interact/Attack/Rotate (their width always equals that clip's frame count). So don't reuse them directly — **re-export each animation as a single strip** under the convention above.

---

## 6. Clips to produce (names must match exactly)

| # | Clip name | Used by | Target length | Frames | Notes |
|---|---|---|---|---|---|
| 1 | `idle` | tree/code | 0.70 s | 4–6 | loop |
| 2 | `walk` | tree/code | 0.70 s | 8 | loop |
| 3 | `run` | tree/code | 0.60 s | 6 | loop |
| 4 | `jump` | code | 0.80 s | 8 | optional (player can't jump yet — top-down) |
| 5 | `hurt` | tree/code | 0.40 s | 3–4 | + red flash (track or code) |
| 6 | `interact` | code | 0.60 s | 6 | optional |
| 7 | `punch_jab` | `jab` (H) | 0.64 s | 6 | contact ~16% |
| 8 | `punch_straight` | `straight` (H,H) | 0.75 s | 6 | contact ~16% |
| 9 | `punch_hook` | `hook` (H,H,H) | 0.90 s | 8 | contact ~16% |
| 10 | `punch_heavy` | `heavy` (J) | 1.29 s | 12 | contact ~17% |
| 11 | `kick_round` | `kick` (K) | 1.00 s | 8 | contact ~16% |
| 12 | `kick_front` | `kick_finisher` (H,H,K) | 1.00 s | 8 | launches |
| 13 | `kick_big` | `kick_finisher_big` (H,H,H,K) | 1.06 s | 10 | launches |

Later (need small code additions): `fall`, `land`, `dead`.

---

## 7. Migration checklist

*(Tick as done. Steps 0–2 are common; then follow either §2 or §3.)*

- [ ] **0.** Decide target on-screen character height; pick source cell size.
- [ ] **1.** Export the 13 clips as strips into `assets/player/<res>/`.
- [ ] **2.** Note each clip's frame count + fps.
- [ ] **3a (Plan A).** Add `texture`/`hframes`/`vframes` tracks + re-key `frame` per clip; update `RESET`.
- [ ] **3b (Plan B).** Build the `SpriteFrames`; swap node to `AnimatedSprite2D`; apply the code edits in §3.3–3.4.
- [ ] **4.** Point the 7 attack `.tres` `animation` fields at the new clip names; set `speed_scale = 1.0`.
- [ ] **5.** Retune `hitbox_offset`/`hitbox_size` for the new proportions.
- [ ] **6.** Verify with the checklist in §8.

---

## 8. How to verify

- Idle breathes; walk/run cycle; flip follows movement direction.
- `H` → `punch_jab`; `H,H` → `punch_straight`; `H,H,H` → `punch_hook`; `H,H,K` → `kick_front`; `H,H,H,K` → `kick_big`; `J` → `punch_heavy`; `K` → `kick_round`.
- Console `[COMBO]`/`[ENEMY]` lines still print (`COMBAT_SYSTEM_HANDOFF.md` §5).
- Combo damages unchanged: `H,H,K` = 18, `H,H,H,K` = 29.
- No runtime errors in the Output panel (an error parks the game in the debugger).
- Headless sanity: `flatpak run org.godotengine.Godot --headless --path <proj> res://tools/combo_smoke.tscn`.

---

## 9. Open decisions
1. **Plan A or Plan B?** (recommendation: B)
2. **Target on-screen height** for the character (drives source resolution + hitbox retune).
3. **Add `duration` to `AttackDefinition`?** (removes the "infer length from the animation" coupling — recommended with Plan B).
4. Keep `jump`/`interact` clips, or drop them (player is top-down, can't jump; `interact` is never played)?
5. Split `jump` into `jump`/`fall`/`land` later?
