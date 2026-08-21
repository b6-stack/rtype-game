class_name WeaponData
extends Resource
## WeaponData — data resource that defines a weapon's properties.
## Create .tres instances of this for each of the 10 weapon types.

@export var weapon_name: String = "Vulcan"
@export var weapon_index: int = 0

## Color used for placeholder bullet polygons
@export var bullet_color: Color = Color.CYAN

## Seconds between primary shots
@export var fire_rate: float = 0.15

## Projectile speed in pixels/sec
@export var bullet_speed: float = 800.0

## Damage per projectile
@export var damage: int = 10

## Charge duration to reach full charge (seconds)
@export var charge_time: float = 2.0

## Short description shown in HUD tooltip
@export_multiline var description: String = ""
