class_name PowerUpSpawner
extends Node
## PowerUpSpawner — instantiates weapon, life, and shield pickups on enemy/boss kills.
## Ensures rich weapon variety and strictly excludes the currently equipped weapon.

const PowerUpScene: PackedScene = preload("res://scenes/powerups/PowerUp.tscn")

## Injected by Game.gd
var powerup_parent: Node = null
var scroll_speed: float = 180.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_spawned_weapon: int = -1

func _ready() -> void:
	_rng.randomize()

## Selects a random weapon index (0..9) with guaranteed exclusion of the
## player's currently equipped weapon, plus avoidance of consecutive duplicates.
func get_random_weapon_index(exclude_current: bool = true) -> int:
	var current_idx: int = GameState.current_weapon_index if exclude_current else -1
	var available_weapons: Array[int] = []

	for i in range(10):
		if i != current_idx:
			available_weapons.append(i)

	# If more than 1 option and we have a previous drop, try to pick a different one
	if available_weapons.size() > 1 and _last_spawned_weapon in available_weapons:
		var non_repeat: Array[int] = []
		for w in available_weapons:
			if w != _last_spawned_weapon:
				non_repeat.append(w)
		if non_repeat.size() > 0:
			available_weapons = non_repeat

	var chosen: int = available_weapons[_rng.randi_range(0, available_weapons.size() - 1)]
	_last_spawned_weapon = chosen
	return chosen

func _on_powerup_spawn_requested(pos: Vector2, weapon_index: int) -> void:
	spawn_powerup_at(pos, weapon_index, "weapon")

func spawn_powerup_at(pos: Vector2, weapon_index: int = -1, p_type: String = "weapon") -> void:
	if powerup_parent == null:
		return

	if p_type == "weapon":
		# If no specific weapon requested or requested weapon matches current equipped, roll random non-equipped weapon
		if weapon_index < 0 or weapon_index == GameState.current_weapon_index or weapon_index >= 10:
			weapon_index = get_random_weapon_index(true)

	_do_spawn_powerup.call_deferred(pos, weapon_index, p_type)

func _do_spawn_powerup(pos: Vector2, weapon_index: int, p_type: String) -> void:
	if powerup_parent == null:
		return
	var pu: PowerUp = PowerUpScene.instantiate()
	powerup_parent.add_child(pu)
	pu.global_position = pos
	pu.setup(weapon_index, scroll_speed, p_type)
