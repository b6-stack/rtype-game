class_name BossData
extends Resource
## BossData — data resource defining a boss encounter.

@export var boss_name: String = "Iron Claw"
@export var boss_index: int = 0

## Placeholder polygon color
@export var color: Color = Color.DARK_RED

## Total hit points across all phases
@export var max_health: int = 1000

## Number of phases (health thresholds divide evenly)
@export var phase_count: int = 2

## Score awarded on defeat
@export var score_value: int = 5000

## Size scale (1.0 = base 160×120)
@export var size_scale: float = 1.0

## Speed during entry slide-in
@export var entry_speed: float = 120.0

## Short flavor text
@export_multiline var description: String = ""
