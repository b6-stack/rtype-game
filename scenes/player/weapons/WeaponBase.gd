class_name WeaponBase
extends Node
## WeaponBase — base class for all 10 weapon types.
## Subclasses override fire() and charge_fire() to implement unique behaviours.
## The Player sets bullet_container before any shots are fired.

signal fired
signal charge_fired

## Set by the Player node when this weapon is equipped
var bullet_container: Node = null

## Populated from WeaponData resource by Player
var weapon_name: String = "Unknown"
var fire_rate: float = 0.15        # shots per second
var bullet_color: Color = Color.CYAN
var bullet_speed: float = 800.0
var damage: int = 10
var weapon_index: int = 0

## Preloaded bullet scene — shared across all weapons
const BulletScene: PackedScene = preload("res://scenes/player/weapons/Bullet.tscn")

## Timer for auto-fire cooldown (managed by Player)
var _fire_cooldown: float = 0.0

func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

func can_fire() -> bool:
	return _fire_cooldown <= 0.0

# ── Override in subclasses ───────────────────────────────────

## Primary fire — called continuously while auto-firing (silent regular shots)
func fire(spawn_pos: Vector2, rate_multiplier: float = 1.0) -> void:
	if not can_fire():
		return
	var eff_rate: float = max(0.1, fire_rate * rate_multiplier)
	_fire_cooldown = 1.0 / eff_rate
	_do_fire(spawn_pos)
	fired.emit()

## Called once when the player releases the charge finger
## charge_level is 0.0–1.0 (1.0 = fully charged)
func charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	_do_charge_fire(spawn_pos, charge_level)
	AudioManager.play_charge_fire_sfx(charge_level)
	charge_fired.emit()

## Override this for primary shot pattern
func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.0)

## Returns damage multiplier based on charge color tier: Red (80%), Yellow (90%), Green (95%), Flashing Max (100%)
func get_charge_tier_multiplier(charge_level: float) -> float:
	if charge_level >= 1.0:
		return 1.00 # 100% full damage when fully charged & flashing
	elif charge_level >= 0.66:
		return 0.95 # 95% green tier
	elif charge_level >= 0.33:
		return 0.90 # 90% yellow tier
	else:
		return 0.80 # 80% red tier

## Override this for charged shot pattern
func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	if charge_level < 1.0:
		# Partial charge: smooth above-average normal shot
		var dmg: int = max(1, int(damage * lerpf(1.25, 1.65, charge_level)))
		var size_m: float = lerpf(1.15, 1.40, charge_level)
		_spawn_bullet(spawn_pos, Vector2.RIGHT * (bullet_speed * 1.05),
				bullet_color.lightened(0.25), dmg, size_m)
	else:
		# Full Super Charge
		var final_dmg: int = max(1, int(damage * 3.2))
		_spawn_bullet(spawn_pos, Vector2.RIGHT * (bullet_speed * 1.15),
				bullet_color.lightened(0.65), final_dmg, 2.6)

# ── Helpers ──────────────────────────────────────────────────

func _spawn_bullet(pos: Vector2, velocity: Vector2,
		col: Color, dmg: int, size_mult: float = 1.0, sprite_type: String = "", pierces: int = 0) -> Bullet:
	var container := _get_bullet_container()
	if container == null:
		push_warning("WeaponBase: bullet_container not set on %s" % weapon_name)
		return null
	if GameState.ultra_mode_enabled:
		col = Color.from_hsv(fmod(Time.get_ticks_msec() * 0.001, 1.0), 1.0, 1.0)
	var b: Bullet = BulletScene.instantiate()
	b.setup(velocity, col, dmg, size_mult, false, sprite_type, pierces)
	b.global_position = pos
	_safe_add_bullet.call_deferred(b, pos)
	return b

func _safe_add_bullet(b: Bullet, pos: Vector2) -> void:
	var container := _get_bullet_container()
	if container and is_instance_valid(b):
		container.add_child(b)
		b.global_position = pos

func _get_bullet_container() -> Node:
	if bullet_container == null or not is_instance_valid(bullet_container):
		var tree := get_tree()
		if tree and tree.current_scene:
			var container := tree.current_scene.get_node_or_null("Entities/PlayerBullets")
			if container:
				bullet_container = container
			else:
				bullet_container = tree.current_scene
	return bullet_container

## Spawns multiple bullets in an arc (angle_spread in degrees, count shots)
func _spawn_spread(pos: Vector2, velocity: Vector2, col: Color,
		dmg: int, size_mult: float, count: int, angle_spread: float, sprite_type: String = "", pierces: int = 0) -> void:
	if count <= 1:
		_spawn_bullet(pos, velocity, col, dmg, size_mult, sprite_type, pierces)
		return
	var half := angle_spread * 0.5
	var step := angle_spread / float(count - 1)
	for i in count:
		var angle_deg := -half + step * i
		var rotated := velocity.rotated(deg_to_rad(angle_deg))
		_spawn_bullet(pos, rotated, col, dmg, size_mult, sprite_type, pierces)

## Initialise this weapon from a WeaponData resource
func init_from_data(data: WeaponData) -> void:
	weapon_name   = data.weapon_name
	weapon_index  = data.weapon_index
	fire_rate     = data.fire_rate
	bullet_color  = data.bullet_color
	bullet_speed  = data.bullet_speed
	damage        = data.damage
