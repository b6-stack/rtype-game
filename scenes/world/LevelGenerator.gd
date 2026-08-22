class_name LevelGenerator
extends Node
## LevelGenerator — procedurally generates and streams terrain chunks.
## Uses a seeded RNG per level for reproducible layouts.
## Guarantees a clear corridor (min 220px) through every chunk.
## Connects chunk spawn signals to EnemySpawner and PowerUpSpawner.

signal boss_trigger_reached(level: int)

const ChunkScene: PackedScene = preload("res://scenes/world/Chunk.tscn")

const CHUNK_WIDTH: float = 640.0
const SCREEN_HEIGHT: float = 1080.0
const MIN_CORRIDOR: float = 220.0
const MAX_WALL_THICKNESS: float = 360.0
const LOOK_AHEAD_CHUNKS: int = 4    # how many chunks ahead to keep ready

## Difficulty scaling per level above 1 (level 1 = baseline density).
const DENSITY_BONUS_PER_LEVEL: float = 0.4  # extra enemies per chunk per level
const SPAWN_CHANCE_PER_LEVEL: float = 0.025 # extra spawn-roll chance per level
const DENSITY_MULTIPLIER: int = 2           # overall density multiplier (2x enemy count per chunk)
const MAX_ENEMIES_PER_CHUNK: int = 10        # segment_w = CHUNK_WIDTH / count must stay >= 60 for spawn spacing math
const MAX_SPAWN_CHANCE: float = 0.95

# Corridor state (Y values of corridor edges)
var _corridor_top: float = 200.0
var _corridor_bottom: float = 880.0

## Injected by Game.gd
var chunk_parent: Node2D = null
var enemy_spawner: Node = null
var powerup_spawner: Node = null

var scroll_speed: float = 180.0
var _base_scroll_speed: float = 180.0
var _rng: RandomNumberGenerator
var _chunk_index: int = 0
var _chunks_until_boss: int = 20
var _boss_chunk_interval: int = 20
var _next_chunk_x: float = 1920.0

## Level color themes [top wall color, bottom wall color]
const LEVEL_COLORS: Array[Color] = [
	Color(0.12, 0.22, 0.38),  # Level 1 - Blue cave
	Color(0.22, 0.12, 0.12),  # Level 2 - Red cavern
	Color(0.10, 0.28, 0.18),  # Level 3 - Green base
	Color(0.28, 0.20, 0.08),  # Level 4 - Brown fortress
	Color(0.18, 0.10, 0.30),  # Level 5 - Purple alien
	Color(0.08, 0.25, 0.28),  # Level 6 - Teal station
	Color(0.30, 0.08, 0.20),  # Level 7 - Crimson core
	Color(0.25, 0.22, 0.05),  # Level 8 - Gold final
	Color(0.20, 0.05, 0.35),  # Level 9 - Cosmic Void
	Color(0.35, 0.15, 0.05),  # Level 10 - Solar Core
]

func _ready() -> void:
	_rng = RandomNumberGenerator.new()

## Boss Rush: trigger the boss almost immediately (still leaves the base
## 3-chunk spawn grace period so it doesn't feel like an ambush) instead of
## the usual ~20-chunk regular-wave build-up between bosses.
const BOSS_RUSH_CHUNKS_UNTIL_BOSS: int = 4

func initialize(level: int, speed: float) -> void:
	scroll_speed = speed
	_base_scroll_speed = speed
	_chunk_index = 0
	_chunks_until_boss = BOSS_RUSH_CHUNKS_UNTIL_BOSS if GameState.boss_rush_mode else _boss_chunk_interval
	_rng.seed = level * 12345 + 1
	_corridor_top = 180.0
	_corridor_bottom = 900.0
	var spawn_x: float = 0.0
	for i in LOOK_AHEAD_CHUNKS + 1:
		_spawn_next_chunk_at(spawn_x)
		spawn_x += CHUNK_WIDTH

func _process(_delta: float) -> void:
	if chunk_parent == null:
		return

	# Calculate current rightmost edge of all active chunks
	var rightmost_x: float = -99999.0
	for c in chunk_parent.get_children():
		if c is Chunk and is_instance_valid(c):
			var end_x: float = c.global_position.x + CHUNK_WIDTH
			if end_x > rightmost_x:
				rightmost_x = end_x

	if rightmost_x < -90000.0:
		rightmost_x = 0.0

	# Continuously spawn ahead chunks seamlessly without gaps
	while rightmost_x < 1920.0 + CHUNK_WIDTH * LOOK_AHEAD_CHUNKS:
		_spawn_next_chunk_at(rightmost_x)
		rightmost_x += CHUNK_WIDTH

var is_boss_active: bool = false

func _spawn_next_chunk_at(spawn_x: float) -> void:
	if chunk_parent == null:
		return

	var chunk: Chunk = ChunkScene.instantiate()
	chunk_parent.add_child(chunk)
	chunk.global_position = Vector2(spawn_x, 0.0)
	chunk.scroll_speed = scroll_speed

	var new_top: float
	var new_bot: float

	if is_boss_active:
		# Open arena bounds during boss fight
		new_top = 80.0
		new_bot = 1000.0
	else:
		# Calculate next corridor values with a smooth random walk
		new_top = _corridor_top + _rng.randf_range(-40.0, 40.0)
		new_bot = _corridor_bottom + _rng.randf_range(-40.0, 40.0)

		# Clamp so corridor always fits and walls exist
		new_top = clamp(new_top, 60.0, SCREEN_HEIGHT - MIN_CORRIDOR - 60.0)
		new_bot = clamp(new_bot, new_top + MIN_CORRIDOR, SCREEN_HEIGHT - 60.0)
		if new_top > MAX_WALL_THICKNESS:
			new_top = MAX_WALL_THICKNESS
		if SCREEN_HEIGHT - new_bot > MAX_WALL_THICKNESS:
			new_bot = SCREEN_HEIGHT - MAX_WALL_THICKNESS

	var level_col_idx: int = clampi(GameState.level - 1, 0, LEVEL_COLORS.size() - 1)
	var wall_col: Color = LEVEL_COLORS[level_col_idx]
	chunk.build(_corridor_top, _corridor_bottom, new_top, new_bot, wall_col, scroll_speed, _rng, GameState.level)

	# Generate spawn data for this chunk (if not fighting boss)
	if not is_boss_active:
		var spawns: Array = _generate_spawn_data(chunk_parent.global_position.x)
		if spawns.size() > 0:
			chunk.call_deferred("emit_spawns", spawns)

	# Connect signals
	if enemy_spawner:
		chunk.enemy_spawn_requested.connect(enemy_spawner._on_enemy_spawn_requested)
	if powerup_spawner:
		chunk.powerup_spawn_requested.connect(powerup_spawner._on_powerup_spawn_requested)

	_corridor_top = new_top
	_corridor_bottom = new_bot
	_chunk_index += 1

	# Boss trigger
	if not is_boss_active:
		_chunks_until_boss -= 1
		if _chunks_until_boss <= 0:
			_chunks_until_boss = _boss_chunk_interval
			boss_trigger_reached.emit(GameState.level)

func _generate_spawn_data(chunk_world_x: float) -> Array:
	var spawns: Array = []
	# Grace intro period: no enemies for the first 3 chunks (gives player ~10-12s of clear flying).
	# Boss Rush skips regular waves entirely — it's boss fights back-to-back, nothing else.
	if _chunk_index < 3 or is_boss_active or GameState.boss_rush_mode:
		return spawns

	var level: int = GameState.level
	var enemy_pool: Array[int] = _get_enemy_pool_for_level(level)

	var enemy_count: int
	var spawn_chance: float

	if _chunk_index < 6:
		# Early scout wave: 1 enemy, 60% chance
		enemy_count = 1
		spawn_chance = 0.60
	elif _chunk_index < 10:
		# Light wave: 1-2 enemies, 70% chance
		enemy_count = _rng.randi_range(1, 2)
		spawn_chance = 0.70
	else:
		# Standard combat wave: 2-3 enemies
		enemy_count = _rng.randi_range(2, 3 + int(level / 3))
		spawn_chance = 0.80

	# Difficulty scaling: higher levels pack in more enemies, more often;
	# the player's difficulty selection scales this growth up or down.
	var diff_mult: float = GameState.get_difficulty_multiplier()
	var density_bonus: int = int(float(level - 1) * DENSITY_BONUS_PER_LEVEL * diff_mult)
	enemy_count += density_bonus
	spawn_chance = minf(MAX_SPAWN_CHANCE, spawn_chance * diff_mult + float(level - 1) * SPAWN_CHANCE_PER_LEVEL * diff_mult)

	# Overall density multiplier (doubles how many enemies pack into each chunk).
	enemy_count = mini(enemy_count * DENSITY_MULTIPLIER, MAX_ENEMIES_PER_CHUNK)

	for i in range(enemy_count):
		if _rng.randf() < spawn_chance:
			var segment_w: float = CHUNK_WIDTH / float(enemy_count)
			var x: float = segment_w * i + _rng.randf_range(30.0, segment_w - 30.0)
			var y: float = _rng.randf_range(_corridor_top + 45.0, _corridor_bottom - 45.0)
			var eid: int = enemy_pool[_rng.randi() % enemy_pool.size()]
			spawns.append({"type": "enemy", "pos": Vector2(x, y), "id": eid})

	return spawns

func _get_enemy_pool_for_level(level: int) -> Array[int]:
	## Returns which enemy type IDs are valid for the given level.
	var pool: Array[int] = [0, 1, 2, 7]  # Grunt, Weaver, Diver, Zigzag
	if level >= 2: pool.append_array([3, 5, 8])       # Sniper, Turret, Bomber
	if level >= 3: pool.append_array([4, 6, 9])       # Spreader, Shield, Stalker
	if level >= 4: pool.append_array([10, 11, 14])    # Circler, Kamikaze, Charger
	if level >= 5: pool.append_array([12, 13, 16])    # Cloaker, Splitter, Formation
	if level >= 6: pool.append_array([15, 17])        # Tanker, Boomerang
	if level >= 7: pool.append_array([18, 19])        # Leech, Overseer
	return pool

func get_corridor_bounds() -> Vector2:
	## Returns Vector2(top_y, bottom_y) of current corridor for player clamping.
	return Vector2(_corridor_top, _corridor_bottom)

func set_scroll_speed(speed: float) -> void:
	scroll_speed = speed
	# Update all existing chunks
	if chunk_parent:
		for child in chunk_parent.get_children():
			if child is Chunk:
				child.scroll_speed = speed
