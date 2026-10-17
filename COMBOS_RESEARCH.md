# Combos — Research & Design Bible

> **Purpose:** a deep, self-contained reference on **how action-game combos work** and **how to build them**, so you (or any other agent) can design, tune and extend the `Gj+2026Test` H/J/K combo system without re-doing the research.
>
> **Companion doc:** `COMBAT_SYSTEM_HANDOFF.md` (what's implemented in this project, file map, debug prints, current values).
> **Last updated:** 2026-10-15
>
> **How to use this:** Part 1–4 are theory (what makes a combo *feel* good). Part 5 is implementation patterns. Part 6 is the annotated source index (every link + what it's good for). Part 7 is a glossary. Everything a design decision needs is cross-referenced to the parameter names used in this project (`cancel_time`, `combo_window`, `hitstun`, `hitstop`, `launch`, …).

---

## Part 0 — TL;DR (the 10 things that matter)

1. Every attack has three phases: **Startup → Active → Recovery**. A combo exists when the *next* attack can land before the enemy recovers.
2. **Hitstun** is the enemy's "I can't act" timer after being hit. If your next hit lands *before* hitstun ends, it's a **true combo**; if the enemy can act in between, it's a **link** ("1-frame link") or just pressure.
3. **Canceling** is the trick that makes combos fast: during the recovery of attack A you're allowed to start attack B, skipping A's remaining recovery. *(Our `cancel_time`.)*
4. **Frame advantage** = (hitstun you inflict) − (your own recovery). Positive/no recovery = you can act first = combos.
5. **Input buffer** = a short memory of recent button presses so a press during an attack isn't lost; it fires the moment it's allowed. *(Our `_pending` + `_buffer`.)*
6. **Combo window** is the *leniency* timer: how long after an attack a press still counts as "continue the chain" instead of "start over." *(Our `combo_window`.)*
7. **Hitstop / hitfreeze** = a tiny pause on impact (usually 2–12 frames). It sells weight and it *also* changes timings.
8. **Pushback / knockback** moves the enemy away; too much kills combos, some is needed for readability.
9. Two big combo schools: **dial-a-combo** (press the sequence; the game chains for you, fast) vs **link/timing combos** (you must time each hit). Most beat 'em ups use **dial + a small buffer**.
10. **Design order:** decide the *feel* (fast mashy vs heavy precise) → pick `cancel_time`/`combo_window` → only then tune `damage`/`knockback`/`launch`.

---

## Part 1 — The anatomy of a combo

### 1.1 The attack timeline
Every melee attack is a timeline:

```
 |<--- startup --->|<-- active -->|<-------- recovery -------->|
 frame 0          hit_delay    +hit_window                   end
```

- **Startup** — from the button press to the first frame the hitbox exists. In this project: `hit_delay`.
- **Active** — frames where the hitbox can connect. In this project: `hit_window`.
- **Recovery** — from hitbox switching off to being able to act again. In this project: everything after `hit_delay + hit_window` up to the end of the animation (scaled by `speed_scale`).

> CritPoints defines these precisely: *"Startup: the period up to the first hitbox appearing. Active: the period across which a hitbox is present. Recovery: the period after the hitbox is gone but the move hasn't ended."* ([Frame Data Patterns](https://critpoints.net/2023/02/20/frame-data-patterns-that-game-designers-should-know/))

### 1.2 Hitstun, blockstun, frame advantage
- **Hitstun** — how long the *victim* is stunned after being hit (can't act). *(Our `hitstun`, in seconds.)*
- **Blockstun** — same, but when they blocked.
- **Frame advantage** = `my hitstun` − `my recovery` (roughly). If advantage ≥ 0, you recover at the same time or earlier → you can hit again → combo/pressure.

CritPoints, *Hitstun in Depth*: the biggest thing hitstun does is **let one character's attacks interrupt/carry into the next**. Factors listed: *"interrupting attacks, advantage time, pushback… knockdown, juggles, counter hits, meaties & multihits, special hitstun states, dizzy, recovery options, control during hitstun, hitfreeze, super armor, no hitstun, blockstun."* ([source](https://critpoints.net/2016/08/14/stunning-detail))

**Rule of thumb:** more hitstun → easier to combo (more forgiving), but can make the game feel "sticky"/loop-y if overdone.

### 1.3 Linking vs canceling (the two ways to continue)
- **Link** — you wait for attack A to *fully* finish, then attack B is fast enough that it connects during the enemy's remaining hitstun. Hard, timing-precise.
- **Cancel** — attack B **interrupts** A's recovery. Easy, fast, expressive. This is the backbone of combo games and of this project.

CritPoints on how combos are actually *discovered/built*: you don't memorize spreadsheets, you reason from **frame advantage** and **cancel windows** ([Framedata: Combos, Traps, and Turns](https://critpoints.net/2016/11/29/understanding-framedata-combos-traps-and-turns)).

### 1.4 Hitstop / hitfreeze (hitlag)
A short pause (a few frames) applied to **both** attacker and victim on impact. Purposes (from *Hitstop in Capcom Beat 'Em Ups*): **emphasize the impact**, add weight, and give the player a beat to read/react. It also affects frame advantage and can enable extra juggles ([source](https://shane-sicienski.com/blog/blog-post-title-one-55pmn)).

In this project `hitstop` exists in the `.tres` schema but is currently **0** — a prime candidate to add later for juice.

### 1.5 Pushback / knockback
On hit, both characters often separate a bit. Pushback:
- makes hits readable,
- prevents infinite "corner" loops,
- but **too much kills combos** (enemy drifts out of range).

In this project: `knockback` (horizontal) and `launch` (upward, for finishers).

### 1.6 Knockdown, launch, juggles
- **Launch** — hit sends the enemy airborne.
- **Knockdown** — hit puts the enemy on the floor for a while (they can't act).
- **Juggle** — hitting an airborne enemy; usually limited by a "juggle counter" to stop infinites.
- **Getup / wakeup** — the recovery after knockdown; a classic moment for "meaty" attacks (timing a hit to land exactly as they stand).

These are **Phase 3** in this project (not yet implemented).

### 1.7 Frame traps & counter hits
- **Frame trap**: a gap small enough that the enemy *thinks* they can act but if they press a button they get counter-hit. Emerges naturally from small frame advantages.
- **Counter hit**: hitting someone during *their* startup → often extra hitstun → opens new combos.

### 1.8 Auto combos & "magic series"
- **Auto combo**: a whole string bound to **one button** (e.g. Dragon Ball FighterZ, BlazBlue). Pressing the same button chains the sequence. Easier for beginners, sometimes lower damage.
- **Magic series / chain rules**: general rules like "light can cancel into medium can cancel into heavy," "normal → special → super."

CritPoints, *What's the Deal with Auto Combos?* — auto combos are *a string attached to a single button*; the trade-off is accessibility vs. depth/agency ([source](https://critpoints.net/2023/05/04/whats-the-deal-with-auto-combos/)).

> **Relevant to your feedback:** pressing the same button and getting a chain is *literally* an auto combo. If you want same-button mashing to chain **fast**, you want a faster `cancel_time` (or a dedicated auto-combo rule), not just bigger damage.

---

## Part 2 — Input buffering (the core tech)

### 2.1 Why buffers exist
Humans press slightly early or late relative to animation windows; raw input tested "every frame vs. exactly on a window" feels broken. A buffer **remembers recent presses** and **consumes** them when allowed. From the Wayline Unity article: *"Do crucial attacks whiff because the engine missed your key press amidst the chaos? … A well-implemented input buffer [fixes] input responsiveness."* ([source](https://www.wayline.io/blog/unity-combat-input-buffer)).

### 2.2 Buffer window sizing
Common buffer sizes:
- **~5–10 frames (≈ 80–160 ms @60fps)** for "don't lose my input" leniency.
- **longer (up to the whole recovery)** for "queue the next hit" feel.

From r/gamedev: a 40-frame buffer means a motion (d, df, f + punch) can be spread over 40 frames ([source](https://www.reddit.com/r/gamedev/comments/1iw22v/buffered_input_like_that_found_in_fighting_games)). **Too long** and the game feels like it's playing itself (see the *No Rest for the Wicked* complaint about buffering feeling unresponsive in dynamic situations — [source](https://forum.norestforthewicked.com/t/input-buffering-combat-queueing-feels-too-unresponsive-in-dynamic-situations/16313)).

### 2.3 The two buffers in this project
| Buffer | Meaning | Cleared when |
|---|---|---|
| `_buffer` | **Confirmed sequence** (`"H"`, `"HH"`, …) | combo window expires, or an invalid continuation resets it |
| `_pending` | The key pressed **while attacking** | consumed at `cancel_time`, or dropped at end of move |

This is a **sequence buffer** (for combos) *plus* a **pending/queue slot** (for chaining). That's the standard pattern.

### 2.4 Ring-buffer implementation (generic pattern)
For directional/multi-input combos later (e.g. `→ K, H, H, ↓ K`), you typically keep a **ring buffer** of the last N `(token, timestamp)` and scan it for the pattern within a time window:

```
buffer: fixed array of N entries {token, time}
on input: push {token, now}
on attack check: scan newest→oldest for pattern tokens within window; if found, consume
```

A Godot 4 addon that implements exactly this: **Input Buffer Combo System** ([Asset Library](https://godotassetlibrary.com/asset/vbMUT9/input-buffer-combo-system)). A community thread on where to start: [Godot forum](https://forum.godotengine.org/t/where-to-start-when-making-an-input-buffer-system/141330).

### 2.5 Design rules for buffers
- Store **timestamped** inputs, not just a count, so you can enforce windows.
- **Consume** a buffered input when used (don't let one press trigger forever).
- Clear stale inputs (age > window) every frame.
- Decide per-context: dashing/jumping may use a shorter buffer than attacks.
- **Never** buffer something the player would hate (e.g. an accidental extra attack after a whiff — see Part 4).

---

## Part 3 — Cancel windows & dial-a-combo

### 3.1 Early cancel vs. wait-for-recovery
The beat-'em-up devlog *Making Chain Combos* frames the core choice: *"do you allow cancelling of the attack into the next attack of the chain, or do you play out the recovery animation of each hit and use an input buffer to start the next attack once the previous one is over?"* — and notes different games do it differently (some have recovery, some instantly cancel on the next press) ([source](https://www.youtube.com/watch?v=aFIs2V5eqOg)).

- **Early cancel** (our model): from `cancel_time` onward, the next press interrupts recovery → **snappy, mashy, forgiving**. Risk: feels like mashing if over-tuned.
- **Wait + buffer**: the full recovery plays; the buffered input fires at the end → **heavier, deliberate**. Risk: "slow" feeling — which is exactly what you reported.

### 3.2 Dial-a-combo
In a **dial-a-combo**, you input the whole string at any speed (even before the previous hits land) and the game performs the chain. Very common in beat 'em ups (e.g. Arkham-style) and in this project's design (press `H`, `H`, `H`, `K`).

### 3.3 Combo window ("leniency")
After an attack ends, there is a short window where the next press is still treated as a continuation. This is what separates "combo" from "new attack":

- Press **inside** `combo_window` → continue the chain.
- Press **after** `combo_window` → start over (fresh basic).

Tuning this is the single biggest knob for **"fast combo vs. slow single hits."**

### 3.4 The three ways to author combo strings
1. **Flat table** (what we do): `dict<string, Attack>`. Simple, readable, data-driven.
2. **Graph / tree**: each node knows its valid next inputs. Good for branching (direction + button).
3. **State-machine + rules**: e.g. "light→medium→heavy" magic series; less explicit data.

For direction-aware combos later (your `Right K,H,H,Down K`), a **graph** or a **token+modifier buffer** (store `{dir, token}`) scales better than a flat string. The flat string can encode direction as `"RKHH"` etc.

---

## Part 4 — Designing combo *feel* (and mapping it to this project)

### 4.1 The feel spectrum
```
MASHY / FAST  <-------------------------------->  HEAVY / PRECISE
 fighters, auto-combos        beat 'em ups          souls-like, MH
 short cancel_time            medium                 long windows, links
 big hitstun                  medium                 small hitstun
 lots of canceling            dial+buffer            committed animations
```

### 4.2 Parameter → feeling map (this project)
| Want this feeling | Change this | In |
|---|---|---|
| Mashing chains faster | ↓ `cancel_time` | `resources/attacks/*.tres` |
| More forgiving combos | ↑ `combo_window` | `.tres` |
| Chains harder to keep | ↓ `combo_window` | `.tres` |
| Enemies can act sooner (less "stun-lock") | ↓ `hitstun` | `.tres` |
| Hits feel heavier | ↑ `hitstop` (currently 0) + ↑ `hitstun` | `.tres` |
| Finishers launch | ↑ `launch` + implement Phase 3 | `.tres` + `enemy.gd` |
| More reach | ↑ `hitbox_size` / `hitbox_offset` | `.tres` |
| Player steps in more | ↑ `lunge` | `.tres` |
| Enemies pushed out of combos | ↓ `knockback` | `.tres` |

### 4.3 Specific to your reported issues
- **"Attacks do damage no matter what; late presses still hit."** Each press *starts a new move*; per-move `_hit_targets` stops a *single swing* hitting twice. That's correct combo behavior. If you want a press during recovery to do *nothing* until the move ends, raise `cancel_time` toward the recovery end (or remove canceling).
- **"Same button doesn't attack immediately — slow."** That's `cancel_time` gating. Options:
  1. **Lower `cancel_time`** (snappier, universal).
  2. **Auto-combo rule**: same token in a row cancels instantly (a la DBFZ) — new code branch.
  3. **Dedicated rapid-jab**: add `"HHHH" → rapid jab` to the table.
- **"Attacks repeat the animation."** All moves reuse `attack` with different `speed_scale` (decision D1a). Real fix = distinct animations per move (Phase 6).

### 4.4 Anti-frustration rules to consider
- Don't buffer a **whiffed** attack (you swing at air, then it fires a second unwanted swing).
- Cap juggles (a "juggle counter") so launch combos can't loop forever.
- Keep finishers **committal** (long recovery, low/no cancel) so they read as enders.
- Give the player a **visible cue** (screen combo counter) — console prints are dev-only.

---

## Part 5 — Implementation patterns (Godot 4)

### 5.1 Architecture we use
- **`AttackDefinition` (Resource)** — data: damage, timings, knockback, hitbox, window, etc. One `.tres` per move. → data-driven, designer-editable.
- **`AttackController` (Node)** — owns the buffer, the combo table, the timer, and the runtime `AttackHitbox`.
- **`player.gd`** — exposes `begin_attack()/end_attack()/apply_attack_lunge()` and blocks movement while attacking.
- **`enemy.gd`** — `take_hit(attack, source_pos)`, hitstun/reaction, health.

### 5.2 Per-frame attack loop (simplified)
```gdscript
func _physics_process(delta):
    if _is_attacking:
        _elapsed += delta
        # active window: check hitbox
        if _elapsed >= _current.hit_delay and _elapsed <= _current.hit_delay + _current.hit_window:
            _check_hits()
        # cancel: consume the pending input once we reach cancel_time
        if _elapsed >= _current.cancel_time and _pending != "":
            var t = _pending; _pending = ""
            _advance(t)
            return
        if _elapsed >= _end_time:
            _finish()
```

### 5.3 Detecting the sequence
```gdscript
var candidate = _buffer + token
if COMBO_TABLE.has(candidate):
    _buffer = candidate
    _play(COMBO_TABLE[candidate])
else:
    _buffer = token          # restart chain
    _play(COMBO_TABLE.get(token, JAB))
```

### 5.4 Common pitfalls
- **Input eaten during animation** → always store into `_pending`, never `if not attacking: read input`.
- **Combo never resets** → use a `Timer` for `combo_window`; clear `_buffer` on timeout.
- **Double hits** → keep a per-swing `_hit_targets` set.
- **Hitbox in the wrong place** → parent it to the player and flip the X offset by `flip_h`; set `monitoring` only during the active window (or just check overlaps only then).
- **Animation vs. code fighting** → disable the `AnimationTree` during attacks (we do) or add an `attack` state to the state machine.
- **Physics pushing the dummy** → only `move_and_slide()` when you actually have knockback (the fix applied here).

### 5.5 Where to add Phase 3 (launch/knockdown/getup)
A small enemy state machine:
```
IDLE/Fighter -> HURT -> (if launch>threshold) LAUNCHED -> KNOCKDOWN -> GETUP -> back
                                   (apply gravity)      (timer)     (invuln?)
```
Add `velocity.y` gravity and a floor check; while `LAUNCHED`, allow "juggle" hits.

---

## Part 6 — Annotated source index

> Grouped by usefulness. **Read first:** ⭐⭐⭐.

### ⭐⭐⭐ Core theory (fighting-game / gremlin math, most transferable)
1. **Frame Data Patterns that ALL Game Designers Should Know — Celia Wagar (CritPoints)**
   <https://critpoints.net/2023/02/20/frame-data-patterns-that-game-designers-should-know/>
   *Defines **Startup / Active / Recovery / Hitstun**, frame advantage/disadvantage, combo, unsafe, frame trap, pushback. The clearest single explanation of why combos work and why attacks are "safe" or not. Start here.*
2. **Stunning Detail: Hitstun in Depth — Celia Wagar (CritPoints)**
   <https://critpoints.net/2016/08/14/stunning-detail>
   *Everything hitstun touches: interrupting attacks, advantage time, pushback, knockdown, juggles, counter hits, multihits, dizzy, recovery, hitfreeze, super armor, blockstun. Explains why hitstun is THE enabler of combos.*
3. **Understanding Framedata: Combos, Traps, and Turns — Celia Wagar (CritPoints)**
   <https://critpoints.net/2016/11/29/understanding-framedata-combos-traps-and-turns>
   *How combos are actually built/discovered from frame advantage, without memorizing spreadsheets. Practical mental model for designing chains.*
4. **Hitstop in Capcom Beat 'Em Ups — Shane Sicienski**
   <https://shane-sicienski.com/blog/blog-post-title-one-55pmn>
   *What hitstop/hitfreeze is, why Capcom beat 'em ups use it, and its side effects on timing. Directly relevant (top-down beat 'em up) and currently unused in this project (`hitstop = 0`).*
5. **What's the Deal with Auto Combos? — Celia Wagar (CritPoints)**
   <https://critpoints.net/2023/05/04/whats-the-deal-with-auto-combos/>
   *Pros/cons of binding a whole string to one button. Directly answers your "press the same button and it chains" question — that IS an auto combo, with real design trade-offs.*
6. **The Fighting Game Glossary — infil.net**
   <https://glossary.infil.net>
   *Authoritative drop-down glossary for every term (hitstun, hitstop, cancel, juggle, meaty, okizeme…). Use it whenever a term is unclear.*

### ⭐⭐ Input buffering & implementation
7. **Level Up Your Unity Combat with Input Buffers — Wayline**
   <https://www.wayline.io/blog/unity-combat-input-buffer>
   *Why buffers fix "dropped" inputs; sizing and responsibilities. Unity code, but the architecture maps 1:1 to Godot (the concepts are engine-agnostic).*
8. **Input Buffer Combo System — Godot Asset Library**
   <https://godotassetlibrary.com/asset/vbMUT9/input-buffer-combo-system>
   *A ready-made Godot 4 addon doing ring-buffer + combo detection. Great as a reference implementation (or to borrow from) instead of writing from scratch.*
9. **Where to start when making an input buffer system? — Godot Forum**
   <https://forum.godotengine.org/t/where-to-start-when-making-an-input-buffer-system/141330>
   *Community patterns: ring buffer, timestamps, clearing stale inputs, cancel handling.*
10. **Fighting Game and input buffering — GameDev StackExchange**
    <https://gamedev.stackexchange.com/questions/43708/fighting-game-and-input-buffering>
    *StackExchange Q&A on buffering clean/dirty input and how long to hold it. (Site blocks scrapers; read in a browser.)*
11. **Buffered Input (like that found in fighting games) — r/gamedev**
    <https://www.reddit.com/r/gamedev/comments/1iw22v/buffered_input_like_that_found_in_fighting_games>
    *Discussion of buffer-window sizing and spreading motions (e.g. quarter-circle) across frames.*
12. **Input buffering (combat queueing) feels too unresponsive — No Rest For The Wicked forum**
    <https://forum.norestforthewicked.com/t/input-buffering-combat-queueing-feels-too-unresponsive-in-dynamic-situations/16313>
    *The counter-argument: when a buffer is too long/large, the game feels like it ignores you. Read before over-buffering.*

### ⭐⭐ Beat 'em up combo design (video; closest genre)
13. **Making CHAIN COMBOS for my 2D Beat 'em up — Devlog (YouTube)**
    <https://www.youtube.com/watch?v=aFIs2V5eqOg>
    *Explicitly compares "cancel the attack into the next" vs "play the recovery + input buffer," and shows startup/active/recovery frame authoring. The most on-point video for this exact project.*
14. **FREE Godot 4 Combo System Addon (Input Buffering + Combos) — YouTube**
    <https://www.youtube.com/watch?v=K9B2ghYxla8>
    *Step-by-step Godot 4 combo + buffering walkthrough (is-attacking flag, combo execute, end-of-animation reset).*
15. **Juicing up your game attacks — GDQuest**
    <https://www.gdquest.com/library/juicy_attack>
    *Polish: hitstop, screenshake, VFX, timing — how to make hits *feel* impactful once the logic works.*

### ⭐ Motion inputs (for the directional combos you mentioned later)
16. **How to Code Fighting Game Motion Inputs — Celia Wagar (CritPoints)** *(search the CritPoints archive: "motion inputs")*
    <https://critpoints.net/archive/>
    *How to detect `→ ↓ ↘ + button` style motions from a timestamped input buffer. Directly relevant to `Right K,H,H,Down K`.*
17. **Fighting Game input system — GameDev.net forum**
    <https://gamedev.net/forums/topic/573120-fighting-game-input-system>
    *Older but concrete: buffering input as it comes and scanning the buffer for patterns; canceling normal → special.*

---

## Part 7 — Glossary

| Term | Meaning |
|---|---|
| **Startup** | Frames before the hitbox appears. (`hit_delay`) |
| **Active** | Frames the hitbox is live. (`hit_window`) |
| **Recovery** | Frames after the hitbox until you can act again. |
| **Hitstun** | Victim's "can't act" time after being hit. (`hitstun`) |
| **Blockstun** | Same, after blocking. |
| **Hitstop / hitfreeze** | Micro-pause on both characters on impact. (`hitstop`, currently 0) |
| **Frame advantage** | `hitstun inflicted − own recovery`; ≥0 means you act first. |
| **Link** | Continue by waiting for the move to end; timing-tight. |
| **Cancel** | Interrupt recovery to start the next move. (`cancel_time`) |
| **Combo window** | Leniency after an attack for the next press to count as a chain. (`combo_window`) |
| **Dial-a-combo** | Input the whole string; the game chains it. |
| **Auto combo** | A whole string on one button. |
| **Magic series** | Rule-based chains, e.g. light→medium→heavy. |
| **Buffér** | Short memory of recent inputs so presses aren't lost. |
| **Pushback / knockback** | Separation applied on hit. (`knockback`) |
| **Launch** | Send the enemy airborne. (`launch`) |
| **Knockdown / getup** | Enemy on the floor / standing back up. |
| **Juggle** | Hitting an airborne enemy (usually capped). |
| **Frame trap** | A small gap that punishes the opponent for pressing a button. |
| **Counter hit** | Hitting the opponent during their startup; often extra hitstun. |
| **Meaty** | Timing a hit to land exactly as the opponent gets up. |
| **Whiff** | An attack that misses. |

---

## Part 8 — Suggested reading order

1. **Frame Data Patterns** (CritPoints) — learn startup/active/recovery/hitstun.
2. **Hitstun in Depth** (CritPoints) — understand why combos connect.
3. **Making CHAIN COMBOS (devlog)** — see the two cancel philosophies in a beat 'em up.
4. **Input Buffers** (Wayline) + **Godot addon** — implement the buffer.
5. **Hitstop in Capcom Beat 'Em Ups** — add juice (and consider `hitstop > 0`).
6. **Auto Combos** (CritPoints) — decide whether to lean into same-button chains.
7. **Motion inputs** (CritPoints archive) — when you add directional combos.

---

## Part 9 — Open questions for this project (to answer with you)

- **Feel target:** do you want mashy/fast (lower `cancel_time`, maybe same-button auto-combo) or heavy/precise (higher `cancel_time`, links)?
- **Same-button chains:** keep dial-a-combo (`H→HH→HHH`), or add an instant same-button cancel?
- **Finishers:** launch (needs Phase 3) or stay as strong pushback?
- **Hitstop:** add `hitstop` for weight, or keep it clean?
- **Whiff buffering:** should a whiffed attack swallow the next buffered press?
- **Combo counter UI:** on-screen number in addition to console prints?
