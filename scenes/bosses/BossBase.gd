class_name BossBase
extends CharacterBody2D
## BossBase — base class for all 8 boss encounters.
## Bosses enter from the right edge, slide to their arena position, show a
## health bar via BossManager, then execute multi-phase attack patterns.
## Subclasses override _phase_attack() and _on_phase_change().

signal died
signal health_changed(current: int, maximum: int)
signal phase_changed(new_phase: int)
signal entrance_complete

# ── Stats ─────────────────────────────────────────────────────
var boss_name: String = "Boss"
var max_health: int = 1000
var current_health: int = 1000
var phase_count: int = 2
var current_phase: int = 0
var score_value: int = 5000
var boss_color: Color = Color.DARK_RED
var size_scale: float = 1.0
var entry_speed: float = 120.0

## Injected by BossManager
var bullet_container: Node = null
var player_ref: Node = null

const BossBulletScene: PackedScene = preload("res://scenes/player/weapons/Bullet.tscn")

# ── Internal ──────────────────────────────────────────────────
var _is_dead: bool = false
var _is_entering: bool = true
var _arena_x: float = 1400.0     # X position boss stops at (right ~75% of screen)
var _time: float = 0.0
var _phase_time: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
	current_health = max_health
	_sprite = $Visual/Sprite2D
	if _sprite:
		_sprite.modulate = boss_color
		_sprite.scale = Vector2(0.165, 0.165) * size_scale
	# Start offscreen to the right
	global_position.x = 2100.0
	global_position.y = 540.0
	add_to_group("bosses")

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_time += delta
	_phase_time += delta

	if _is_entering:
		_do_entry(delta)
		return

	_phase_attack(delta)
	move_and_slide()

	# Clamp boss to arena bounds
	global_position.x = clamp(global_position.x, 150.0, 1850.0)
	global_position.y = clamp(global_position.y, 60.0, 1020.0)

# ── Override in subclasses ────────────────────────────────────

## Called every frame during combat — implement attack patterns here
func _phase_attack(delta: float) -> void:
	pass

## Called when phase changes — use to switch attack patterns
func _on_phase_change(new_phase: int) -> void:
	pass

# ── Public API ────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if _sprite:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.06)
		tw.tween_property(_sprite, "modulate", boss_color, 0.06)
	_check_phase_transition()
	if current_health <= 0:
		_die()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area is Bullet and not area.is_enemy_bullet:
		take_damage(area.damage)
	elif area.is_in_group("player_bullet"):
		var dmg = 10
		if "damage" in area:
			dmg = area.damage
		take_damage(dmg)

func init_from_data(data: BossData) -> void:
	boss_name   = data.boss_name
	max_health  = data.max_health
	current_health = data.max_health
	phase_count = data.phase_count
	score_value = data.score_value
	boss_color  = data.color
	size_scale  = data.size_scale
	entry_speed = data.entry_speed

# ── Helpers ───────────────────────────────────────────────────

func _do_entry(delta: float) -> void:
	velocity.x = -entry_speed
	move_and_slide()
	if global_position.x <= _arena_x:
		global_position.x = _arena_x
		velocity = Vector2.ZERO
		_is_entering = false
		_phase_time = 0.0
		entrance_complete.emit()

func _check_phase_transition() -> void:
	if phase_count <= 1:
		return
	var hp_fraction := float(current_health) / float(max_health)
	var threshold_per_phase := 1.0 / float(phase_count)
	var expected_phase := phase_count - 1 - int(hp_fraction / threshold_per_phase)
	expected_phase = clamp(expected_phase, 0, phase_count - 1)
	if expected_phase != current_phase:
		current_phase = expected_phase
		_phase_time = 0.0
		phase_changed.emit(current_phase)
		_on_phase_change(current_phase)

func _die() -> void:
	_is_dead = true
	GameState.add_score(score_value)
	_spawn_death_explosion()
	died.emit()
	queue_free()

func _spawn_death_explosion() -> void:
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		for i in 6:
			var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
			parent_node.call_deferred("add_child", fx)
			var offset := Vector2(randf_range(-100, 100), randf_range(-60, 60)) * size_scale
			if fx.has_method("setup"):
				fx.setup(global_position + offset, boss_color, size_scale * 1.6)

## Fires a bullet toward the player
func _fire_at_player(speed: float = 500.0, dmg: int = 1, col: Color = Color.ORANGE_RED) -> void:
	if bullet_container == null:
		return
	var dir := get_player_direction()
	_spawn_boss_bullet(dir * speed, col, dmg)

## Fires in a radial spread
func _fire_radial(count: int, speed: float = 450.0, dmg: int = 1,
		col: Color = Color.ORANGE_RED, angle_offset: float = 0.0) -> void:
	for i in count:
		var angle := TAU / float(count) * i + deg_to_rad(angle_offset)
		var vel := Vector2.RIGHT.rotated(angle) * speed
		_spawn_boss_bullet(vel, col, dmg)

func _spawn_boss_bullet(vel: Vector2, col: Color, dmg: int) -> void:
	if bullet_container == null:
		return
	var b: Bullet = BossBulletScene.instantiate()
	bullet_container.add_child(b)
	b.global_position = global_position
	b.setup(vel, col, dmg, 1.3, true)

func get_player_direction() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		return (player_ref.global_position - global_position).normalized()
	return Vector2.LEFT
