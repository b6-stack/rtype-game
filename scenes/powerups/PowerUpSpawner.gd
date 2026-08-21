class_name PowerUpSpawner
extends Node
## PowerUpSpawner — instantiates weapon, life, and shield pickups on enemy/boss kills.

const PowerUpScene: PackedScene = preload("res://scenes/powerups/PowerUp.tscn")

## Injected by Game.gd
var powerup_parent: Node = null
var scroll_speed: float = 180.0

func _on_powerup_spawn_requested(pos: Vector2, weapon_index: int) -> void:
	spawn_powerup_at(pos, weapon_index, "weapon")

func spawn_powerup_at(pos: Vector2, weapon_index: int = -1, p_type: String = "weapon") -> void:
	if powerup_parent == null:
		return
	if p_type == "weapon" and weapon_index < 0:
		weapon_index = randi_range(0, 9)
	var pu: PowerUp = PowerUpScene.instantiate()
	powerup_parent.call_deferred("add_child", pu)
	pu.global_position = pos
	pu.setup(weapon_index, scroll_speed, p_type)
