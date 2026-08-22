class_name EnemyBase
extends CharacterBody2D
## EnemyBase — base class for all 20 enemy types.
## Subclasses override _move() and _shoot() to implement unique personalities.

signal died(position: Vector2, score_value: int)
signal damaged(amount: int)

# ── Stats (populated from EnemyData or set directly) ─────────
var max_health: int = 20
var current_health: int = 20
var move_speed: float = 180.0
var score_value: int = 100
var shoot_cooldown: float = 2.0
var bullet_color: Color = Color.ORANGE_RED
var bullet_speed: float = 400.0
var bullet_damage: int = 1
var enemy_color: Color = Color.RED
var size_scale: float = 1.0

## Container node for enemy bullets — injected by EnemySpawner
var bullet_container: Node = null

## Reference to player — injected by EnemySpawner
var player_ref: Node = null

const EnemyBulletScene: PackedScene = preload("res://scenes/player/weapons/Bullet.tscn")

# ── Internal ─────────────────────────────────────────────────
var _shoot_timer: float = 0.0
var _is_dead: bool = false
var _time: float = 0.0          # elapsed time for pattern math
var _spawn_position: Vector2 = Vector2.ZERO
var _sprite: Sprite2D

func _ready() -> void:
	current_health = max_health
	_sprite = $Visual/Sprite2D
	if _sprite:
		_sprite.modulate = enemy_color
		_scale_visual()
	_shoot_timer = randf_range(0.0, shoot_cooldown)
	_spawn_position = global_position

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_time += delta
	_move(delta)
	move_and_slide()

	_shoot_timer -= delta
	if _shoot_timer <= 0.0 and shoot_cooldown > 0.0:
		_shoot_timer = shoot_cooldown
		_shoot()

	# Auto-destroy when scrolled off screen (left edge)
	if global_position.x < -200.0:
		queue_free()

# ── Override these ────────────────────────────────────────────

## Override to implement unique movement pattern each frame
func _move(delta: float) -> void:
	velocity.x = -move_speed

## Override to implement unique shooting behaviour
func _shoot() -> void:
	_fire_at_player()

# ── Public API ────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_health = max(0, current_health - amount)
	if current_health > 0 and _sprite and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(_sprite, "modulate", enemy_color, 0.05)
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

func init_from_data(data: EnemyData) -> void:
	max_health    = data.max_health
	current_health = data.max_health
	move_speed    = data.move_speed
	score_value   = data.score_value
	shoot_cooldown = data.shoot_cooldown
	bullet_color  = data.bullet_color
	bullet_speed  = data.bullet_speed
	bullet_damage = data.bullet_damage
	enemy_color   = data.color
	size_scale    = data.size_scale

# ── Helpers ───────────────────────────────────────────────────

func _die() -> void:
	_is_dead = true
	died.emit(global_position, score_value)
	AudioManager.play_explosion_sfx()
	# Spawn a small explosion visual
	_spawn_death_flash()
	queue_free()

func _spawn_death_flash() -> void:
	_do_spawn_explosion.call_deferred(global_position, enemy_color, max(0.9, size_scale))

func _do_spawn_explosion(pos: Vector2, col: Color, scale_s: float) -> void:
	var tree := get_tree()
	var parent_node: Node = get_parent() if get_parent() else (tree.current_scene if tree else null)
	if parent_node:
		var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
		parent_node.add_child(fx)
		fx.global_position = pos
		if fx.has_method("setup"):
			fx.setup(pos, col, scale_s)

func _fire_at_player() -> void:
	if bullet_container == null:
		return
	var dir := Vector2.LEFT
	if player_ref and is_instance_valid(player_ref):
		dir = (player_ref.global_position - global_position).normalized()
	_spawn_enemy_bullet(dir * bullet_speed)

func _fire_direction(dir: Vector2) -> void:
	_spawn_enemy_bullet(dir.normalized() * bullet_speed)

func _spawn_enemy_bullet(vel: Vector2) -> void:
	if bullet_container == null:
		return
	_do_spawn_enemy_bullet.call_deferred(global_position, vel, bullet_color, bullet_damage)

func _do_spawn_enemy_bullet(spawn_pos: Vector2, vel: Vector2, col: Color, dmg: int) -> void:
	if bullet_container == null:
		return
	var b: Bullet = EnemyBulletScene.instantiate()
	bullet_container.add_child(b)
	b.global_position = spawn_pos
	b.setup(vel, col, dmg, 1.0, true)

func _scale_visual() -> void:
	if _sprite:
		_sprite.scale = Vector2(0.065, 0.065) * size_scale

func get_player_direction() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		return (player_ref.global_position - global_position).normalized()
	return Vector2.LEFT
