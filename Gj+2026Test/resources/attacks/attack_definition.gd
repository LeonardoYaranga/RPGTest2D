class_name AttackDefinition
extends Resource
## Data for a single attack (a "move") that can be part of a combo.
## Create one .tres per move and reference it from AttackController.

@export var id: StringName = &"jab"
## AnimationPlayer animation played for this move.
## The AnimationTree is paused while attacking, so this bypasses the state machine.
@export var animation: StringName = &"attack"
## Playback speed multiplier for this move.
@export var speed_scale: float = 1.0

@export_group("Damage")
@export var damage: int = 4
## Freeze frames on connect (reserved for polish).
@export var hitstop: float = 0.0

@export_group("Hitbox")
## Time (seconds) before the hitbox becomes active.
@export var hit_delay: float = 0.10
## How long the hitbox stays active.
@export var hit_window: float = 0.08
## Offset of the hitbox from the player (x is mirrored by facing).
@export var hitbox_offset: Vector2 = Vector2(14, -10)
@export var hitbox_size: Vector2 = Vector2(24, 24)

@export_group("Reaction")
## The target cannot act for this long.
@export var hitstun: float = 0.18
## Horizontal push applied to the target.
@export var knockback: Vector2 = Vector2(60, 0)
## > 0 launches the target airborne (used by finishers, phase 3+).
@export var launch: float = 0.0

@export_group("Combo")
## From this time on, the next input can cancel the recovery.
@export var cancel_time: float = 0.14
## Extra time after the move ends during which input still chains.
## Set to 0 on finishers to end the combo.
@export var combo_window: float = 0.35
## Small forward step at the start of the move.
@export var lunge: float = 30.0
@export var stamina_cost: float = 0.0
