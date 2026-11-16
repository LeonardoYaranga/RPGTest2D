class_name AttackDefinition
extends Resource
## Data for a single 2.5D/3D attack (a "move") that can be part of a combo.
## Create one .tres per move and reference it from AttackController3D.

enum HitReaction {
	HITSTUN,   ## Normal grounded flinch with short slide, stays standing.
	STAGGER,   ## Heavy flinch with longer pause/stumble, still grounded.
	KNOCKDOWN, ## Drops enemy directly to the floor (KnockdownState) with low/no vertical height.
	LAUNCH,    ## Launches enemy high into the air for airborne juggle (LaunchedState).
}

@export var id: StringName = &"jab"
## Animation played on AnimatedSprite3D for this move.
@export var animation: StringName = &"attack"
## Playback speed multiplier for this move.
@export var speed_scale: float = 1.0
## Optional duration override in seconds (<= 0 infers from SpriteFrames).
@export var duration: float = 0.0

@export_group("Damage")
@export var damage: int = 4
## Freeze frames applied to attacker + target on connect (seconds).
@export var hitstop: float = 0.04

@export_group("Hitbox")
## Time (seconds) before the 3D hitbox becomes active.
@export var hit_delay: float = 0.10
## How long the hitbox stays active.
@export var hit_window: float = 0.08
## 3D offset from the attacker (x is mirrored by facing).
@export var hitbox_offset: Vector3 = Vector3(0.85, 0.75, 0.0)
## Full size of the BoxShape3D (keep Z generous so brawler combos connect cleanly).
@export var hitbox_size: Vector3 = Vector3(1.15, 1.35, 1.15)

@export_group("Reaction")
## Reaction type triggered on the receiver.
@export var reaction_type: HitReaction = HitReaction.HITSTUN
## Ground hitstun duration (seconds) when launch == 0.
@export var hitstun: float = 0.20
## Push applied in 3D (x away from attacker, z depth).
@export var knockback: Vector3 = Vector3(2.8, 0.0, 0.0)
## > 0 launches the target airborne (+Y velocity), triggering Launched -> Knockdown -> GetUp.
@export var launch: float = 0.0
## If true, can hit targets lying on the ground (OTG).
@export var can_hit_knockdown: bool = false

@export_group("Combo")
## From this time on, the next input can cancel recovery into the next hit.
@export var cancel_time: float = 0.14
## Extra time after the move ends during which input still chains. Set 0 on finishers.
@export var combo_window: float = 0.35
## Forward lunge speed along facing at the start of the move (m/s).
@export var lunge: float = 1.6
@export var stamina_cost: float = 0.0
