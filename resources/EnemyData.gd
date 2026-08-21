class_name EnemyData
extends Resource
## EnemyData — data resource that defines an enemy's stats and behaviour class.

@export var enemy_name: String = "Grunt"
@export var enemy_type_id: int = 0

## Script path for the GDScript that implements movement/shooting
@export_file("*.gd") var script_path: String = ""

## Placeholder polygon color
@export var color: Color = Color.RED

## Hit points
@export var max_health: int = 20

## Score awarded on death
@export var score_value: int = 100

## Pixels per second base movement speed
@export var move_speed: float = 180.0

## Seconds between shots (0 = never shoots)
@export var shoot_cooldown: float = 2.0

## Bullet color
@export var bullet_color: Color = Color.ORANGE_RED

## Bullet speed
@export var bullet_speed: float = 400.0

## Bullet damage dealt to player
@export var bullet_damage: int = 1

## Size scale for the placeholder polygon (1.0 = base 40×30 enemy)
@export var size_scale: float = 1.0
